#!/usr/bin/env bash
# Read Cache Invalidator — clears cache for modified files
# Runs as PostToolUse hook on Edit/Write

SESSION_KEY="${TERM_SESSION_ID:-default}"
CACHE_DIR="/tmp/claude-read-cache-${SESSION_KEY}"
[ ! -d "$CACHE_DIR" ] && exit 0

# On any file modification, clear entire read cache
# This is aggressive but safe — cache rebuilds naturally on next reads
# Typical cache has <20 entries, clearing is instant
rm -f "$CACHE_DIR"/* 2>/dev/null

exit 0
