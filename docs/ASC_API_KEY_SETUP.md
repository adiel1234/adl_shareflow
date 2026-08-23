# פתיחת אוטומציה ל־App Store Connect (אופציונלי)

כרגע אין במחשב מפתח API ל־ASC — לכן מילוי מוצרים/מטא־דאטה נעשה ידנית.

אם תיצור מפתח, אפשר יהיה בשלב הבא:
- ליצור/לאמת מוצרי IAP
- להעלות מטא־דאטה מתיקיית `store/ios/`
- לבדוק סטטוס הסכמים

## יצירת מפתח (ב־Apple)

1. [App Store Connect](https://appstoreconnect.apple.com) → Users and Access → Integrations → App Store Connect API  
2. Generate API Key עם הרשאת **App Manager** (או Admin)  
3. הורד את קובץ `AuthKey_XXXXXX.p8` **פעם אחת**  
4. רשום: Key ID, Issuer ID

## שמירה מקומית (לא ב־git)

צור קובץ בשורש הריפו:

`.asc_api.local.json`

```json
{
  "key_id": "XXXXXXXXXX",
  "issuer_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "key_path": "/absolute/path/to/AuthKey_XXXXXX.p8",
  "bundle_id": "com.adl.shareflow"
}
```

הקובץ כבר ב־`.gitignore` דרך דפוס `*.local` / נוסיף במפורש.

אחרי שיש קובץ — כתוב בצ׳אט «יש מפתח ASC» ונמשיך לאוטומציה.
