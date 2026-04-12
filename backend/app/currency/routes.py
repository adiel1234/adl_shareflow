from datetime import datetime, timedelta
from decimal import Decimal

from flask import Blueprint, request, current_app
from flask_jwt_extended import jwt_required

from app import db
from app.models import ExchangeRate
from app.common.errors import success_response, error_response

currency_bp = Blueprint('currency', __name__)

# Fallback rates (updated periodically — used if live fetch fails)
FALLBACK_RATES = {
    ('USD', 'ILS'): Decimal('3.68'),
    ('ILS', 'USD'): Decimal('0.272'),
    ('EUR', 'ILS'): Decimal('4.02'),
    ('ILS', 'EUR'): Decimal('0.249'),
    ('GBP', 'ILS'): Decimal('4.72'),
    ('ILS', 'GBP'): Decimal('0.212'),
    ('JPY', 'ILS'): Decimal('0.024'),
    ('ILS', 'JPY'): Decimal('41.5'),
    ('AED', 'ILS'): Decimal('1.00'),
    ('ILS', 'AED'): Decimal('1.00'),
    ('USD', 'EUR'): Decimal('0.92'),
    ('EUR', 'USD'): Decimal('1.09'),
}

SUPPORTED_CURRENCIES = ['ILS', 'USD', 'EUR', 'GBP', 'JPY', 'AED', 'CHF', 'CAD', 'AUD']
RATE_CACHE_HOURS = 6  # Refresh rates every 6 hours


@currency_bp.get('/rates')
@jwt_required()
def get_rates():
    from_currency = (request.args.get('from') or 'ILS').upper()
    to_currency = (request.args.get('to') or '').upper()

    # Check DB for fresh rates (less than RATE_CACHE_HOURS old)
    cutoff = datetime.utcnow() - timedelta(hours=RATE_CACHE_HOURS)
    q = ExchangeRate.query.filter(
        ExchangeRate.from_currency == from_currency,
        ExchangeRate.fetched_at >= cutoff,
    )
    if to_currency:
        q = q.filter_by(to_currency=to_currency)
    db_rates = q.order_by(ExchangeRate.fetched_at.desc()).all()

    if db_rates:
        return success_response(data={
            'rates': [r.to_dict() for r in db_rates],
            'source': 'cache',
        })

    # Try live fetch
    live_rates = _fetch_live_rates(from_currency)
    if live_rates:
        _save_rates_to_db(from_currency, live_rates)
        result = []
        for tc, rate in live_rates.items():
            if not to_currency or tc == to_currency:
                result.append({
                    'from_currency': from_currency,
                    'to_currency': tc,
                    'rate': str(rate),
                    'source': 'live',
                })
        return success_response(data={'rates': result, 'source': 'live'})

    # Fallback to hardcoded rates
    fallback = []
    for (fc, tc), rate in FALLBACK_RATES.items():
        if fc == from_currency and (not to_currency or tc == to_currency):
            fallback.append({
                'from_currency': fc,
                'to_currency': tc,
                'rate': str(rate),
                'source': 'fallback',
            })
    return success_response(data={'rates': fallback, 'source': 'fallback'})


@currency_bp.get('/convert')
@jwt_required()
def convert():
    """Quick conversion: /api/currency/convert?from=USD&to=ILS&amount=100"""
    from_currency = (request.args.get('from') or 'ILS').upper()
    to_currency = (request.args.get('to') or 'ILS').upper()
    try:
        amount = Decimal(str(request.args.get('amount', '1')))
    except Exception:
        return error_response('amount must be a valid number')

    if from_currency == to_currency:
        return success_response(data={
            'from_currency': from_currency,
            'to_currency': to_currency,
            'original_amount': str(amount),
            'converted_amount': str(amount),
            'rate': '1.0',
        })

    rate = _get_best_rate(from_currency, to_currency)
    if not rate:
        return error_response(f'No rate available for {from_currency} → {to_currency}', 404)

    converted = (amount * rate).quantize(Decimal('0.01'))
    return success_response(data={
        'from_currency': from_currency,
        'to_currency': to_currency,
        'original_amount': str(amount),
        'converted_amount': str(converted),
        'rate': str(rate),
    })


@currency_bp.post('/rates')
@jwt_required()
def set_rate():
    data = request.get_json(silent=True) or {}
    from_currency = (data.get('from_currency') or '').upper()
    to_currency = (data.get('to_currency') or '').upper()

    if not from_currency or not to_currency:
        return error_response('from_currency and to_currency are required')

    try:
        rate = Decimal(str(data.get('rate', 0)))
        if rate <= 0:
            raise ValueError()
    except Exception:
        return error_response('rate must be a positive number')

    exchange_rate = ExchangeRate(
        from_currency=from_currency,
        to_currency=to_currency,
        rate=rate,
        source='manual',
    )
    db.session.add(exchange_rate)
    db.session.commit()
    return success_response(data=exchange_rate.to_dict(), status_code=201)


@currency_bp.post('/refresh')
@jwt_required()
def refresh_rates():
    """Force-refresh all rates from live API."""
    results = {}
    for base in ['ILS', 'USD', 'EUR']:
        rates = _fetch_live_rates(base)
        if rates:
            _save_rates_to_db(base, rates)
            results[base] = list(rates.keys())
    return success_response(data={'refreshed': results})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _fetch_live_rates(base_currency: str) -> dict:
    """Fetch live rates from ExchangeRate-API (free, no key needed)."""
    try:
        import urllib.request
        import json
        url = f'https://api.exchangerate-api.com/v4/latest/{base_currency}'
        with urllib.request.urlopen(url, timeout=5) as resp:
            data = json.loads(resp.read())
        rates = {}
        for currency in SUPPORTED_CURRENCIES:
            if currency != base_currency and currency in data.get('rates', {}):
                rates[currency] = Decimal(str(data['rates'][currency]))
        return rates
    except Exception as e:
        current_app.logger.warning(f'Live rate fetch failed for {base_currency}: {e}')
        return {}


def _save_rates_to_db(base_currency: str, rates: dict):
    try:
        for to_currency, rate in rates.items():
            er = ExchangeRate(
                from_currency=base_currency,
                to_currency=to_currency,
                rate=rate,
                source='api',
            )
            db.session.add(er)
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f'Failed saving rates: {e}')


def _get_best_rate(from_currency: str, to_currency: str) -> Decimal | None:
    cutoff = datetime.utcnow() - timedelta(hours=RATE_CACHE_HOURS)
    er = ExchangeRate.query.filter(
        ExchangeRate.from_currency == from_currency,
        ExchangeRate.to_currency == to_currency,
        ExchangeRate.fetched_at >= cutoff,
    ).order_by(ExchangeRate.fetched_at.desc()).first()
    if er:
        return er.rate
    return FALLBACK_RATES.get((from_currency, to_currency))
