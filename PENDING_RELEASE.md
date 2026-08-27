# מקור האמת לגרסה — `1.0.9+77`

| שדה | ערך |
|-----|-----------|
| **גרסה** | **`1.0.9+77`** |
| **סיבה** | תיקון Google Sign-In (מופע יחיד) + hygiene + `google-services` עם SHA של Play/העלאה + אייקון התראות FCM |
| **הפצה** | AAB ל־Play Alpha (closed testing) |
| **עודכן** | `2026-08-27` |
| **HEAD** | `7da651a` |

## נכלל ב־77
- מופע יחיד של `GoogleSignIn` (`static final`) — מונע מצב דביק בהחלפת חשבונות
- `prepareGoogleSignIn` במסך כניסה + `signOutGoogle` ביציאה / לפני כניסה
- `google-services.json` עם SHA-1 של Play App Signing + מפתח העלאה + Web client
- אייקון התראות מקומיות: `@mipmap/launcher_icon` (במקום `ic_launcher` החסר)

## ממתין להפצה
- העלאת AAB ל־Play + אימות Google Sign-In על התקנה מהחנות
- `git push` (לפריסת דפי ההתקנה ב־Railway)
- שליחת הודעת WhatsApp (טיוטה מעודכנת ל־77)

## פתוחים
| נושא | סטטוס |
|------|--------|
| אימות Google על חתימת Play אחרי פרסום 77 | ממתין להעלאה + בדיקת בודק |
