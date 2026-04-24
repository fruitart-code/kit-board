#!/usr/bin/env bash
# Copy .github/board/ module to target repo, replace placeholders in config.yml
set -euo pipefail

echo "📦 Installing .github/board/ module..."

mkdir -p "$TARGET_DIR/.github/board/scripts"
mkdir -p "$TARGET_DIR/.github/board/migrations"

# Copy README, USER-GUIDE as-is
cp "$KIT_DIR/templates/.github/board/README.md" "$TARGET_DIR/.github/board/README.md"
cp "$KIT_DIR/templates/.github/board/USER-GUIDE.md" "$TARGET_DIR/.github/board/USER-GUIDE.md"
echo "  + README.md, USER-GUIDE.md"

# Copy scripts (executable)
cp "$KIT_DIR/templates/.github/board/scripts/setup-fields.sh" "$TARGET_DIR/.github/board/scripts/"
cp "$KIT_DIR/templates/.github/board/scripts/backfill.sh" "$TARGET_DIR/.github/board/scripts/"
cp "$KIT_DIR/templates/.github/board/scripts/audit.sh" "$TARGET_DIR/.github/board/scripts/"
chmod +x "$TARGET_DIR/.github/board/scripts/"*.sh
echo "  + scripts/setup-fields.sh, backfill.sh, audit.sh"

# Copy config.yml and replace {{placeholders}} with .env values
python3 - <<PYEOF
import os, re
src = os.path.join(os.environ['KIT_DIR'], 'templates/.github/board/config.yml')
dst = os.path.join(os.environ['TARGET_DIR'], '.github/board/config.yml')

with open(src) as f:
    content = f.read()

replacements = {
    'PROJECT_OWNER':  os.environ['PROJECT_OWNER'],
    'PROJECT_NUMBER': os.environ['PROJECT_NUMBER'],
    'PROJECT_TITLE':  os.environ.get('PROJECT_TITLE', 'Project Board'),
    'BACKEND_USER':   os.environ.get('BACKEND_USER',  os.environ['OPS_USER']),
    'FRONTEND_USER':  os.environ.get('FRONTEND_USER', os.environ['OPS_USER']),
    'AUTH_USER':      os.environ.get('AUTH_USER',     os.environ['OPS_USER']),
    'DATA_USER':      os.environ.get('DATA_USER',     os.environ['OPS_USER']),
    'OPS_USER':       os.environ['OPS_USER'],
    'DOCS_USER':      os.environ.get('DOCS_USER',     os.environ['OPS_USER']),
}
for key, val in replacements.items():
    content = content.replace('{{' + key + '}}', str(val))

# Also strip outer quotes if PROJECT_NUMBER is numeric
content = re.sub(r'number:\s*"(\d+)"', r'number: \1', content)

with open(dst, 'w') as f:
    f.write(content)
print('  + config.yml (placeholders replaced)')
PYEOF

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
