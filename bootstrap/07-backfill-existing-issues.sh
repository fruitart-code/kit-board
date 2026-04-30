#!/usr/bin/env bash
# ==============================================================================
# 07-backfill-existing-issues.sh
#
# For repos that already have open issues when kit-board is installed:
#   1. Add every open issue to the Project v2 board (idempotent — skips items
#      that are already attached).
#   2. Run .github/board/scripts/backfill.sh --apply to populate Этап / Зависит
#      от / 📋 Действие / 🤖 Срочность / Status fields on every item.
#
# Why both steps:
#   - GitHub auto-add-to-project workflow only fires on issues.opened. Existing
#     issues never trigger it, so they never reach the board automatically.
#   - The kit-board issue-automation workflow assumes issues are already on
#     the board and only populates fields. Without auto-add, fields never get
#     set because the runner sees no item.
#
# Skipped automatically when there are zero open issues.
# ==============================================================================
set -euo pipefail

OPEN_COUNT=$(gh issue list --repo "$TARGET_REPO" --state open --limit 200 --json number --jq 'length' 2>/dev/null || echo "0")

echo "🔄 Backfilling existing open issues..."
echo "   Repo:   $TARGET_REPO"
echo "   Issues: $OPEN_COUNT open"
echo ""

if [ "$OPEN_COUNT" -eq 0 ]; then
  echo "  ✓ No open issues — nothing to backfill"
  exit 0
fi

# --- 1. Add every issue to the project (idempotent) ---
echo "═══ 1/2  Adding issues to Project v2 ═══"

# Get current items already on the project so we don't re-add them.
CURRENT_ITEMS=$(gh api graphql -f query="
query {
  $OWNER_ENTITY(login: \"$PROJECT_OWNER\") {
    projectV2(number: $PROJECT_NUMBER) {
      items(first: 100) {
        nodes { content { ... on Issue { number } } }
      }
    }
  }
}" --jq ".data.${OWNER_ENTITY}.projectV2.items.nodes[].content.number" 2>/dev/null | sort -u)

ADD_COUNT=0
SKIP_COUNT=0
gh issue list --repo "$TARGET_REPO" --state open --limit 200 --json number,url \
  | python3 -c "
import json, sys
issues = json.load(sys.stdin)
for i in issues:
    print(f\"{i['number']}\t{i['url']}\")
" | while IFS=$'\t' read -r num url; do
  if echo "$CURRENT_ITEMS" | grep -qFx "$num"; then
    SKIP_COUNT=$((SKIP_COUNT+1))
    continue
  fi
  if gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --url "$url" >/dev/null 2>&1; then
    echo "  + #$num added"
    ADD_COUNT=$((ADD_COUNT+1))
  else
    echo "  ⚠️  #$num: failed to add"
  fi
done

# --- 2. Run backfill.sh --apply to populate fields ---
echo ""
echo "═══ 2/2  Populating fields via backfill.sh --apply ═══"

BACKFILL="$TARGET_DIR/.github/board/scripts/backfill.sh"
if [ ! -x "$BACKFILL" ]; then
  echo "⚠️  $BACKFILL not found / not executable — re-run 06-install-board-module.sh"
  exit 0
fi

cd "$TARGET_DIR"
bash "$BACKFILL" --apply

echo ""
echo "✅ Backfill complete."
echo "   Verify via: gh project view $PROJECT_NUMBER --owner $PROJECT_OWNER --web"
