"""In-app account deletion for App Store Guideline 5.1.1."""
from __future__ import annotations

from app import db
from app.models import (
    FCMToken,
    Group,
    GroupMember,
    Notification,
    PasswordResetToken,
    RefreshToken,
    ReminderSettings,
    ScheduledReminder,
    User,
    UserIdentity,
)
from app.pilot_mode import revoke_refresh_tokens

ACCOUNT_MODE_DELETED = 'deleted'
DELETED_DISPLAY_NAME = 'חשבון שנמחק'


def is_deleted_account(user: User | None) -> bool:
    if user is None:
        return True
    if getattr(user, 'account_mode', None) == ACCOUNT_MODE_DELETED:
        return True
    email = (user.email or '')
    return email.startswith('deleted+') and email.endswith('@invalid.shareflow')


def delete_account(user: User) -> None:
    """Strip personal data, revoke login, and leave shared group history."""
    if is_deleted_account(user):
        return

    uid = user.id
    memberships = list(GroupMember.query.filter_by(user_id=uid).all())

    for membership in memberships:
        group_id = membership.group_id
        others = GroupMember.query.filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id != uid,
        ).all()

        if not others:
            group = db.session.get(Group, group_id)
            if group:
                db.session.delete(group)
            continue

        if membership.role == 'admin':
            has_other_admin = any(other.role == 'admin' for other in others)
            if not has_other_admin:
                others[0].role = 'admin'
        db.session.delete(membership)

    ScheduledReminder.query.filter(
        (ScheduledReminder.user_id == uid) | (ScheduledReminder.to_user_id == uid)
    ).delete(synchronize_session=False)
    ReminderSettings.query.filter_by(user_id=uid).delete(synchronize_session=False)
    Notification.query.filter_by(user_id=uid).delete(synchronize_session=False)
    FCMToken.query.filter_by(user_id=uid).delete(synchronize_session=False)
    PasswordResetToken.query.filter_by(user_id=uid).delete(synchronize_session=False)
    UserIdentity.query.filter_by(user_id=uid).delete(synchronize_session=False)
    revoke_refresh_tokens(uid)
    RefreshToken.query.filter_by(user_id=uid).delete(synchronize_session=False)

    user.email = f'deleted+{uid}@invalid.shareflow'
    user.display_name = DELETED_DISPLAY_NAME
    user.avatar_url = None
    user.phone = None
    user.payment_phone = None
    user.paybox_link = None
    user.bank_name = None
    user.bank_branch = None
    user.bank_account_number = None
    user.is_active = False
    user.account_mode = ACCOUNT_MODE_DELETED

    db.session.add(user)
    db.session.commit()
