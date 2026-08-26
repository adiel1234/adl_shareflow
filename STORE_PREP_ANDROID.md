# הכנת תשתית Android ל־Google Play — בלי AAB סופי עכשיו

> **מטרה:** כמו iOS — לסגור חשבון, זהות, מטא־דאטה, Data safety ו־IAP כך שביום ההשקה יישארו בעיקר: בניית AAB → העלאה → Internal/Production.  
> **לא לבנות / לא לפרסם AAB לייצור עכשיו** אלא אם יוחלט אחרת.  
> **package name:** `com.adl.shareflow`

עודכן: 23 באוגוסט 2026

**מדריך שלבים:** `docs/PLAY_CONSOLE_MANUAL_CHECKLIST.md`  
**מטא־דאטה (reuse מ־iOS):** `store/ios/metadata/` → יועתק גם ל־`store/android/` בהמשך  
**IAP:** אותם Product ID כמו iOS (`store/ios/iap/products.tsv`, בלי חובת `tier_25`)

---

## עקרון

| עכשיו (תשתית) | ביום ההעלאה |
|---------------|-------------|
| אימות זהות חשבון Play | `./build_release.sh android` (AAB סופי) |
| יצירת אפליקציה + Data safety | העלאה ל־Internal testing ואז Production |
| מטא־דאטה + צילומים | Review |
| מוצרי IAP + פרופיל תשלומים | `PAYMENTS_ENABLED=true` לפי החלטה |
| AAB תשתית ל־Internal (לא סופי) | `store/android/builds/*-INTERNAL-INFRA-NOT-FINAL.aab` |

פיילוט אנדרואיד נשאר על APK ב־`/download` עד השקה בחנות.
