# מוצרי ADL — מפת Railway, סביבה ופירוד

> **עודכן:** 5 יוני 2026  
> **מטרה:** שלושה מוצרים ברורים, פריסה מוכנה למכירת Blueprint, וסידור Railway לפני פירוד קוד (שלב 1.3).

---

## שלושת המוצרים

| מוצר | מה זה | קוד / מאגר | פרויקט Railway (יעד) |
|------|--------|------------|----------------------|
| **ADL Control** | ממשק ניהול מרכזי לכל המוצרים — מערכות, tenants, ניהול ShareFlow | `adl_control` (חלק `adl_bp` + `shareflow_bp`) | **ADL Control** |
| **ADL Blueprint** | מוצר נפרד — פרויקטים, הצעות, טפסים ללקוח (`/blueprint`, `/b`) | `adl_control` (חלק `blueprint_*`) | **ADL Blueprint** (אחרי פירוד) |
| **ADL ShareFlow** | אפליקציה לנייד + API + PostgreSQL של המוצר | `ADL ShareFlow` → `backend/` | **ADL ShareFlow** |

**עקרון:** ShareFlow כבר מופרד. Control ו-Blueprint חולקים היום **פריסה אחת** — יעד: שני שירותי Railway ושני entry points (`run_control` / `run_blueprint`).

---

## Railway — מצב נוכחי מול יעד

Workspace: **ADL Projects** (או שם מקביל ב-Railway).

| פרויקט Railway | מצב היום (4.6.2026) | יעד |
|----------------|---------------------|-----|
| **ADL Control** | פרויקט קיים — שירות Web מ-`adl_control` | מקור אמת לדשבורד + `/shareflow` + (זמנית גם Blueprint עד פירוד) |
| **ADL ShareFlow** | Backend API + Postgres ShareFlow — **לא לגעת** | ללא שינוי |
| **ADL Blueprint** | שם ישן — היה מארח את כל `adl_control`; שירות Web ישן עדיין עלול להיות פעיל | **רק Postgres** זמני → שינוי שם ל-`ADL Blueprint (DB temp)` → לא למחוק DB |

### כתובות (ייצור)

| מוצר / שירות | URL | הערה |
|--------------|-----|------|
| ADL Control (Web) | `https://web-production-cddac.up.railway.app` | עד דומיין קבוע / העברת domain |
| ADL ShareFlow API | `https://adlshareflow-production.up.railway.app` | `/api/*`, `/download`, `/join/<code>` |
| ADL Blueprint (מוצר, עתידי) | TBD — subdomain נפרד (למשל `blueprint.adl-studio.com`) | אחרי `run_blueprint` + פרויקט נפרד |

---

## משתני סביבה לפי פרויקט

> **ללא ערכי סוד** — רק שמות משתנים ותפקיד.

### פרויקט ADL Control (שירות Web — `adl_control`)

| משתנה | חובה | תפקיד |
|--------|------|--------|
| `DATABASE_URL` | ✅ | PostgreSQL של `adl_control` (מערכות, admin) |
| `SECRET_KEY` | ✅ | Session Flask |
| `ADMIN_PASSWORD` | ✅ | כניסה ל-`/login` |
| `SHAREFLOW_API_URL` | ✅ | בסיס API — `https://adlshareflow-production.up.railway.app/api` |
| `SHAREFLOW_ADMIN_KEY` | ✅ | = `ADL_ADMIN_KEY` ב-ShareFlow (`X-ADL-Admin-Key`) |
| `PORT` | 🟡 | Railway ($PORT) |
| `FLASK_ENV` | 🟡 | `production` |

**לא** על Control: `JWT_SECRET_KEY`, `FIREBASE_*`, `RESEND_*`, `GOOGLE_APPLICATION_CREDENTIALS`.

### פרויקט ADL Blueprint (יעד — שירות Web נפרד)

| משתנה | חובה | תפקיד |
|--------|------|--------|
| `DATABASE_URL` | ✅ | PostgreSQL של Blueprint (פרויקטים, הצעות) — היום עלול להיות אותו instance כמו Control עד פיצול DB |
| `SECRET_KEY` | ✅ | Session |
| `ADMIN_PASSWORD` | ✅ | אם נדרש לאותו מודל login |
| `PORT` | 🟡 | Railway |

**לא** על Blueprint (ביעד): `SHAREFLOW_*` — אלא אם נוסיף קישור ב-Control בלבד.

### פרויקט ADL ShareFlow (Backend)

| משתנה | חובה | תפקיד |
|--------|------|--------|
| `DATABASE_URL` | ✅ | PostgreSQL ShareFlow |
| `JWT_SECRET_KEY` | ✅ | Tokens משתמשים |
| `SECRET_KEY` | ✅ | Flask |
| `ADL_ADMIN_KEY` | ✅ | `/api/adl/*` |
| `FIREBASE_CREDENTIALS_PATH` | ✅ | Push |
| `GOOGLE_APPLICATION_CREDENTIALS` | ✅ | OCR |
| `RESEND_API_KEY` | ✅ | מיילים |
| `RESEND_FROM_EMAIL` | ✅ | שולח |
| `GOOGLE_CLIENT_ID` | ✅ | Google Sign-In |
| `APPLE_*` | ✅ | Apple Sign-In |
| `TESTFLIGHT_URL` | ✅ | דף הורדה iOS |
| `APK_DOWNLOAD_URL` | ✅ | דף הורדה Android |
| `PAYMENTS_ENABLED` | 🟡 | תשלומים |
| `JWT_REFRESH_TOKEN_EXPIRES_DAYS` | 🟡 | refresh |

