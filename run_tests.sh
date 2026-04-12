#!/usr/bin/env zsh
# ADL ShareFlow — Test Runner
set -e

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[Tests]${NC} $1"; }
ok()  { echo -e "${GREEN}✓${NC} $1"; }

BACKEND_DIR="$(cd "$(dirname "$0")/backend" && pwd)"

log "Setting up test database..."
dropdb -U adl shareflow_test 2>/dev/null || true
createdb -U adl shareflow_test

log "Running backend tests..."
cd "$BACKEND_DIR"
source venv/bin/activate

TEST_DATABASE_URL="postgresql://adl@localhost:5432/shareflow_test" \
  python -m pytest tests/ -v "$@"

echo ""
ok "All tests complete!"
