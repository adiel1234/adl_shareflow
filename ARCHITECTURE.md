# ADL ShareFlow — ארכיטקטורה ומבנה מערכת

> מסמך זה מתעד את מבנה המערכת, שירותים חיצוניים, תהליכי פריסה ואחזקה.
> עודכן לאחרונה: 27 אפריל 2026 (גרסה 1.0.1+2)

---

## תרשים מערכת

```
┌─────────────────────────────────────────────────────────┐
│                    משתמשי הקצה                          │
│         iPhone              Android                      │
└────────┬────────────────────────┬───────────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────────────────────────────────────────────┐
│              Flutter App (ADL ShareFlow)                 │
│  • iOS — TestFlight / App Store                          │
│  • Android — APK ישיר / Google Play                     │
│  • שפות: עברית + אנגלית (l10n)                          │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTPS REST API
                       ▼
┌─────────────────────────────────────────────────────────┐
│           Backend (Python / Flask)                       │
│  מיקום: שרת ענן (Render / Railway / ngrok לפיתוח)       │
│  פורט: 5050                                              │
│  URL ייצור: https://[hosting-url]/api                    │
└──┬──────────────┬──────────────┬────────────────────────┘
   │              │              │
   ▼              ▼              ▼
┌──────┐    ┌──────────┐   ┌──────────────┐
│ DB   │    │ Firebase │   │ שירותים      │
│ PG   │    │ FCM Push │   │ חיצוניים     │
│      │    │          │   │ • Google OCR │
│      │    │          │   │ • ExchangeRate│
│      │    │          │   │ • Resend Mail│
└──────┘    └──────────┘   └──────────────┘
```

---

## רכיבי המערכת

### 1. Flutter App (Mobile)

**מיקום קוד:** `/mobile/lib/`

| תיקייה | תוכן |
|--------|------|
| `core/config/` | הגדרות סביבה (dev/staging/prod) + כתובת API |
| `core/network/` | ApiClient (Dio) — כל קריאות ה-HTTP |
| `features/auth/` | התחברות, הרשמה, Google Sign-In, Apple Sign-In |
| `features/groups/` | קבוצות — יצירה, הזמנה, QR, ניהול |
| `features/expenses/` | הוצאות — הוספה, עריכה, OCR |
| `features/balances/` | יתרות, סיכום אירוע, התחשבנות |
| `features/notifications/` | התראות in-app |
| `features/profile/` | פרופיל, הגדרות, תזכורות, פרטי תשלום |
| `features/ocr/` | סריקת קבלות |
| `l10n/` | עברית (`app_he.arb`) + אנגלית (`app_en.arb`) — 396 מפתחות |
| `services/fcm_service.dart` | ניהול Push Notifications — אתחול, רישום token, ניווט מהתראה |
| `services/share_service.dart` | שיתוף קישורים / WhatsApp |
| `providers/` | Riverpod state management |
| `theme/` | צבעים, טיפוגרפיה, עיצוב |

**סביבות:**

| סביבה | כתובת Backend | מתי משתמשים |
|--------|--------------|-------------|
| `dev` | `localhost:5050` | פיתוח מקומי |
| `staging` | ngrok URL | בדיקות על מכשיר אמיתי |
| `prod` | URL שרת הענן | גרסת ייצור (TestFlight / APK) |

**שינוי סביבה:** קובץ `/mobile/lib/core/config/app_config.dart`

---

### 2. Backend (Python / Flask)

**מיקום קוד:** `/backend/app/`

| מודול | תיאור | Endpoints עיקריים |
|-------|--------|-------------------|
| `auth/` | JWT + Google + Apple | POST /auth/login, /register, /google, /apple |
| `users/` | פרופיל משתמש | GET/PUT /users/me |
| `groups/` | קבוצות + מונטיזציה | CRUD /groups, /activate, /extend, /renew, /upgrade-tier |
| `expenses/` | הוצאות | CRUD /expenses |
| `balances/` | מנוע חישוב יתרות | GET /groups/{id}/balances |
| `settlements/` | הסדרי חובות | POST /settlements |
| `notifications/` | התראות + FCM | GET /notifications, POST /fcm-token |
| `ocr/` | סריקת קבלות | POST /ocr/scan |
| `currency/` | שערי חליפין | GET /currency/rates |
| `dashboard/` | ADL Admin API | GET /dashboard/stats, /monetization |
| `download/` | דפי הורדה + join | GET /download, /join/<code>, /api/deferred-link |
| `scheduler.py` | משימות אוטומטיות | תזכורות שעתיות + בדיקת פקיעה יומית |

