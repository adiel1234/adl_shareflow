# פריסת ADL Control ב-Railway — מדריך שלב-אחר-שלב

> **מטרה:** להפריד את דשבורד הניהול המרכזי (**ADL Control**) מפרויקט **ADL Blueprint** לפרויקט Railway עצמאי, תוך שמירה על **ADL ShareFlow** כפרויקט נפרד ל-backend של האפליקציה.
>
> **עודכן:** 3 יוני 2026

---

## מפת מצב נוכחי → יעד

| רכיב | שם קנוני | פרויקט Railway נוכחי | URL נוכחי |
|------|-----------|----------------------|-----------|
| דשבורד ניהול (כל האפליקציות) | **ADL Control** | ADL Blueprint | `https://web-production-cddac.up.railway.app` |
| Backend ShareFlow (API + DB) | **ADL ShareFlow** | ADL ShareFlow | `https://adlshareflow-production.up.railway.app` |
| פרויקט legacy / Blueprint | **ADL Blueprint** | ADL Blueprint | (לאחר המעבר — לארכיון או שינוי שם) |

**Repo מקור ל-ADL Control (מחוץ ל-repo הזה):**

- Repo: **`adl_control`** (GitHub: `adiel1234/adl_control`)
- אפליקציית Flask **אחת** — `/dashboard`, `/shareflow`, `/blueprint`, `/b`
- מודול ShareFlow מ-repo `ADL ShareFlow`: **`adl_platform_module/shareflow/`** — מוטמע ב-`adl_control`

> **הערה:** `garage_system` היה מקור ישן; `adl_platform` הועבר ל-`adl_control` (2026).

**שני השירותים בפרויקט ADL Blueprint:**

| שירות | מה זה |
|--------|--------|
| Web (`web-production-cddac`) | אותה אפליקציה — דשבורד + Blueprint |
| PostgreSQL | בסיס נתונים של `adl_control` — **לא** אפליקציה נפרדת |

**להעברה ל-ADL Control:** העבר/שכפל **Web + Postgres** (או Transfer כל השירותים הרלוונטיים) — לא שני repos.

---

## שלב א — תיקון מיידי: נתוני ShareFlow ריקים (לפני המעבר)

**תסמין:** ב-`/shareflow` מופיע דשבורד ריק או באנר "מפתח API חסר".

**סיבה:** `SHAREFLOW_ADMIN_KEY` חסר על **שירות הפלטפורמה** (`web-production-cddac`), לא על backend ShareFlow.

### פעולות ב-Railway UI (עכשיו)

