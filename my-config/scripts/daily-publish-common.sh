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
  # CC Switch 于 2026-08-26 被主动卸载（残留在 ~/.cc-switch.uninstalled-20260826，
  # 原因是它反复覆盖 ~/.codex/config.toml）。这个健康检查的意义是“装了但熔断了”，
  # 对一个根本没安装的组件强制要求，只会把发布链路永久卡死——所以未安装时降级跳过。
  if [ "$require_cc_switch" = "1" ] && [ ! -d "/Applications/CC Switch.app" ]; then
    require_cc_switch=0
    daily_common_log "$context 未安装 CC Switch，跳过其健康检查（codex 直连官方端点）"
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

daily_process_age_seconds() {
  local pid="$1"
  ps -p "$pid" -o etime= 2>/dev/null | awk -F '[-:]' '
    {
      gsub(/[[:space:]]/, "")
      if (NF == 4) print ($1 * 86400) + ($2 * 3600) + ($3 * 60) + $4
      else if (NF == 3) print ($1 * 3600) + ($2 * 60) + $3
      else if (NF == 2) print ($1 * 60) + $2
    }
  '
}

daily_run_with_timeout() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
  elif [ -x /opt/homebrew/bin/gtimeout ]; then
    /opt/homebrew/bin/gtimeout "$seconds" "$@"
  else
    /usr/bin/perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
  fi
}

# Send one verified Feishu failure receipt per job/day through the Codex bot.
# The bridge deduplicates on the stable job/date id. Callers may retry freely.
daily_notify_failure_once() {
  local job="$1"
  local summary="$2"
  local work="${3:-$PWD}"
  local bridge="${DAILY_TASK_BRIDGE:-$HOME/Desktop/01-项目开发/15-飞书桥接/task-progress-bridge.py}"
  local day="${TODAY:-$(date +%F)}"
  local stable_id="${job}-${day}"
  local start_result finish_result finish_status

  if [ ! -f "$bridge" ] || ! command -v jq >/dev/null 2>&1; then
    daily_common_log "WARN: $job 飞书失败告警不可用（bridge/jq 缺失）"
    return 1
  fi

  start_result="$({
    jq -nc \
      --arg session_id "$stable_id" \
      --arg turn_id "$stable_id" \
      --arg cwd "$work" \
      --arg prompt "${job} 每日自动任务 · ${day}" \
      '{session_id:$session_id,turn_id:$turn_id,cwd:$cwd,prompt:$prompt}' |
      daily_run_with_timeout 30 env CODEX_NOTIFY_DISABLE=0 AI_TASK_NOTIFY_DISABLE=0 \
        /usr/bin/python3 "$bridge" --source codex --event UserPromptSubmit --emit-result
  } 2>/dev/null || true)"

  finish_result="$({
    jq -nc \
      --arg session_id "$stable_id" \
      --arg turn_id "$stable_id" \
      --arg cwd "$work" \
      --arg summary "$summary" \
      '{session_id:$session_id,turn_id:$turn_id,cwd:$cwd,last_assistant_message:$summary}' |
      daily_run_with_timeout 30 env CODEX_NOTIFY_DISABLE=0 AI_TASK_NOTIFY_DISABLE=0 \
        /usr/bin/python3 "$bridge" --source codex --event StopFailure --emit-result
  } 2>/dev/null || true)"

  finish_status="$(printf '%s' "$finish_result" | jq -r '.status // empty' 2>/dev/null || true)"
  case "$finish_status" in
    sent|deduped)
      daily_common_log "$job 飞书失败告警已确认（status=${finish_status}）"
      return 0
      ;;
    *)
      daily_common_log "WARN: $job 飞书失败告警未确认（start=${start_result:-empty} finish=${finish_result:-empty}）"
      return 1
      ;;
  esac
}

# --- Codex CLI 可执行性守卫 -------------------------------------------------
# 2026-08-27 事故：npm 的 optionalDependencies 在 npmmirror 源下丢了平台二进制
# (@openai/codex-darwin-arm64)，nvm 里的 codex 启动即 rc=1。生成脚本此前只检查
# 代理/GitHub/ChatGPT，不检查 codex 本身能不能跑，于是 13 轮接力在 4 秒内全部
# 烧掉，最后以“暂存区 en=0 zh=0”结束——日志里看不出真正原因，当天无推送。
# 这里把“codex 能不能跑”提前成硬预检，并在失败时做一次有界自愈。
DAILY_CODEX_FALLBACKS="${DAILY_CODEX_FALLBACKS:-$HOME/.local/bin/codex $HOME/.nvm/versions/node/v24.14.0/bin/codex}"
DAILY_CODEX_NPM="${DAILY_CODEX_NPM:-$HOME/.nvm/versions/node/v24.14.0/bin/npm}"
DAILY_CODEX_NPM_PREFIX="${DAILY_CODEX_NPM_PREFIX:-$HOME/.nvm/versions/node/v24.14.0}"

daily_codex_probe() {
  local bin="${1:-}"
  [ -n "$bin" ] || return 1
  [ -x "$bin" ] || [ -L "$bin" ] || return 1
  "$bin" --version 2>/dev/null | grep -Eq '^codex-cli [0-9]+\.[0-9]+\.[0-9]+'
}

daily_codex_repair() {
  [ "$DAILY_PREFLIGHT_REPAIR" = "1" ] || return 1
  [ -x "$DAILY_CODEX_NPM" ] || return 1
  daily_common_log "尝试有界自愈：重装 @openai/codex@latest（平台二进制缺失）"
  env NPM_CONFIG_PREFIX="$DAILY_CODEX_NPM_PREFIX" \
    /usr/bin/perl -e 'alarm shift; exec @ARGV' 300 \
    "$DAILY_CODEX_NPM" install -g @openai/codex@latest >/dev/null 2>&1
}

# 用法: daily_codex_ready <context>；成功后把可用路径写回全局 CODEX 并导出。
daily_codex_ready() {
  local context="${1:-daily-generation}"
  local candidates="${CODEX:-} ${DAILY_CODEX_FALLBACKS:-}"
  local bin=""
  local ver=""
  local round=0
  while [ "$round" -lt 2 ]; do
    round=$((round + 1))
    for bin in $candidates; do
      ver=""
      if [ -x "$bin" ] || [ -L "$bin" ]; then
        ver="$("$bin" --version 2>/dev/null || true)"
      fi
      case "$ver" in
        codex-cli\ [0-9]*)
          CODEX="$bin"
          export CODEX
          daily_common_log "$context Codex 可执行性预检通过: $bin ($ver)"
          return 0
          ;;
      esac
    done
    [ "$round" -eq 1 ] || break
    daily_common_log "WARN: $context 所有候选 codex 均无法启动，进入一次性自愈"
    daily_codex_repair || break
  done
  daily_common_log "FATAL: $context Codex CLI 不可执行（平台二进制缺失或未安装），拒绝进入接力循环"
  return 1
}

# 供接力循环内识别“二进制本身坏了”，避免把重试预算烧在必然失败的调用上。
daily_codex_binary_failure_file() {
  local file="$1"
  grep -qiE 'Missing optional dependency @openai/codex|findCodexExecutable|codex: command not found|No such file or directory.*codex' "$file" 2>/dev/null
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  daily_infra_preflight "standalone-check"
fi
