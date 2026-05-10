#!/usr/bin/env bash
# Read Cache — blocks redundant file reads within a Claude Code session
# Saves 30-60% of Read tool tokens by preventing re-reads of unchanged files
#
# Safety:
#   - Only blocks if file mtime hasn't changed since last read
#   - Cache invalidated on Edit/Write (via read-cache-invalidate.sh)
#   - Cache scoped to session via PPID
#   - Files not on disk are always allowed (let Claude handle errors)

if ! command -v jq &>/dev/null; then
  exit 0
fi

# Session ID: TERM_SESSION_ID is stable across all hook invocations in one terminal session
SESSION_KEY="${TERM_SESSION_ID:-default}"
CACHE_DIR="/tmp/claude-read-cache-${SESSION_KEY}"
mkdir -p "$CACHE_DIR" 2>/dev/null

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# No file path = not a file read, pass through
[ -z "$FILE_PATH" ] && exit 0

# File doesn't exist = let Claude handle the error
[ ! -f "$FILE_PATH" ] && exit 0

# Get current modification time (macOS stat)
CURRENT_MTIME=$(stat -f %m "$FILE_PATH" 2>/dev/null)
[ -z "$CURRENT_MTIME" ] && exit 0

# Extract read range for cache key
OFFSET=$(echo "$INPUT" | jq -r '.tool_input.offset // "0"')
LIMIT=$(echo "$INPUT" | jq -r '.tool_input.limit // "full"')

# Cache key = hash of path + range
CACHE_KEY=$(printf '%s:%s:%s' "$FILE_PATH" "$OFFSET" "$LIMIT" | md5 -q 2>/dev/null)
[ -z "$CACHE_KEY" ] && exit 0

CACHE_FILE="$CACHE_DIR/$CACHE_KEY"

if [ -f "$CACHE_FILE" ]; then
  CACHED_MTIME=$(cat "$CACHE_FILE")
  if [ "$CACHED_MTIME" = "$CURRENT_MTIME" ]; then
    # Same file, same range, unchanged — block the redundant read
    jq -n --arg path "$(basename "$FILE_PATH")" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "block",
        "permissionDecisionReason": ("Read cache hit: " + $path + " already in context, unchanged. Use existing content.")
      }
    }'
    exit 0
  fi
fi

# First read or file changed — allow and update cache
echo "$CURRENT_MTIME" > "$CACHE_FILE"
exit 0
