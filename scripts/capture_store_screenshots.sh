#!/usr/bin/env zsh
# Capture App Store screenshots on iOS Simulator (NOT a store IPA upload).
# Usage: ./scripts/capture_store_screenshots.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CREDS="$ROOT/.store_review_account.local"
OUT="$ROOT/store/ios/screenshots"
SIM_NAME="iPhone 17"

if [[ ! -f "$CREDS" ]]; then
  echo "Missing $CREDS — run: cd backend && python scripts/setup_app_review_demo.py"
  exit 1
fi

EMAIL="$(python3 -c "import json;print(json.load(open('$CREDS'))['email'])")"
PASS="$(python3 -c "import json;print(json.load(open('$CREDS'))['password'])")"
GROUP_ID="$(python3 -c "import json;print(json.load(open('$CREDS'))['group_id'])")"
mkdir -p "$OUT"

echo "Booting simulator: $SIM_NAME"
xcrun simctl boot "$SIM_NAME" 2>/dev/null || true
open -a Simulator
sleep 5
UDID="$(python3 - <<'PY'
import subprocess,re
out=subprocess.check_output(['xcrun','simctl','list','devices','booted'], text=True)
m=re.search(r'iPhone[^\n]*\(([0-9A-F-]{36})\)', out)
print(m.group(1) if m else '')
PY
)"
if [[ -z "$UDID" ]]; then
  echo "No booted iPhone simulator"
  exit 1
fi
echo "UDID=$UDID group=$GROUP_ID"

capture_scene() {
  local scene="$1"
  local file="$2"
  local settle="${3:-15}"
  local log="/tmp/sf_screenshot_${scene}.log"
  echo ""
  echo "=== Scene: $scene → $file ==="
  pkill -f "flutter run" 2>/dev/null || true
  sleep 2
  : > "$log"
  cd "$ROOT/mobile"
  flutter run \
    -d "$UDID" \
    --dart-define=FLAVOR=prod \
    --dart-define=SCREENSHOT_EMAIL="$EMAIL" \
    --dart-define=SCREENSHOT_PASSWORD="$PASS" \
    --dart-define=SCREENSHOT_GROUP_ID="$GROUP_ID" \
    --dart-define=SCREENSHOT_SCENE="$scene" \
    >>"$log" 2>&1 &
  local pid=$!
  local ready=0
  for i in $(seq 1 120); do
    if rg -q "Flutter run key commands" "$log" 2>/dev/null; then
      ready=1
      break
    fi
    if rg -q "Could not build the application|Error launching application|Failed to build iOS app" "$log" 2>/dev/null; then
      echo "Flutter failed"
      tail -50 "$log"
      kill "$pid" 2>/dev/null || true
      return 1
    fi
    sleep 2
  done
  if [[ "$ready" -ne 1 ]]; then
    echo "Timeout waiting for Flutter"
    tail -50 "$log"
    kill "$pid" 2>/dev/null || true
    return 1
  fi
  echo "App running — settle ${settle}s for scene '$scene'"
  sleep "$settle"
  xcrun simctl io "$UDID" screenshot "$OUT/$file"
  echo "Saved $OUT/$file ($(wc -c < "$OUT/$file") bytes)"
  kill "$pid" 2>/dev/null || true
  pkill -f "flutter run" 2>/dev/null || true
  sleep 2
}

capture_scene home "01_home.png" 14
capture_scene expenses "02_expenses.png" 16
capture_scene balances "03_balances.png" 16
capture_scene invite "04_invite.png" 16

echo ""
echo "Done. Review files in $OUT"
ls -la "$OUT"/*.png
