"""Unit tests — currency rate resolution."""
from decimal import Decimal
from unittest.mock import patch

import pytest

from app import create_app, db
from app.currency.routes import _get_best_rate
from config import TestingConfig


@pytest.fixture
def app():
    application = create_app(TestingConfig)
    with application.app_context():
        db.create_all()
        yield application
        db.session.remove()


def test_get_best_rate_uses_live_api_when_cache_empty(app):
    with patch('app.currency.routes._fetch_live_rates') as mock_fetch:
        mock_fetch.return_value = {'ILS': Decimal('2.95')}
        rate = _get_best_rate('USD', 'ILS')
    assert rate == Decimal('2.95')
    mock_fetch.assert_called_once_with('USD')


def test_get_best_rate_falls_back_to_inverse_base(app):
    with patch('app.currency.routes._fetch_live_rates') as mock_fetch:
        mock_fetch.side_effect = [{}, {'USD': Decimal('0.339')}]
        rate = _get_best_rate('USD', 'ILS')
    assert rate == Decimal('2.950000')
    assert mock_fetch.call_count == 2


def test_get_best_rate_same_currency(app):
    assert _get_best_rate('ILS', 'ILS') == Decimal('1')
