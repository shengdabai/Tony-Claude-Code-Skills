#!/bin/bash
# CLI 自动更新：Codex 官方 standalone installer + antigravity (agy 自带 update)
# 由 launchd com.tony.cli-auto-update 每日触发
set -uo pipefail

LOG_DIR="${CLI_AUTO_UPDATE_LOG_DIR:-$HOME/.claude/logs}"
mkdir -p "$LOG_DIR"
LOG="${CLI_AUTO_UPDATE_LOG:-$LOG_DIR/cli-auto-update.log}"
mkdir -p "$(dirname "$LOG")"

# 绝对 node/npm 路径，规避 NVM lazy-loading 导致 PATH 解析失败
NODE_BIN="$HOME/.nvm/versions/node/v24.14.0/bin"
BREW_NODE_BIN="/opt/homebrew/bin"
AGY="${AGY:-$HOME/.local/bin/agy}"
CODEX="${CODEX:-$HOME/.local/bin/codex}"
CODEX_INSTALL_DIR="${CODEX_INSTALL_DIR:-$HOME/.local/bin}"
CODEX_HOME_DIR="${CODEX_HOME_DIR:-$HOME/.codex}"
CODEX_INSTALLER_URL="${CODEX_INSTALLER_URL:-https://chatgpt.com/codex/install.sh}"
CODEX_INSTALLER_TIMEOUT="${CODEX_INSTALLER_TIMEOUT:-600}"
export PATH="$HOME/.local/bin:$NODE_BIN:$BREW_NODE_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
export HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:7897}" HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:7897}"
export ALL_PROXY="${ALL_PROXY:-socks5://127.0.0.1:7897}" NO_PROXY="127.0.0.1,localhost,::1,*.local"

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" >>"$LOG"; }

log "=== cli-auto-update start ==="
FAILURES=0
INSTALLER_TMP=""
cleanup() {
  [ -z "$INSTALLER_TMP" ] || rm -f "$INSTALLER_TMP"
}
trap cleanup EXIT
trap 'cleanup; exit 130' HUP INT TERM

update_codex_standalone() {
  local before after installer
  before=$("$CODEX" --version 2>/dev/null || true)
  installer="$(mktemp "${TMPDIR:-/tmp}/codex-install.XXXXXX")" || {
    log "codex: cannot create installer temp file"
    FAILURES=$((FAILURES + 1))
    return
  }
  INSTALLER_TMP="$installer"
  if ! curl -fsSL --connect-timeout 15 --max-time 120 "$CODEX_INSTALLER_URL" -o "$installer"; then
    log "codex: official installer download FAILED; keeping ${before:-current install}"
    rm -f "$installer"
    FAILURES=$((FAILURES + 1))
    return
  fi
  if ! env CODEX_NON_INTERACTIVE=1 CODEX_INSTALL_DIR="$CODEX_INSTALL_DIR" CODEX_HOME="$CODEX_HOME_DIR" \
      /usr/bin/perl -e 'alarm shift; exec @ARGV' "$CODEX_INSTALLER_TIMEOUT" /bin/sh "$installer" >>"$LOG" 2>&1; then
    log "codex: official standalone update FAILED; keeping ${before:-current install}"
    "$CODEX" --version >/dev/null 2>&1 || log "codex: install failed and the existing binary is BROKEN"
    rm -f "$installer"
    FAILURES=$((FAILURES + 1))
    return
  fi
  rm -f "$installer"
  INSTALLER_TMP=""
  after=$("$CODEX" --version 2>/dev/null || true)
  if ! printf '%s\n' "$after" | grep -Eq '^codex-cli [0-9]+\.[0-9]+\.[0-9]+'; then
    log "codex: post-update version probe FAILED"
    FAILURES=$((FAILURES + 1))
    return
  fi
  if [ "$CODEX" = "$HOME/.local/bin/codex" ] && [ "$(command -v codex 2>/dev/null)" != "$CODEX" ]; then
    log "codex: standalone path is not the active command"
    FAILURES=$((FAILURES + 1))
    return
  fi
  if [ "$before" = "$after" ]; then
    log "codex: already latest ($after)"
  else
    log "codex: updated ${before:-missing} -> $after"
  fi
}

# --- Codex standalone (stable ~/.local/bin/codex symlink) ---
update_codex_standalone

# --- antigravity (agy) ---
if [ -x "$AGY" ]; then
  CUR=$("$AGY" --version 2>/dev/null)
  if "$AGY" update >>"$LOG" 2>&1; then
    NEW=$("$AGY" --version 2>/dev/null || true)
    if [ -z "$NEW" ]; then
      log "agy: update returned success but version probe FAILED"
      FAILURES=$((FAILURES + 1))
    elif [ "$CUR" != "$NEW" ]; then
      log "agy: updated $CUR -> $NEW"
    else
      log "agy: already latest ($CUR)"
    fi
  else
    log "agy: update FAILED"
    FAILURES=$((FAILURES + 1))
  fi
else
  log "agy: not found at $AGY, skip"
fi

log "=== cli-auto-update done ==="
[ "$FAILURES" -eq 0 ]
