# הכנת תשתית iOS לחנות — בלי בניית גרסה סופית

> **מטרה:** עד סוף הפיילוט (~28.8) התשתית מוכנה כך שביום ההעלאה יישארו רק: bump אם צריך → בניית IPA → העלאה → Submit.  
> **לא לבנות / לא להעלות IPA סופי עכשיו** — אלא אם יוחלט אחרת.  
> **גרסת יעד נעולה:** `1.0.9+70` — ראה `PENDING_RELEASE.md`.

עודכן: 23 באוגוסט 2026

**אימות אוטומטי:** הרץ `./scripts/verify_ios_store_prep.sh`  
**מדריך ASC ידני:** `docs/ASC_MANUAL_CHECKLIST.md`  
**ישיבת מילוי אחת:** `store/ios/ASC_SITTING.html`  
**תוויות פרטיות מוכנות להעתקה:** `docs/ASC_APP_PRIVACY_ANSWERS.md`  
**דירוג גיל:** `docs/ASC_AGE_RATING.md`  
**מטא־דאטה להעתקה/deliver:** `store/ios/metadata/` · IAP: `store/ios/iap/products.tsv`  
**אופציונלי — מפתח API:** `docs/ASC_API_KEY_SETUP.md`  
פריטי ASC **לא** נסגרים בלי פעולה בפורטל (או מפתח API).

---

## עקרון

| עכשיו (תשתית) | ביום ההעלאה (אחרי הפיילוט) |
|---------------|---------------------------|
| מילוי ASC, IAP, צילומים, טקסטים | `flutter build ipa` מגרסת היעד |
| ExportOptions + PrivacyInfo | העלאה ל־App Store Connect |
| סודות / הסכמים / תוויות פרטיות | עשן ב־TestFlight על הבילד הסופי |
| תוכנית יציאת פיילוט | Submit לביקורת (+ דגלי ייצור לפי החלטה) |

---

## א. מה לסגור עכשיו ב־App Store Connect (ידני)

סמן כאן כשנעשה:

### זהות ואפליקציה
- [x] האפליקציה ShareFlow קיימת (`com.adl.shareflow`) — `1.0 Prepare for Submission` · Apple ID `6763933889`
- [x] הסכמי חוזים / מס / בנקאות ב־ASC מעודכנים ופעילים
- [x] Paid Apps / IAP agreement מאושר (גם אם התשלומים עדיין כבויים בשרת)

### דף המוצר (ניתן למלא לפני הבילד)
- [x] שם: ADL ShareFlow (או כפי שאושר)
- [x] כותרת משנה (עד 30 תווים) — HE + EN — לוודא אם כבר מולא
- [x] תיאור מלא — HE + EN
- [x] מילות מפתח
- [x] URL תמיכה: `https://adlshareflow-production.up.railway.app/getting-started` (חי; `/support` אחרי פריסה)
- [x] URL שיווקי: `https://adlshareflow-production.up.railway.app/getting-started`
- [x] URL מדיניות פרטיות: `https://adlshareflow-production.up.railway.app/privacy`
- [x] קטגוריה ראשית: Finance
- [x] דירוג גיל — 4+
- [x] תוויות פרטיות (App Privacy) פורסמו

### צילומי מסך
- [x] העלאה ל־ASC במחלקת **6.9"**
- [x] טיוטות בריפו: `store/ios/screenshots/` (צילום מסימולטור `iPhone 17 Pro Max`)
- [ ] רענון אופציונלי ממכשיר פיזי `+69` אם רוצים מראה «אמיתי» יותר

### In-App Purchases (יצירה עכשיו, הפעלה בשרת אחר כך)
ליצור מוצרי **Consumable** בלבד (הקוד: `buyConsumable`) — מזהים חייבים להתאים ל־`iap_service.dart`:

| מחיר (₪) | Product ID |
|----------|------------|
| 5 | `com.adl.shareflow.tier_5` |
| 10 | `com.adl.shareflow.tier_10` |
| 15 | `com.adl.shareflow.tier_15` |
| 20 | `com.adl.shareflow.tier_20` |
| 25 | `com.adl.shareflow.tier_25` |
| 30 | `com.adl.shareflow.tier_30` |
| 35 | `com.adl.shareflow.tier_35` |
| 45 | `com.adl.shareflow.tier_45` |
| 49 | `com.adl.shareflow.tier_49` |
| 69 | `com.adl.shareflow.tier_69` |
| 79 | `com.adl.shareflow.tier_79` |
| 89 | `com.adl.shareflow.tier_89` |

