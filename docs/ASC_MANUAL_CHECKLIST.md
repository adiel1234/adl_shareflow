# App Store Connect — מדריך תשתית (ידני)

> מטרה: לסגור את כל מה שדורש ASC **לפני** סוף הפיילוט, בלי לבנות IPA סופי.  
> טקסטים מוכנים: `docs/APP_STORE_LISTING_IOS.md`  
> אימות ריפו/שרת: `./scripts/verify_ios_store_prep.sh`

---

## 1) דף המוצר (App Information + Version)

1. היכנס ל־[App Store Connect](https://appstoreconnect.apple.com) → האפליקציה **ShareFlow**
2. **App Information**
   - Privacy Policy URL:  
     `https://adlshareflow-production.up.railway.app/privacy`
   - Category: Finance או Lifestyle
   - Age rating: מלא לפי השאלון (אין UGC מסוכן / אין הימורים)
3. צור / ערוך גרסה (למשל 1.0.9) — **בלי** לשייך build עדיין
4. העתק מ־`docs/APP_STORE_LISTING_IOS.md`:
   - שם / כותרת משנה
   - תיאור HE + EN
   - מילות מפתח
   - Support URL / Marketing URL
5. **App Privacy** — סמן איסוף שתואם ל־`/privacy`:
   - Contact Info (Email)
   - Financial Info (פרטי תשלום בין משתמשים — Bit/PayBox וכו׳, אם מוצג)
   - Device ID (Push / FCM)
   - Tracking: לא

סמן כאן כשסיימת: `[ ] דף מוצר + פרטיות ASC`

---

## 2) צילומי מסך

צלם מההתקנה המקומית על האייפון (`1.0.9+69`), **בלי** להפיץ:

| # | מסך | איך להגיע |
|---|-----|-----------|
| 1 | בית / קבוצות | אחרי התחברות |
| 2 | הוספת הוצאה | קבוצה → + → מטבע עם דגל + תאריך |
| 3 | רשימת הוצאות | עם תאריכים + כפתור מיון |
| 4 | יתרות | טאב חשבון / מי חייב למי |
| 5 | הזמנה | הזמן חבר → קוד + QR + קישור |

העלה ל־ASC לפי הגדלים שדורשים כרגע (לרוב 6.7").

סמן: `[ ] צילומי מסך הועלו`

---

## 3) In-App Purchases — צור את כולם עכשיו

**סוג:** לפי המודל הקיים בקוד — מוצרי מחיר חד־פעמיים (Consumable או Non-Consumable; אם לא בטוח — Non-Consumable לכל tier activation).  
**חשוב:** ה־Product ID חייב להיות **בדיוק** כמו בטבלה.

| מחיר | Product ID | שם לתצוגה (הצעה) |
|------|------------|-------------------|
| 5 ₪ | `com.adl.shareflow.tier_5` | ShareFlow Tier 5 |
| 10 ₪ | `com.adl.shareflow.tier_10` | ShareFlow Tier 10 |
| 15 ₪ | `com.adl.shareflow.tier_15` | ShareFlow Tier 15 |
| 20 ₪ | `com.adl.shareflow.tier_20` | ShareFlow Tier 20 |
| 25 ₪ | `com.adl.shareflow.tier_25` | ShareFlow Tier 25 |
| 30 ₪ | `com.adl.shareflow.tier_30` | ShareFlow Tier 30 |
| 35 ₪ | `com.adl.shareflow.tier_35` | ShareFlow Tier 35 |
| 45 ₪ | `com.adl.shareflow.tier_45` | ShareFlow Tier 45 |
| 49 ₪ | `com.adl.shareflow.tier_49` | ShareFlow Tier 49 |
| 69 ₪ | `com.adl.shareflow.tier_69` | ShareFlow Tier 69 |
| 79 ₪ | `com.adl.shareflow.tier_79` | ShareFlow Tier 79 |
| 89 ₪ | `com.adl.shareflow.tier_89` | ShareFlow Tier 89 |

`APPLE_SHARED_SECRET` כבר קיים ב־Railway — אין צורך ליצור מחדש אלא אם החלפת סוד.

סמן: `[ ] 12 מוצרים נוצרו ב־ASC`

---

## 4) הסכמים וכסף

App Store Connect → **Business / Agreements, Tax, and Banking**:

- [ ] Paid Apps / IAP agreement פעיל
- [ ] מס (Tax) הושלם
- [ ] בנקאות הושלמה

בלי זה אי אפשר לפרסם מוצרים בתשלום (גם אם בשרת `PAYMENTS_ENABLED=false` בינתיים).

---

## 5) חשבון דמו לסוקר

צור משתמש ייעודי באפליקציה (הרשמה רגילה), למשל:

- אימייל: `review@adlprojects.co.il` (או אימייל שאתה שולט בו)
- סיסמה חזקה שמורה במנהל סיסמאות
- הוסף לקבוצת דמו עם כמה הוצאות לדוגמה

הדבק ב־App Review Information ב־ASC + העתק ל־`docs/APP_STORE_LISTING_IOS.md` בסעיף «הערות לסוקר».

סמן: `[ ] חשבון דמו מוכן וממולא ב־ASC`

---

## 6) מה לא לעשות עדיין

- לא לבנות / לא להעלות IPA סופי
- לא לשייך build לגרסה וללחוץ Submit
- לא לכבות `PILOT_MODE` / לא להדליק `PAYMENTS_ENABLED` עד יום ההשקה

---

## אחרי שכל הסעיפים מסומנים

יום ההעלאה = רק:

```bash
./scripts/verify_ios_store_prep.sh
./build_release.sh ios
# העלאה ב-Transporter / Xcode → TestFlight עשן → Submit
```