1. פתח [Railway Dashboard](https://railway.app) → פרויקט **ADL Blueprint**.
2. בחר את השירות **`web-production-cddac`** (או השם המקביל — Web / adl_platform).
3. לשונית **Variables** → הוסף/עדכן:

   | משתנה | ערך |
   |--------|-----|
   | `SHAREFLOW_API_URL` | `https://adlshareflow-production.up.railway.app/api` |
   | `SHAREFLOW_ADMIN_KEY` | **העתק** את הערך של `ADL_ADMIN_KEY` מפרויקט **ADL ShareFlow** → שירות Backend (אותו מפתח בדיוק) |

4. **Redeploy** את השירות (Deployments → ⋮ → Redeploy).
5. בדוק: `https://web-production-cddac.up.railway.app/shareflow/` — אמור להציג סטטיסטיקות (משתמשים, קבוצות וכו').

> **חשוב:** `ADL_ADMIN_KEY` על backend ShareFlow **לבדו** לא מספיק. חובה `SHAREFLOW_ADMIN_KEY` על שירות ADL Control.

---

## שלב ב — יצירת פרויקט Railway חדש "ADL Control"

1. Railway Dashboard → **New Project**.
2. שם הפרויקט: **`ADL Control`** (שם קנוני).
3. **אל** תיצור כאן PostgreSQL ל-ShareFlow — DB של ShareFlow נשאר בפרויקט **ADL ShareFlow**.

---

## שלב ג — העברת שירות או פריסה מחדש

### אפשרות 1 (מומלצת): פריסה מחדש מ-GitHub

1. בפרויקט **ADL Control** → **Deploy from GitHub repo**.
2. בחר repo: **`adl_control`**.
3. **Root Directory:** שורש ה-repo (אין תת-תיקייה `adl_platform`).
4. וודא ש-**Start Command** / Dockerfile תואמים לפריסה הקודמת (העתק מהשירות הישן ב-ADL Blueprint).
5. אם יש **PostgreSQL** ל-`adl_control` DB — חבר אותו לפרויקט החדש (ראה שלב ד).

### אפשרות 2: העברת שירות קיים (Transfer)

> Railway מאפשר Transfer של שירות לפרויקט אחר — זמין רק אם האפשרות מופיעה ב-UI.

1. ADL Blueprint → שירות `web-production-cddac` → **Settings** → **Transfer** (אם קיים).
2. יעד: פרויקט **ADL Control**.
3. אחרי ההעברה — עדכן שם השירות ל-`adl-control` (אופציונלי).

### אם repo לא נמצא

- חפש ב-GitHub: `garage_system`, `adl_platform`, `ADL Blueprint`.
- בדוק ב-Railway הישן → שירות → **Settings → Source** — שם מופיע ה-repo המחובר.

---

## שלב ד — העתקת כל ה-Variables

### 4.1 מהשירות הישן לחדש

1. ADL Blueprint → שירות `web-production-cddac` → **Variables** → **Raw Editor** → העתק הכל.
2. ADL Control → שירות החדש → **Variables** → **Raw Editor** → הדבק.
3. וודא במיוחד:

| משתנה | חובה | הערות |
|--------|------|--------|
| `DATABASE_URL` | ✅ | PostgreSQL של `adl_control` (לא ShareFlow!) |
| `SECRET_KEY` | ✅ | סession Flask |
| `ADMIN_PASSWORD` | ✅ | סיסמת כניסה ל-UI (אם מוגדר) |
| `PORT` | 🟡 | Railway מזריק — בדרך כלל `$PORT` |
| `SHAREFLOW_API_URL` | ✅ | `https://adlshareflow-production.up.railway.app/api` |
| `SHAREFLOW_ADMIN_KEY` | ✅ | = `ADL_ADMIN_KEY` ב-ADL ShareFlow |
| `FLASK_ENV` | 🟡 | `production` |

4. אם PostgreSQL היה בפרויקט Blueprint — **צור DB חדש** ב-ADL Control או **העבר** את volume/שירות Postgres (לפי מה ש-Railway מאפשר). עדכן `DATABASE_URL` בהתאם.

### 4.2 טבלת השוואה — ADL Control vs ADL ShareFlow

#### שירות **ADL Control** (דשבורד ניהול)

| משתנה | תפקיד | חובה |
|--------|--------|------|
| `DATABASE_URL` | DB של `adl_control` (מערכות, משתמשי admin) | ✅ |
| `SECRET_KEY` | חתימת session | ✅ |
| `ADMIN_PASSWORD` | כניסה ל-`/login` | ✅ (אם בשימוש) |
| `SHAREFLOW_API_URL` | בסיס API לקריאות ShareFlow | ✅ |
| `SHAREFLOW_ADMIN_KEY` | header `X-ADL-Admin-Key` ל-API | ✅ |
| `PORT` | פורט Railway | 🟡 (אוטומטי) |

**לא** שייך ל-ADL Control: `JWT_SECRET_KEY`, `FIREBASE_*`, `RESEND_*`, `GOOGLE_APPLICATION_CREDENTIALS` — אלה רק ב-backend ShareFlow.

#### שירות **ADL ShareFlow** (backend API)

| משתנה | תפקיד | חובה |
|--------|--------|------|
| `DATABASE_URL` | PostgreSQL ShareFlow | ✅ |
| `JWT_SECRET_KEY` | tokens משתמשים | ✅ |
| `SECRET_KEY` | Flask | ✅ |
| `ADL_ADMIN_KEY` | אימות `/api/adl/*` | ✅ |
| `FIREBASE_CREDENTIALS_PATH` | Push notifications | ✅ |
| `GOOGLE_APPLICATION_CREDENTIALS` | OCR | ✅ |
| `RESEND_API_KEY` | מיילים | ✅ |
| `RESEND_FROM_EMAIL` | שולח | ✅ |
| `GOOGLE_CLIENT_ID` | Google Sign-In | ✅ |
| `APPLE_*` | Apple Sign-In | ✅ |
| `TESTFLIGHT_URL` | דף הורדה iOS | ✅ |
| `APK_DOWNLOAD_URL` | דף הורדה Android | ✅ |
| _(אין)_ | `PAYMENTS_ENABLED` נשמר ב-DB (`feature_flags`) — ניהול מ-`/shareflow` ב-Control | — |
| `JWT_REFRESH_TOKEN_EXPIRES_DAYS` | refresh token | 🟡 |

**קשר בין הפרויקטים:**

```
SHAREFLOW_ADMIN_KEY  (ADL Control)  ===  ADL_ADMIN_KEY  (ADL ShareFlow)
```

---

## שלב ה — דומיין

### אפשרות א: השאר URL Railway (`web-production-cddac`)

- אחרי העברה/פריסה — Railway ייתן URL חדש (למשל `adl-control-production.up.railway.app`).
- **Settings → Networking → Generate Domain** — אפשר ליצור subdomain חדש.
- אם רוצים **לשמור** את `web-production-cddac`:
  - העבר את השירות (Transfer) במקום deploy חדש, **או**
  - מחק domain מהשירות הישן והוסף לחדש (רק domain אחד לשירות).

### אפשרות ב: דומיין מותאם (למשל `control.adl-studio.com`)

1. ADL Control → שירות → **Settings → Networking → Custom Domain**.
2. הוסף: `control.adl-studio.com` (או subdomain אחר).
3. ב-**Namecheap** → Advanced DNS → CNAME:
   - Host: `control`
   - Value: כתובת Railway שמוצגת ב-UI
4. המתן ל-DNS (עד 30 דקות).

---

## שלב ו — אימות

| בדיקה | URL | תוצאה צפויה |
|--------|-----|-------------|
| דשבורד ראשי ADL Control | `/dashboard` או `/` | מסך login / רשימת מערכות |
| ShareFlow Admin | `/shareflow/` | סטטיסטיקות, משתמשים, קבוצות |
| ShareFlow API (ישיר) | `https://adlshareflow-production.up.railway.app/api/adl/stats` | 403 בלי header — תקין |
| API עם מפתח | curl עם `X-ADL-Admin-Key` | JSON עם נתונים |

**בדיקת API ידנית (מהטרמינל):**

```bash
curl -s -H "X-ADL-Admin-Key: <ADL_ADMIN_KEY>" \
  https://adlshareflow-production.up.railway.app/api/adl/stats | head
```

אם `/shareflow` ריק — חזור לשלב א (`SHAREFLOW_ADMIN_KEY`).

---

## שלב ז — ADL Blueprint (אופציונלי)

לאחר ש-ADL Control עובד בפרויקט החדש:

1. **Settings** בפרויקט ADL Blueprint → **Rename** ל-`ADL Blueprint (archived)` — או
2. מחק שירותים שלא בשימוש (רק אחרי וידוא שהכל עובד).
3. **אל** תמחק PostgreSQL של ShareFlow — הוא בפרויקט **ADL ShareFlow**, לא ב-Blueprint.

---

## סיכום ארכיטקטורת Railway (יעד)

```
┌─────────────────────────┐     ┌─────────────────────────┐
│   ADL Control           │     │   ADL ShareFlow         │
│   (פרויקט Railway)      │     │   (פרויקט Railway)      │
│                         │     │                         │
│  garage_system/         │     │  ADL ShareFlow/backend  │
│  adl_platform           │     │                         │
│  /dashboard  /shareflow │────▶│  /api/*  /download      │
│                         │ HTTP│  PostgreSQL (ShareFlow) │
│  PostgreSQL (adl_control)│     │                         │
└─────────────────────────┘     └─────────────────────────┘

┌─────────────────────────┐
│   ADL Blueprint         │  ← legacy / ארכיון אחרי המעבר
└─────────────────────────┘
```

---

## פיתוח מקומי (השוואה)

| מצב | כתובת | קובץ env |
|-----|--------|----------|
| ShareFlow Admin standalone | `http://localhost:5002/shareflow` | `adl_platform_module/.env` |
| ShareFlow Backend | `http://localhost:5050/api` | `backend/.env` |
| ADL Control מלא | תלוי ב-`garage_system` | `.env` של `adl_platform` |

ראה גם: `ARCHITECTURE.md` → סעיף ADL Control.
