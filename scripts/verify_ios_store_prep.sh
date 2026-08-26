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
[[ "$VER" == "1.0.9+70" ]] && ok "pubspec matches locked target 1.0.9+70" || bad "pubspec is $VER (expected 1.0.9+70 unless intentionally bumped)"

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

SUPPORT_URL="$(tr -d '\n' < "$ROOT/store/ios/metadata/en-US/support_url.txt")"
code="$(curl -sS -o /dev/null -w '%{http_code}' "$SUPPORT_URL")"
[[ "$code" == "200" ]] && ok "Support URL HTTP 200 ($SUPPORT_URL)" || bad "Support URL HTTP $code ($SUPPORT_URL)"

code="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/getting-started")"
[[ "$code" == "200" ]] && ok "/getting-started HTTP 200" || bad "/getting-started HTTP $code"

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

# --- Screenshot drafts (6.9" required class) ---
SS="$ROOT/store/ios/screenshots"
ALLOWED='1320x2868 1290x2796 1260x2736'
SS_OK=1
for f in 01_home.png 02_expenses.png 03_balances.png 04_invite.png; do
  if [[ ! -f "$SS/$f" ]]; then
    bad "screenshot missing: $f"
    SS_OK=0
    continue
  fi
  wh="$(sips -g pixelWidth -g pixelHeight "$SS/$f" 2>/dev/null | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')"
  if echo " $ALLOWED " | grep -q " $wh "; then
    ok "screenshot $f ($wh)"
  else
    bad "screenshot $f is $wh — need 6.9\" (1320×2868 / 1290×2796 / 1260×2736)"
    SS_OK=0
  fi
done
[[ "$SS_OK" -eq 1 ]] || echo "  tip: ./scripts/capture_store_screenshots.sh  (uses iPhone 17 Pro Max)"

# --- Metadata + IAP paste packs ---
[[ -f "$ROOT/store/ios/metadata/he-IL/description.txt" ]] && ok "metadata he-IL pack" || bad "metadata he-IL missing"
[[ -f "$ROOT/store/ios/metadata/en-US/description.txt" ]] && ok "metadata en-US pack" || bad "metadata en-US missing"
[[ -f "$ROOT/store/ios/iap/products.tsv" ]] && ok "IAP products.tsv" || bad "IAP products.tsv missing"
if grep -q $'\tconsumable\t' "$ROOT/store/ios/iap/products.tsv" \
  && ! grep -q $'\tnon_consumable\t' "$ROOT/store/ios/iap/products.tsv"; then
  ok "IAP type is consumable (matches buyConsumable)"
else
  bad "IAP products.tsv must be consumable — code uses buyConsumable"
fi
[[ -f "$ROOT/docs/ASC_AGE_RATING.md" ]] && ok "ASC_AGE_RATING.md" || bad "age rating answers missing"
[[ -f "$ROOT/docs/ASC_APP_PRIVACY_ANSWERS.md" ]] && ok "ASC_APP_PRIVACY_ANSWERS.md" || bad "privacy answers missing"
[[ -f "$ROOT/store/ios/review_notes.txt" ]] && ok "review_notes.txt" || bad "review_notes.txt missing"

echo ""
echo "Manual ASC items (not auto-verified) — see docs/ASC_MANUAL_CHECKLIST.md:"
echo "  [ ] Listing metadata (copy from store/ios/metadata)"
echo "  [ ] App Privacy (copy from docs/ASC_APP_PRIVACY_ANSWERS.md)"
echo "  [ ] Upload screenshots from store/ios/screenshots → ASC 6.9\""
echo "  [ ] 12 IAP products (store/ios/iap/products.tsv)"
echo "  [ ] Tax/banking/agreements"
echo "  [ ] Paste demo login from .store_review_account.local into ASC"
echo "  track locally: cp docs/ASC_STATUS_TEMPLATE.md STORE_PREP_ASC_STATUS.local.md"
echo ""

# Demo account login (if local creds exist)
CREDS="$ROOT/.store_review_account.local"
if [[ -f "$CREDS" ]]; then
  if python3 - "$CREDS" <<'PY'
import json,sys,urllib.request
creds=json.load(open(sys.argv[1]))
body=json.dumps({"email":creds["email"],"password":creds["password"]}).encode()
req=urllib.request.Request(
  "https://adlshareflow-production.up.railway.app/api/auth/login",
  data=body, headers={"Content-Type":"application/json"}, method="POST")
with urllib.request.urlopen(req, timeout=30) as r:
  d=json.load(r)
assert d.get("success") or d.get("data",{}).get("access_token")
print("demo_login_ok")
PY
  then ok "App Review demo account login works"
  else bad "App Review demo account login failed"
  fi
else
  bad "missing .store_review_account.local — run: cd backend && python scripts/setup_app_review_demo.py"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
