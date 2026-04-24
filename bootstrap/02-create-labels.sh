#!/usr/bin/env bash
# Create 20+ labels in target repo (idempotent)
set -euo pipefail

REPO="$TARGET_REPO"

ensure_label() {
  local name="$1" color="$2" desc="$3"
  if gh label list --repo "$REPO" --limit 200 --json name --jq '.[].name' 2>/dev/null | grep -qFx "$name"; then
    echo "  ✓ exists: $name"
  else
    gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" >/dev/null
    echo "  + created: $name"
  fi
}

echo "🏷  Creating labels in $REPO..."

# role:*
ensure_label "role:backend"         "1D76DB" "Backend (assignee: $BACKEND_USER)"
ensure_label "role:frontend"        "0E8A16" "Frontend (assignee: $FRONTEND_USER)"
ensure_label "role:auth"            "5319E7" "Auth/Keycloak (assignee: $AUTH_USER)"
ensure_label "role:data-migration"  "FBCA04" "Data migration (assignee: $DATA_USER)"
ensure_label "role:ops"             "D93F0B" "Infrastructure (assignee: $OPS_USER)"
ensure_label "role:docs"            "0075CA" "Documentation (assignee: $DOCS_USER)"

# этап:*
ensure_label "этап:0" "C5DEF5" "Этап 0 — Infrastructure"
ensure_label "этап:1" "BFD4F2" "Этап 1 — Backend core"
ensure_label "этап:2" "D4C5F9" "Этап 2 — Frontend"
ensure_label "этап:3" "E99695" "Этап 3 — Admin Panel"
ensure_label "этап:4" "F9D0C4" "Этап 4 — Data migration"
ensure_label "этап:5" "FEF2C0" "Этап 5 — Staging Deploy"
ensure_label "этап:6" "C2E0C6" "Этап 6 — MVP Acceptance"
ensure_label "этап:none" "EDEDED" "Cross-cutting, вне этапов"

# Templates
ensure_label "task"                 "A2EEEF" "Обычная задача"
ensure_label "found-work"           "BFDADC" "Обнаруженная работа"

# Process
ensure_label "blocked"              "b60205" "Blocked by dependency"
ensure_label "docs:significant"     "D93F0B" "Значимое docs-изменение"
ensure_label "docs:trivial"         "EDEDED" "Тривиальное docs-изменение"
ensure_label "team-sync-overdue"    "FF0000" "PR merged без team-sync"
ensure_label "board-audit"          "FBCA04" "Weekly sanity audit"
ensure_label "metrics-report"       "0E8A16" "Auto-generated cycle time metrics"
ensure_label "dependency-graph"     "1D76DB" "Auto-generated dependency graph"

echo "✅ Labels done"
