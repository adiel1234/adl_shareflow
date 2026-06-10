"""Unit tests for activation expense split among group members."""
from decimal import Decimal
from unittest.mock import MagicMock, patch

from app.groups.internal_expense_service import (
    create_payment_expense,
    add_member_to_group_split_expenses,
    retroactively_add_member_to_expenses,
    _rebalance_equal_participants,
)


class TestCreatePaymentExpenseSplit:
    def test_split_among_group_includes_all_members(self):
        group = MagicMock()
        group.id = 'group-1'
        group.base_currency = 'ILS'

        members = [
            MagicMock(user_id='admin-1'),
            MagicMock(user_id='member-2'),
            MagicMock(user_id='member-3'),
        ]

        with patch('app.groups.internal_expense_service.db') as mock_db, \
             patch('app.groups.internal_expense_service.GroupMember') as mock_gm, \
             patch('app.groups.internal_expense_service._rebalance_equal_participants') as mock_rebalance:
            mock_gm.query.filter_by.return_value.order_by.return_value.all.return_value = members

            create_payment_expense(
                group,
                payer_id='admin-1',
                amount=Decimal('15'),
                source='activation',
                split_among_group=True,
            )

        mock_rebalance.assert_called_once()
        participant_ids = mock_rebalance.call_args[0][1]
        assert set(participant_ids) == {'admin-1', 'member-2', 'member-3'}

    def test_split_off_uses_payer_only(self):
        group = MagicMock()
        group.id = 'group-1'
        group.base_currency = 'ILS'

        with patch('app.groups.internal_expense_service.db') as mock_db, \
             patch('app.groups.internal_expense_service._rebalance_equal_participants') as mock_rebalance:
            create_payment_expense(
                group,
                payer_id='admin-1',
                amount=Decimal('15'),
                source='activation',
                split_among_group=False,
            )

        mock_rebalance.assert_called_once()
        assert mock_rebalance.call_args[0][1] == ['admin-1']


class TestAddMemberToSplitExpenses:
    def test_new_member_rebalances_system_expense(self):
        expense = MagicMock()
        expense.id = 'expense-1'
        expense.is_system_expense = True
        expense.participants = [MagicMock(user_id='admin-1')]

        payment = MagicMock()
        payment.expense_id = 'expense-1'

        with patch('app.groups.internal_expense_service.db') as mock_db, \
             patch('app.groups.internal_expense_service.GroupPayment') as mock_gp, \
             patch('app.groups.internal_expense_service._rebalance_equal_participants') as mock_rebalance:
            mock_gp.query.filter_by.return_value.filter.return_value.all.return_value = [payment]
            mock_db.session.get.return_value = expense

            add_member_to_group_split_expenses('group-1', 'member-2')

        mock_rebalance.assert_called_once()
        participant_ids = set(mock_rebalance.call_args[0][1])
        assert participant_ids == {'admin-1', 'member-2'}


class TestRetroactivelyAddMemberToExpenses:
    def test_adds_guest_to_each_existing_expense(self):
        expense_a = MagicMock()
        expense_a.participants = [MagicMock(user_id='admin-1')]
        expense_b = MagicMock()
        expense_b.participants = [
            MagicMock(user_id='admin-1'),
            MagicMock(user_id='member-2'),
        ]

        with patch('app.groups.internal_expense_service.db') as mock_db, \
             patch('app.groups.internal_expense_service.Expense') as mock_expense, \
             patch('app.groups.internal_expense_service._rebalance_equal_participants') as mock_rebalance:
            mock_expense.query.filter_by.return_value.all.return_value = [
                expense_a, expense_b,
            ]

            retroactively_add_member_to_expenses('group-1', 'guest-1')

        assert mock_rebalance.call_count == 2
        assert mock_rebalance.call_args_list[0][0][1] == ['admin-1', 'guest-1']
        assert set(mock_rebalance.call_args_list[1][0][1]) == {
            'admin-1', 'guest-1', 'member-2',
        }

    def test_skips_expense_when_guest_already_participant(self):
        expense = MagicMock()
        expense.participants = [
            MagicMock(user_id='admin-1'),
            MagicMock(user_id='guest-1'),
        ]

        with patch('app.groups.internal_expense_service.db'), \
             patch('app.groups.internal_expense_service.Expense') as mock_expense, \
             patch('app.groups.internal_expense_service._rebalance_equal_participants') as mock_rebalance:
            mock_expense.query.filter_by.return_value.all.return_value = [expense]

            retroactively_add_member_to_expenses('group-1', 'guest-1')

        mock_rebalance.assert_not_called()


class TestRebalanceEqualParticipants:
    def test_deletes_via_query_not_stale_relationship(self):
        expense = MagicMock()
        expense.id = 'expense-1'
        expense.converted_amount = Decimal('15.00')

        with patch('app.groups.internal_expense_service.db') as mock_db, \
             patch('app.groups.internal_expense_service.ExpenseParticipant') as mock_ep:
            _rebalance_equal_participants(expense, ['a', 'b', 'c'])

        mock_ep.query.filter_by.assert_called_once_with(expense_id='expense-1')
        mock_ep.query.filter_by.return_value.delete.assert_called_once_with(
            synchronize_session=False
        )
        assert mock_db.session.add.call_count == 3
