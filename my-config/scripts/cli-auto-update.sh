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
BREW_NODE_BIN="/opt/homebrew/bin"
BREW_NPM="$BREW_NODE_BIN/npm"
AGY="$HOME/.local/bin/agy"
export PATH="$NODE_BIN:$BREW_NODE_BIN:/usr/bin:/bin:/usr/sbin:/sbin"

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >>"$LOG"; }

log "=== cli-auto-update start ==="

update_codex_npm() {
  local label="$1"
  local node_bin="$2"
  local npm_bin="$3"

  if [ ! -x "$npm_bin" ]; then
    log "codex($label): npm not found at $npm_bin, skip"
    return 0
  fi

  if [ ! -x "$node_bin/codex" ]; then
    log "codex($label): codex not found at $node_bin/codex, skip"
    return 0
  fi

  local cur latest new
  cur=$("$node_bin/codex" --version 2>/dev/null | awk '{print $NF}')
  latest=$("$npm_bin" view @openai/codex version 2>/dev/null)
  if [ -n "$latest" ] && [ "$cur" != "$latest" ]; then
    log "codex($label): $cur -> $latest, updating..."
    if NPM_CONFIG_PREFIX="$(dirname "$node_bin")" "$npm_bin" install -g @openai/codex@latest >>"$LOG" 2>&1; then
      new=$("$node_bin/codex" --version 2>/dev/null | awk '{print $NF}')
      log "codex($label): updated to $new"
    else
      log "codex($label): update FAILED"
    fi
  else
    log "codex($label): already latest ($cur)"
  fi
}

# --- codex (@openai/codex) ---
update_codex_npm "nvm" "$NODE_BIN" "$NPM"
update_codex_npm "homebrew" "$BREW_NODE_BIN" "$BREW_NPM"

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
