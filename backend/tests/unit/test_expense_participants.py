"""Tests for expense participant share assignment on create."""
from decimal import Decimal

from app.expenses.routes import (
    _equal_participant_shares,
    _participants_have_explicit_shares,
)


class TestEqualParticipantShares:
    def test_splits_800_between_two(self):
        shares = _equal_participant_shares(Decimal('800'), 2)
        assert sum(shares) == Decimal('800')
        assert shares == [Decimal('400.00'), Decimal('400.00')]


class TestExplicitSharesDetection:
    def test_user_ids_only_not_explicit(self):
        data = [{'user_id': 'a'}, {'user_id': 'b'}]
        assert _participants_have_explicit_shares(data) is False

    def test_with_amounts_is_explicit(self):
        data = [{'user_id': 'a', 'share_amount': '300'}]
        assert _participants_have_explicit_shares(data) is True


class TestCreatePathUsesEqualSplit:
    """Mobile sends participants with user_id only — create must equal-split."""

    def test_two_user_ids_get_400_each_from_800(self):
        shares = _equal_participant_shares(Decimal('800'), 2)
        assert shares == [Decimal('400.00'), Decimal('400.00')]
        assert not _participants_have_explicit_shares(
            [{'user_id': 'u1'}, {'user_id': 'u2'}]
        )
