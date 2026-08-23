# תשובות מוכנות — App Privacy (App Store Connect)

מבוסס על `/privacy` החי (אפריל 2026) + התנהגות האפליקציה.

**Privacy Policy URL:**  
`https://adlshareflow-production.up.railway.app/privacy`

---

## האם האפליקציה אוספת נתונים?

**כן.**

## Tracking

| שאלה | תשובה |
|------|--------|
| האם משתמשים בנתונים ל־Tracking? | **לא** |
| האם מחוברים ל־tracking frameworks של צד ג׳? | **לא** |

---

## סוגי נתונים לסמן

### Contact Info
| שדה | נאסף? | מקושר לזהות? | משמש ל־Tracking? | מטרות |
|-----|--------|---------------|-------------------|--------|
| Name | כן (שם תצוגה) | כן | לא | App Functionality |
| Email Address | כן | כן | לא | App Functionality, Account Management |
| Phone Number | כן (אופציונלי) | כן | לא | App Functionality |

### Financial Info
| שדה | נאסף? | מקושר לזהות? | Tracking? | מטרות |
|-----|--------|---------------|-----------|--------|
| Payment Info | כן — פרטי Bit/PayBox/בנק **בין משתמשים** (לא כרטיס אשראי שלנו) | כן | לא | App Functionality |
| Credit Info / Other financial | לא (אלא אם תוסיפו בעתיד) | — | — | — |

> הערה: תשלומי IAP של Apple לא נשמרים אצלנו כמספרי כרטיס; רק אימות קבלה בשרת כש־`PAYMENTS_ENABLED=true`.

### Identifiers
| שדה | נאסף? | מקושר לזהות? | Tracking? | מטרות |
|-----|--------|---------------|-----------|--------|
| Device ID | כן — FCM / push token | כן (משויך למשתמש) | לא | App Functionality, Notifications |

### User Content
| שדה | נאסף? | מקושר? | Tracking? | מטרות |
|-----|--------|--------|-----------|--------|
| Photos or Videos | כן — תמונות קבלות (אם המשתמש מעלה/סורק) | כן | לא | App Functionality |
| Other User Content | כן — שמות קבוצות, כותרות הוצאות, הערות | כן | לא | App Functionality |

### Usage Data
| שדה | נאסף? | מקושר? | Tracking? | מטרות |
|-----|--------|--------|-----------|--------|
| Product Interaction | חלקית — הוצאות/קבוצות/יתרות כחלק מהשירות | כן | לא | App Functionality |
| Crash / Performance | לא (אין Crashlytics פעיל כרגע) | — | — | — |

### Diagnostics
לא — כל עוד אין Firebase Crashlytics / Analytics פעילים בבילד.

---

## מה לא לסמן (כרגע)

- Location
- Health
- Browsing History
- Purchases history (מעבר ל־IAP של Apple עצמו)
- Advertising Data
- Sensitive Info

---

## אחרי מילוי ב־ASC

סמן ב־`STORE_PREP_ASC_STATUS.local.md`:  
`- [x] App Privacy labels`
