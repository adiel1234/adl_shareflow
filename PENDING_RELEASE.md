# מקור האמת לגרסה — `1.0.9+65`

> אם יש סתירה בין הטלפון / הצ׳אט / הזיכרון לבין המסמך הזה — **רק המסמך + `git` קובעים**.

---

## הזהות של הגרסה (חובה לבניה)

| שדה | ערך מדויק |
|-----|-----------|
| **גרסה לבניה / חנויות / TestFlight** | **`1.0.9+65`** |
| **`mobile/pubspec.yaml` → `version`** | `1.0.9+65` |
| **מספר build** | `65` |
| **שם שיווקי** | 1.0.9 |
| **ענף** | `main` |
| **קומיט התוכן (כל התיקונים)** | **`bcce496`** — *Prepare 1.0.9+65 for store release* |
| **מינימום לבילוי** | כל commit ב־`main` ש־`bcce496` הוא אב שלו, ו־`pubspec` עדיין `1.0.9+65` |
| **גרסה קודמת מופצת** | `1.0.9+64` = `b767ac8` |

### כלל ברזל

1. הגרסה היא **`1.0.9+65`** — זה מה שמופיע ב־App Store Connect / Play / על המכשיר.
2. היא **חייבת** לכלול את קומיט התוכן **`bcce496`** (ומה שאחריו ב־`main` עד tip, כל עוד לא שינינו קוד בלי bump).
3. אם נוספו **תיקוני קוד** אחרי `bcce496` — חובה bump ל־`1.0.9+66` (או יותר) **לפני** בניה לחנויות, ולעדכן מסמך זה.
4. קומיטי תיעוד בלבד אחרי `bcce496` **לא** דורשים bump — עדיין בונים כ־`+65`.

### בדיקה לפני כל בניה

```bash
cd /path/to/ADL\ ShareFlow
git checkout main && git pull
grep '^version:' mobile/pubspec.yaml          # חייב: 1.0.9+65
git merge-base --is-ancestor bcce496 HEAD && echo "OK: bcce496 included"
git status --porcelain                        # חייב: ריק
```

---

## מה נכנס ל־`+65` (אתמול + היום)

טווח: מ־`b767ac8` (`+64`) עד tip של `main` שכולל את `bcce496`.

### באגים / נכונות נתונים
- באג **30 הוצאות** — טעינת כל העמודים
- **אגורות** בתצוגה / העתקה / WhatsApp (לא עיגול לשלם)
- **חלוקה שווה** עם remainder (בלי כשל עם הרבה חברים)
- **סה״כ תקופתי** נכון (לא מערבב עם lifetime)
- פירוט **לפי מטבע** (יתרות + כותרת קבוצה)
- סמל **₪** במקום `ILS`
- שגיאות **הצטרפות** אמיתיות מהשרת

### התראות / הזמנות / אורחים
- **FCM iOS** (AppDelegate + APNs)
- **קישור אורח** בהצטרפות
- **Deep link** join בלי 404

### UX / מובייל
- סיור בית + סיור קבוצה + howto
- יצירת קבוצה → קבוצה + הזמנה; תמחור גלוי
- טאב «מי חייב למי», FAB בהוצאות, באנר תשלום
- **אנדרואיד Safe Area**
- מונה «מציג X הוצאות»
- אייקון בנק נראה

### תשלומים (בקוד; דגל כבוי בפיילוט)
- מיפוי IAP כולל 5/10/25 + הודעות כשל
- אימות Google עם `com.adl.shareflow`
- חיוב יידלק בדשבורד רק בהעלאה לחנויות

### תשתית
- Backend פרוס (Railway) עם התיקונים
- ניקוי נתוני הדמייה מהפיילוט (פעולת DB, לא חלק מה־IPA)

---

## מצב ייצור עד סוף שבוע הבא

| דגל | ערך |
|-----|-----|
| `PAYMENTS_ENABLED` | `false` |
| `PILOT_MODE_ENABLED` | `true` |

---

## בניה לחנויות (סוף שבוע הבא)

```bash
cd mobile
git checkout main && git pull
grep '^version:' pubspec.yaml   # 1.0.9+65
git merge-base --is-ancestor bcce496 HEAD && echo OK

flutter build ipa --release --dart-define=FLAVOR=prod
flutter build appbundle --release --dart-define=FLAVOR=prod
```

אחרי בניה: לרשום כאן תאריך + `git rev-parse --short HEAD` שממנו נבנה.

---

## צ׳קליסט העלאה

1. [ ] `version` = `1.0.9+65` ו־`bcce496` כלול ב־HEAD
2. [ ] working tree ריק
3. [ ] סיום פיילוט: `PILOT_MODE_ENABLED=false`, `PAYMENTS_ENABLED=true`
4. [ ] בניה אחת (IPA + AAB)
5. [ ] Submit + Smoke
