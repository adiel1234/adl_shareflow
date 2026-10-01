# תיקונים ממתינים להפצה

**עודכן:** 1 באוקטובר 2026  
**HEAD מרוחק:** `d2fa943` ב־`origin/main`  
**חבילת ביקורת אפל:** iOS `1.0.9+83`  
**מתג גלובלי:** `PAYMENTS_ENABLED=false` — לא שונה

## שכבה A — כבר ב־`origin/main` / בילד 83

- קומיט `d2fa943` — הכנת הפצה 1.0.9 בילד 83
- `PAYMENTS_ENABLED` כבוי לכל המשתמשים
- אין חריגת IAP לפי משתמש בשרת החי

## שכבה B — committed מקומית, לא push, לא בשרת החי

חריגת IAP לחשבון ביקורת בלבד, לפי JWT מאומת ו־`IAP_REVIEW_USER_IDS`.

קבצים:

- `backend/app/iap/policy.py` (חדש)
- `backend/app/__init__.py`
- `backend/app/iap/routes.py`
- `backend/app/groups/routes.py`
- `backend/app/groups/monetization_service.py`
- `backend/tests/unit/test_iap_review_override.py` (חדש)
- `backend/.env.example`
- `ARCHITECTURE.md`

מה **לא** נכלל ולא הוגדר:

- משתנה Railway `IAP_REVIEW_USER_IDS` — לא הוגדר
- בילד לקוח חדש — לא נדרש ולא נבנה
- הדלקת `PAYMENTS_ENABLED`

שאריות מקומיות שאינן חלק מהשינוי: קבצי APK 72–74, צילומי ipad13, QR ביקורת, מחיקות חנות אנדרואיד / קובץ הפעלה.

## חבילות

| פלטפורמה | קובץ | סטטוס |
|----------|------|--------|
| iOS חנות | בילד 83 בביקורת אפל | קפוא · בלי בילד חדש |
| שרת חי | `d2fa943` | בלי חריגת הביקורת |

## פתוחים

| נושא | סטטוס |
|------|--------|
| אפל לא מוצאת IAP | ממתין לאישור: commit + push + `IAP_REVIEW_USER_IDS` |
| `PAYMENTS_ENABLED` | כבוי · לא להדליק לכולם |
| `IAP_REVIEW_USER_IDS` | לא הוגדר בייצור |
| Commit / push של החריגה | ממתין לאישור מפורש |
