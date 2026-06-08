"""
MonetizationService - handles group activation, extension, and renewal.

Activation always records a group expense so balances reflect the admin's
split choice (among all members vs payer alone). Real payment gateway charges
only when PAYMENTS_ENABLED is true in feature_flags.
"""
from datetime import datetime, timezone, timedelta
from decimal import Decimal

from app import db
from app.models import GroupMember, GroupPayment, FeatureFlag
from app.groups.lifecycle_service import MonetizationConfig, check_tier_upgrade
from app.groups.internal_expense_service import create_payment_expense
from app.notifications import service as notif_service


def _payments_enabled() -> bool:
    """Returns True only when PAYMENTS_ENABLED flag is explicitly set to true."""
    flag = FeatureFlag.query.filter_by(key='PAYMENTS_ENABLED').first()
    if flag is None:
        return False
    return str(flag.value).lower() in ('true', '1', 'yes')


def _record_platform_payment(
    group,
    payer_id: str,
    amount: Decimal,
    payment_type: str,
    source: str,
    split_among_group: bool,
):
    """
    Always inject a system expense into group balances.
    GroupPayment audit row is always created; amount is zero when payments disabled.
    """
    expense = create_payment_expense(
        group=group,
        payer_id=payer_id,
        amount=amount,
        source=source,
        split_among_group=split_among_group,
    )
    recorded_amount = amount if _payments_enabled() else Decimal('0')
    payment = GroupPayment(
        group_id=group.id,
        payer_id=payer_id,
        amount=recorded_amount,
        payment_type=payment_type,
        split_among_group=split_among_group,
        expense_id=expense.id,
    )
    db.session.add(payment)
    return expense


class MonetizationService:

    @staticmethod
    def activate_group(group, payer_id: str, split_among_group: bool) -> dict:
        """
        Activate a free/limited group.
        Computes price based on current member count, sets expiry, records payment.
        Expense is always created; gateway charge only when PAYMENTS_ENABLED=true.
        """
        member_count = GroupMember.query.filter_by(group_id=group.id).count()
        pricing = MonetizationConfig.resolve_price(group.group_type, member_count)

        if pricing is None:
            raise ValueError(
                f'מספר המשתתפים ({member_count}) חורג מהמגבלה המקסימלית הנתמכת'
            )

        amount = Decimal(str(pricing['amount']))
        duration_days = pricing['duration_days']
        now = datetime.now(timezone.utc)

        group.group_state = 'active'
        group.pricing_tier = pricing['tier']
        group.activated_at = now
        group.expiry_date = now + timedelta(days=duration_days)
        group.max_participants_snapshot = member_count
        group.is_closed = False
        group.closed_at = None

        _record_platform_payment(
            group, payer_id, amount, 'activation', 'activation', split_among_group
        )

        db.session.commit()

        try:
            notif_service.notify_group_activated(group.id, group.name, payer_id)
        except Exception:
            pass

        return {
            'group_state': group.group_state,
            'expiry_date': group.expiry_date.isoformat(),
            'amount_paid': str(amount) if _payments_enabled() else '0',
            'pricing_tier': pricing['tier'],
            'payments_enabled': _payments_enabled(),
            'expense_recorded': True,
            'split_among_group': split_among_group,
        }

    @staticmethod
    def upgrade_tier(group, payer_id: str, split_among_group: bool) -> dict:
        """
        Upgrade a group's pricing tier when member count has grown past the
        snapshot taken at last activation/upgrade.
        """
        member_count = GroupMember.query.filter_by(group_id=group.id).count()
        upgrade_info = check_tier_upgrade(
            group.group_type, member_count, group.max_participants_snapshot
        )
        if not upgrade_info:
            raise ValueError('אין צורך בשדרוג - המספר הנוכחי נמצא בתוך הרמה הקיימת')

        diff = Decimal(str(upgrade_info['upgrade_price_diff']))
        new_tier = upgrade_info['upgrade_new_tier']

        group.pricing_tier = new_tier
        group.max_participants_snapshot = member_count

        _record_platform_payment(
            group, payer_id, diff, 'upgrade', 'upgrade', split_among_group
        )

        db.session.commit()

        return {
            'group_state': group.group_state,
            'pricing_tier': new_tier,
            'max_participants_snapshot': member_count,
            'amount_paid': str(diff) if _payments_enabled() else '0',
            'payments_enabled': _payments_enabled(),
            'expense_recorded': True,
            'split_among_group': split_among_group,
        }

    @staticmethod
    def extend_group(group, payer_id: str, split_among_group: bool) -> dict:
        """
        Extend an event group by EVENT_EXTENSION_DAYS (15 ILS flat).
        Works even when group is already EXPIRED.
        """
        amount = Decimal(str(MonetizationConfig.EVENT_EXTENSION_PRICE))
        ext_days = MonetizationConfig.EVENT_EXTENSION_DAYS
        now = datetime.now(timezone.utc)

        base = group.expiry_date if group.expiry_date and group.expiry_date > now else now
        if base.tzinfo is None:
            base = base.replace(tzinfo=timezone.utc)

        group.expiry_date = base + timedelta(days=ext_days)
        group.group_state = 'active'

        _record_platform_payment(
            group, payer_id, amount, 'extension', 'extension', split_among_group
        )

        db.session.commit()

        return {
            'group_state': group.group_state,
            'expiry_date': group.expiry_date.isoformat(),
            'amount_paid': str(amount) if _payments_enabled() else '0',
            'payments_enabled': _payments_enabled(),
            'expense_recorded': True,
            'split_among_group': split_among_group,
        }

    @staticmethod
    def renew_group(group, payer_id: str, split_among_group: bool) -> dict:
        """
        Renew an ongoing group for another billing period.
        Works even when group is READ_ONLY (expired ongoing).
        """
        member_count = GroupMember.query.filter_by(group_id=group.id).count()
        pricing = MonetizationConfig.resolve_price(group.group_type, member_count)

        if pricing is None:
            raise ValueError(
                f'מספר המשתתפים ({member_count}) חורג מהמגבלה המקסימלית הנתמכת'
            )

        amount = Decimal(str(pricing['amount']))
        duration_days = pricing['duration_days']
        now = datetime.now(timezone.utc)

        base = group.expiry_date if group.expiry_date and group.expiry_date > now else now
        if base.tzinfo is None:
            base = base.replace(tzinfo=timezone.utc)

        group.expiry_date = base + timedelta(days=duration_days)
        group.group_state = 'active'
        group.pricing_tier = pricing['tier']
        group.max_participants_snapshot = member_count
        group.is_closed = False
        group.closed_at = None

        _record_platform_payment(
            group, payer_id, amount, 'renewal', 'renewal', split_among_group
        )

        db.session.commit()

        return {
            'group_state': group.group_state,
            'expiry_date': group.expiry_date.isoformat(),
            'amount_paid': str(amount) if _payments_enabled() else '0',
            'pricing_tier': pricing['tier'],
            'payments_enabled': _payments_enabled(),
            'expense_recorded': True,
            'split_among_group': split_among_group,
        }
