#!/usr/bin/env zsh
# =============================================================
# ADL ShareFlow — One-click launcher
# =============================================================

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$ROOT/backend"
MOBILE="$ROOT/mobile"

# -----------------------------------------------
# הבטח PATH מלא (Homebrew + Flutter) — חיוני כשרצים מ-Finder
# -----------------------------------------------
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"
FLUTTER_BIN="$(which flutter 2>/dev/null || echo '/opt/homebrew/bin/flutter')"

if [[ ! -x "$FLUTTER_BIN" ]]; then
    echo "❌  Flutter לא נמצא. ודא ש-Flutter מותקן ב-PATH"
    exit 1
fi

# -----------------------------------------------
# עצור תהליכים ישנים
# -----------------------------------------------
echo "🔄  עוצר תהליכים ישנים..."
lsof -ti:5050 | xargs kill -9 2>/dev/null
pkill -f "python run.py" 2>/dev/null
sleep 1

# -----------------------------------------------
# הפעל Backend בחלון Terminal נפרד
# -----------------------------------------------
echo "🚀  מפעיל Backend..."
osascript <<EOF
tell application "Terminal"
    activate
    set win to do script "export PATH='/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:\$PATH' && cd '$BACKEND' && source venv/bin/activate && FLASK_APP=run.py flask db upgrade > /dev/null 2>&1 && echo '✅ Backend: http://localhost:5050' && python run.py"
    set custom title of win to "ADL ShareFlow — Backend"
end tell
EOF

# -----------------------------------------------
# המתן שהשרת יעלה
# -----------------------------------------------
echo "⏳  ממתין לBackend..."
for i in {1..25}; do
    if curl -s http://localhost:5050/health > /dev/null 2>&1; then
        echo "✅  Backend מוכן!"
        break
    fi
    printf "."
    sleep 1
done
echo ""

if ! curl -s http://localhost:5050/health > /dev/null 2>&1; then
    echo "❌  Backend לא עלה — בדוק את חלון ה-Terminal שנפתח"
    exit 1
fi

# -----------------------------------------------
# הפעל Flutter ב-Chrome
# -----------------------------------------------
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ADL ShareFlow מופעל                   ║"
echo "║  Backend:  http://localhost:5050        ║"
echo "║  Chrome נפתח אוטומטית...               ║"
echo "║  לעצירה: Ctrl+C                        ║"
echo "╚════════════════════════════════════════╝"
echo ""

cd "$MOBILE"
"$FLUTTER_BIN" run -d chrome --dart-define=FLAVOR=dev