**קשר בין פרויקטים:**

```
SHAREFLOW_ADMIN_KEY (Control)  ===  ADL_ADMIN_KEY (ShareFlow)
```

---

## מאגר `adl_control` — היום מול יעד

### היום (פריסה משולבת)

קובץ `app/__init__.py` — `create_app()` רושם **ארבעה** blueprints:

| Blueprint | קידומת URL | תוכן |
|-----------|------------|------|
| `adl_bp` | `` (שורש) | Control: `/login`, `/logout`, `/`, `/dashboard`, `/systems/...`, `/garageiq-intelligence`, API פנימי |
| `shareflow_bp` | `/shareflow` | ניהול ShareFlow: `/`, `/users`, `/groups`, `/ocr-stats`, `/monetization`, פעולות POST |
| `blueprint_admin_bp` | `/blueprint` | מוצר Blueprint — ניהול פרויקטים, הצעות, PDF, WhatsApp/מייל |
| `blueprint_public_bp` | `/b` | לקוח קצה — טופס לפי token: `/<token>`, שלבים, review, thanks |

**הרצה:** `run.py` / `wsgi.py` / `Procfile` → `create_app()` אחד (הכל יחד).

### יעד (פירוד פריסה — שלב 1.4)

| Entry point | Blueprints | פרויקט Railway |
|-------------|------------|----------------|
| `run_control.py` → `create_control_app()` | `adl_bp` + `shareflow_bp` | ADL Control |
| `run_blueprint.py` → `create_blueprint_app()` | `blueprint_admin_bp` + `blueprint_public_bp` | ADL Blueprint |

Control **לא** ייבא לוגיקת Blueprint — רק קישור למוצר (כמו ShareFlow דרך API/URL).

---

## רשימת ניקוי Railway — מיידי

בצע **לפי הסדר** (אחרי ש-ADL Control נפתח ו-`/shareflow` מציג נתונים):

- [ ] **1.** פרויקט **ADL Blueprint** → שירות **Web** הישן (`web-production-cddac` אם כפול) → **השהה** או **מחק** — רק אם **ADL Control** כבר מגיש את אותו אתר
- [ ] **2.** פרויקט **ADL Control** → **Settings → Source** → חיבור GitHub: `adiel1234/adl_control` (שורש repo)
- [ ] **3.** **ADL Control** → Variables: `SHAREFLOW_API_URL`, `SHAREFLOW_ADMIN_KEY` (ראה `DEPLOY_ADL_CONTROL.md` שלב א)
- [ ] **4.** **ADL Control** → **Networking** — domain קבוע (`control.adl-studio.com` או שמירת `web-production-cddac`)
- [ ] **5.** פרויקט **ADL Blueprint** → **Rename** ל-`ADL Blueprint (DB temp)` — מסמן שרק DB
- [ ] **6.** **אל** למחוק שירות **PostgreSQL** בפרויקט Blueprint עד העברת `DATABASE_URL` ל-Control / Blueprint נפרד
- [ ] **7.** **ADL ShareFlow** — ללא שינוי פריסה; רק וידוא deploy אחרון אחרי push

מדריך מפורט: [`DEPLOY_ADL_CONTROL.md`](../DEPLOY_ADL_CONTROL.md)

---

## פירוד קוד (שלב 1.3 — יושם ב-repo `adl_control`)

| שלב | סטטוס |
|------|--------|
| `create_control_app()` — `adl_bp` + `shareflow_bp` | ✅ |
| `create_blueprint_app()` — `blueprint_admin_bp` + `blueprint_public_bp` | ✅ |
| `run_control.py` / `run_blueprint.py` | ✅ |
| `railway.control.toml` / `railway.blueprint.toml` (פקודות gunicorn) | ✅ |
| `create_app()` מלא — תאימות לאחור (`railway.toml`, `Procfile`) | ✅ ללא שינוי |

**פריסה Railway (הבא):** שני שירותים מאותו repo — Control: `adl_control.app:create_control_app()`; Blueprint: `adl_control.app:create_blueprint_app()` (ראה `railway.*.toml`).

**עדיין לא בוצע:** מבנה תיקיות נפרד, `DATABASE_URL` נפרד ל-Blueprint, שירות Web שני ב-UI, כרטיס Blueprint ב-Control שמצביע ל-URL חיצוני, דומיין מכירה.

---

## המשך יום 2 — בדיקות ופיילוט

| בלוק | מסמך |
|------|------|
| בלוק 2 — בדיקות ShareFlow | [`PILOT_DAY2.md`](PILOT_DAY2.md#בלוק-2--פיילוט-shareflow-בדיקות-וסגירה) |
| בלוק 3 — 15–20 משתתפים | [`PILOT_DAY2.md`](PILOT_DAY2.md#בלוק-3--תשתית-פיילוט-1520-משתתפים) |

קישורים קיימים:

- [`PILOT_TEST_CHECKLIST.md`](../PILOT_TEST_CHECKLIST.md)
- [`DEPLOY_PILOT.md`](../DEPLOY_PILOT.md)

---

## סדר עבודה היום

1. **1.1–1.2** — מסמך זה + ניקוי Railway (ידני ב-UI)
2. **1.3** — factories + entry points ב-`adl_control` (✅); המשך: שני שירותים ב-Railway UI
3. **בלוק 2–3** — לפי [`PILOT_DAY2.md`](PILOT_DAY2.md)
