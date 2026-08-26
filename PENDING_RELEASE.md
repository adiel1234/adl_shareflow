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
| **גרסה קודמת (`+70`)** | יעד קודם · לא הופצה כבילד סופי לחנויות |
| **מצב נוכחי** | **יעד בניה מעודכן** · כולל OAuth + תשתית חנות + תשלום חלקי + ניסוח משתתפים · ארטיפקטי ניסוי מוכנים מקומית |
| **HEAD מקומי** | יעודכן אחרי קומיט + push |

### כלל ברזל

1. הגרסה לבניה לחנויות אחרי הפיילוט היא **`1.0.9+71`** (אחרי bump מ־`+70` בגלל תיקוני מוצר).
2. אם יתווסף תיקון קוד לפני החנויות — bump נוסף ועדכון המסמך הזה.
3. מדריכי ההתקנה החיים (פיילוט) נשארים על build שכבר הופץ למשתתפים עד הפצה רשמית של `+71`.

### בדיקה לפני כל בניה

```bash
cd /path/to/ADL\ ShareFlow
git checkout main && git pull
grep '^version:' mobile/pubspec.yaml          # חייב: 1.0.9+71
git status --porcelain                        # חייב: ריק
```

---

## מה נכנס ל־`+71` (חדש)

### תשלום חלקי / כמה אישורים
- מסך תשלום: שדה «סכום לתשלום» עם ברירת מחדל = מלוא היתרה
- תצוגה «שולם X מתוך Y» כשיש pending לאותו זוג
- אפשר תמיד לשלוח תשלומים נוספים; כל pending מאושר בנפרד אצל המקבל
- חובות תקופתיים: עמודה `amount_paid` + סימון חלקי ב־`mark-paid`

### ניסוח
- `tipParticipantsEqualSplit`: «מי משתתף בחלוקה? סמנו, והסכום יתחלק שווה ביניהם.»

---

## מה נכנס ל־`+70` (נשאר בתוקף בתוך `+71`)

### התחברות / הרשמה
- Google Sign-In ו־Sign in with Apple
- תצורת iOS + אימות Google מרובה-audience בשרת
- מסך כניסה מפושט

### מ־`+69` / `+67`/`+68`
- בחירת מטבע, צור קשר, תאריך הוצאה, סדר הוצאות
- המרת מטבע לפי תאריך + הזמנות WhatsApp/קישור/QR/מייל/קוד

---

## מצב ייצור עד סוף הפיילוט (28.8)

| דגל | ערך |
|-----|-----|
| `PAYMENTS_ENABLED` | `false` |
| `PILOT_MODE_ENABLED` | `true` |

---

## ממתין (לא בקומיט) — 26.8.2026 · HEAD `0ee2271` · יעד `1.0.9+71`

לא נכנס לבילד מופץ עדיין.

### שכבה A — קוד אפליקציה (ייכנס ל־IPA/APK של `+71`)
- `login_screen.dart` / `register_screen.dart` / `social_auth.dart`
- `GoogleService-Info.plist` · `Info.plist` · `Runner.entitlements`
- `app_constants.dart` · l10n (כולל `loginSubtitle`, `tipParticipantsEqualSplit`, `paidOfTotal`)
- `screenshot_mode.dart` · שינויי FCM/onboarding לצילומים (פעילים רק עם `SCREENSHOT_*`)
- `payment_options_screen.dart` · `balances_screen.dart` · `payment_scenario_labels.dart`
- `period_report_model.dart` · `group_repository.dart`
- `pubspec.yaml` → `1.0.9+71`

### שכבה B — שרת / תשתית חנות (לא חלק מ־IPA)
- `backend/app/auth/service.py` (אימות Google מרובה-audience)
- `backend/app/models.py` · `backend/app/groups/routes.py` (תשלום חלקי לחוב תקופתי)
- migration: `c3d4e5f6a7b8_add_period_debt_amount_paid.py`
- דף `/support` + מטא־דאטה ASC / IAP / צילומי 6.9" / מדריכי Play
- **Play AAB תשתית** (24.8, עדיין על תוכן `+70`): `store/android/builds/shareflow-1.0.9+70-INTERNAL-INFRA-NOT-FINAL.aab` — בדיקה פנימית בלבד

**חסר להפצה:** קומיט + push · Deploy שרת + הרצת migration · העלאת AAB לבדיקה סגורה · העלאת IPA ל־TestFlight · אימות OAuth ותשלום חלקי על מכשיר.

### ארטיפקטים מוכנים מקומית (26.8 · build `71`)
- iPhone (פיתוח): הותקן והופעל `1.0.9 (71)` על המכשיר המחובר
- Play בדיקה סגורה: `store/android/builds/shareflow-1.0.9+71-CLOSED-TESTING.aab`
- TestFlight: `store/ios/builds/shareflow-1.0.9+71-TESTFLIGHT.ipa`
