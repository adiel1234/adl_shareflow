# טבלת מילוי — 11 מוצרי IAP ב־Google Play

> קובץ לעבודה מחוץ לצ׳אט. פתחו בצד ומלאו מוצר־אחר־מוצר.  
> **לא** ליצור `tier_25`.

---

## כללים שזהים לכל 11 המוצרים

| שדה | ערך קבוע |
|-----|----------|
| סוג הרכישה | **קנייה** (לא השכרה) |
| תגי אפשרות רכישה | אפשר להשאיר ריק, או להעתיק את התג מהעמודה בטבלה |
| תוכן דיגיטלי / שירות (אם מופיע באפשרויות מתקדמות) | **שירות** |
| כמויות ומגבלות (אם מופיע) | לא חובה — השאירו כבוי |
| זמינות | **זמין בכל המדינות** (ברירת מחדל של Play) — אל תשנו אלא אם יש סיבה |
| מחיר | הגדירו מחיר בסיס ב־**ILS (₪)** לפי העמודה; Play יחשב מחירים מקומיים לשאר המדינות |
| מסים לפי מדינה | **אל תשנו ידנית** — השאירו את חישוב Play לפי קטגוריית המס שכבר בחרתם במוצר |
| בסוף המסך | **הפעלה** |

### איך להגדיר את המחיר בפועל
1. בסעיף **זמינות ומחירים** לחצו על **הגדרת מחירים** / עריכה.  
2. בחרו עריכה המונית או הגדירו מחיר לישראל ב־₪.  
3. הזינו את הסכום מהטבלה (למשל `5.00` ל־tier_5).  
4. המטבע: **ILS**.  
5. החילו / שמרו.  
6. **הפעלה**.

---

## טבלה ראשית — מה להעתיק לכל מוצר

| # | מזהה המוצר (כבר נוצר) | מזהה אפשרות הרכישה | סוג | תג (אופציונלי) | מחיר ₪ |
|---|------------------------|---------------------|-----|----------------|--------|
| 1 | `com.adl.shareflow.tier_5` | `buy-tier-5` | קנייה | `tier-5` | **5** |
| 2 | `com.adl.shareflow.tier_10` | `buy-tier-10` | קנייה | `tier-10` | **10** |
| 3 | `com.adl.shareflow.tier_15` | `buy-tier-15` | קנייה | `tier-15` | **15** |
| 4 | `com.adl.shareflow.tier_20` | `buy-tier-20` | קנייה | `tier-20` | **20** |
| 5 | `com.adl.shareflow.tier_30` | `buy-tier-30` | קנייה | `tier-30` | **30** |
| 6 | `com.adl.shareflow.tier_35` | `buy-tier-35` | קנייה | `tier-35` | **35** |
| 7 | `com.adl.shareflow.tier_45` | `buy-tier-45` | קנייה | `tier-45` | **45** |
| 8 | `com.adl.shareflow.tier_49` | `buy-tier-49` | קנייה | `tier-49` | **49** |
| 9 | `com.adl.shareflow.tier_69` | `buy-tier-69` | קנייה | `tier-69` | **69** |
| 10 | `com.adl.shareflow.tier_79` | `buy-tier-79` | קנייה | `tier-79` | **79** |
| 11 | `com.adl.shareflow.tier_89` | `buy-tier-89` | קנייה | `tier-89` | **89** |

---

## כרטיס מילוי — מוצר 1 (דוגמה מלאה)

| סעיף | ערך |
|------|-----|
| מזהה אפשרות הרכישה | `buy-tier-5` |
| סוג הרכישה | קנייה |
| תגים | `tier-5` (או ריק) |
| זמינות | כל המדינות — זמין |
| מחיר בסיס | 5 ₪ (ILS) |
| שיעורי מס בעמודת המדינות | לא לגעת |
| פעולה אחרונה | הפעלה |

---

## רשימת סימון

- [ ] tier_5 — ₪5 — `buy-tier-5`
- [ ] tier_10 — ₪10 — `buy-tier-10`
- [ ] tier_15 — ₪15 — `buy-tier-15`
- [ ] tier_20 — ₪20 — `buy-tier-20`
- [ ] tier_30 — ₪30 — `buy-tier-30`
- [ ] tier_35 — ₪35 — `buy-tier-35`
- [ ] tier_45 — ₪45 — `buy-tier-45`
- [ ] tier_49 — ₪49 — `buy-tier-49`
- [ ] tier_69 — ₪69 — `buy-tier-69`
- [ ] tier_79 — ₪79 — `buy-tier-79`
- [ ] tier_89 — ₪89 — `buy-tier-89`

---

## תזכורת לשלבי המוצר (לפני אפשרות הרכישה)

אם עדיין לא נוצרו חלק מהמוצרים — פרטי המוצר:

| מזהה מוצר | שם HE | שם EN | תג מוצר |
|-----------|-------|-------|---------|
| `com.adl.shareflow.tier_5` | ShareFlow — מדרגה 5 ₪ | ShareFlow Tier 5 | `tier-5` |
| `com.adl.shareflow.tier_10` | ShareFlow — מדרגה 10 ₪ | ShareFlow Tier 10 | `tier-10` |
| `com.adl.shareflow.tier_15` | ShareFlow — מדרגה 15 ₪ | ShareFlow Tier 15 | `tier-15` |
| `com.adl.shareflow.tier_20` | ShareFlow — מדרגה 20 ₪ | ShareFlow Tier 20 | `tier-20` |
| `com.adl.shareflow.tier_30` | ShareFlow — מדרגה 30 ₪ | ShareFlow Tier 30 | `tier-30` |
| `com.adl.shareflow.tier_35` | ShareFlow — מדרגה 35 ₪ | ShareFlow Tier 35 | `tier-35` |
| `com.adl.shareflow.tier_45` | ShareFlow — מדרגה 45 ₪ | ShareFlow Tier 45 | `tier-45` |
| `com.adl.shareflow.tier_49` | ShareFlow — מדרגה 49 ₪ | ShareFlow Tier 49 | `tier-49` |
| `com.adl.shareflow.tier_69` | ShareFlow — מדרגה 69 ₪ | ShareFlow Tier 69 | `tier-69` |
| `com.adl.shareflow.tier_79` | ShareFlow — מדרגה 79 ₪ | ShareFlow Tier 79 | `tier-79` |
| `com.adl.shareflow.tier_89` | ShareFlow — מדרגה 89 ₪ | ShareFlow Tier 89 | `tier-89` |

**תיאור HE (לכולם):**  
שדרוג קיבולת או הפעלת קבוצה ב־ShareFlow. רכישה חד־פעמית לפי מדרגת המחיר.

**תיאור EN (לכולם):**  
Group capacity upgrade or activation in ShareFlow. One-time purchase for this price tier.

**מס:** מכירות אפליקציות דיגיטליות · לא tokenized.
