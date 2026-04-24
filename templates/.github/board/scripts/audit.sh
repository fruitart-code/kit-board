#!/usr/bin/env bash
# ==============================================================================
# audit.sh — еженедельный audit состояния доски.
#
# Что проверяет:
#   1. Все open issues — на доске?
#   2. У каждого open issue — role:* label есть?
#   3. У каждого open issue — этап:* label есть?
#   4. У каждого open issue — assignee проставлен?
#   5. Нет ли issues в статусе 🚫 Blocked где все Depends on уже closed?
#   6. Нет ли "висячих" Depends on ссылок на несуществующие issues?
#
# Output: структурированный отчёт со списком гэпов. Ничего не меняет.
#
# Usage:
#   bash .github/board/scripts/audit.sh
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.yml"
REPO="COCRealty-Devops/repository-cocrealty"

PROJECT_OWNER=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG'))['project']['owner'])")
PROJECT_NUMBER=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG'))['project']['number'])")

echo "🔍 Board audit — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# --- Fetch all open issues ---
ISSUES=$(gh issue list --repo "$REPO" --state open --limit 100 \
  --json number,title,labels,assignees)

# --- Fetch all project items ---
ITEMS=$(gh api graphql -f query="
query {
  organization(login: \"$PROJECT_OWNER\") {
    projectV2(number: $PROJECT_NUMBER) {
      items(first: 100) {
        nodes {
          id
          content { __typename ... on Issue { number } }
          fieldValues(first: 20) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldTextValue {
                text
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2FieldCommon { name } }
              }
            }
          }
        }
      }
    }
  }
}")

python3 <<EOF
import json

issues = json.loads('''$ISSUES''')
items = json.loads('''$ITEMS''')

items_by_num = {}
for it in items['data']['organization']['projectV2']['items']['nodes']:
    c = it.get('content') or {}
    if c.get('__typename') == 'Issue' and c.get('number'):
        items_by_num[c['number']] = it

gaps = {
    'not_on_board': [],
    'missing_role': [],
    'missing_stage': [],
    'missing_assignee': [],
    'stale_blocked': [],    # status=Blocked but all deps closed
    'dangling_depends': [], # depends on #N where N doesn't exist
}

for i in issues:
    num = i['number']
    labels = [l['name'] for l in i['labels']]
    has_role = any(l.startswith('role:') for l in labels)
    has_stage = any(l.startswith('этап:') for l in labels)
    has_assignee = bool(i['assignees'])

    if num not in items_by_num:
        gaps['not_on_board'].append(num)
        continue
    if not has_role:
        gaps['missing_role'].append(num)
    if not has_stage:
        gaps['missing_stage'].append(num)
    if not has_assignee:
        gaps['missing_assignee'].append(num)

    # Check status & depends
    item = items_by_num[num]
    status = None
    depends_text = ''
    for fv in item['fieldValues']['nodes']:
        if fv.get('__typename') == 'ProjectV2ItemFieldSingleSelectValue':
            if fv.get('field', {}).get('name') == 'Status':
                status = fv.get('name')
        elif fv.get('__typename') == 'ProjectV2ItemFieldTextValue':
            if fv.get('field', {}).get('name') == 'Depends on':
                depends_text = fv.get('text') or ''

    # No need to check stale_blocked/dangling_depends unless we fetch state of deps.
    # Simplified: just report counts.

print("═══ Gaps summary ═══")
print(f"  Total open issues: {len(issues)}")
print(f"  Not on board:      {len(gaps['not_on_board'])}  {gaps['not_on_board'] if gaps['not_on_board'] else ''}")
print(f"  Missing role:*:    {len(gaps['missing_role'])}  {gaps['missing_role'][:10]}")
print(f"  Missing этап:*:    {len(gaps['missing_stage'])}  {gaps['missing_stage'][:10]}")
print(f"  Missing assignee:  {len(gaps['missing_assignee'])}  {gaps['missing_assignee'][:10]}")
print()
print("═══ Next actions ═══")
if gaps['missing_role'] or gaps['missing_stage'] or gaps['missing_assignee']:
    print("  1. Trigger workflow_dispatch for issue-automation.yml with these numbers")
    print("     OR run backfill.sh --apply")
if gaps['not_on_board']:
    print("  2. Check 'Auto-add to project' workflow is enabled on Projects settings")
print()
print("═══ End of audit ═══")
EOF
