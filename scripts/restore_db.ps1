# =============================================================
# ADL ShareFlow — שחזור DB בשרת (ThinkPad)
# =============================================================
# הפעלה: PowerShell כמנהל
#   cd "C:\Users\chinuch\Projects\ADL ShareFlow"
#   .\scripts\restore_db.ps1
# =============================================================

param(
    [string]$DumpFile = "C:\Users\chinuch\Downloads\shareflow_restore.sql"
)

$PG_BIN = "C:\Program Files\PostgreSQL\16\bin"
$PG_USER = "postgres"
$DB_NAME = "shareflow"

Write-Host ""
Write-Host "=== ADL ShareFlow — שחזור מסד נתונים ===" -ForegroundColor Cyan
Write-Host ""

# --- בדיקת קובץ ---
if (-not (Test-Path $DumpFile)) {
    Write-Host "❌  הקובץ לא נמצא: $DumpFile" -ForegroundColor Red
    Write-Host "   ודא שהעתקת את קובץ ה-dump מהמחשב המקומי"
    exit 1
}

$FileSize = (Get-Item $DumpFile).Length / 1KB
Write-Host "✅  קובץ נמצא: $DumpFile ($([math]::Round($FileSize, 1)) KB)" -ForegroundColor Green

# --- ניקוי טבלאות ---
Write-Host ""
Write-Host "ℹ️  מנקה טבלאות קיימות..." -ForegroundColor Blue

$TruncateSQL = @"
TRUNCATE TABLE refresh_tokens, receipts, notifications, settlements,
               expense_participants, expenses, group_members, groups,
               user_identities, users RESTART IDENTITY CASCADE;
"@

& "$PG_BIN\psql.exe" -U $PG_USER -d $DB_NAME -c $TruncateSQL

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌  ניקוי נכשל — בדוק שה-PostgreSQL פועל" -ForegroundColor Red
    exit 1
}
Write-Host "✅  טבלאות נוקו" -ForegroundColor Green

# --- שחזור נתונים ---
Write-Host ""
Write-Host "ℹ️  משחזר נתונים..." -ForegroundColor Blue

& "$PG_BIN\psql.exe" -U $PG_USER -d $DB_NAME -f $DumpFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌  שחזור נכשל" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅  DB שוחזר בהצלחה!" -ForegroundColor Green
Write-Host ""
Write-Host "  הפעל מחדש את ShareFlow backend:" -ForegroundColor Yellow
Write-Host "  cd backend && venv\Scripts\activate && python run.py"
Write-Host ""
