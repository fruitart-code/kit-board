#!/usr/bin/env bash
# Copy 6 workflow files to target repo
set -euo pipefail

echo "🔄 Installing workflows..."

mkdir -p "$TARGET_DIR/.github/workflows"

WORKFLOWS=(
  "issue-automation.yml"
  "board-automation.yml"
  "board-sanity.yml"
  "docs-change-watcher.yml"
  "cycle-time-metrics.yml"
  "dependency-graph.yml"
)

for wf in "${WORKFLOWS[@]}"; do
  src="$KIT_DIR/templates/.github/workflows/$wf"
  dst="$TARGET_DIR/.github/workflows/$wf"
  if [ -f "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      echo "  ✓ $wf — unchanged"
    else
      cp "$src" "$dst"
      echo "  ↻ $wf — updated"
    fi
  else
    cp "$src" "$dst"
    echo "  + $wf — installed"
  fi
done

echo "✅ Workflows installed"
