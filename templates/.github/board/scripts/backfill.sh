#!/usr/bin/env bash
# ==============================================================================
# backfill.sh — проставляет новые Project поля (Этап, Depends on, Order) на
# существующих open issues, которые были созданы до появления этой
# автоматизации.
#
# Что делает:
#   1. Перечисляет все open issues репозитория
#   2. Для каждого — смотрит labels, извлекает role:* и этап:*
#   3. Если role:* отсутствует — по умолчанию fallback_assignee
#   4. Заполняет Project fields: Этап, Depends on (из body если есть), Status
#   5. Не трогает issues которые уже в статусе В работе / На ревью / Одобрено / Готово
#
# Requirements:
#   - gh, python3, pyyaml
#   - GH_TOKEN с scopes project + repo
#
# Usage:
#   bash .github/board/scripts/backfill.sh           # dry-run (печатает план)
#   bash .github/board/scripts/backfill.sh --apply   # реально применяет
# ==============================================================================

set -euo pipefail

APPLY=${1:-}
DRY_RUN=true
if [ "$APPLY" = "--apply" ]; then
  DRY_RUN=false
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.yml"
REPO="COCRealty-Devops/repository-cocrealty"

if [ "$DRY_RUN" = true ]; then
  echo "🔎 DRY-RUN mode. Run with --apply to execute changes."
else
  echo "🚀 APPLY mode. Changes WILL be persisted."
fi
echo ""

# --- 1. Project metadata ---
PROJECT_OWNER=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG'))['project']['owner'])")
PROJECT_NUMBER=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG'))['project']['number'])")

