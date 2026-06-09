import mimetypes
import os
from flask import Blueprint, request, current_app, send_from_directory, redirect
from flask_jwt_extended import jwt_required, get_jwt_identity

from app import db
from app.models import Receipt, GroupMember, Expense
from app.ocr.provider import get_ocr_provider
from app.common.errors import success_response, error_response
from app.common.utils import allowed_image

ocr_bp = Blueprint('ocr', __name__)


@ocr_bp.post('/attach')
@jwt_required()
def attach_receipt():
    """Upload receipt image only — no OCR (pilot: view-only attachment)."""
    user_id = get_jwt_identity()

    if 'image' not in request.files:
        return error_response('image file is required')

    file = request.files['image']
    if not file.filename or not allowed_image(file.filename):
        return error_response('Invalid image format. Allowed: png, jpg, jpeg, webp, heic')

    group_id = request.form.get('group_id')
    image_bytes = file.read()
    image_url = _save_image(image_bytes, file.filename, user_id)

    receipt = Receipt(
        user_id=user_id,
        group_id=group_id or None,
        image_url=image_url,
        status='confirmed',
    )
    db.session.add(receipt)
    db.session.commit()

    from app.common.media import public_media_url

    return success_response(data={
        'receipt_id': receipt.id,
        'image_url': public_media_url(image_url) or image_url,
    }, status_code=201)


@ocr_bp.post('/scan')
@jwt_required()
def scan_receipt():
    user_id = get_jwt_identity()

    if 'image' not in request.files:
        return error_response('image file is required')

    file = request.files['image']
    if not file.filename or not allowed_image(file.filename):
        return error_response('Invalid image format. Allowed: png, jpg, jpeg, webp, heic')

    group_id = request.form.get('group_id')
    image_bytes = file.read()

    # Save image
    image_url = _save_image(image_bytes, file.filename, user_id)

    # OCR scan
    try:
        provider = get_ocr_provider()
        result = provider.scan(image_bytes)
    except Exception as e:
        current_app.logger.error(f'OCR scan failed: {e}')
        return error_response('OCR processing failed. Please try again or enter manually.')

    receipt = Receipt(
        user_id=user_id,
        group_id=group_id or None,
        image_url=image_url,
        ocr_raw={'text': result.raw_text},
        extracted_amount=result.extracted_amount,
        extracted_merchant=result.extracted_merchant,
        extracted_date=result.extracted_date,
        status='pending',
    )
    db.session.add(receipt)
    db.session.commit()

    from app.common.media import public_media_url

    return success_response(data={
        'receipt_id': receipt.id,
        'image_url': public_media_url(image_url) or image_url,
        'extracted': {
            'amount': str(result.extracted_amount) if result.extracted_amount else None,
            'merchant': result.extracted_merchant,
            'date': result.extracted_date.isoformat() if result.extracted_date else None,
        },
        'confidence': result.confidence,
        'needs_review': result.confidence < 0.7,
    }, status_code=201)


@ocr_bp.get('/receipts/<receipt_id>/image')
@jwt_required()
def receipt_image(receipt_id):
    """Serve receipt image to authenticated group members (pilot: local disk)."""
    user_id = get_jwt_identity()
    receipt = db.session.get(Receipt, receipt_id)
    if not receipt:
        return error_response('Receipt not found', status_code=404)
    if not _can_view_receipt(user_id, receipt):
        return error_response('Forbidden', status_code=403)

    image_url = receipt.image_url
    if image_url.startswith('http://') or image_url.startswith('https://'):
        from app.common.media import public_media_url
        url = public_media_url(image_url) or image_url
        return redirect(url)

    resolved = _resolve_local_receipt_path(image_url)
    if not resolved:
        return error_response('Receipt file not found', status_code=404)
    directory, filename = resolved
    guessed, _ = mimetypes.guess_type(filename)
    return send_from_directory(
        directory, filename, mimetype=guessed or 'image/jpeg'
    )


def _can_view_receipt(user_id: str, receipt: Receipt) -> bool:
    if receipt.user_id == user_id:
        return True
    group_ids = set()
    if receipt.group_id:
        group_ids.add(receipt.group_id)
    for (gid,) in db.session.query(Expense.group_id).filter(
        Expense.receipt_id == receipt.id
    ).distinct():
        group_ids.add(gid)
    for gid in group_ids:
        if GroupMember.query.filter_by(group_id=gid, user_id=user_id).first():
            return True
    return False


def _resolve_local_receipt_path(image_url: str) -> tuple[str, str] | None:
    upload_root = os.path.abspath(
        current_app.config.get('STORAGE_LOCAL_PATH', './uploads')
    )
    rel = image_url
    if rel.startswith('/uploads/'):
        rel = rel[len('/uploads/'):]
    elif rel.startswith('uploads/'):
        rel = rel[len('uploads/'):]
    else:
        rel = rel.lstrip('/')
    full = os.path.normpath(os.path.join(upload_root, rel))
    if not full.startswith(upload_root) or not os.path.isfile(full):
        return None
    return os.path.dirname(full), os.path.basename(full)


def _save_image(image_bytes: bytes, filename: str, user_id: str) -> str:
    backend = current_app.config.get('STORAGE_BACKEND', 'local')
    if backend == 's3':
        return _save_to_s3(image_bytes, filename, user_id)
    return _save_local(image_bytes, filename, user_id)


def _save_local(image_bytes: bytes, filename: str, user_id: str) -> str:
    import uuid
    ext = filename.rsplit('.', 1)[-1].lower()
    unique_name = f'{user_id}/{uuid.uuid4().hex}.{ext}'
    upload_path = current_app.config.get('STORAGE_LOCAL_PATH', './uploads')
    user_dir = os.path.join(upload_path, user_id)
    os.makedirs(user_dir, exist_ok=True)
    full_path = os.path.join(upload_path, unique_name)
    with open(full_path, 'wb') as f:
        f.write(image_bytes)
    return f'/uploads/{unique_name}'


def _save_to_s3(image_bytes: bytes, filename: str, user_id: str) -> str:
    import uuid
    import boto3
    ext = filename.rsplit('.', 1)[-1].lower()
    key = f'receipts/{user_id}/{uuid.uuid4().hex}.{ext}'
    s3 = boto3.client('s3')
    s3.put_object(
        Bucket=current_app.config['AWS_S3_BUCKET'],
        Key=key,
        Body=image_bytes,
        ContentType=f'image/{ext}',
    )
    region = current_app.config['AWS_S3_REGION']
    bucket = current_app.config['AWS_S3_BUCKET']
    return f'https://{bucket}.s3.{region}.amazonaws.com/{key}'
