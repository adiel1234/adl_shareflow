#!/usr/bin/env zsh
# =============================================================
# ADL ShareFlow — Deploy to External Server (ThinkPad)
# =============================================================
# הפעלה: ./deploy.sh
# מבצע: git push + ייצוא DB + עדכון השרת החיצוני
# =============================================================

# -----------------------------------------------
# הגדרות שרת (ערוך כאן אם משהו השתנה)
# -----------------------------------------------
SERVER_IP="192.168.68.150"
SERVER_SSH_USER="חינוך"
SERVER_PG_USER="postgres"
SERVER_DB="shareflow"

LOCAL_PG_USER="adl"
LOCAL_DB="shareflow"

DUMP_FILE="/tmp/shareflow_data_$(date +%Y%m%d_%H%M%S).sql"
ROOT="$(cd "$(dirname "$0")" && pwd)"

# -----------------------------------------------
# צבעים
# -----------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()    { echo "${BLUE}ℹ️  $1${NC}" }
log_success() { echo "${GREEN}✅  $1${NC}" }
log_warn()    { echo "${YELLOW}⚠️  $1${NC}" }
log_error()   { echo "${RED}❌  $1${NC}" }

# -----------------------------------------------
# פונקציה: הוראות ידניות (מוגדרת ראשונה)
# -----------------------------------------------
print_manual_db_instructions() {
    echo ""
    log_warn "הוראות לסנכרון DB ידני (בצע ב-ThinkPad):"
    echo ""
    echo "  1. העתק את הקובץ הבא לתיקיית Downloads ב-ThinkPad:"
    echo "     $DUMP_FILE"
    echo ""
    echo "  2. פתח PowerShell כמנהל ב-ThinkPad והרץ:"
    echo '     cd "C:\Users\חינוך\Projects\ADL ShareFlow"'
    echo '     .\scripts\restore_db.ps1'
    echo ""
}

# -----------------------------------------------
# שלב 1: git commit + push
# -----------------------------------------------
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ADL ShareFlow — Deploy to ThinkPad      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

log_info "שלב 1/4 — בדיקת שינויים ב-Git..."
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "  קבצים שהשתנו:"
    git status --short
    echo ""
    read -r "MSG?  הכנס הודעת commit (Enter לדלג): "
    if [[ -n "$MSG" ]]; then
        git add -A
        git commit -m "$MSG"
        log_success "Commit בוצע"
    else
        log_warn "דולג על commit — שינויים לא ישמרו"
    fi
else
    log_info "אין שינויים חדשים ב-Git"
fi

git push origin main
if [[ $? -eq 0 ]]; then
    log_success "קוד עלה ל-GitHub"
else
    log_error "Push נכשל — בדוק חיבור לאינטרנט"
    exit 1
fi

# -----------------------------------------------
# שלב 2: ייצוא DB מהמחשב המקומי
# -----------------------------------------------
echo ""
log_info "שלב 2/4 — ייצוא מסד הנתונים המקומי..."

pg_dump -U "$LOCAL_PG_USER" \
    --data-only \
    --no-owner \
    --disable-triggers \
    -t users \
    -t user_identities \
    -t groups \
    -t group_members \
    -t expenses \
    -t expense_participants \
    -t settlements \
    -t notifications \
    -t receipts \
    -t refresh_tokens \
    "$LOCAL_DB" > "$DUMP_FILE" 2>/dev/null

if [[ $? -eq 0 && -s "$DUMP_FILE" ]]; then
    SIZE=$(du -h "$DUMP_FILE" | cut -f1)
    log_success "DB יוצא → $DUMP_FILE ($SIZE)"
else
    log_error "ייצוא DB נכשל — בדוק ש-PostgreSQL מקומי פועל"
    exit 1
fi

# -----------------------------------------------
# שלב 3: שליחה לשרת ב-SSH
# -----------------------------------------------
echo ""
log_info "שלב 3/4 — מנסה להתחבר ל-$SERVER_IP..."

ssh -o ConnectTimeout=5 -o BatchMode=yes "$SERVER_SSH_USER@$SERVER_IP" "echo ok" > /dev/null 2>&1
SSH_OK=$?

if [[ $SSH_OK -eq 0 ]]; then
    log_success "חיבור SSH הצליח"

    log_info "  מעביר DB dump לשרת..."
    scp "$DUMP_FILE" "$SERVER_SSH_USER@$SERVER_IP:/tmp/shareflow_restore.sql"

    if [[ $? -eq 0 ]]; then
        log_info "  מעדכן קוד ומשחזר DB בשרת..."

        ssh "$SERVER_SSH_USER@$SERVER_IP" powershell -Command "
            Set-Location 'C:\Users\חינוך\Projects\ADL ShareFlow';
            git pull origin main;
            & 'C:\Program Files\PostgreSQL\16\bin\psql.exe' -U $SERVER_PG_USER -d $SERVER_DB -c 'TRUNCATE TABLE refresh_tokens, receipts, notifications, settlements, expense_participants, expenses, group_members, groups, user_identities, users RESTART IDENTITY CASCADE;';
            & 'C:\Program Files\PostgreSQL\16\bin\psql.exe' -U $SERVER_PG_USER -d $SERVER_DB -f '/tmp/shareflow_restore.sql';
            Write-Host 'Deploy complete';
        "
        SSH_DEPLOY_OK=$?
    else
        log_warn "העברת הקובץ נכשלה"
        SSH_DEPLOY_OK=1
    fi
else
    log_warn "SSH לא זמין (יתכן שלא הופעל ב-Windows)"
    SSH_DEPLOY_OK=1
fi

if [[ $SSH_DEPLOY_OK -ne 0 ]]; then
    print_manual_db_instructions
fi

# -----------------------------------------------
# שלב 4: סיכום
# -----------------------------------------------
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  סיכום Deploy                            ║"
echo "╠══════════════════════════════════════════╣"

if [[ $SSH_OK -eq 0 && $SSH_DEPLOY_OK -eq 0 ]]; then
    echo "║  ✅  קוד: עודכן ב-GitHub ובשרת          ║"
    echo "║  ✅  DB:  מסונכרן לשרת                  ║"
else
    echo "║  ✅  קוד: עודכן ב-GitHub                ║"
    echo "║  ⚠️   DB:  דורש סנכרון ידני              ║"
    echo "║       העתק את הקובץ ל-ThinkPad           ║"
fi

echo "╚══════════════════════════════════════════╝"
echo ""

# ניקוי קובץ dump לאחר שעה (ברקע)
( sleep 3600 && rm -f "$DUMP_FILE" ) &
