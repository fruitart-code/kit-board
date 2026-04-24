#!/usr/bin/env bash
# ==============================================================================
# kit-board — uninstall.sh
#
# Удаляет все артефакты kit-board из target repo.
# Спрашивает подтверждение перед каждым destructive шагом.
# ==============================================================================

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 /path/to/target-repo" >&2
  exit 1
fi

TARGET_DIR="$1"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$KIT_DIR"

if [ -f .env ]; then
  source .env
else
  echo "⚠️  .env not found — some operations (label delete by API) will be skipped"
  TARGET_REPO=""
  PROJECT_OWNER=""
  PROJECT_NUMBER=""
fi
export TARGET_REPO PROJECT_OWNER PROJECT_NUMBER

echo "⚠️  kit-board uninstall — target: $TARGET_DIR"
echo ""
echo "This will REMOVE:"
echo "  - .github/workflows/{board-automation,issue-automation,board-sanity,docs-change-watcher,cycle-time-metrics,dependency-graph}.yml"
echo "  - .github/ISSUE_TEMPLATE/{task,bug_report,feature_request,found_work}.yml — WARNING: all templates"
echo "  - .github/board/ целиком"
echo ""
echo "And optionally (with extra confirmation):"
echo "  - Labels in $TARGET_REPO"
echo "  - Project v2 custom fields (DATA LOSS!)"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# --- 1. Remove files from target ---
echo ""
echo "━━━ 1. Remove files from target repo ━━━"

FILES_TO_REMOVE=(
  ".github/workflows/issue-automation.yml"
  ".github/workflows/board-sanity.yml"
  ".github/workflows/docs-change-watcher.yml"
  ".github/workflows/cycle-time-metrics.yml"
  ".github/workflows/dependency-graph.yml"
  # board-automation.yml — спорный, был ли он до kit. Не трогаем по умолчанию.
  ".github/ISSUE_TEMPLATE/task.yml"
  ".github/ISSUE_TEMPLATE/bug_report.yml"
  ".github/ISSUE_TEMPLATE/feature_request.yml"
  ".github/ISSUE_TEMPLATE/found_work.yml"
)

for f in "${FILES_TO_REMOVE[@]}"; do
  full="$TARGET_DIR/$f"
  if [ -f "$full" ]; then
    rm "$full"
    echo "  🗑  $f"
  fi
done

if [ -d "$TARGET_DIR/.github/board" ]; then
  rm -rf "$TARGET_DIR/.github/board"
  echo "  🗑  .github/board/ (целиком)"
fi

echo ""
echo "Files removed. Review $TARGET_DIR and commit the deletion:"
echo "  cd $TARGET_DIR && git add -A && git commit -m 'chore(board): uninstall kit-board'"

# --- 2. Labels ---
if [ -n "$TARGET_REPO" ]; then
  echo ""
  echo "━━━ 2. GitHub labels ━━━"
  read -p "Also remove labels role:*/этап:*/blocked/etc from $TARGET_REPO? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    LABELS=(
      "role:backend" "role:frontend" "role:auth" "role:data-migration" "role:ops" "role:docs"
      "этап:0" "этап:1" "этап:2" "этап:3" "этап:4" "этап:5" "этап:6" "этап:none"
      "task" "found-work" "blocked"
      "docs:significant" "docs:trivial"
      "team-sync-overdue" "board-audit" "metrics-report" "dependency-graph"
    )
    for lbl in "${LABELS[@]}"; do
      gh label delete "$lbl" --repo "$TARGET_REPO" --yes 2>/dev/null && echo "  🗑  $lbl" || true
    done
  fi
fi

# --- 3. Project fields (dangerous) ---
if [ -n "$PROJECT_OWNER" ] && [ -n "$PROJECT_NUMBER" ]; then
  echo ""
  echo "━━━ 3. Project v2 custom fields ━━━"
  echo "⚠️  Removing fields will DELETE all field values on all items (DATA LOSS)"
  read -p "Really remove custom fields Этап/Зависит от/Порядок/🤖 Срочность/⏱ Last moved/📋 Действие? [type 'DELETE' to confirm] " confirm
  if [ "$confirm" = "DELETE" ]; then
    FIELDS=("Этап" "Зависит от" "Порядок" "🤖 Срочность" "⏱ Last moved" "📋 Действие")
    for fname in "${FIELDS[@]}"; do
      FID=$(gh api graphql -f query='
query { organization(login: "'"$PROJECT_OWNER"'") { projectV2(number: '"$PROJECT_NUMBER"') {
  fields(first: 50) { nodes { ... on ProjectV2FieldCommon { id name } } }
}}}' 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
for f in d['data']['organization']['projectV2']['fields']['nodes']:
    if f.get('name') == '$fname':
        print(f['id']); break
" 2>/dev/null || echo "")
      if [ -n "$FID" ]; then
        gh api graphql -f query='mutation { deleteProjectV2Field(input: {fieldId: "'"$FID"'"}) { projectV2Field { ... on ProjectV2FieldCommon { name } } } }' >/dev/null 2>&1 && echo "  🗑  $fname" || echo "  ⚠️  $fname — failed (may be protected)"
      fi
    done
  else
    echo "Skipped (did not type 'DELETE')"
  fi
fi

echo ""
echo "✅ kit-board uninstall complete."
echo ""
echo "Notes:"
echo "  - Project v2 itself NOT removed (delete manually via UI → Project Settings → Delete)"
echo "  - board-automation.yml left intact (was baseline before kit install)"
echo "  - Existing issue data preserved"
