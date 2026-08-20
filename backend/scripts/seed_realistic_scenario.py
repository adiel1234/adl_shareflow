#!/usr/bin/env python3
"""
Realistic ShareFlow demo seed — summer party with many expenses (past the old 30-page bug).

Default: production API, 12 members (1 admin + 11 guests), 45 expenses.
Use --heavy for 50 members × 100 expenses.

  python scripts/seed_realistic_scenario.py
  python scripts/seed_realistic_scenario.py --heavy
  python scripts/seed_realistic_scenario.py --base-url http://127.0.0.1:5050/api
"""
from __future__ import annotations

import argparse
import os
import random
import sys
import time
import uuid
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / '.env')
    load_dotenv(ROOT.parent / 'adl_platform_module' / '.env')
except Exception:
    pass

GUESTS = [
    'רעות חדידה', 'נועם לוי', 'דניאל כהן', 'מיכל אברהם', 'איתי מזרחי',
    'שירה בן-דוד', 'עומר פרץ', 'תמר גולן', 'יונתן שמש', 'לין אדרי',
    'אורי נחמני', 'מאיה רוזן', 'עידו ברק', 'נויה שטיין', 'רועי אלון',
    'הילה דהן', 'אדם ביטון', 'יובל סגל', 'נועה חיים', 'תום אזולאי',
    'שקד מלכה', 'ליאור חדד', 'יעל קלנר', 'אריאל סופר', 'דנה וייס',
    'גיל אוחנה', 'סתיו ממן', 'עומרי לוין', 'הדר פרידמן', 'אביב שפירא',
    'ניב קרן', 'מאי אשכנזי', 'עינת בר', 'שי קציר', 'רז נחום',
    'טליה מור', 'יואב רגב', 'ענבר סלע', 'פז אורן', 'כרמל דביר',
    'אלון גפן', 'ספיר לוי', 'עמית חן', 'נועם ברגר', 'ליהי צור',
    'דור פלד', 'שני אביטל', 'איילת רון', 'בן צורי',
]

