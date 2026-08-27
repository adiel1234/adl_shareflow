# מקור האמת לגרסה — `1.0.9+79`

| שדה | ערך |
|-----|-----------|
| **גרסה** | **`1.0.9+79`** |
| **סיבה** | מהדורה נקייה ל־Closed testing (אחרי מהדורה שבורה עם 0 מכשירים) |
| **הפצה** | **בהעלאה / בפירסום ל־Play Alpha** — שם מהדורה: `1.0.9 (79)` |
| **AAB** | `Desktop/shareflow-1.0.9+79-CLOSED-TESTING.aab` |
| **HEAD** | `04078b5` |
| **עודכן** | `2026-08-27` |

## נכלל ב־79
- `google-services.json` עם SHA-1 האמיתי של Play App Signing (`F1:22:1C:DD…`) + מפתח העלאה
- מופע יחיד של `GoogleSignIn` + hygiene ביציאה/לפני כניסה
- אייקון התראות FCM `@mipmap/launcher_icon`
- בלי לוגים/הודעות דיבאג זמניות

## אחרי שהפרסום מסתיים — חובה לאמת
1. בסיכום המהדורה: **קוד גרסה 79** + App bundle מופיע + **לא** «0 מכשירים»
2. Opt-in עובד: https://play.google.com/apps/testing/com.adl.shareflow → Become a tester
3. התקנה מ־Play → בפרופיל **1.0.9 (79)**
4. Google Sign-In: כניסה → יציאה → כניסה

## ממתין
| נושא | סטטוס |
|------|--------|
| פרסום 79 ב־Play Available | בהעלאה |
| Become a tester / התקנה | ממתין לפרסום |
| אימות Google מ־Play | ממתין |
| WhatsApp לקבוצה | **רק אחרי** אימות Google מ־Play |

טיוטת הודעה מוכנה: `store/android/WHATSAPP_CLOSED_TESTING_MESSAGE.md` (כבר על 79)
מדריך חסימות: `store/android/CLOSED_TESTING_UNBLOCK.md`
