"""
ADL Dashboard API — admin endpoints for the ADL Platform integration.
Requires X-ADL-Admin-Key header (set ADL_ADMIN_KEY in .env).
"""
import os
from datetime import datetime, timedelta, timezone

from flask import Blueprint, request
from sqlalchemy import func

from app import db
from app.models import (
    User, Group, GroupMember, Expense, Receipt, Settlement,
    Notification, FeatureFlag, GroupPayment, FCMToken,
)
from app.common.errors import success_response, error_response

dashboard_bp = Blueprint('dashboard', __name__)


def _require_adl_admin():
    adl_key = request.headers.get('X-ADL-Admin-Key', '')
    expected = os.getenv('ADL_ADMIN_KEY', '')
    if not expected or adl_key != expected:
        return error_response('ADL admin access required', 403)
    return None


def _platform_map(user_ids: list[str]) -> dict[str, str]:
    """Latest FCM platform per user (ios/android)."""
    if not user_ids:
        return {}
    rows = (
        db.session.query(FCMToken.user_id, FCMToken.platform, FCMToken.created_at)
        .filter(FCMToken.user_id.in_(user_ids))
        .order_by(FCMToken.created_at.desc())
        .all()
    )
    result = {}
    for uid, platform, _ in rows:
        if uid not in result:
            result[uid] = platform
    return result


def _user_admin_dict(user: User, platform: str | None = None) -> dict:
    d = user.to_dict()
    d['platform'] = platform
    d['group_count'] = GroupMember.query.filter_by(user_id=user.id).count()
    d['expense_count'] = Expense.query.filter_by(paid_by=user.id).count()
    return d


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

@dashboard_bp.get('/stats')
def adl_stats():
    err = _require_adl_admin()
    if err:
        return err

    now = datetime.now(timezone.utc)
    last_30 = now - timedelta(days=30)
    last_7 = now - timedelta(days=7)
    last_1 = now - timedelta(days=1)

    total_users = User.query.count()
    active_users = User.query.filter_by(is_active=True).count()
    pro_users = User.query.filter_by(plan='pro').count()
    new_users_30d = User.query.filter(User.created_at >= last_30).count()
    new_users_7d = User.query.filter(User.created_at >= last_7).count()
    dau = User.query.filter(User.last_login_at >= last_1).count()
    wau = User.query.filter(User.last_login_at >= last_7).count()
    ios_users = (
        db.session.query(func.count(func.distinct(FCMToken.user_id)))
        .filter(FCMToken.platform == 'ios')
        .scalar()
        or 0
    )
    android_users = (
        db.session.query(func.count(func.distinct(FCMToken.user_id)))
        .filter(FCMToken.platform == 'android')
        .scalar()
        or 0
    )

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
            'dau': dau,
            'wau': wau,
            'ios': ios_users,
            'android': android_users,
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
            'pending': Settlement.query.filter_by(status='pending').count(),
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

    group = db.session.get(Group, group_id)
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
    platforms = _platform_map([u.id for u in users])

    return success_response(data={
        'users': [_user_admin_dict(u, platforms.get(u.id)) for u in users],
        'pagination': {'total': total, 'page': page, 'per_page': per_page},
    })


@dashboard_bp.get('/users/<user_id>')
def adl_user_detail(user_id):
    err = _require_adl_admin()
    if err:
        return err

    user = db.session.get(User, user_id)
    if not user:
        return error_response('User not found', 404)

    platforms = _platform_map([user.id])
    memberships = GroupMember.query.filter_by(user_id=user.id).all()
    group_ids = [m.group_id for m in memberships]
    groups = Group.query.filter(Group.id.in_(group_ids)).all() if group_ids else []
    expenses = (
        Expense.query.filter_by(paid_by=user.id)
        .order_by(Expense.created_at.desc())
        .limit(30)
        .all()
    )
    settlements = (
        Settlement.query.filter(
            (Settlement.from_user_id == user.id) | (Settlement.to_user_id == user.id)
        )
        .order_by(Settlement.created_at.desc())
        .limit(30)
        .all()
    )

    group_map = {g.id: g.name for g in groups}
    return success_response(data={
        'user': _user_admin_dict(user, platforms.get(user.id)),
        'groups': [
            {
                'id': g.id,
                'name': g.name,
                'group_type': g.group_type,
                'group_state': g.group_state,
                'role': next((m.role for m in memberships if m.group_id == g.id), None),
            }
            for g in groups
        ],
        'expenses': [
            {
                **e.to_dict(),
                'group_name': group_map.get(e.group_id, e.group_id),
            }
            for e in expenses
        ],
        'settlements': [
            {
                **s.to_dict(),
                'group_name': group_map.get(s.group_id)
                or (db.session.get(Group, s.group_id).name if db.session.get(Group, s.group_id) else s.group_id),
                'from_name': s.from_user.display_name if s.from_user else s.from_user_id,
                'to_name': s.to_user.display_name if s.to_user else s.to_user_id,
            }
            for s in settlements
        ],
    })


@dashboard_bp.put('/users/<user_id>/suspend')
def suspend_user(user_id):
    err = _require_adl_admin()
    if err:
        return err

    user = db.session.get(User, user_id)
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

    user = db.session.get(User, user_id)
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

    user = db.session.get(User, user_id)
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


