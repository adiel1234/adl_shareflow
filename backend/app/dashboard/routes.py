"""
ADL Dashboard API — admin endpoints for the ADL Platform integration.
Requires X-ADL-Admin-Key header (set ADL_ADMIN_KEY in .env).
"""
import os
from datetime import datetime, timedelta

from flask import Blueprint, request
from sqlalchemy import func

from app import db
from app.models import User, Group, GroupMember, Expense, Receipt, Settlement, Notification, FeatureFlag, GroupPayment
from app.common.errors import success_response, error_response

dashboard_bp = Blueprint('dashboard', __name__)


def _require_adl_admin():
    adl_key = request.headers.get('X-ADL-Admin-Key', '')
    expected = os.getenv('ADL_ADMIN_KEY', '')
    if not expected or adl_key != expected:
        return error_response('ADL admin access required', 403)
    return None


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

@dashboard_bp.get('/stats')
def adl_stats():
    err = _require_adl_admin()
    if err:
        return err

    now = datetime.utcnow()
    last_30 = now - timedelta(days=30)
    last_7 = now - timedelta(days=7)

    total_users = User.query.count()
    active_users = User.query.filter_by(is_active=True).count()
    pro_users = User.query.filter_by(plan='pro').count()
    new_users_30d = User.query.filter(User.created_at >= last_30).count()
    new_users_7d = User.query.filter(User.created_at >= last_7).count()

    total_groups = Group.query.filter_by(is_active=True).count()
    active_groups_30d = db.session.query(func.count(func.distinct(Expense.group_id)))\
        .filter(Expense.created_at >= last_30).scalar() or 0

    total_expenses = Expense.query.count()
    expenses_30d = Expense.query.filter(Expense.created_at >= last_30).count()
    total_expense_volume = db.session.query(func.sum(Expense.converted_amount)).scalar() or 0

    total_receipts = Receipt.query.count()
    ocr_confirmed = Receipt.query.filter_by(status='confirmed').count()
    ocr_pending = Receipt.query.filter_by(status='pending').count()

    total_settlements = Settlement.query.count()
    confirmed_settlements = Settlement.query.filter_by(status='confirmed').count()

    # Monetization metrics
    groups_free = Group.query.filter_by(is_active=True, group_state='free').count()
    groups_limited = Group.query.filter_by(is_active=True, group_state='limited').count()
    groups_active_event = Group.query.filter_by(
        is_active=True, group_state='active', group_type='event').count()
    groups_active_ongoing = Group.query.filter_by(
        is_active=True, group_state='active', group_type='ongoing').count()
    groups_expired = Group.query.filter_by(is_active=True, group_state='expired').count()
    groups_read_only = Group.query.filter_by(is_active=True, group_state='read_only').count()

    total_activatable = groups_free + groups_limited
    total_converted = groups_active_event + groups_active_ongoing
    upgrade_rate = round(total_converted / (total_activatable + total_converted) * 100, 1) \
        if (total_activatable + total_converted) > 0 else 0

    total_payments = db.session.query(func.sum(GroupPayment.amount)).scalar() or 0
    payments_30d = db.session.query(func.sum(GroupPayment.amount))\
        .filter(GroupPayment.created_at >= last_30).scalar() or 0

    return success_response(data={
        'users': {
            'total': total_users,
            'active': active_users,
            'pro': pro_users,
            'free': total_users - pro_users,
            'new_30d': new_users_30d,
            'new_7d': new_users_7d,
        },
        'groups': {
            'total': total_groups,
            'active_30d': active_groups_30d,
        },
        'expenses': {
            'total': total_expenses,
            'last_30d': expenses_30d,
            'total_volume_ils': float(total_expense_volume),
        },
        'ocr': {
            'total_scans': total_receipts,
            'confirmed': ocr_confirmed,
            'pending': ocr_pending,
            'failed': total_receipts - ocr_confirmed - ocr_pending,
            'success_rate': round(ocr_confirmed / total_receipts * 100, 1) if total_receipts > 0 else 0,
        },
        'settlements': {
            'total': total_settlements,
            'confirmed': confirmed_settlements,
            'pending': total_settlements - confirmed_settlements,
        },
        'shareflow': {
            'groups_free': groups_free,
            'groups_limited': groups_limited,
            'groups_active_event': groups_active_event,
            'groups_active_ongoing': groups_active_ongoing,
            'groups_expired': groups_expired,
            'groups_read_only': groups_read_only,
            'upgrade_conversion_rate': f'{upgrade_rate}%',
            'total_revenue_ils': float(total_payments),
            'revenue_30d_ils': float(payments_30d),
        },
    })


# ---------------------------------------------------------------------------
# Monetization — manual group activation (beta)
# ---------------------------------------------------------------------------

@dashboard_bp.post('/groups/<group_id>/activate')
def adl_activate_group(group_id):
    """
    Manually activate a group from the ADL Dashboard (beta flow).
    Body: { split_among_group: bool }
    The activating admin's identity is set to the group creator.
    """
    err = _require_adl_admin()
    if err:
        return err

    group = Group.query.get(group_id)
    if not group:
        return error_response('Group not found', 404)

    if group.group_state == 'active':
        return error_response('Group is already active', 400)

    data = request.get_json(silent=True) or {}
    split_among_group = bool(data.get('split_among_group', False))

    from app.groups.monetization_service import MonetizationService
    try:
        result = MonetizationService.activate_group(
            group, payer_id=group.created_by, split_among_group=split_among_group
        )
    except ValueError as e:
        return error_response(str(e), 400)

    return success_response(data={**group.to_dict(), **result},
                            message=f'Group {group.name} activated')


