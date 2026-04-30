#!/usr/bin/env bash
# Create 6 custom Project v2 fields + 🚫 Blocked status option (idempotent)
set -euo pipefail

echo "📊 Creating Project v2 fields..."

PROJECT_DATA=$(gh api graphql -f query='
query {
  '"$OWNER_ENTITY"'(login: "'"$PROJECT_OWNER"'") {
    projectV2(number: '"$PROJECT_NUMBER"') {
      id
      fields(first: 50) {
        nodes {
          __typename
          ... on ProjectV2Field { id name dataType }
          ... on ProjectV2SingleSelectField { id name dataType options { id name color description } }
        }
      }
    }
  }
}')

PROJECT_ID=$(echo "$PROJECT_DATA" | python3 -c "import json,sys,os; print(json.load(sys.stdin)['data'][os.environ['OWNER_ENTITY']]['projectV2']['id'])")
echo "  Project ID: $PROJECT_ID"

field_id() {
  echo "$PROJECT_DATA" | python3 -c "
import json,sys,os
data = json.load(sys.stdin)
for f in data['data'][os.environ['OWNER_ENTITY']]['projectV2']['fields']['nodes']:
    if f.get('name') == '$1':
        print(f['id']); break
"
}

# Этап — single-select
if [ -z "$(field_id 'Этап')" ]; then
  echo "  + creating Этап (single-select, 8 options)"
  gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\",
    dataType: SINGLE_SELECT,
    name: \"Этап\",
    singleSelectOptions: [
      {name: \"Этап 0\", color: GRAY, description: \"\"},
      {name: \"Этап 1\", color: GRAY, description: \"\"},
      {name: \"Этап 2\", color: GRAY, description: \"\"},
      {name: \"Этап 3\", color: GRAY, description: \"\"},
      {name: \"Этап 4\", color: GRAY, description: \"\"},
      {name: \"Этап 5\", color: GRAY, description: \"\"},
      {name: \"Этап 6\", color: GRAY, description: \"\"},
      {name: \"Вне этапов\", color: GRAY, description: \"\"}
    ]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
}" >/dev/null
  echo "    ✓ created"
else
  echo "  ✓ Этап exists"
fi

# Зависит от — text
if [ -z "$(field_id 'Зависит от')" ] && [ -z "$(field_id 'Depends on')" ]; then
  echo "  + creating Зависит от (text)"
  gh api graphql -f query="
mutation { createProjectV2Field(input: {
  projectId: \"$PROJECT_ID\", dataType: TEXT, name: \"Зависит от\"
}) { projectV2Field { ... on ProjectV2Field { id } } } }" >/dev/null
  echo "    ✓ created"
else
  echo "  ✓ Зависит от / Depends on exists"
fi

# Порядок — number
if [ -z "$(field_id 'Порядок')" ] && [ -z "$(field_id 'Order')" ]; then
  echo "  + creating Порядок (number)"
  gh api graphql -f query="
mutation { createProjectV2Field(input: {
  projectId: \"$PROJECT_ID\", dataType: NUMBER, name: \"Порядок\"
}) { projectV2Field { ... on ProjectV2Field { id } } } }" >/dev/null
  echo "    ✓ created"
else
  echo "  ✓ Порядок / Order exists"
fi

# 🤖 Срочность — single-select
if [ -z "$(field_id '🤖 Срочность')" ] && [ -z "$(field_id 'Срочность')" ]; then
  echo "  + creating 🤖 Срочность (4 options, auto-computed)"
  gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\",
    dataType: SINGLE_SELECT,
    name: \"🤖 Срочность\",
    singleSelectOptions: [
      {name: \"🔥 Горит\",          color: RED,    description: \"Блокирует 2+ задач\"},
      {name: \"⚡ Срочно\",           color: ORANGE, description: \"Блокирует 1\"},
      {name: \"⏳ Обычно\",           color: GRAY,   description: \"По умолчанию\"},
      {name: \"🟢 Может подождать\",  color: GREEN,  description: \"Cross-cutting\"}
    ]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
}" >/dev/null
  echo "    ✓ created"
else
  echo "  ✓ 🤖 Срочность exists"
fi

# ⏱ Last moved — date
if [ -z "$(field_id '⏱ Last moved')" ] && [ -z "$(field_id 'Last moved')" ]; then
  echo "  + creating ⏱ Last moved (date)"
  gh api graphql -f query="
mutation { createProjectV2Field(input: {
  projectId: \"$PROJECT_ID\", dataType: DATE, name: \"⏱ Last moved\"
}) { projectV2Field { ... on ProjectV2Field { id } } } }" >/dev/null
  echo "    ✓ created"
else
  echo "  ✓ ⏱ Last moved exists"
fi

# 📋 Действие — single-select
if [ -z "$(field_id '📋 Действие')" ]; then
  echo "  + creating 📋 Действие (8 options, auto-derived from title)"
  gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\",
    dataType: SINGLE_SELECT,
    name: \"📋 Действие\",
    singleSelectOptions: [
      {name: \"💻 Реализовать\",    color: BLUE,   description: \"feat/refactor/test\"},
      {name: \"🐛 Исправить\",       color: RED,    description: \"fix\"},
      {name: \"📝 Документировать\", color: GRAY,   description: \"docs\"},
      {name: \"⚙️ Настроить\",       color: YELLOW, description: \"ops/chore/auth/data\"},
      {name: \"👀 Ознакомиться\",    color: GRAY,   description: \"team-sync\"},
      {name: \"🔍 Исследовать\",     color: PURPLE, description: \"proposal/research\"},
      {name: \"✅ Ревьюить\",        color: GREEN,  description: \"review\"},
      {name: \"🤝 Согласовать\",     color: ORANGE, description: \"coord\"}
    ]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
}" >/dev/null
  echo "    ✓ created"
else
  echo "  ✓ 📋 Действие exists"
fi

# Status options — kit-board canonical 7-state set
# (📥 Бэклог / 🚫 Blocked / 📋 К работе / 🔨 В работе / 👀 На ревью / ✅ Одобрено / 🏁 Готово)
#
# If the Status field already has these 7 options (or a superset), nothing changes.
# Otherwise the field is updated to match — UpdateProjectV2Field replaces options
# atomically, so item values keyed by option_id are preserved only when the option
# IDs survive. To avoid wiping data, we rewrite ONLY when the canonical options
# are missing AND the project has zero items (fresh install).
#
# For an existing project with item values, we ADD missing canonical options on
# top of whatever already exists — old options stay so item values remain valid.
echo ""
echo "📌 Ensuring Status has kit-board canonical options..."

STATUS_FIELD=$(echo "$PROJECT_DATA" | python3 -c "
import json,sys,os
data = json.load(sys.stdin)
for f in data['data'][os.environ['OWNER_ENTITY']]['projectV2']['fields']['nodes']:
    if f.get('name') == 'Status' and f.get('__typename') == 'ProjectV2SingleSelectField':
        print(json.dumps(f)); break
")

if [ -z "$STATUS_FIELD" ]; then
  echo "  ⚠️  Status field not found — skipping (unusual; check project)"
else
  ITEMS_COUNT=$(gh api graphql -f query="
{ $OWNER_ENTITY(login: \"$PROJECT_OWNER\") { projectV2(number: $PROJECT_NUMBER) { items(first: 1) { totalCount } } } }" \
    --jq ".data.${OWNER_ENTITY}.projectV2.items.totalCount" 2>/dev/null || echo "0")

  STATUS_OPS=$(STATUS_FIELD_JSON="$STATUS_FIELD" ITEMS_COUNT="$ITEMS_COUNT" python3 << 'PYEOF'
import json, os

f = json.loads(os.environ['STATUS_FIELD_JSON'])
canonical = [
    ('📥 Бэклог',   'GRAY',   'Новые задачи, идеи, запросы'),
    ('🚫 Blocked',  'RED',    'Заблокировано: кликни карточку → Depends on в sidebar. Авто-разблок когда все зависимости закрыты'),
    ('📋 К работе', 'BLUE',   'Взято в текущий период — все зависимости закрыты, можно брать'),
    ('🔨 В работе', 'YELLOW', 'Активно в работе, ветка создана'),
    ('👀 На ревью', 'ORANGE', 'PR открыт, ждёт проверки'),
    ('✅ Одобрено', 'PURPLE', 'PR одобрен, ждёт merge'),
    ('🏁 Готово',   'GREEN',  'Замержено в develop'),
]
existing_names = {o['name'] for o in f.get('options', [])}
fresh_install = int(os.environ.get('ITEMS_COUNT', '0')) == 0

if fresh_install:
    # Replace options entirely — clean canonical set
    parts = [
        '{name: "%s", color: %s, description: "%s"}' % (n, c, d.replace('"','\\"'))
        for n, c, d in canonical
    ]
    print('REPLACE')
    print(','.join(parts))
else:
    # Project has items already — only ADD missing options, preserve existing
    parts = []
    for o in f.get('options', []):
        d = (o.get('description') or '').replace('"','\\"').replace('\n',' ')
        parts.append('{id: "%s", name: "%s", color: %s, description: "%s"}' % (o['id'], o['name'], o['color'], d))
    added = []
    for n, c, d in canonical:
        if n not in existing_names:
            parts.append('{name: "%s", color: %s, description: "%s"}' % (n, c, d.replace('"','\\"')))
            added.append(n)
    if added:
        print('ADD ' + ','.join(added))
    else:
        print('NOOP')
    print(','.join(parts))
PYEOF
)
  MODE=$(echo "$STATUS_OPS" | head -1 | awk '{print $1}')
  OPTS=$(echo "$STATUS_OPS" | tail -1)
  STATUS_ID=$(echo "$STATUS_FIELD" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  case "$MODE" in
    NOOP)
      echo "  ✓ all 7 canonical options already present"
      ;;
    REPLACE|ADD)
      [ "$MODE" = "REPLACE" ] && echo "  + replacing Status options (fresh project, no item data to preserve)"
      [ "$MODE" = "ADD" ]     && echo "  + adding missing canonical options (existing item data preserved)"
      gh api graphql -f query="
mutation {
  updateProjectV2Field(input: {
    fieldId: \"$STATUS_ID\",
    singleSelectOptions: [$OPTS]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
}" >/dev/null
      echo "    ✓ Status options updated"
      ;;
  esac
fi

echo ""
echo "✅ Fields done"
