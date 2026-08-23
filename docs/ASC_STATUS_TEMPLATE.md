# סטטוס ASC — עותק לעבודה מקומית

> העתק לקובץ `STORE_PREP_ASC_STATUS.local.md` (gitignored) וסמן שם.  
> או סמן כאן אם אתה רוצה לעקוב בריפו (פחות מומלץ לסיסמאות).

תבנית:

```markdown
# ASC status (local)

- [ ] דף מוצר + תיאורים + קישורים
- [ ] App Privacy labels
- [ ] צילומי מסך
- [ ] 12 מוצרי IAP
- [ ] Agreements / Tax / Banking
- [ ] חשבון דמו ממולא ב-ASC (מתוך `.store_review_account.local`)

עודכן: YYYY-MM-DD
```

יצירת חשבון דמו + קבוצה:

```bash
cd backend && python scripts/setup_app_review_demo.py
# → נוצר `.store_review_account.local` בשורש הריפו
```
