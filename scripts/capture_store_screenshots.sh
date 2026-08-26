#!/usr/bin/env zsh
# Capture App Store screenshots on iOS Simulator (NOT a store IPA upload).
# Usage: ./scripts/capture_store_screenshots.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CREDS="$ROOT/.store_review_account.local"
OUT="$ROOT/store/ios/screenshots"
# 6.9" class (required by ASC): iPhone 17 Pro Max → 1320×2868
SIM_NAME="iPhone 17 Pro Max"

if [[ ! -f "$CREDS" ]]; then
  echo "Missing $CREDS — run: cd backend && python scripts/setup_app_review_demo.py"
  exit 1
fi

EMAIL="$(python3 -c "import json;print(json.load(open('$CREDS'))['email'])")"
PASS="$(python3 -c "import json;print(json.load(open('$CREDS'))['password'])")"
GROUP_ID="$(python3 -c "import json;print(json.load(open('$CREDS'))['group_id'])")"
mkdir -p "$OUT"

echo "Shutting down other sims; booting: $SIM_NAME"
xcrun simctl shutdown all 2>/dev/null || true
xcrun simctl boot "$SIM_NAME" 2>/dev/null || true
open -a Simulator
sleep 6
UDID="$(xcrun simctl list devices booted | sed -n "s/.*${SIM_NAME} *(\\([0-9A-F-]\\{36\\}\\)).*/\\1/p" | head -1)"
if [[ -z "$UDID" ]]; then
  echo "No booted simulator named: $SIM_NAME"
  xcrun simctl list devices available | rg -i "iPhone 17" || true
  exit 1
fi
echo "UDID=$UDID group=$GROUP_ID"
# Avoid system notification permission dialog over screenshots
xcrun simctl privacy "$UDID" grant notifications com.adl.shareflow 2>/dev/null || true
# Fresh install state each capture run (keeps screenshot defines consistent)
xcrun simctl uninstall "$UDID" com.adl.shareflow 2>/dev/null || true

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

capture_scene home "01_home.png" 18
capture_scene expenses "02_expenses.png" 22
capture_scene balances "03_balances.png" 22
capture_scene invite "04_invite.png" 28

echo ""
echo "Validating 6.9\" ASC sizes (1320×2868 / 1290×2796 / 1260×2736)..."
failed=0
for f in "$OUT"/0*.png; do
  wh="$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')"
  case "$wh" in
    1320x2868|1290x2796|1260x2736) echo "  OK $(basename "$f"): $wh" ;;
    *) echo "  BAD $(basename "$f"): $wh"; failed=1 ;;
  esac
done
if [[ "$failed" -ne 0 ]]; then
  echo "Screenshots are not in required 6.9\" class — expected iPhone 17 Pro Max"
  exit 1
fi
echo "All screenshots match ASC 6.9\" class"

echo ""
echo "Done. Review files in $OUT"
ls -la "$OUT"/*.png
