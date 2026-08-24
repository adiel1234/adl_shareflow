# ADL ShareFlow — ארכיטקטורה ומבנה מערכת

> מסמך זה מתעד את מבנה המערכת, שירותים חיצוניים, תהליכי פריסה ואחזקה.
> עודכן לאחרונה: 24 אוגוסט 2026 — מקור גרסה `PENDING_RELEASE.md`: **`1.0.9+70` נעולה** · דף `/account-deletion` ל־Google Play · OAuth Google/Apple במסך כניסה · הכנת חנות iOS ב־`STORE_PREP_IOS.md`

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

## תשתית Railway (יעד)

**מפת מוצרים, env, ניקוי Railway ותוכנית פירוד:** [`docs/ADL_PRODUCTS.md`](docs/ADL_PRODUCTS.md)  
**יום 2 — בדיקות פיילוט ו-15–20 משתתפים:** [`docs/PILOT_DAY2.md`](docs/PILOT_DAY2.md)  
**הזמנת פיילוט (שכנוע):** https://adlshareflow-production.up.railway.app/pilot/join  
**התקנה / התחלה:** https://adlshareflow-production.up.railway.app/getting-started · [`docs/PILOT_ONBOARDING_GUIDE.md`](docs/PILOT_ONBOARDING_GUIDE.md)  
**מדריך iOS (legacy):** [`docs/TESTFLIGHT_IOS_GUIDE.html`](docs/TESTFLIGHT_IOS_GUIDE.html)

שלושה פרויקטים נפרדים ב-Railway:

| פרויקט Railway | שם קנוני | תפקיד | URL ייצור | Repo |
|----------------|-----------|--------|-----------|------|
| **ADL Control** | ADL Control | דשבורד ניהול + Blueprint (`/dashboard`, `/shareflow`, `/blueprint`) | `https://web-production-cddac.up.railway.app` (עד מעבר דומיין) | `adl_control` |
| **ADL ShareFlow** | ADL ShareFlow | Backend API + PostgreSQL ShareFlow | `https://adlshareflow-production.up.railway.app` | repo זה → `backend/` |
| **ADL Blueprint** | ADL Blueprint | legacy — לאחר מעבר Control לארכיון | — | — |

```
┌──────────────────── ADL Control ────────────────────┐
│  adl_control (Flask מונולית)                        │
│  /dashboard  ·  /shareflow (מ-adl_platform_module)  │
│  DB: adl_control (PostgreSQL)                       │
└────────────────────────┬────────────────────────────┘
                         │ HTTPS + X-ADL-Admin-Key
                         ▼
┌──────────────────── ADL ShareFlow ──────────────────┐
│  backend/ Flask API  ·  PostgreSQL ShareFlow        │
│  /api/*  ·  /download  ·  /pilot  ·  /api/adl/*     │
└─────────────────────────────────────────────────────┘
```

**מדריך מעבר:** `DEPLOY_ADL_CONTROL.md`

**מצב נוכחי (5 יוני 2026):** ב-repo `adl_control` קיימים שני factories לפריסה נפרדת; ב-Railway עדיין יכול לרוץ `create_app()` מונוליתי עד הגדרת שני שירותים (`railway.control.toml` / `railway.blueprint.toml`).

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
| `features/expenses/` | הוצאות — הוספה, עריכה, OCR, בחירת משתתפים |
| `features/balances/` | יתרות, סיכום אירוע, התחשבנות |
| `features/notifications/` | התראות in-app |
| `features/profile/` | פרופיל, הגדרות, תזכורות, פרטי תשלום |
| `features/ocr/` | סריקת קבלות |
| `l10n/` | עברית (`app_he.arb`) + אנגלית (`app_en.arb`) — 399 מפתחות |
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
| `groups/` | קבוצות + מונטיזציה | CRUD /groups, /activate, /extend, /renew, /upgrade-tier, /reopen, /duplicate |
| `expenses/` | הוצאות | CRUD /expenses |
| `balances/` | מנוע חישוב יתרות | GET /groups/{id}/balances |
| `settlements/` | הסדרי חובות | POST /settlements |
| `notifications/` | התראות + FCM | GET /notifications, POST /fcm-token |
| `ocr/` | קבלות — צירוף + OCR | POST /ocr/attach, POST /ocr/scan, GET /ocr/receipts/{id}/image |
| `currency/` | שערי חליפין | GET /currency/rates, /convert; POST /currency/rates (admin), /refresh (admin) |
| `dashboard/` | ADL Admin API | GET /dashboard/stats, /monetization |
| `download/` | דפי הורדה + פיילוט | GET /download, /pilot/join, /getting-started, /support, /account-deletion, /privacy, /join/<code>; `/pilot` ו-`/invite` מפנים לנתיבים החדשים |
| `scheduler.py` | משימות אוטומטיות | תזכורות שעתיות + בדיקת פקיעה יומית |

**קובץ הגדרות:** `/backend/.env` (לא ב-git)

**כתובת ייצור:** `https://adlshareflow-production.up.railway.app` — **פעיל** ✅

---

### 3. בסיס נתונים (PostgreSQL)

**מודלים עיקריים** (`/backend/app/models.py`):

