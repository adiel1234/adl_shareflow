"""
IAP receipt validation.

Validates in-app purchase receipts from Apple (iOS) and Google Play (Android)
before allowing group activation/extension/renewal.

Required environment variables:
  APPLE_SHARED_SECRET  – Found in App Store Connect → Your App → In-App Purchases → App-Specific Shared Secret
  GOOGLE_PLAY_CREDENTIALS_JSON  – Service account JSON with androidpublisher scope
                                   (Google Play Console → Setup → API access → Service account)

When PAYMENTS_ENABLED=false (pilot mode), validation is skipped automatically.
"""
import json
import logging
import os

import requests
from flask import Blueprint, jsonify, request

from flask_jwt_extended import jwt_required, get_jwt_identity

from sqlalchemy.exc import IntegrityError

from app import db
from app.models import FeatureFlag, IapProcessedTransaction

logger = logging.getLogger(__name__)
iap_bp = Blueprint('iap', __name__, url_prefix='/api/iap')

APPLE_BUNDLE_ID = 'com.adl.shareflow'
ANDROID_PACKAGE_NAME = 'com.adl.shareflow'
APPLE_VERIFY_URL_PROD = 'https://buy.itunes.apple.com/verifyReceipt'
APPLE_VERIFY_URL_SANDBOX = 'https://sandbox.itunes.apple.com/verifyReceipt'


def _payments_enabled() -> bool:
    flag = FeatureFlag.query.filter_by(key='PAYMENTS_ENABLED').first()
    return bool(flag and str(flag.value).lower() in ('true', '1', 'yes'))


# ---------------------------------------------------------------------------
# Apple receipt validation
# ---------------------------------------------------------------------------

def _apple_transactions(data: dict) -> list[dict]:
    """Product IDs and transaction IDs from Apple-verified receipt JSON."""
    found = []
    seen = set()
    sources = [
        data.get('latest_receipt_info') or [],
        (data.get('receipt') or {}).get('in_app') or [],
    ]
    for source in sources:
        for txn in source:
            product_id = txn.get('product_id')
            transaction_id = txn.get('transaction_id')
            if not product_id or not transaction_id:
                continue
            key = (transaction_id, product_id)
            if key in seen:
                continue
            seen.add(key)
            found.append({
                'product_id': product_id,
                'transaction_id': str(transaction_id),
            })
    return found


def verify_apple_receipt(receipt_data: str) -> dict:
    """
    Validates an iOS receipt with Apple's servers.
    Does not trust a client-supplied Product ID.
    Returns {'valid': bool, 'error': str|None, 'transactions': list}.
    """
    if not receipt_data:
        return {'valid': False, 'error': 'חסרה קבלת תשלום', 'transactions': []}

    shared_secret = os.environ.get('APPLE_SHARED_SECRET', '')
    if not shared_secret:
        logger.error('[iap] APPLE_SHARED_SECRET not set')
        return {
            'valid': False,
            'error': 'Server misconfiguration: missing Apple shared secret',
            'transactions': [],
        }

    payload = {
        'receipt-data': receipt_data,
        'password': shared_secret,
        'exclude-old-transactions': True,
    }

    for url in (APPLE_VERIFY_URL_PROD, APPLE_VERIFY_URL_SANDBOX):
        try:
            resp = requests.post(url, json=payload, timeout=15)
            resp.raise_for_status()
            data = resp.json()
            status = data.get('status', -1)
            if status == 21007:
                continue
            if status != 0:
                return {
                    'valid': False,
                    'error': f'Apple validation failed: status {status}',
                    'transactions': [],
                }
            return {
                'valid': True,
                'error': None,
                'transactions': _apple_transactions(data),
            }
        except requests.RequestException as e:
            logger.exception('[iap] Apple validation request failed')
            return {'valid': False, 'error': str(e), 'transactions': []}

    return {'valid': False, 'error': 'Apple validation failed after retries', 'transactions': []}


# ---------------------------------------------------------------------------
# Google Play receipt validation
# ---------------------------------------------------------------------------

