#!/usr/bin/env bash
# Copy 7 workflow files + composite actions to target repo (with placeholder substitution)
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

# Composite actions, на которые ссылаются workflows (через ./.github/actions/...)
# Без рендеринга placeholders — actions резолвят runtime values сами через
# config.yml + GraphQL (см. resolve-board-ids/action.yml).
echo "🔄 Installing composite actions..."
mkdir -p "$TARGET_DIR/.github/actions"

ACTIONS=(
  "resolve-board-ids"
)

for act in "${ACTIONS[@]}"; do
  src_dir="$KIT_DIR/templates/.github/actions/$act"
  dst_dir="$TARGET_DIR/.github/actions/$act"
  if [ ! -d "$src_dir" ]; then
    echo "  ⚠️  action '$act' missing in kit templates — skipping"
    continue
  fi
  mkdir -p "$dst_dir"
  # action.yml через render_template (на случай если в будущем появятся placeholders)
  for f in "$src_dir"/*.yml "$src_dir"/*.yaml; do
    [ -f "$f" ] || continue
    tmp="$(mktemp)"
    render_template "$f" "$tmp"
    dst_file="$dst_dir/$(basename "$f")"
    if [ -f "$dst_file" ] && cmp -s "$tmp" "$dst_file"; then
      echo "  ✓ actions/$act/$(basename "$f") — unchanged"
      rm -f "$tmp"
    elif [ -f "$dst_file" ]; then
      mv "$tmp" "$dst_file"
      echo "  ↻ actions/$act/$(basename "$f") — updated"
    else
      mv "$tmp" "$dst_file"
      echo "  + actions/$act/$(basename "$f") — installed"
    fi
  done
done

echo "✅ Workflows + composite actions installed"
