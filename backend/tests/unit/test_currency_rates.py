"""Unit tests — currency rate resolution."""
from decimal import Decimal
from unittest.mock import patch

import pytest

from app import create_app, db
from app.currency.routes import _get_best_rate, refresh_all_exchange_rates, SUPPORTED_CURRENCIES
from app.models import ExchangeRate
from config import TestingConfig


@pytest.fixture
def app():
    application = create_app(TestingConfig)
    with application.app_context():
        db.create_all()
        yield application
        db.session.remove()


def _clear_exchange_rate_cache():
    """Remove cached rows so this test controls the rate state it needs."""
    ExchangeRate.query.delete()
    db.session.commit()


def test_get_best_rate_uses_live_api_when_cache_empty(app):
    _clear_exchange_rate_cache()
    with patch('app.currency.routes._fetch_live_rates') as mock_fetch:
        mock_fetch.return_value = {'ILS': Decimal('2.95')}
        rate = _get_best_rate('USD', 'ILS')
    assert rate == Decimal('2.95')
    mock_fetch.assert_called_once_with('USD')


def test_get_best_rate_falls_back_to_inverse_base(app):
    _clear_exchange_rate_cache()
    inverse = Decimal('0.339')
    expected = (Decimal('1') / inverse).quantize(Decimal('0.000001'))
    with patch('app.currency.routes._fetch_live_rates') as mock_fetch:
        mock_fetch.side_effect = [{}, {'USD': inverse}]
        rate = _get_best_rate('USD', 'ILS')
    assert rate == expected
    assert mock_fetch.call_count == 2
    assert mock_fetch.call_args_list[0].args == ('USD',)
    assert mock_fetch.call_args_list[1].args == ('ILS',)


def test_get_best_rate_same_currency(app):
    assert _get_best_rate('ILS', 'ILS') == Decimal('1')


def test_refresh_all_exchange_rates_covers_all_supported(app):
    with patch('app.currency.routes._fetch_live_rates') as mock_fetch:
        mock_fetch.return_value = {'ILS': Decimal('3.55')}
        results = refresh_all_exchange_rates()
    assert set(results.keys()) == set(SUPPORTED_CURRENCIES)
    assert mock_fetch.call_count == len(SUPPORTED_CURRENCIES)