| טבלה | תוכן |
|------|------|
| `users` | משתמשים, פרופיל, פרטי תשלום, `is_guest`, `account_mode` (`pilot`/`active`), `last_login_at` |
| `groups` | קבוצות + מצב lifecycle + תמחור |
| `group_members` | חברות בקבוצות + תפקידים |
| `expenses` | הוצאות + פיצולים |
| `expense_participants` | חלוקת הוצאה לכל משתתף |
| `settlements` | הסדרי חובות |
| `notifications` | התראות in-app |
| `fcm_tokens` | tokens לפוש נוטיפיקיישן |
| `group_payments` | תשלומי הפעלה/שדרוג/הארכה |
| `feature_flags` | הגדרות מערכת (PAYMENTS_ENABLED וכו') |
| `pilot_funnel_events` | אירועי משפך פיילוט אנונימיים (עמוד התקנה / TestFlight / APK) |
| `reminder_settings` | הגדרות תזכורות אוטומטיות |

**שינוי סכמה אחרון (migration `a9b8c7d6e5f4`):**
- נוסף עמודה `account_mode VARCHAR(20) NOT NULL DEFAULT 'pilot'` לטבלת `users`

---

### 4. שירותים חיצוניים

| שירות | מה הוא עושה | חשוב לדעת |
|-------|------------|-----------|
| **Firebase** | Push Notifications (FCM) | Backend: `firebase-credentials.json`; Android: `google-services.json` + plugin; iOS: `GoogleService-Info.plist` |
| **Firebase Auth** | Google Sign-In | Bundle: `com.adl.shareflow` |
| **Google Vision** | OCR — סריקת קבלות | 1,000 סריקות/חודש חינם |
| **ExchangeRate-API** | שערי מטבע בזמן אמת | חינמי, ללא מפתח — `api.exchangerate-api.com/v4/latest/{base}`; cache ב-PostgreSQL 3 שעות; scheduler מרענן **כל 9 המטבעות** (ILS, USD, EUR, GBP, JPY, AED, CHF, CAD, AUD) כל 3 שעות |
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

### 5. ADL Control (דשבורד ניהול — שם קנוני)

**שם קנוני:** ADL Control (לא "ADL Platform" / "Blueprint Web").

**מיקום קוד:**

| שכבה | נתיב | פרויקט Railway |
|------|------|----------------|
| דשבורד ראשי + `/shareflow` + Blueprint | repo `adl_control` | **ADL Control** (יעד) — כיום ב-**ADL Blueprint** |
| מודול ShareFlow (blueprint) | `/adl_platform_module/shareflow/` | משולב ב-ADL Control |
| API נתוני ShareFlow | `/backend/app/dashboard/routes.py` → `/api/adl/*` | **ADL ShareFlow** |

מודול `/shareflow` **לא** קורא ישירות מ-DB של ShareFlow — רק HTTP ל-backend:

| שכבה | משתנה | תפקיד |
|------|--------|--------|
| ADL Control UI | `SHAREFLOW_API_URL` | בסיס API ShareFlow |
| ADL Control UI | `SHAREFLOW_ADMIN_KEY` | = `ADL_ADMIN_KEY` ב-ADL ShareFlow |
| ADL ShareFlow Backend | `ADL_ADMIN_KEY` | אימות `X-ADL-Admin-Key` |

**שני מצבי הפעלה:**

| מצב | כתובת | איפה מגדירים env |
|-----|--------|-------------------|
| מקומי (standalone) | `http://localhost:5002/shareflow` | `adl_platform_module/.env` |
| ייצור (ADL Control) | `https://web-production-cddac.up.railway.app/shareflow/` | **Variables בשירות ADL Control** — לא ב-ADL ShareFlow |

על שירות **ADL Control** (repo `adl_control`):

```
SHAREFLOW_API_URL=https://adlshareflow-production.up.railway.app/api
SHAREFLOW_ADMIN_KEY=<זהה ל-ADL_ADMIN_KEY ב-adlshareflow-production>
```

`adl_platform_module/.env` **לא** משפיע על ADL Control בייצור. `ADL_ADMIN_KEY` ב-backend בלבד **לא מספיק** — חובה `SHAREFLOW_ADMIN_KEY` על ADL Control.

- **Endpoints (ShareFlow API):** `GET /api/adl/stats`, `/users`, `/groups`, `/monetization`, `/ocr-stats`, `/feature-flags`, `/activity`, `/settlements`; `POST /api/adl/pilot/reset`; `GET|PUT /api/adl/pilot/mode`; `POST /api/adl/expenses/repair-fx` (תיקון שערי המרה לפי תאריך הוצאה)
- **סינון פיילוט:** פרמטר `scope=pilot` מסנן לפי `feature_flags.PILOT_STARTED_AT` (לשונית פיילוט ב-ADL Control בלבד)
- **כיבוי פיילוט:** `PUT /api/adl/pilot/mode` עם `enabled=false` חוסם את כל `account_mode=pilot`, מבטל refresh tokens; התחברות מחזירה `PILOT_ENDED`; הרשמה חוזרת עם אותו אימייל/OAuth ממירה ל-`active`
- **נתוני ShareFlow:** PostgreSQL ShareFlow (`DATABASE_URL` בפרויקט **ADL ShareFlow** בלבד)
- **DB של ADL Control:** `adl_control` PostgreSQL (`DATABASE_URL` בפרויקט **ADL Control**)

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

### תשתית IAP (In-App Purchase)

| מצב | התנהגות |
|-----|---------|
| `PAYMENTS_ENABLED=false` | הפעלה חינמית (מצב פיילוט) |
| `PAYMENTS_ENABLED=true` | חיוב דרך Apple/Google לפני הפעלה |

**זרימת תשלום:**
1. Flutter: `IapService.purchase(priceIls)` — פותח גיליון תשלום של Apple/Google
2. Apple/Google מחזירים `receipt` / `purchaseToken`
3. Flutter שולח ל-`POST /api/groups/:id/activate` עם `receipt_data + platform + product_id`
4. Backend → `validate_iap_receipt()` → מאמת מול שרתי Apple (`/verifyReceipt`) / Google Play API
5. אם תקין — מפעיל את הקבוצה

**Product IDs (נדרש יצירה ידנית בחנויות — חייב להתאים ל־`iap_service.dart`):**

| מחיר | Product ID |
|------|-----------|
| 5 ₪ | `com.adl.shareflow.tier_5` |
| 10 ₪ | `com.adl.shareflow.tier_10` |
| 15 ₪ | `com.adl.shareflow.tier_15` |
| 20 ₪ | `com.adl.shareflow.tier_20` |
| 25 ₪ | `com.adl.shareflow.tier_25` |
| 30 ₪ | `com.adl.shareflow.tier_30` |
| 35 ₪ | `com.adl.shareflow.tier_35` |
| 45 ₪ | `com.adl.shareflow.tier_45` |
| 49 ₪ | `com.adl.shareflow.tier_49` |
| 69 ₪ | `com.adl.shareflow.tier_69` |
| 79 ₪ | `com.adl.shareflow.tier_79` |
| 89 ₪ | `com.adl.shareflow.tier_89` |

**משתני סביבה נדרשים (Railway):**

| משתנה | מקור |
|-------|------|
| `APPLE_SHARED_SECRET` | App Store Connect → App → In-App Purchases → App-Specific Shared Secret |
| `GOOGLE_PLAY_CREDENTIALS_JSON` | Google Play Console → Setup → API access → Service account (JSON) |

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

**APK אחרון שהופץ לפיילוט (גרסה 1.0.9+64):**
- קישור: `APK_DOWNLOAD_URL` ב-Railway (GitHub Releases); משתמשים מקבלים `GET /download/apk`
- Release: https://github.com/adiel1234/adl_shareflow/releases/tag/v1.0.9-build64
- **למשתמשי פיילוט:** שתפו `/pilot/join` → `/getting-started` (לא `/download` ישירות)
- **יעד הבא לחנויות / הפצה:** `1.0.9+70` — ראה `PENDING_RELEASE.md` (עדיין לא Release חדש)

### iOS (TestFlight)
```
1. עדכן version ב-pubspec.yaml
2. Xcode → Product → Archive (~3 דקות)
3. Organizer → Distribute App → Upload (~5 דקות)
4. App Store Connect → TestFlight → Build חדש מופיע אוטומטית
```

**מסע פיילוט:** `/pilot/join` → `/getting-started`. אייפון: (1) `/install/testflight` (2) `TESTFLIGHT_URL` ל-ShareFlow. אנדרואיד: `/download/apk`. `/invite` ו-`/pilot` מפנים לנתיבים החדשים. `/join/<code>` נשאר להזמנת קבוצה.

---

## משתני סביבה קריטיים (Backend)

| משתנה | תיאור | חובה | ערך נוכחי |
|-------|--------|-------|-----------|
| `DATABASE_URL` | PostgreSQL connection string | ✅ | Railway PostgreSQL |
| `JWT_SECRET_KEY` | סוד לחתימת tokens | ✅ | — |
| `FIREBASE_CREDENTIALS_PATH` | נתיב לקובץ Firebase Admin JSON | ✅ Push | — |
| `GOOGLE_APPLICATION_CREDENTIALS` | נתיב לקובץ Google Vision JSON | ✅ OCR | — |
| `PUBLIC_BASE_URL` | בסיס URL ציבורי לקבצי `/uploads` (קבלות) — **ללא** `/api` | 🟡 | `https://adlshareflow-production.up.railway.app` |
| `STORAGE_LOCAL_PATH` | תיקיית uploads מקומית בשרת | 🟡 | `./uploads` |
| `ADL_ADMIN_KEY` | מפתח גישה ל-Dashboard | ✅ Dashboard | — |
| `RESEND_API_KEY` | מפתח Resend לשליחת מיילים | ✅ | מוגדר ב-Railway |
| `RESEND_FROM_EMAIL` | כתובת שולח המיילים | ✅ | `noreply@adl-studio.com` |
| `SMTP_SENDER_NAME` | שם השולח בכותרת המייל | 🟡 | `ADL ShareFlow` (ברירת מחדל) |
| _(DB: `feature_flags`)_ | `PAYMENTS_ENABLED` — גביית תשלום אמיתי (לא משתנה סביבה) | 🔴 כבוי בפיילוט | `false` עד ההעלאה לחנויות; ניהול: Control → `/shareflow` |
| _(DB: `feature_flags`)_ | `PILOT_STARTED_AT` — חותמת זמן לתחילת הפיילוט | ✅ פעיל | סינון `scope=pilot`; מתעדכן ב-`POST /api/adl/pilot/reset` |
| _(DB: `feature_flags`)_ | `PILOT_MODE_ENABLED` — מצב פיילוט פתוח/סגור | ✅ פעיל בפיילוט | `true`/`false`; ניהול: Control → `/shareflow/pilot` |
| _(DB: `users.account_mode`)_ | `pilot` / `active` — סוג חשבון | ✅ | הרשמה בפיילוט → `pilot`; אחרי כיבוי + הרשמה מחדש → `active` |
| `TESTFLIGHT_URL` | קישור TestFlight Public Link ל-iOS — `/pilot`, `/download` (redirect iPhone) | ✅ **חובה לפיילוט** | Public Link מ-App Store Connect; לא `placeholder` |
| `APK_DOWNLOAD_URL` | מקור APK (Drive file URL / id) — בדפים מוגש `/download/apk` | ✅ | Google Drive / GitHub Releases (ישיר) |

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
| App Store Connect | ShareFlow (שם) · Apple ID `6763933889` · SKU `adlshareflow2026` |
| TestFlight | Internal Group פעיל |

---

## תהליכים אוטומטיים (Scheduler)

| משימה | תדירות | תיאור |
|-------|--------|--------|
| `send_auto_reminders` | כל שעה | תזכורות תשלום לחייבים |
| `check_group_expirations` | כל 24 שעות | מעבר קבוצות ל-expired + התראה 3 ימים מראש |
| `refresh_exchange_rates` | כל 3 שעות | משיכת שערים מ-ExchangeRate-API לכל 9 מטבעות האפליקציה → PostgreSQL |

---

## נקודות כשל ידועות ופתרונות

| בעיה | סיבה | פתרון |
|------|------|--------|
| אפליקציה לא מתחברת לשרת | URL הייצור לא מוגדר | עדכן `app_config.dart` → בנה מחדש |
| Push לא מגיע ל-iOS | APNs לא מוגדר | הוגדר ב-Firebase (Key: `4BT7S9CS4V`) |
| אפליקציה Android תקועה ב-splash | Deadlock ב-Keystore באתחול (build ≤35) | build **36+**: `AppSecureStorage` + דחיית FCM |
| מסך login נפתח שוב ושוב (Android) | FCM מנסה לרשום token לפני login → 401 → `onSessionExpired` | build **37+**: רישום FCM רק אחרי login; `onSessionExpired` רק עם סשן |
| אפליקציה Android תקועה ב-splash | `google-services.json` חסר | הורד מ-Firebase Console → שמור ב-`android/app/` |
| OCR לא עובד | Google Vision credentials חסר | הגדר `GOOGLE_APPLICATION_CREDENTIALS` בשרת |
| שער דולר/שקל שגוי (למשל 3.72) | `/currency/convert` השתמש רק ב-fallback קבוע כשאין cache ב-DB | **תוקן 10.6.26** — live API + scheduler; פריסת backend בלבד; build חדש אופציונלי (רענון cache במסך הוצאה) |
| שערי GBP/JPY/AED/CHF/CAD/AUD ישנים | scheduler ריענן רק ILS/USD/EUR; AUD חסר ב-fallback | **תוקן 10.6.26** — scheduler לכל 9 מטבעות + fallback AUD; פריסת backend בלבד |
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
| PAYMENTS_ENABLED | 🔴 כבוי (פיילוט חינמי) — מופעל רק בהעלאה לחנויות |
| Firebase App Distribution | 🟡 מתוכנן — טרם הוגדר |

---

## שינויים — build 32 prep (9 יוני 2026)

### Backend
- **`POST /ocr/attach`**: העלאת תמונת קבלה **ללא OCR** — `status=confirmed`; מחזיר `receipt_id` + `image_url`.
- **`GET /uploads/<path>`**: הגשת קבצי קבלות (`STORAGE_BACKEND=local`, ללא JWT).
- **`GET /ocr/receipts/<id>/image`** (build 34): הגשת קבלה **מאומתת** (JWT + חבר קבוצה); מומלץ לצפייה באפליקציה.
- **`Expense.to_dict`**: שדות `has_receipt`, `receipt_image_url`, `receipt_id`; `POST/PUT` expenses מקבלים `receipt_id`.
- **`DELETE /groups/<id>/members/<user_id>`** (סעיף 13): חסימה אם `net > 0` (נושה); הסרה + **חלוקה מחדש** per-expense אם החבר חייב; **הוסר** `forgive_debt`.
- **`POST /groups/<id>/reopen`** (סעיף 14): שחזור **קבוצה סגורה** (`is_closed=true`, admin בלבד) — `is_closed=false`, `closed_at=null`, סנכרון lifecycle; **אותה** קבוצה עם כל ההוצאות/חברים/היסטוריה; **לא** סופר כקבוצה חדשה במגבלת 3.
- **`POST /groups/<id>/duplicate`** (סעיף 14): שכפול **קבוצה סגורה** (`is_closed=true`, admin בלבד) — קבוצה **חדשה וריקה** עם אותם `GroupMember` (כולל אורחים), אותו `group_type`/`category`, `invite_code` חדש, lifecycle `free`/`limited` לפי מגבלת 3 קבוצות; **ללא** העתקת הוצאות/תשלומים/היסטוריה.

### Flutter (Mobile)
- **קבלות (9.4)**: «צרף קבלה» בהוספת הוצאה; אינדיקטור ברשימה; צפייה בעריכה/לחיצה (`ReceiptViewerScreen`).
- **קטגוריות (11)**: פריסטים לפי `event` / `ongoing` + «אחר» עם שם חופשי ביצירת קבוצה.
- **הסרת חבר (13)**: דיאלוג חדש — חסימת נושה; אישור חלוקה מחדש לחייב.
- **שחזור/שכפול קבוצה סגורה (14)**: «שחזור / המשך קבוצה» בתפריט ⋮ (מנהל, קבוצה סגורה) → דיאלוג 2 אפשרויות: **שחזור** (`POST /reopen`, אותה קבוצה + נתונים) או **שכפול** (דיאלוג שם → `POST /duplicate`, קבוצה חדשה); אם `limited` בשכפול — זרימת הפעלה קיימת.

---

## שינויים — F1 + F3a (יוני 2026)

> **הערה:** F1 «מחל על החוב» **בוטל** — ראו סעיף 13 / build 32 למעלה.

### Backend (היסטורי)
- **`DELETE /groups/<group_id>/members/<user_id>`** (`groups/routes.py`): ~~`forgive_debt`~~ — **הוסר ב-build 32**.

### Flutter (Mobile) — היסטורי
- ~~**F1 — הסרת חבר עם בחירת טיפול בחוב**~~ — **הוחלף** ב-build 32 (סעיף 13).
- **F3a — כפתור "שילמתי ישירות"** (`balances/presentation/screens/balances_screen.dart`):
  - בכרטיס "העברות נדרשות": נוסף כפתור outline "שילמתי ישירות" → Dialog "האם {name} אישר?" → `requestSettlement` → snackbar "ממתין לאישור {name}".
  - ב-`_PeriodReportCard._markPaid` (חובות תקופתיים): כפתור "שולם ✓" פותח עכשיו דיאלוג אישור עם שמות הצדדים לפני ביצוע.
- **l10n**: נוספו מפתחות `removeMemberDebtQuestion`, `removeMemberDebtPay`, `removeMemberDebtForgive`, `memberRemovedForgiven`, `paidDirectly`, `confirmDirectPayment`, `waitingForConfirmation`, `confirmMarkDebtPaid`, `confirmMarkDebtPaidBody`.

---

## שינויים — גל יוני 2026 (אבטחה ותיקוני לוגיקה)

### Backend
- **מנוע יתרות** (`balances/engine.py`):
  - `calculate_group_balances` מחסיר `Settlement` עם `status='confirmed'` מהיתרות — חובות נמחקים לאחר תשלום.
  - חברים שהוסרו מהקבוצה (`GroupMember` נמחק) עדיין נכללים בחישוב אם הם מופיעים בהוצאות; מסומנים `is_former_member=True`.
  - `SettlementSuggestion` כולל שדות `from_is_former_member` / `to_is_former_member`.
- **JWT** (`config.py`): ברירת מחדל של `JWT_REFRESH_TOKEN_EXPIRES` שונתה מ-30 יום ל-3650 יום (10 שנים). ניתן לשנות דרך `JWT_REFRESH_TOKEN_EXPIRES_DAYS`.
- **`mark_debt_paid`** (`groups/routes.py`): נוספה בדיקת חברות בקבוצה — רק חבר בקבוצה שבבעלות החוב יכול לסמן כשולם.
- **`POST /currency/rates`** (`currency/routes.py`): מוגן עכשיו בבדיקת `X-ADL-Admin-Key` header — רק אדמין יכול לעדכן שערי מטבע ידניים.
- **`POST /groups/<id>/expenses`** (`expenses/routes.py`): `paid_by` ומשתתפים — חברים פעילים בלבד; כש-`participants` מכיל רק `user_id` (ללא `share_amount`) — חלוקה שווה כמו בעריכה; ולידציה שסכום החלקים = `converted_amount`.
- **`PUT /expenses/<id>`** (`expenses/routes.py`): כשהלקוח שולח `participants`, השרת מחליף את רשימת המשתתפים ומחלק שווה את `converted_amount` (כולל אורחים — `GroupMember` פעיל עם `is_guest`); ולידציה על סכום החלקים.
- **`DELETE /expenses/<id>`** (`expenses/routes.py`): מחיקת הוצאה — יוצר ההוצאה או מנהל קבוצה; חסימה אם הקבוצה אינה פעילה. האפליקציה (build 41): כפתור «מחק הוצאה» במסך עריכה + דיאלוג אישור; רענון `expensesProvider` / `balancesProvider` / `groupsProvider`.
- **`GET /groups/<id>/event-summary`** (`balances/routes.py`): תצוגה מקדימה לוויזארד «סיים אירוע» — ללא התראות / push. אותה תגובה כמו `POST /summary` (סיכום, `whatsapp_text`, `participants`).
- **`POST /groups/<id>/summary`** (`balances/routes.py`): שליחת סיכום לחברים (`send_app=true`). שדות `books_balanced` / `books_warning` — מזהה חשבונות לא מאוזנים. `queue_notify_event_summary` — שמירת התראות + FCM ברקע (`app/common/background.py`).
- **`POST /groups/<id>/settlements/mark-guest-paid`** (`settlements/routes.py`): מניעת כפילויות — אם כבר קיים pending לאותו אורח→נושה, מחזיר אותו במקום ליצור כפילות; תוכנית העברות (`calculate_settlement_plan`) מפחיתה סכומי pending כדי שלא יופיע חוב כפול ב-UI.
- **`MonetizationService`** (`groups/monetization_service.py`): הוצאת מערכת (`ADL ShareFlow Service`) **תמיד** נוצרת בהפעלה/הארכה/חידוש/שדרוג — גם כש-`PAYMENTS_ENABLED=false` (פיילוט חינמי). `GroupPayment.amount=0` כשאין גבייה אמיתית; `split_among_group=true` מחלק שווה בין **כל** `GroupMember` פעילים בהפעלה; `add_member_to_group_split_expenses` מוסיף חברים/אורחים חדשים להוצאות מערכת (הצטרפות + `POST /groups/<id>/guests`).
- **`POST /groups/<id>/duplicate`** (`groups/routes.py`): שכפול קבוצה סגורה — קבוצה חדשה ללא הוצאות. כשמגבלת 3 קבוצות (`limited`) ו-`PAYMENTS_ENABLED=false` — **הפעלה אוטומטית** בשרת (ללא מסך תשלום באפליקציה); `creation_reason` לא נשלח. כש-`PAYMENTS_ENABLED=true` — נשאר `limited` + דיאלוג הפעלה בלקוח.
- **`POST /groups/<id>/guests`** (`groups/routes.py`): body אופציונלי `split_mode` — `'forward'` (ברירת מחדל) או `'full'`. `'full'` קורא ל-`retroactively_add_member_to_expenses` ומחלק מחדש שווה את כל ההוצאות הקיימות (כולל אורח). אותה לוגיקה משותפת עם `POST /groups/join/<code>`. מנהל בלבד (`require_group_admin`); בממשק — רמז `guestAdminOnlyHint` לחברים שאינם מנהלים (טאב חברים + גיליון הזמנה).
- **`my_role` בתשובות קבוצה:** `POST /groups` (יצירה), `POST /groups/<id>/duplicate`, `POST /groups/<id>/reopen` מחזירים `my_role` (בדרך כלל `admin`) כדי שהלקוח לא יחשב `isAdmin=false` אחרי ניווט ישיר עם האובייקט מהתשובה.
- **דיאלוג `split_mode` בהוספת אורח (build 40, UX build 42):** לפני הצגת הדיאלוג, האפליקציה קוראת `GET /groups/<id>` ל-`fetchExpenseCount` — אובייקט `Group` במטמון Riverpod לא התעדכן אחרי הוספת הוצאה (`expenseCount` נשאר 0). נקודות כניסה: טאב חברים (`_showAddGuestSheet` — דיאלוג לפני פתיחת הגיליון) וגיליון הזמנה (`_showInvite` — דיאלוג לפני פתיחת הגיליון; `splitMode` מועבר ל-`_InviteSheet` ול-`POST /groups/<id>/guests`). build 41: דיאלוג הופיע פעמיים (בפתיחת הזמנה + בסיום `_addGuest`) — תוקן ב-build 42.
- **`split_mode` — מי מחליט? (build 44):** **המזמין** (admin/manager) מגדיר `split_mode` בעת יצירת קישור הזמנה (`_showInvite` ב-`group_detail_screen.dart`) — נשמר כ-`invite_split_mode` על הקבוצה. **הג'וינר** לא רואה דיאלוג — `_join()` בגיליון ההצטרפות קורא את `invite_split_mode` מתגובת `checkInvite` ומשתמש בו ישירות.
- **`POST /groups/<id>/settlements/mark-guest-paid`** (build 21): כשהמנהל שמסמן תשלום הוא גם הנושה (אורח→חבר) — הסטטוס `confirmed` מיד (ללא שלב pending נוסף); pending קיים מאותו סכום מועלה ל-`confirmed` באותה קריאה.
- **`GET /groups/<id>/settlements/pending`** (build 20): מחזיר `can_confirm` / `is_creditor_confirm`; אורחים מסוננים לפי קבוצה (לא גלובלי). אחרי `mark-guest-paid` — נושה שאינו המנהל מאשר בנפרד; מנהל=נושה נסגר בפעולה אחת (build 21).

---

## שינויים אחרונים — גל מאי 2026 (גרסה 1.0.3+6)

### Flutter (Mobile)
- **FCM Real-Time Refresh**: `FcmService.setDataChangeCallback` + `_invalidateForGroup` ב-`main.dart` — כשמגיעה התראה FCM ב-foreground, מתבצע `ref.invalidate` על `expensesProvider` / `balancesProvider` / `pendingSettlementsProvider` / `settlementPlanProvider` / `notificationsProvider` לפי סוג ההתראה.
- **אישור תשלום מהתראה (build 55)**: ב-`settlement_requested` נפתח דיאלוג עם כפתור ירוק «אשר קבלה» (לפי `settlement_id` ב-payload) + «עבור לאישור התשלום» ללשונית יתרות; גם מרשימת ההתראות באפליקציה. קלף ההמתנה ביתרות מציג כפתור אישור לפני מצב «ממתין» של חייב.
- **FCM כשהאפליקציה סגורה**: ב-`fcm_service.py` חייב להיות `ApsAlert(title, body)` בתוך `apns.payload` — אחרת FCM דורס את כותרת/גוף ההתראה ב-iOS ואין באנר ברקע/סגורה (foreground עדיין עובד דרך local notifications). הלקוח רושם `FirebaseMessaging.onBackgroundMessage` ב-`main()` לפני `runApp`; Android: `POST_NOTIFICATIONS` + בקשת הרשאה ב-`initialize`; ערוץ `shareflow_default` תואם לשרת.
- **FCM Tap → Dialog** (build 24): `FcmService.setNotificationTapCallback` + `notification_detail_dialog.dart` — לחיצה על push פותחת דיאלוג עם טקסט מלא וכפתור «סגור»; payload FCM כולל `title`/`body` ב-`data`.
- **Notification Sound** (build 24+): `FeedbackService.notification()` + `assets/sounds/notification.wav` — צליל ב-foreground; `fcm_service.dart` מציג local notification תמיד (גם כש-iOS מסיר `message.notification`); `FeedbackService` משתמש ב-`playback` ב-iOS.
- **FCM Sound Payload** (build 25 fix): `fcm_service.py` — `apns.Aps(sound='default')` + `AndroidNotification(sound='default', channel_id='shareflow_default')` לצליל ב-background.
- **Event Summary Notifications** (build 24): גוף התראה רב-שורתי (`סה"כ` / `משתתפים` / `עלות ממוצעת`) ב-`notifications/service.py`; רשימת in-app מציגה `event_summary` במלואו.
- **Guest Member UI**: תג סגול "אורח" + avatar סגול + כפתורי 🔗 ו-🗑️ ברשימת חברים; Banner למנהל; Sheet "קשר אורח לחשבון"; "שולם" סגול ביתרות.
- **Close Buttons**: נוסף `IconButton(Icons.close)` ל-`_InviteSheet` ו-`_JoinGroupSheet` כדי לאפשר יציאה מפורשת מ-modal bottom sheets.
- **Group Detail Freshness**: `GroupCard.onTap` מנווט דרך `/group-detail` עם `groupId` בלבד — `_GroupDetailLoader` שולף נתוני קבוצה עדכניים מהשרת בכל ניווט. `Group.to_dict()` כולל `total_expenses_amount` (סכום `converted_amount` במטבע הבסיס). הלקוח טוען את **כל** עמודי `/groups/<id>/expenses` (לא רק 30 הראשונים).
- **Deep links להזמנה (תיקון 404):** קישורי `/join/<code>` ו-`shareflow://join/<code>` מטופלים רק ב-`app_links` → `pendingInviteCodeProvider`. Deep linking המובנה של Flutter **כבוי** (`flutter_deeplinking_enabled=false` ב-Android, `FlutterDeepLinkingEnabled=false` ב-iOS) כדי שלא יידחף נתיב `/join/...` ל-Navigator ויציג `_NotFoundScreen`. ב-`AppRouter` נתיבי join מופנים ל-Splash במקום 404 (הגנה משנית).
- **FCM / פושים:** ב־iOS חובה `registerForRemoteNotifications` + העברת `apnsToken` ל־Firebase (`AppDelegate`); רישום טוקן עם המתנה/retry ל־APNs; רישום מחדש ב־`AppLifecycleState.resumed`. הוצאה חדשה: פוש לכל חבר אמיתי שאינו `paid_by` (אורחים מדולגים). `POST /api/adl/users/<id>/test-push` — פוש בדיקה מאדמין. שגיאות `notify_new_expense` נרשמות בלוג (לא נבלעות בשקט).
- **תג אייקון (build 66):** `fcm_service.py` שולח `badge` = מספר התראות שלא נקראו (לא קבוע 1). הלקוח מסנכרן תג ב־`AppBadgeService` בפתיחה / סימון נקרא / יציאה. התראות שדורשות פעולה (תשלום, שדרוג, תפוגה) מוצגות בכתום/אדום; שאר המידע בכחול/נייטרלי. רשימת התראות טוענת את כל העמודים.
- **סיור תהליך + howto:** סיור בית (`home_coach_done_v4`: יצירה → הצטרפות → QR → התראות → פרופיל) ואז howto. סיור קבוצה (`group_coach_done_v2`) עם סגירה חזרה למסך הראשי. עזרה רק מפרופיל (בלי `?` במסך קבוצות). אחרי יצירת קבוצה — מעבר לקבוצה + הזמנה; תמחור גלוי ביצירה, כפתור «צור קבוצה» בלי מחיר.
- **יתרות / מטבע:** בטאב «מי חייב למי» סה״כ הוצאות לפי מטבע מקור; הודעות WhatsApp ותצוגות סכום עם סמל (`149 ₪`) דרך `currency_format.dart`.
- **אנדרואיד Safe Area:** `WindowCompat.setDecorFitsSystemWindows(true)` ב-`MainActivity` + `SafeArea` ב-`MainShell` — מניעת חפיפת שורת ניווט מערכת עם התוכן.

### Backend
- **בדיקת עומס:** `backend/scripts/load_probe_50x100.py` — יוצר קבוצה עם ~50 חברים (אורחים) ו־100 הוצאות, מודד זמני כתיבה/קריאה. דורש `ADL_ADMIN_KEY` להפעלה מעבר למגבלת חינם (7 חברים).
- **Guest Endpoints** (`groups/routes.py`):
  - `POST /groups/<id>/guests` — הוסף אורח לקבוצה (`name`, אופציונלי `split_mode`: `forward` | `full`)
  - `PUT /groups/<id>/guests/<guest_id>/link` — קשר אורח לחשבון קיים
  - `DELETE /groups/<id>/guests/<guest_id>` — הסר אורח
- **Guest Settlement** (`settlements/routes.py`): `POST /groups/<id>/settlements/mark-guest-paid` — מנהל מאשר תשלום אורח:
  - **אורח→חבר**: יוצר `pending` — החבר (נושה) מאשר קבלה.
  - **אורח→אורח**: יוצר `confirmed` מיד (פעולת מנהל אחת).
- **4 תרחישי תשלום** (גרסה 1.0.5+17, תיקון רענון ב-+18):
  1. חבר→חבר: חייב «שילמתי» → נושה «אשר קבלה».
  2. חבר→אורח: חייב «שילמתי» → מנהל «אשר קבלה לאורח».
  3. אורח→חבר: מנהל «אשר העברת אורח» → נושה «אשר קבלה» (אם המנהל הוא הנושה — סגירה מיידית, build 21).
  4. אורח→אורח: מנהל «אשר העברת אורח» (סגירה מיידית).
- **`GET /groups/<id>/settlements/pending`**: מחזיר `from_is_guest` / `to_is_guest` / `is_creditor_confirm`; מנהל רואה תשלומים עם אורחים **בקבוצה**.
- **`PUT /settlements/<id>/confirm`**: נושה מאשר; מנהל יכול לאשר בשם אורח-נושה (תרחיש 2).
- **`GET /groups/<id>/balances/settlements-plan`**: שדה `to_is_guest` נוסף לכל הצעה.
- **Notification Routing** (`notifications/service.py`): התראות לאורחים מנותבות למנהל הקבוצה; האורח עצמו אינו מקבל push. **הוצאה חדשה:** push/in-app רק לחברים שאינם `paid_by` (יוצר ההוצאה לא מקבל). **תזכורת תשלום** (`POST /groups/<id>/remind`, build 31): כותרת `תזכורת תשלום - {שם קבוצה}`; גוף `{נושה} מזכיר לך בקבוצה "{שם}": אתה חייב {סכום} {מטבע}` (גם FCM וגם רשומת DB).
- **FCM Async Dispatch** (build 25+): `notifications/fcm_service.py` — `send_to_user` / `send_to_users` רצים ב-thread נפרד (`app/common/background.py`).
- **Event Summary Non-Blocking** (build 26 fix): `queue_notify_event_summary` — כל `notify_event_summary` (DB + FCM) ברקע; האפליקציה קוראת `GET /event-summary` בפתיחת הוויזארד ו-`POST /summary` רק בשלב 2.
- **DB Migration** (`480ff4d3679c`): נוסף `is_guest BOOLEAN NOT NULL DEFAULT false` ל-`users`.
- **Download / Pilot Pages**: `/pilot/join` שכנוע; `/getting-started` התקנה; `/download` redirect לפי מכשיר.
- **ADL Control Pilot**: לשונית «פיילוט» + מתג `PILOT_MODE_ENABLED`; קוראת ל-`/api/adl/stats|users|activity|settlements|users/<id>` עם `scope=pilot`.
- **מעקב הורדות בפיילוט:** `GET /install/testflight`, `/install/shareflow`, `/download/apk`, `/getting-started`, `/pilot/join` רושמים ל-`pilot_funnel_events`; מוצג ב-`/api/adl/stats` → `downloads` ובלשונית פיילוט ב-Control.
- **איפוס פיילוט (10 אוג׳ 2026):** נמחקו משתמשים/קבוצות/הוצאות/סילוקים בייצור; נשמרים `feature_flags`, `plans`, `exchange_rates`.
- **סיום פיילוט:** כיבוי חוסם משתמשי `pilot`; הרשמה מחדש (אותו אימייל/OAuth) ממירה ל-`active`; JWT בודק `is_active` בכל בקשה (blocklist).
- **פישוט חשבון (אפליקציה):** במסך תשלום — «שילמתי — שלח לאישור»; סגירת קבוצה תמיד עם אישור (`dry_run` ב-`POST /groups/<id>/close`); אשף «סיים אירוע» ב-2 שלבים + קישור חזרה להסדרת חובות.
- **טיפי בהירות (פיילוט):** הסברים קצרים ביצירת קבוצה, הוצאות ריקות, משתתפים, טאב חשבון, באנר חינם, פרטי תשלום, הזמנה/אורח, סריקה מול צירוף קבלה.
- **פוליש לפני פיילוט:** נתיב הסדרה אחד («הסדר תשלום» → מסך תשלום → «שילמתי»); סריקת קבלה כ-CTA ראשי; רמזי אורח מקוצרים בלי תגי תרחיש.
- **תווית יצירת קבוצה (דינמית):** האפליקציה קוראת `GET /api/config/public` (`pilot_mode_enabled`). פיילוט פתוח → «ללא חיוב עכשיו»; פיילוט סגור → «צור קבוצה - {price} ₪». מתג: Control → `/shareflow/pilot`.
- **הזמנת חברים (פישוט):** גיליון הזמנה — WhatsApp ראשי, העתקה/שיתוף משניים, QR/קוד/מייל/אורח מקופלים; בטאב חברים — «הזמן עם קישור» ראשי ו«הוסיפו כאורח» משני.
- **Group Renewal Pricing**: `MonetizationService.renew_group` משתמש ב-`resolve_price(group_type, member_count)` — אותו מחיר כמו הפעלה; אפליקציה קוראת `required_pricing` מהשרת (build 30).

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
