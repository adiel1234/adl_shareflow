"""Review-account-only IAP enablement while PAYMENTS_ENABLED stays false."""
import os
from unittest.mock import MagicMock, patch

import pytest
from flask_jwt_extended import create_access_token, verify_jwt_in_request

from app import create_app, db
from app.groups.routes import _validate_iap
from app.iap.policy import (
    REVIEW_USER_IDS_ENV,
    parse_review_user_ids,
    payments_required_for_user,
)
from app.iap.routes import validate_paid_operation
from config import TestingConfig

APPLE_UID = '28d0876c-32f8-47ac-9fa6-da2de12ed395'
OTHER_UID = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'


@pytest.fixture
def app():
    application = create_app(TestingConfig)
    application.config['JWT_BLOCKLIST_ENABLED'] = False
    return application


def _auth_headers(app, user_id):
    with app.app_context():
        token = create_access_token(identity=user_id)
    return {'Authorization': f'Bearer {token}'}


def _active_user(user_id):
    user = MagicMock()
    user.id = user_id
    user.is_active = True
    user.account_mode = 'pilot'
    return user


def _jwt_user(user_id):
    return patch.object(db.session, 'get', return_value=_active_user(user_id))


def _apple_ok_result(product_id='com.adl.shareflow.tier_15', transaction_id='T-OK'):
    return {
        'valid': True,
        'error': None,
        'transactions': [{
            'product_id': product_id,
            'transaction_id': transaction_id,
        }],
    }


class TestParseReviewUserIds:
    def test_empty_and_unset_are_empty(self):
        assert parse_review_user_ids(None) == frozenset()
        assert parse_review_user_ids('') == frozenset()
        assert parse_review_user_ids('   ') == frozenset()

    def test_one_uuid_and_comma_separated(self):
        assert parse_review_user_ids(APPLE_UID) == frozenset({APPLE_UID})
        parsed = parse_review_user_ids(f' {APPLE_UID}, {OTHER_UID} ')
        assert parsed == frozenset({APPLE_UID, OTHER_UID})

    def test_malformed_values_fail_closed(self):
        assert parse_review_user_ids('*') == frozenset()
        assert parse_review_user_ids('true') == frozenset()
        assert parse_review_user_ids('all') == frozenset()
        assert parse_review_user_ids('not-a-uuid,also-bad') == frozenset()
        assert parse_review_user_ids(f'*,{APPLE_UID},true') == frozenset({APPLE_UID})


class TestPaymentsRequiredForUser:
    def test_global_false_empty_list_normal_user(self):
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: ''}, clear=False):
            os.environ.pop(REVIEW_USER_IDS_ENV, None)
            assert payments_required_for_user(OTHER_UID) is False
            assert payments_required_for_user(APPLE_UID) is False
            assert payments_required_for_user(None) is False

    def test_global_false_review_user_only(self):
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False):
            assert payments_required_for_user(APPLE_UID) is True
            assert payments_required_for_user(APPLE_UID.upper()) is True
            assert payments_required_for_user(OTHER_UID) is False
            assert payments_required_for_user(None) is False
            assert payments_required_for_user('') is False
            assert payments_required_for_user('not-a-uuid') is False

    def test_global_true_enables_everyone(self):
        with patch('app.iap.policy.global_payments_enabled', return_value=True), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: ''}, clear=False):
            os.environ.pop(REVIEW_USER_IDS_ENV, None)
            assert payments_required_for_user(OTHER_UID) is True
            assert payments_required_for_user(APPLE_UID) is True
            assert payments_required_for_user(None) is True

    def test_malformed_env_never_enables_broadly(self):
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: '*,true,all'}, clear=False):
            assert payments_required_for_user(OTHER_UID) is False
            assert payments_required_for_user(APPLE_UID) is False


