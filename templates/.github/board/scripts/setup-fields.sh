#!/usr/bin/env bash
# ==============================================================================
# setup-fields.sh — идемпотентная настройка полей, опций статусов и labels.
#
# Что делает:
#   1. Создаёт недостающие labels (role:*, этап:*, task, found-work)
#   2. Создаёт недостающие Project v2 поля: Этап (single-select), Depends on (text), Order (number)
#   3. Добавляет опции в поле Этап по списку stages из config.yml
#   4. Добавляет опцию "🚫 Blocked" в существующее поле Status
#
# Requirements:
#   - gh (>= 2.40)
#   - python3 + pyyaml
#   - ENV GH_TOKEN с scopes project + repo + admin:org
#
# Usage:
#   bash .github/board/scripts/setup-fields.sh
#
# Idempotent: можно запускать сколько угодно раз.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.yml"
REPO="COCRealty-Devops/repository-cocrealty"

if [ ! -f "$CONFIG" ]; then
  echo "❌ Config not found: $CONFIG" >&2
  exit 1
fi

PROJECT_OWNER=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG'))['project']['owner'])")
PROJECT_NUMBER=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG'))['project']['number'])")

echo "🔍 Project: $PROJECT_OWNER #$PROJECT_NUMBER"

# ------------------------------------------------------------------------------
# 1. Labels — обязательные для работы auto-assign
# ------------------------------------------------------------------------------
echo ""
echo "═══ 1/4 Labels ═══"

ensure_label() {
  local name="$1" color="$2" desc="$3"
  if gh label list --repo "$REPO" --limit 200 --json name --jq '.[].name' | grep -qFx "$name"; then
    echo "  ✓ exists: $name"
  else
    gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" >/dev/null
    echo "  + created: $name"
  fi
}

ensure_label "role:backend"         "1D76DB" "Go backend (assignee: razqqm)"
ensure_label "role:frontend"        "0E8A16" "Angular SPA (assignee: kenesovaregina-ops)"
ensure_label "role:auth"            "5319E7" "Keycloak/auth (assignee: zxczxcas1)"
ensure_label "role:data-migration"  "FBCA04" "Data migration (assignee: hottraff)"
ensure_label "role:ops"             "D93F0B" "Infrastructure (assignee: fruitart-code)"
ensure_label "role:docs"            "0075CA" "Documentation (assignee: fruitart-code)"

ensure_label "этап:0" "C5DEF5" "Этап 0 — Infrastructure Bootstrap"
ensure_label "этап:1" "BFD4F2" "Этап 1 — Backend API core"
ensure_label "этап:2" "D4C5F9" "Этап 2 — Frontend Angular SPA"
ensure_label "этап:3" "E99695" "Этап 3 — Admin Panel"
ensure_label "этап:4" "F9D0C4" "Этап 4 — Migration 694 ВНД"
ensure_label "этап:5" "FEF2C0" "Этап 5 — Staging Deploy"
ensure_label "этап:6" "C2E0C6" "Этап 6 — MVP Acceptance"
ensure_label "этап:none" "EDEDED" "Cross-cutting, вне этапов"

ensure_label "task"        "A2EEEF" "Обычная задача (template: task.yml)"
ensure_label "found-work"  "BFDADC" "Обнаруженная работа по ходу (template: found_work.yml)"

ensure_label "docs:significant"    "D93F0B" "Значимое docs-изменение, требуется team-sync"
ensure_label "docs:trivial"        "EDEDED" "Тривиальное docs-изменение (typo, format)"
ensure_label "team-sync-overdue"   "FF0000" "PR merged без team-sync issues"
ensure_label "board-audit"         "FBCA04" "Weekly sanity audit report"
ensure_label "metrics-report"      "0E8A16" "Auto-generated weekly cycle time metrics"
ensure_label "dependency-graph"    "1D76DB" "Auto-generated weekly dependency graph"

# ------------------------------------------------------------------------------
# 2. Project ID + existing fields inventory
# ------------------------------------------------------------------------------
echo ""
echo "═══ 2/4 Project inventory ═══"

