#!/usr/bin/env bash
# ==============================================================================
# 02-setup-secrets.sh
#
# Idempotently configures repository secrets that kit-board workflows need:
#
#   PROJECT_TOKEN          — required. PAT with `project` scope, used by
#                            issue-automation, board-automation, board-sanity,
#                            cycle-time-metrics, dependency-graph,
#                            auto-add-to-project to read/write Project v2.
#
#   TELEGRAM_BOT_TOKEN     — optional. Skipped if .env value is empty.
#   TELEGRAM_CHAT_ID_TASKS — optional. Skipped if empty.
#
# By default `PROJECT_TOKEN` is sourced from the local `gh auth token`
# (the same scopes the install script is already using). For a stricter
# setup, generate a dedicated PAT in https://github.com/settings/tokens
# and put it into PROJECT_TOKEN_OVERRIDE in .env.
# ==============================================================================
set -euo pipefail

echo "🔐 Setting up repo secrets in $TARGET_REPO ..."

set_secret() {
  local name="$1" value="$2"
  if [ -z "$value" ]; then
    echo "  ✓ $name skipped (empty)"
    return 0
  fi
  if echo "$value" | gh secret set "$name" --repo "$TARGET_REPO" >/dev/null 2>&1; then
    echo "  ✓ $name set"
  else
    echo "  ⚠️  $name failed (need admin rights on $TARGET_REPO)"
  fi
}

# --- PROJECT_TOKEN: from override or current gh CLI keyring token ---
if [ -n "${PROJECT_TOKEN_OVERRIDE:-}" ]; then
  echo "  → using PROJECT_TOKEN_OVERRIDE from .env"
  set_secret PROJECT_TOKEN "$PROJECT_TOKEN_OVERRIDE"
else
  if gh auth token >/dev/null 2>&1; then
    # Verify the token actually has `project` scope before pushing it as a secret.
    SCOPES=$(gh api -i user 2>&1 | grep -i "x-oauth-scopes:" | cut -d':' -f2- || true)
    if echo "$SCOPES" | grep -q "project"; then
      set_secret PROJECT_TOKEN "$(gh auth token)"
    else
      echo "  ⚠️  current gh token has no 'project' scope — PROJECT_TOKEN not set"
      echo "     Either run: gh auth refresh -s project,workflow,admin:org"
      echo "     Or generate a dedicated PAT and set PROJECT_TOKEN_OVERRIDE in .env"
    fi
  else
    echo "  ⚠️  gh auth not available — PROJECT_TOKEN not set"
  fi
fi

# --- Optional: Telegram notifications ---
set_secret TELEGRAM_BOT_TOKEN     "${TELEGRAM_BOT_TOKEN:-}"
set_secret TELEGRAM_CHAT_ID_TASKS "${TELEGRAM_CHAT_ID_TASKS:-}"

echo ""
echo "✅ Secrets step done"
