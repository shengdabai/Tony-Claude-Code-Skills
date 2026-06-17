#!/bin/bash
# Auth preflight hook — runs at SessionStart.
# Goal: surface "key/auth missing" BEFORE you waste a session hitting 403.
#
# IMPORTANT: This hook runs in a Claude subprocess that does NOT inherit
# zshrc-loaded env vars. Checking $ANTHROPIC_API_KEY here would always
# report "missing" (false alarm). So we check things that are reliable:
#   1. gh CLI auth state (uses keychain, works without env)
#   2. Critical config file existence (mode files, ntfy env, MCP scripts)
#   3. Settings.json env keys are present (declarative auth surfaces)
#
# Always non-blocking. Output to stderr (Claude sees it as advisory).

REPORT=""
note() { REPORT="${REPORT}${1}\n"; }

note "[auth-preflight @ $(date '+%H:%M:%S')]"

# 1. gh CLI auth (uses macOS keychain, reliable)
# Capture once — also surface token SCOPES so a missing scope (e.g. 'user',
# 'workflow') is caught at SessionStart instead of mid-task 403 (report friction #2).
# NOTE: do NOT wrap `gh auth status` in `timeout` — on macOS that empirically
# breaks gh's keychain/keyring read and yields a false "not logged in" every
# session. gh makes a single bounded API call (its own internal timeouts apply);
# this direct call is the pre-existing, proven behavior across 200+ sessions.
# The change below only ADDS scope parsing on the already-captured output.
if command -v gh >/dev/null 2>&1; then
  GH_STATUS="$(gh auth status 2>&1)"
  if printf '%s' "$GH_STATUS" | grep -q "Logged in"; then
    note "  ✓ gh auth: ok"
    SCOPES_LINE="$(printf '%s' "$GH_STATUS" | grep -i 'Token scopes:' | head -1)"
    if [ -n "$SCOPES_LINE" ]; then
      MISSING=""
      for need in repo workflow user; do
        printf '%s' "$SCOPES_LINE" | grep -q "'$need'" || MISSING="${MISSING}${MISSING:+ }$need"
      done
      [ -n "$MISSING" ] && note "  ⚠ gh scopes missing: ${MISSING} (gh auth refresh -s ${MISSING// / -s })"
    fi
  else
    note "  ✗ gh auth: NOT logged in (run: gh auth login)"
  fi
fi

# 2. Critical config file existence (these load env at shell startup)
CONFIG_FILES=(
  "$HOME/.config/ntfy/.env|ntfy notification env"
  "$HOME/.config/exa-mcp/start.sh|Exa MCP launcher"
  "$HOME/.config/lark-mcp/start.sh|Lark MCP launcher"
  "$HOME/.config/github-mcp/start.sh|GitHub MCP launcher"
  "$HOME/.claude/getnote-mcp/start.sh|GetNote MCP launcher"
  "$HOME/.config/firecrawl/.env|Firecrawl scrape key"
)

for entry in "${CONFIG_FILES[@]}"; do
  path="${entry%%|*}"
  label="${entry##*|}"
  if [ -f "$path" ]; then
    note "  ✓ $label: present"
  else
    note "  ⚠ $label: MISSING ($path)"
  fi
done

# 3. Mode env files (Claude Code provider switching)
MODE_DIR="$HOME/.claude/cli-modes"
if [ -d "$MODE_DIR" ]; then
  count=$(ls "$MODE_DIR"/*.env 2>/dev/null | wc -l | tr -d ' ')
  note "  ✓ cli-modes: $count mode env file(s)"
else
  note "  ⚠ cli-modes dir missing: $MODE_DIR"
fi

# Output to stderr (advisory only)
if [ -n "$REPORT" ]; then
  printf "%b" "$REPORT" >&2
fi

exit 0
