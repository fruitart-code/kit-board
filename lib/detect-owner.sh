#!/usr/bin/env bash
# ==============================================================================
# kit-board — lib/detect-owner.sh
#
# Determines whether $PROJECT_OWNER is a GitHub User or Organization,
# exports the result as $OWNER_ENTITY (lowercase, suitable for GraphQL):
#   - "user"          for User accounts
#   - "organization"  for Organization accounts
#
# Also exports $PROJECT_URL — the canonical web URL of the Project v2:
#   - User:         https://github.com/users/<owner>/projects/<number>
#   - Organization: https://github.com/orgs/<owner>/projects/<number>
#
# Usage (in any bootstrap or template script):
#   source "$KIT_DIR/lib/detect-owner.sh"
#   echo "Querying as: $OWNER_ENTITY"
#
# Requires: $PROJECT_OWNER, $PROJECT_NUMBER set in the environment
#           gh CLI authenticated with `user` scope
# ==============================================================================

set -euo pipefail

if [ -z "${PROJECT_OWNER:-}" ]; then
  echo "❌ detect-owner: PROJECT_OWNER not set" >&2
  return 1 2>/dev/null || exit 1
fi

# Query GitHub API: returns "User" or "Organization" in the .type field
OWNER_TYPE_RAW=$(gh api "users/$PROJECT_OWNER" --jq '.type' 2>/dev/null || echo "")

case "$OWNER_TYPE_RAW" in
  User)
    OWNER_ENTITY="user"
    PROJECT_URL_PREFIX="https://github.com/users/$PROJECT_OWNER"
    ;;
  Organization)
    OWNER_ENTITY="organization"
    PROJECT_URL_PREFIX="https://github.com/orgs/$PROJECT_OWNER"
    ;;
  *)
    echo "❌ detect-owner: cannot determine type of '$PROJECT_OWNER' (got: '$OWNER_TYPE_RAW')" >&2
    echo "   Check that the login exists and that gh CLI has 'user' scope." >&2
    return 1 2>/dev/null || exit 1
    ;;
esac

if [ -n "${PROJECT_NUMBER:-}" ]; then
  PROJECT_URL="$PROJECT_URL_PREFIX/projects/$PROJECT_NUMBER"
else
  PROJECT_URL="$PROJECT_URL_PREFIX"
fi

export OWNER_ENTITY PROJECT_URL
