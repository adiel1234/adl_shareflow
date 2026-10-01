"""Authoritative decision: whether a paid IAP receipt is required.

Global PAYMENTS_ENABLED remains the kill switch for everyone.
IAP_REVIEW_USER_IDS is an optional allow-list of verified user UUIDs
that must still complete real StoreKit validation while the global
flag is off.

Identity must come from a verified JWT subject, never from the client.
"""
from __future__ import annotations

import os
import uuid

REVIEW_USER_IDS_ENV = 'IAP_REVIEW_USER_IDS'


def parse_review_user_ids(raw: str | None) -> frozenset[str]:
    """Parse a comma-separated UUID list. Invalid tokens are ignored.

    Wildcards, booleans, or other non-UUID values never match anyone.
    """
    if raw is None:
        return frozenset()
    text = str(raw).strip()
    if not text:
        return frozenset()

    found: set[str] = set()
    for part in text.replace(';', ',').replace('\n', ',').split(','):
        token = part.strip().strip('"').strip("'")
        if not token:
            continue
        try:
            found.add(str(uuid.UUID(token)))
        except (ValueError, AttributeError, TypeError):
            continue
    return frozenset(found)


def review_user_ids_from_env() -> frozenset[str]:
    return parse_review_user_ids(os.environ.get(REVIEW_USER_IDS_ENV))


def normalize_user_id(user_id: str | None) -> str | None:
    if user_id is None:
        return None
    text = str(user_id).strip()
    if not text:
        return None
    try:
        return str(uuid.UUID(text))
    except (ValueError, AttributeError, TypeError):
        return None


def global_payments_enabled() -> bool:
    """True only when the PAYMENTS_ENABLED feature flag is explicitly on."""
    from app.models import FeatureFlag
    from app.pilot_mode import flag_truthy

    flag = FeatureFlag.query.filter_by(key='PAYMENTS_ENABLED').first()
    return flag_truthy(flag.value if flag else None)


def payments_required_for_user(user_id: str | None) -> bool:
    """Return whether this authenticated user must complete real IAP.

    Global flag on → everyone. Otherwise only an allow-listed UUID.
    Missing, empty, or malformed allow-list values fail closed.
    """
    if global_payments_enabled():
        return True
    normalized = normalize_user_id(user_id)
    if normalized is None:
        return False
    return normalized in review_user_ids_from_env()
