#!/usr/bin/env bash
# Copy 4 issue templates to target repo (with placeholder substitution)
set -euo pipefail

if ! declare -F render_template >/dev/null; then
  source "$KIT_DIR/lib/render-template.sh"
fi

echo "📄 Installing issue templates..."

mkdir -p "$TARGET_DIR/.github/ISSUE_TEMPLATE"

TEMPLATES=("task.yml" "bug_report.yml" "feature_request.yml" "found_work.yml")

for tpl in "${TEMPLATES[@]}"; do
  src="$KIT_DIR/templates/.github/ISSUE_TEMPLATE/$tpl"
  dst="$TARGET_DIR/.github/ISSUE_TEMPLATE/$tpl"
  tmp="$(mktemp)"
  render_template "$src" "$tmp"
  if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
    echo "  ✓ $tpl — unchanged"
    rm -f "$tmp"
  elif [ -f "$dst" ]; then
    mv "$tmp" "$dst"
    echo "  ↻ $tpl — updated"
  else
    mv "$tmp" "$dst"
    echo "  + $tpl — installed"
  fi
done

echo "✅ Templates installed"
