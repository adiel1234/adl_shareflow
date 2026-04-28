#!/usr/bin/env python3
"""
reset_db_data.py — מחיקת כל הנתונים מה-DB תוך שמירת הסכמה והמיגרציות.

הרצה:
    cd backend
    source venv/bin/activate   # (locally)
    python scripts/reset_db_data.py
"""

import sys
import os

# Allow running from backend root
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app, db

TABLES_TO_TRUNCATE = [
    # Child tables first (foreign key order)
    'scheduled_reminders',
    'period_debts',
    'period_reports',
    'settlements',
    'receipts',
    'expense_participants',
    'expenses',
    'group_payments',
    'group_members',
    'groups',
    'notifications',
    'reminder_settings',
    'fcm_tokens',
    'refresh_tokens',
    'user_identities',
    'deferred_links',
    'exchange_rates',
    'subscriptions',
    'users',
    # Keep: plans, feature_flags (config data, not user data)
]

def reset():
    app = create_app()
    with app.app_context():
        print("⚠️  מוחק את כל הנתונים מה-DB...")
        print(f"   טבלאות: {', '.join(TABLES_TO_TRUNCATE)}\n")

        confirm = input("האם אתה בטוח? הקלד YES להמשך: ").strip()
        if confirm != 'YES':
            print("בוטל.")
            return

        with db.engine.connect() as conn:
            # Use CASCADE to handle any remaining FK constraints automatically
            tables_sql = ', '.join(TABLES_TO_TRUNCATE)
            conn.execute(db.text(f'TRUNCATE TABLE {tables_sql} RESTART IDENTITY CASCADE'))
            conn.commit()

        print("\n✅ הנתונים נמחקו בהצלחה!")
        print("   הטבלאות plans ו-feature_flags לא נמחקו (הגדרות מערכת).")
        print("\n   המערכת מוכנה לבדיקות מלאות 🚀")

if __name__ == '__main__':
    reset()
