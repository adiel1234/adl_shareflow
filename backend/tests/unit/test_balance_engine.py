"""
Unit tests for the Balance Engine.

Tests run WITHOUT a database — we mock models directly.
"""
import pytest
from decimal import Decimal
from unittest.mock import MagicMock, patch

from app.balances.engine import calculate_settlement_plan, calculate_group_balances


def _make_member(user_id, display_name):
    m = MagicMock()
    m.user_id = user_id
    m.user.display_name = display_name
    return m


def _make_expense(paid_by, converted_amount, participants):
    e = MagicMock()
    e.paid_by = paid_by
    e.converted_amount = Decimal(str(converted_amount))
    e.participants = [_make_participant(uid, share) for uid, share in participants]
    return e


def _make_participant(user_id, share_amount):
    p = MagicMock()
    p.user_id = user_id
    p.share_amount = Decimal(str(share_amount))
    return p


class TestBalanceEngine:
    """Three users: Alice, Bob, Carol."""

    ALICE = 'user-alice'
    BOB = 'user-bob'
    CAROL = 'user-carol'

    @pytest.fixture
    def members(self):
        return [
            _make_member(self.ALICE, 'Alice'),
            _make_member(self.BOB, 'Bob'),
            _make_member(self.CAROL, 'Carol'),
        ]

    def _run_plan(self, members, expenses):
        """Patches DB queries and runs the settlement plan."""
        with patch('app.balances.engine.GroupMember') as MockMember, \
             patch('app.balances.engine.Expense') as MockExpense:

            MockMember.query.filter_by.return_value.all.return_value = members
            MockExpense.query.filter_by.return_value.all.return_value = expenses

            suggestions = calculate_settlement_plan('group-1', 'ILS')
            return suggestions

    def test_equal_three_way_split(self, members):
        """Alice pays 300, split equally → Bob and Carol each owe 100."""
        expenses = [
            _make_expense(self.ALICE, 300, [
                (self.ALICE, 100),
                (self.BOB, 100),
                (self.CAROL, 100),
            ])
        ]
        suggestions = self._run_plan(members, expenses)

        assert len(suggestions) == 2
        payers = {s.from_user_id for s in suggestions}
        assert payers == {self.BOB, self.CAROL}
        for s in suggestions:
            assert s.to_user_id == self.ALICE
            assert s.amount == Decimal('100.00')

    def test_already_settled(self, members):
        """Everyone pays their own share — no settlements needed."""
        expenses = [
            _make_expense(self.ALICE, 100, [(self.ALICE, 100)]),
            _make_expense(self.BOB, 100, [(self.BOB, 100)]),
            _make_expense(self.CAROL, 100, [(self.CAROL, 100)]),
        ]
        suggestions = self._run_plan(members, expenses)
        assert suggestions == []

    def test_minimum_transactions(self, members):
        """
        Alice paid 200, Bob paid 100, Carol paid 0. Split equally (100 each).
        Net: Alice +100, Bob 0, Carol -100.
        → 1 transaction: Carol → Alice 100
        """
        expenses = [
            _make_expense(self.ALICE, 200, [
                (self.ALICE, 100), (self.BOB, 50), (self.CAROL, 50),
            ]),
            _make_expense(self.BOB, 100, [
                (self.ALICE, 0), (self.BOB, 50), (self.CAROL, 50),
            ]),
        ]
        suggestions = self._run_plan(members, expenses)
        assert len(suggestions) == 1
        assert suggestions[0].from_user_id == self.CAROL
        assert suggestions[0].to_user_id == self.ALICE
        assert suggestions[0].amount == Decimal('100.00')

    def test_complex_multi_transfer(self, members):
        """
        Alice paid 600 (owes 200 herself), Bob paid 0, Carol paid 0.
        Net: Alice +400, Bob -200, Carol -200.
        → 2 transactions minimum.
        """
        expenses = [
            _make_expense(self.ALICE, 600, [
                (self.ALICE, 200), (self.BOB, 200), (self.CAROL, 200),
            ])
        ]
        suggestions = self._run_plan(members, expenses)
        assert len(suggestions) == 2
        for s in suggestions:
            assert s.to_user_id == self.ALICE
            assert s.amount == Decimal('200.00')

    def test_zero_amount_expense(self, members):
        """Zero amount expense produces no settlements."""
        expenses = [
            _make_expense(self.ALICE, 0, [
                (self.ALICE, 0), (self.BOB, 0), (self.CAROL, 0),
            ])
        ]
        suggestions = self._run_plan(members, expenses)
        assert suggestions == []

    def test_no_expenses(self, members):
        """No expenses → no settlements."""
        suggestions = self._run_plan(members, [])
        assert suggestions == []

    def test_two_users_simple(self):
        """Alice paid 100 for Bob. Bob owes Alice 50 (split equally)."""
        members = [
            _make_member('alice', 'Alice'),
            _make_member('bob', 'Bob'),
        ]
        expenses = [
            _make_expense('alice', 100, [('alice', 50), ('bob', 50)])
        ]
        suggestions = self._run_plan(members, expenses)
        assert len(suggestions) == 1
        assert suggestions[0].from_user_id == 'bob'
        assert suggestions[0].to_user_id == 'alice'
        assert suggestions[0].amount == Decimal('50.00')
