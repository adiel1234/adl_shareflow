from datetime import datetime, timezone

from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app import db
from app.models import Settlement, GroupMember, Group
from app.common.errors import success_response, error_response
from app.common.decorators import require_group_member, require_group_operational
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


@settlements_bp.put('/settlements/<settlement_id>/confirm')
@jwt_required()
def confirm_settlement(settlement_id):
    user_id = get_jwt_identity()
    settlement = db.session.get(Settlement, settlement_id)
    if not settlement:
        return error_response('Settlement not found', 404)

    if settlement.to_user_id != user_id:
        return error_response('Only the recipient can confirm a settlement', 403)
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


@settlements_bp.get('/groups/<group_id>/settlements/pending')
@jwt_required()
@require_group_member
def list_pending_settlements(group_id, **kwargs):
    """Return all pending settlements in this group that involve the current user."""
    user_id = get_jwt_identity()
    settlements = Settlement.query.filter_by(
        group_id=group_id,
        status='pending',
    ).filter(
        (Settlement.from_user_id == user_id) | (Settlement.to_user_id == user_id)
    ).order_by(Settlement.created_at.desc()).all()

    from app.models import User
    user_map = {}
    for s in settlements:
        for uid in [s.from_user_id, s.to_user_id]:
            if uid not in user_map:
                u = db.session.get(User, uid)
                user_map[uid] = u.display_name if u else uid

    result = []
    for s in settlements:
        d = s.to_dict()
        d['from_display_name'] = user_map.get(s.from_user_id, s.from_user_id)
        d['to_display_name'] = user_map.get(s.to_user_id, s.to_user_id)
        result.append(d)

    return success_response(data={'settlements': result})


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
