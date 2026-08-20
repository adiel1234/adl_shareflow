# גרסה `1.0.9+65` — מצב נוכחי

> **עודכן:** 2026-08-21 02:25 (שעון ישראל)  
> **ענף / HEAD:** `main`  
> **pubspec:** `1.0.9+65`  
> **Backend:** פרוס ב־Railway  
> **יעד חנויות:** סוף שבוע הבא — אחרי סיום פיילוט + אימות תיקונים

---

## מצב ייצור (כפי שהוגדר בדשבורד)

| דגל | ערך נוכחי | משמעות |
|-----|-----------|--------|
| `PAYMENTS_ENABLED` | `false` | הפעלת קבוצות בחינם (פיילוט) |
| `PILOT_MODE_ENABLED` | `true` | פיילוט פתוח; הרשמות → `account_mode=pilot` |

הקוד מוכן לחנויות; **ההפעלה בחנויות מתוכננת לסוף שבוע הבא** אחרי סיום הפיילוט (אז: `PAYMENTS_ENABLED=true`, `PILOT_MODE_ENABLED=false`, בניה והעלאה).

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

## צ׳קליסט — סוף שבוע הבא (העלאה לחנויות)

1. [ ] סיום פיילוט + אימות שכל התיקונים יציבים אצל המשתמשים
2. [ ] לוודא מוצרי IAP בחנויות (כולל `tier_5` / `tier_10` / `tier_25` אם חסרים)
3. [ ] בדשבורד: `PAYMENTS_ENABLED=true` + `PILOT_MODE_ENABLED=false`
4. [ ] בניה אחת: IPA + App Bundle (bump build אם יהיו שינויים נוספים השבוע)
5. [ ] Submit ל־App Store / Play + Smoke אחרי העלאה

---

## פקודות אימות

```bash
curl -s https://adlshareflow-production.up.railway.app/api/config/public
grep '^version:' mobile/pubspec.yaml
git rev-parse --short HEAD
```
