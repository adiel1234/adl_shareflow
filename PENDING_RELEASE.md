# מקור האמת לגרסה — `1.0.9+79`

| שדה | ערך |
|-----|-----------|
| **גרסה** | **`1.0.9+79`** |
| **סיבה** | מהדורה נקייה להעלאה מחדש ל־Closed testing (78 לא הופיעה כראוי בחנות / מהדורה עם 0 מכשירים) |
| **הפצה** | AAB ל־Play Alpha — שם מהדורה חובה: `1.0.9 (79)` |
| **עודכן** | `2026-08-27` |
| **HEAD** | `d673f42` |

## נכלל ב־79
- `google-services.json` עם SHA-1 האמיתי של Play App Signing (`F1:22:1C:DD…`) + מפתח העלאה
- מופע יחיד של `GoogleSignIn` + hygiene ביציאה/לפני כניסה
- אייקון התראות FCM `@mipmap/launcher_icon`
- בלי לוגים/הודעות דיבאג זמניות

## הוראות העלאה (חשוב)
1. Play Console → Closed testing → **יצירת מהדורה חדשה**
2. העלה: `shareflow-1.0.9+79-CLOSED-TESTING.aab` מהשולחן
3. שם המהדורה: **`1.0.9 (79)`** (לא 72)
4. אחרי העלאה ודא בסיכום: **קוד גרסה 78→79**, App bundle מופיע, **לא** «0 מכשירים»
5. הפץ לבודקים / Send for review

ראה גם: `store/android/CLOSED_TESTING_UNBLOCK.md`

## ממתין
- העלאה תקינה ל־Play + Become a tester עובד
- אימות Google Sign-In מ־Play
- WhatsApp לקבוצה
