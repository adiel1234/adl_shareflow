from datetime import datetime, timezone
from decimal import Decimal

from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app import db
from app.models import Settlement, GroupMember, Group
from app.common.errors import success_response, error_response
from app.common.decorators import require_group_member, require_group_admin, require_group_operational
from app.common.utils import to_decimal

settlements_bp = Blueprint('settlements', __name__)


@settlements_bp.post('/groups/<group_id>/settlements')
@jwt_required()
@require_group_member
@require_group_operational
def create_settlement(group_id, **kwargs):
    user_id = get_jwt_identity()
    data = request.get_json(silent=True) or {}

    to_user_id = data.get('to_user_id')
    if not to_user_id:
        return error_response('to_user_id is required')

    try:
        amount = to_decimal(data.get('amount'))
        if amount <= 0:
            raise ValueError()
    except Exception:
        return error_response('amount must be a positive number')

    group = db.session.get(Group, group_id)
    if not group:
        return error_response('Group not found', 404)

    to_member = GroupMember.query.filter_by(group_id=group_id, user_id=to_user_id).first()
    if not to_member:
        return error_response('to_user_id is not a member of this group')

    settlement = Settlement(
        group_id=group_id,
        from_user_id=user_id,
        to_user_id=to_user_id,
        amount=amount,
        currency=data.get('currency', group.base_currency),
        notes=data.get('notes'),
    )
    db.session.add(settlement)
    db.session.commit()

    try:
        from app.models import User
        from app.notifications.service import notify_settlement_requested
        actor = db.session.get(User, user_id)
        notify_settlement_requested(settlement, actor.display_name if actor else 'מישהו')
    except Exception:
        pass

    return success_response(data=settlement.to_dict(), status_code=201)


def _can_confirm_settlement(settlement, user_id) -> bool:
    """Creditor confirms receipt; admin confirms on behalf of guest creditor."""
    if settlement.to_user_id == user_id:
        return True
    from app.models import User
    to_user = db.session.get(User, settlement.to_user_id)
    if to_user and to_user.is_guest:
        member = GroupMember.query.filter_by(
            group_id=settlement.group_id, user_id=user_id
        ).first()
        return member is not None and member.role == 'admin'
    return False


@settlements_bp.put('/settlements/<settlement_id>/confirm')
@jwt_required()
def confirm_settlement(settlement_id):
    user_id = get_jwt_identity()
    settlement = db.session.get(Settlement, settlement_id)
    if not settlement:
        return error_response('Settlement not found', 404)

    if not _can_confirm_settlement(settlement, user_id):
        return error_response('Only the recipient (or admin for guest) can confirm', 403)

    if settlement.status == 'confirmed':
        return success_response(data=settlement.to_dict())
    if settlement.status != 'pending':
        return error_response(f'Settlement is already {settlement.status}')

    settlement.status = 'confirmed'
    settlement.confirmed_at = datetime.now(timezone.utc)
    db.session.commit()

    try:
        from app.models import User
        from app.notifications.service import notify_settlement_confirmed
        confirmer = db.session.get(User, user_id)
        notify_settlement_confirmed(settlement, confirmer.display_name if confirmer else 'מישהו')
    except Exception:
        pass

    return success_response(data=settlement.to_dict())


def _guest_user_ids_in_group(group_id: str) -> list[str]:
    """Guest member user IDs in this group (not all guests system-wide)."""
    from app.models import User
    rows = (
        db.session.query(GroupMember.user_id)
        .join(User, User.id == GroupMember.user_id)
        .filter(GroupMember.group_id == group_id, User.is_guest.is_(True))
        .all()
    )
    return [row[0] for row in rows]


@settlements_bp.get('/groups/<group_id>/settlements/pending')
@jwt_required()
@require_group_member
def list_pending_settlements(group_id, **kwargs):
    """Return pending settlements involving the user; admins also see guest-related ones."""
    user_id = get_jwt_identity()
    from app.models import User

    member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    is_admin = member is not None and member.role == 'admin'

    base = Settlement.query.filter_by(group_id=group_id, status='pending')

    involved = (
        (Settlement.from_user_id == user_id) | (Settlement.to_user_id == user_id)
    )
    if is_admin:
        guest_ids = _guest_user_ids_in_group(group_id)
        if guest_ids:
            involved = involved | Settlement.from_user_id.in_(guest_ids) | Settlement.to_user_id.in_(guest_ids)

    settlements = base.filter(involved).order_by(Settlement.created_at.desc()).all()

    user_map = {}
    guest_map = {}
    for s in settlements:
        for uid in [s.from_user_id, s.to_user_id]:
            if uid not in user_map:
                u = db.session.get(User, uid)
                user_map[uid] = u.display_name if u else uid
                guest_map[uid] = bool(u and u.is_guest)

    result = []
    for s in settlements:
        d = s.to_dict()
        d['from_display_name'] = user_map.get(s.from_user_id, s.from_user_id)
        d['to_display_name'] = user_map.get(s.to_user_id, s.to_user_id)
        d['from_is_guest'] = guest_map.get(s.from_user_id, False)
        d['to_is_guest'] = guest_map.get(s.to_user_id, False)
        d['can_confirm'] = _can_confirm_settlement(s, user_id)
        d['is_creditor_confirm'] = (
            s.to_user_id == user_id and not guest_map.get(s.to_user_id, False)
        )
        result.append(d)

    return success_response(data={'settlements': result})


