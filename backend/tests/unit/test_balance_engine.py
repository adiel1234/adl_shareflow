"""
Unit tests for the Balance Engine.

Tests run WITHOUT a database — we mock models directly.
"""
import pytest
from decimal import Decimal
from unittest.mock import MagicMock, patch

from app.balances.engine import (
    calculate_settlement_plan,
    calculate_group_balances,
    calculate_member_amounts_paid,
)


def _make_member(user_id, display_name):
    m = MagicMock()
    m.user_id = user_id
    m.user.display_name = display_name
    return m


def _make_expense(paid_by, converted_amount, participants, is_system_expense=False,
                  expense_source=None):
    e = MagicMock()
    e.paid_by = paid_by
    e.converted_amount = Decimal(str(converted_amount))
    e.participants = [_make_participant(uid, share) for uid, share in participants]
    e.is_system_expense = is_system_expense
    e.expense_source = expense_source
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
             patch('app.balances.engine.Expense') as MockExpense, \
             patch('app.balances.engine.Settlement') as MockSettlement:

            MockMember.query.filter_by.return_value.all.return_value = members
            MockExpense.query.filter_by.return_value.all.return_value = expenses
            MockSettlement.query.filter_by.return_value.all.return_value = []

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


class TestMemberAmountsPaid:
    """Stage 4: full amount paid per member, before split or settlement."""

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

    def _run_paid(self, members, expenses):
        with patch('app.balances.engine.GroupMember') as MockMember, \
             patch('app.balances.engine.Expense') as MockExpense:
            MockMember.query.filter_by.return_value.all.return_value = members
            MockExpense.query.filter_by.return_value.all.return_value = expenses
            return calculate_member_amounts_paid('group-1')

    def _run_balances(self, members, expenses, confirmed=None):
        with patch('app.balances.engine.GroupMember') as MockMember, \
             patch('app.balances.engine.Expense') as MockExpense, \
             patch('app.balances.engine.Settlement') as MockSettlement:
            MockMember.query.filter_by.return_value.all.return_value = members
            MockExpense.query.filter_by.return_value.all.return_value = expenses
            MockSettlement.query.filter_by.return_value.all.return_value = confirmed or []
            return calculate_group_balances('group-1')

    def test_one_payer_equal_split_is_full_amount_not_share(self, members):
        expenses = [
            _make_expense(self.ALICE, 300, [
                (self.ALICE, 100), (self.BOB, 100), (self.CAROL, 100),
            ])
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('300.00')
        assert paid[self.BOB] == Decimal('0.00')
        assert paid[self.CAROL] == Decimal('0.00')

    def test_multiple_payers(self, members):
        expenses = [
            _make_expense(self.ALICE, 300, [
                (self.ALICE, 100), (self.BOB, 100), (self.CAROL, 100),
            ]),
            _make_expense(self.BOB, 150, [
                (self.ALICE, 50), (self.BOB, 50), (self.CAROL, 50),
            ]),
            _make_expense(self.CAROL, 50, [
                (self.ALICE, 0), (self.BOB, 0), (self.CAROL, 50),
            ]),
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('300.00')
        assert paid[self.BOB] == Decimal('150.00')
        assert paid[self.CAROL] == Decimal('50.00')

    def test_custom_exact_split_still_uses_full_paid_amount(self, members):
        expenses = [
            _make_expense(self.ALICE, 300, [
                (self.ALICE, 50), (self.BOB, 200), (self.CAROL, 50),
            ])
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('300.00')
        assert paid[self.BOB] == Decimal('0.00')

    def test_percentage_split_still_uses_full_paid_amount(self, members):
        expenses = [
            _make_expense(self.ALICE, 200, [
                (self.ALICE, 100), (self.BOB, 60), (self.CAROL, 40),
            ])
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('200.00')
        assert paid[self.BOB] == Decimal('0.00')
        assert paid[self.CAROL] == Decimal('0.00')

    def test_payer_not_in_split(self, members):
        expenses = [
            _make_expense(self.ALICE, 300, [
                (self.BOB, 150), (self.CAROL, 150),
            ])
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('300.00')
        assert paid[self.BOB] == Decimal('0.00')
        assert paid[self.CAROL] == Decimal('0.00')

    def test_member_with_zero_paid_expenses(self, members):
        expenses = [
            _make_expense(self.ALICE, 90, [
                (self.ALICE, 30), (self.BOB, 30), (self.CAROL, 30),
            ])
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.CAROL] == Decimal('0.00')

    def test_edited_expense_uses_current_amount(self, members):
        expenses = [
            _make_expense(self.ALICE, 450, [
                (self.ALICE, 150), (self.BOB, 150), (self.CAROL, 150),
            ])
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('450.00')

    def test_deleted_expense_absent_from_query(self, members):
        remaining = [
            _make_expense(self.BOB, 80, [
                (self.ALICE, 40), (self.BOB, 40),
            ])
        ]
        paid = self._run_paid(members, remaining)
        assert paid[self.ALICE] == Decimal('0.00')
        assert paid[self.BOB] == Decimal('80.00')
        assert paid[self.CAROL] == Decimal('0.00')

    def test_multiple_expenses_same_member(self, members):
        expenses = [
            _make_expense(self.ALICE, 100, [
                (self.ALICE, 50), (self.BOB, 50),
            ]),
            _make_expense(self.ALICE, 40, [
                (self.ALICE, 20), (self.CAROL, 20),
            ]),
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('140.00')

    def test_uses_converted_group_currency_amount(self, members):
        expenses = [
            _make_expense(self.ALICE, 370.50, [
                (self.ALICE, 123.50), (self.BOB, 123.50), (self.CAROL, 123.50),
            ])
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('370.50')

    def test_historical_group_no_date_filter(self, members):
        expenses = [
            _make_expense(self.ALICE, 10, [(self.ALICE, 10)]),
            _make_expense(self.BOB, 20, [(self.BOB, 20)]),
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('10.00')
        assert paid[self.BOB] == Decimal('20.00')
        assert paid[self.CAROL] == Decimal('0.00')

    def test_approved_settlement_does_not_change_amounts_paid(self, members):
        expenses = [
            _make_expense(self.ALICE, 300, [
                (self.ALICE, 100), (self.BOB, 100), (self.CAROL, 100),
            ])
        ]
        settlement = MagicMock()
        settlement.from_user_id = self.CAROL
        settlement.to_user_id = self.ALICE
        settlement.amount = Decimal('100')

        paid = self._run_paid(members, expenses)
        balances = self._run_balances(members, expenses, confirmed=[settlement])

        assert paid[self.ALICE] == Decimal('300.00')
        assert paid[self.BOB] == Decimal('0.00')
        assert paid[self.CAROL] == Decimal('0.00')

        by_id = {b.user_id: b for b in balances}
        # Engine total_paid includes Carol's confirmed settlement; amounts_paid does not.
        assert by_id[self.ALICE].net_amount == Decimal('100.00')
        assert by_id[self.ALICE].total_paid == Decimal('300.00')
        assert by_id[self.CAROL].total_paid == Decimal('100.00')
        assert by_id[self.CAROL].net_amount == Decimal('0.00')
        assert by_id[self.BOB].net_amount == Decimal('-100.00')

    def test_settlement_plan_unchanged_by_paid_helper(self, members):
        expenses = [
            _make_expense(self.ALICE, 300, [
                (self.ALICE, 100), (self.BOB, 100), (self.CAROL, 100),
            ])
        ]
        with patch('app.balances.engine.GroupMember') as MockMember, \
             patch('app.balances.engine.Expense') as MockExpense, \
             patch('app.balances.engine.Settlement') as MockSettlement:
            MockMember.query.filter_by.return_value.all.return_value = members
            MockExpense.query.filter_by.return_value.all.return_value = expenses
            MockSettlement.query.filter_by.return_value.all.return_value = []
            before = calculate_settlement_plan('group-1', 'ILS')
            paid = calculate_member_amounts_paid('group-1')
            after = calculate_settlement_plan('group-1', 'ILS')

        assert paid[self.ALICE] == Decimal('300.00')
        assert len(before) == len(after) == 2
        assert {(s.from_user_id, s.to_user_id, s.amount) for s in before} == {
            (s.from_user_id, s.to_user_id, s.amount) for s in after
        }
        for s in after:
            assert s.to_user_id == self.ALICE
            assert s.amount == Decimal('100.00')

    def test_system_monetization_expenses_are_excluded(self, members):
        expenses = [
            _make_expense(self.ALICE, 300, [
                (self.ALICE, 100), (self.BOB, 100), (self.CAROL, 100),
            ]),
            _make_expense(
                self.ALICE, 49, [(self.ALICE, 49)],
                is_system_expense=True, expense_source='activation',
            ),
            _make_expense(
                self.ALICE, 15, [(self.ALICE, 15)],
                is_system_expense=True, expense_source='extension',
            ),
            _make_expense(
                self.BOB, 69, [(self.BOB, 69)],
                is_system_expense=True, expense_source='renewal',
            ),
            _make_expense(
                self.CAROL, 40, [(self.CAROL, 40)],
                is_system_expense=True, expense_source='upgrade',
            ),
        ]
        paid = self._run_paid(members, expenses)
        assert paid[self.ALICE] == Decimal('300.00')
        assert paid[self.BOB] == Decimal('0.00')
        assert paid[self.CAROL] == Decimal('0.00')

        balances = self._run_balances(members, expenses)
        by_id = {b.user_id: b for b in balances}
        assert by_id[self.ALICE].total_paid == Decimal('364.00')

    def test_former_member_payer_included(self, members):
        departed = 'user-dana'
        expenses = [
            _make_expense(departed, 75, [
                (self.ALICE, 25), (self.BOB, 25), (self.CAROL, 25),
            ])
        ]
        paid = self._run_paid(members, expenses)
        assert paid[departed] == Decimal('75.00')
        assert paid[self.ALICE] == Decimal('0.00')