**קובץ הגדרות:** `/backend/.env` (לא ב-git)

**כתובת ייצור:** `https://adlshareflow-production.up.railway.app` — **פעיל** ✅

---

### 3. בסיס נתונים (PostgreSQL)

**מודלים עיקריים** (`/backend/app/models.py`):

| טבלה | תוכן |
|------|------|
| `users` | משתמשים, פרופיל, פרטי תשלום |
| `groups` | קבוצות + מצב lifecycle + תמחור |
| `group_members` | חברות בקבוצות + תפקידים |
| `expenses` | הוצאות + פיצולים |
| `expense_participants` | חלוקת הוצאה לכל משתתף |
| `settlements` | הסדרי חובות |
| `notifications` | התראות in-app |
| `fcm_tokens` | tokens לפוש נוטיפיקיישן |
| `group_payments` | תשלומי הפעלה/שדרוג/הארכה |
| `feature_flags` | הגדרות מערכת (PAYMENTS_ENABLED וכו') |
| `reminder_settings` | הגדרות תזכורות אוטומטיות |

---

### 4. שירותים חיצוניים

| שירות | מה הוא עושה | חשוב לדעת |
|-------|------------|-----------|
| **Firebase** | Push Notifications (FCM) | Backend: `firebase-credentials.json`; Android: `google-services.json` + plugin; iOS: `GoogleService-Info.plist` |
| **Firebase Auth** | Google Sign-In | Bundle: `com.adl.shareflow` |
| **Google Vision** | OCR — סריקת קבלות | 1,000 סריקות/חודש חינם |
| **ExchangeRate-API** | שערי מטבע בזמן אמת | חינמי |
| **Resend** | שליחת מיילי הזמנה | `RESEND_API_KEY` בסביבת הייצור |
| **Apple APNs** | Push Notifications ל-iOS | Key ID: `4BT7S9CS4V`, Team: `9QP3FZTL8C` |

---

### 5. ADL Dashboard Integration

**מיקום:** `/adl_platform_module/` + `/backend/app/dashboard/routes.py`

ה-Dashboard של ADL מתממשק לשרת דרך:
- **כתובת:** `GET /dashboard/stats` / `/dashboard/monetization` / `/dashboard/revenue`
- **אבטחה:** Header `X-ADL-Admin-Key` (מוגדר ב-`.env` → `ADL_ADMIN_KEY`)
- **נתונים:** משתמשים, קבוצות, הכנסות, OCR stats, Feature Flags

---

## מודל תמחור (Monetization)

### קבוצת אירוע (חד-פעמי)

| משתתפים | מחיר | תוקף |
|----------|------|-------|
| עד 5 | 15 ₪ | 30 יום |
| עד 10 | 20 ₪ | 30 יום |
| עד 15 | 30 ₪ | 30 יום |
| עד 39 | 35 ₪ | 30 יום |
| 40+ | 45 ₪ | 30 יום |
| הארכה | 15 ₪ | +15 יום |

### קבוצה שוטפת (חוזרת)

| משתתפים | מחיר | תוקף |
|----------|------|-------|
| עד 5 | 49 ₪ | 30 יום |
| עד 8 | 69 ₪ | 30 יום |
| עד 11 | 79 ₪ | 30 יום |
| 12+ | 89 ₪ | 30 יום |

### מצבי קבוצה (Lifecycle)

```
free (5 ימים) → limited → [תשלום] → active → expired / read_only
                                               ↑
                              [הארכה/חידוש/שדרוג tier]
```

---

## תהליך עדכון גרסה

### Backend
```bash
git push origin main
# → Render/Railway מתעדכן אוטומטית (auto-deploy)
```

### Android APK
```bash
# 1. עדכן גרסה ב-pubspec.yaml:
#    version: X.Y.Z+N  (הגדל N בכל build)

# 2. בנה APK:
cd mobile
flutter build apk --release

# 3. קובץ מוכן ב:
#    build/app/outputs/flutter-apk/app-release.apk

# 4. העלה ל-Google Drive (שתף → "כל מי שיש לו קישור")
# 5. עדכן APK_DOWNLOAD_URL ב-Railway:
#    https://drive.google.com/uc?export=download&id=<FILE_ID>

# להתקנה מהירה על מכשיר מחובר USB (לפיתוח):
flutter install --release
```

**APK נוכחי (גרסה 1.0.1+2):**
- קישור Google Drive: `https://drive.google.com/uc?export=download&id=1gCIuCZOErAJnkbqCpPbpsO_OJk4y89dt`
- זמין להורדה דרך: `https://adlshareflow-production.up.railway.app/download`

### iOS (TestFlight)
```
1. עדכן version ב-pubspec.yaml
2. Xcode → Product → Archive (~3 דקות)
3. Organizer → Distribute App → Upload (~5 דקות)
4. App Store Connect → TestFlight → Build חדש מופיע אוטומטית
```

---

## משתני סביבה קריטיים (Backend)

| משתנה | תיאור | חובה |
|-------|--------|-------|
| `DATABASE_URL` | PostgreSQL connection string | ✅ |
| `JWT_SECRET_KEY` | סוד לחתימת tokens | ✅ |
| `FIREBASE_CREDENTIALS_PATH` | נתיב לקובץ Firebase Admin JSON | ✅ Push |
| `GOOGLE_APPLICATION_CREDENTIALS` | נתיב לקובץ Google Vision JSON | ✅ OCR |
| `ADL_ADMIN_KEY` | מפתח גישה ל-Dashboard | ✅ Dashboard |
| `RESEND_API_KEY` | מפתח שליחת מיילים | 🟡 אופציונלי |
| `PAYMENTS_ENABLED` | האם לגבות תשלום אמיתי | 🔴 כבוי בפיילוט |
| `TESTFLIGHT_URL` | קישור TestFlight חיצוני ל-iOS | 🟡 להגדיר לפני פיילוט |
| `APK_DOWNLOAD_URL` | קישור הורדת APK ל-Android | 🟡 להגדיר לפני פיילוט |

---

## פרטי Apple Developer

| פרמטר | ערך |
|-------|-----|
| Apple ID | adiely03@gmail.com |
| Team ID | `9QP3FZTL8C` |
| Bundle ID | `com.adl.shareflow` |
| APNs Key ID | `4BT7S9CS4V` |
| App Store Connect | ShareFlow (שם) |
| TestFlight | Internal Group פעיל |

---

## תהליכים אוטומטיים (Scheduler)

| משימה | תדירות | תיאור |
|-------|--------|--------|
| `send_auto_reminders` | כל שעה | תזכורות תשלום לחייבים |
| `check_group_expirations` | כל 24 שעות | מעבר קבוצות ל-expired + התראה 3 ימים מראש |

---

## נקודות כשל ידועות ופתרונות

| בעיה | סיבה | פתרון |
|------|------|--------|
| אפליקציה לא מתחברת לשרת | URL הייצור לא מוגדר | עדכן `app_config.dart` → בנה מחדש |
| Push לא מגיע ל-iOS | APNs לא מוגדר | הוגדר ב-Firebase (Key: `4BT7S9CS4V`) |
| אפליקציה Android תקועה ב-splash | `google-services.json` חסר | הורד מ-Firebase Console → שמור ב-`android/app/` |
| OCR לא עובד | Google Vision credentials חסר | הגדר `GOOGLE_APPLICATION_CREDENTIALS` בשרת |
| תשלומים לא נגבים | `PAYMENTS_ENABLED=false` | שנה ל-`true` ב-DB כשמוכן |
| קבוצה לא עוברת ל-limited | Scheduler לא פועל | וודא ש-APScheduler פעיל בשרת |
| לחיצה על התראה לא מנווטת | route `/group-detail` חסר | תוקן ב-router.dart — נדרש build חדש |

---

## מצב פיילוט (אפריל 2026)

| נושא | מצב |
|------|-----|
| Backend (Railway) | ✅ פעיל |
| iOS (TestFlight) | ✅ Internal — גרסה 1.0.0 (נדרש עדכון ל-1.0.1+2) |
| Android (APK) | ✅ גרסה 1.0.1+2 — זמין ב-/download |
| QR + הזמנות | ✅ עובד בשני הכיוונים |
| Push Notifications | ✅ מגיעות — ניווט בבדיקה |
| PAYMENTS_ENABLED | 🔴 כבוי (פיילוט חינמי) |
| Firebase App Distribution | 🟡 מתוכנן — טרם הוגדר |
