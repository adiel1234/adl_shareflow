"""
MonetizationService — handles group activation, extension, and renewal.

Beta mode: activation is triggered manually (no real payment gateway).
The service records the payment, injects it as a group expense, and
transitions the group to ACTIVE state.
"""
from datetime import datetime, timezone, timedelta
from decimal import Decimal

from app import db
from app.models import GroupMember, GroupPayment
from app.groups.lifecycle_service import MonetizationConfig
from app.groups.internal_expense_service import create_payment_expense


class MonetizationService:

    @staticmethod
    def activate_group(group, payer_id: str, split_among_group: bool) -> dict:
        """
        Activate a free/limited group.
        Computes price based on current member count, sets expiry, records payment.
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

        # Create system expense
        expense = create_payment_expense(
            group=group,
            payer_id=payer_id,
            amount=amount,
            source='activation',
            split_among_group=split_among_group,
        )

        # Transition group to ACTIVE
        group.group_state = 'active'
        group.pricing_tier = pricing['tier']
        group.activated_at = now
        group.expiry_date = now + timedelta(days=duration_days)
        group.max_participants_snapshot = member_count

        # Record payment
        payment = GroupPayment(
            group_id=group.id,
            payer_id=payer_id,
            amount=amount,
            payment_type='activation',
            split_among_group=split_among_group,
            expense_id=expense.id,
        )
        db.session.add(payment)
        db.session.commit()

        return {
            'group_state': group.group_state,
            'expiry_date': group.expiry_date.isoformat(),
            'amount_paid': str(amount),
            'pricing_tier': pricing['tier'],
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

        expense = create_payment_expense(
            group=group,
            payer_id=payer_id,
            amount=amount,
            source='extension',
            split_among_group=split_among_group,
        )

        # Extend from now if already expired, else from current expiry
        base = group.expiry_date if group.expiry_date and group.expiry_date > now else now
        if base.tzinfo is None:
            base = base.replace(tzinfo=timezone.utc)

        group.expiry_date = base + timedelta(days=ext_days)
        group.group_state = 'active'

        payment = GroupPayment(
            group_id=group.id,
            payer_id=payer_id,
            amount=amount,
            payment_type='extension',
            split_among_group=split_among_group,
            expense_id=expense.id,
        )
        db.session.add(payment)
        db.session.commit()

        return {
            'group_state': group.group_state,
            'expiry_date': group.expiry_date.isoformat(),
            'amount_paid': str(amount),
        }

    @staticmethod
    def renew_group(group, payer_id: str, split_among_group: bool) -> dict:
        """
        Renew an ongoing group for another billing period.
        Works even when group is READ_ONLY (expired ongoing).
        """
        member_count = GroupMember.query.filter_by(group_id=group.id).count()
        pricing = MonetizationConfig.resolve_ongoing_price(member_count)

        if pricing is None:
            raise ValueError(
                f'מספר המשתתפים ({member_count}) חורג מהמגבלה המקסימלית הנתמכת'
            )

        amount = Decimal(str(pricing['amount']))
        duration_days = pricing['duration_days']
        now = datetime.now(timezone.utc)

        expense = create_payment_expense(
            group=group,
            payer_id=payer_id,
            amount=amount,
            source='renewal',
            split_among_group=split_among_group,
        )

        base = group.expiry_date if group.expiry_date and group.expiry_date > now else now
        if base.tzinfo is None:
            base = base.replace(tzinfo=timezone.utc)

        group.expiry_date = base + timedelta(days=duration_days)
        group.group_state = 'active'
        group.pricing_tier = pricing['tier']
        group.max_participants_snapshot = member_count

        payment = GroupPayment(
            group_id=group.id,
            payer_id=payer_id,
            amount=amount,
            payment_type='renewal',
            split_among_group=split_among_group,
            expense_id=expense.id,
        )
        db.session.add(payment)
        db.session.commit()

        return {
            'group_state': group.group_state,
            'expiry_date': group.expiry_date.isoformat(),
            'amount_paid': str(amount),
            'pricing_tier': pricing['tier'],
        }
