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

from app import db
from app.models import FeatureFlag

logger = logging.getLogger(__name__)
iap_bp = Blueprint('iap', __name__, url_prefix='/api/iap')

APPLE_BUNDLE_ID = 'com.adl.shareflow'
APPLE_VERIFY_URL_PROD = 'https://buy.itunes.apple.com/verifyReceipt'
APPLE_VERIFY_URL_SANDBOX = 'https://sandbox.itunes.apple.com/verifyReceipt'


def _payments_enabled() -> bool:
    flag = FeatureFlag.query.filter_by(key='PAYMENTS_ENABLED').first()
    return bool(flag and str(flag.value).lower() in ('true', '1', 'yes'))


# ---------------------------------------------------------------------------
# Apple receipt validation
# ---------------------------------------------------------------------------

def verify_apple_receipt(receipt_data: str, product_id: str) -> dict:
    """
    Validates an iOS receipt with Apple's servers.
    Returns {'valid': bool, 'error': str|None}.
    """
    shared_secret = os.environ.get('APPLE_SHARED_SECRET', '')
    if not shared_secret:
        logger.error('[iap] APPLE_SHARED_SECRET not set')
        return {'valid': False, 'error': 'Server misconfiguration: missing Apple shared secret'}

    payload = {
        'receipt-data': receipt_data,
        'password': shared_secret,
        'exclude-old-transactions': True,
    }

    # Try production first, fall back to sandbox (status 21007)
    for url in (APPLE_VERIFY_URL_PROD, APPLE_VERIFY_URL_SANDBOX):
        try:
            resp = requests.post(url, json=payload, timeout=15)
            resp.raise_for_status()
            data = resp.json()
            status = data.get('status', -1)
            if status == 21007:
                continue  # sandbox receipt, try sandbox URL
            if status != 0:
                return {'valid': False, 'error': f'Apple validation failed: status {status}'}

            # Find the matching transaction in latest_receipt_info
            transactions = data.get('latest_receipt_info', [])
            for txn in transactions:
                if txn.get('product_id') == product_id:
                    return {'valid': True, 'error': None, 'transaction_id': txn.get('transaction_id')}

            # Also check receipt.in_app for consumables
            in_app = data.get('receipt', {}).get('in_app', [])
            for txn in in_app:
                if txn.get('product_id') == product_id:
                    return {'valid': True, 'error': None, 'transaction_id': txn.get('transaction_id')}

            return {'valid': False, 'error': 'Receipt valid but product not found in transactions'}
        except requests.RequestException as e:
            logger.exception('[iap] Apple validation request failed')
            return {'valid': False, 'error': str(e)}

    return {'valid': False, 'error': 'Apple validation failed after retries'}


# ---------------------------------------------------------------------------
# Google Play receipt validation
# ---------------------------------------------------------------------------

def verify_google_receipt(purchase_token: str, product_id: str) -> dict:
    """
    Validates an Android purchase token with Google Play.
    Returns {'valid': bool, 'error': str|None}.

    Requires GOOGLE_PLAY_CREDENTIALS_JSON env var (service account JSON).
    """
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
            packageName=APPLE_BUNDLE_ID,
            productId=product_id,
            token=purchase_token,
        ).execute()

        # purchaseState: 0=purchased, 1=cancelled, 2=pending
        if result.get('purchaseState') != 0:
            return {'valid': False, 'error': 'Purchase not in purchased state'}

        return {'valid': True, 'error': None, 'order_id': result.get('orderId')}

    except ImportError:
        return {'valid': False, 'error': 'google-api-python-client not installed'}
    except Exception as e:
        logger.exception('[iap] Google Play validation failed')
        return {'valid': False, 'error': str(e)}


# ---------------------------------------------------------------------------
# Public helper — called by groups routes
# ---------------------------------------------------------------------------

def validate_iap_receipt(receipt_data: str, platform: str, product_id: str) -> dict:
    """
    Validates a receipt/token from iOS or Android.
    Returns {'valid': bool, 'error': str|None}.
    When PAYMENTS_ENABLED=false, always returns valid (pilot mode).
    """
    if not _payments_enabled():
        return {'valid': True, 'error': None}

    if platform == 'ios':
        return verify_apple_receipt(receipt_data, product_id)
    elif platform == 'android':
        return verify_google_receipt(receipt_data, product_id)
    else:
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
