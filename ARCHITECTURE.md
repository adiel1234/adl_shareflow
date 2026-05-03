# ADL ShareFlow — ארכיטקטורה ומבנה מערכת

> מסמך זה מתעד את מבנה המערכת, שירותים חיצוניים, תהליכי פריסה ואחזקה.
> עודכן לאחרונה: 3 מאי 2026 (גרסה 1.0.3+6)

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
| `users` | משתמשים, פרופיל, פרטי תשלום, `is_guest` (boolean) |
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

**שינוי סכמה אחרון (migration `480ff4d3679c`):**
- נוסף עמודה `is_guest BOOLEAN NOT NULL DEFAULT false` לטבלת `users`

---

### 4. שירותים חיצוניים

| שירות | מה הוא עושה | חשוב לדעת |
|-------|------------|-----------|
| **Firebase** | Push Notifications (FCM) | Backend: `firebase-credentials.json`; Android: `google-services.json` + plugin; iOS: `GoogleService-Info.plist` |
| **Firebase Auth** | Google Sign-In | Bundle: `com.adl.shareflow` |
| **Google Vision** | OCR — סריקת קבלות | 1,000 סריקות/חודש חינם |
| **ExchangeRate-API** | שערי מטבע בזמן אמת | חינמי |
| **Resend** | שליחת מיילי הזמנה + דוחות תקופה | `RESEND_API_KEY` + `RESEND_FROM_EMAIL=noreply@adl-studio.com`; דומיין מאומת ב-eu-west-1 (Ireland) |
| **Namecheap** | רישום דומיין `adl-studio.com` | DNS מנוהל ב-Advanced DNS; רשומות DKIM + SPF + DMARC + MX הוגדרו |
| **Apple APNs** | Push Notifications ל-iOS | Key ID: `4BT7S9CS4V`, Team: `9QP3FZTL8C` |
| **Google Postmaster Tools** | ניטור מוניטין דואר יוצא | דומיין `adl-studio.com` מאומת; לצפייה בדוחות spam rate ו-authentication |

#### הגדרות DNS — `adl-studio.com` (Namecheap → Advanced DNS)

| סוג רשומה | Host | ערך / תוכן | מטרה |
|-----------|------|-----------|------|
| TXT | `resend._domainkey` | `v=DKIM1; p=...` (ערך מ-Resend) | DKIM — חתימה דיגיטלית |
| TXT | `@` | `v=spf1 include:amazonses.com ~all` | SPF — אישור שרתי שליחה |
| TXT | `_dmarc` | `v=DMARC1; p=quarantine; pct=100; rua=mailto:noreply@adl-studio.com` | DMARC — מדיניות טיפול במיילים לא מאומתים |
| MX | `@` | `feedback-smtp.eu-west-1.amazonses.com` (Priority 10) | MX — קבלת bounce reports |

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

**APK נוכחי (גרסה 1.0.3+6):**
- קישור: מוגדר ב-`APK_DOWNLOAD_URL` ב-Railway
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

| משתנה | תיאור | חובה | ערך נוכחי |
|-------|--------|-------|-----------|
| `DATABASE_URL` | PostgreSQL connection string | ✅ | Railway PostgreSQL |
| `JWT_SECRET_KEY` | סוד לחתימת tokens | ✅ | — |
| `FIREBASE_CREDENTIALS_PATH` | נתיב לקובץ Firebase Admin JSON | ✅ Push | — |
| `GOOGLE_APPLICATION_CREDENTIALS` | נתיב לקובץ Google Vision JSON | ✅ OCR | — |
| `ADL_ADMIN_KEY` | מפתח גישה ל-Dashboard | ✅ Dashboard | — |
| `RESEND_API_KEY` | מפתח Resend לשליחת מיילים | ✅ | מוגדר ב-Railway |
| `RESEND_FROM_EMAIL` | כתובת שולח המיילים | ✅ | `noreply@adl-studio.com` |
| `SMTP_SENDER_NAME` | שם השולח בכותרת המייל | 🟡 | `ADL ShareFlow` (ברירת מחדל) |
| `PAYMENTS_ENABLED` | האם לגבות תשלום אמיתי | 🔴 כבוי בפיילוט | `false` |
| `TESTFLIGHT_URL` | קישור TestFlight חיצוני ל-iOS | ✅ | מוגדר ב-Railway |
| `APK_DOWNLOAD_URL` | קישור הורדת APK ל-Android | ✅ | Google Drive (גרסה נוכחית) |

---

## פרטי שירותים ודומיין

