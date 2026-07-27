from decimal import Decimal

from flask import Blueprint, request, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity

from app.models import Group, GroupMember, Expense, User
from app.balances.engine import calculate_group_balances, calculate_settlement_plan
from app.common.errors import success_response, error_response
from app.common.decorators import require_group_member, require_group_admin
from app import db

balances_bp = Blueprint('balances', __name__)


@balances_bp.get('/groups/<group_id>/balances')
@jwt_required()
@require_group_member
def get_balances(group_id, **kwargs):
    group = db.session.get(Group, group_id)
    if not group:
        return error_response('Group not found', 404)

    balances = calculate_group_balances(group_id)
    return success_response(data={
        'group_id': group_id,
        'base_currency': group.base_currency,
        'balances': [
            {
                'user_id': b.user_id,
                'display_name': b.display_name,
                'net_amount': str(b.net_amount),
                'total_paid': str(b.total_paid),
                'total_owed': str(b.total_owed),
                'status': 'creditor' if b.net_amount > 0 else ('debtor' if b.net_amount < 0 else 'settled'),
            }
            for b in balances
        ],
    })


@balances_bp.get('/groups/<group_id>/balances/settlements-plan')
@jwt_required()
@require_group_member
def get_settlement_plan(group_id, **kwargs):
    group = db.session.get(Group, group_id)
    if not group:
        return error_response('Group not found', 404)

    suggestions = calculate_settlement_plan(group_id, group.base_currency)

    # Build lookup maps: creditor payment details + guest/member status for all users
    all_user_ids = {s.from_user_id for s in suggestions} | {s.to_user_id for s in suggestions}
    all_users = {u.id: u for u in db.session.query(User).filter(User.id.in_(all_user_ids)).all()}
    creditors = all_users  # reuse — all users already fetched

    # Current active member IDs in this group
    active_member_ids = {
        m.user_id for m in GroupMember.query.filter_by(group_id=group_id).all()
    }

    return success_response(data={
        'group_id': group_id,
        'currency': group.base_currency,
        'settlements': [
            {
                'from_user_id': s.from_user_id,
                'from_display_name': s.from_display_name,
                'from_is_guest': all_users[s.from_user_id].is_guest if s.from_user_id in all_users else False,
                'from_is_former_member': s.from_user_id not in active_member_ids,
                'to_user_id': s.to_user_id,
                'to_display_name': s.to_display_name,
                'to_is_guest': all_users[s.to_user_id].is_guest if s.to_user_id in all_users else False,
                'amount': str(s.amount),
                'currency': s.currency,
                'to_payment_phone': creditors[s.to_user_id].payment_phone if s.to_user_id in creditors else None,
                'to_paybox_link': creditors[s.to_user_id].paybox_link if s.to_user_id in creditors else None,
                'to_bank_name': creditors[s.to_user_id].bank_name if s.to_user_id in creditors else None,
                'to_bank_branch': creditors[s.to_user_id].bank_branch if s.to_user_id in creditors else None,
                'to_bank_account_number': creditors[s.to_user_id].bank_account_number if s.to_user_id in creditors else None,
                # Debtor contact for device-side WhatsApp reminders (phone or payment_phone).
                'from_phone': (
                    (all_users[s.from_user_id].phone or all_users[s.from_user_id].payment_phone)
                    if s.from_user_id in all_users else None
                ),
            }
            for s in suggestions
        ],
        'count': len(suggestions),
    })


