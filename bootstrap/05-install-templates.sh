#!/usr/bin/env bash
# Copy 4 issue templates to target repo
set -euo pipefail

echo "📄 Installing issue templates..."

mkdir -p "$TARGET_DIR/.github/ISSUE_TEMPLATE"

TEMPLATES=("task.yml" "bug_report.yml" "feature_request.yml" "found_work.yml")

for tpl in "${TEMPLATES[@]}"; do
  src="$KIT_DIR/templates/.github/ISSUE_TEMPLATE/$tpl"
  dst="$TARGET_DIR/.github/ISSUE_TEMPLATE/$tpl"
  if [ -f "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      echo "  ✓ $tpl — unchanged"
    else
      cp "$src" "$dst"
      echo "  ↻ $tpl — updated"
    fi
  else
    cp "$src" "$dst"
    echo "  + $tpl — installed"
  fi
done

echo "✅ Templates installed"
