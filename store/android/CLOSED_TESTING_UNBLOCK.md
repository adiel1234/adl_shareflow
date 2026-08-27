# חסימת Closed Testing — «האפליקציה לא זמינה»

> עודכן: 27 אוגוסט 2026 · אחרי בדיקות אוטומטיות מהריפו (בלי גישה ל־Play Console)

## מה כבר אומת מהמחשב ✅

| בדיקה | תוצאה |
|--------|--------|
| `pubspec` | `1.0.9+79` |
| AAB בשולחן / builds | `shareflow-1.0.9+79-CLOSED-TESTING.aab` קיים |
| APK מקומי | `versionCode=78`, חתימת העלאה `07010b12…` |
| `google-services.json` | כולל SHA Play האמיתי `f1221cdd…` + העלאה + Web client |
| קוד Google Sign-In | מופע יחיד + hygiene |
| קישור חנות ציבורי | `…/store/apps/details?id=com.adl.shareflow` → **HTTP 404** (אין listing ציבורי) |
| קישור opt-in | `…/apps/testing/com.adl.shareflow` → מפנה ל־Google Login (תקין ככתובת) |
| `git push` | `main` מעודכן כולל 78 (Railway) |

**מסקנה:** הקוד, ה־SHA והבילד תקינים. החסימה היא **רק במצב מסלול הבדיקה ב־Play Console**.

## למה הקישורים «לא עובדים»

- דף החנות הציבורי **יישאר 404** כל עוד אין Production (וזה תקין לפיילוט).
- קישור הבדיקה מציג «לא זמינה» כש־Closed testing לא פתוח לבודק בפועל.

## צ׳קליסט חובה ב־Play Console (5 דקות)

היכנסו: https://play.google.com/console → ADL ShareFlow

1. **Testing → Closed testing → Releases**
   - [ ] יש release עם version code **78**
   - [ ] סטטוס: **Available to testers** (לא Draft / In review / Rejected)
2. **Testers** (באותו מסלול)
   - [ ] המייל שלכם ברשימה
   - [ ] ליד הרשימה יש **וי** (הרשימה פעילה במסלול)
   - [ ] העתיקו מחדש את **Copy link** מהמסך הזה
3. **Countries / regions** של המסלול
   - [ ] **Israel** מסומן
4. **Publishing overview**
   - [ ] אין שינויים ממתינים בלי **Send for review**
5. בטלפון
   - [ ] אותו חשבון Google כמו ברשימה
   - [ ] הוסרו התקנות USB קודמות של ShareFlow
   - [ ] קישור opt-in → Become a tester → Download on Google Play

## אחרי ש־«Become a tester» עובד

1. עדכון ל־**1.0.9 (79)** מהחנות  
2. בדיקת Google Sign-In (השער האחרון)  
3. שליחת WhatsApp מ־`store/android/WHATSAPP_CLOSED_TESTING_MESSAGE.md`

## מה לא צריך עכשיו

- באמפ ל־79  
- שינוי קישור WhatsApp  
- בנייה מחדש  

הבעיה אינה בבילד.
