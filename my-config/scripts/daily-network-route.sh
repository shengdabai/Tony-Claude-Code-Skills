#!/bin/bash
# Bounded Clash Verge route repair for unattended Tony Articles generation.
# It changes only the two existing selector choices and never edits subscriptions.

daily_chatgpt_ready() {
  local i code
  for i in 1 2 3; do
    code="$(daily_http_code https://chatgpt.com/)"
    case "$code" in
      2??|3??|401|403) return 0 ;;
    esac
    sleep "$i"
  done
  return 1
}

daily_switch_selector_to_working_node() {
  local group="$1" target_url="$2"
  shift 2
  local socket="/tmp/verge/verge-mihomo.sock" candidate encoded delay group_encoded previous target_encoded
  [ "$DAILY_PREFLIGHT_REPAIR" = "1" ] || return 1
  [ -S "$socket" ] || return 1
  group_encoded="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$group")" || return 1
  target_encoded="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$target_url")" || return 1
  previous="$(curl --unix-socket "$socket" -sS http://localhost/proxies 2>/dev/null |
    python3 -c 'import json,sys; print((json.load(sys.stdin).get("proxies",{}).get(sys.argv[1],{}) or {}).get("now", ""))' "$group" 2>/dev/null)"
  for candidate in "$@"; do
    encoded="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$candidate")" || continue
    delay="$(curl --unix-socket "$socket" -sS --max-time 12 \
      "http://localhost/proxies/${encoded}/delay?timeout=10000&url=${target_encoded}" 2>/dev/null |
      python3 -c 'import json,sys; print(int(json.load(sys.stdin).get("delay",0)))' 2>/dev/null || true)"
    [ "${delay:-0}" -gt 0 ] 2>/dev/null || continue
    curl --unix-socket "$socket" -sS -X PUT -H 'Content-Type: application/json' \
      -d "{\"name\":\"${candidate}\"}" "http://localhost/proxies/${group_encoded}" >/dev/null 2>&1 || continue
    daily_common_log "代理选择器 ${group}: ${previous:-<unknown>} -> ${candidate}（目标探测 ${delay}ms）"
    return 0
  done
  return 1
}

daily_generation_preflight() {
  local context="${1:-daily-generation}"
  if ! daily_infra_preflight "$context" 0; then
    daily_switch_selector_to_working_node "🌍海外出口" "https://github.com/" \
      JP-B Webshare JP-A US-H US-S US-G VN-A US-N || return 1
    daily_infra_preflight "$context" 0 || return 1
  fi
  if ! daily_chatgpt_ready; then
    daily_switch_selector_to_working_node "🤖OpenAI专用" "https://chatgpt.com/" \
      US-N US-G US-H JP-A US-A SG-A TW-A || return 1
    daily_chatgpt_ready || return 1
  fi
  daily_common_log "$context 生成端预检通过：GitHub/ChatGPT，且不依赖 CC Switch"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  # shellcheck source=$HOME/.claude/scripts/daily-publish-common.sh
  source "$HOME/.claude/scripts/daily-publish-common.sh"
  daily_generation_preflight "standalone-generation-check"
fi
