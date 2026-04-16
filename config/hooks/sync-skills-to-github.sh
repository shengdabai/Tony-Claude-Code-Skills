#!/usr/bin/env bash
# Post-session hook: auto-sync all Claude Code config to GitHub
# Runs at Stop hook — delegates to config-sync for comprehensive sync

CONFIG_SYNC="$HOME/.claude/tools/config-sync.sh"

# Check if config-sync exists
[ -x "$CONFIG_SYNC" ] || exit 0

# Run sync in background (don't block session end)
$CONFIG_SYNC > /dev/null 2>&1 &

exit 0