EXPENSES = [
    ('סופר בשופרסל לפני המסיבה', 420, 'ILS', 'shopping'),
    ('שתייה קלה ובירה', 310, 'ILS', 'food'),
    ('גחלים ובשר למנגל', 580, 'ILS', 'food'),
    ('עוגת יום הולדת', 220, 'ILS', 'food'),
    ('בלונים וקישוטים', 95, 'ILS', 'entertainment'),
    ('אובר מהתחנה לדירה', 68, 'ILS', 'transport'),
    ('אובר חזרה בלילה', 85, 'ILS', 'transport'),
    ('Airbnb מקדמה', 180, 'USD', 'housing'),
    ('Airbnb יתרה', 240, 'USD', 'housing'),
    ('נייר טואלט וניקיון', 74, 'ILS', 'utilities'),
    ('מוזיקה / רמקול להשכרה', 150, 'ILS', 'entertainment'),
    ('פיצה ב-02:00', 189, 'ILS', 'food'),
    ('קפה ומאפים בבוקר', 126, 'ILS', 'food'),
    ('חניה בתל אביב', 48, 'ILS', 'transport'),
    ('דלק לנסיעה צפונה', 210, 'ILS', 'transport'),
    ('קרטיבים וגלידה', 92, 'ILS', 'food'),
    ('בקבוקי יין', 260, 'ILS', 'food'),
    ('ערכת עזרה ראשונה', 55, 'ILS', 'health'),
    ('כניסה לפארק מים', 360, 'ILS', 'entertainment'),
    ('טיפים למלצרים', 80, 'ILS', 'food'),
    ('סנדוויצ׳ים לדרך', 145, 'ILS', 'food'),
    ('צידנית חדשה', 119, 'ILS', 'shopping'),
    ('קרח מהתחנה', 40, 'ILS', 'food'),
    ('נטפליקס / שיתוף חשבון', 12, 'USD', 'entertainment'),
    ('Uber Eats ארוחת צהריים', 34, 'USD', 'food'),
    ('כרטיסי מוזיאון', 95, 'EUR', 'entertainment'),
    ('ארוחת ערב במסעדה', 420, 'ILS', 'food'),
    ('בקבוק שמפניה', 175, 'ILS', 'food'),
    ('מתנה משותפת למארחת', 300, 'ILS', 'shopping'),
    ('צילום פולארויד + פילם', 210, 'ILS', 'entertainment'),
    ('משחקי קופסה', 160, 'ILS', 'entertainment'),
    ('כביסה אחרי האירוע', 45, 'ILS', 'utilities'),
    ('תחליף נורה / נרות', 38, 'ILS', 'utilities'),
    ('פירות וירקות בשוק', 132, 'ILS', 'food'),
    ('לחמים וחומוס', 88, 'ILS', 'food'),
    ('מיץ טבעי', 64, 'ILS', 'food'),
    ('מפיות וכלים חד פעמיים', 79, 'ILS', 'shopping'),
    ('שקיות זבל', 22, 'ILS', 'shopping'),
    ('טעינת רב-קו לקבוצה', 150, 'ILS', 'transport'),
    ('כניסה לחניון קניון', 36, 'ILS', 'transport'),
    ('סופגניות / קינוחים', 110, 'ILS', 'food'),
    ('ערכת בר', 245, 'ILS', 'food'),
    ('הזמנת דיג׳יי חובב', 400, 'ILS', 'entertainment'),
    ('תוספת Airbnb ניקיון', 45, 'USD', 'housing'),
    ('מים מינרליים ארגז', 70, 'ILS', 'food'),
    ('סלטים מוכנים', 156, 'ILS', 'food'),
    ('גבינות ומעדנייה', 198, 'ILS', 'food'),
    ('חטיפים למנגל', 84, 'ILS', 'food'),
    ('כבל טעינה חירום', 49, 'ILS', 'shopping'),
    ('ביטוח ביטול דירה', 18, 'EUR', 'housing'),
    ('כרטיסי רכבת לחיפה', 268, 'ILS', 'travel'),
    ('ארוחת בוקר משותפת', 240, 'ILS', 'food'),
    ('טיול ג׳יפים מקדמה', 90, 'USD', 'travel'),
    ('כובעים מהשוק', 120, 'ILS', 'shopping'),
    ('קרם הגנה לכל החבורה', 96, 'ILS', 'health'),
    ('תרופות / משככי כאבים', 42, 'ILS', 'health'),
    ('שטיפת רכב אחרי', 60, 'ILS', 'transport'),
    ('החזר דמי פיקדון חלקי', 50, 'USD', 'housing'),
    ('תוספת שתייה בסופר', 135, 'ILS', 'food'),
    ('עוגת גבינה שנייה', 180, 'ILS', 'food'),
]


