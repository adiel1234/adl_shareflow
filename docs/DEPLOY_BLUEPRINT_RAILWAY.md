# פריסת ADL Blueprint ב-Railway — שלב אחר שלב

> **עודכן:** 2026-06-05  
> **מטרה:** שירות Blueprint נפרד (`adl-blueprint-web`), בעוד Control נשאר ב-`adl-control-production`.  
> **Repo:** `adiel1234/adl_control` — אותו מאגר, משתנה סביבה אחד מבדיל בין המוצרים.

---

## אבחון מהיר (לפני שינוי הגדרות)

| בדיקה | Control (שגוי על Blueprint) | Blueprint (נכון) |
|--------|-------------------------------|------------------|
| `curl -sI …/dashboard` | `302` → `/login` | **`404`** (אין נתיב דשבורד) |
| `curl -sI …/shareflow/` | `302` → `/login` | **`404`** (אין ShareFlow) |
| `curl -sI …/blueprint/` | `302` → `/login` | `302` → `/login` (לפני התחברות) |

אם `/dashboard` מחזיר `302` ולא `404` — השירות עדיין מריץ **Control**, לא Blueprint.

### שגיאת 500 אחרי התחברות (תוקן 5.6.2026)

| סימפטום | סיבה | תיקון |
|---------|------|--------|
| `/login` עובד (200), אחרי התחברות `/blueprint/` → 500 | `url_for('adl.dashboard')` בתבנית `_layout.html` — ב-Blueprint בלבד אין blueprint `adl` | עדכון `adl_control`: `control_dashboard_url` ב-context processor |

אימות אחרי deploy (עם session — בדפדפן או cookie):

```bash
# לפני login — 302
curl -sI "$BASE/blueprint/" | head -1
# אחרי login בדפדפן — דשבורד פרויקטים, לא 500
```

אופציונלי: `ADL_CONTROL_URL=https://adl-control-production.up.railway.app` — קישור "Control" בסרגל Blueprint.

---

## הדבר היחיד שחייבים להגדיר ב-Railway (שירות Blueprint Web)

1. פתחו את **פרויקט Railway** של Blueprint (לא פרויקט Control).
2. בחרו את שירות ה-**Web** שמחובר לדומיין `adl-blueprint-web.up.railway.app`.
3. לשונית **Variables** (משתני סביבה).
4. הוסיפו משתנה:
   - **Name:** `ADL_PRODUCT`
   - **Value:** `blueprint`
5. **Deploy** → **Redeploy** (או המתינו לדיפלוי אוטומטי אחרי push ל-`main`).

אין חובה להגדיר `RAILWAY_CONFIG_FILE` או Custom Start Command — הקוד קורא `ADL_PRODUCT` ב-`create_app()`.

### מה לא לעשות

- אל תגדירו `ADL_PRODUCT=blueprint` על שירות **Control** — הוא יישאר בלי המשתנה (ברירת מחדל: control).
- **Root Directory:** השאירו **ריק** (שורש המאגר `adl_control`). אם מוגדר תת-תיקייה שגויה — הבנייה נכשלת או רצה קוד ישן.
- **אותו דומיין על שני שירותים:** ודאו ש-`adl-blueprint-web` מצביע רק לשירות Blueprint Web, לא ל-Control.

### אופציונלי (אם Custom Start Command כבר שונה ידנית)

ב-**Settings → Deploy → Custom Start Command** אפשר לאפס (ריק) או:

```text
gunicorn --workers 2 --bind 0.0.0.0:$PORT --timeout 120 "adl_control.app:create_app()"
```

---

## מבנה יעד

| פרויקט Railway | שירות | `ADL_PRODUCT` | דומיין לדוגמה |
|----------------|--------|---------------|----------------|
| ADL Control | Web | *(לא מוגדר / control)* | `adl-control-production.up.railway.app` |
| ADL Blueprint | Web + Postgres | **`blueprint`** | `adl-blueprint-web.up.railway.app` |

---

## משתני סביבה נוספים (Blueprint Web)

העתיקו מ-Control את אותם ערכי DB וסודות, לפי הצורך:

| משתנה | הערה |
|--------|------|
| `DATABASE_URL` | Postgres של פרויקט Blueprint (או משותף — לפי הארכיטקטורה) |
| `SECRET_KEY` | כמו Control |
| `ADMIN_PASSWORD` | אם אין משתמשים ב-`users` |
| `BLUEPRINT_APP_URL` | `https://adl-blueprint-web.up.railway.app` (לקישורים חיצוניים) |
| `ADL_CONTROL_URL` | `https://adl-control-production.up.railway.app` (קישור Control בתפריט Blueprint) |

---

## אימות אחרי Redeploy

```bash
BASE="https://adl-blueprint-web.up.railway.app"
echo "dashboard (צריך 404):" && curl -sI "$BASE/dashboard" | head -1
echo "shareflow (צריך 404):" && curl -sI "$BASE/shareflow/" | head -1
echo "blueprint (צריך 302 login):" && curl -sI "$BASE/blueprint/" | grep -E '^HTTP|^location'
```

תוצאה תקינה:

- `dashboard` → `HTTP/2 404`
- `shareflow/` → `HTTP/2 404`
- `blueprint/` → `HTTP/2 302` עם `location: /login`

---

## שלב 5 — חיבור מ-Control

בשירות **Control** → Variables:

```text
BLUEPRINT_APP_URL=https://adl-blueprint-web.up.railway.app
```

Redeploy ל-Control. בדשבורד Control, כרטיס Blueprint יפתח את הכתובת הנפרדת.

---

## דחיפת קוד (מפתח)

```bash
cd "/Users/adl/Projects/adl_control"
git push origin main
```

אחרי push + `ADL_PRODUCT=blueprint` + redeploy — הריצו את פקודות ה-curl למעלה.
