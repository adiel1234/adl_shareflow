"""Anonymous pilot funnel tracking (downloads / install page views)."""
from __future__ import annotations

import logging

from flask import request

from app import db
from app.models import PilotFunnelEvent

logger = logging.getLogger(__name__)


def platform_from_ua(ua: str | None = None) -> str:
    ua = (ua or request.headers.get('User-Agent') or '').lower()
    if 'android' in ua:
        return 'android'
    if 'iphone' in ua or 'ipad' in ua or 'ipod' in ua:
        return 'ios'
    return 'other'


def track_funnel_event(event: str, platform: str | None = None) -> None:
    """Best-effort insert — never break the download/redirect path."""
    try:
        row = PilotFunnelEvent(
            event=event,
            platform=platform or platform_from_ua(),
        )
        db.session.add(row)
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        logger.warning('funnel track failed (%s): %s', event, exc)
