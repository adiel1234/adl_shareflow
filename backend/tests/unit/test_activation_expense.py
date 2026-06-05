"""Unit tests for activation expense creation."""
from decimal import Decimal
from unittest.mock import MagicMock, patch

from app.groups.monetization_service import _record_platform_payment


class TestActivationExpense:
    def test_always_creates_expense_when_payments_disabled(self):
        group = MagicMock()
        group.id = 'group-1'
        group.base_currency = 'ILS'

        expense = MagicMock()
        expense.id = 'expense-1'

        with patch('app.groups.monetization_service.create_payment_expense', return_value=expense) as mock_create, \
             patch('app.groups.monetization_service._payments_enabled', return_value=False), \
             patch('app.groups.monetization_service.db') as mock_db:
            _record_platform_payment(
                group,
                payer_id='admin-1',
                amount=Decimal('15'),
                payment_type='activation',
                source='activation',
                split_among_group=True,
            )

        mock_create.assert_called_once()
        assert mock_create.call_args.kwargs['split_among_group'] is True
        assert mock_create.call_args.kwargs['amount'] == Decimal('15')
        mock_db.session.add.assert_called_once()
        payment = mock_db.session.add.call_args[0][0]
        assert payment.amount == Decimal('0')
        assert payment.split_among_group is True
        assert payment.expense_id == 'expense-1'