@settlements_bp.post('/groups/<group_id>/settlements/mark-guest-paid')
@jwt_required()
@require_group_admin
def mark_guest_paid(group_id, **kwargs):
    """Admin confirms guest payment.

    guest→member: pending (member must confirm receipt).
    guest→guest: confirmed immediately (single admin action).
    """
    from app.models import User
    admin_id = get_jwt_identity()
    data = request.get_json(silent=True) or {}

    guest_user_id = data.get('guest_user_id')
    to_user_id = data.get('to_user_id')
    if not guest_user_id or not to_user_id:
        return error_response('guest_user_id and to_user_id are required')

    guest = db.session.get(User, guest_user_id)
    if not guest or not guest.is_guest:
        return error_response('guest_user_id must belong to a guest member', 404)

    to_user = db.session.get(User, to_user_id)
    if not to_user:
        return error_response('to_user_id not found', 404)

    # Allow marking as paid even after the guest has been removed from the group.
    # Verify the guest has history in this group (active member OR past expense/settlement data).
    from app.models import Expense, ExpenseParticipant
    still_member = GroupMember.query.filter_by(
        group_id=group_id, user_id=guest_user_id
    ).first() is not None
    has_expense = Expense.query.filter_by(
        group_id=group_id, paid_by=guest_user_id
    ).first() is not None
    has_participation = (
        db.session.query(ExpenseParticipant)
        .join(Expense, Expense.id == ExpenseParticipant.expense_id)
        .filter(Expense.group_id == group_id, ExpenseParticipant.user_id == guest_user_id)
        .first()
    ) is not None
    if not (still_member or has_expense or has_participation):
        return error_response('Guest has no history in this group', 404)

    try:
        amount = to_decimal(data.get('amount'))
        if amount <= 0:
            raise ValueError()
    except Exception:
        return error_response('amount must be a positive number')

    group = db.session.get(Group, group_id)
    if not group:
        return error_response('Group not found', 404)

    currency = data.get('currency', group.base_currency)

    # Idempotent: return existing pending settlement for the same transfer
    existing = Settlement.query.filter_by(
        group_id=group_id,
        from_user_id=guest_user_id,
        to_user_id=to_user_id,
        status='pending',
    ).order_by(Settlement.created_at.desc()).first()
    if existing and Decimal(str(existing.amount)) == amount and existing.currency == currency:
        d = existing.to_dict()
        d['from_is_guest'] = True
        d['to_is_guest'] = to_user.is_guest
        return success_response(data=d)

    # guest→guest: one admin step closes debt; guest→member: member confirms receipt
    is_guest_to_guest = to_user.is_guest
    now = datetime.now(timezone.utc)
    settlement = Settlement(
        group_id=group_id,
        from_user_id=guest_user_id,
        to_user_id=to_user_id,
        amount=amount,
        currency=data.get('currency', group.base_currency),
        status='confirmed' if is_guest_to_guest else 'pending',
        confirmed_at=now if is_guest_to_guest else None,
        notes=f'סומן ע"י מנהל בשם האורח {guest.display_name}',
    )
    db.session.add(settlement)
    db.session.commit()

    if settlement.status == 'pending':
        try:
            from app.notifications.service import notify_settlement_requested
            admin = db.session.get(User, admin_id)
            actor_name = admin.display_name if admin else 'מנהל'
            notify_settlement_requested(settlement, actor_name)
        except Exception:
            pass

    d = settlement.to_dict()
    d['from_is_guest'] = True
    d['to_is_guest'] = to_user.is_guest
    return success_response(data=d, status_code=201)


@settlements_bp.put('/settlements/<settlement_id>/cancel')
@jwt_required()
def cancel_settlement(settlement_id):
    user_id = get_jwt_identity()
    settlement = db.session.get(Settlement, settlement_id)
    if not settlement:
        return error_response('Settlement not found', 404)

    if settlement.from_user_id != user_id and settlement.to_user_id != user_id:
        return error_response('Access denied', 403)
    if settlement.status != 'pending':
        return error_response(f'Cannot cancel a {settlement.status} settlement')

    settlement.status = 'cancelled'
    db.session.commit()

    return success_response(data=settlement.to_dict())