class TestPublicConfig:
    def test_unauthenticated_cannot_trigger_review_exception(self, app):
        client = app.test_client()
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch('app.pilot_mode.is_pilot_mode_enabled', return_value=True), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False):
            resp = client.get(
                f'/api/config/public?user_id={APPLE_UID}',
            )
        assert resp.status_code == 200
        body = resp.get_json()
        assert body['payments_enabled'] is False
        assert body['pilot_mode_enabled'] is True
        assert 'IAP_REVIEW_USER_IDS' not in body
        assert APPLE_UID not in resp.get_data(as_text=True)

    def test_review_user_gets_payments_enabled(self, app):
        client = app.test_client()
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch('app.pilot_mode.is_pilot_mode_enabled', return_value=True), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False), \
             _jwt_user(APPLE_UID):
            resp = client.get(
                '/api/config/public',
                headers=_auth_headers(app, APPLE_UID),
            )
        assert resp.status_code == 200
        body = resp.get_json()
        assert body['payments_enabled'] is True
        assert 'review' not in body
        assert APPLE_UID not in resp.get_data(as_text=True)

    def test_other_authenticated_user_stays_false(self, app):
        client = app.test_client()
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch('app.pilot_mode.is_pilot_mode_enabled', return_value=True), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False), \
             _jwt_user(OTHER_UID):
            resp = client.get(
                f'/api/config/public?user_id={APPLE_UID}',
                headers=_auth_headers(app, OTHER_UID),
            )
        assert resp.status_code == 200
        assert resp.get_json()['payments_enabled'] is False

    def test_empty_allowlist_keeps_review_user_false(self, app):
        client = app.test_client()
        env = {k: v for k, v in os.environ.items() if k != REVIEW_USER_IDS_ENV}
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch('app.pilot_mode.is_pilot_mode_enabled', return_value=True), \
             patch.dict(os.environ, env, clear=True), \
             _jwt_user(APPLE_UID):
            resp = client.get(
                '/api/config/public',
                headers=_auth_headers(app, APPLE_UID),
            )
        assert resp.status_code == 200
        assert resp.get_json()['payments_enabled'] is False

    def test_global_true_is_true_for_everyone(self, app):
        client = app.test_client()
        env = {k: v for k, v in os.environ.items() if k != REVIEW_USER_IDS_ENV}
        with patch('app.iap.policy.global_payments_enabled', return_value=True), \
             patch('app.pilot_mode.is_pilot_mode_enabled', return_value=True), \
             patch.dict(os.environ, env, clear=True), \
             _jwt_user(OTHER_UID):
            anon = client.get('/api/config/public')
            other = client.get(
                '/api/config/public',
                headers=_auth_headers(app, OTHER_UID),
            )
        assert anon.get_json()['payments_enabled'] is True
        assert other.get_json()['payments_enabled'] is True


