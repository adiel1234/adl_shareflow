# Google Play Console — מדריך מההתחלה

> מטרה: לסגור תשתית Play **לפני** סוף הפיילוט, בלי AAB לייצור.  
> בפיילוט אנדרואיד ממשיך ב־APK ישיר.

קישור: [Google Play Console](https://play.google.com/console)

---

## 0) חשבון ואימות זהות (השלב שנתקעתם בו בעבר)

גוגל דורשת אימות זהות לפני יצירת אפליקציות / פרסום. זה נפרד מתשלום ה־$25.

### מה לבחור

| סוג חשבון | מתי | מה גוגל מבקשת בדרך כלל |
|-----------|-----|-------------------------|
| **Personal** | מפתח יחיד בשם פרטי | תעודת זהות / דרכון, סלפי / וידאו קצר, כתובת |
| **Organization** | חברה (למשל ADL Projects) | מסמכי חברה + D-U-N-S (או תהליך אימות ארגון) + נציג מורשה |

ל־ShareFlow כמותג של ADL — **Organization** עדיף אם יש חברה רשומה. אם אין עדיין מסמכים מוכנים — Personal עובד גם כן, ואפשר להעביר אחר כך (תהליך נפרד).

### תשלום חד־פעמי

- דמי רישום מפתח: **$25** (כרטיס אשראי על חשבון Google)
- בלי תשלום + אימות — לא תתקדמו ליצירת אפליקציה מלאה

### בעיות נפוצות בזיהוי (ישראל)

1. **שם לא תואם** — השם בחשבון Google חייב להתאים למסמך (כולל איות באנגלית)
2. **תמונה מטושטשת / חתוכה** — צילום חדות של ת.ז. / דרכון, בלי בוהק
3. **כתובת** — כתובת מגורים תואמת למסמך / חשבון
4. **Organization בלי D-U-N-S** — אם בחרתם ארגון, צריך מספר D-U-N-S (חינם דרך Dun & Bradstreet) או להשלים את מסלול האימות שגוגל מציגה
5. **חשבון Google «הלא נכון»** — היכנסו עם אותו חשבון ששילם / שנרשם כמפתח
6. **דחייה** — אפשר להגיש שוב; קראו את המייל מ־Google בדיוק (מה חסר)

### איך לבדוק איפה אתם עכשיו

1. היכנסו ל־[play.google.com/console](https://play.google.com/console)
2. אם מופיע באנר **Verify your identity** / **Complete account details** — זה השלב הראשון
3. Settings → **Developer account** / **Identity verification** — סטטוס

כתבו כאן מה אתם רואים (או שלחו צילום):
- אין חשבון מפתח בכלל
- שולם $25 אבל Identity Pending / Rejected
- Identity Verified ואפשר ליצור אפליקציה

---

## 1) אחרי שהזהות מאושרת — יצירת אפליקציה

1. **Create app**
2. שם: `ADL ShareFlow`
3. שפת ברירת מחדל: English (United States) או Hebrew
4. סוג: App (לא Game)
5. Free / Paid: לפי מודל (האפליקציה חינמית להורדה + IAP) → בדרך כלל **Free**
6. אישורי הצהרות (Declarations) — סמנו לפי האמת

Package name בבילד חייב להיות בדיוק:
`com.adl.shareflow`

(נקבע ב־`mobile/android` — לא משנים עכשיו.)

---

## 2) Dashboard — משימות חובה לפני Production

סמנו ב־Play Console (Grow / Policy / App content):

- [ ] Privacy policy: `https://adlshareflow-production.up.railway.app/privacy`
- [ ] App access (חשבון דמו לסוקר) — מ־`.store_review_account.local`
- [ ] Ads — האם מציגים מודעות? (ShareFlow: בדרך כלל לא)
- [ ] Content ratings (שאלון IARC)
- [ ] Target audience
- [ ] News app / COVID / Data safety / Government apps — לפי האמת
- [ ] **Data safety** — מקביל ל־App Privacy ב־iOS (פירוט ב־`docs/ASC_APP_PRIVACY_ANSWERS.md` כבסיס)

---

## 3) Store listing

טקסטים מוכנים: `store/ios/metadata/` ו־`docs/APP_STORE_LISTING_IOS.md`

- כותרת קצרה / תיאור מלא — HE + EN
- אייקון 512×512
- Feature graphic 1024×500
- צילומי טלפון (אפשר להתחיל מ־`store/ios/screenshots/` ולחתוך/להתאים לדרישות Play)

---

## 4) מוצרים בתשלום (IAP)

סוג: **Managed product** / Consumable בהתאם לממשק הנוכחי של Play.  
Product ID **זהים ל־iOS**:

| מחיר ₪ | Product ID |
|--------|------------|
| 5 | `com.adl.shareflow.tier_5` |
| 10 | `com.adl.shareflow.tier_10` |
| 15 | `com.adl.shareflow.tier_15` |
| 20 | `com.adl.shareflow.tier_20` |
| 30 | `com.adl.shareflow.tier_30` |
| 35 | `com.adl.shareflow.tier_35` |
| 45 | `com.adl.shareflow.tier_45` |
| 49 | `com.adl.shareflow.tier_49` |
| 69 | `com.adl.shareflow.tier_69` |
| 79 | `com.adl.shareflow.tier_79` |
| 89 | `com.adl.shareflow.tier_89` |

נדרש גם: Payments profile / Merchant (מס + בנק) בחשבון Play.

---

## 5) מה לא לעשות עדיין

- לא להעלות AAB ל־Production
- לא לכבות פיילוט / לא להדליק `PAYMENTS_ENABLED` עד יום ההשקה
- לא לשנות `applicationId` / package name

---

## אחרי שכל הסעיפים מסומנים

יום ההעלאה ≈:

```bash
./scripts/verify_ios_store_prep.sh   # חלק מהבדיקות משותפות
./build_release.sh android
# העלאת AAB → Internal testing → Production
```
