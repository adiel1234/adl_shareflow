from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app import db
from app.models import User, FCMToken, ReminderSettings
from app.common.errors import success_response, error_response

users_bp = Blueprint('users', __name__)


@users_bp.get('/me')
@jwt_required()
def get_me():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user:
        return error_response('User not found', 404)
    return success_response(data=user.to_dict())


@users_bp.put('/me')
@jwt_required()
def update_me():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user:
        return error_response('User not found', 404)

    data = request.get_json(silent=True) or {}
    if 'display_name' in data:
        name = data['display_name'].strip()
        if not name:
            return error_response('display_name cannot be empty')
        user.display_name = name
    if 'phone' in data:
        user.phone = data['phone'].strip() or None
    if 'default_currency' in data:
        user.default_currency = data['default_currency'].upper()[:3]
    if 'language' in data and data['language'] in ('he', 'en'):
        user.language = data['language']
    if 'avatar_url' in data:
        user.avatar_url = data['avatar_url'] or None
    # Payment details
    if 'payment_phone' in data:
        user.payment_phone = (data['payment_phone'] or '').strip() or None
    if 'bank_name' in data:
        user.bank_name = (data['bank_name'] or '').strip() or None
    if 'bank_branch' in data:
        user.bank_branch = (data['bank_branch'] or '').strip() or None
    if 'bank_account_number' in data:
        user.bank_account_number = (data['bank_account_number'] or '').strip() or None

    db.session.commit()
    return success_response(data=user.to_dict())


@users_bp.delete('/me')
@jwt_required()
def delete_me():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user:
        return error_response('User not found', 404)

    user.is_active = False
    db.session.commit()
    return success_response(message='Account deactivated')


@users_bp.post('/fcm-token')
@jwt_required()
def register_fcm_token():
    user_id = get_jwt_identity()
    data = request.get_json(silent=True) or {}
    token = (data.get('token') or '').strip()
    platform = (data.get('platform') or '').lower()

    if not token or platform not in ('ios', 'android'):
        return error_response('token and platform (ios/android) are required')

    existing = FCMToken.query.filter_by(user_id=user_id, token=token).first()
    if not existing:
        fcm = FCMToken(user_id=user_id, token=token, platform=platform)
        db.session.add(fcm)
        db.session.commit()

    return success_response(message='FCM token registered')


@users_bp.get('/me/reminder-settings')
@jwt_required()
def get_reminder_settings():
    user_id = get_jwt_identity()
    settings = ReminderSettings.query.filter_by(user_id=user_id).first()
    if not settings:
        return success_response(data={
            'frequency': 'manual',
            'platforms': ['app'],
            'enabled': True,
        })
    return success_response(data=settings.to_dict())


@users_bp.put('/me/reminder-settings')
@jwt_required()
def update_reminder_settings():
    user_id = get_jwt_identity()
    data = request.get_json(silent=True) or {}

    frequency = data.get('frequency', 'manual')
    valid_frequencies = {'none', 'manual', 'daily', 'every_2_days', 'weekly', 'biweekly'}
    if frequency not in valid_frequencies:
        return error_response(f'frequency must be one of: {", ".join(valid_frequencies)}')

    platforms_list = data.get('platforms', ['app'])
    if isinstance(platforms_list, list):
        platforms = ','.join(p for p in platforms_list if p in ('app', 'whatsapp'))
    else:
        platforms = 'app'

    settings = ReminderSettings.query.filter_by(user_id=user_id).first()
    if not settings:
        settings = ReminderSettings(
            user_id=user_id,
            frequency=frequency,
            platforms=platforms or 'app',
            enabled=data.get('enabled', True),
        )
        db.session.add(settings)
    else:
        settings.frequency = frequency
        settings.platforms = platforms or 'app'
        settings.enabled = data.get('enabled', settings.enabled)

    db.session.commit()
    return success_response(data=settings.to_dict())
