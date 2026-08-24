#!/bin/bash
# Shared reliability helpers for the Tony Articles generation/publish pipeline.
# Safe to source from launchd jobs. It never changes proxy nodes, credentials,
# article content, Git history, or Feishu state.

DAILY_PROXY_URL="${DAILY_PROXY_URL:-http://127.0.0.1:7897}"
DAILY_PROXY_HOST="${DAILY_PROXY_HOST:-127.0.0.1}"
DAILY_PROXY_PORT="${DAILY_PROXY_PORT:-7897}"
DAILY_CC_SWITCH_HEALTH="${DAILY_CC_SWITCH_HEALTH:-http://127.0.0.1:15721/health}"
DAILY_PREFLIGHT_REPAIR="${DAILY_PREFLIGHT_REPAIR:-1}"

daily_common_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$*"
  else
    printf '[daily-publish] %s\n' "$*" >&2
  fi
}

daily_export_proxy() {
  export HTTP_PROXY="$DAILY_PROXY_URL" HTTPS_PROXY="$DAILY_PROXY_URL" ALL_PROXY="$DAILY_PROXY_URL"
  export http_proxy="$DAILY_PROXY_URL" https_proxy="$DAILY_PROXY_URL" all_proxy="$DAILY_PROXY_URL"
  export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}"
  export no_proxy="${no_proxy:-$NO_PROXY}"
}

daily_proxy_ready() {
  nc -z -w 2 "$DAILY_PROXY_HOST" "$DAILY_PROXY_PORT" >/dev/null 2>&1
}

daily_restart_clash() {
  [ "$DAILY_PREFLIGHT_REPAIR" = "1" ] || return 1
  [ -d "/Applications/Clash Verge.app" ] || return 1
  daily_common_log "代理端口未就绪；仅重启 Clash Verge 应用与核心（不改节点/订阅）"
  /usr/bin/osascript -e 'tell application "Clash Verge" to quit' >/dev/null 2>&1 || true
  local i
  for i in 1 2 3 4 5; do
    pgrep -x clash-verge >/dev/null 2>&1 || break
    sleep 1
  done
  /usr/bin/open -a "Clash Verge" >/dev/null 2>&1 || return 1
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    daily_proxy_ready && return 0
    sleep 1
  done
  return 1
}

daily_http_code() {
  local url="$1"
  curl -x "$DAILY_PROXY_URL" -L -sS -o /dev/null \
    --connect-timeout 6 --max-time 20 -w '%{http_code}' "$url" 2>/dev/null || true
}

daily_github_ready() {
  local i code
  for i in 1 2 3; do
    code="$(daily_http_code https://github.com/)"
    case "$code" in
      2??|3??) return 0 ;;
    esac
    sleep "$i"
  done
  return 1
}

daily_cc_switch_ready() {
  curl -fsS --connect-timeout 3 --max-time 6 "$DAILY_CC_SWITCH_HEALTH" 2>/dev/null |
    grep -q '"status":"healthy"'
}

daily_restart_cc_switch() {
  [ "$DAILY_PREFLIGHT_REPAIR" = "1" ] || return 1
  [ -d "/Applications/CC Switch.app" ] || return 1
  daily_common_log "检测到 CC Switch 供应商熔断；仅重启应用以清理瞬时断路状态（不改渠道配置）"
  /usr/bin/osascript -e 'tell application "CC Switch" to quit' >/dev/null 2>&1 || true
  local i
  for i in 1 2 3 4 5; do
    pgrep -x "CC Switch" >/dev/null 2>&1 || break
    sleep 1
  done
  /usr/bin/open -a "CC Switch" >/dev/null 2>&1 || return 1
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    daily_cc_switch_ready && return 0
    sleep 1
  done
  return 1
}

daily_infra_preflight() {
  local context="${1:-daily-publish}"
  local require_cc_switch="${2:-1}"
  if ! daily_proxy_ready; then
    daily_restart_clash || {
      daily_common_log "FATAL: $context 基础设施预检失败：代理 $DAILY_PROXY_HOST:$DAILY_PROXY_PORT 未监听"
      return 1
    }
  fi
  daily_export_proxy
  if ! daily_github_ready; then
    if [ "$DAILY_PREFLIGHT_REPAIR" = "1" ]; then
      daily_restart_clash || true
      daily_export_proxy
    fi
    daily_github_ready || {
      daily_common_log "FATAL: $context 基础设施预检失败：GitHub 经本机代理不可达"
      return 1
    }
  fi
  if [ "$require_cc_switch" = "1" ] && ! daily_cc_switch_ready; then
    if [ "$DAILY_PREFLIGHT_REPAIR" = "1" ] && [ -d "/Applications/CC Switch.app" ]; then
      /usr/bin/open -a "CC Switch" >/dev/null 2>&1 || true
      sleep 3
    fi
    daily_cc_switch_ready || {
      daily_common_log "FATAL: $context 基础设施预检失败：CC Switch 15721 健康检查未通过"
      return 1
    }
  fi
  if [ "$require_cc_switch" = "1" ]; then
    daily_common_log "$context 基础设施预检通过：proxy/GitHub/CC Switch"
  else
    daily_common_log "$context 基础设施预检通过：proxy/GitHub（本阶段不依赖 CC Switch）"
  fi
  return 0
}

daily_getnote_preflight() {
  local codex_bin="${1:-codex}"
  [ -r "$HOME/.config/getnote/.env" ] || {
    daily_common_log "FATAL: GetNote 环境文件缺失或不可读"
    return 1
  }
  "$codex_bin" mcp list 2>/dev/null |
    awk '$1=="getnote" && $0 ~ /enabled/ {found=1} END {exit !found}' || {
      daily_common_log "FATAL: Codex MCP 列表中 GetNote 未启用"
      return 1
    }
  daily_common_log "GetNote 配置预检通过（凭据内容未读取）"
}

daily_git_retry() {
  local attempt rc=1
  for attempt in 1 2 3; do
    git -c "http.proxy=$DAILY_PROXY_URL" "$@" && return 0
    rc=$?
    daily_common_log "Git $1 第 $attempt 次失败（rc=$rc），将按边界重试"
    sleep $((attempt * 3))
  done
  return "$rc"
}

daily_transient_failure_file() {
  local file="$1"
  grep -qiE '所有供应商|熔断|503 Service Unavailable|502 Bad Gateway|504 Gateway Timeout|SSL_ERROR_SYSCALL|stream disconnected|Reconnecting\.\.\.|request timed out|connection timed out|connection refused|error sending request|transport channel closed' "$file" 2>/dev/null
}

daily_repair_transient_failure() {
  local file="$1"
  if grep -qiE '所有供应商|熔断|127\.0\.0\.1:15721|503 Service Unavailable' "$file" 2>/dev/null; then
    daily_restart_cc_switch || true
  fi
  if grep -qiE 'SSL_ERROR_SYSCALL|stream disconnected|Reconnecting\.\.\.|request timed out|connection timed out|connection refused|error sending request|transport channel closed' "$file" 2>/dev/null; then
    daily_restart_clash || true
    daily_export_proxy
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  daily_infra_preflight "standalone-check"
fi
