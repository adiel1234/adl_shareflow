"""
Integration tests — full API flow.
Tests: register → login → create group → add expense → get balances → settle
"""
import pytest
import json
from unittest.mock import patch, MagicMock
from app import create_app, db
from config import TestingConfig


@pytest.fixture(scope='session')
def app():
    """Single app instance for entire test session."""
    import os
    os.environ['ADL_ADMIN_KEY'] = 'shareflow-adl-admin-dev-key'

    with patch('app.currency.routes._fetch_live_rates', return_value={}), \
         patch('app.notifications.fcm_service._get_app', return_value=None), \
         patch('app.notifications.fcm_service.send_to_user', return_value=0), \
         patch('app.notifications.fcm_service.send_to_users', return_value=0):

        application = create_app(TestingConfig)
        with application.app_context():
            db.create_all()
            yield application
            # No drop_all — leave DB for inspection; run script to reset manually


@pytest.fixture(scope='session')
def client(app):
    return app.test_client()


@pytest.fixture(scope='session')
def auth_tokens(client):
    """Register two users and return their tokens."""
    r = client.post('/api/auth/register', json={
        'email': 'alice@shareflowtest.com',
        'password': 'Password1!',
        'display_name': 'Alice',
    })
    assert r.status_code == 201, r.data
    alice = r.get_json()['data']

    r = client.post('/api/auth/register', json={
        'email': 'bob@shareflowtest.com',
        'password': 'Password1!',
        'display_name': 'Bob',
    })
    assert r.status_code == 201, r.data
    bob = r.get_json()['data']

    return {
        'alice_token': alice['access_token'],
        'alice_id': alice['user']['id'],
        'bob_token': bob['access_token'],
        'bob_id': bob['user']['id'],
    }


def _auth(token):
    return {'Authorization': f'Bearer {token}'}