PROJECT_DATA=$(gh api graphql -f query="
query {
  organization(login: \"$PROJECT_OWNER\") {
    projectV2(number: $PROJECT_NUMBER) {
      id
      fields(first: 50) {
        nodes {
          __typename
          ... on ProjectV2Field { id name }
          ... on ProjectV2SingleSelectField {
            id name
            options { id name }
          }
        }
      }
      items(first: 100) {
        nodes {
          id
          content { __typename ... on Issue { number } }
        }
      }
    }
  }
}")

PROJECT_ID=$(echo "$PROJECT_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['organization']['projectV2']['id'])")

get_field_id() {
  echo "$PROJECT_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for f in data['data']['organization']['projectV2']['fields']['nodes']:
    if f.get('name') == '$1':
        print(f['id']); break
"
}

get_option_id() {
  echo "$PROJECT_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for f in data['data']['organization']['projectV2']['fields']['nodes']:
    if f.get('name') == '$1':
        for o in f.get('options', []):
            if o['name'] == '$2':
                print(o['id']); break
        break
"
}

STAGE_FIELD=$(get_field_id "Этап")
DEPENDS_FIELD=$(get_field_id "Depends on")
STATUS_FIELD=$(get_field_id "Status")

if [ -z "$STAGE_FIELD" ] || [ -z "$DEPENDS_FIELD" ] || [ -z "$STATUS_FIELD" ]; then
  echo "❌ Missing fields. Run setup-fields.sh first." >&2
  exit 1
fi

TODO_OPT=$(get_option_id "Status" "📋 К работе")
BLOCKED_OPT=$(get_option_id "Status" "🚫 Blocked")
BACKLOG_OPT=$(get_option_id "Status" "📥 Бэклог")

# --- 2. Find items map: issue_number → item_id ---
declare -A ITEMS_MAP
while IFS=$'\t' read -r num item_id; do
  ITEMS_MAP[$num]=$item_id
done < <(echo "$PROJECT_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data['data']['organization']['projectV2']['items']['nodes']:
    c = item.get('content') or {}
    if c.get('__typename') == 'Issue' and c.get('number'):
        print(f\"{c['number']}\t{item['id']}\")
")

# --- 3. Process open issues ---
echo "═══ Processing open issues ═══"
echo ""

gh issue list --repo "$REPO" --state open --limit 100 --json number,labels,body,assignees \
  | python3 -c "
import json, sys, yaml, re
cfg = yaml.safe_load(open('$CONFIG'))
issues = json.load(sys.stdin)
for i in issues:
    labels = [l['name'] for l in i['labels']]
    role = None
    for lab in labels:
        if lab.startswith('role:'):
            role = lab[5:]; break
    stage = None
    for lab in labels:
        if lab.startswith('этап:'):
            stage = lab[5:]; break

    body = i.get('body') or ''
    m = re.search(r'###\s+(?:Зависит от|Depends on)\s*\n+([^\n]+?)(?:\n|\$)', body, re.IGNORECASE)
    deps = []
    if m and m.group(1).strip() != '_No response_':
        deps = [int(x) for x in re.findall(r'#(\d+)', m.group(1))]

    print(f\"{i['number']}|{role or ''}|{stage or ''}|{','.join(str(d) for d in deps)}|{','.join(a['login'] for a in i['assignees'])}\")
" | while IFS='|' read -r num role stage deps assignees; do

  item_id="${ITEMS_MAP[$num]:-}"
  if [ -z "$item_id" ]; then
    echo "  #$num: skip (not on project)"
    continue
  fi

  # Determine stage option name
  stage_opt_name=""
  case "$stage" in
    0|1|2|3|4|5|6) stage_opt_name="Этап $stage" ;;
    none)          stage_opt_name="Вне этапов" ;;
    "")            stage_opt_name="" ;;
  esac

  # Determine target status by deps
  target_status="todo"
  if [ -n "$deps" ]; then
    for d in ${deps//,/ }; do
      state=$(gh issue view "$d" --repo "$REPO" --json state --jq .state 2>/dev/null || echo "UNKNOWN")
      if [ "$state" = "OPEN" ]; then
        target_status="blocked"
        break
      fi
    done
  fi

  echo "  #$num: role=$role, stage=$stage, deps=[$deps] → status=$target_status"

  if [ "$DRY_RUN" = true ]; then
    continue
  fi

  # Apply stage
  if [ -n "$stage_opt_name" ]; then
    opt_id=$(get_option_id "Этап" "$stage_opt_name")
    if [ -n "$opt_id" ]; then
      gh api graphql -f query="
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: \"$PROJECT_ID\",
    itemId: \"$item_id\",
    fieldId: \"$STAGE_FIELD\",
    value: { singleSelectOptionId: \"$opt_id\" }
  }) { projectV2Item { id } }
}" >/dev/null
    fi
  fi

  # Apply depends on (text)
  deps_text=""
  if [ -n "$deps" ]; then
    deps_text=$(echo "$deps" | sed 's/,/, #/g' | sed 's/^/#/')
  fi
  gh api graphql -f query="
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: \"$PROJECT_ID\",
    itemId: \"$item_id\",
    fieldId: \"$DEPENDS_FIELD\",
    value: { text: \"$deps_text\" }
  }) { projectV2Item { id } }
}" >/dev/null

  # Apply status (only if current is Backlog)
  # Read current status
  current_status=$(gh api graphql -f query="
query {
  node(id: \"$item_id\") {
    ... on ProjectV2Item {
      fieldValues(first: 20) {
        nodes {
          __typename
          ... on ProjectV2ItemFieldSingleSelectValue {
            name
            field { ... on ProjectV2FieldCommon { name } }
          }
        }
      }
    }
  }
}" | python3 -c "
import json, sys
data = json.load(sys.stdin)['data']['node']['fieldValues']['nodes']
for fv in data:
    if fv.get('__typename') == 'ProjectV2ItemFieldSingleSelectValue' and fv.get('field', {}).get('name') == 'Status':
        print(fv.get('name', ''))
        break
")

  case "$current_status" in
    "📥 Бэклог"|"🚫 Blocked"|"📋 К работе"|"")
      new_opt_id=""
      if [ "$target_status" = "todo" ]; then
        new_opt_id="$TODO_OPT"
      elif [ "$target_status" = "blocked" ]; then
        new_opt_id="$BLOCKED_OPT"
      fi
      if [ -n "$new_opt_id" ]; then
        gh api graphql -f query="
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: \"$PROJECT_ID\",
    itemId: \"$item_id\",
    fieldId: \"$STATUS_FIELD\",
    value: { singleSelectOptionId: \"$new_opt_id\" }
  }) { projectV2Item { id } }
}" >/dev/null
      fi
      ;;
  esac
done

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "🔎 Dry-run complete. Run with --apply to persist."
else
  echo "✅ Backfill complete."
fi
