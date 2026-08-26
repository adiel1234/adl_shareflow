#!/usr/bin/env zsh
# Print a single sitting paste-pack for App Store Connect (no secrets in git).
# Usage: ./scripts/print_asc_paste_pack.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="https://adlshareflow-production.up.railway.app"
CREDS="$ROOT/.store_review_account.local"

hr() { printf '\n%s\n' "────────────────────────────────────────"; }

echo "ADL ShareFlow — ASC paste pack"
echo "Open: https://appstoreconnect.apple.com → ShareFlow"
hr
echo "## App Information URLs"
echo "Privacy:   $BASE/privacy"
echo "Support:   $(cat "$ROOT/store/ios/metadata/en-US/support_url.txt")"
echo "Marketing: $(cat "$ROOT/store/ios/metadata/en-US/marketing_url.txt")"
echo "Category:  Finance (or Lifestyle)"
hr
echo "## Name / Subtitle / Keywords — he-IL"
echo "Name:     $(cat "$ROOT/store/ios/metadata/he-IL/name.txt")"
echo "Subtitle: $(cat "$ROOT/store/ios/metadata/he-IL/subtitle.txt")"
echo "Keywords: $(cat "$ROOT/store/ios/metadata/he-IL/keywords.txt")"
hr
echo "## Description — he-IL"
cat "$ROOT/store/ios/metadata/he-IL/description.txt"
hr
echo "## Name / Subtitle / Keywords — en-US"
echo "Name:     $(cat "$ROOT/store/ios/metadata/en-US/name.txt")"
echo "Subtitle: $(cat "$ROOT/store/ios/metadata/en-US/subtitle.txt")"
echo "Keywords: $(cat "$ROOT/store/ios/metadata/en-US/keywords.txt")"
hr
echo "## Description — en-US"
cat "$ROOT/store/ios/metadata/en-US/description.txt"
hr
echo "## Screenshots (upload to 6.9\")"
ls -1 "$ROOT/store/ios/screenshots"/0*.png
hr
echo "## IAP products (Non-Consumable) — create ALL"
column -t -s $'\t' "$ROOT/store/ios/iap/products.tsv" 2>/dev/null || cat "$ROOT/store/ios/iap/products.tsv"
hr
echo "## App Privacy answers"
echo "File: docs/ASC_APP_PRIVACY_ANSWERS.md"
hr
echo "## App Review notes (paste text; password from local file)"
cat "$ROOT/store/ios/review_notes.txt"
if [[ -f "$CREDS" ]]; then
  python3 - <<PY
import json
d=json.load(open("$CREDS"))
print()
print("Demo email:   ", d.get("email"))
print("Demo password:", d.get("password"))
print("Demo group:   ", d.get("group_name"), d.get("group_id"))
PY
else
  echo "(missing .store_review_account.local — run setup_app_review_demo.py)"
fi
hr
echo "## Agreements"
echo "Business → Agreements, Tax, and Banking — Paid Apps / IAP + Tax + Banking"
hr
echo "Track: STORE_PREP_ASC_STATUS.local.md"
echo "Done when every box there is checked — then day-of = IPA only."