def verify_google_receipt(purchase_token: str, expected_product_id: str) -> dict:
    """
    Validates an Android purchase token with Google Play.
    Queries the server-calculated Product ID, not a client-supplied ID.
    Returns {'valid': bool, 'error': str|None, 'transaction_id': str|None, 'product_id': str|None}.
    """
    if not purchase_token:
        return {'valid': False, 'error': 'חסרה קבלת תשלום'}

    creds_json = os.environ.get('GOOGLE_PLAY_CREDENTIALS_JSON', '')
    if not creds_json:
        logger.error('[iap] GOOGLE_PLAY_CREDENTIALS_JSON not set')
        return {'valid': False, 'error': 'Server misconfiguration: missing Google Play credentials'}

    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build

        creds_dict = json.loads(creds_json)
        credentials = service_account.Credentials.from_service_account_info(
            creds_dict,
            scopes=['https://www.googleapis.com/auth/androidpublisher'],
        )
        service = build('androidpublisher', 'v3', credentials=credentials)
        result = service.purchases().products().get(
            packageName=ANDROID_PACKAGE_NAME,
            productId=expected_product_id,
            token=purchase_token,
        ).execute()

        if result.get('purchaseState') != 0:
            return {'valid': False, 'error': 'Purchase not in purchased state'}

        order_id = result.get('orderId')
        if not order_id:
            return {'valid': False, 'error': 'Google Play order id missing'}

        return {
            'valid': True,
            'error': None,
            'transaction_id': str(order_id),
            'product_id': expected_product_id,
        }

    except ImportError:
        return {'valid': False, 'error': 'google-api-python-client not installed'}
    except Exception as e:
        logger.exception('[iap] Google Play validation failed')
        return {'valid': False, 'error': str(e)}


# ---------------------------------------------------------------------------
# Public helper — called by groups routes
# ---------------------------------------------------------------------------

def _reserve_transaction(
    transaction_id: str,
    product_id: str,
    platform: str,
    operation: str,
    group_id: str,
    user_id: str,
) -> dict:
    """Insert a used-transaction row. Unique transaction_id is the replay lock."""
    existing = IapProcessedTransaction.query.filter_by(
        transaction_id=transaction_id
    ).first()
    if existing:
        return {'valid': False, 'error': 'העסקה כבר מומשה'}

    db.session.add(IapProcessedTransaction(
        transaction_id=transaction_id,
        product_id=product_id,
        platform=platform,
        operation=operation,
        group_id=group_id,
        user_id=user_id,
    ))
    try:
        db.session.flush()
    except IntegrityError:
        db.session.rollback()
        return {'valid': False, 'error': 'העסקה כבר מומשה'}
    return {'valid': True, 'error': None}


def validate_paid_operation(
    receipt_data: str,
    platform: str,
    expected_product_id: str,
    operation: str,
    group_id: str,
    user_id: str,
) -> dict:
    """
    When PAYMENTS_ENABLED=true: verify store receipt, require the
    server-calculated Product ID, and consume the Apple/Play transaction once.
    Client-supplied product_id is ignored.
    """
    if not _payments_enabled():
        return {'valid': True, 'error': None}

    if platform == 'ios':
        apple = verify_apple_receipt(receipt_data)
        if not apple['valid']:
            return {'valid': False, 'error': apple.get('error') or 'תשלום לא אומת'}
        matching = [
            t for t in apple.get('transactions') or []
            if t.get('product_id') == expected_product_id
        ]
        if not matching:
            return {'valid': False, 'error': 'המוצר ששולם אינו תואם למדרגה הנדרשת'}
        last_error = 'העסקה כבר מומשה'
        for txn in matching:
            reserved = _reserve_transaction(
                txn['transaction_id'],
                expected_product_id,
                'ios',
                operation,
                group_id,
                user_id,
            )
            if reserved['valid']:
                return reserved
            last_error = reserved.get('error') or last_error
        return {'valid': False, 'error': last_error}

    if platform == 'android':
        google = verify_google_receipt(receipt_data, expected_product_id)
        if not google.get('valid'):
            return {'valid': False, 'error': google.get('error') or 'תשלום לא אומת'}
        actual = google.get('product_id')
        if actual != expected_product_id:
            return {'valid': False, 'error': 'המוצר ששולם אינו תואם למדרגה הנדרשת'}
        return _reserve_transaction(
            google['transaction_id'],
            expected_product_id,
            'android',
            operation,
            group_id,
            user_id,
        )

    return {'valid': False, 'error': f'Unknown platform: {platform}'}


# ---------------------------------------------------------------------------
# Debug endpoint (requires auth)
# ---------------------------------------------------------------------------

@iap_bp.get('/status')
@jwt_required()
def iap_status():
    """Returns IAP configuration status for debugging."""
    has_apple = bool(os.environ.get('APPLE_SHARED_SECRET'))
    has_google = bool(os.environ.get('GOOGLE_PLAY_CREDENTIALS_JSON'))
    return jsonify({
        'payments_enabled': _payments_enabled(),
        'apple_secret_set': has_apple,
        'google_credentials_set': has_google,
    })
