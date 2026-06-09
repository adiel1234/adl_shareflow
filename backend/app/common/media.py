"""Public URL helpers for uploaded media."""
from flask import current_app, request


def public_media_url(relative_or_absolute: str | None) -> str | None:
    if not relative_or_absolute:
        return None
    if relative_or_absolute.startswith('http://') or relative_or_absolute.startswith('https://'):
        return relative_or_absolute
    base = (current_app.config.get('PUBLIC_BASE_URL') or '').rstrip('/')
    if not base and request:
        base = request.host_url.rstrip('/')
    path = relative_or_absolute if relative_or_absolute.startswith('/') else f'/{relative_or_absolute}'
    return f'{base}{path}' if base else relative_or_absolute
