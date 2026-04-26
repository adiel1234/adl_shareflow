"""
Notification creation service.
Creates in-app Notification records and optionally sends FCM push.
"""
from app import db
from app.models import Notification, GroupMember
from app.notifications import fcm_service


def notify_new_expense(expense, actor_name: str):
    """Notify all group members when a new expense is added."""
    from app.models import Group
    group = db.session.get(Group, expense.group_id)
    group_name = group.name if group else ''
    members = GroupMember.query.filter_by(group_id=expense.group_id).all()
    title = f'הוצאה חדשה — {group_name}' if group_name else 'הוצאה חדשה נוספה'
    body = f'{actor_name} הוסיף: {expense.title} — {expense.original_amount} {expense.original_currency}'

    for member in members:
        if member.user_id == expense.paid_by:
            continue  # Don't notify the one who added it
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

    # Send FCM push
    recipient_ids = [m.user_id for m in members if m.user_id != expense.paid_by]
    fcm_service.send_to_users(recipient_ids, title, body, {
        'type': 'new_expense',
        'group_id': expense.group_id,
        'expense_id': expense.id,
    })


def notify_settlement_requested(settlement, requester_name: str):
    """Notify debtor that a settlement has been requested."""
    title = 'בקשת הסדר חוב'
    body = f'{requester_name} ביקש לסגור חוב של {settlement.amount} {settlement.currency}'

    notif = Notification(
        user_id=settlement.to_user_id,
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

    fcm_service.send_to_user(settlement.to_user_id, title, body, {
        'type': 'settlement_requested',
        'group_id': settlement.group_id,
        'settlement_id': settlement.id,
    })


def notify_settlement_confirmed(settlement, confirmer_name: str):
    """Notify creditor that debtor confirmed the payment."""
    title = 'תשלום אושר!'
    body = f'{confirmer_name} אישר תשלום של {settlement.amount} {settlement.currency}'

    notif = Notification(
        user_id=settlement.from_user_id,
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

    fcm_service.send_to_user(settlement.from_user_id, title, body, {
        'type': 'settlement_confirmed',
        'group_id': settlement.group_id,
        'settlement_id': settlement.id,
    })


def notify_event_summary(group_id: str, summary_data: dict, actor_user_id: str):
    """Send event summary notification to all group members."""
    members = GroupMember.query.filter_by(group_id=group_id).all()
    title = f'סיכום אירוע — {summary_data["group_name"]}'
    body = (
        f'סה"כ: {summary_data["total_summary"]} | '
        f'{summary_data["member_count"]} משתתפים | '
        f'עלות ממוצעת: {summary_data["avg_per_member"]}'
    )
    for member in members:
        notif = Notification(
            user_id=member.user_id,
            type='event_summary',
            title=title,
            body=body,
            data={'group_id': group_id, 'summary': summary_data},
        )
        db.session.add(notif)
    db.session.commit()

    recipient_ids = [m.user_id for m in members]
    fcm_service.send_to_users(recipient_ids, title, body, {
        'type': 'event_summary',
        'group_id': group_id,
    })


def notify_payment_reminder(settlement_suggestion: dict, creditor_name: str):
    """Notify a debtor that they need to pay."""
    debtor_id = settlement_suggestion['from_user_id']
    amount = settlement_suggestion['amount']
    currency = settlement_suggestion['currency']
    title = 'תזכורת תשלום'
    body = f'{creditor_name} מזכיר לך: אתה חייב {amount} {currency}'

    notif = Notification(
        user_id=debtor_id,
        type='payment_reminder',
        title=title,
        body=body,
        data={
            'group_id': settlement_suggestion.get('group_id'),
            'to_user_id': settlement_suggestion['to_user_id'],
            'amount': str(amount),
            'currency': currency,
        },
    )
    db.session.add(notif)
    db.session.commit()

    fcm_service.send_to_user(debtor_id, title, body, {
        'type': 'payment_reminder',
        'group_id': settlement_suggestion.get('group_id'),
    })


def notify_tier_upgrade_required(group_id: str, upgrade_price: int, admin_user_id: str):
    """Notify group admin that a tier upgrade payment is needed."""
    title = 'נדרש שדרוג תכנית'
    body = f'מספר המשתתפים עלה — נדרש תשלום נוסף של {upgrade_price} ₪'

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
    body = f'ל"{group_name}" נותרו {days_left} ימים — חדשו כדי להמשיך'

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
    """Notify all members when group is activated/renewed."""
    members = GroupMember.query.filter_by(group_id=group_id).all()
    title = f'הקבוצה "{group_name}" הופעלה!'
    body = 'ניתן להוסיף הוצאות ולעדכן יתרות'

    for member in members:
        if member.user_id == activator_user_id:
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

    recipient_ids = [m.user_id for m in members if m.user_id != activator_user_id]
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
