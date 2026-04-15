import secrets
from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app import db
from app.models import Group, GroupMember, User
from app.common.errors import success_response, error_response
from app.common.decorators import require_group_member, require_group_admin
from app.common.utils import generate_invite_code
from app.groups.lifecycle_service import GroupLifecycleService

groups_bp = Blueprint('groups', __name__)


@groups_bp.get('')
@jwt_required()
def list_groups():
    user_id = get_jwt_identity()
    memberships = GroupMember.query.filter_by(user_id=user_id).all()
    groups = []
    dirty = False
    for m in memberships:
        g = m.group
        if g and g.is_active:
            dirty |= GroupLifecycleService.sync_state(g, db.session)
            d = g.to_dict()
            d['my_role'] = m.role
            admin_member = GroupMember.query.filter_by(group_id=g.id, role='admin').first()
            if admin_member:
                admin_user = User.query.get(admin_member.user_id)
                d['admin_name'] = admin_user.display_name if admin_user else None
            else:
                d['admin_name'] = None
            groups.append(d)
    if dirty:
        db.session.commit()
    return success_response(data=groups)


@groups_bp.post('')
@jwt_required()
def create_group():
    user_id = get_jwt_identity()
    data = request.get_json(silent=True) or {}
    name = (data.get('name') or '').strip()
    if not name:
        return error_response('name is required')

    group_type = data.get('group_type', 'event')
    if group_type not in ('event', 'ongoing'):
        group_type = 'event'

    group = Group(
        name=name,
        description=(data.get('description') or '').strip() or None,
        base_currency=(data.get('base_currency') or 'ILS').upper(),
        category=data.get('category') or None,
        created_by=user_id,
        invite_code=generate_invite_code(),
        group_type=group_type,
        group_state='free',
    )
    db.session.add(group)
    db.session.flush()

    member = GroupMember(group_id=group.id, user_id=user_id, role='admin')
    db.session.add(member)
    db.session.commit()

    return success_response(data=group.to_dict(), status_code=201)


@groups_bp.get('/<group_id>')
@jwt_required()
@require_group_member
def get_group(group_id, **kwargs):
    user_id = get_jwt_identity()
    group = Group.query.get(group_id)
    if not group or not group.is_active:
        return error_response('Group not found', 404)

    # Sync lifecycle state on every fetch
    if GroupLifecycleService.sync_state(group, db.session):
        db.session.commit()

    member = kwargs.get('_member')
    d = group.to_dict()
    d['my_role'] = member.role if member else None
    d['members'] = [m.to_dict() for m in group.members]

    # Include pricing info for limited/expired groups so Flutter can show correct price
    if group.group_state in ('free', 'limited', 'expired', 'read_only'):
        from app.groups.lifecycle_service import MonetizationConfig
        member_count = len(group.members)
        pricing = MonetizationConfig.resolve_price(group.group_type, member_count)
        d['required_pricing'] = pricing

    return success_response(data=d)


@groups_bp.put('/<group_id>')
@jwt_required()
@require_group_admin
def update_group(group_id, **kwargs):
    group = Group.query.get(group_id)
    if not group or not group.is_active:
        return error_response('Group not found', 404)

    data = request.get_json(silent=True) or {}
    if 'name' in data:
        name = data['name'].strip()
        if not name:
            return error_response('name cannot be empty')
        group.name = name
    if 'description' in data:
        group.description = data['description'].strip() or None
    if 'base_currency' in data:
        group.base_currency = data['base_currency'].upper()[:3]
    if 'category' in data:
        group.category = data['category'] or None

    db.session.commit()
    return success_response(data=group.to_dict())


@groups_bp.get('/<group_id>/members')
@jwt_required()
@require_group_member
def get_members(group_id, **kwargs):
    members = GroupMember.query.filter_by(group_id=group_id).all()
    return success_response(data=[m.to_dict() for m in members])


