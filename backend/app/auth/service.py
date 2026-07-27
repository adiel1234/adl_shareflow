"""
Auth service — registration, login, JWT, Google, Apple.
"""
import hashlib
import os
from datetime import datetime, timezone, timedelta

from werkzeug.security import generate_password_hash, check_password_hash
from flask_jwt_extended import create_access_token, create_refresh_token
from flask import current_app

from app import db
from app.models import User, UserIdentity, RefreshToken, PasswordResetToken
from app.common.utils import hash_token
from app.email_service import send_password_reset_email


_RESET_CODE_TTL_MINUTES = 30


# ---------------------------------------------------------------------------
# Email / Password
# ---------------------------------------------------------------------------

def register_email(email: str, password: str, display_name: str) -> tuple[User, str, str]:
    email = email.lower().strip()

    existing = UserIdentity.query.filter_by(provider='email', provider_user_id=email).first()
    if existing:
        raise ValueError('Email already registered')

    user = User(email=email, display_name=display_name)
    db.session.add(user)
    db.session.flush()

    identity = UserIdentity(
        user_id=user.id,
        provider='email',
        provider_user_id=email,
        password_hash=generate_password_hash(password),
    )
    db.session.add(identity)
    db.session.commit()

    access_token, refresh_token = _generate_tokens(user)
    return user, access_token, refresh_token


def login_email(email: str, password: str) -> tuple[User, str, str]:
    email = email.lower().strip()

    identity = UserIdentity.query.filter_by(provider='email', provider_user_id=email).first()
    if not identity or not check_password_hash(identity.password_hash or '', password):
        raise ValueError('Invalid email or password')

    user = db.session.get(User, identity.user_id)
    if not user or not user.is_active:
        raise ValueError('Account is disabled')

    access_token, refresh_token = _generate_tokens(user)
    return user, access_token, refresh_token


# ---------------------------------------------------------------------------
# Google Sign-In
# ---------------------------------------------------------------------------

def login_google(id_token: str) -> tuple[User, str, str]:
    from google.oauth2 import id_token as google_id_token
    from google.auth.transport import requests as google_requests

    try:
        idinfo = google_id_token.verify_oauth2_token(
            id_token,
            google_requests.Request(),
            current_app.config['GOOGLE_CLIENT_ID'],
        )
    except Exception as e:
        raise ValueError(f'Invalid Google token: {e}')

    google_user_id = idinfo['sub']
    email = idinfo.get('email', '').lower()
    display_name = idinfo.get('name', email.split('@')[0])
    avatar_url = idinfo.get('picture')

    return _upsert_oauth_user('google', google_user_id, email, display_name, avatar_url)


# ---------------------------------------------------------------------------
# Apple Sign-In
# ---------------------------------------------------------------------------

def login_apple(identity_token: str, display_name: str = None) -> tuple[User, str, str]:
    import jwt as pyjwt
    import requests

    # Fetch Apple public keys
    apple_keys_url = 'https://appleid.apple.com/auth/keys'
    try:
        keys_response = requests.get(apple_keys_url, timeout=10)
        keys_data = keys_response.json()
    except Exception as e:
        raise ValueError(f'Could not fetch Apple keys: {e}')

    try:
        header = pyjwt.get_unverified_header(identity_token)
        kid = header.get('kid')

        from jwt.algorithms import RSAAlgorithm
        matching_key = next((k for k in keys_data['keys'] if k['kid'] == kid), None)
        if not matching_key:
            raise ValueError('No matching Apple key found')

        public_key = RSAAlgorithm.from_jwk(matching_key)
        payload = pyjwt.decode(
            identity_token,
            public_key,
            algorithms=['RS256'],
            audience=current_app.config['APPLE_CLIENT_ID'],
        )
    except Exception as e:
        raise ValueError(f'Invalid Apple token: {e}')

    apple_user_id = payload['sub']
    email = payload.get('email', f'{apple_user_id}@privaterelay.appleid.com').lower()
    name = display_name or email.split('@')[0]

    return _upsert_oauth_user('apple', apple_user_id, email, name, None)


# ---------------------------------------------------------------------------
# Token refresh
# ---------------------------------------------------------------------------

def refresh_access_token(raw_refresh_token: str) -> str:
    token_hash = hash_token(raw_refresh_token)
    stored = RefreshToken.query.filter_by(token_hash=token_hash).first()

    if not stored:
        raise ValueError('Refresh token not found')
    if stored.expires_at < datetime.now(timezone.utc):
        db.session.delete(stored)
        db.session.commit()
        raise ValueError('Refresh token expired')

    user = db.session.get(User, stored.user_id)
    if not user or not user.is_active:
        raise ValueError('Account disabled')

    return create_access_token(identity=user.id)