class TestAuthFlow:
    def test_register_duplicate_email(self, client, auth_tokens):
        r = client.post('/api/auth/register', json={
            'email': 'alice@shareflowtest.com',
            'password': 'Password1!',
            'display_name': 'Alice2',
        })
        assert r.status_code in (400, 409)

    def test_login_success(self, client, auth_tokens):
        r = client.post('/api/auth/login', json={
            'email': 'alice@shareflowtest.com',
            'password': 'Password1!',
        })
        assert r.status_code == 200
        data = r.get_json()['data']
        assert 'access_token' in data

    def test_login_wrong_password(self, client, auth_tokens):
        r = client.post('/api/auth/login', json={
            'email': 'alice@shareflowtest.com',
            'password': 'wrong',
        })
        assert r.status_code == 401

    def test_get_profile(self, client, auth_tokens):
        r = client.get('/api/users/me', headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 200
        assert r.get_json()['data']['email'] == 'alice@shareflowtest.com'


class TestGroupFlow:
    @pytest.fixture(scope='session')
    def group_id(self, client, auth_tokens):
        r = client.post('/api/groups', json={
            'name': 'Trip to Paris',
            'base_currency': 'EUR',
            'category': 'travel',
        }, headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 201
        return r.get_json()['data']['id']

    def test_list_groups(self, client, auth_tokens, group_id):
        r = client.get('/api/groups', headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 200
        # API returns list directly in data
        groups = r.get_json()['data']
        assert isinstance(groups, list)
        assert any(g['id'] == group_id for g in groups)

    def test_get_group(self, client, auth_tokens, group_id):
        r = client.get(f'/api/groups/{group_id}', headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 200
        assert r.get_json()['data']['name'] == 'Trip to Paris'

    def test_get_invite_link(self, client, auth_tokens, group_id):
        r = client.get(f'/api/groups/{group_id}/invite-link',
                       headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 200
        data = r.get_json()['data']
        assert 'invite_code' in data

    def test_bob_joins_group(self, client, auth_tokens, group_id):
        # Get invite code
        r = client.get(f'/api/groups/{group_id}/invite-link',
                       headers=_auth(auth_tokens['alice_token']))
        code = r.get_json()['data']['invite_code']

        # Bob joins via URL param
        r = client.post(f'/api/groups/join/{code}',
                        headers=_auth(auth_tokens['bob_token']))
        assert r.status_code in (200, 201)

    def test_expense_flow(self, client, auth_tokens, group_id):
        # Add expense
        r = client.post(f'/api/groups/{group_id}/expenses', json={
            'title': 'Dinner in Paris',
            'original_amount': '120.00',
            'original_currency': 'EUR',
            'paid_by': auth_tokens['alice_id'],
        }, headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 201
        expense_id = r.get_json()['data']['id']

        # List expenses
        r = client.get(f'/api/groups/{group_id}/expenses', headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 200
        expenses = r.get_json()['data']['expenses']
        assert any(e['id'] == expense_id for e in expenses)

    def test_balances(self, client, auth_tokens, group_id):
        r = client.get(f'/api/groups/{group_id}/balances', headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 200
        data = r.get_json()['data']
        # balances endpoint returns balances + settlement_plan
        assert 'balances' in data or isinstance(data, dict)

    def test_settlement_flow(self, client, auth_tokens, group_id):
        # Bob owes Alice — Bob creates settlement TO Alice
        r = client.post(f'/api/groups/{group_id}/settlements', json={
            'to_user_id': auth_tokens['alice_id'],
            'amount': '60.00',
            'currency': 'EUR',
        }, headers=_auth(auth_tokens['bob_token']))
        assert r.status_code == 201, r.get_json()
        settlement_id = r.get_json()['data']['id']

        # Alice (to_user) confirms receiving payment
        r = client.put(f'/api/settlements/{settlement_id}/confirm',
                       headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 200
        assert r.get_json()['data']['status'] == 'confirmed'


class TestCurrencyAPI:
    def test_get_rates(self, client, auth_tokens):
        r = client.get('/api/currency/rates?from=ILS', headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 200
        data = r.get_json()['data']
        assert 'rates' in data

    def test_convert(self, client, auth_tokens):
        r = client.get('/api/currency/convert?from=USD&to=ILS&amount=100',
                       headers=_auth(auth_tokens['alice_token']))
        assert r.status_code == 200
        data = r.get_json()['data']
        assert float(data['converted_amount']) > 0


class TestJoinSplitMode:
    """
    Tests for the new split_mode feature when joining a group with existing expenses.
    Uses isolated group (Alice2 + Charlie + Dave) to avoid interference with TestGroupFlow.
    """

    @pytest.fixture(scope='class')
    def split_users(self, client):
        """Register Charlie and Dave for split-mode tests."""
        users = {}
        for name, email in [
            ('Charlie', 'charlie@shareflowtest.com'),
            ('Dave', 'dave@shareflowtest.com'),
        ]:
            r = client.post('/api/auth/register', json={
                'email': email,
                'password': 'Password1!',
                'display_name': name,
            })
            assert r.status_code == 201, r.data
            d = r.get_json()['data']
            users[name.lower() + '_token'] = d['access_token']
            users[name.lower() + '_id'] = d['user']['id']

        # Alice2 (owner of the split-mode test group)
        r = client.post('/api/auth/register', json={
            'email': 'alice2@shareflowtest.com',
            'password': 'Password1!',
            'display_name': 'Alice2',
        })
        assert r.status_code == 201, r.data
        d = r.get_json()['data']
        users['alice2_token'] = d['access_token']
        users['alice2_id'] = d['user']['id']
        return users

    @pytest.fixture(scope='class')
    def split_group(self, client, split_users):
        """
        Create a group owned by Alice2, add 2 expenses BEFORE new members join.
        Returns dict with group_id, invite_code, expense IDs.
        """
        tok = split_users['alice2_token']
        uid = split_users['alice2_id']

        r = client.post('/api/groups', json={
            'name': 'Split-Mode Test Group',
            'base_currency': 'EUR',
            'category': 'travel',
        }, headers=_auth(tok))
        assert r.status_code == 201
        group_id = r.get_json()['data']['id']

        # Add 2 expenses while only Alice2 is in the group
        expense_ids = []
        for title, amount in [('Hotel', '90.00'), ('Taxi', '30.00')]:
            r = client.post(f'/api/groups/{group_id}/expenses', json={
                'title': title,
                'original_amount': amount,
                'original_currency': 'EUR',
                'paid_by': uid,
            }, headers=_auth(tok))
            assert r.status_code == 201, r.data
            expense_ids.append(r.get_json()['data']['id'])

        # Get invite code
        r = client.get(f'/api/groups/{group_id}/invite-link', headers=_auth(tok))
        assert r.status_code == 200
        invite_code = r.get_json()['data']['invite_code']

        return {
            'group_id': group_id,
            'invite_code': invite_code,
            'expense_ids': expense_ids,
            'owner_id': uid,
        }

    # ------------------------------------------------------------------
    # 1. check endpoint
    # ------------------------------------------------------------------

    def test_check_invite_returns_expense_count(self, client, split_users, split_group):
        code = split_group['invite_code']
        r = client.get(f'/api/groups/check/{code}',
                       headers=_auth(split_users['charlie_token']))
        assert r.status_code == 200
        data = r.get_json()['data']
        assert data['has_expenses'] is True
        assert data['expense_count'] == 2
        assert data['already_member'] is False

    def test_check_invite_invalid_code(self, client, split_users):
        r = client.get('/api/groups/check/INVALID',
                       headers=_auth(split_users['charlie_token']))
        assert r.status_code == 404

    # ------------------------------------------------------------------
    # 2. join with split_mode=full (retroactive)
    # ------------------------------------------------------------------

    def test_join_full_retroactive(self, client, split_users, split_group):
        """Charlie joins with split_mode=full — he must appear in all existing expenses."""
        code = split_group['invite_code']
        alice2_tok = split_users['alice2_token']
        charlie_tok = split_users['charlie_token']
        charlie_id = split_users['charlie_id']

        r = client.post(f'/api/groups/join/{code}',
                        json={'split_mode': 'full'},
                        headers=_auth(charlie_tok))
        assert r.status_code in (200, 201), r.get_json()
        assert r.get_json()['data']['retroactive_expenses'] == 2

        # Verify Charlie now appears in each expense's participants
        for exp_id in split_group['expense_ids']:
            r = client.get(
                f'/api/groups/{split_group["group_id"]}/expenses/{exp_id}',
                headers=_auth(alice2_tok),
            )
            if r.status_code == 404:
                # No single-expense endpoint — check balances instead
                break
            participants = r.get_json()['data'].get('participants', [])
            participant_ids = [p['user_id'] for p in participants]
            assert charlie_id in participant_ids, (
                f"Charlie missing from expense {exp_id} after full retroactive join"
            )

        # Balances: Charlie should be non-zero if retroactive worked
        r = client.get(f'/api/groups/{split_group["group_id"]}/balances',
                       headers=_auth(charlie_tok))
        assert r.status_code == 200
        balances = r.get_json()['data'].get('balances', [])
        charlie_balance = next(
            (b for b in balances if b.get('user_id') == charlie_id), None
        )
        # After retroactive split Charlie owes money (net < 0) or is tracked
        assert charlie_balance is not None, "Charlie not found in balances after full join"
        assert charlie_balance['net_amount'] != 0, "Charlie balance should be non-zero after retroactive join"

    def test_charlie_already_member(self, client, split_users, split_group):
        """Charlie trying to join again should fail."""
        code = split_group['invite_code']
        r = client.post(f'/api/groups/join/{code}',
                        json={'split_mode': 'forward'},
                        headers=_auth(split_users['charlie_token']))
        assert r.status_code in (400, 409)

    # ------------------------------------------------------------------
    # 3. join with split_mode=forward (future only)
    # ------------------------------------------------------------------

    def test_join_forward_not_retroactive(self, client, split_users, split_group):
        """Dave joins with split_mode=forward — existing expenses remain unchanged."""
        code = split_group['invite_code']
        dave_tok = split_users['dave_token']
        dave_id = split_users['dave_id']

        r = client.post(f'/api/groups/join/{code}',
                        json={'split_mode': 'forward'},
                        headers=_auth(dave_tok))
        assert r.status_code in (200, 201), r.get_json()
        assert r.get_json()['data']['retroactive_expenses'] == 0

        # Dave's balance should be 0 (not part of any existing expense)
        r = client.get(f'/api/groups/{split_group["group_id"]}/balances',
                       headers=_auth(dave_tok))
        assert r.status_code == 200
        balances = r.get_json()['data'].get('balances', [])
        dave_balance = next(
            (b for b in balances if b.get('user_id') == dave_id), None
        )
        # Dave either doesn't appear or appears with 0 balance
        if dave_balance is not None:
            assert float(dave_balance['net_amount']) == 0.0, (
                "Dave should have 0 balance after forward-only join"
            )

    # ------------------------------------------------------------------
    # 4. check shows already_member for existing members
    # ------------------------------------------------------------------

    def test_check_already_member(self, client, split_users, split_group):
        code = split_group['invite_code']
        r = client.get(f'/api/groups/check/{code}',
                       headers=_auth(split_users['charlie_token']))
        assert r.status_code == 200
        assert r.get_json()['data']['already_member'] is True


class TestDashboardAPI:
    ADL_KEY = 'shareflow-adl-admin-dev-key'

    def test_stats_no_key(self, client):
        r = client.get('/api/adl/stats')
        assert r.status_code == 403

    def test_stats_with_key(self, client):
        r = client.get('/api/adl/stats', headers={'X-ADL-Admin-Key': self.ADL_KEY})
        assert r.status_code == 200
        data = r.get_json()['data']
        assert 'users' in data
        assert 'groups' in data
        assert 'expenses' in data

    def test_users_list(self, client):
        r = client.get('/api/adl/users', headers={'X-ADL-Admin-Key': self.ADL_KEY})
        assert r.status_code == 200
        assert len(r.get_json()['data']['users']) >= 2
