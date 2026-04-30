#!/usr/bin/env bash
# ==============================================================================
# kit-board — lib/render-template.sh
#
# Renders a template file by substituting {{PLACEHOLDER}} tokens with values
# from the environment. Idempotent: applying twice yields the same output as
# applying once (placeholders consumed in a single pass).
#
# Supported placeholders (set via .env + lib/detect-owner.sh):
#   {{PROJECT_OWNER}}   — GitHub login (org or user)
#   {{PROJECT_NUMBER}}  — Project v2 number
#   {{PROJECT_TITLE}}   — Project display title
#   {{PROJECT_URL}}     — Canonical web URL of the Project v2
#   {{OWNER_ENTITY}}    — "user" | "organization" — for GraphQL queries
#   {{TARGET_REPO}}     — owner/name of target repo
#   {{BACKEND_USER}}    — role assignees (fall back to OPS_USER if empty)
#   {{FRONTEND_USER}}
#   {{AUTH_USER}}
#   {{DATA_USER}}
#   {{OPS_USER}}
#   {{DOCS_USER}}
#
# Usage:
#   source "$KIT_DIR/lib/render-template.sh"
#   render_template "$src_path" "$dst_path"
#
# Requires: PROJECT_OWNER, PROJECT_NUMBER, OPS_USER, OWNER_ENTITY, PROJECT_URL
# ==============================================================================

render_template() {
  local src="$1"
  local dst="$2"

  if [ ! -f "$src" ]; then
    echo "❌ render_template: source not found: $src" >&2
    return 1
  fi

  python3 - "$src" "$dst" <<'PYEOF'
import os, sys, re

src, dst = sys.argv[1], sys.argv[2]

with open(src, 'r', encoding='utf-8') as f:
    content = f.read()

ops = os.environ['OPS_USER']
replacements = {
    'PROJECT_OWNER':   os.environ['PROJECT_OWNER'],
    'PROJECT_NUMBER':  os.environ['PROJECT_NUMBER'],
    'PROJECT_TITLE':   os.environ.get('PROJECT_TITLE', 'Project Board'),
    'PROJECT_URL':     os.environ['PROJECT_URL'],
    'OWNER_ENTITY':    os.environ['OWNER_ENTITY'],
    'TARGET_REPO':     os.environ['TARGET_REPO'],
    'BACKEND_USER':    os.environ.get('BACKEND_USER',  ops) or ops,
    'FRONTEND_USER':   os.environ.get('FRONTEND_USER', ops) or ops,
    'AUTH_USER':       os.environ.get('AUTH_USER',     ops) or ops,
    'DATA_USER':       os.environ.get('DATA_USER',     ops) or ops,
    'OPS_USER':        ops,
    'DOCS_USER':       os.environ.get('DOCS_USER',     ops) or ops,
}
for key, val in replacements.items():
    content = content.replace('{{' + key + '}}', str(val))

# In YAML, strip outer quotes if PROJECT_NUMBER ends up quoted as "N"
content = re.sub(r'number:\s*"(\d+)"', r'number: \1', content)

os.makedirs(os.path.dirname(dst) or '.', exist_ok=True)
with open(dst, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF
}

export -f render_template