class TestValidatePaidOperationGate:
    def test_pilot_user_bypasses_without_receipt(self):
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False), \
             patch('app.iap.routes.verify_apple_receipt') as verify:
            result = validate_paid_operation(
                receipt_data='',
                platform='',
                expected_product_id='com.adl.shareflow.tier_15',
                operation='activation',
                group_id='g1',
                user_id=OTHER_UID,
            )
        assert result['valid'] is True
        verify.assert_not_called()

    def test_review_user_requires_valid_receipt_and_product(self):
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False), \
             patch(
                 'app.iap.routes.verify_apple_receipt',
                 return_value=_apple_ok_result(),
             ) as verify, \
             patch(
                 'app.iap.routes._reserve_transaction',
                 return_value={'valid': True, 'error': None},
             ) as reserve:
            result = validate_paid_operation(
                receipt_data='sandbox-receipt',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_15',
                operation='activation',
                group_id='g1',
                user_id=APPLE_UID,
            )
        assert result['valid'] is True
        verify.assert_called_once_with('sandbox-receipt')
        reserve.assert_called_once_with(
            'T-OK',
            'com.adl.shareflow.tier_15',
            'ios',
            'activation',
            'g1',
            APPLE_UID,
        )

    def test_review_user_wrong_product_rejected(self):
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False), \
             patch(
                 'app.iap.routes.verify_apple_receipt',
                 return_value=_apple_ok_result('com.adl.shareflow.tier_5', 'T-CHEAP'),
             ), \
             patch('app.iap.routes._reserve_transaction') as reserve:
            result = validate_paid_operation(
                receipt_data='sandbox-receipt',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_15',
                operation='activation',
                group_id='g1',
                user_id=APPLE_UID,
            )
        assert result['valid'] is False
        reserve.assert_not_called()

    def test_review_user_replay_rejected(self):
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False), \
             patch(
                 'app.iap.routes.verify_apple_receipt',
                 return_value=_apple_ok_result(),
             ), \
             patch(
                 'app.iap.routes._reserve_transaction',
                 return_value={'valid': False, 'error': 'העסקה כבר מומשה'},
             ):
            result = validate_paid_operation(
                receipt_data='sandbox-receipt',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_15',
                operation='activation',
                group_id='g1',
                user_id=APPLE_UID,
            )
        assert result['valid'] is False
        assert 'כבר' in result['error']

    def test_review_user_empty_receipt_rejected(self):
        with patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False):
            result = validate_paid_operation(
                receipt_data='',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_15',
                operation='activation',
                group_id='g1',
                user_id=APPLE_UID,
            )
        assert result['valid'] is False

    def test_spoofed_body_user_id_does_not_enable_other_jwt(self, app):
        group = MagicMock()
        group.id = 'g1'
        group.group_type = 'event'
        headers = _auth_headers(app, OTHER_UID)
        with app.test_request_context(
            '/api/groups/g1/activate',
            method='POST',
            json={
                'user_id': APPLE_UID,
                'receipt_data': '',
                'platform': 'ios',
            },
            headers=headers,
        ), patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False), \
             _jwt_user(OTHER_UID), \
             patch('app.iap.routes.verify_apple_receipt') as verify:
            verify_jwt_in_request()
            ok, err = _validate_iap(
                {
                    'user_id': APPLE_UID,
                    'receipt_data': '',
                    'platform': 'ios',
                },
                group,
                'activation',
            )
        assert ok is True
        assert err is None
        verify.assert_not_called()

    def test_review_jwt_requires_iap_even_if_body_claims_other_user(self, app):
        group = MagicMock()
        group.id = 'g1'
        group.group_type = 'event'
        headers = _auth_headers(app, APPLE_UID)
        with app.test_request_context(
            '/api/groups/g1/activate',
            method='POST',
            json={'user_id': OTHER_UID, 'receipt_data': ''},
            headers=headers,
        ), patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False), \
             _jwt_user(APPLE_UID), \
             patch(
                 'app.iap.products.required_amount_ils',
                 return_value=15,
             ), \
             patch(
                 'app.iap.products.product_id_for_amount',
                 return_value='com.adl.shareflow.tier_15',
             ):
            verify_jwt_in_request()
            ok, err = _validate_iap(
                {'user_id': OTHER_UID, 'receipt_data': ''},
                group,
                'activation',
            )
        assert ok is False
        assert err is not None


class TestMonetizationUsesPayerIdentity:
    def test_review_payer_records_real_amount(self):
        from decimal import Decimal
        from app.groups.monetization_service import _record_platform_payment

        group = MagicMock()
        group.id = 'g1'
        group.base_currency = 'ILS'
        expense = MagicMock()
        expense.id = 'e1'
        with patch(
            'app.groups.monetization_service.create_payment_expense',
            return_value=expense,
        ), patch('app.groups.monetization_service.db') as mock_db, \
             patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False):
            _record_platform_payment(
                group,
                payer_id=APPLE_UID,
                amount=Decimal('15'),
                payment_type='activation',
                source='activation',
                split_among_group=True,
            )
        payment = mock_db.session.add.call_args[0][0]
        assert payment.amount == Decimal('15')

    def test_pilot_payer_records_zero(self):
        from decimal import Decimal
        from app.groups.monetization_service import _record_platform_payment

        group = MagicMock()
        group.id = 'g1'
        group.base_currency = 'ILS'
        expense = MagicMock()
        expense.id = 'e1'
        with patch(
            'app.groups.monetization_service.create_payment_expense',
            return_value=expense,
        ), patch('app.groups.monetization_service.db') as mock_db, \
             patch('app.iap.policy.global_payments_enabled', return_value=False), \
             patch.dict(os.environ, {REVIEW_USER_IDS_ENV: APPLE_UID}, clear=False):
            _record_platform_payment(
                group,
                payer_id=OTHER_UID,
                amount=Decimal('15'),
                payment_type='activation',
                source='activation',
                split_among_group=True,
            )
        payment = mock_db.session.add.call_args[0][0]
        assert payment.amount == Decimal('0')


class TestDuplicateUsesSameDecision:
    def test_source_passes_user_id_into_payments_check(self):
        from app.groups import routes as groups_routes
        import inspect
        src = inspect.getsource(groups_routes.duplicate_group)
        assert '_payments_enabled(user_id)' in src
        assert 'not _payments_enabled()' not in src
