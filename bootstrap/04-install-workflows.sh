#!/usr/bin/env bash
# Copy 6 workflow files to target repo (with placeholder substitution)
set -euo pipefail

# render_template helper — loaded by install.sh; load standalone if invoked directly
if ! declare -F render_template >/dev/null; then
  source "$KIT_DIR/lib/render-template.sh"
fi

echo "🔄 Installing workflows..."

mkdir -p "$TARGET_DIR/.github/workflows"

WORKFLOWS=(
  "issue-automation.yml"
  "board-automation.yml"
  "board-sanity.yml"
  "docs-change-watcher.yml"
  "cycle-time-metrics.yml"
  "dependency-graph.yml"
  "auto-add-to-project.yml"
)

for wf in "${WORKFLOWS[@]}"; do
  src="$KIT_DIR/templates/.github/workflows/$wf"
  dst="$TARGET_DIR/.github/workflows/$wf"
  tmp="$(mktemp)"
  render_template "$src" "$tmp"
  if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
    echo "  ✓ $wf — unchanged"
    rm -f "$tmp"
  elif [ -f "$dst" ]; then
    mv "$tmp" "$dst"
    echo "  ↻ $wf — updated"
  else
    mv "$tmp" "$dst"
    echo "  + $wf — installed"
  fi
done

echo "✅ Workflows installed"
