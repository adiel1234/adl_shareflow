"""
FCM Push Notification Service — ADL ShareFlow
Sends notifications via Firebase Admin SDK.
Gracefully skips if Firebase is not configured.

FCM sends run in a background thread so API handlers (e.g. event summary)
return immediately after persisting in-app notifications.
"""
import logging
from typing import Optional

from app.common.background import run_in_background

logger = logging.getLogger(__name__)

_firebase_app = None
_firebase_initialized = False

# Must match AndroidNotificationChannel id in mobile/lib/services/fcm_service.dart
_ANDROID_CHANNEL_ID = 'shareflow_default'


def _get_app():
    """Initialize Firebase app once, return None if not configured.

    Supports two methods (checked in order):
    1. FIREBASE_CREDENTIALS_JSON — full service-account JSON as an env-var string
       (preferred for Railway / containerised deployments).
    2. FIREBASE_CREDENTIALS_PATH — path to a service-account JSON file
       (convenient for local development).
    """
    global _firebase_app, _firebase_initialized
    if _firebase_initialized:
        return _firebase_app
    _firebase_initialized = True
    try:
        import json
        import os
        import firebase_admin
        from firebase_admin import credentials

        cred = None

        # Method 1: JSON string in env var
        creds_json = os.getenv('FIREBASE_CREDENTIALS_JSON')
        if creds_json:
            try:
                cred = credentials.Certificate(json.loads(creds_json))
            except Exception as e:
                logger.warning(f'Failed to parse FIREBASE_CREDENTIALS_JSON: {e}')

        # Method 2: Path to JSON file
        if cred is None:
            creds_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
            if creds_path and os.path.exists(creds_path):
                cred = credentials.Certificate(creds_path)

        if cred is None:
            logger.info('Firebase credentials not configured — push notifications disabled')
            return None

        try:
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info('Firebase initialized successfully')
        except ValueError as e:
            if 'already exists' in str(e):
                # App was already initialized (e.g. by another call); reuse it.
                _firebase_app = firebase_admin.get_app()
                logger.info('Firebase app reused (already initialized)')
            else:
                raise
    except Exception as e:
        logger.warning(f'Firebase initialization failed: {e}')
    return _firebase_app


def _build_message(title: str, body: str, payload_data: dict, token: str):
    from firebase_admin import messaging

    return messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=payload_data,
        token=token,
        android=messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                sound='default',
                channel_id=_ANDROID_CHANNEL_ID,
                default_sound=True,
            ),
        ),
        apns=messaging.APNSConfig(
            headers={'apns-priority': '10'},
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound='default', badge=1),
            ),
        ),
    )


def _send_to_user_impl(user_id: str, title: str, body: str, data: Optional[dict] = None) -> int:
    """Synchronous FCM send — used from background thread only."""
    app = _get_app()
    if not app:
        return 0

    try:
        from app.models import FCMToken
        tokens = FCMToken.query.filter_by(user_id=user_id).all()
        if not tokens:
            return 0

        from firebase_admin import messaging
        from app import db

        sent = 0
        for token_row in tokens:
            try:
                payload_data = {k: str(v) for k, v in (data or {}).items()}
                payload_data['title'] = title
                payload_data['body'] = body
                message = _build_message(title, body, payload_data, token_row.token)
                messaging.send(message, app=app)
                sent += 1
            except messaging.UnregisteredError:
                db.session.delete(token_row)
                db.session.commit()
            except Exception as e:
                logger.error(f'FCM send failed for token {token_row.token[:20]}...: {e}')
        return sent
    except Exception as e:
        logger.error(f'FCM send_to_user error: {e}')
        return 0


def send_to_user(user_id: str, title: str, body: str, data: Optional[dict] = None) -> int:
    """
    Queue push notification to all FCM tokens registered for a user.
    Returns 0 immediately; actual send runs in a background thread.
    """
    run_in_background(_send_to_user_impl, user_id, title, body, data)
    return 0


def _send_to_users_impl(user_ids: list, title: str, body: str, data: Optional[dict] = None) -> int:
    total = 0
    for uid in user_ids:
        total += _send_to_user_impl(uid, title, body, data)
    return total


def send_to_users(user_ids: list, title: str, body: str, data: Optional[dict] = None) -> int:
    """Queue the same notification for multiple users (non-blocking)."""
    if not user_ids:
        return 0
    run_in_background(_send_to_users_impl, list(user_ids), title, body, data)
    return 0


def send_to_group(group_id: str, exclude_user_id: Optional[str], title: str, body: str, data: Optional[dict] = None) -> int:
    """Send notification to all group members except the one who triggered the action."""
    try:
        from app.models import GroupMember
        members = GroupMember.query.filter_by(group_id=group_id).all()
        user_ids = [m.user_id for m in members if m.user_id != exclude_user_id]
        return send_to_users(user_ids, title, body, data)
    except Exception as e:
        logger.error(f'FCM send_to_group error: {e}')
        return 0