@dashboard_bp.get('/revenue')
def adl_revenue():
    err = _require_adl_admin()
    if err:
        return err

    now = datetime.now(timezone.utc)

    def _sum_from(since):
        result = db.session.query(func.sum(GroupPayment.amount))\
            .filter(GroupPayment.created_at >= since).scalar()
        return float(result or 0)

    def _count_from(since):
        return GroupPayment.query.filter(GroupPayment.created_at >= since).count()

    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = today_start - timedelta(days=now.weekday())
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    year_start = now.replace(month=1, day=1, hour=0, minute=0, second=0, microsecond=0)

    total_all = float(db.session.query(func.sum(GroupPayment.amount)).scalar() or 0)
    count_all = GroupPayment.query.count()

    return success_response(data={
        'today':   {'amount': _sum_from(today_start), 'count': _count_from(today_start)},
        'week':    {'amount': _sum_from(week_start),  'count': _count_from(week_start)},
        'month':   {'amount': _sum_from(month_start), 'count': _count_from(month_start)},
        'year':    {'amount': _sum_from(year_start),  'count': _count_from(year_start)},
        'total':   {'amount': total_all,              'count': count_all},
    })


# ---------------------------------------------------------------------------
# Pilot activity + settlements (reuse existing tables)
# ---------------------------------------------------------------------------

@dashboard_bp.get('/activity')
def adl_activity():
    """Unified recent activity feed from existing models (no audit table)."""
    err = _require_adl_admin()
    if err:
        return err

    limit = min(request.args.get('limit', 40, type=int), 100)
    events = []

    for u in User.query.filter(User.is_guest.is_(False)).order_by(User.created_at.desc()).limit(20):
        events.append({
            'type': 'registration',
            'at': u.created_at.isoformat() if u.created_at else None,
            'user_id': u.id,
            'user_name': u.display_name,
            'summary': f'{u.display_name} נרשם/ה',
        })

    for g in Group.query.order_by(Group.created_at.desc()).limit(20):
        creator = db.session.get(User, g.created_by)
        events.append({
            'type': 'group_created',
            'at': g.created_at.isoformat() if g.created_at else None,
            'user_id': g.created_by,
            'user_name': creator.display_name if creator else g.created_by,
            'group_id': g.id,
            'group_name': g.name,
            'summary': f'נוצרה קבוצה «{g.name}»',
        })

    for e in Expense.query.order_by(Expense.created_at.desc()).limit(20):
        payer = db.session.get(User, e.paid_by)
        group = db.session.get(Group, e.group_id)
        events.append({
            'type': 'expense_created',
            'at': e.created_at.isoformat() if e.created_at else None,
            'user_id': e.paid_by,
            'user_name': payer.display_name if payer else e.paid_by,
            'group_id': e.group_id,
            'group_name': group.name if group else e.group_id,
            'amount': str(e.original_amount),
            'currency': e.original_currency,
            'summary': f'הוצאה: {e.title} · {e.original_amount} {e.original_currency}',
        })

    for s in Settlement.query.order_by(Settlement.created_at.desc()).limit(20):
        from_u = s.from_user
        to_u = s.to_user
        group = db.session.get(Group, s.group_id)
        events.append({
            'type': 'settlement',
            'at': s.created_at.isoformat() if s.created_at else None,
            'user_id': s.from_user_id,
            'user_name': from_u.display_name if from_u else s.from_user_id,
            'group_id': s.group_id,
            'group_name': group.name if group else s.group_id,
            'amount': str(s.amount),
            'currency': s.currency,
            'status': s.status,
            'summary': (
                f'תשלום {s.amount} {s.currency}: '
                f'{from_u.display_name if from_u else "?"} → {to_u.display_name if to_u else "?"} '
                f'({s.status})'
            ),
        })

    events = [e for e in events if e.get('at')]
    events.sort(key=lambda x: x['at'], reverse=True)
    return success_response(data={'events': events[:limit]})


@dashboard_bp.get('/settlements')
def adl_settlements():
    err = _require_adl_admin()
    if err:
        return err

    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 50, type=int), 200)
    status = request.args.get('status', '').strip()
    user_id = request.args.get('user_id', '').strip()
    group_id = request.args.get('group_id', '').strip()
    date_from = request.args.get('from', '').strip()
    date_to = request.args.get('to', '').strip()

    q = Settlement.query
    if status:
        q = q.filter_by(status=status)
    if group_id:
        q = q.filter_by(group_id=group_id)
    if user_id:
        q = q.filter(
            (Settlement.from_user_id == user_id) | (Settlement.to_user_id == user_id)
        )
    if date_from:
        try:
            q = q.filter(Settlement.created_at >= datetime.fromisoformat(date_from))
        except ValueError:
            pass
    if date_to:
        try:
            q = q.filter(Settlement.created_at <= datetime.fromisoformat(date_to))
        except ValueError:
            pass

    q = q.order_by(Settlement.created_at.desc())
    total = q.count()
    rows = q.offset((page - 1) * per_page).limit(per_page).all()

    result = []
    for s in rows:
        group = db.session.get(Group, s.group_id)
        result.append({
            'id': s.id,
            'created_at': s.created_at.isoformat() if s.created_at else None,
            'confirmed_at': s.confirmed_at.isoformat() if s.confirmed_at else None,
            'group_id': s.group_id,
            'group_name': group.name if group else s.group_id,
            'from_user_id': s.from_user_id,
            'from_name': s.from_user.display_name if s.from_user else s.from_user_id,
            'to_user_id': s.to_user_id,
            'to_name': s.to_user.display_name if s.to_user else s.to_user_id,
            'transaction_type': 'settlement',
            'amount': str(s.amount),
            'currency': s.currency,
            'status': s.status,
        })

    return success_response(data={
        'settlements': result,
        'pagination': {'total': total, 'page': page, 'per_page': per_page},
    })
