"""Public URL helpers for uploaded media."""
from flask import current_app, request


def _public_base_url() -> str:
    base = (current_app.config.get('PUBLIC_BASE_URL') or '').rstrip('/')
    if base.endswith('/api'):
        base = base[:-4]
    if not base and request:
        base = request.host_url.rstrip('/')
        if base.endswith('/api'):
            base = base[:-4]
    return base


def _normalize_upload_path(path: str) -> str:
    if path.startswith('/api/uploads/'):
        return path[4:]
    if path.startswith('api/uploads/'):
        return f'/{path[4:]}'
    return path if path.startswith('/') else f'/{path}'


def public_media_url(relative_or_absolute: str | None) -> str | None:
    if not relative_or_absolute:
        return None
    if relative_or_absolute.startswith('http://') or relative_or_absolute.startswith('https://'):
        for wrong in ('/api/uploads/', '/api/uploads'):
            if wrong in relative_or_absolute:
                return relative_or_absolute.replace('/api/uploads', '/uploads', 1)
        return relative_or_absolute
    base = _public_base_url()
    path = _normalize_upload_path(relative_or_absolute)
    return f'{base}{path}' if base else path
