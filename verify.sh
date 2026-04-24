#!/usr/bin/env bash
# ==============================================================================
# kit-board — verify.sh
#
# Проверяет что install прошёл корректно.
# Read-only: никаких изменений не вносит.
#
# Usage:
#   ./verify.sh /path/to/target-repo
# ==============================================================================

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 /path/to/target-repo" >&2
  exit 1
fi

TARGET_DIR="$1"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$KIT_DIR"
source .env
export PROJECT_OWNER PROJECT_NUMBER TARGET_REPO

echo "🔎 kit-board verify — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

FAIL=0
WARN=0

# --- 1. Files in target repo ---
echo "━━━ 1. Files in target repo ━━━"
FILES=(
  ".github/workflows/board-automation.yml"
  ".github/workflows/issue-automation.yml"
  ".github/workflows/board-sanity.yml"
  ".github/workflows/docs-change-watcher.yml"
  ".github/workflows/cycle-time-metrics.yml"
  ".github/workflows/dependency-graph.yml"
  ".github/ISSUE_TEMPLATE/task.yml"
  ".github/ISSUE_TEMPLATE/bug_report.yml"
  ".github/ISSUE_TEMPLATE/feature_request.yml"
  ".github/ISSUE_TEMPLATE/found_work.yml"
  ".github/board/README.md"
  ".github/board/USER-GUIDE.md"
  ".github/board/config.yml"
  ".github/board/scripts/setup-fields.sh"
)
for f in "${FILES[@]}"; do
  if [ -f "$TARGET_DIR/$f" ]; then
    echo "  ✅ $f"
  else
    echo "  ❌ $f — MISSING"
    FAIL=$((FAIL+1))
  fi
done

# --- 2. Placeholders replaced in config.yml ---
echo ""
echo "━━━ 2. Config integrity ━━━"
CONFIG="$TARGET_DIR/.github/board/config.yml"
if [ -f "$CONFIG" ]; then
  if grep -q "{{.*}}" "$CONFIG"; then
    echo "  ❌ config.yml still has unreplaced placeholders:"
    grep -n "{{.*}}" "$CONFIG" | head -5 | sed 's/^/     /'
    FAIL=$((FAIL+1))
  else
    echo "  ✅ config.yml placeholders all replaced"
  fi
else
  echo "  ❌ config.yml not found"
  FAIL=$((FAIL+1))
fi

# --- 3. Labels on GitHub ---
echo ""
echo "━━━ 3. Labels on GitHub ($TARGET_REPO) ━━━"
EXPECTED_LABELS=(
  "role:backend" "role:frontend" "role:auth" "role:data-migration" "role:ops" "role:docs"
  "этап:0" "этап:1" "этап:2" "этап:3" "этап:4" "этап:5" "этап:6" "этап:none"
  "task" "found-work" "blocked"
  "docs:significant" "docs:trivial"
  "team-sync-overdue" "board-audit" "metrics-report" "dependency-graph"
)
ACTUAL_LABELS=$(gh label list --repo "$TARGET_REPO" --limit 200 --json name --jq '.[].name' 2>/dev/null || echo "")
for lbl in "${EXPECTED_LABELS[@]}"; do
  if echo "$ACTUAL_LABELS" | grep -qFx "$lbl"; then
    echo "  ✅ $lbl"
  else
    echo "  ❌ $lbl — MISSING"
    FAIL=$((FAIL+1))
  fi
done

# --- 4. Project v2 fields ---
echo ""
echo "━━━ 4. Project v2 custom fields ━━━"
PROJ_FIELDS=$(gh api graphql -f query='
query {
  organization(login: "'"$PROJECT_OWNER"'") {
    projectV2(number: '"$PROJECT_NUMBER"') {
      fields(first: 50) { nodes { ... on ProjectV2FieldCommon { name } } }
    }
  }
}' 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(f['name'] for f in d['data']['organization']['projectV2']['fields']['nodes']))" 2>/dev/null || echo "")

EXPECTED_FIELDS=("Этап" "Зависит от" "Порядок" "🤖 Срочность" "⏱ Last moved" "📋 Действие")
for fld in "${EXPECTED_FIELDS[@]}"; do
  if echo "$PROJ_FIELDS" | grep -qFx "$fld"; then
    echo "  ✅ $fld"
  else
    echo "  ❌ $fld — MISSING"
    FAIL=$((FAIL+1))
  fi
done

# --- 5. Status has 🚫 Blocked ---
echo ""
echo "━━━ 5. Status field has 🚫 Blocked option ━━━"
STATUS_OPTS=$(gh api graphql -f query='
query {
  organization(login: "'"$PROJECT_OWNER"'") {
    projectV2(number: '"$PROJECT_NUMBER"') {
      fields(first: 50) { nodes { ... on ProjectV2SingleSelectField { name options { name } } } }
    }
  }
}' 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
for f in d['data']['organization']['projectV2']['fields']['nodes']:
    if f.get('name') == 'Status':
        for o in f.get('options', []):
            print(o['name'])
        break
" 2>/dev/null || echo "")

if echo "$STATUS_OPTS" | grep -q "🚫 Blocked"; then
  echo "  ✅ 🚫 Blocked option present"
else
  echo "  ❌ 🚫 Blocked option MISSING — run ./bootstrap/03-create-project-fields.sh"
  FAIL=$((FAIL+1))
fi

# --- 6. Secrets (warn only) ---
echo ""
echo "━━━ 6. GitHub Actions secrets (warnings only) ━━━"
SECRETS=$(gh secret list --repo "$TARGET_REPO" --json name --jq '.[].name' 2>/dev/null || echo "")

if echo "$SECRETS" | grep -qFx "PROJECT_TOKEN"; then
  echo "  ✅ PROJECT_TOKEN set"
else
  echo "  ⚠️  PROJECT_TOKEN not set — workflows will use GITHUB_TOKEN (limited perms)"
  WARN=$((WARN+1))
fi
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  if echo "$SECRETS" | grep -qFx "TELEGRAM_BOT_TOKEN"; then
    echo "  ✅ TELEGRAM_BOT_TOKEN set"
  else
    echo "  ⚠️  TELEGRAM_BOT_TOKEN in .env but not added to repo secrets"
    WARN=$((WARN+1))
  fi
fi

# --- Summary ---
echo ""
echo "════════════════════════════════════════════════════"
if [ $FAIL -eq 0 ]; then
  echo "  ✅ READY TO USE  (warnings: $WARN)"
  echo "════════════════════════════════════════════════════"
  echo ""
  echo "Next: see ACCEPTANCE_CHECKLIST.md → Smoke test"
  exit 0
else
  echo "  ❌ FAILURES: $FAIL   (warnings: $WARN)"
  echo "════════════════════════════════════════════════════"
  echo ""
  echo "See TROUBLESHOOTING.md for resolution."
  exit 1
fi