PROJECT_DATA=$(gh api graphql -f query="
query {
  organization(login: \"$PROJECT_OWNER\") {
    projectV2(number: $PROJECT_NUMBER) {
      id
      fields(first: 50) {
        nodes {
          __typename
          ... on ProjectV2Field { id name dataType }
          ... on ProjectV2SingleSelectField {
            id name dataType
            options { id name }
          }
        }
      }
    }
  }
}")

PROJECT_ID=$(echo "$PROJECT_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['organization']['projectV2']['id'])")
echo "  Project ID: $PROJECT_ID"

field_id() {
  local name="$1"
  echo "$PROJECT_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for f in data['data']['organization']['projectV2']['fields']['nodes']:
    if f.get('name') == '$name':
        print(f['id'])
        break
"
}

field_option_id() {
  local field_name="$1" option_name="$2"
  echo "$PROJECT_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for f in data['data']['organization']['projectV2']['fields']['nodes']:
    if f.get('name') == '$field_name':
        for o in f.get('options') or []:
            if o['name'] == '$option_name':
                print(o['id'])
                break
        break
"
}

# ------------------------------------------------------------------------------
# 3. Create missing fields: Этап (single-select), Depends on (text), Order (number)
# ------------------------------------------------------------------------------
echo ""
echo "═══ 3/4 Fields ═══"

# Stage options derived from config.yml
STAGE_OPTIONS_JSON=$(python3 -c "
import yaml, json
cfg = yaml.safe_load(open('$CONFIG'))
for f in cfg['fields']['managed']:
    if f['name'] == 'Этап':
        opts = [{'name': o['name']} for o in f['options']]
        print(json.dumps(opts))
        break
")

# Этап — single-select
STAGE_FIELD_ID=$(field_id "Этап")
if [ -z "$STAGE_FIELD_ID" ]; then
  echo "  + creating field: Этап (single-select)"
  # single-select options must be provided at creation
  OPTS_GQL=$(python3 -c "
import json, sys
opts = json.loads('$STAGE_OPTIONS_JSON')
print(','.join([
  '{name: \"' + o['name'] + '\", color: GRAY, description: \"\"}'
  for o in opts
]))
")
  gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\",
    dataType: SINGLE_SELECT,
    name: \"Этап\",
    singleSelectOptions: [$OPTS_GQL]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } }
}" >/dev/null
  echo "    ✓ created with $(echo "$STAGE_OPTIONS_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))") options"
else
  echo "  ✓ exists: Этап ($STAGE_FIELD_ID)"
  # Check if all desired options exist; add missing
  python3 -c "
import yaml, json
cfg = yaml.safe_load(open('$CONFIG'))
project = json.loads('''$PROJECT_DATA''')['data']['organization']['projectV2']
field = next(f for f in project['fields']['nodes'] if f.get('name') == 'Этап')
existing = {o['name'] for o in field.get('options', [])}
wanted = [o['name'] for o in next(x for x in cfg['fields']['managed'] if x['name'] == 'Этап')['options']]
missing = [w for w in wanted if w not in existing]
print(' '.join(missing))
" | while read -r missing_opts; do
    for opt in $missing_opts; do
      echo "    + adding option: $opt"
      # Note: GitHub Projects v2 API doesn't support adding options to existing field via public API yet.
      # If that becomes a blocker — recreate field manually via UI or via script extension.
      echo "    ⚠️  cannot programmatically add options to existing single-select; add '$opt' via Projects UI"
    done
  done
fi

# Depends on — text (alias: Зависит от)
DEPENDS_FIELD_ID=$(field_id "Зависит от")
if [ -z "$DEPENDS_FIELD_ID" ]; then
  DEPENDS_FIELD_ID=$(field_id "Depends on")
fi
if [ -z "$DEPENDS_FIELD_ID" ]; then
  echo "  + creating field: Depends on (text)"
  gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\",
    dataType: TEXT,
    name: \"Depends on\"
  }) { projectV2Field { ... on ProjectV2Field { id name } } }
}" >/dev/null
  echo "    ✓ created"
else
  echo "  ✓ exists: Depends on/Зависит от ($DEPENDS_FIELD_ID)"
fi

# Order — number (alias: Порядок)
ORDER_FIELD_ID=$(field_id "Порядок")
if [ -z "$ORDER_FIELD_ID" ]; then
  ORDER_FIELD_ID=$(field_id "Order")
fi
if [ -z "$ORDER_FIELD_ID" ]; then
  echo "  + creating field: Order (number)"
  gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\",
    dataType: NUMBER,
    name: \"Order\"
  }) { projectV2Field { ... on ProjectV2Field { id name } } }
}" >/dev/null
  echo "    ✓ created"
else
  echo "  ✓ exists: Order/Порядок ($ORDER_FIELD_ID)"
fi

# ⏱ Last moved — date (card aging tracker)
LASTMOVED_FIELD_ID=$(field_id "⏱ Last moved")
if [ -z "$LASTMOVED_FIELD_ID" ]; then
  LASTMOVED_FIELD_ID=$(field_id "Last moved")
fi
if [ -z "$LASTMOVED_FIELD_ID" ]; then
  echo "  + creating field: ⏱ Last moved (date, auto-updated)"
  gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\",
    dataType: DATE,
    name: \"⏱ Last moved\"
  }) { projectV2Field { ... on ProjectV2Field { id name } } }
}" >/dev/null
  echo "    ✓ created"
else
  echo "  ✓ exists: ⏱ Last moved ($LASTMOVED_FIELD_ID)"
fi

# Срочность — single-select (auto-computed). Now renamed to 🤖 Срочность.
URGENCY_FIELD_ID=$(field_id "🤖 Срочность")
if [ -z "$URGENCY_FIELD_ID" ]; then
  URGENCY_FIELD_ID=$(field_id "Срочность")
