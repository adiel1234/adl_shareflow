# פריסת פיילוט — Railway + טלפון

גרסה: **1.0.5+11**

---

## 1. עדכון קוד בענן (Railway)

### א. וידוא שינויים מקומיים

```bash
cd "/Users/adl/Projects/ADL ShareFlow"
git status
git add -A
git commit -m "פיילוט 1.0.5: תיקוני ליבה, משתתפים, סשן, אורח, wizard סגירה"
git push origin main
```

(התאם שם branch אם לא `main`.)

### ב. Deploy ב-Railway

1. היכנס ל-[Railway Dashboard](https://railway.app)
2. פרויקט **ADL ShareFlow** → שירות Backend
3. וודא שה-deploy האחרון **Succeeded** אחרי ה-push
4. בלשונית **Deployments** — בדוק לוגים שאין שגיאת startup

### ג. מיגרציות DB

בטרמינל Railway (או locally עם `DATABASE_URL` של production):

```bash
cd backend
flask db upgrade
```

וודא שמיגרציה `paybox_link` (ואחרות) רצו בלי שגיאה.

### ד. משתני סביבה (אם רלוונטי)

| משתנה | הערה |
|--------|------|
| `JWT_REFRESH_TOKEN_EXPIRES_DAYS` | אופציונלי — ברירת מחדל בקוד: 3650 |
| `ADL_ADMIN_KEY` | לעדכון שערי מטבע בלבד |
| `TESTFLIGHT_URL` | **חובה** — Public Link מ-App Store Connect → TestFlight → ShareFlow → Public Link. בלי זה כפתורי iPhone ב-`/pilot` ו-`/download` לא עובדים. |
| `APK_DOWNLOAD_URL` | URL של קובץ ב-Google Drive (עם `id=...`) או קישור ישיר (GitHub Releases). קבצים גדולים ב-Drive: השרת מגיש `/download/apk` — אל תסמכו על `uc?export=download&confirm=t` ישירות מהטלפון |

---

## 2. התקנת העדכון בטלפון

### Android (APK)

```bash
cd "/Users/adl/Projects/ADL ShareFlow/mobile"
flutter build apk --release
```

קובץ הפלט:

`build/app/outputs/flutter-apk/app-release.apk`

**העברה לטלפון:**

- AirDrop / Google Drive / USB
- או העלאה ל-URL ועדכון `APK_DOWNLOAD_URL` ב-Railway

**התקנה:** אפשר "מקורות לא ידועים" → פתח APK → התקן (מעל גרסה קודמת).

### iOS (TestFlight / מכשיר מחובר)

```bash
cd mobile
flutter build ios --release
```

אחר כך ב-Xcode:

1. פתח `ios/Runner.xcworkspace`
2. Product → Archive
3. Distribute → TestFlight (או Development למכשיר שלך)

**גרסה:** וודא `1.0.5` build `11` ב-Xcode תואם ל-`pubspec.yaml`.

### בדיקת חיבור לשרת

ב-`mobile/lib/core/config/app_config.dart` (או flavor) — וודא ש-API מצביע ל:

`https://adlshareflow-production.up.railway.app`

(או staging אם זה מה שאתה בודק.)

---

## 3. בדיקות

השתמש בקובץ:

**`PILOT_TEST_CHECKLIST.md`**

מומלץ לבצע בסדר: סשן → הצטרפות → הוצאות → תשלומים → אורח → סגירה.

---

## פתרון בעיות נפוצות

| בעיה | פתרון |
|------|--------|
| 401 אחרי זמן רב | וודא build חדש עם תיקון refresh; נסה login מחדש פעם אחת |
| קישור הזמנה לא עובד | וודא Universal Link / `shareflow://` מוגדר ב-iOS/Android |
| יתרות לא מתעדכנות אחרי תשלום | וודא deploy אחרון של backend (מנוע יתרות) |
| APK בטלפון נתקע על דף עם "APK" | Drive מחזיר HTML (~2KB) במקום APK — deploy אחרון + `APK_DOWNLOAD_URL` עם id Drive; בדוק `https://…/download/apk` |
| PayBox לא פותח סכום | צפוי — רק העתק סכום + קישור אישי |
