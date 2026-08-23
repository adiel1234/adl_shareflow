#!/usr/bin/env zsh
# =============================================================================
# Verify iOS store infrastructure (no IPA build).
# Usage: ./scripts/verify_ios_store_prep.sh
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="https://adlshareflow-production.up.railway.app"
PASS=0
FAIL=0

ok()  { echo "✓ $1"; PASS=$((PASS+1)); }
bad() { echo "✗ $1"; FAIL=$((FAIL+1)); }

echo "ADL ShareFlow — iOS store prep verification"
echo "Root: $ROOT"
echo ""

# --- Repo artifacts ---
[[ -f "$ROOT/STORE_PREP_IOS.md" ]] && ok "STORE_PREP_IOS.md" || bad "STORE_PREP_IOS.md missing"
[[ -f "$ROOT/docs/APP_STORE_LISTING_IOS.md" ]] && ok "APP_STORE_LISTING_IOS.md" || bad "listing draft missing"
[[ -f "$ROOT/mobile/ios/ExportOptions.plist" ]] && ok "ExportOptions.plist" || bad "ExportOptions.plist missing"
[[ -f "$ROOT/mobile/ios/Runner/PrivacyInfo.xcprivacy" ]] && ok "PrivacyInfo.xcprivacy" || bad "PrivacyInfo missing"

if grep -q 'manageAppVersionAndBuildNumber</key>' "$ROOT/mobile/ios/ExportOptions.plist" \
  && grep -q '<false/>' "$ROOT/mobile/ios/ExportOptions.plist"; then
  ok "ExportOptions keeps pubspec version (manageAppVersionAndBuildNumber=false)"
else
  bad "ExportOptions must set manageAppVersionAndBuildNumber=false"
fi

if grep -q 'PrivacyInfo.xcprivacy in Resources' "$ROOT/mobile/ios/Runner.xcodeproj/project.pbxproj"; then
  ok "PrivacyInfo linked in Xcode resources"
else
  bad "PrivacyInfo not in Xcode project resources"
fi

if grep -q 'export-options-plist' "$ROOT/build_release.sh"; then
  ok "build_release.sh uses ExportOptions"
else
  bad "build_release.sh missing ExportOptions"
fi

VER="$(grep '^version:' "$ROOT/mobile/pubspec.yaml" | awk '{print $2}')"
echo "  pubspec version: $VER"
[[ "$VER" == "1.0.9+69" ]] && ok "pubspec matches locked target 1.0.9+69" || bad "pubspec is $VER (expected 1.0.9+69 unless intentionally bumped)"

# IAP IDs present in Dart
REQUIRED_TIERS=(5 10 15 20 25 30 35 45 49 69 79 89)
for t in "${REQUIRED_TIERS[@]}"; do
  if grep -q "com.adl.shareflow.tier_$t" "$ROOT/mobile/lib/services/iap_service.dart"; then
    ok "IAP product id tier_$t in code"
  else
    bad "missing tier_$t in iap_service.dart"
  fi
done

# --- Live endpoints ---
code="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/privacy")"
[[ "$code" == "200" ]] && ok "/privacy HTTP 200" || bad "/privacy HTTP $code"

code="$(curl -sS -o /tmp/sf_aasa_check.json -w '%{http_code}' "$BASE/.well-known/apple-app-site-association")"
if [[ "$code" == "200" ]] && grep -q '9QP3FZTL8C.com.adl.shareflow' /tmp/sf_aasa_check.json; then
  ok "AASA live with correct appID"
else
  bad "AASA missing or wrong (HTTP $code)"
fi

cfg="$(curl -sS "$BASE/api/config/public")"
echo "  public config: $cfg"
echo "$cfg" | grep -q 'payments_enabled' && ok "/api/config/public reachable" || bad "config public failed"

# --- Railway secrets (presence only; never print values) ---
if command -v railway >/dev/null 2>&1; then
  if RAW="$(cd "$ROOT" && railway variables --json 2>/dev/null)"; then
    echo "$RAW" | python3 -c '
import sys,json
d=json.load(sys.stdin)
def chk(k):
  v=d.get(k)
  return bool(v)
print("APPLE_SHARED_SECRET", "SET" if chk("APPLE_SHARED_SECRET") else "MISSING")
print("TESTFLIGHT_URL", "SET" if chk("TESTFLIGHT_URL") else "MISSING")
print("FIREBASE_CREDENTIALS_JSON", "SET" if chk("FIREBASE_CREDENTIALS_JSON") else "MISSING")
' | while read -r line; do
      k="${line%% *}"; st="${line##* }"
      if [[ "$st" == "SET" ]]; then ok "Railway $k"; else bad "Railway $k $st"; fi
    done
  else
    bad "railway variables --json failed (link project?)"
  fi
else
  bad "railway CLI not installed — skip secret checks"
fi

echo ""
echo "Manual ASC items (not auto-verified) — see STORE_PREP_IOS.md §א:"
echo "  [ ] Listing metadata filled"
echo "  [ ] Screenshots uploaded"
echo "  [ ] All 12 IAP products created in ASC"
echo "  [ ] Tax/banking/agreements active"
echo "  [ ] Reviewer demo account ready"
echo ""
echo "Result: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
