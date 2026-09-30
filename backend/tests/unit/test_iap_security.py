"""IAP product mapping + paid-operation verification when payments are enabled."""
from unittest.mock import MagicMock, patch

from app.iap.products import PRICE_TO_PRODUCT_ID, product_id_for_amount, required_amount_ils
from app.iap.routes import (
    _apple_transactions,
    _reserve_transaction,
    validate_paid_operation,
    verify_apple_receipt,
)
from app.groups.lifecycle_service import MonetizationConfig, check_tier_upgrade


EXPECTED_IDS = {
    'com.adl.shareflow.tier_5',
    'com.adl.shareflow.tier_10',
    'com.adl.shareflow.tier_15',
    'com.adl.shareflow.tier_20',
    'com.adl.shareflow.tier_25',
    'com.adl.shareflow.tier_30',
    'com.adl.shareflow.tier_35',
    'com.adl.shareflow.tier_40',
    'com.adl.shareflow.tier_45',
    'com.adl.shareflow.tier_49',
    'com.adl.shareflow.tier_69',
    'com.adl.shareflow.tier_79',
    'com.adl.shareflow.tier_89',
}


def test_thirteen_product_ids_including_tier_40():
    assert len(PRICE_TO_PRODUCT_ID) == 13
    assert set(PRICE_TO_PRODUCT_ID.values()) == EXPECTED_IDS
    assert product_id_for_amount(40) == 'com.adl.shareflow.tier_40'
    for amount, product_id in PRICE_TO_PRODUCT_ID.items():
        assert product_id == f'com.adl.shareflow.tier_{amount}'


def test_upgrade_49_to_89_requires_tier_40():
    info = check_tier_upgrade('ongoing', 12, 5)
    assert info['upgrade_price_diff'] == 40
    assert product_id_for_amount(info['upgrade_price_diff']) == 'com.adl.shareflow.tier_40'


def test_existing_event_and_ongoing_amounts_still_map():
    assert MonetizationConfig.resolve_event_price(5)['amount'] == 15
    assert product_id_for_amount(15) == 'com.adl.shareflow.tier_15'
    assert product_id_for_amount(25) == 'com.adl.shareflow.tier_25'
    assert product_id_for_amount(89) == 'com.adl.shareflow.tier_89'
    assert product_id_for_amount(7) is None


def _apple_ok(transactions):
    return {
        'status': 0,
        'latest_receipt_info': transactions,
        'receipt': {'in_app': transactions},
    }


class TestAppleExtraction:
    def test_extracts_product_and_transaction_from_apple_payload(self):
        txns = _apple_transactions(_apple_ok([
            {'product_id': 'com.adl.shareflow.tier_15', 'transaction_id': 'T-15'},
        ]))
        assert txns == [{
            'product_id': 'com.adl.shareflow.tier_15',
            'transaction_id': 'T-15',
        }]