def logout(raw_refresh_token: str):
    token_hash = hash_token(raw_refresh_token)
    RefreshToken.query.filter_by(token_hash=token_hash).delete()
    db.session.commit()


# ---------------------------------------------------------------------------
# Password reset
# ---------------------------------------------------------------------------

def request_password_reset(email: str) -> None:
    """Create a 6-digit reset code and email it. Silent if email unknown."""
    import secrets

    email = email.lower().strip()
    identity = UserIdentity.query.filter_by(
        provider='email', provider_user_id=email
    ).first()
    if not identity or not identity.password_hash:
        return

    user = db.session.get(User, identity.user_id)
    if not user or not user.is_active or user.is_guest:
        return

    # Invalidate previous unused codes for this user.
    PasswordResetToken.query.filter_by(user_id=user.id, used_at=None).delete()

    code = f'{secrets.randbelow(1_000_000):06d}'
    row = PasswordResetToken(
        user_id=user.id,
        code_hash=hash_token(code),
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=_RESET_CODE_TTL_MINUTES),
    )
    db.session.add(row)
    db.session.commit()

    sent = send_password_reset_email(
        to_email=user.email,
        display_name=user.display_name,
        code=code,
    )
    if not sent:
        # Keep token so a retry can still work after Resend recovers;
        # surface a soft failure to the route layer.
        raise RuntimeError('Failed to send password reset email')


def reset_password(email: str, code: str, new_password: str) -> None:
    """Validate emailed code and set a new password for the email identity."""
    email = email.lower().strip()
    code = (code or '').strip().replace(' ', '')
    if len(code) != 6 or not code.isdigit():
        raise ValueError('קוד לא תקין או שפג תוקפו')
    if len(new_password) < 8:
        raise ValueError('הסיסמה חייבת להיות לפחות 8 תווים')

    identity = UserIdentity.query.filter_by(
        provider='email', provider_user_id=email
    ).first()
    if not identity:
        raise ValueError('קוד לא תקין או שפג תוקפו')

    now = datetime.now(timezone.utc)
    row = (
        PasswordResetToken.query
        .filter_by(user_id=identity.user_id, code_hash=hash_token(code), used_at=None)
        .order_by(PasswordResetToken.created_at.desc())
        .first()
    )
    if not row:
        raise ValueError('קוד לא תקין או שפג תוקפו')

    expires = row.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if expires < now:
        raise ValueError('קוד לא תקין או שפג תוקפו')

    identity.password_hash = generate_password_hash(new_password)
    row.used_at = now
    # Revoke all refresh tokens so other devices must re-login.
    RefreshToken.query.filter_by(user_id=identity.user_id).delete()
    db.session.commit()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _upsert_oauth_user(
    provider: str,
    provider_user_id: str,
    email: str,
    display_name: str,
    avatar_url: str,
) -> tuple[User, str, str]:
    identity = UserIdentity.query.filter_by(
        provider=provider,
        provider_user_id=provider_user_id,
    ).first()

    if identity:
        user = db.session.get(User, identity.user_id)
        if avatar_url and not user.avatar_url:
            user.avatar_url = avatar_url
            db.session.commit()
    else:
        # Check if email already exists (link accounts)
        user = User.query.filter_by(email=email).first()
        if not user:
            user = User(email=email, display_name=display_name, avatar_url=avatar_url)
            db.session.add(user)
            db.session.flush()

        identity = UserIdentity(
            user_id=user.id,
            provider=provider,
            provider_user_id=provider_user_id,
        )
        db.session.add(identity)
        db.session.commit()

    if not user.is_active:
        raise ValueError('Account is disabled')

    access_token, refresh_token = _generate_tokens(user)
    return user, access_token, refresh_token


def _generate_tokens(user: User) -> tuple[str, str]:
    access_token = create_access_token(identity=user.id)
    raw_refresh = create_refresh_token(identity=user.id)

    expires_at = datetime.now(timezone.utc) + current_app.config['JWT_REFRESH_TOKEN_EXPIRES']
    stored = RefreshToken(
        user_id=user.id,
        token_hash=hash_token(raw_refresh),
        expires_at=expires_at,
    )
    db.session.add(stored)
    db.session.commit()

    return access_token, raw_refresh
