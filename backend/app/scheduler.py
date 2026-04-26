"""
APScheduler — automatic payment reminders + group expiry checks.
Reminders run hourly; expiry checks run daily.
"""
from datetime import datetime, timezone, timedelta

from flask_apscheduler import APScheduler

scheduler = APScheduler()

# Frequency → minimum hours between sends
_FREQ_HOURS = {
    'daily': 24,
    'every_2_days': 48,
    'weekly': 168,
    'biweekly': 336,
}


def _should_send(last_sent_at, frequency: str) -> bool:
    if frequency in ('none', 'manual') or not frequency:
        return False
    min_hours = _FREQ_HOURS.get(frequency)
    if not min_hours:
        return False
    if last_sent_at is None:
        return True
    elapsed = (datetime.now(timezone.utc) - last_sent_at).total_seconds() / 3600
    return elapsed >= min_hours


@scheduler.task('interval', id='auto_reminders', hours=1, misfire_grace_time=300)
def send_auto_reminders():
    """Check every hour who needs an automatic reminder."""
    with scheduler.app.app_context():
        from app import db
        from app.models import ReminderSettings, GroupMember, Settlement
        from app.balances.engine import calculate_settlement_plan
        from app.models import Group
        from app.notifications import service as notif_svc

        # Load all reminder settings that are enabled and not 'manual'/'none'
        all_settings = ReminderSettings.query.filter(
            ReminderSettings.enabled.is_(True),
            ReminderSettings.frequency.notin_(['manual', 'none']),
        ).all()

        for settings in all_settings:
            if not _should_send(settings.last_sent_at, settings.frequency):
                continue

            # Find all groups this user is a creditor in
            memberships = GroupMember.query.filter_by(
                user_id=settings.user_id
            ).all()

            sent_any = False
            for membership in memberships:
                group = db.session.get(Group, membership.group_id)
                if not group:
                    continue

                suggestions = calculate_settlement_plan(
                    membership.group_id, group.base_currency
                )
                for s in suggestions:
                    # Only send if this user is the creditor (to_user = creditor)
                    if s.to_user_id != settings.user_id:
                        continue

                    # Check if this debt is already settled
                    settled = Settlement.query.filter_by(
                        group_id=membership.group_id,
                        from_user_id=s.from_user_id,
                        to_user_id=s.to_user_id,
                        status='confirmed',
                    ).first()
                    if settled:
                        continue

                    notif_svc.notify_payment_reminder(
                        {
                            'from_user_id': s.from_user_id,
                            'to_user_id': s.to_user_id,
                            'amount': str(s.amount),
                            'currency': s.currency,
                            'group_id': membership.group_id,
                        },
                        creditor_name=s.to_display_name,
                    )
                    sent_any = True

            if sent_any:
                settings.last_sent_at = datetime.now(timezone.utc)
                db.session.commit()


@scheduler.task('interval', id='check_group_expirations', hours=24, misfire_grace_time=3600)
def check_group_expirations():
    """
    Daily job: scan active groups whose expiry_date has passed and transition
    them to 'expired' (event) or 'read_only' (ongoing).
    Also sends expiry warnings 3 days before expiry.
    """
    with scheduler.app.app_context():
        from app import db
        from app.models import Group
        from app.notifications import service as notif_svc

        now = datetime.now(timezone.utc)

        # --- Transition expired groups ---
        expired_groups = Group.query.filter(
            Group.group_state == 'active',
            Group.expiry_date.isnot(None),
            Group.expiry_date < now,
            Group.is_active.is_(True),
        ).all()

        updated = 0
        for group in expired_groups:
            new_state = 'expired' if group.group_type == 'event' else 'read_only'
            group.group_state = new_state
            updated += 1

        if updated:
            db.session.commit()

        # --- Warn groups expiring in 3–4 days (24-hour window matches daily run) ---
        warn_from = now + timedelta(days=3)
        warn_to = now + timedelta(days=4)
        expiring_soon = Group.query.filter(
            Group.group_state == 'active',
            Group.expiry_date.isnot(None),
            Group.expiry_date >= warn_from,
            Group.expiry_date < warn_to,
            Group.is_active.is_(True),
        ).all()

        for group in expiring_soon:
            try:
                notif_svc.notify_group_expiring_soon(
                    group_id=group.id,
                    group_name=group.name,
                    days_left=3,
                )
            except Exception:
                pass

        # --- Transition free groups that hit the 5-day limit ---
        free_cutoff = now - timedelta(days=5)
        free_groups = Group.query.filter(
            Group.group_state == 'free',
            Group.created_at < free_cutoff,
            Group.is_active.is_(True),
        ).all()

        limited = 0
        for group in free_groups:
            group.group_state = 'limited'
            limited += 1

        if limited:
            db.session.commit()
