"""
ADL Dashboard API — admin endpoints for the ADL Platform integration.
Requires X-ADL-Admin-Key header (set ADL_ADMIN_KEY in .env).
"""
import os
from datetime import datetime, timedelta, timezone

from flask import Blueprint, request
from sqlalchemy import func, text

from app import db
from app.models import (
    User, Group, GroupMember, Expense, Receipt, Settlement,
    Notification, FeatureFlag, GroupPayment, FCMToken, PilotFunnelEvent,
)
from app.common.errors import success_response, error_response
from app.pilot_mode import (
    PILOT_STARTED_FLAG,
    is_pilot_mode_enabled,
    set_pilot_mode,
)

dashboard_bp = Blueprint('dashboard', __name__)
_PILOT_USER_TABLES = (
    'period_debts',
    'period_reports',
    'scheduled_reminders',
    'reminder_settings',
    'notifications',
    'receipts',
    'expense_participants',
    'expenses',
    'settlements',
    'group_payments',
    'group_members',
    'groups',
    'fcm_tokens',
    'refresh_tokens',
    'password_reset_tokens',
    'user_identities',
    'subscriptions',
    'deferred_links',
    'pilot_funnel_events',
    'users',
)


def _require_adl_admin():
    adl_key = request.headers.get('X-ADL-Admin-Key', '')
    expected = os.getenv('ADL_ADMIN_KEY', '')
    if not expected or adl_key != expected:
        return error_response('ADL admin access required', 403)
    return None


def _pilot_cutoff():
    """When scope=pilot, return PILOT_STARTED_AT cutoff (or far-future if unset → empty)."""
    if request.args.get('scope') != 'pilot':
        return None
    flag = FeatureFlag.query.filter_by(key=PILOT_STARTED_FLAG).first()
    raw = flag.value if flag else None
    if raw is None or (isinstance(raw, str) and not raw.strip()):
        # Pilot mode without a start mark: show nothing (clean slate until reset).
        return datetime.now(timezone.utc) + timedelta(days=36500)
    try:
        text_val = str(raw).strip().strip('"').replace('Z', '+00:00')
        return datetime.fromisoformat(text_val)
    except ValueError:
        return datetime.now(timezone.utc) + timedelta(days=36500)


def _with_cutoff(query, column, cutoff):
    if cutoff is None:
        return query
    return query.filter(column >= cutoff)


def _pilot_started_value() -> str | None:
    flag = FeatureFlag.query.filter_by(key=PILOT_STARTED_FLAG).first()
    return flag.value if flag else None


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


def _set_pilot_started_at(when: datetime | None = None) -> str:
    when = when or datetime.now(timezone.utc)
    value = when.isoformat()
    flag = FeatureFlag.query.filter_by(key=PILOT_STARTED_FLAG).first()
    if not flag:
        flag = FeatureFlag(
            key=PILOT_STARTED_FLAG,
            description='תחילת פיילוט — סינון דשבורד (scope=pilot)',
        )
        db.session.add(flag)
    flag.value = value
    return value


def _wipe_user_data() -> None:
    """Delete all user-generated rows. Keeps feature_flags, plans, exchange_rates."""
    tables = ', '.join(_PILOT_USER_TABLES)
    db.session.execute(text(f'TRUNCATE TABLE {tables} RESTART IDENTITY CASCADE'))


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

