"""
GroupLifecycleService — evaluates and transitions group states.

State machine:
  FREE       → LIMITED  (7+ members OR 7+ days from creation)
  FREE       → ACTIVE   (on activation payment)
  LIMITED    → ACTIVE   (on activation payment)
  ACTIVE     → EXPIRED  (expiry_date passed, event groups)
  ACTIVE     → READ_ONLY (expiry_date passed, ongoing groups)
  EXPIRED    → ACTIVE   (extension payment)
  READ_ONLY  → ACTIVE   (renewal payment)
"""
from datetime import datetime, timezone, timedelta

# Free tier limits: up to 7 members, 7 days per group, max 3 free groups per user
FREE_MAX_MEMBERS = 7
FREE_MAX_DAYS = 7


class MonetizationConfig:
    """Single source of truth for all pricing.

    Event tiers (max_participants, price_ils, duration_days):
      ≤5  → 15 ILS / 7 days
      ≤10 → 20 ILS / 7 days
      ≤15 → 30 ILS / 7 days
      ≤39 → 35 ILS / 7 days
      40+ → 45 ILS / 7 days

    Ongoing tiers (max_participants, price_ils, duration_days):
      ≤5  → 49 ILS / 30 days
      ≤8  → 69 ILS / 30 days
      ≤11 → 79 ILS / 30 days
      12+ → 89 ILS / 30 days
    """

    # Event: (max_participants, price_ils, duration_days)
    EVENT_TIERS = [
        (5,   15, 7),
        (10,  20, 7),
        (15,  30, 7),
        (39,  35, 7),
        (999, 45, 7),
    ]
    EVENT_EXTENSION_PRICE = 15
    EVENT_EXTENSION_DAYS = 7

    # Ongoing: fixed tiers by participant count
    ONGOING_TIERS = [
        (5,   49, 30),
        (8,   69, 30),
        (11,  79, 30),
        (999, 89, 30),
    ]

    @classmethod
    def resolve_event_price(cls, participant_count: int) -> dict | None:
        for max_p, price, days in cls.EVENT_TIERS:
            if participant_count <= max_p:
                return {'amount': price, 'tier': str(price), 'duration_days': days}
        return None

    @classmethod
    def resolve_ongoing_price(cls, participant_count: int) -> dict | None:
        if participant_count < 1:
            return None
        for max_p, price, days in cls.ONGOING_TIERS:
            if participant_count <= max_p:
                return {'amount': price, 'tier': str(price), 'duration_days': days}
        return None

    @classmethod
    def resolve_price(cls, group_type: str, participant_count: int) -> dict | None:
        if group_type == 'event':
            return cls.resolve_event_price(participant_count)
        return cls.resolve_ongoing_price(participant_count)


def check_tier_upgrade(group_type: str, current_count: int, snapshot: int | None) -> dict | None:
    """
    Returns upgrade info if current_count has crossed into a more expensive tier
    compared to the snapshot count at last activation/upgrade.
    Returns None if no upgrade is needed.
    """
    if not snapshot or current_count <= snapshot:
        return None
    new_pricing = MonetizationConfig.resolve_price(group_type, current_count)
    old_pricing = MonetizationConfig.resolve_price(group_type, snapshot)
    if not new_pricing or not old_pricing:
        return None
    if new_pricing['amount'] <= old_pricing['amount']:
        return None
    diff = new_pricing['amount'] - old_pricing['amount']
    return {
        'tier_upgrade_required': True,
        'upgrade_price_diff': diff,
        'upgrade_new_price': new_pricing['amount'],
        'upgrade_new_tier': new_pricing['tier'],
    }


class GroupLifecycleService:

    @staticmethod
    def evaluate_state(group) -> str:
        """
        Compute the correct state for a group without mutating it.
        Returns the new state string.
        """
        now = datetime.now(timezone.utc)

        # Already explicitly closed — treat as read_only
        if group.is_closed:
            return 'read_only'

        current = group.group_state

        # Active group: check if expiry passed
        if current == 'active':
            if group.expiry_date:
                exp = group.expiry_date
                if exp.tzinfo is None:
                    exp = exp.replace(tzinfo=timezone.utc)
                if now > exp:
                    return 'expired' if group.group_type == 'event' else 'read_only'
            return 'active'

        # Free group: check if limits hit
        if current == 'free':
            member_count = len(group.members)
            age_days = (now - group.created_at.replace(tzinfo=timezone.utc)).days
            if member_count > FREE_MAX_MEMBERS or age_days >= FREE_MAX_DAYS:
                return 'limited'
            return 'free'

        # Other states are sticky (limited, expired, read_only) until payment
        return current

    @staticmethod
    def sync_state(group, db_session) -> bool:
        """
        Evaluate and persist state if it has changed.
        Returns True if state was updated.
        """
        new_state = GroupLifecycleService.evaluate_state(group)
        if new_state != group.group_state:
            group.group_state = new_state
            db_session.add(group)
            return True
        return False

    @staticmethod
    def is_operational(group) -> bool:
        """Returns True when write operations are allowed."""
        state = GroupLifecycleService.evaluate_state(group)
        return state in ('free', 'active')
