#!/usr/bin/env bash
# ==============================================================================
# kit-board — install.sh
#
# Main orchestrator. Запускает bootstrap скрипты последовательно.
# Идемпотентен — можно запускать много раз без побочных эффектов.
#
# Usage:
#   ./install.sh /path/to/target-repo-on-disk
#
# Prerequisites:
#   - .env файл заполнен (cp .env.example .env + edit)
#   - gh CLI авторизован с scope project+repo+admin:org+workflow
#   - Target repo — локальная копия (git clone), Admin access на GitHub
#   - Project v2 создан в PROJECT_OWNER → PROJECT_NUMBER
# ==============================================================================

set -euo pipefail

# --- Args ---
if [ $# -lt 1 ]; then
  echo "Usage: $0 /path/to/target-repo" >&2
  exit 1
fi

TARGET_DIR="$1"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$KIT_DIR"

# --- Load .env ---
if [ ! -f ".env" ]; then
  echo "❌ .env not found. Copy .env.example → .env and fill in." >&2
  exit 1
fi

set -a
source .env
set +a

# --- Export для bootstrap scripts ---
export KIT_DIR TARGET_DIR
export PROJECT_OWNER PROJECT_NUMBER PROJECT_TITLE TARGET_REPO
export BACKEND_USER FRONTEND_USER AUTH_USER DATA_USER OPS_USER DOCS_USER
export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID_TASKS
export KIT_BOARD_LANG="${KIT_BOARD_LANG:-ru}"

# --- Sanity: required vars ---
REQUIRED=(PROJECT_OWNER PROJECT_NUMBER TARGET_REPO OPS_USER DOCS_USER)
for var in "${REQUIRED[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "❌ Required env var not set: $var" >&2
    echo "   Check .env and fill in the missing value." >&2
    exit 1
  fi
done

# --- Target dir sanity ---
if [ ! -d "$TARGET_DIR/.git" ]; then
  echo "❌ $TARGET_DIR is not a git repository" >&2
  exit 1
fi

echo "🚀 kit-board install starting"
echo "   Kit dir:       $KIT_DIR"
echo "   Target dir:    $TARGET_DIR"
echo "   Project owner: $PROJECT_OWNER"
echo "   Project #:     $PROJECT_NUMBER"
echo "   Target repo:   $TARGET_REPO"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted by user."
  exit 0
fi

# --- Run bootstrap steps ---
STEPS=(
  "01-check-prerequisites"
  "02-create-labels"
  "03-create-project-fields"
  "04-install-workflows"
  "05-install-templates"
  "06-install-board-module"
  "07-backfill-existing-issues"
)

for step in "${STEPS[@]}"; do
  script="$KIT_DIR/bootstrap/${step}.sh"
  if [ ! -x "$script" ]; then
    echo "❌ Bootstrap script missing or not executable: $script" >&2
    exit 1
  fi
  echo ""
  echo "════════════════════════════════════════════════════"
  echo "  ${step}"
  echo "════════════════════════════════════════════════════"
  bash "$script"
done

echo ""
echo "════════════════════════════════════════════════════"
echo "  ✅ Install complete!"
echo "════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Run ./verify.sh $TARGET_DIR to check installation"
echo "  2. In $TARGET_DIR: git status, review changes"
echo "  3. Commit: cd $TARGET_DIR && git add .github/ && git commit -m 'feat(board): install kit-board'"
echo "  4. Push and test — create a new issue via template"
echo ""
echo "See ACCEPTANCE_CHECKLIST.md for full verification."