@dashboard_bp.get('/stats')
def adl_stats():
    err = _require_adl_admin()
    if err:
        return err

    cutoff = _pilot_cutoff()
    now = datetime.now(timezone.utc)
    last_30 = now - timedelta(days=30)
    last_7 = now - timedelta(days=7)
    last_1 = now - timedelta(days=1)

    users_q = _with_cutoff(User.query, User.created_at, cutoff)
    total_users = users_q.count()
    active_users = users_q.filter_by(is_active=True).count()
    pro_users = users_q.filter_by(plan='pro').count()
    new_users_30d = _with_cutoff(User.query, User.created_at, cutoff).filter(
        User.created_at >= last_30
    ).count()
    new_users_7d = _with_cutoff(User.query, User.created_at, cutoff).filter(
        User.created_at >= last_7
    ).count()
    dau = _with_cutoff(User.query, User.created_at, cutoff).filter(
        User.last_login_at >= last_1
    ).count()
    wau = _with_cutoff(User.query, User.created_at, cutoff).filter(
        User.last_login_at >= last_7
    ).count()

    if cutoff is not None:
        pilot_user_ids = [uid for (uid,) in db.session.query(User.id).filter(User.created_at >= cutoff).all()]
        if not pilot_user_ids:
            ios_users = 0
            android_users = 0
        else:
            ios_users = (
                db.session.query(func.count(func.distinct(FCMToken.user_id)))
                .filter(FCMToken.platform == 'ios', FCMToken.user_id.in_(pilot_user_ids))
                .scalar()
                or 0
            )
            android_users = (
                db.session.query(func.count(func.distinct(FCMToken.user_id)))
                .filter(FCMToken.platform == 'android', FCMToken.user_id.in_(pilot_user_ids))
                .scalar()
                or 0
            )
    else:
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

    groups_q = _with_cutoff(Group.query, Group.created_at, cutoff).filter_by(is_active=True)
    total_groups = groups_q.count()
    active_groups_30d = (
        _with_cutoff(
            db.session.query(func.count(func.distinct(Expense.group_id))),
            Expense.created_at,
            cutoff,
        )
        .filter(Expense.created_at >= last_30)
        .scalar()
        or 0
    )

    total_expenses = _with_cutoff(Expense.query, Expense.created_at, cutoff).count()
    expenses_30d = _with_cutoff(Expense.query, Expense.created_at, cutoff).filter(
        Expense.created_at >= last_30
    ).count()
    total_expense_volume = (
        _with_cutoff(
            db.session.query(func.sum(Expense.converted_amount)),
            Expense.created_at,
            cutoff,
        ).scalar()
        or 0
    )

    receipts_q = _with_cutoff(Receipt.query, Receipt.created_at, cutoff)
    total_receipts = receipts_q.count()
    ocr_confirmed = receipts_q.filter_by(status='confirmed').count()
    ocr_pending = receipts_q.filter_by(status='pending').count()

    settlements_q = _with_cutoff(Settlement.query, Settlement.created_at, cutoff)
    total_settlements = settlements_q.count()
    confirmed_settlements = settlements_q.filter_by(status='confirmed').count()
    pending_settlements = settlements_q.filter_by(status='pending').count()

    # Monetization metrics
    groups_free = groups_q.filter_by(group_state='free').count()
    groups_limited = groups_q.filter_by(group_state='limited').count()
    groups_active_event = groups_q.filter_by(
        group_state='active', group_type='event'
    ).count()
    groups_active_ongoing = groups_q.filter_by(
        group_state='active', group_type='ongoing'
    ).count()
    groups_expired = groups_q.filter_by(group_state='expired').count()
    groups_read_only = groups_q.filter_by(group_state='read_only').count()

    total_activatable = groups_free + groups_limited
    total_converted = groups_active_event + groups_active_ongoing
    upgrade_rate = (
        round(total_converted / (total_activatable + total_converted) * 100, 1)
        if (total_activatable + total_converted) > 0
        else 0
    )

    total_payments = (
        _with_cutoff(
            db.session.query(func.sum(GroupPayment.amount)),
            GroupPayment.created_at,
            cutoff,
        ).scalar()
        or 0
    )
    payments_30d = (
        _with_cutoff(
            db.session.query(func.sum(GroupPayment.amount)),
            GroupPayment.created_at,
            cutoff,
        )
        .filter(GroupPayment.created_at >= last_30)
        .scalar()
        or 0
    )

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
            'pending': pending_settlements,
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
        'pilot_started_at': _pilot_started_value(),
        'pilot_mode_enabled': is_pilot_mode_enabled(),
        'downloads': _funnel_stats(cutoff),
    })


def _funnel_stats(cutoff):
    """Anonymous install-funnel counts (+ recent events) for the pilot dashboard."""
    def _base():
        q = PilotFunnelEvent.query
        if cutoff is not None:
            q = q.filter(PilotFunnelEvent.created_at >= cutoff)
        return q

    def _count(event: str) -> int:
        return _base().filter(PilotFunnelEvent.event == event).count()

    recent = (
        _base()
        .order_by(PilotFunnelEvent.created_at.desc())
        .limit(40)
        .all()
    )
    labels = {
        'pilot_join': 'פתיחת הזמנה',
        'getting_started': 'עמוד התקנה',
        'testflight_app': 'הורדת TestFlight',
        'shareflow_ios': 'הורדת ShareFlow (אייפון)',
        'apk': 'הורדת APK (אנדרואיד)',
    }
    ios_dl = _count('shareflow_ios')
    apk_dl = _count('apk')
    return {
        'pilot_join': _count('pilot_join'),
        'getting_started': _count('getting_started'),
        'testflight_app': _count('testflight_app'),
        'shareflow_ios': ios_dl,
        'apk': apk_dl,
        'total_downloads': ios_dl + apk_dl,
        'recent': [
            {
                **e.to_dict(),
                'label': labels.get(e.event, e.event),
            }
            for e in recent
        ],
    }


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

    q = _with_cutoff(User.query, User.created_at, _pilot_cutoff())
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

    cutoff = _pilot_cutoff()
    if cutoff is not None and (not user.created_at or user.created_at < cutoff):
        return error_response('User not found', 404)

    platforms = _platform_map([user.id])
    from app.models import FCMToken
    tokens = FCMToken.query.filter_by(user_id=user.id).all()
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
        'fcm_tokens': [
            {
                'id': t.id,
                'platform': t.platform,
                'created_at': t.created_at.isoformat() if t.created_at else None,
                'token_prefix': (t.token or '')[:16],
            }
            for t in tokens
        ],
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