@groups_bp.delete('/<group_id>/members/<target_user_id>')
@jwt_required()
@require_group_admin
def remove_member(group_id, target_user_id, **kwargs):
    """
    Remove a member from the group.
    mode:
      'settle'       (default) — create confirmed settlement to clear net debt
      'redistribute' — redistribute their expense shares among remaining members
    """
    from decimal import Decimal, ROUND_HALF_UP
    from app.models import Expense, ExpenseParticipant, Settlement
    from app.balances.engine import calculate_group_balances

    user_id = get_jwt_identity()
    removing_self = (target_user_id == user_id)

    member = GroupMember.query.filter_by(
        group_id=group_id, user_id=target_user_id
    ).first()
    if not member:
        return error_response('Member not found', 404)

    group = Group.query.get(group_id)
    mode = (request.get_json(silent=True) or {}).get('mode', 'settle')

    if mode == 'redistribute':
        # Redistribute leaving member's share among remaining participants per expense
        expenses = Expense.query.filter_by(group_id=group_id).all()
        for expense in expenses:
            leaving = ExpenseParticipant.query.filter_by(
                expense_id=expense.id, user_id=target_user_id
            ).first()
            if not leaving:
                continue

            remaining = ExpenseParticipant.query.filter(
                ExpenseParticipant.expense_id == expense.id,
                ExpenseParticipant.user_id != target_user_id,
            ).all()

            if remaining:
                extra = (leaving.share_amount / len(remaining)).quantize(
                    Decimal('0.01'), rounding=ROUND_HALF_UP
                )
                for p in remaining:
                    p.share_amount = (p.share_amount + extra).quantize(
                        Decimal('0.01'), rounding=ROUND_HALF_UP
                    )

            db.session.delete(leaving)

    elif mode == 'settle':
        # Create a confirmed settlement to zero out the member's net balance
        balances = calculate_group_balances(group_id)
        member_bal = next(
            (b for b in balances if b.user_id == target_user_id), None
        )

        if member_bal and member_bal.net_amount != 0:
            net = member_bal.net_amount
            others = [b for b in balances if b.user_id != target_user_id]

            if net < 0:
                # Member owes → settlement from them to biggest creditor
                creditor = max(others, key=lambda b: b.net_amount, default=None)
                if creditor:
                    db.session.add(Settlement(
                        group_id=group_id,
                        from_user_id=target_user_id,
                        to_user_id=creditor.user_id,
                        amount=abs(net),
                        currency=group.base_currency,
                        status='confirmed',
                    ))
            else:
                # Member is owed → settlement from biggest debtor to them
                debtor = min(others, key=lambda b: b.net_amount, default=None)
                if debtor:
                    db.session.add(Settlement(
                        group_id=group_id,
                        from_user_id=debtor.user_id,
                        to_user_id=target_user_id,
                        amount=net,
                        currency=group.base_currency,
                        status='confirmed',
                    ))

    db.session.delete(member)

    # If admin removed themselves, promote the next member (earliest joined_at)
    if removing_self:
        next_member = (
            GroupMember.query
            .filter(
                GroupMember.group_id == group_id,
                GroupMember.user_id != target_user_id,
            )
            .order_by(GroupMember.joined_at.asc())
            .first()
        )
        if next_member:
            next_member.role = 'admin'

    db.session.commit()
    return success_response(message='Member removed')


@groups_bp.post('/<group_id>/activate')
@jwt_required()
@require_group_admin
def activate_group(group_id, **kwargs):
    """
    Activate a free/limited group (beta: no real payment gateway).
    Body: { split_among_group: bool }
    """
    from app.groups.monetization_service import MonetizationService

    group = Group.query.get(group_id)
    if not group or not group.is_active:
        return error_response('Group not found', 404)

    if group.group_state == 'active':
        return error_response('הקבוצה כבר פעילה', 400)

    data = request.get_json(silent=True) or {}
    split_among_group = bool(data.get('split_among_group', True))
    payer_id = get_jwt_identity()

    try:
        result = MonetizationService.activate_group(group, payer_id, split_among_group)
    except ValueError as e:
        return error_response(str(e), 400)

    return success_response(data={**group.to_dict(), **result}, message='הקבוצה הופעלה בהצלחה')


