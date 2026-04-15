"""
GroupLifecycleService — evaluates and transitions group states.

State machine:
  FREE       → LIMITED  (3+ members OR 5+ days from creation)
  FREE       → ACTIVE   (on activation payment)
  LIMITED    → ACTIVE   (on activation payment)
  ACTIVE     → EXPIRED  (expiry_date passed, event groups)
  ACTIVE     → READ_ONLY (expiry_date passed, ongoing groups)
  EXPIRED    → ACTIVE   (extension payment)
  READ_ONLY  → ACTIVE   (renewal payment)
"""
from datetime import datetime, timezone, timedelta

# Free tier limits
FREE_MAX_MEMBERS = 3
FREE_MAX_DAYS = 5


class MonetizationConfig:
    """Single source of truth for all pricing."""

    # Event: (max_participants, price_ils, duration_days)
    # 3-6 members: 15 ILS | 7-10: 20 ILS | 11-15: 30 ILS | 16+: 40 ILS
    EVENT_TIERS = [
        (6,  15, 7),
        (10, 20, 7),
        (15, 30, 7),
        (999, 40, 7),  # 16+ — no upper cap
    ]
    EVENT_EXTENSION_PRICE = 15
    EVENT_EXTENSION_DAYS = 7

    # Ongoing: 10 ILS per member per month
    ONGOING_PRICE_PER_USER = 10
    ONGOING_DURATION_DAYS = 30

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
        amount = participant_count * cls.ONGOING_PRICE_PER_USER
        return {
            'amount': amount,
            'tier': f'{cls.ONGOING_PRICE_PER_USER}_per_user',
            'duration_days': cls.ONGOING_DURATION_DAYS,
        }

    @classmethod
    def resolve_price(cls, group_type: str, participant_count: int) -> dict | None:
        if group_type == 'event':
            return cls.resolve_event_price(participant_count)
        return cls.resolve_ongoing_price(participant_count)


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
