# מדריך התקנה — ADL ShareFlow ל-iPhone (TestFlight)

> **גרסת פיילוט:** 1.0.5 build 20 · **ADL Projects**

## קובץ לשיתוף

**המדריך המעוצב (HTML):** [`TESTFLIGHT_IOS_GUIDE.html`](TESTFLIGHT_IOS_GUIDE.html)

שלחו את קובץ ה-HTML ב-WhatsApp / מייל, או העלו ל-Google Drive / iCloud ושתפו קישור. הקובץ עובד גם **offline** (ללא תלות ב-CDN), ומותאם **למובייל** (iPhone) — כפתור CTA דביק, גופנים גדולים, עמודה אחת.

## לפני השיתוף — עדכון קישור TestFlight

1. App Store Connect → TestFlight → External / Internal Group → **Public Link**
2. עדכנו את `href` בכפתור «הצטרפות ל-TestFlight» בקובץ HTML  
   **או** הגדירו `TESTFLIGHT_URL` ב-Railway — דף ההורדה יפנה אוטומטית:  
   `https://adlshareflow-production.up.railway.app/download`

> ⚠️ כרגע ב-HTML מופיע placeholder `[קישור TestFlight]` — יש להחליף לפני הפצה לקבוצת הפיילוט.

## שלבים (תקציר)

1. התקנת **TestFlight** מ-App Store (אם חסר)
2. פתיחת **קישור ההזמנה**
3. **Accept** ב-TestFlight
4. **Install** — ADL ShareFlow
5. התחברות והצטרפות לקבוצה
6. עדכונים דרך TestFlight + אפשרת Push

## תמיכה

- **מייל:** info@adlprojects.co.il  
- **אתר:** [adlprojects.co.il](https://adlprojects.co.il)

## מסמכים קשורים

- [`DEPLOY_PILOT.md`](../DEPLOY_PILOT.md) — פריסה ובניית TestFlight  
- [`PILOT_TEST_CHECKLIST.md`](../PILOT_TEST_CHECKLIST.md) — רשימת בדיקות  
- [`docs/PILOT_DAY2.md`](PILOT_DAY2.md) — יום 2 פיילוט