@dashboard_bp.get('/monetization')
def adl_monetization():
    """
    Returns all groups with their lifecycle state for the monetization dashboard view.
    """
    err = _require_adl_admin()
    if err:
        return err

    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 50, type=int), 200)
    state_filter = request.args.get('state', '').strip()

    q = Group.query.filter_by(is_active=True)
    if state_filter:
        q = q.filter_by(group_state=state_filter)
    q = q.order_by(Group.created_at.desc())

    total = q.count()
    groups = q.offset((page - 1) * per_page).limit(per_page).all()

    result = []
    for g in groups:
        d = g.to_dict()
        d['member_count'] = GroupMember.query.filter_by(group_id=g.id).count()
        d['expense_count'] = Expense.query.filter_by(group_id=g.id).count()
        d['payment_count'] = 0
        result.append(d)

    return success_response(data={
        'groups': result,
        'pagination': {'total': total, 'page': page, 'per_page': per_page},
    })


# ---------------------------------------------------------------------------
# Users management
# ---------------------------------------------------------------------------

@dashboard_bp.get('/users')
def adl_users():
    err = _require_adl_admin()
    if err:
        return err

    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 50, type=int), 200)
    search = request.args.get('search', '').strip()
    plan_filter = request.args.get('plan', '').strip()

    q = User.query
    if search:
        q = q.filter(
            (User.email.ilike(f'%{search}%')) |
            (User.display_name.ilike(f'%{search}%'))
        )
    if plan_filter:
        q = q.filter_by(plan=plan_filter)

    q = q.order_by(User.created_at.desc())
    total = q.count()
    users = q.offset((page - 1) * per_page).limit(per_page).all()

    return success_response(data={
        'users': [u.to_dict() for u in users],
        'pagination': {'total': total, 'page': page, 'per_page': per_page},
    })


@dashboard_bp.put('/users/<user_id>/suspend')
def suspend_user(user_id):
    err = _require_adl_admin()
    if err:
        return err

    user = User.query.get(user_id)
    if not user:
        return error_response('User not found', 404)

    user.is_active = False
    db.session.commit()
    return success_response(message=f'User {user.email} suspended')


@dashboard_bp.put('/users/<user_id>/activate')
def activate_user(user_id):
    err = _require_adl_admin()
    if err:
        return err

    user = User.query.get(user_id)
    if not user:
        return error_response('User not found', 404)

    user.is_active = True
    db.session.commit()
    return success_response(message=f'User {user.email} activated')


@dashboard_bp.put('/users/<user_id>/set-plan')
def set_user_plan(user_id):
    err = _require_adl_admin()
    if err:
        return err

    data = request.get_json(silent=True) or {}
    plan = data.get('plan', 'free')
    if plan not in ('free', 'pro'):
        return error_response('plan must be free or pro')

    user = User.query.get(user_id)
    if not user:
        return error_response('User not found', 404)

    user.plan = plan
    db.session.commit()
    return success_response(message=f'User {user.email} plan set to {plan}')


# ---------------------------------------------------------------------------
# Groups
# ---------------------------------------------------------------------------

@dashboard_bp.get('/groups')
def adl_groups():
    err = _require_adl_admin()
    if err:
        return err

    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 50, type=int), 200)

    q = Group.query.order_by(Group.created_at.desc())
    total = q.count()
    groups = q.offset((page - 1) * per_page).limit(per_page).all()

    result = []
    for g in groups:
        d = g.to_dict()
        d['member_count'] = GroupMember.query.filter_by(group_id=g.id).count()
        d['expense_count'] = Expense.query.filter_by(group_id=g.id).count()
        result.append(d)

    return success_response(data={
        'groups': result,
        'pagination': {'total': total, 'page': page, 'per_page': per_page},
    })


# ---------------------------------------------------------------------------
# OCR Stats
# ---------------------------------------------------------------------------

@dashboard_bp.get('/ocr-stats')
def adl_ocr_stats():
    err = _require_adl_admin()
    if err:
        return err

    total = Receipt.query.count()
    pending = Receipt.query.filter_by(status='pending').count()
    confirmed = Receipt.query.filter_by(status='confirmed').count()
    failed = Receipt.query.filter_by(status='failed').count()

    return success_response(data={
        'total': total,
        'pending': pending,
        'confirmed': confirmed,
        'failed': failed,
        'success_rate': round(confirmed / total * 100, 1) if total > 0 else 0,
    })


# ---------------------------------------------------------------------------
# Feature Flags
# ---------------------------------------------------------------------------

@dashboard_bp.get('/feature-flags')
def adl_feature_flags():
    err = _require_adl_admin()
    if err:
        return err

    flags = FeatureFlag.query.all()
    return success_response(data={
        'flags': [{'key': f.key, 'value': f.value, 'description': f.description} for f in flags]
    })


@dashboard_bp.put('/feature-flags/<key>')
def update_feature_flag(key):
    err = _require_adl_admin()
    if err:
        return err

    data = request.get_json(silent=True) or {}
    flag = FeatureFlag.query.filter_by(key=key).first()
    if not flag:
        flag = FeatureFlag(key=key)
        db.session.add(flag)

    flag.value = data.get('value')
    flag.description = data.get('description', flag.description)
    db.session.commit()
    return success_response(data={'key': flag.key, 'value': flag.value})


@dashboard_bp.delete('/feature-flags/<key>')
def delete_feature_flag(key):
    err = _require_adl_admin()
    if err:
        return err

    flag = FeatureFlag.query.filter_by(key=key).first()
    if not flag:
        return error_response('Flag not found', 404)

    db.session.delete(flag)
    db.session.commit()
    return success_response(message=f'Flag {key} deleted')
