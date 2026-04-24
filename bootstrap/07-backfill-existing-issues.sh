#!/usr/bin/env bash
# Optionally trigger backfill workflow for existing open issues.
set -euo pipefail

echo "🔄 Backfill existing open issues?"
echo ""
echo "If the target repo already has open issues, this step triggers"
echo "the issue-automation workflow to populate fields (role/stage from"
echo "labels, urgency, action, etc.) for each of them."
echo ""
echo "Note: only works if .github/workflows/issue-automation.yml is"
echo "already committed to the default branch. If not — skip now and"
echo "run later: gh workflow run issue-automation.yml --ref main"
echo ""

OPEN_COUNT=$(gh issue list --repo "$TARGET_REPO" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
echo "  Open issues in target repo: $OPEN_COUNT"

if [ "$OPEN_COUNT" -eq 0 ]; then
  echo "  ✓ No issues to backfill — skipping"
  exit 0
fi

read -p "Trigger backfill now? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipped. Can trigger manually later:"
  echo "  cd $TARGET_DIR && gh workflow run issue-automation.yml"
  exit 0
fi

# Check that workflow exists on default branch
DEFAULT_BRANCH=$(gh api "repos/$TARGET_REPO" --jq .default_branch 2>/dev/null || echo "main")
if ! gh workflow list --repo "$TARGET_REPO" 2>/dev/null | grep -q "issue-automation"; then
  echo "⚠️  issue-automation.yml not yet committed to $DEFAULT_BRANCH on $TARGET_REPO"
  echo "   Commit first: cd $TARGET_DIR && git add .github && git commit -m '...' && git push"
  echo "   Then run:     gh workflow run issue-automation.yml --ref $DEFAULT_BRANCH"
  exit 0
fi

echo "  Triggering workflow_dispatch..."
gh workflow run issue-automation.yml --repo "$TARGET_REPO" --ref "$DEFAULT_BRANCH"
echo "  ✓ triggered — poll status with: gh run list --repo $TARGET_REPO --workflow=issue-automation.yml"

echo ""
echo "✅ Backfill step done"
