#!/usr/bin/env python3
"""
Load probe: 50 members (1 admin + 49 guests) and 100 expenses.

Usage (from backend/):
  python scripts/load_probe_50x100.py
  python scripts/load_probe_50x100.py --base-url http://127.0.0.1:5050/api
  python scripts/load_probe_50x100.py --members 50 --expenses 100

Requires ADL_ADMIN_KEY in env (or backend/.env) to activate past the free 7-member limit.
"""
from __future__ import annotations

import argparse
import os
import statistics
import sys
import time
import uuid
from pathlib import Path

import requests

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parents[1] / '.env')
except Exception:
    pass


def _ms(seconds: float) -> float:
    return round(seconds * 1000, 1)


def _ok(resp: requests.Response) -> dict:
    try:
        body = resp.json()
    except Exception:
        body = {'raw': resp.text[:300]}
    if resp.status_code >= 400:
        raise RuntimeError(f'{resp.request.method} {resp.request.url} → {resp.status_code}: {body}')
    return body.get('data', body)


def main() -> int:
    parser = argparse.ArgumentParser(description='ShareFlow load probe 50×100')
    parser.add_argument('--base-url', default=os.getenv('LOAD_PROBE_BASE_URL', 'http://127.0.0.1:5050/api'))
    parser.add_argument('--members', type=int, default=50, help='Total members including admin')
    parser.add_argument('--expenses', type=int, default=100)
    parser.add_argument('--admin-key', default=os.getenv('ADL_ADMIN_KEY', ''))
    args = parser.parse_args()

    base = args.base_url.rstrip('/')
    adl_base = base.replace('/api', '/api/adl') if base.endswith('/api') else f'{base}/adl'
    guest_count = max(args.members - 1, 0)
    stamp = uuid.uuid4().hex[:8]
    email = f'loadprobe_{stamp}@shareflowtest.local'
    password = 'LoadProbe1!'

    print(f'Base URL: {base}')
    print(f'Target: {args.members} members, {args.expenses} expenses')
    print()

    s = requests.Session()
    s.headers.update({'Content-Type': 'application/json'})

    t0 = time.perf_counter()
    auth = _ok(s.post(f'{base}/auth/register', json={
        'email': email,
        'password': password,
        'display_name': f'Load Probe {stamp}',
    }))
    token = auth['access_token']
    user_id = auth['user']['id']
    s.headers['Authorization'] = f'Bearer {token}'
    print(f'Register: {_ms(time.perf_counter() - t0)} ms  ({email})')

    t0 = time.perf_counter()
    group = _ok(s.post(f'{base}/groups', json={
        'name': f'עומס {stamp} — 50×100',
        'base_currency': 'ILS',
        'category': 'event',
        'group_type': 'event',
    }))
    group_id = group['id']
    print(f'Create group: {_ms(time.perf_counter() - t0)} ms  ({group_id})')

    if not args.admin_key:
        print('ERROR: ADL_ADMIN_KEY missing — cannot activate group past free limit (7 members).')
        return 1

    t0 = time.perf_counter()
    act = s.post(
        f'{adl_base}/groups/{group_id}/activate',
        headers={'X-ADL-Admin-Key': args.admin_key},
        json={'split_among_group': False},
    )
    _ok(act)
    print(f'Admin activate: {_ms(time.perf_counter() - t0)} ms')

    guest_ids: list[str] = []
    guest_times: list[float] = []
    t_guests = time.perf_counter()
    for i in range(1, guest_count + 1):
        t1 = time.perf_counter()
        g = _ok(s.post(f'{base}/groups/{group_id}/guests', json={
            'name': f'אורח {i:02d}',
            'split_mode': 'forward',
        }))
        guest_ids.append(g['user_id'])
        guest_times.append(time.perf_counter() - t1)
        if i % 10 == 0 or i == guest_count:
            print(f'  guests {i}/{guest_count}…')
    print(
        f'Add {guest_count} guests: {_ms(time.perf_counter() - t_guests)} ms '
        f'(avg {_ms(statistics.mean(guest_times))} / p95 {_ms(statistics.quantiles(guest_times, n=20)[18])})'
    )

    payers = [user_id] + guest_ids
    currencies = ['ILS', 'ILS', 'ILS', 'USD', 'EUR']
    exp_times: list[float] = []
    t_exp = time.perf_counter()
    for i in range(1, args.expenses + 1):
        t1 = time.perf_counter()
        cur = currencies[i % len(currencies)]
        amount = 10 + (i % 90)
        _ok(s.post(f'{base}/groups/{group_id}/expenses', json={
            'title': f'הוצאה {i:03d}',
            'original_amount': str(amount),
            'original_currency': cur,
            'paid_by': payers[i % len(payers)],
            'split_type': 'equal',
            'category': 'food' if i % 2 == 0 else 'travel',
        }))
        exp_times.append(time.perf_counter() - t1)
        if i % 20 == 0 or i == args.expenses:
            print(f'  expenses {i}/{args.expenses}…')
    print(
        f'Create {args.expenses} expenses: {_ms(time.perf_counter() - t_exp)} ms '
        f'(avg {_ms(statistics.mean(exp_times))} / p95 {_ms(statistics.quantiles(exp_times, n=20)[18])})'
    )

    def timed_get(label: str, path: str) -> dict:
        times = []
        last = {}
        for _ in range(3):
            t1 = time.perf_counter()
            last = _ok(s.get(f'{base}{path}'))
            times.append(time.perf_counter() - t1)
        print(
            f'{label}: avg {_ms(statistics.mean(times))} ms '
            f'(min {_ms(min(times))} / max {_ms(max(times))})'
        )
        return last

    print()
    print('--- Read path (3 samples each) ---')
    members = timed_get('GET members', f'/groups/{group_id}/members')
    expenses = timed_get('GET expenses?per_page=100', f'/groups/{group_id}/expenses?page=1&per_page=100')
    balances = timed_get('GET balances', f'/groups/{group_id}/balances')
    timed_get('GET settlements-plan', f'/groups/{group_id}/balances/settlements-plan')
    group_detail = timed_get('GET group', f'/groups/{group_id}')

    member_n = len(members) if isinstance(members, list) else len(members.get('members', []))
    exp_list = expenses.get('expenses', expenses if isinstance(expenses, list) else [])
    exp_n = len(exp_list)
    bal_list = balances.get('balances', balances if isinstance(balances, list) else [])
    bal_n = len(bal_list) if isinstance(bal_list, list) else 0

    print()
    print('--- Verification ---')
    print(f'Members reported: {member_n} (target {args.members})')
    print(f'Expenses returned: {exp_n} (target {args.expenses})')
    print(f'Balances rows: {bal_n}')
    print(f'Group state: {group_detail.get("group_state")} / expense_count={group_detail.get("expense_count")}')
    print(f'Group id (for app inspection): {group_id}')
    print(f'Login: {email} / {password}')

    ok = member_n >= args.members and exp_n >= args.expenses
    if not ok:
        print('RESULT: FAIL (counts below target)')
        return 2
    print('RESULT: OK')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f'FAILED: {e}', file=sys.stderr)
        raise SystemExit(1)
