"""POST /api/ocr/scan must not invoke OCR. Attach and view stay available."""
import inspect
import io
import os
import uuid
from unittest.mock import MagicMock, patch

import pytest
from flask_jwt_extended import create_access_token

from app import create_app, db
from app.models import Receipt, User
from app.ocr.routes import scan_receipt
from config import TestingConfig


@pytest.fixture
def app(tmp_path):
    application = create_app(TestingConfig)
    application.config['STORAGE_BACKEND'] = 'local'
    application.config['STORAGE_LOCAL_PATH'] = str(tmp_path / 'uploads')
    os.makedirs(application.config['STORAGE_LOCAL_PATH'], exist_ok=True)
    return application


def _active_user(user_id):
    user = MagicMock()
    user.id = user_id
    user.is_active = True
    user.account_mode = 'pilot'
    return user


def _token(app, user_id=None):
    uid = user_id or str(uuid.uuid4())
    with app.app_context():
        return uid, create_access_token(identity=uid)


def _jpeg():
    return (io.BytesIO(b'\xff\xd8\xff\xe0' + b'\x00' * 32), 'receipt.jpg')


def test_scan_function_has_no_provider_call():
    src = inspect.getsource(scan_receipt)
    assert 'get_ocr_provider' not in src
    assert 'provider.scan' not in src
    assert '.scan(' not in src


def test_scan_endpoint_does_not_call_provider(app):
    client = app.test_client()
    user_id, token = _token(app)
    with patch.object(db.session, 'get', return_value=_active_user(user_id)), \
         patch('app.ocr.provider.get_ocr_provider') as mock_get, \
         patch('app.ocr.provider.GoogleVisionProvider.scan') as mock_scan:
        mock_get.side_effect = AssertionError('OCR provider must not be created')
        mock_scan.side_effect = AssertionError('provider.scan must not be called')
        r = client.post(
            '/api/ocr/scan',
            headers={'Authorization': f'Bearer {token}'},
            data={'image': _jpeg()},
            content_type='multipart/form-data',
        )
    assert r.status_code == 410
    assert r.get_json()['success'] is False
    mock_get.assert_not_called()
    mock_scan.assert_not_called()


def test_attach_still_works_without_ocr(app):
    client = app.test_client()
    user_id, token = _token(app)
    def _add(obj):
        if getattr(obj, 'id', None) is None:
            obj.id = str(uuid.uuid4())

    with patch.object(db.session, 'get', return_value=_active_user(user_id)), \
         patch.object(db.session, 'add', side_effect=_add), \
         patch.object(db.session, 'commit'), \
         patch('app.ocr.provider.get_ocr_provider') as mock_get, \
         patch('app.ocr.provider.GoogleVisionProvider.scan') as mock_scan:
        r = client.post(
            '/api/ocr/attach',
            headers={'Authorization': f'Bearer {token}'},
            data={'image': _jpeg()},
            content_type='multipart/form-data',
        )
    assert r.status_code == 201, r.data
    data = r.get_json()['data']
    assert data['receipt_id']
    assert data['image_url']
    mock_get.assert_not_called()
    mock_scan.assert_not_called()


def test_existing_receipt_view_still_works(app):
    client = app.test_client()
    user_id, token = _token(app)
    upload_root = app.config['STORAGE_LOCAL_PATH']
    user_dir = os.path.join(upload_root, user_id)
    os.makedirs(user_dir, exist_ok=True)
    filename = 'view.jpg'
    with open(os.path.join(user_dir, filename), 'wb') as f:
        f.write(b'\xff\xd8\xff\xe0' + b'\x00' * 32)

    receipt = MagicMock()
    receipt.id = str(uuid.uuid4())
    receipt.user_id = user_id
    receipt.group_id = None
    receipt.image_url = f'/uploads/{user_id}/{filename}'

    def _session_get(model, ident):
        if model is User:
            return _active_user(user_id)
        if model is Receipt:
            return receipt
        return None

    with patch.object(db.session, 'get', side_effect=_session_get):
        r = client.get(
            f'/api/ocr/receipts/{receipt.id}/image',
            headers={'Authorization': f'Bearer {token}'},
        )
    assert r.status_code == 200
    assert r.mimetype.startswith('image/')
