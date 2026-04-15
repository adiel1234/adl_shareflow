"""
Notification creation service.
Creates in-app Notification records and optionally sends FCM push.
"""
from typing import Optional
from app import db
from app.models import Notification, GroupMember
from app.notifications import fcm_service


def notify_new_expense(expense, actor_name: str):
    """Notify all group members when a new expense is added."""
    members = GroupMember.query.filter_by(group_id=expense.group_id).all()
    title = 'הוצאה חדשה נוספה'
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
