#!/bin/bash
# lark-bridge-reload.sh — 重新加载飞书桥接 daemon(bootout + bootstrap)
#
# 为什么不是 `launchctl kickstart -k`:kickstart 只重启进程,用的是 launchd 里已缓存的
# job 定义,plist 里新增/改动的 EnvironmentVariables 不会生效。改过 plist 必须走
# bootout + bootstrap 重新加载定义。
#
# 手动:bash ~/.claude/scripts/lark-bridge-reload.sh
set -uo pipefail

LABEL="ai.lark-channel-bridge.bot"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
LOG="$HOME/.claude/logs/lark-bridge-reload.log"
mkdir -p "$(dirname "$LOG")"

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { printf '[%s] %s\n' "$(ts)" "$*" >>"$LOG"; }

log "=== reload start ==="

if ! plutil -lint "$PLIST" >/dev/null 2>&1; then
  log "plist 语法错误,放弃 reload: $PLIST"
  exit 1
fi

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null
sleep 2
if launchctl bootstrap "$DOMAIN" "$PLIST" 2>>"$LOG"; then
  log "bootstrap ok"
else
  log "bootstrap 失败,尝试 kickstart 兜底"
  launchctl kickstart -k "$DOMAIN/$LABEL" 2>>"$LOG" || true
fi

sleep 8
if launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -Eq 'pid = [0-9]+'; then
  hard="$(launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -o 'LARK_BRIDGE_HARD_TIMEOUT_MS => [0-9]*' | head -1)"
  log "bot 已运行; ${hard:-LARK_BRIDGE_HARD_TIMEOUT_MS 未在 launchd 环境中读到}"
else
  log "bot 未运行!需人工介入: launchctl bootstrap $DOMAIN $PLIST"
fi

log "=== reload done ==="
