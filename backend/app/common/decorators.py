from functools import wraps
from flask import request
from flask_jwt_extended import get_jwt_identity
from app.common.errors import error_response
from app.models import GroupMember


def require_group_member(f):
    """Ensures the current user is a member of the group (group_id from URL)."""
    @wraps(f)
    def decorated(*args, **kwargs):
        group_id = kwargs.get('group_id')
        user_id = get_jwt_identity()
        member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
        if not member:
            return error_response('You are not a member of this group', 403)
        kwargs['_member'] = member
        return f(*args, **kwargs)
    return decorated


def require_group_admin(f):
    """Ensures the current user is an admin of the group."""
    @wraps(f)
    def decorated(*args, **kwargs):
        group_id = kwargs.get('group_id')
        user_id = get_jwt_identity()
        member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
        if not member:
            return error_response('You are not a member of this group', 403)
        if member.role != 'admin':
            return error_response('Admin access required', 403)
        kwargs['_member'] = member
        return f(*args, **kwargs)
    return decorated


def require_pro(f):
    """Ensures the current user has a Pro plan."""
    @wraps(f)
    def decorated(*args, **kwargs):
        from app.models import User
        from app import db
        user_id = get_jwt_identity()
        user = db.session.get(User, user_id)
        if not user or user.plan == 'free':
            return error_response('This feature requires a Pro plan', 402)
        return f(*args, **kwargs)
    return decorated


def require_group_operational(f):
    """
    Blocks write operations when a group is in a non-operational state
    (limited, expired, or read_only). Groups in 'free' or 'active' state
    are allowed. The evaluated state is synced to the DB if it changed.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        from app.models import Group
        from app import db
        from app.groups.lifecycle_service import GroupLifecycleService

        group_id = kwargs.get('group_id')
        group = db.session.get(Group, group_id)
        if not group:
            return error_response('Group not found', 404)

        # Sync state (may transition free→limited or active→expired silently)
        GroupLifecycleService.sync_state(group, db.session)
        if db.session.dirty:
            db.session.commit()

        if not GroupLifecycleService.is_operational(group):
            state_labels = {
                'limited': 'הקבוצה הגיעה למגבלת החינם ודורשת הפעלה',
                'expired': 'הקבוצה פגה - יש לחדש אותה כדי להמשיך',
                'read_only': 'הקבוצה במצב קריאה בלבד - יש לחדש את החיוב',
            }
            msg = state_labels.get(group.group_state, 'הקבוצה אינה פעילה')
            return error_response(msg, 403, errors={'group_state': group.group_state})

        return f(*args, **kwargs)
    return decorated
