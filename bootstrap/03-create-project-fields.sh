#!/usr/bin/env bash
# Create 6 custom Project v2 fields + 🚫 Blocked status option (idempotent)
set -euo pipefail

echo "📊 Creating Project v2 fields..."

PROJECT_DATA=$(gh api graphql -f query='
query {
  organization(login: "'"$PROJECT_OWNER"'") {
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

PROJECT_ID=$(echo "$PROJECT_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['organization']['projectV2']['id'])")
echo "  Project ID: $PROJECT_ID"

field_id() {
  echo "$PROJECT_DATA" | python3 -c "
import json,sys
data = json.load(sys.stdin)
for f in data['data']['organization']['projectV2']['fields']['nodes']:
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

# 🚫 Blocked option in Status
echo ""
echo "🚫 Checking 'Blocked' option in Status..."

STATUS_FIELD=$(echo "$PROJECT_DATA" | python3 -c "
import json,sys
data = json.load(sys.stdin)
for f in data['data']['organization']['projectV2']['fields']['nodes']:
    if f.get('name') == 'Status' and f.get('__typename') == 'ProjectV2SingleSelectField':
        print(json.dumps(f)); break
")

if [ -n "$STATUS_FIELD" ]; then
  HAS_BLOCKED=$(echo "$STATUS_FIELD" | python3 -c "
import json,sys
f = json.load(sys.stdin)
for o in f.get('options', []):
    if o['name'] == '🚫 Blocked':
        print('yes'); break
")
  if [ "$HAS_BLOCKED" = "yes" ]; then
    echo "  ✓ 🚫 Blocked option exists"
  else
    echo "  + adding 🚫 Blocked to Status..."
    STATUS_ID=$(echo "$STATUS_FIELD" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
    OPTS=$(echo "$STATUS_FIELD" | python3 -c "
import json,sys
f = json.load(sys.stdin)
parts = []
for o in f.get('options', []):
    desc = (o.get('description') or '').replace('\"','\\\"').replace('\n',' ')
    parts.append(f'{{id: \"{o[\"id\"]}\", name: \"{o[\"name\"]}\", color: {o[\"color\"]}, description: \"{desc}\"}}')
parts.insert(1, '{name: \"🚫 Blocked\", color: RED, description: \"Заблокировано зависимостью\"}')
print(','.join(parts))
")
    gh api graphql -f query="
mutation {
  updateProjectV2Field(input: {
    fieldId: \"$STATUS_ID\",
    singleSelectOptions: [$OPTS]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
}" >/dev/null
    echo "    ✓ added"
  fi
fi

echo ""
echo "✅ Fields done"
