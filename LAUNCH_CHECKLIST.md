# רשימת משימות — השקת ADL ShareFlow

---

## 🔴 חובה לפני השקה (לא מוכן)

### 1. העלאה לענן (Backend)
- [ ] Deploy backend (Railway / Render)
- [ ] PostgreSQL בענן
- [ ] דומיין + SSL (`api.shareflow.adl.co.il`)
- [ ] עדכון כתובת ייצור ב-`mobile/lib/core/config/app_config.dart`

### 2. הפצה ל-iOS
- [ ] תיקון שם חשבון Apple Developer (ממתין לאפל — 2-3 ימים)
- [ ] Archive + Upload ב-Xcode ל-App Store Connect
- [ ] יצירת קבוצת TestFlight + קישור הזמנה
- [ ] עדכון הודעת WhatsApp לקישור TestFlight האמיתי

### 3. הפצה ל-Android
- [ ] `flutter build apk --release --dart-define=FLAVOR=prod`
- [ ] העלאת APK לשרת הענן
- [ ] קישור הורדה ישיר

### 4. דף נחיתה חכם (`/download`)
- [ ] `https://shareflow.adl.co.il/download`
- [ ] זיהוי מכשיר אוטומטי: iOS → TestFlight / Android → APK
- [ ] הודעת WhatsApp עם קישור אחד לכולם

---

## 🟡 לקראת השקה רשמית בחנויות

### 5. הגדרת מצב Pro
- [ ] מחיר מנוי (חודשי / שנתי)
- [ ] פיצ׳רים בלעדיים ל-Pro:
  - קבוצות ללא הגבלת חברים
  - קבוצות ללא הגבלת זמן
  - דוחות וייצוא נתונים
  - התראות חכמות
  - OCR קבלות (סריקה אוטומטית)
  - המרת מטבע בזמן אמת
- [ ] חיבור מערכת תשלום (Stripe / Apple Pay / Google Pay)
- [ ] מסך Upgrade ב-Flutter

### 6. App Store — iOS
- [ ] שינוי שם חשבון Apple לאחר אישור
- [ ] צילומי מסך (5-8 תמונות לכל גודל מסך)
- [ ] תיאור האפליקציה (עברית + אנגלית)
- [ ] מילות מפתח (Keywords)
- [ ] Privacy Policy URL
- [ ] אייקון אפליקציה ברזולוציה גבוהה (1024×1024)
- [ ] סיווג גיל
- [ ] הגדרת מחיר (חינמי + רכישות בתוך האפליקציה)

### 7. Google Play — Android
- [ ] יצירת חשבון Google Play Console ($25 חד פעמי)
- [ ] בניית AAB: `flutter build appbundle --dart-define=FLAVOR=prod`
- [ ] אותם assets כמו App Store (תיאור, צילומי מסך, אייקון)
- [ ] Privacy Policy
- [ ] הצהרת נגישות

### 8. Push Notifications
- [ ] חיבור FCM ב-Flutter (Android)
- [ ] הגדרת APNs Certificate ב-Firebase (iOS)
- [ ] שליחת התראות מהשרת על אירועים (הוצאה חדשה, הצטרף חבר, יתרה)

### 9. Universal Links (לאחר שהדומיין פעיל)
- [ ] קובץ `apple-app-site-association` על השרת
- [ ] קובץ `assetlinks.json` על השרת
- [ ] שינוי `shareflow://join/CODE` → `https://shareflow.adl.co.il/join/CODE`
- [ ] עדכון הודעת ההזמנה בוואטסאפ לכתובת החדשה

---

## 🟢 אופציונלי / שלב הבא

- [ ] אנליטיקס (Firebase Analytics / Mixpanel)
- [ ] Crash Reporting (Firebase Crashlytics)
- [ ] תמיכת לקוחות (Intercom / WhatsApp עסקי)
- [ ] עמוד נחיתה שיווקי
- [ ] B2B — מנוי לעסקים / white label
