"""
Notification creation service.
Creates in-app Notification records and optionally sends FCM push.

Guest routing: guests have no app and no FCM token. Any notification destined
for a guest is redirected to the group admin instead. For broadcast loops
(all-member notifications) guests are simply skipped — the admin is already
in the list and will receive the notification naturally.
"""
from app import db
from app.models import Notification, GroupMember
from app.notifications import fcm_service


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_admin_id(group_id: str) -> str | None:
    """Return the user_id of the group admin, or None if not found."""
    admin = GroupMember.query.filter_by(group_id=group_id, role='admin').first()
    return admin.user_id if admin else None


def _resolve_recipient(user_id: str, group_id: str) -> str:
    """
    If user_id belongs to a guest, return the group admin's user_id instead.
    The caller should add context to the notification body so the admin knows
    the message is acting on behalf of a guest.
    """
    from app.models import User
    user = db.session.get(User, user_id)
    if user and user.is_guest:
        admin_id = _get_admin_id(group_id)
        return admin_id if admin_id else user_id
    return user_id


def _guest_display(user_id: str) -> str | None:
    """Return the guest's display_name if the user is a guest, else None."""
    from app.models import User
    user = db.session.get(User, user_id)
    return user.display_name if (user and user.is_guest) else None


# ---------------------------------------------------------------------------
# Notification functions
# ---------------------------------------------------------------------------

def notify_new_expense(expense, actor_name: str):
    """Notify all group members when a new expense is added."""
    from app.models import Group
    group = db.session.get(Group, expense.group_id)
    group_name = group.name if group else ''
    members = GroupMember.query.filter_by(group_id=expense.group_id).all()
    title = f'הוצאה חדשה - {group_name}' if group_name else 'הוצאה חדשה נוספה'
    body = f'{actor_name} הוסיף: {expense.title} - {expense.original_amount} {expense.original_currency}'

    for member in members:
        if member.user_id == expense.paid_by:
            continue  # Don't notify the one who added it
        # Skip guests — admin is already in the loop and will be notified
        if member.user and member.user.is_guest:
            continue
        notif = Notification(
            user_id=member.user_id,
            type='new_expense',
            title=title,
            body=body,
            data={
                'group_id': expense.group_id,
                'expense_id': expense.id,
            },
        )
        db.session.add(notif)

    db.session.commit()

    # FCM — skip guests (admin already in list)
    recipient_ids = [
        m.user_id for m in members
        if m.user_id != expense.paid_by and not (m.user and m.user.is_guest)
    ]
    fcm_service.send_to_users(recipient_ids, title, body, {
        'type': 'new_expense',
        'group_id': expense.group_id,
        'expense_id': expense.id,
    })


def notify_settlement_requested(settlement, requester_name: str):
    """Notify debtor (or admin on their behalf) that a settlement was requested."""
    recipient_id = _resolve_recipient(settlement.to_user_id, settlement.group_id)
    guest_name = _guest_display(settlement.to_user_id)

    title = 'בקשת הסדר חוב'
    if guest_name:
        body = f'{requester_name} ביקש לסגור חוב של {settlement.amount} {settlement.currency} בשם האורח {guest_name}'
    else:
        body = f'{requester_name} ביקש לסגור חוב של {settlement.amount} {settlement.currency}'

    notif = Notification(
        user_id=recipient_id,
        type='settlement_requested',
        title=title,
        body=body,
        data={
            'group_id': settlement.group_id,
            'settlement_id': settlement.id,
        },
    )
    db.session.add(notif)
    db.session.commit()

    fcm_service.send_to_user(recipient_id, title, body, {
        'type': 'settlement_requested',
        'group_id': settlement.group_id,
        'settlement_id': settlement.id,
    })


def notify_settlement_confirmed(settlement, confirmer_name: str):
    """Notify creditor (or admin) that a payment was confirmed."""
    recipient_id = _resolve_recipient(settlement.from_user_id, settlement.group_id)
    guest_name = _guest_display(settlement.from_user_id)

    title = 'תשלום אושר!'
    if guest_name:
        body = f'תשלום של {settlement.amount} {settlement.currency} עבור האורח {guest_name} אושר'
    else:
        body = f'{confirmer_name} אישר תשלום של {settlement.amount} {settlement.currency}'

    notif = Notification(
        user_id=recipient_id,
        type='settlement_confirmed',
        title=title,
        body=body,
        data={
            'group_id': settlement.group_id,
            'settlement_id': settlement.id,
        },
    )
    db.session.add(notif)
    db.session.commit()

    fcm_service.send_to_user(recipient_id, title, body, {
        'type': 'settlement_confirmed',
        'group_id': settlement.group_id,
        'settlement_id': settlement.id,
    })