@groups_bp.post('/<group_id>/extend')
@jwt_required()
@require_group_admin
def extend_group(group_id, **kwargs):
    """
    Extend an event group by 7 additional days (15 ILS).
    Body: { split_among_group: bool }
    """
    from app.groups.monetization_service import MonetizationService

    group = Group.query.get(group_id)
    if not group or not group.is_active:
        return error_response('Group not found', 404)

    if group.group_type != 'event':
        return error_response('הארכה זמינה רק לקבוצות אירוע', 400)

    data = request.get_json(silent=True) or {}
    split_among_group = bool(data.get('split_among_group', True))
    payer_id = get_jwt_identity()

    result = MonetizationService.extend_group(group, payer_id, split_among_group)
    return success_response(data={**group.to_dict(), **result}, message='הקבוצה הוארכה בהצלחה')


@groups_bp.post('/<group_id>/renew')
@jwt_required()
@require_group_admin
def renew_group(group_id, **kwargs):
    """
    Renew an ongoing group for another billing period.
    Body: { split_among_group: bool }
    """
    from app.groups.monetization_service import MonetizationService

    group = Group.query.get(group_id)
    if not group or not group.is_active:
        return error_response('Group not found', 404)

    if group.group_type != 'ongoing':
        return error_response('חידוש זמין רק לקבוצות שוטפות', 400)

    data = request.get_json(silent=True) or {}
    split_among_group = bool(data.get('split_among_group', True))
    payer_id = get_jwt_identity()

    try:
        result = MonetizationService.renew_group(group, payer_id, split_among_group)
    except ValueError as e:
        return error_response(str(e), 400)

    return success_response(data={**group.to_dict(), **result}, message='הקבוצה חודשה בהצלחה')


@groups_bp.post('/<group_id>/close')
@jwt_required()
@require_group_admin
def close_group(group_id, **kwargs):
    """
    Close a group (admin/creator only).
    If there are unsettled balances, returns a 409 with details.
    Pass force=true in the body to close anyway.
    """
    from app.balances.engine import calculate_group_balances

    user_id = get_jwt_identity()
    group = Group.query.get(group_id)
    if not group or not group.is_active:
        return error_response('Group not found', 404)

    if group.is_closed:
        return error_response('Group is already closed', 400)

    # Only the creator can close the group
    if group.created_by != user_id:
        return error_response('Only the group creator can close it', 403)

    data = request.get_json(silent=True) or {}
    force = data.get('force', False)

    # Check for unsettled balances
    balances = calculate_group_balances(group_id)
    unsettled = [b for b in balances if abs(float(b.net_amount)) > 0.01]

    if unsettled and not force:
        from app.models import User as _User
        details = []
        for b in unsettled:
            u = _User.query.get(b.user_id)
            name = u.display_name if u else b.user_id
            details.append({
                'user_id': b.user_id,
                'display_name': name,
                'net_amount': str(b.net_amount),
                'currency': group.base_currency,
            })
        return error_response(
            'יש חובות שטרם הוסדרו בקבוצה',
            409,
            errors={'unsettled': details}
        )

    from datetime import datetime, timezone
    group.is_closed = True
    group.closed_at = datetime.now(timezone.utc)
    db.session.commit()
    return success_response(data=group.to_dict(), message='הקבוצה נסגרה בהצלחה')


@groups_bp.get('/<group_id>/invite-link')
@jwt_required()
@require_group_member
def get_invite_link(group_id, **kwargs):
    group = Group.query.get(group_id)
    if not group:
        return error_response('Group not found', 404)

    return success_response(data={
        'invite_code': group.invite_code,
        'invite_link': f'shareflow://join/{group.invite_code}',
        'share_text': f'Join my group "{group.name}" on ADL ShareFlow!\nsf://join/{group.invite_code}',
    })


