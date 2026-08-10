"""
Pilot mode helpers — feature flag + account_mode lifecycle.
"""
from __future__ import annotations

from datetime import datetime, timezone

from app import db
from app.models import FeatureFlag, RefreshToken, User

PILOT_MODE_FLAG = 'PILOT_MODE_ENABLED'
PILOT_STARTED_FLAG = 'PILOT_STARTED_AT'

ACCOUNT_MODE_PILOT = 'pilot'
ACCOUNT_MODE_ACTIVE = 'active'

ERR_PILOT_ENDED = 'PILOT_ENDED'
ERR_ACCOUNT_DISABLED = 'Account is disabled'


def flag_truthy(value) -> bool:
    if value is None:
        return False
    if isinstance(value, bool):
        return value
    return str(value).strip().strip('"').lower() in ('true', '1', 'yes')


def _get_flag(key: str) -> FeatureFlag | None:
    return FeatureFlag.query.filter_by(key=key).first()


def _set_flag(key: str, value: str, description: str) -> FeatureFlag:
    flag = _get_flag(key)
    if not flag:
        flag = FeatureFlag(key=key, description=description)
        db.session.add(flag)
    flag.value = value
    flag.description = description
    return flag


def is_pilot_mode_enabled() -> bool:
    flag = _get_flag(PILOT_MODE_FLAG)
    if flag is None:
        # Default while flag missing: treat as pilot (current product phase).
        return True
    return flag_truthy(flag.value)


def registration_account_mode() -> str:
    return ACCOUNT_MODE_PILOT if is_pilot_mode_enabled() else ACCOUNT_MODE_ACTIVE


def raise_if_blocked(user: User | None) -> None:
    if user is None:
        raise ValueError(ERR_ACCOUNT_DISABLED)
    if user.is_active:
        return
    if getattr(user, 'account_mode', None) == ACCOUNT_MODE_PILOT:
        raise ValueError(ERR_PILOT_ENDED)
    raise ValueError(ERR_ACCOUNT_DISABLED)


def revoke_refresh_tokens(user_id: str) -> int:
    return RefreshToken.query.filter_by(user_id=user_id).delete()


def promote_to_active(user: User, *, display_name: str | None = None) -> User:
    """Convert a (blocked) pilot account into a real active account."""
    if display_name:
        user.display_name = display_name
    user.account_mode = ACCOUNT_MODE_ACTIVE
    user.is_active = True
    revoke_refresh_tokens(user.id)
    db.session.add(user)
    return user


def enable_pilot_mode() -> dict:
    """Turn pilot mode ON (new registrations become pilot). Does not re-activate blocked users."""
    _set_flag(
        PILOT_MODE_FLAG,
        'true',
        'מצב פיילוט — הרשמות חדשות מסומנות כ-pilot',
    )
    started = _get_flag(PILOT_STARTED_FLAG)
    if not started or not started.value:
        _set_flag(
            PILOT_STARTED_FLAG,
            datetime.now(timezone.utc).isoformat(),
            'תחילת פיילוט — סינון דשבורד (scope=pilot)',
        )
    db.session.commit()
    return {
        'pilot_mode_enabled': True,
        'pilot_started_at': (_get_flag(PILOT_STARTED_FLAG).value if _get_flag(PILOT_STARTED_FLAG) else None),
        'blocked_users': 0,
    }


def disable_pilot_mode() -> dict:
    """
    Turn pilot mode OFF:
    - new registrations become active
    - all pilot users are blocked and refresh tokens revoked
    """
    _set_flag(
        PILOT_MODE_FLAG,
        'false',
        'מצב פיילוט — כבוי; הרשמות חדשות הן חשבונות פעילים',
    )
    pilot_users = User.query.filter_by(account_mode=ACCOUNT_MODE_PILOT).all()
    blocked = 0
    for user in pilot_users:
        if user.is_active:
            user.is_active = False
            blocked += 1
        revoke_refresh_tokens(user.id)
        db.session.add(user)
    db.session.commit()
    return {
        'pilot_mode_enabled': False,
        'blocked_users': blocked,
        'pilot_users_total': len(pilot_users),
    }


def set_pilot_mode(enabled: bool) -> dict:
    return enable_pilot_mode() if enabled else disable_pilot_mode()