class TestValidatePaidOperation:
    def test_payments_disabled_bypasses_without_reading_client_flags(self):
        with patch('app.iap.routes._payments_enabled', return_value=False):
            result = validate_paid_operation(
                receipt_data='',
                platform='',
                expected_product_id='com.adl.shareflow.tier_89',
                operation='activation',
                group_id='g1',
                user_id='u1',
            )
        assert result['valid'] is True

    def test_accepts_matching_verified_product(self):
        apple = {
            'valid': True,
            'transactions': [{
                'product_id': 'com.adl.shareflow.tier_15',
                'transaction_id': 'T-OK',
            }],
        }
        with patch('app.iap.routes._payments_enabled', return_value=True), \
             patch('app.iap.routes.verify_apple_receipt', return_value=apple), \
             patch('app.iap.routes._reserve_transaction', return_value={'valid': True, 'error': None}) as reserve:
            result = validate_paid_operation(
                receipt_data='receipt',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_15',
                operation='activation',
                group_id='g1',
                user_id='u1',
            )
        assert result['valid'] is True
        reserve.assert_called_once_with(
            'T-OK', 'com.adl.shareflow.tier_15', 'ios', 'activation', 'g1', 'u1'
        )

    def test_rejects_cheaper_or_wrong_product_even_if_receipt_valid(self):
        apple = {
            'valid': True,
            'transactions': [{
                'product_id': 'com.adl.shareflow.tier_5',
                'transaction_id': 'T-CHEAP',
            }],
        }
        with patch('app.iap.routes._payments_enabled', return_value=True), \
             patch('app.iap.routes.verify_apple_receipt', return_value=apple), \
             patch('app.iap.routes._reserve_transaction') as reserve:
            result = validate_paid_operation(
                receipt_data='receipt',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_89',
                operation='activation',
                group_id='g1',
                user_id='u1',
            )
        assert result['valid'] is False
        reserve.assert_not_called()

    def test_rejects_tier_40_when_amount_is_not_40(self):
        apple = {
            'valid': True,
            'transactions': [{
                'product_id': 'com.adl.shareflow.tier_40',
                'transaction_id': 'T-40',
            }],
        }
        with patch('app.iap.routes._payments_enabled', return_value=True), \
             patch('app.iap.routes.verify_apple_receipt', return_value=apple), \
             patch('app.iap.routes._reserve_transaction') as reserve:
            result = validate_paid_operation(
                receipt_data='receipt',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_15',
                operation='activation',
                group_id='g1',
                user_id='u1',
            )
        assert result['valid'] is False
        reserve.assert_not_called()

    def test_accepts_tier_40_for_required_40(self):
        apple = {
            'valid': True,
            'transactions': [{
                'product_id': 'com.adl.shareflow.tier_40',
                'transaction_id': 'T-40',
            }],
        }
        with patch('app.iap.routes._payments_enabled', return_value=True), \
             patch('app.iap.routes.verify_apple_receipt', return_value=apple), \
             patch('app.iap.routes._reserve_transaction', return_value={'valid': True, 'error': None}):
            result = validate_paid_operation(
                receipt_data='receipt',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_40',
                operation='upgrade',
                group_id='g1',
                user_id='u1',
            )
        assert result['valid'] is True

    def test_rejects_invalid_apple_receipt(self):
        with patch('app.iap.routes._payments_enabled', return_value=True), \
             patch('app.iap.routes.verify_apple_receipt', return_value={'valid': False, 'error': 'bad', 'transactions': []}), \
             patch('app.iap.routes._reserve_transaction') as reserve:
            result = validate_paid_operation(
                receipt_data='nope',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_15',
                operation='activation',
                group_id='g1',
                user_id='u1',
            )
        assert result['valid'] is False
        reserve.assert_not_called()

    def test_rejects_already_used_transaction(self):
        apple = {
            'valid': True,
            'transactions': [{
                'product_id': 'com.adl.shareflow.tier_15',
                'transaction_id': 'T-USED',
            }],
        }
        with patch('app.iap.routes._payments_enabled', return_value=True), \
             patch('app.iap.routes.verify_apple_receipt', return_value=apple), \
             patch('app.iap.routes._reserve_transaction', return_value={'valid': False, 'error': 'העסקה כבר מומשה'}):
            result = validate_paid_operation(
                receipt_data='receipt',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_15',
                operation='activation',
                group_id='g1',
                user_id='u1',
            )
        assert result['valid'] is False
        assert 'כבר' in result['error']

    def test_ignores_client_product_id_argument_path(self):
        """Server expected ID is the only product that can match."""
        apple = {
            'valid': True,
            'transactions': [{
                'product_id': 'com.adl.shareflow.tier_5',
                'transaction_id': 'T-5',
            }],
        }
        with patch('app.iap.routes._payments_enabled', return_value=True), \
             patch('app.iap.routes.verify_apple_receipt', return_value=apple):
            result = validate_paid_operation(
                receipt_data='receipt',
                platform='ios',
                expected_product_id='com.adl.shareflow.tier_45',
                operation='activation',
                group_id='g1',
                user_id='u1',
            )
        assert result['valid'] is False


class TestReserveTransaction:
    def test_rejects_when_row_already_exists(self):
        with patch('app.iap.routes.IapProcessedTransaction') as model:
            model.query.filter_by.return_value.first.return_value = MagicMock()
            result = _reserve_transaction('T1', 'com.adl.shareflow.tier_15', 'ios', 'activation', 'g', 'u')
        assert result['valid'] is False

    def test_integrity_error_is_treated_as_replay(self):
        from sqlalchemy.exc import IntegrityError

        with patch('app.iap.routes.IapProcessedTransaction') as model, \
             patch('app.iap.routes.db') as mock_db:
            model.query.filter_by.return_value.first.return_value = None
            mock_db.session.flush.side_effect = IntegrityError('dup', None, None)
            result = _reserve_transaction('T1', 'com.adl.shareflow.tier_15', 'ios', 'activation', 'g', 'u')
        assert result['valid'] is False
        mock_db.session.rollback.assert_called()


class TestRequiredAmountUsesServerState:
    def test_activation_uses_member_count_from_query(self):
        group = MagicMock()
        group.id = 'g1'
        group.group_type = 'event'
        with patch('app.models.GroupMember') as gm:
            gm.query.filter_by.return_value.count.return_value = 4
            assert required_amount_ils(group, 'activation') == 15

    def test_upgrade_uses_snapshot_not_client(self):
        group = MagicMock()
        group.id = 'g1'
        group.group_type = 'ongoing'
        group.max_participants_snapshot = 5
        with patch('app.models.GroupMember') as gm:
            gm.query.filter_by.return_value.count.return_value = 12
            assert required_amount_ils(group, 'upgrade') == 40


class TestVerifyAppleReceiptEmpty:
    def test_empty_receipt_rejected(self):
        result = verify_apple_receipt('')
        assert result['valid'] is False