@groups_bp.post('/<group_id>/invite/email')
@jwt_required()
@require_group_member
def invite_by_email(group_id, **kwargs):
    """Send a group invitation to an email address."""
    from app.email_service import send_group_invitation

    user_id = get_jwt_identity()
    group = Group.query.get(group_id)
    if not group or not group.is_active:
        return error_response('Group not found', 404)

    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip().lower()
    if not email or '@' not in email:
        return error_response('כתובת אימייל לא תקינה')

    inviter = User.query.get(user_id)
    inviter_name = inviter.display_name if inviter else 'חבר'

    # Determine group emoji by category
    emoji_map = {
        'apartment': '🏠', 'trip': '✈️', 'vehicle': '🚗',
        'event': '🎉',
    }
    group_emoji = emoji_map.get(group.category or '', '👥')

    sent = send_group_invitation(
        to_email=email,
        inviter_name=inviter_name,
        group_name=group.name,
        invite_code=group.invite_code,
        group_emoji=group_emoji,
    )

    if not sent:
        return error_response(
            'שירות המייל אינו מוגדר. הוסף RESEND_API_KEY ל-.env',
            503,
        )

    return success_response(message=f'הזמנה נשלחה ל-{email}')


@groups_bp.get('/check/<invite_code>')
@jwt_required()
def check_invite(invite_code):
    """Check invite code validity and return expense count before joining."""
    from app.models import Expense
    user_id = get_jwt_identity()
    group = Group.query.filter_by(invite_code=invite_code.upper(), is_active=True).first()
    if not group:
        return error_response('Invalid or expired invite code', 404)

    already_member = GroupMember.query.filter_by(
        group_id=group.id, user_id=user_id
    ).first() is not None

    expense_count = Expense.query.filter_by(group_id=group.id).count()
    member_count = GroupMember.query.filter_by(group_id=group.id).count()

    return success_response(data={
        'group': group.to_dict(),
        'already_member': already_member,
        'expense_count': expense_count,
        'member_count': member_count,
        'has_expenses': expense_count > 0,
    })


@groups_bp.post('/join/<invite_code>')
@jwt_required()
def join_group(invite_code):
    """
    Join a group via invite code.
    split_mode:
      'forward' (default) — new member participates only in future expenses
      'full'              — retroactively add member to all existing expenses
    """
    from decimal import Decimal, ROUND_HALF_UP
    from app.models import Expense, ExpenseParticipant

    user_id = get_jwt_identity()
    group = Group.query.filter_by(invite_code=invite_code.upper(), is_active=True).first()
    if not group:
        return error_response('Invalid or expired invite code', 404)

    existing = GroupMember.query.filter_by(group_id=group.id, user_id=user_id).first()
    if existing:
        return error_response('You are already a member of this group')

    split_mode = (request.get_json(silent=True) or {}).get('split_mode', 'forward')

    # Add the new member
    member = GroupMember(group_id=group.id, user_id=user_id, role='member')
    db.session.add(member)
    db.session.flush()

    if split_mode == 'full':
        # Retroactively add the new member to all existing expenses
        expenses = Expense.query.filter_by(group_id=group.id).all()
        for expense in expenses:
            participants = ExpenseParticipant.query.filter_by(
                expense_id=expense.id
            ).all()

            # Skip if already a participant (safety check)
            participant_ids = {p.user_id for p in participants}
            if user_id in participant_ids:
                continue

            all_member_ids = list(participant_ids) + [user_id]
            n = len(all_member_ids)

            # Recalculate equal shares with rounding correction
            base_share = (expense.converted_amount / n).quantize(
                Decimal('0.01'), rounding=ROUND_HALF_UP
            )
            total_distributed = base_share * (n - 1)
            last_share = (expense.converted_amount - total_distributed).quantize(
                Decimal('0.01'), rounding=ROUND_HALF_UP
            )

            # Update existing participants
            for i, p in enumerate(participants):
                p.share_amount = base_share if i < len(participants) - 1 else last_share

            # Add new participant with last share (corrected for rounding)
            db.session.add(ExpenseParticipant(
                expense_id=expense.id,
                user_id=user_id,
                share_amount=base_share,
            ))

    db.session.commit()

    expense_count = Expense.query.filter_by(group_id=group.id).count()
    result = group.to_dict()
    result['split_mode'] = split_mode
    result['retroactive_expenses'] = expense_count if split_mode == 'full' else 0

    return success_response(data=result, status_code=201)
