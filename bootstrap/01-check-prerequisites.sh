#!/usr/bin/env bash
# Check prerequisites: gh, python, pyyaml, jq, bash, git, token scopes.
set -euo pipefail

echo "🔎 Checking prerequisites..."

# gh CLI
if ! command -v gh &> /dev/null; then
  echo "❌ gh CLI not found. Install: https://cli.github.com/" >&2
  exit 1
fi
GH_VERSION=$(gh --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "  ✓ gh CLI $GH_VERSION"

# Python
if ! command -v python3 &> /dev/null; then
  echo "❌ python3 not found" >&2
  exit 1
fi
python3 --version >/dev/null && echo "  ✓ python3 $(python3 --version | cut -d' ' -f2)"

# pyyaml
if ! python3 -c "import yaml" 2>/dev/null; then
  echo "❌ pyyaml not installed. Run: python3 -m pip install --user pyyaml" >&2
  exit 1
fi
echo "  ✓ pyyaml"

# jq
if ! command -v jq &> /dev/null; then
  echo "❌ jq not found. Install via brew/apt" >&2
  exit 1
fi
echo "  ✓ jq $(jq --version)"

# git
if ! command -v git &> /dev/null; then
  echo "❌ git not found" >&2
  exit 1
fi
echo "  ✓ git $(git --version | cut -d' ' -f3)"

# gh auth
if ! gh auth status &> /dev/null; then
  echo "❌ gh not authenticated. Run: gh auth login" >&2
  exit 1
fi
echo "  ✓ gh authenticated"

# Required scopes
SCOPES=$(gh api user -i 2>&1 | grep -i "x-oauth-scopes:" | cut -d':' -f2- | tr -d ' ' | tr ',' '\n' || echo "")
for required in "repo" "project" "workflow"; do
  if echo "$SCOPES" | grep -q "$required"; then
    echo "  ✓ scope: $required"
  else
    echo "  ⚠️  scope missing: $required — may cause issues"
    echo "     Run: gh auth refresh -s project,repo,admin:org,workflow"
  fi
done

# Verify project exists
echo ""
echo "🔎 Verifying Project v2 access..."
PROJ_TITLE=$(gh api graphql -f query='
query {
  organization(login: "'"$PROJECT_OWNER"'") {
    projectV2(number: '"$PROJECT_NUMBER"') { title }
  }
}' 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
p = d.get('data',{}).get('organization',{}).get('projectV2')
print(p.get('title') if p else 'NOT_FOUND')
" 2>/dev/null || echo "NOT_FOUND")

if [ "$PROJ_TITLE" = "NOT_FOUND" ] || [ -z "$PROJ_TITLE" ]; then
  echo "❌ Project v2 $PROJECT_OWNER/$PROJECT_NUMBER not accessible"
  echo "   Check: project exists, token has 'project' scope, you have access"
  exit 1
fi
echo "  ✓ Project accessible: '$PROJ_TITLE'"

# Verify target repo exists
echo ""
echo "🔎 Verifying target repo access..."
if ! gh repo view "$TARGET_REPO" &>/dev/null; then
  echo "❌ Target repo $TARGET_REPO not accessible" >&2
  exit 1
fi
echo "  ✓ Target repo: $TARGET_REPO"

echo ""
echo "✅ Prerequisites OK"
