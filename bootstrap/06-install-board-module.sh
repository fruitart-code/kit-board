#!/usr/bin/env bash
# Copy .github/board/ module to target repo, replacing {{placeholders}}
set -euo pipefail

if ! declare -F render_template >/dev/null; then
  source "$KIT_DIR/lib/render-template.sh"
fi

echo "📦 Installing .github/board/ module..."

mkdir -p "$TARGET_DIR/.github/board/scripts"
mkdir -p "$TARGET_DIR/.github/board/migrations"

# Render README, USER-GUIDE (placeholders replaced — kills hardcoded URLs)
render_template "$KIT_DIR/templates/.github/board/README.md"     "$TARGET_DIR/.github/board/README.md"
render_template "$KIT_DIR/templates/.github/board/USER-GUIDE.md" "$TARGET_DIR/.github/board/USER-GUIDE.md"
echo "  + README.md, USER-GUIDE.md"

# Render scripts (executable; placeholders replaced for runtime queries)
for s in setup-fields.sh backfill.sh audit.sh; do
  render_template "$KIT_DIR/templates/.github/board/scripts/$s" "$TARGET_DIR/.github/board/scripts/$s"
done
chmod +x "$TARGET_DIR/.github/board/scripts/"*.sh
echo "  + scripts/setup-fields.sh, backfill.sh, audit.sh"

# Render config.yml
render_template "$KIT_DIR/templates/.github/board/config.yml" "$TARGET_DIR/.github/board/config.yml"
echo "  + config.yml (placeholders replaced)"

# Initial migration record
cat > "$TARGET_DIR/.github/board/migrations/000-initial-from-kit.md" <<EOF
# Migration 000 — Initial from kit-board

**Дата:** $(date -u +%Y-%m-%d)
**Установщик:** @$OPS_USER
**Источник:** https://github.com/fruitart-code/kit-board
**Статус:** applied

## Что установлено

- 6 workflow файлов в \`.github/workflows/\`
- 4 issue templates в \`.github/ISSUE_TEMPLATE/\`
- \`.github/board/\` модуль (config.yml, README.md, USER-GUIDE.md, scripts/, migrations/)
- 20+ labels в \`$TARGET_REPO\`
- 6 custom Project v2 fields в проекте \`$PROJECT_OWNER/projects/$PROJECT_NUMBER\`
- Status option \`🚫 Blocked\`

## Конфигурация

- \`PROJECT_OWNER\`:  $PROJECT_OWNER
- \`PROJECT_NUMBER\`: $PROJECT_NUMBER
- \`TARGET_REPO\`:    $TARGET_REPO

## Rollback

\`\`\`bash
cd /path/to/kit-board
./uninstall.sh $TARGET_DIR
\`\`\`
EOF
echo "  + migrations/000-initial-from-kit.md"

echo "✅ Board module installed"
