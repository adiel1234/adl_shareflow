# רשימת משימות — השקת ADL ShareFlow

> עודכן לאחר השלמת שלבי פיתוח 1–7 ו-9.

---

## ✅ הושלם בפיתוח (שלבים 1–7, 9)

- [x] מודל תמחור — Backend + Frontend (Tiers, activation, extension, renewal, upgrade)
- [x] שדרוג Tier אוטומטי כשמשתתפים מתווספים
- [x] מסך פרופיל מורחב (אודות, צור קשר, ADL Projects, Pro banner)
- [x] Push Notifications — FCM (Flutter + Backend)
  - [x] רישום FCM token בהתחברות + מחיקה ב-logout
  - [x] שליחת push על הוצאה חדשה, הצטרפות, שדרוג, הפעלה
  - [x] Scheduler — push 3 ימים לפני פקיעת קבוצה
- [x] QR Code — הצגה + סריקה להצטרפות לקבוצה
- [x] l10n מלא — 396 מפתחות, עברית + אנגלית מסונכרנים
- [x] הוצאות שירות ADL ShareFlow — כולל upgrade
- [x] מסמך PRO_PLAN.md נוצר

---

## 🔴 חובה לפני השקה

### 1. Backend בענן
- [ ] Deploy backend (Railway — כתובת קיימת: `adlshareflow-production.up.railway.app`)
- [ ] PostgreSQL בענן — migration: `flask db upgrade`
- [ ] `FIREBASE_CREDENTIALS_PATH` מוגדר בסביבת הייצור
- [ ] `PAYMENTS_ENABLED` feature flag — הפעלה לפני גביית כסף

### 2. iOS — TestFlight (שלב 8)
- [ ] Archive + Upload ב-Xcode ל-App Store Connect
- [ ] הגדרת APNs Certificate ב-Firebase Console (נדרש ל-push על iOS)
- [ ] יצירת קבוצת TestFlight + קישור הזמנה
- [ ] עדכון הודעת WhatsApp לקישור TestFlight

### 3. Android
- [ ] `flutter build apk --release --dart-define=FLAVOR=prod`
- [ ] העלאת APK לשרת הענן
- [ ] קישור הורדה ישיר

### 4. דף נחיתה חכם (`/download`)
- [ ] זיהוי מכשיר: iOS → TestFlight / Android → APK
- [ ] הודעת WhatsApp עם קישור אחד לכולם

---

## 🟡 לקראת השקה רשמית בחנויות

### 5. Pro Plan (ראה PRO_PLAN.md)
- [ ] הגדרת מנוי + Stripe / Apple Pay
- [ ] מסך Upgrade ב-Flutter

### 6. App Store — iOS
- [ ] צילומי מסך (5-8 לכל גודל מסך)
- [ ] תיאור האפליקציה (עברית + אנגלית)
- [ ] Privacy Policy URL
- [ ] אייקון 1024×1024

### 7. Google Play — Android
- [ ] חשבון Google Play Console ($25)
- [ ] `flutter build appbundle`
- [ ] Privacy Policy

### 8. Universal Links (לאחר דומיין פעיל)
- [ ] `apple-app-site-association` על השרת
- [ ] `assetlinks.json` על השרת
- [ ] מעבר מ-`shareflow://join/CODE` → `https://shareflow.adl.co.il/join/CODE`

---

## 🟢 אופציונלי / שלב הבא

- [ ] Firebase Analytics / Crashlytics
- [ ] תמיכת לקוחות (WhatsApp עסקי)
- [ ] עמוד נחיתה שיווקי
- [ ] B2B / white label
