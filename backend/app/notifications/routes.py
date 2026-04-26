from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app import db
from app.models import Notification, FCMToken
from app.common.errors import success_response, error_response

notifications_bp = Blueprint('notifications', __name__)


@notifications_bp.get('')
@jwt_required()
def list_notifications():
    user_id = get_jwt_identity()
    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 30, type=int), 100)

    q = Notification.query.filter_by(user_id=user_id).order_by(Notification.created_at.desc())
    total = q.count()
    unread = Notification.query.filter_by(user_id=user_id, is_read=False).count()
    items = q.offset((page - 1) * per_page).limit(per_page).all()

    return success_response(data={
        'notifications': [n.to_dict() for n in items],
        'unread_count': unread,
        'pagination': {'total': total, 'page': page, 'per_page': per_page},
    })


@notifications_bp.put('/<notification_id>/read')
@jwt_required()
def mark_read(notification_id):
    user_id = get_jwt_identity()
    notif = Notification.query.filter_by(id=notification_id, user_id=user_id).first()
    if not notif:
        return error_response('Notification not found', 404)

    notif.is_read = True
    db.session.commit()
    return success_response(data=notif.to_dict())


@notifications_bp.put('/read-all')
@jwt_required()
def mark_all_read():
    user_id = get_jwt_identity()
    Notification.query.filter_by(user_id=user_id, is_read=False).update({'is_read': True})
    db.session.commit()
    return success_response(message='All notifications marked as read')


@notifications_bp.post('/fcm-token')
@jwt_required()
def register_fcm_token():
    user_id = get_jwt_identity()
    data = request.get_json(silent=True) or {}
    token = data.get('token', '').strip()
    plat = data.get('platform', 'ios')

    if not token:
        return error_response('token required', 400)
    if plat not in ('ios', 'android'):
        plat = 'ios'

    existing = FCMToken.query.filter_by(user_id=user_id, token=token).first()
    if not existing:
        ft = FCMToken(user_id=user_id, token=token, platform=plat)
        db.session.add(ft)
        db.session.commit()

    return success_response(message='FCM token registered')


@notifications_bp.delete('/fcm-token')
@jwt_required()
def unregister_fcm_token():
    user_id = get_jwt_identity()
    data = request.get_json(silent=True) or {}
    token = data.get('token', '').strip()

    if token:
        FCMToken.query.filter_by(user_id=user_id, token=token).delete()
    else:
        FCMToken.query.filter_by(user_id=user_id).delete()

    db.session.commit()
    return success_response(message='FCM token removed')
