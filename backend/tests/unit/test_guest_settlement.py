"""Unit tests for guest→member settlement flow."""
from decimal import Decimal
from unittest.mock import MagicMock, patch

from app.balances.engine import calculate_settlement_plan
from app.settlements.routes import _can_confirm_settlement


class TestGuestSettlementPermissions:
    def test_creditor_can_confirm_guest_to_member(self):
        settlement = MagicMock()
        settlement.to_user_id = 'member-1'
        settlement.group_id = 'group-1'
        assert _can_confirm_settlement(settlement, 'member-1') is True

    def test_admin_can_confirm_guest_creditor(self):
        settlement = MagicMock()
        settlement.to_user_id = 'guest-creditor'
        settlement.group_id = 'group-1'

        guest_user = MagicMock()
        guest_user.is_guest = True

        admin_member = MagicMock()
        admin_member.role = 'admin'

        with patch('app.settlements.routes.db') as mock_db, \
             patch('app.settlements.routes.GroupMember') as mock_gm:
            mock_db.session.get.return_value = guest_user
            mock_gm.query.filter_by.return_value.first.return_value = admin_member
            assert _can_confirm_settlement(settlement, 'admin-1') is True

    def test_random_member_cannot_confirm_for_other_creditor(self):
        settlement = MagicMock()
        settlement.to_user_id = 'member-1'
        settlement.group_id = 'group-1'
        assert _can_confirm_settlement(settlement, 'member-2') is False

    def test_creditor_confirm_flag_for_guest_to_member(self):
        """Creditor (non-guest payee) should get is_creditor_confirm semantics."""
        settlement = MagicMock()
        settlement.to_user_id = 'member-1'
        settlement.from_user_id = 'guest-1'
        settlement.group_id = 'group-1'

        assert _can_confirm_settlement(settlement, 'member-1') is True
        assert settlement.to_user_id == 'member-1'


class TestSettlementPlanPendingAdjustment:
    def test_pending_settlement_reduces_open_debt_in_plan(self):
        """Pending guest→member payment should not duplicate in settlement plan."""
        from app.models import Settlement

        balances = [
            MagicMock(
                user_id='guest-1',
                display_name='Guest',
                net_amount=Decimal('-50'),
                is_former_member=False,
            ),
            MagicMock(
                user_id='member-1',
                display_name='Member',
                net_amount=Decimal('50'),
                is_former_member=False,
            ),
        ]

        pending = [
            MagicMock(
                from_user_id='guest-1',
                to_user_id='member-1',
                amount=Decimal('50'),
            ),
        ]

        with patch('app.balances.engine.calculate_group_balances', return_value=balances), \
             patch.object(Settlement, 'query') as mock_query:
            mock_query.filter_by.return_value.all.return_value = pending
            suggestions = calculate_settlement_plan('group-1', 'ILS')

        assert suggestions == []
