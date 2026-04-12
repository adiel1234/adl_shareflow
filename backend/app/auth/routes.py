from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app.auth import service
from app.common.errors import success_response, error_response

auth_bp = Blueprint('auth', __name__)


@auth_bp.post('/register')
def register():
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip()
    password = data.get('password', '')
    display_name = (data.get('display_name') or '').strip()

    if not email or not password or not display_name:
        return error_response('email, password, and display_name are required')
    if len(password) < 8:
        return error_response('Password must be at least 8 characters')

    try:
        user, access_token, refresh_token = service.register_email(email, password, display_name)
    except ValueError as e:
        return error_response(str(e))

    return success_response(
        data={
            'user': user.to_dict(),
            'access_token': access_token,
            'refresh_token': refresh_token,
        },
        status_code=201,
    )


@auth_bp.post('/login')
def login():
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip()
    password = data.get('password', '')

    if not email or not password:
        return error_response('email and password are required')

    try:
        user, access_token, refresh_token = service.login_email(email, password)
    except ValueError as e:
        return error_response(str(e), 401)

    return success_response(data={
        'user': user.to_dict(),
        'access_token': access_token,
        'refresh_token': refresh_token,
    })


@auth_bp.post('/google')
def google_login():
    data = request.get_json(silent=True) or {}
    id_token = (data.get('id_token') or '').strip()

    if not id_token:
        return error_response('id_token is required')

    try:
        user, access_token, refresh_token = service.login_google(id_token)
    except ValueError as e:
        return error_response(str(e), 401)

    return success_response(data={
        'user': user.to_dict(),
        'access_token': access_token,
        'refresh_token': refresh_token,
    })


@auth_bp.post('/apple')
def apple_login():
    data = request.get_json(silent=True) or {}
    identity_token = (data.get('identity_token') or '').strip()
    display_name = (data.get('display_name') or '').strip() or None

    if not identity_token:
        return error_response('identity_token is required')

    try:
        user, access_token, refresh_token = service.login_apple(identity_token, display_name)
    except ValueError as e:
        return error_response(str(e), 401)

    return success_response(data={
        'user': user.to_dict(),
        'access_token': access_token,
        'refresh_token': refresh_token,
    })


@auth_bp.post('/refresh')
def refresh():
    data = request.get_json(silent=True) or {}
    raw_refresh_token = (data.get('refresh_token') or '').strip()

    if not raw_refresh_token:
        return error_response('refresh_token is required')

    try:
        access_token = service.refresh_access_token(raw_refresh_token)
    except ValueError as e:
        return error_response(str(e), 401)

    return success_response(data={'access_token': access_token})


@auth_bp.post('/logout')
@jwt_required()
def logout():
    data = request.get_json(silent=True) or {}
    raw_refresh_token = (data.get('refresh_token') or '').strip()

    if raw_refresh_token:
        service.logout(raw_refresh_token)

    return success_response(message='Logged out successfully')


@auth_bp.post('/forgot-password')
def forgot_password():
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip()

    if not email:
        return error_response('email is required')

    service.request_password_reset(email)
    return success_response(message='If this email exists, a reset link has been sent')


@auth_bp.post('/reset-password')
def reset_password():
    data = request.get_json(silent=True) or {}
    token = (data.get('token') or '').strip()
    new_password = data.get('new_password', '')

    if not token or not new_password:
        return error_response('token and new_password are required')
    if len(new_password) < 8:
        return error_response('Password must be at least 8 characters')

    try:
        service.reset_password(token, new_password)
    except (ValueError, NotImplementedError) as e:
        return error_response(str(e))

    return success_response(message='Password reset successfully')
