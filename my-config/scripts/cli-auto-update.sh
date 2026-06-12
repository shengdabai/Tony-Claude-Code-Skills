#!/bin/bash
# CLI 自动更新：codex (npm) + antigravity (agy 自带 update)
# 由 launchd com.tony.cli-auto-update 每日触发
set -uo pipefail

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/cli-auto-update.log"

# 绝对 node/npm 路径，规避 NVM lazy-loading 导致 PATH 解析失败
NODE_BIN="$HOME/.nvm/versions/node/v24.14.0/bin"
NPM="$NODE_BIN/npm"
AGY="$HOME/.local/bin/agy"

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >>"$LOG"; }

log "=== cli-auto-update start ==="

# --- codex (@openai/codex) ---
if [ -x "$NPM" ]; then
  CUR=$("$NODE_BIN/codex" --version 2>/dev/null | awk '{print $NF}')
  LATEST=$("$NPM" view @openai/codex version 2>/dev/null)
  if [ -n "$LATEST" ] && [ "$CUR" != "$LATEST" ]; then
    log "codex: $CUR -> $LATEST, updating..."
    if "$NPM" install -g @openai/codex@latest >>"$LOG" 2>&1; then
      NEW=$("$NODE_BIN/codex" --version 2>/dev/null | awk '{print $NF}')
      log "codex: updated to $NEW"
    else
      log "codex: update FAILED"
    fi
  else
    log "codex: already latest ($CUR)"
  fi
else
  log "codex: npm not found at $NPM, skip"
fi

# --- antigravity (agy) ---
if [ -x "$AGY" ]; then
  CUR=$("$AGY" --version 2>/dev/null)
  if "$AGY" update >>"$LOG" 2>&1; then
    NEW=$("$AGY" --version 2>/dev/null)
    if [ "$CUR" != "$NEW" ]; then
      log "agy: updated $CUR -> $NEW"
    else
      log "agy: already latest ($CUR)"
    fi
  else
    log "agy: update FAILED"
  fi
else
  log "agy: not found at $AGY, skip"
fi

log "=== cli-auto-update done ==="
exit 0