@dashboard_bp.post('/users/<user_id>/test-push')
def adl_user_test_push(user_id):
    """Admin: send a test FCM push to a specific user (sync)."""
    err = _require_adl_admin()
    if err:
        return err

    user = db.session.get(User, user_id)
    if not user:
        return error_response('User not found', 404)

    from app.models import FCMToken
    from app.notifications import fcm_service

    tokens = FCMToken.query.filter_by(user_id=user_id).all()
    app = fcm_service._get_app()
    firebase_ok = app is not None
    sent = 0
    if firebase_ok:
        sent = fcm_service._send_to_user_impl(
            user_id,
            'בדיקת פוש — ADL ShareFlow',
            f'היי {user.display_name}, אם אתה רואה את זה — הפושים עובדים',
            {'type': 'test'},
        )

    return success_response(data={
        'user_id': user_id,
        'display_name': user.display_name,
        'firebase_initialized': firebase_ok,
        'token_count': len(tokens),
        'platforms': sorted({t.platform for t in tokens}),
        'sent': sent,
    })


@dashboard_bp.post('/users/<user_id>/demo-notifications')
def adl_user_demo_notifications(user_id):
    """Admin: create one in-app (+ push) sample for each notification UX type."""
    err = _require_adl_admin()
    if err:
        return err

    user = db.session.get(User, user_id)
    if not user:
        return error_response('User not found', 404)

    from app.models import Notification
    from app.notifications import fcm_service

    samples = [
        {
            'type': 'settlement_requested',
            'title': 'בקשת הסדר חוב',
            'body': 'דוגמה: דני ביקש לסגור חוב של 50.00 ILS — דורש אישור שלך',
            'data': {'group_id': '', 'settlement_id': ''},
        },
        {
            'type': 'payment_reminder',
            'title': 'תזכורת תשלום',
            'body': 'דוגמה: יש לך חוב פתוח בקבוצה — מומלץ להסדיר',
            'data': {'group_id': ''},
        },
        {
            'type': 'tier_upgrade_required',
            'title': 'נדרש שדרוג',
            'body': 'דוגמה: הקבוצה עברה את מגבלת החינם — נדרשת הפעלה',
            'data': {'group_id': ''},
        },
        {
            'type': 'group_expiring_soon',
            'title': 'הקבוצה עומדת לפוג',
            'body': 'דוגמה: נותרו 3 ימים עד סיום התקופה',
            'data': {'group_id': ''},
        },
        {
            'type': 'new_expense',
            'title': 'הוצאה חדשה',
            'body': 'דוגמה: מיכל הוסיפה הוצאה של 120.00 ILS — סופרמרקט',
            'data': {'group_id': ''},
        },
        {
            'type': 'settlement_confirmed',
            'title': 'תשלום אושר',
            'body': 'דוגמה: יוסי אישר קבלת תשלום של 50.00 ILS',
            'data': {'group_id': ''},
        },
        {
            'type': 'member_joined',
            'title': 'חבר חדש',
            'body': 'דוגמה: נועה הצטרפה לקבוצה',
            'data': {'group_id': ''},
        },
        {
            'type': 'event_summary',
            'title': 'סיכום אירוע',
            'body': 'דוגמה: סיכום האירוע מוכן לצפייה',
            'data': {'group_id': ''},
        },
        {
            'type': 'group_activated',
            'title': 'הקבוצה הופעלה',
            'body': 'דוגמה: הקבוצה הופעלה בהצלחה',
            'data': {'group_id': ''},
        },
    ]

    created = []
    for sample in samples:
        notif = Notification(
            user_id=user_id,
            type=sample['type'],
            title=sample['title'],
            body=sample['body'],
            data=sample['data'],
        )
        db.session.add(notif)
        created.append(sample['type'])
    db.session.commit()

    # One push after all rows exist — badge = real unread count.
    sent = fcm_service._send_to_user_impl(
        user_id,
        'התראות לדוגמה',
        f'נוספו {len(created)} התראות לבדיקה (פעולה + מידע)',
        {'type': 'demo_batch'},
    )

    unread = Notification.query.filter_by(user_id=user_id, is_read=False).count()
    return success_response(data={
        'user_id': user_id,
        'created_types': created,
        'unread_count': unread,
        'push_sent': sent,
    })


