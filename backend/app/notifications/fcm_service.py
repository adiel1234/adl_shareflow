"""
FCM Push Notification Service — ADL ShareFlow
Sends notifications via Firebase Admin SDK.
Gracefully skips if Firebase is not configured.

FCM sends run in a background thread so API handlers (e.g. event summary)
return immediately after persisting in-app notifications.
"""
import logging
import threading
from typing import Optional

logger = logging.getLogger(__name__)

_firebase_app = None
_firebase_initialized = False

# Must match AndroidNotificationChannel id in mobile/lib/services/fcm_service.dart
_ANDROID_CHANNEL_ID = 'shareflow_default'


def _get_app():
    """Initialize Firebase app once, return None if not configured."""
    global _firebase_app, _firebase_initialized
    if _firebase_initialized:
        return _firebase_app
    _firebase_initialized = True
    try:
        import os
        import firebase_admin
        from firebase_admin import credentials

        creds_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        if not creds_path or not os.path.exists(creds_path):
            logger.info('Firebase credentials not found — push notifications disabled')
            return None

        cred = credentials.Certificate(creds_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        logger.info('Firebase initialized successfully')
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


def _dispatch_async(target, *args, **kwargs) -> None:
    """Run FCM work off the request thread so HTTP handlers return promptly."""
    try:
        from flask import current_app
        app = current_app._get_current_object()
    except RuntimeError:
        # Outside request context (e.g. tests) — run inline
        target(*args, **kwargs)
        return

    def _run():
        with app.app_context():
            try:
                target(*args, **kwargs)
            except Exception as e:
                logger.error(f'Async FCM dispatch failed: {e}')

    threading.Thread(target=_run, daemon=True).start()


def send_to_user(user_id: str, title: str, body: str, data: Optional[dict] = None) -> int:
    """
    Queue push notification to all FCM tokens registered for a user.
    Returns 0 immediately; actual send runs in a background thread.
    """
    _dispatch_async(_send_to_user_impl, user_id, title, body, data)
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
    _dispatch_async(_send_to_users_impl, list(user_ids), title, body, data)
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
