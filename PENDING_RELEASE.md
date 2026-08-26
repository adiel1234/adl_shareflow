# מקור האמת לגרסה — `1.0.9+71`

> אם יש סתירה בין הטלפון / הצ׳אט / הזיכרון לבין המסמך הזה — **רק המסמך + `git` קובעים**.

---

## הזהות של הגרסה (חובה לבניה)

| שדה | ערך מדויק |
|-----|-----------|
| **גרסה לבניה / חנויות / TestFlight** | **`1.0.9+71`** |
| **`mobile/pubspec.yaml` → `version`** | `1.0.9+71` |
| **מספר build** | `71` |
| **שם שיווקי** | 1.0.9 |
| **ענף** | `main` |
| **HEAD ב־`origin/main`** | `b1251e3` |
| **שרת ייצור** | Deploy אחרי push · migration `c3d4e5f6a7b8` (`amount_paid`) על הראש |
| **מכשיר פיתוח (iPhone)** | הותקן `1.0.9 (71)` |

### כלל ברזל

1. הגרסה לבדיקה סגורה / TestFlight היא **`1.0.9+71`**.
2. אם יתווסף תיקון קוד — bump ועדכון המסמך.
3. מדריכי ההתקנה החיים (פיילוט) נשארים על build שכבר הופץ עד הפצה רשמית חדשה.

### בדיקה לפני כל בניה

```bash
cd /path/to/ADL\ ShareFlow
git checkout main && git pull
grep '^version:' mobile/pubspec.yaml          # חייב: 1.0.9+71
git status --porcelain                        # חייב: ריק (או רק ארטיפקטים מקומיים)
```

---

## מה נכנס ל־`+71`

### תשלום חלקי / כמה אישורים
- שדה «סכום לתשלום» (ברירת מחדל = מלוא היתרה)
- «שולם X מתוך Y» כשיש pending
- כמה pending לאותו זוג; אישור נפרד לכל אחד
- חובות תקופתיים: `amount_paid` + `mark-paid` חלקי

### ניסוח
- `tipParticipantsEqualSplit`: «מי משתתף בחלוקה? סמנו, והסכום יתחלק שווה ביניהם.»

### מ־`+70` (נשאר)
- OAuth Google/Apple + תשתית חנויות

---

## מצב ייצור

| דגל | ערך |
|-----|-----|
| `PAYMENTS_ENABLED` | `false` |
| `PILOT_MODE_ENABLED` | `true` |

---

## ארטיפקטי ניסוי (מקומיים · לא ב־git)

| מסלול | קובץ |
|--------|------|
| Play בדיקה סגורה | `store/android/builds/shareflow-1.0.9+71-CLOSED-TESTING.aab` |
| TestFlight | `store/ios/builds/shareflow-1.0.9+71-TESTFLIGHT.ipa` |

**חסר ידנית:** העלאת AAB לבדיקה סגורה + הזמנת 12 · העלאת IPA ב־Transporter · אימות בנק ב־Play אם עדיין פתוח.