- [x] Product IDs נדרשים נוצרו ב־ASC (11; בלי `tier_25`)
- [x] App-Specific Shared Secret ב־Railway כ־`APPLE_SHARED_SECRET`
- [ ] לוודא בכל מוצר: Localization + Price + Availability + Review screenshot
- [ ] (אופציונלי) בדיקת Sandbox — אפשר לדחות ליום ההעלאה

### ביקורת
- [x] חשבון דמו לסוקר ממולא ב־App Review Information
- [x] הערות לסוקר נשמרו

---

## ב. מה מוכן / הוכן בריפו (אוטומטי)

- [x] גרסת יעד נעולה: `1.0.9+70` ב־`PENDING_RELEASE.md`
- [x] חתימה / Bundle / Push / Associated Domains (הוכח בפיילוט)
- [x] מדיניות פרטיות חיה: `/privacy` (HTTP 200)
- [x] AASA חי עם `9QP3FZTL8C.com.adl.shareflow` ונתיבי `/join/*`
- [x] `APPLE_SHARED_SECRET` קיים ב־Railway (נוכחות אומתה; לא להדפיס ערך)
- [x] `TESTFLIGHT_URL` + `FIREBASE_CREDENTIALS_JSON` ב־Railway
- [x] `mobile/ios/ExportOptions.plist` — העלאה לחנות בלי ש־ASC תשנה מספר build
- [x] `PrivacyInfo.xcprivacy` מחובר למשאבי Runner
- [x] `build_release.sh ios` משתמש ב־ExportOptions + `FLAVOR=prod`
- [x] טיוטת טקסטים לחנות: `docs/APP_STORE_LISTING_IOS.md`
- [x] סקריפט אימות: `scripts/verify_ios_store_prep.sh`
- [x] סקריפט חשבון דמו לסוקר: `backend/scripts/setup_app_review_demo.py` → `.store_review_account.local`
- [x] מדריך ASC ידני: `docs/ASC_MANUAL_CHECKLIST.md`
- [x] חבילות העתקה: `store/ios/metadata/`, `store/ios/iap/products.tsv`, `store/ios/review_notes.txt`
- [x] צילומי 6.9" ב־`store/ios/screenshots/` + `./scripts/capture_store_screenshots.sh`
- [x] דף תמיכה לחנות: `/support` (+ `./scripts/print_asc_paste_pack.sh`)
- [x] מסמך זה: `STORE_PREP_IOS.md`

---

## ג. תוכנית יציאת פיילוט (לפני Submit אם רוצים מצב «חנויות»)

**חשוב:** `PILOT_MODE_ENABLED=false` (`disable_pilot_mode`) **חוסם** את כל משתמשי `account_mode=pilot` (מבטל refresh tokens).

אפשרויות:

**א — השארה רכה לביקורת:** לשלוח עם `PAYMENTS_ENABLED=false` ו־`PILOT_MODE_ENABLED=true`, ולהסביר לסוקר.

**ב — סיום פיילוט אמיתי:**
1. ליידע משתתפים מראש
2. כיבוי דרך ADL Control / `PUT /api/adl/pilot/mode` עם `enabled=false`
3. משתמשים שנחסמו יכולים **להירשם מחדש** עם אותו אימייל/OAuth → `promote_to_active` ממיר ל־`active`
4. `PAYMENTS_ENABLED=true` — **רק** אחרי שכל 12 מוצרי IAP קיימים ב־ASC + בדיקת Sandbox

---

## ד. יום ההעלאה — רק אלה

```bash
cd /path/to/ADL\ ShareFlow
git checkout main && git pull
grep '^version:' mobile/pubspec.yaml   # חייב להתאים ל-PENDING_RELEASE
git status --porcelain                 # ריק

# בנייה (אחרי שהגרסה הסופית נעולה — כרגע +69 אלא אם bump)
./build_release.sh ios
# או:
# cd mobile && flutter build ipa --release \
#   --dart-define=FLAVOR=prod \
#   --export-options-plist=ios/ExportOptions.plist
```

1. העלאת ה־IPA (Transporter / Xcode / `xcrun altool`)
2. חיבור הבילד לדף האפליקציה ב־ASC
3. עשן ב־TestFlight על הבילד הסופי
4. סנכרון מדריכי התקנה + `APK`/`TESTFLIGHT` לפי כלל הפצה
5. Submit for Review

---

## ה. מה לא לעשות עד סוף הפיילוט

- לא לבנות IPA «סופי» ולהפיץ לכולם (אלא אם באג קריטי)
- לא לעדכן דפי `/getting-started` ל־`+69` לפני שיש הפצה אמיתית
- לא לכבות `PILOT_MODE` בלי המרת משתמשים
- לא להדליק `PAYMENTS_ENABLED` בלי IAP + Shared Secret