def notify_event_summary(group_id: str, summary_data: dict, actor_user_id: str):
    """Send event summary notification to all group members (guests skipped)."""
    members = GroupMember.query.filter_by(group_id=group_id).all()
    title = f'סיכום אירוע - {summary_data["group_name"]}'
    body = (
        f'סה"כ: {summary_data["total_summary"]} | '
        f'{summary_data["member_count"]} משתתפים | '
        f'עלות ממוצעת: {summary_data["avg_per_member"]}'
    )
    for member in members:
        # Skip guests — admin is already in the list
        if member.user and member.user.is_guest:
            continue
        notif = Notification(
            user_id=member.user_id,
            type='event_summary',
            title=title,
            body=body,
            data={'group_id': group_id, 'summary': summary_data},
        )
        db.session.add(notif)
    db.session.commit()

    recipient_ids = [m.user_id for m in members if not (m.user and m.user.is_guest)]
    fcm_service.send_to_users(recipient_ids, title, body, {
        'type': 'event_summary',
        'group_id': group_id,
    })


def notify_payment_reminder(settlement_suggestion: dict, creditor_name: str):
    """Notify a debtor (or admin on their behalf) that a payment is due."""
    debtor_id = settlement_suggestion['from_user_id']
    group_id = settlement_suggestion.get('group_id')
    amount = settlement_suggestion['amount']
    currency = settlement_suggestion['currency']

    recipient_id = _resolve_recipient(debtor_id, group_id) if group_id else debtor_id
    guest_name = _guest_display(debtor_id)

    title = 'תזכורת תשלום'
    if guest_name:
        body = f'תזכורת: האורח {guest_name} חייב {amount} {currency} ל-{creditor_name}'
    else:
        body = f'{creditor_name} מזכיר לך: אתה חייב {amount} {currency}'

    notif = Notification(
        user_id=recipient_id,
        type='payment_reminder',
        title=title,
        body=body,
        data={
            'group_id': group_id,
            'to_user_id': settlement_suggestion['to_user_id'],
            'amount': str(amount),
            'currency': currency,
        },
    )
    db.session.add(notif)
    db.session.commit()

    fcm_service.send_to_user(recipient_id, title, body, {
        'type': 'payment_reminder',
        'group_id': group_id,
    })


def notify_tier_upgrade_required(group_id: str, upgrade_price: int, admin_user_id: str):
    """Notify group admin that a tier upgrade payment is needed."""
    title = 'נדרש שדרוג תכנית'
    body = f'מספר המשתתפים עלה - נדרש תשלום נוסף של {upgrade_price} ₪'

    notif = Notification(
        user_id=admin_user_id,
        type='tier_upgrade_required',
        title=title,
        body=body,
        data={'group_id': group_id, 'upgrade_price': str(upgrade_price)},
    )
    db.session.add(notif)
    db.session.commit()

    fcm_service.send_to_user(admin_user_id, title, body, {
        'type': 'tier_upgrade_required',
        'group_id': group_id,
    })


def notify_group_expiring_soon(group_id: str, group_name: str, days_left: int):
    """Notify group admin when group is about to expire."""
    members = GroupMember.query.filter_by(group_id=group_id, role='admin').all()
    title = 'הקבוצה עומדת לפוג'
    body = f'ל"{group_name}" נותרו {days_left} ימים - חדשו כדי להמשיך'

    for member in members:
        notif = Notification(
            user_id=member.user_id,
            type='group_expiring_soon',
            title=title,
            body=body,
            data={'group_id': group_id, 'days_left': str(days_left)},
        )
        db.session.add(notif)
    db.session.commit()

    admin_ids = [m.user_id for m in members]
    fcm_service.send_to_users(admin_ids, title, body, {
        'type': 'group_expiring_soon',
        'group_id': group_id,
    })


def notify_group_activated(group_id: str, group_name: str, activator_user_id: str):
    """Notify all members (guests skipped) when group is activated/renewed."""
    members = GroupMember.query.filter_by(group_id=group_id).all()
    title = f'הקבוצה "{group_name}" הופעלה!'
    body = 'ניתן להוסיף הוצאות ולעדכן יתרות'

    for member in members:
        if member.user_id == activator_user_id:
            continue
        # Skip guests — admin is already in the list
        if member.user and member.user.is_guest:
            continue
        notif = Notification(
            user_id=member.user_id,
            type='group_activated',
            title=title,
            body=body,
            data={'group_id': group_id},
        )
        db.session.add(notif)
    db.session.commit()

    recipient_ids = [
        m.user_id for m in members
        if m.user_id != activator_user_id and not (m.user and m.user.is_guest)
    ]
    fcm_service.send_to_users(recipient_ids, title, body, {
        'type': 'group_activated',
        'group_id': group_id,
    })


def notify_group_joined(group, new_member_name: str, joiner_user_id: str):
    """Notify group admin when someone joins."""
    from app.models import Group
    group_obj = db.session.get(Group, group.id if hasattr(group, 'id') else group)
    if not group_obj:
        return

    admin = GroupMember.query.filter_by(
        group_id=group_obj.id, role='admin'
    ).first()
    if not admin or admin.user_id == joiner_user_id:
        return

    title = 'חבר חדש בקבוצה'
    body = f'{new_member_name} הצטרף לקבוצה {group_obj.name}'

    notif = Notification(
        user_id=admin.user_id,
        type='member_joined',
        title=title,
        body=body,
        data={'group_id': group_obj.id},
    )
    db.session.add(notif)
    db.session.commit()

    fcm_service.send_to_user(admin.user_id, title, body, {
        'type': 'member_joined',
        'group_id': group_obj.id,
    })