def _ok(resp: requests.Response):
    try:
        body = resp.json()
    except Exception:
        body = {'raw': resp.text[:400]}
    if resp.status_code >= 400:
        raise RuntimeError(f'{resp.request.method} {resp.url} → {resp.status_code}: {body}')
    return body.get('data', body)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument('--base-url', default='https://adlshareflow-production.up.railway.app/api')
    p.add_argument('--admin-key', default=os.getenv('SHAREFLOW_ADMIN_KEY') or os.getenv('ADL_ADMIN_KEY', ''))
    p.add_argument('--heavy', action='store_true', help='50 members + 100 expenses')
    p.add_argument('--members', type=int, default=0)
    p.add_argument('--expenses', type=int, default=0)
    args = p.parse_args()

    members = args.members or (50 if args.heavy else 12)
    expense_n = args.expenses or (100 if args.heavy else 45)
    guest_n = members - 1

    if not args.admin_key:
        print('ERROR: set SHAREFLOW_ADMIN_KEY or ADL_ADMIN_KEY', file=sys.stderr)
        return 1

    base = args.base_url.rstrip('/')
    adl = f'{base}/adl'
    stamp = uuid.uuid4().hex[:6]
    email = f'demo.summer.{stamp}@shareflow-demo.local'
    password = 'DemoSummer2026!'

    s = requests.Session()
    s.headers['Content-Type'] = 'application/json'

    print(f'Target: {base}')
    print(f'Scenario: {members} members, {expense_n} expenses')

    auth = _ok(s.post(f'{base}/auth/register', json={
        'email': email,
        'password': password,
        'display_name': 'יערה שעתל',
    }))
    token = auth['access_token']
    admin_id = auth['user']['id']
    s.headers['Authorization'] = f'Bearer {token}'

    group = _ok(s.post(f'{base}/groups', json={
        'name': f'מסיבת סוף הקיץ — הדמייה {stamp}',
        'base_currency': 'ILS',
        'category': 'party',
        'group_type': 'event',
        'description': 'הדמיית עומס מציאותית לבדיקת רשימת הוצאות מעל 30',
    }))
    gid = group['id']
    print(f'Group: {gid}')

    _ok(s.post(
        f'{adl}/groups/{gid}/activate',
        headers={'X-ADL-Admin-Key': args.admin_key},
        json={'split_among_group': False},
    ))
    print('Activated')

    guest_ids = []
    for i, name in enumerate(GUESTS[:guest_n], 1):
        g = _ok(s.post(f'{base}/groups/{gid}/guests', json={
            'name': name,
            'split_mode': 'forward',
        }))
        guest_ids.append(g['user_id'])
        if i % 10 == 0 or i == guest_n:
            print(f'  guests {i}/{guest_n}')

    payers = [admin_id] + guest_ids
    all_member_ids = payers[:]
    rates = {'ILS': 1.0, 'USD': 3.7, 'EUR': 4.0}
    random.seed(42)
    catalog = list(EXPENSES)
    while len(catalog) < expense_n:
        catalog.extend(EXPENSES)
    catalog = catalog[:expense_n]

    def equal_shares(amount: float, n: int) -> list[str]:
        from decimal import Decimal, ROUND_HALF_UP
        total = Decimal(str(amount)).quantize(Decimal('0.01'))
        base = (total / n).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        mid = base * (n - 1)
        last = (total - mid).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        return [str(base)] * (n - 1) + [str(last)]

    t0 = time.perf_counter()
    for i, (title, amount, cur, cat) in enumerate(catalog, 1):
        rate = rates.get(cur, 1.0)
        converted = round(amount * rate, 2)
        shares = equal_shares(converted, len(all_member_ids))
        participants = [
            {'user_id': uid, 'share_amount': sh}
            for uid, sh in zip(all_member_ids, shares)
        ]
        _ok(s.post(f'{base}/groups/{gid}/expenses', json={
            'title': title if i <= len(EXPENSES) else f'{title} ({i})',
            'original_amount': str(amount),
            'original_currency': cur,
            'exchange_rate': rate,
            'paid_by': payers[i % len(payers)],
            'split_type': 'equal',
            'category': cat,
            'participants': participants,
        }))
        if i % 15 == 0 or i == expense_n:
            print(f'  expenses {i}/{expense_n}')
    print(f'Create expenses: {(time.perf_counter() - t0):.1f}s')

    # Verify pagination like the fixed client
    all_exp = []
    page = 1
    while True:
        data = _ok(s.get(f'{base}/groups/{gid}/expenses', params={'page': page, 'per_page': 100}))
        batch = data.get('expenses', [])
        all_exp.extend(batch)
        total = data.get('pagination', {}).get('total', len(all_exp))
        if len(all_exp) >= total or len(batch) < 100:
            break
        page += 1

    old_bug = _ok(s.get(f'{base}/groups/{gid}/expenses', params={'page': 1, 'per_page': 30}))
    old_n = len(old_bug.get('expenses', []))

    member_rows = _ok(s.get(f'{base}/groups/{gid}/members'))
    member_n = len(member_rows) if isinstance(member_rows, list) else len(member_rows.get('members', []))
    bal = _ok(s.get(f'{base}/groups/{gid}/balances'))
    bal_n = len(bal.get('balances', bal if isinstance(bal, list) else []))

    invite = _ok(s.get(f'{base}/groups/{gid}/invite-link'))
    code = invite.get('invite_code') or invite.get('code') or group.get('invite_code')

    print()
    print('=== DEMO READY ===')
    print(f'Group name: מסיבת סוף הקיץ — הדמייה {stamp}')
    print(f'Group id:   {gid}')
    print(f'Invite:     {code}')
    print(f'Login:      {email}')
    print(f'Password:   {password}')
    print(f'Members:    {member_n}')
    print(f'Expenses (full client load): {len(all_exp)} / total={total}')
    print(f'Old bug (per_page=30 only):  {old_n}  ← would hide the rest')
    print(f'Balances:   {bal_n}')
    ok = len(all_exp) >= expense_n and member_n >= members
    print('RESULT:', 'OK' if ok else 'FAIL')
    return 0 if ok else 2


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f'FAILED: {e}', file=sys.stderr)
        raise SystemExit(1)