@dashboard_bp.post('/users/<user_id>/clear-badge')
def adl_user_clear_badge(user_id):
    """Admin: mark all notifications read and push badge=0 to clear home-screen badge."""
    err = _require_adl_admin()
    if err:
        return err

    user = db.session.get(User, user_id)
    if not user:
        return error_response('User not found', 404)

    from app.models import Notification
    from app.notifications import fcm_service

    Notification.query.filter_by(user_id=user_id, is_read=False).update(
        {'is_read': True}
    )
    db.session.commit()

    sent = fcm_service._sync_badge_impl(user_id, 0)
    return success_response(data={
        'user_id': user_id,
        'unread_count': 0,
        'push_sent': sent,
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
    cutoff = _pilot_cutoff()
    events = []

    users_q = _with_cutoff(User.query.filter(User.is_guest.is_(False)), User.created_at, cutoff)
    for u in users_q.order_by(User.created_at.desc()).limit(20):
        events.append({
            'type': 'registration',
            'at': u.created_at.isoformat() if u.created_at else None,
            'user_id': u.id,
            'user_name': u.display_name,
            'summary': f'{u.display_name} נרשם/ה',
        })

    groups_q = _with_cutoff(Group.query, Group.created_at, cutoff)
    for g in groups_q.order_by(Group.created_at.desc()).limit(20):
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

    expenses_q = _with_cutoff(Expense.query, Expense.created_at, cutoff)
    for e in expenses_q.order_by(Expense.created_at.desc()).limit(20):
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

    settlements_q = _with_cutoff(Settlement.query, Settlement.created_at, cutoff)
    for s in settlements_q.order_by(Settlement.created_at.desc()).limit(20):
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

    q = _with_cutoff(Settlement.query, Settlement.created_at, _pilot_cutoff())
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


@dashboard_bp.post('/pilot/reset')
def adl_pilot_reset():
    """
    Wipe all user-generated data and mark pilot start time.
    Keeps feature_flags (except overwriting PILOT_STARTED_AT), plans, exchange_rates.
    Body: { "confirm": "RESET_PILOT_DATA" }
    """
    err = _require_adl_admin()
    if err:
        return err

    data = request.get_json(silent=True) or {}
    if data.get('confirm') != 'RESET_PILOT_DATA':
        return error_response('confirm must be RESET_PILOT_DATA', 400)

    # Preserve PAYMENTS_ENABLED and other flags across TRUNCATE (flags table not truncated).
    _wipe_user_data()
    started = _set_pilot_started_at()
    db.session.commit()
    mode = set_pilot_mode(True)

    return success_response(
        data={'pilot_started_at': started, **mode},
        message='Pilot data wiped; dashboard scope=pilot starts empty',
    )


@dashboard_bp.get('/pilot/mode')
def adl_pilot_mode_get():
    err = _require_adl_admin()
    if err:
        return err
    return success_response(data={
        'pilot_mode_enabled': is_pilot_mode_enabled(),
        'pilot_started_at': _pilot_started_value(),
    })


@dashboard_bp.put('/pilot/mode')
def adl_pilot_mode_set():
    """
    Enable/disable pilot mode.
    Body: { "enabled": true|false }
    When disabled: all account_mode=pilot users are blocked and must re-register
    as active (same email/OAuth identity is allowed and becomes active).
    """
    err = _require_adl_admin()
    if err:
        return err

    data = request.get_json(silent=True) or {}
    if 'enabled' not in data:
        return error_response('enabled is required', 400)

    enabled = data.get('enabled')
    if isinstance(enabled, str):
        enabled = enabled.strip().lower() in ('true', '1', 'yes')
    else:
        enabled = bool(enabled)

    result = set_pilot_mode(enabled)
    return success_response(
        data=result,
        message='Pilot mode enabled' if enabled else 'Pilot mode disabled; pilot users blocked',
    )
