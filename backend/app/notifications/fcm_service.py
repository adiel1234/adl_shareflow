"""
FCM Push Notification Service — ADL ShareFlow
Sends notifications via Firebase Admin SDK.
Gracefully skips if Firebase is not configured.
"""
import logging
from typing import Optional

logger = logging.getLogger(__name__)

_firebase_app = None
_firebase_initialized = False


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


def send_to_user(user_id: str, title: str, body: str, data: Optional[dict] = None) -> int:
    """
    Send push notification to all FCM tokens registered for a user.
    Returns number of tokens notified.
    """
    app = _get_app()
    if not app:
        return 0

    try:
        from app.models import FCMToken
        tokens = FCMToken.query.filter_by(user_id=user_id).all()
        if not tokens:
            return 0

        from firebase_admin import messaging
        sent = 0
        for token_row in tokens:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data={k: str(v) for k, v in (data or {}).items()},
                    token=token_row.token,
                )
                messaging.send(message, app=app)
                sent += 1
            except messaging.UnregisteredError:
                # Token expired — delete it
                from app import db
                db.session.delete(token_row)
                db.session.commit()
            except Exception as e:
                logger.error(f'FCM send failed for token {token_row.token[:20]}...: {e}')
        return sent
    except Exception as e:
        logger.error(f'FCM send_to_user error: {e}')
        return 0


def send_to_users(user_ids: list, title: str, body: str, data: Optional[dict] = None) -> int:
    """Send the same notification to multiple users."""
    total = 0
    for uid in user_ids:
        total += send_to_user(uid, title, body, data)
    return total


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
