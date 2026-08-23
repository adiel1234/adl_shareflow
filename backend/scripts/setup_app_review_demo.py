#!/usr/bin/env python3
"""
Create / refresh App Store review demo account + sample group on production.

Writes credentials to repo-root `.store_review_account.local` (gitignored).
Does NOT build or upload an IPA.

  cd backend && python scripts/setup_app_review_demo.py
"""
from __future__ import annotations

import json
import os
import secrets
import string
import sys
from datetime import date, timedelta
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.store_review_account.local'
BASE = os.getenv('SHAREFLOW_API', 'https://adlshareflow-production.up.railway.app/api')

# Stable identity for App Review (not a real inbox — login only).
EMAIL = 'apple.review@shareflow-demo.local'
DISPLAY = 'App Review Demo'

SAMPLE_EXPENSES = [
    ('ארוחת ערב משותפת', 240, 'ILS', 'food', 2),
    ('סופר לשבת', 186, 'ILS', 'shopping', 5),
    ('מונית משדה התעופה', 45, 'EUR', 'transport', 8),
    ('מלון לילה אחד', 120, 'EUR', 'housing', 10),
    ('קפה ומאפים', 68, 'ILS', 'food', 1),
    ('כרטיסי מוזיאון', 36, 'EUR', 'entertainment', 3),
    ('דלק', 210, 'ILS', 'transport', 4),
    ('מתנה משותפת', 150, 'ILS', 'shopping', 6),
]


def _ok(resp: requests.Response):
    try:
        body = resp.json()
    except Exception:
        body = {'raw': resp.text[:400]}
    if resp.status_code >= 400:
        raise RuntimeError(f'{resp.request.method} {resp.url} → {resp.status_code}: {body}')
    return body.get('data', body)


def _password(n: int = 16) -> str:
    alphabet = string.ascii_letters + string.digits
    return 'Ar!' + ''.join(secrets.choice(alphabet) for _ in range(n))


def main() -> int:
    admin_key = os.getenv('SHAREFLOW_ADMIN_KEY') or os.getenv('ADL_ADMIN_KEY', '')
    if not admin_key:
        # Pull from Railway without printing
        try:
            import subprocess
            raw = subprocess.check_output(
                ['railway', 'variables', '--json'],
                cwd=str(ROOT),
                text=True,
            )
            import json as _json
            admin_key = _json.loads(raw).get('ADL_ADMIN_KEY', '')
        except Exception:
            admin_key = ''
    if not admin_key:
        print('ERROR: ADL_ADMIN_KEY missing', file=sys.stderr)
        return 1

    base = BASE.rstrip('/')
    adl = f'{base}/adl'
    s = requests.Session()
    s.headers['Content-Type'] = 'application/json'

    password = None
    if OUT.exists():
        try:
            prev = json.loads(OUT.read_text())
            password = prev.get('password')
        except Exception:
            password = None
    if not password:
        password = _password()

    # Register or login
    reg = s.post(f'{base}/auth/register', json={
        'email': EMAIL,
        'password': password,
        'display_name': DISPLAY,
    })
    if reg.status_code < 400:
        auth = _ok(reg)
        print(f'Registered {EMAIL}')
    else:
        login = s.post(f'{base}/auth/login', json={'email': EMAIL, 'password': password})
        if login.status_code >= 400:
            # Password rotated — create fresh password and try register again fails → reset via new account stamp
            password = _password()
            # If email exists with unknown password, fail clearly
            print(
                'ERROR: account exists but local password mismatch. '
                'Delete .store_review_account.local only after resetting user, '
                'or change EMAIL in this script.',
                file=sys.stderr,
            )
            print(login.text[:300], file=sys.stderr)
            return 1
        auth = _ok(login)
        print(f'Logged in {EMAIL}')

    token = auth['access_token']
    user = auth['user']
    uid = user['id']
    s.headers['Authorization'] = f'Bearer {token}'

    # Ensure active (admin activate)
    try:
        _ok(s.put(
            f'{adl}/users/{uid}/activate',
            headers={'X-ADL-Admin-Key': admin_key},
            json={},
        ))
    except Exception as e:
        print(f'note: activate skipped ({e})')

    group = _ok(s.post(f'{base}/groups', json={
        'name': 'קבוצת הדגמה — App Review',
        'base_currency': 'ILS',
        'category': 'trip',
        'group_type': 'event',
        'description': 'Demo group for Apple App Review screenshots and testing',
    }))
    gid = group['id']
    print(f'Group: {gid}')

    _ok(s.post(
        f'{adl}/groups/{gid}/activate',
        headers={'X-ADL-Admin-Key': admin_key},
        json={'split_among_group': False},
    ))

    guests = []
    for name in ('נועה כהן', 'יואב לוי', 'מאיה ישראלי'):
        g = _ok(s.post(f'{base}/groups/{gid}/guests', json={
            'name': name,
            'split_mode': 'forward',
        }))
        guests.append(g['user_id'])

    members = [uid] + guests
    today = date.today()
    rates = {'ILS': 1.0, 'EUR': 4.0, 'USD': 3.7}

    for title, amount, cur, cat, days_ago in SAMPLE_EXPENSES:
        rate = rates[cur]
        converted = round(amount * rate, 2)
        n = len(members)
        share = round(converted / n, 2)
        shares = [share] * (n - 1)
        shares.append(round(converted - sum(shares), 2))
        exp_date = (today - timedelta(days=days_ago)).isoformat()
        _ok(s.post(f'{base}/groups/{gid}/expenses', json={
            'title': title,
            'original_amount': str(amount),
            'original_currency': cur,
            'exchange_rate': rate,
            'paid_by': members[days_ago % len(members)],
            'split_type': 'equal',
            'category': cat,
            'expense_date': exp_date,
            'participants': [
                {'user_id': mid, 'share_amount': str(sh)}
                for mid, sh in zip(members, shares)
            ],
        }))

    payload = {
        'email': EMAIL,
        'password': password,
        'display_name': DISPLAY,
        'user_id': uid,
        'group_id': gid,
        'group_name': 'קבוצת הדגמה — App Review',
        'api': base,
        'notes': 'Paste email/password into App Store Connect → App Review Information',
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n')
    print(f'Wrote {OUT} (gitignored)')
    print('Demo ready for ASC App Review fields.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