### Resend (Email)
| פרמטר | ערך |
|-------|-----|
| דומיין שליחה | `adl-studio.com` |
| כתובת שולח | `noreply@adl-studio.com` |
| שם שולח | `ADL ShareFlow` |
| אזור Resend | `eu-west-1` (Ireland) |
| סטטוס דומיין | ✅ Verified |
| Dashboard | [resend.com/domains](https://resend.com/domains) |

### Namecheap (Domain Registrar)
| פרמטר | ערך |
|-------|-----|
| דומיין | `adl-studio.com` |
| תאריך רכישה | 2 מאי 2026 |
| תוקף | 2027 (חידוש אוטומטי מומלץ) |
| DNS ניהול | Advanced DNS בלוח הבקרה של Namecheap |

### Google Postmaster Tools
| פרמטר | ערך |
|-------|-----|
| דומיין מנוטר | `adl-studio.com` |
| מטרה | מעקב אחר spam rate, authentication, delivery errors |
| כניסה | [postmaster.google.com](https://postmaster.google.com) עם Google Account |

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

## מצב פיילוט (מאי 2026)

| נושא | מצב |
|------|-----|
| Backend (Railway) | ✅ פעיל |
| iOS (TestFlight) | ✅ גרסה 1.0.3+6 — Internal |
| Android (APK) | ✅ גרסה 1.0.3+6 — זמין ב-/download |
| QR + הזמנות | ✅ עובד בשני הכיוונים |
| Push Notifications | ✅ מגיעות + real-time refresh בפורגראונד |
| Email Invitations | ✅ `noreply@adl-studio.com` — נבדק, מגיע לתיבה הראשית |
| Domain `adl-studio.com` | ✅ מאומת ב-Resend; DKIM + SPF + DMARC + MX פעילים |
| Google Postmaster Tools | ✅ דומיין מאומת — ניטור מוניטין |
| DMARC Policy | ✅ `p=quarantine` — מוגן מזיוף |
| Guest Member Feature | ✅ הוספה / קישור / הסרה / חיוב / settlement |
| PAYMENTS_ENABLED | 🔴 כבוי (פיילוט חינמי) |
| Firebase App Distribution | 🟡 מתוכנן — טרם הוגדר |

---

## שינויים אחרונים — גל מאי 2026 (גרסה 1.0.3+6)

### Flutter (Mobile)
- **FCM Real-Time Refresh**: `FcmService.setDataChangeCallback` + `_invalidateForGroup` ב-`main.dart` — כשמגיעה התראה FCM ב-foreground, מתבצע `ref.invalidate` על `expensesProvider` / `balancesProvider` / `notificationsProvider` לפי סוג ההתראה.
- **Guest Member UI**: תג סגול "אורח" + avatar סגול + כפתורי 🔗 ו-🗑️ ברשימת חברים; Banner למנהל; Sheet "קשר אורח לחשבון"; "שולם" סגול ביתרות.
- **Close Buttons**: נוסף `IconButton(Icons.close)` ל-`_InviteSheet` ו-`_JoinGroupSheet` כדי לאפשר יציאה מפורשת מ-modal bottom sheets.
- **Group Detail Freshness**: `GroupCard.onTap` מנווט דרך `/group-detail` עם `groupId` בלבד — `_GroupDetailLoader` שולף נתוני קבוצה עדכניים מהשרת בכל ניווט.

### Backend
- **Guest Endpoints** (`groups/routes.py`):
  - `POST /groups/<id>/guests` — הוסף אורח לקבוצה
  - `PUT /groups/<id>/guests/<guest_id>/link` — קשר אורח לחשבון קיים
  - `DELETE /groups/<id>/guests/<guest_id>` — הסר אורח
- **Guest Settlement** (`settlements/routes.py`): endpoint חדש `POST /groups/<id>/settlements/mark-guest-paid` — מנהל מסמן חוב אורח כשולם ישירות (confirmed, ללא אישור).
- **Notification Routing** (`notifications/service.py`): התראות לאורחים מנותבות למנהל הקבוצה; האורח עצמו אינו מקבל push.
- **DB Migration** (`480ff4d3679c`): נוסף `is_guest BOOLEAN NOT NULL DEFAULT false` ל-`users`.
- **Download Page**: גרסה עודכנה ל-v1.0.2; `TESTFLIGHT_URL` + `APK_DOWNLOAD_URL` נקראים ממשתני סביבה.

---

## שינויים — גל אפריל 2026 (גרסה 1.0.1+3)

### Flutter (Mobile)
- **JWT Refresh + API Errors**: `ApiClient._AuthInterceptor` מנסה refresh אוטומטי. אם נכשל → ניווט ל-login + הודעה. שגיאות 5xx → Snackbar אדום.
- **Offline Banner**: `connectivity_plus` — בדיקת חיבור רציפה, באנר אפור בראש המסך.
- **Settlement Confirmation Flow**: חייב: "שלמתי" → creates pending settlement. נושה: "אשר קבלה" → confirms. Provider: `pendingSettlementsProvider`.
- **Haptic Feedback**: `HapticFeedback.mediumImpact()` ב-login, register, צור קבוצה, שמירת הוצאה, settlement.
- **"מי שילם הכי הרבה"**: `event_summary_screen.dart` — chip 🏆 עם שם ה-top payer.
- **חיפוש הוצאות**: `ExpensesListScreen` → `ConsumerStatefulWidget` עם שדה חיפוש real-time.

### Backend
- `settlements/routes.py`: endpoint חדש `GET /groups/<id>/settlements/pending`.
- `balances/routes.py`: שדה `top_payer` נוסף ל-event summary response.