def _build_event_summary_payload(group_id: str, group: Group) -> dict:
    """Compute summary + WhatsApp text (no side effects)."""
    expenses = Expense.query.filter_by(group_id=group_id).all()
    currency_totals: dict = {}
    for e in expenses:
        c = e.original_currency
        currency_totals[c] = currency_totals.get(c, Decimal('0')) + e.original_amount

    total_summary = ' | '.join(
        f'{int(v)} {k}' for k, v in currency_totals.items()
    ) or '0'

    members = GroupMember.query.filter_by(group_id=group_id).all()
    member_count = len(members)
    participants = []
    for m in members:
        user = db.session.get(User, m.user_id)
        if user:
            participants.append({
                'user_id': user.id,
                'display_name': user.display_name,
                # Prefer contact phone; fall back to payment phone for device WhatsApp.
                'phone': user.phone or user.payment_phone,
                'is_guest': user.is_guest,
            })
    suggestions = calculate_settlement_plan(group_id, group.base_currency)

    from app.balances.engine import check_group_books_balanced
    books_balanced, books_warning = check_group_books_balanced(group_id)

    base_total = sum(e.converted_amount for e in expenses)
    avg_per_member = (
        f'{int(base_total / member_count)} {group.base_currency}'
        if member_count else '0'
    )

    # Top payer - person who paid the most (by converted amount)
    payer_totals: dict = {}
    for e in expenses:
        payer_totals[e.paid_by] = payer_totals.get(e.paid_by, Decimal('0')) + e.converted_amount
    top_payer_data = None
    if payer_totals:
        top_uid = max(payer_totals, key=lambda k: payer_totals[k])
        top_user = db.session.get(User, top_uid)
        top_payer_data = {
            'user_id': top_uid,
            'display_name': top_user.display_name if top_user else top_uid,
            'total_paid': f'{int(payer_totals[top_uid])} {group.base_currency}',
        }

    summary_data = {
        'group_name': group.name,
        'total_summary': total_summary,
        'totals_by_currency': {k: int(v) for k, v in currency_totals.items()},
        'member_count': member_count,
        'avg_per_member': avg_per_member,
        'top_payer': top_payer_data,
        'transfers': [
            {
                'from_user_id': s.from_user_id,
                'from_name': s.from_display_name,
                'to_user_id': s.to_user_id,
                'to_name': s.to_display_name,
                'amount': str(s.amount),
                'currency': s.currency,
                'from_phone': next(
                    (p['phone'] for p in participants
                     if p['user_id'] == s.from_user_id),
                    None,
                ),
            }
            for s in suggestions
        ],
        'books_balanced': books_balanced,
        'books_warning': books_warning,
        'participants': participants,
    }

    lines = [
        f'*סיכום אירוע — {group.name}*',
        f'💰 סה"כ הוצאות: {total_summary}',
        f'👥 משתתפים: {member_count}',
        f'📊 עלות לכל משתתף: {avg_per_member}',
        '',
        '*💸 העברות נדרשות:*',
    ]
    for s in suggestions:
        lines.append(
            f'• {s.from_display_name} חייב ל-{s.to_display_name} '
            f'{int(s.amount)} {s.currency}'
        )
    lines += ['', 'סיכום הוצאות מאפליקציית ADL ShareFlow']

    whatsapp_text = '\n'.join(lines)

    return {
        'summary': summary_data,
        'whatsapp_text': whatsapp_text,
    }


@balances_bp.get('/groups/<group_id>/event-summary')
@jwt_required()
@require_group_admin
def get_event_summary_preview(group_id, **kwargs):
    """Read-only event summary for the finish-event wizard (no notifications)."""
    group = db.session.get(Group, group_id)
    if not group:
        return error_response('Group not found', 404)

    try:
        return success_response(data=_build_event_summary_payload(group_id, group))
    except Exception:
        current_app.logger.exception(
            'event-summary build failed group_id=%s', group_id
        )
        return error_response('שגיאה בבניית סיכום האירוע', 500)


@balances_bp.post('/groups/<group_id>/summary')
@jwt_required()
@require_group_admin
def send_event_summary(group_id, **kwargs):
    """Admin sends event summary notification to all members."""
    group = db.session.get(Group, group_id)
    if not group:
        return error_response('Group not found', 404)

    data = request.get_json(silent=True) or {}
    send_app = bool(data.get('send_app', False))

    try:
        payload = _build_event_summary_payload(group_id, group)
    except Exception:
        current_app.logger.exception(
            'event-summary build failed group_id=%s', group_id
        )
        return error_response('שגיאה בבניית סיכום האירוע', 500)

    if send_app:
        from app.notifications import service as notif_svc
        notif_svc.queue_notify_event_summary(
            group_id, payload['summary'], actor_user_id=get_jwt_identity()
        )

    return success_response(data={
        **payload,
        'sent_app': send_app,
    })


@balances_bp.post('/groups/<group_id>/remind')
@jwt_required()
@require_group_member
def send_payment_reminder(group_id, **kwargs):
    """Creditor sends a reminder push to a specific debtor."""
    user_id = get_jwt_identity()
    data = request.get_json(silent=True) or {}
    to_user_id = data.get('to_user_id')
    amount = data.get('amount', '0')
    currency = data.get('currency', '')

    if not to_user_id:
        return error_response('to_user_id is required')

    creditor = db.session.get(User, user_id)
    creditor_name = creditor.display_name if creditor else 'מישהו'

    from app.notifications import service as notif_svc
    notif_svc.notify_payment_reminder(
        {
            'from_user_id': to_user_id,
            'to_user_id': user_id,
            'amount': amount,
            'currency': currency,
            'group_id': group_id,
        },
        creditor_name=creditor_name,
    )
    return success_response(message='Reminder sent')