fi
# 📋 Действие — single-select (auto-derived from title prefix)
ACTION_FIELD_ID=$(field_id "📋 Действие")
if [ -z "$ACTION_FIELD_ID" ]; then
  echo "  + creating field: 📋 Действие (single-select, auto-derived from title)"
  gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\",
    dataType: SINGLE_SELECT,
    name: \"📋 Действие\",
    singleSelectOptions: [
      {name: \"💻 Реализовать\",    color: BLUE,   description: \"Написать новый код (feat/refactor/test)\"},
      {name: \"🐛 Исправить\",       color: RED,    description: \"Баг, инцидент, регрессия (fix:)\"},
      {name: \"📝 Документировать\", color: GRAY,   description: \"ADR, спека, runbook — текст для людей (docs:)\"},
      {name: \"⚙️ Настроить\",       color: YELLOW, description: \"Инфра, конфиги, CI, DNS (ops/chore/auth/data)\"},
      {name: \"👀 Ознакомиться\",    color: GRAY,   description: \"Прочитать и отписаться (team-sync:)\"},
      {name: \"🔍 Исследовать\",     color: PURPLE, description: \"Выбор опций, спайк (proposal/research)\"},
      {name: \"✅ Ревьюить\",        color: GREEN,  description: \"Code review / sign-off (review:)\"},
      {name: \"🤝 Согласовать\",     color: ORANGE, description: \"Внешние стороны — юрлица, юристы (coord:)\"}
    ]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } }
}" >/dev/null
  echo "    ✓ created with 8 action values"
else
  echo "  ✓ exists: 📋 Действие ($ACTION_FIELD_ID)"
fi

if [ -z "$URGENCY_FIELD_ID" ]; then
  echo "  + creating field: 🤖 Срочность (single-select, auto-computed)"
  gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\",
    dataType: SINGLE_SELECT,
    name: \"🤖 Срочность\",
    singleSelectOptions: [
      {name: \"🔥 Горит\", color: RED, description: \"Блокирует 2+ задач или critical path\"},
      {name: \"⚡ Срочно\", color: ORANGE, description: \"Блокирует 1 задачу\"},
      {name: \"⏳ Обычно\", color: GRAY, description: \"По умолчанию\"},
      {name: \"🟢 Может подождать\", color: GREEN, description: \"Cross-cutting, никого не блокирует\"}
    ]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } }
}" >/dev/null
  echo "    ✓ created with 4 urgency levels"
else
  echo "  ✓ exists: 🤖 Срочность ($URGENCY_FIELD_ID)"
fi

# ------------------------------------------------------------------------------
# 4. Status field — add "🚫 Blocked" option
# ------------------------------------------------------------------------------
echo ""
echo "═══ 4/4 Status option '🚫 Blocked' ═══"

BLOCKED_OPT_ID=$(field_option_id "Status" "🚫 Blocked")
if [ -n "$BLOCKED_OPT_ID" ]; then
  echo "  ✓ option exists: 🚫 Blocked ($BLOCKED_OPT_ID)"
else
  # updateProjectV2Field с передачей всех существующих options (с id для сохранения
  # item values) + новая опция. Без id существующие пересоздадутся и item field values
  # будут очищены.
  STATUS_FIELD_ID=$(field_id "Status")
  echo "  + adding option '🚫 Blocked' to Status via updateProjectV2Field"

  EXISTING_OPTS=$(echo "$PROJECT_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for f in data['data']['organization']['projectV2']['fields']['nodes']:
    if f.get('name') == 'Status':
        for o in f.get('options', []):
            desc = (o.get('description') or '').replace('\"', '\\\"')
            print(f'{{id: \"{o[\"id\"]}\", name: \"{o[\"name\"]}\", color: {o[\"color\"]}, description: \"{desc}\"}}')
        break
")

  # Insert Blocked after Бэклог (first position in our order)
  BACKLOG_LINE=$(echo "$EXISTING_OPTS" | grep 'Бэклог' || true)
  REST_LINES=$(echo "$EXISTING_OPTS" | grep -v 'Бэклог')
  BLOCKED_NEW='{name: "🚫 Blocked", color: RED, description: "Заблокировано другой задачей (см. поле Depends on)"}'

  OPTS_PAYLOAD=$(echo -e "$BACKLOG_LINE\n$BLOCKED_NEW\n$REST_LINES" | paste -sd ',' -)

  gh api graphql -f query="
mutation {
  updateProjectV2Field(input: {
    fieldId: \"$STATUS_FIELD_ID\",
    singleSelectOptions: [$OPTS_PAYLOAD]
  }) {
    projectV2Field { ... on ProjectV2SingleSelectField { id name } }
  }
}" >/dev/null && echo "    ✓ added" || echo "    ⚠️ failed — add manually via UI"
fi

echo ""
echo "✅ setup-fields.sh complete"
echo ""
echo "Verify on board: https://github.com/orgs/$PROJECT_OWNER/projects/$PROJECT_NUMBER/settings"
