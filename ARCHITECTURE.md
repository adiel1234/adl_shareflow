# ADL ShareFlow — ארכיטקטורה ומבנה מערכת

> מסמך זה מתעד את מבנה המערכת, שירותים חיצוניים, תהליכי פריסה ואחזקה.
> עודכן לאחרונה: 6 יוני 2026 (תיקון סגירת חוב אורח→נושה כשמנהל=נושה; build 21)

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
**מדריך התקנה iOS (TestFlight):** [`docs/TESTFLIGHT_IOS_GUIDE.html`](docs/TESTFLIGHT_IOS_GUIDE.html) · [`docs/TESTFLIGHT_IOS_GUIDE.md`](docs/TESTFLIGHT_IOS_GUIDE.md)

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
│  /api/*  ·  /download  ·  /api/adl/*                │
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

- **Endpoints (ShareFlow API):** `GET /api/adl/stats`, `/users`, `/groups`, `/monetization`, `/ocr-stats`, `/feature-flags`
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

**מדריך למשתמשי פיילוט:** [`docs/TESTFLIGHT_IOS_GUIDE.html`](docs/TESTFLIGHT_IOS_GUIDE.html) — HTML עצמאי (RTL, מיתוג ADL) לשיתוף ב-WhatsApp. עדכן `href` בכפתור ההזמנה או `TESTFLIGHT_URL` ב-Railway.

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
| _(DB: `feature_flags`)_ | `PAYMENTS_ENABLED` — גביית תשלום אמיתי (לא משתנה סביבה) | 🔴 כבוי בפיילוט | `false` ב-PostgreSQL; ניהול: Control → `/shareflow` |
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

## שינויים — F1 + F3a (יוני 2026)

### Backend
- **`DELETE /groups/<group_id>/members/<user_id>`** (`groups/routes.py`): נוסף פרמטר `forgive_debt: bool` (ברירת מחדל: `false`).
  - `forgive_debt=false` (ברירת מחדל): מסיר את רשומת ה-`GroupMember`; כל חלקי ההוצאות (`ExpenseParticipant`) נשמרים — החוב ממשיך להופיע בהתחשבנות כ-"חבר לשעבר".
  - `forgive_debt=true`: מאפס את `share_amount` לכל `ExpenseParticipant` של החבר בקבוצה — החוב נמחל לחלוטין מיתרת המערכת.

### Flutter (Mobile)
- **F1 — הסרת חבר עם בחירת טיפול בחוב** (`groups/presentation/screens/members_tab_screen.dart`):
  - כשיש יתרה פתוחה: Dialog מורחב עם שני כפתורי פעולה — "ישלם את חלקו (סכום)" → `forgiveDebt=false`, "מחל על החוב" → `forgiveDebt=true`.
  - ללא יתרה: Dialog אישור פשוט.
  - `GroupRepository.removeMember` עודכן עם פרמטר `forgiveDebt: bool`.
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
- **`POST /groups/<id>/summary`** (`balances/routes.py`): שדות `books_balanced` / `books_warning` — מזהה חשבונות לא מאוזנים (חלקים שגויים או שני זכאים בלי חייבים).
- **`POST /groups/<id>/settlements/mark-guest-paid`** (`settlements/routes.py`): מניעת כפילויות — אם כבר קיים pending לאותו אורח→נושה, מחזיר אותו במקום ליצור כפילות; תוכנית העברות (`calculate_settlement_plan`) מפחיתה סכומי pending כדי שלא יופיע חוב כפול ב-UI.
- **`MonetizationService`** (`groups/monetization_service.py`): הוצאת מערכת (`ADL ShareFlow Service`) **תמיד** נוצרת בהפעלה/הארכה/חידוש/שדרוג — גם כש-`PAYMENTS_ENABLED=false` (פיילוט חינמי). `GroupPayment.amount=0` כשאין גבייה אמיתית; `split_among_group=true` מחלק שווה בין **כל** `GroupMember` פעילים בהפעלה; `add_member_to_group_split_expenses` מוסיף חברים/אורחים חדשים להוצאות מערכת (הצטרפות + `POST /groups/<id>/guests`).
- **`POST /groups/<id>/settlements/mark-guest-paid`** (build 21): כשהמנהל שמסמן תשלום הוא גם הנושה (אורח→חבר) — הסטטוס `confirmed` מיד (ללא שלב pending נוסף); pending קיים מאותו סכום מועלה ל-`confirmed` באותה קריאה.
- **`GET /groups/<id>/settlements/pending`** (build 20): מחזיר `can_confirm` / `is_creditor_confirm`; אורחים מסוננים לפי קבוצה (לא גלובלי). אחרי `mark-guest-paid` — נושה שאינו המנהל מאשר בנפרד; מנהל=נושה נסגר בפעולה אחת (build 21).

---

## שינויים אחרונים — גל מאי 2026 (גרסה 1.0.3+6)

### Flutter (Mobile)
- **FCM Real-Time Refresh**: `FcmService.setDataChangeCallback` + `_invalidateForGroup` ב-`main.dart` — כשמגיעה התראה FCM ב-foreground, מתבצע `ref.invalidate` על `expensesProvider` / `balancesProvider` / `pendingSettlementsProvider` / `settlementPlanProvider` / `notificationsProvider` לפי סוג ההתראה.
- **Guest Member UI**: תג סגול "אורח" + avatar סגול + כפתורי 🔗 ו-🗑️ ברשימת חברים; Banner למנהל; Sheet "קשר אורח לחשבון"; "שולם" סגול ביתרות.
- **Close Buttons**: נוסף `IconButton(Icons.close)` ל-`_InviteSheet` ו-`_JoinGroupSheet` כדי לאפשר יציאה מפורשת מ-modal bottom sheets.
- **Group Detail Freshness**: `GroupCard.onTap` מנווט דרך `/group-detail` עם `groupId` בלבד — `_GroupDetailLoader` שולף נתוני קבוצה עדכניים מהשרת בכל ניווט.

### Backend
- **Guest Endpoints** (`groups/routes.py`):
  - `POST /groups/<id>/guests` — הוסף אורח לקבוצה
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
