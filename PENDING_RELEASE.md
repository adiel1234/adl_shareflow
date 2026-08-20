# מוכנות לחנויות — גרסה `1.0.9+65`

> **עודכן:** 2026-08-21 02:15 (שעון ישראל)  
> **ענף:** `main`  
> **יעד build:** `1.0.9+65` (בניה אחת בסוף — אחרי deploy)

---

## בוצע הערב / מוכן בקוד

| נושא | סטטוס |
|------|--------|
| ניקוי נתוני הדמייה/עומס מפיילוט בייצור | ✅ נמחקו 3 חשבונות דמו + 3 קבוצות + 60 אורחים |
| טעינת כל עמודי הוצאות (באג 30) | ✅ |
| עיגול סכומים → אגורות | ✅ `currency_format.dart` + מסך תשלום |
| חלוקה שווה עם remainder | ✅ backend |
| FCM iOS AppDelegate | ✅ בקוד |
| קישור אורח בהצטרפות | ✅ בקוד |
| אנדרואיד Safe Area | ✅ |
| סיור / howto / UX | ✅ |
| IAP: מוצרי 5/10/25 + הודעות כשל | ✅ בקוד |
| Google Play package name באימות | ✅ תוקן |
| באנר בנק נראה | ✅ |
| שגיאות join אמיתיות | ✅ |
| סה״כ תקופתי נכון | ✅ |
| bump `1.0.9+65` | ✅ pubspec |

---

## חובה לפני Submit לחנויות

### 1. Deploy Backend (Railway)
אחרי `git push` לוודא ש־Railway עלה עם הקומיט החדש.

### 2. דגלי ייצור
| דגל | ערך לחנות |
|-----|-----------|
| `PAYMENTS_ENABLED` | `true` |
| `PILOT_MODE_ENABLED` | `false` (משתמשי פיילוט ייחסמו עד הרשמה מחדש) |

### 3. מוצרי IAP בחנויות (חובה ליצור ידנית)
מזהים ב־`IapService.kPriceToProductId`:

| מחיר | Product ID |
|------|------------|
| 5 | `com.adl.shareflow.tier_5` |
| 10 | `com.adl.shareflow.tier_10` |
| 15 | `com.adl.shareflow.tier_15` |
| 20 | `com.adl.shareflow.tier_20` |
| 25 | `com.adl.shareflow.tier_25` |
| 30 | `com.adl.shareflow.tier_30` |
| 35 | `com.adl.shareflow.tier_35` |
| 45 | `com.adl.shareflow.tier_45` |
| 49 | `com.adl.shareflow.tier_49` |
| 69 | `com.adl.shareflow.tier_69` |
| 79 | `com.adl.shareflow.tier_79` |
| 89 | `com.adl.shareflow.tier_89` |

סוג: **Consumable**.  
סודות שרת: `APPLE_SHARED_SECRET` ✅ קיים · `GOOGLE_PLAY_CREDENTIALS_JSON` ✅ קיים.

### 4. בניית אפליקציה (פעם אחת)
```bash
# אחרי deploy + מוצרי IAP מוכנים
cd mobile
flutter build ipa --release --dart-define=FLAVOR=prod
flutter build appbundle --release --dart-define=FLAVOR=prod
```

### 5. בדיקות Smoke אחרי בילד
- [ ] יצירת קבוצה + הזמנה + אורח + קישור אורח
- [ ] >30 הוצאות מוצגות במלואן
- [ ] תשלום IAP sandbox (הפעלה)
- [ ] פוש iOS בהוצאה חדשה
- [ ] הסדר תשלום עם אגורות (`33.33 ₪`)
- [ ] אנדרואיד — אין חפיפת ניווט

---

## פקודות אימות

```bash
git rev-parse --short HEAD
curl -s https://adlshareflow-production.up.railway.app/api/config/public
grep '^version:' mobile/pubspec.yaml
```
