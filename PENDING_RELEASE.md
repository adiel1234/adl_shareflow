# גרסה `1.0.9+65` — מצב נוכחי

> **עודכן:** 2026-08-21 02:20 (שעון ישראל)  
> **ענף / HEAD:** `main` @ `bcce496`  
> **pubspec:** `1.0.9+65`  
> **Backend:** פרוס ב־Railway  

---

## מצב ייצור (כפי שהוגדר בדשבורד)

| דגל | ערך נוכחי | משמעות |
|-----|-----------|--------|
| `PAYMENTS_ENABLED` | `false` | הפעלת קבוצות בחינם (פיילוט) |
| `PILOT_MODE_ENABLED` | `true` | פיילוט פתוח; הרשמות → `account_mode=pilot` |

הקוד מוכן לחנויות; **ההפעלה בחנויות תיעשה רק כשתהיה מוכן סופית** (אז: `PAYMENTS_ENABLED=true`, `PILOT_MODE_ENABLED=false`, בניה והעלאה).

---

## מה כלול ב־`+65` (כבר בשרת + בקוד)

| נושא | סטטוס |
|------|--------|
| ניקוי נתוני הדמייה/עומס מהפיילוט | ✅ |
| טעינת כל עמודי הוצאות (באג 30) | ✅ |
| עיגול סכומים → אגורות | ✅ |
| חלוקה שווה עם remainder | ✅ |
| FCM iOS / קישור אורח / Safe Area / סיורים | ✅ |
| IAP מוכן בקוד (יופעל רק כש־`PAYMENTS_ENABLED=true`) | ✅ |
| Deploy Railway | ✅ |

---

## לפני העלאה לחנויות (מאוחר יותר)

1. לוודא מוצרי IAP בחנויות (כולל `tier_5` / `tier_10` / `tier_25` אם חסרים)
2. `PAYMENTS_ENABLED=true` + `PILOT_MODE_ENABLED=false` בדשבורד
3. בניה אחת: IPA + App Bundle מ־`1.0.9+65` (או bump אם יהיו שינויים נוספים)
4. Submit ל־App Store / Play

---

## פקודות אימות

```bash
curl -s https://adlshareflow-production.up.railway.app/api/config/public
grep '^version:' mobile/pubspec.yaml
git rev-parse --short HEAD
```
