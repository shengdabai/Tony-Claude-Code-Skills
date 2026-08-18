#!/usr/bin/env bash
# netcheck-3clients.sh — Claude Code / ChatGPT 客户端 / 终端 Codex 三条网络链路一键验收
# 用法: bash ~/.claude/scripts/netcheck-3clients.sh   (只读,不改任何配置;全 PASS 退出 0)
# 判据来源: ~/.omc/plans/network-config-optimize-todo.md 的 DoD
set -u
SOCK=/tmp/verge/verge-mihomo.sock
JQ=/usr/bin/jq
PROXY=http://127.0.0.1:7897
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
fail=0
ok()   { printf '  ✅ %s\n' "$*"; }
bad()  { printf '  ❌ %s\n' "$*"; fail=1; }
warn() { printf '  ⚠️  %s\n' "$*"; }

enc() { printf '%s' "$1" | $JQ -rR @uri; }
group_now() { curl -s --unix-socket "$SOCK" "http://localhost/proxies/$(enc "$1")" 2>/dev/null | $JQ -r '.now // empty'; }
rule_for()  { curl -s --unix-socket "$SOCK" http://localhost/rules 2>/dev/null | $JQ -r --arg d "$1" '.rules[] | select(.type=="DomainSuffix" and .payload==$d) | .proxy' | head -1; }
# 经代理访问 URL,返回 "HTTP码 出口IP 国家"
probe() { # $1=url
  local code ip loc
  code=$(curl -s -o /dev/null -w '%{http_code}' -x "$PROXY" -A "$UA" --max-time 15 "$1")
  printf '%s' "$code"
}
trace_ip() { curl -s -x "$PROXY" -A "$UA" --max-time 12 "$1/cdn-cgi/trace" 2>/dev/null | awk -F= '/^ip=/{ip=$2}/^loc=/{loc=$2}END{print ip" "loc}'; }

echo "━━━ 0. 基础设施 ━━━"
if curl -s --unix-socket "$SOCK" --max-time 3 http://localhost/version >/dev/null 2>&1; then ok "mihomo 内核在线 ($(curl -s --unix-socket "$SOCK" http://localhost/version | $JQ -r .version))"; else bad "mihomo 内核不可达 ($SOCK)"; fi
nc -z -w1 127.0.0.1 7897 2>/dev/null && ok "mixed-port 7897 监听" || bad "7897 未监听"

echo "━━━ 1. ChatGPT 客户端 (chatgpt.com / openai.com) ━━━"
r=$(rule_for chatgpt.com); [ "$r" = "🤖OpenAI专用" ] && ok "规则 chatgpt.com → $r" || bad "规则 chatgpt.com → ${r:-无} (期望 🤖OpenAI专用)"
r=$(rule_for openai.com);  [ "$r" = "🤖OpenAI专用" ] && ok "规则 openai.com → $r"  || bad "规则 openai.com → ${r:-无}"
now=$(group_now "🤖OpenAI专用"); case "$now" in HK-*|RU-*|"") bad "🤖OpenAI专用 当前节点=$now (HK/RU 不受 OpenAI 支持)";; *) ok "🤖OpenAI专用 当前节点=$now";; esac
c=$(probe https://chatgpt.com/robots.txt); [ "$c" = 200 ] && ok "chatgpt.com/robots.txt HTTP $c" || bad "chatgpt.com/robots.txt HTTP $c"
c=$(probe https://api.openai.com/v1/models); [ "$c" = 401 ] && ok "api.openai.com 可达 (401=需鉴权,链路通)" || bad "api.openai.com HTTP $c"
read -r ip loc <<< "$(trace_ip https://chatgpt.com)"; [ -n "$ip" ] && ok "ChatGPT 出口 $ip ($loc)" || bad "无法读取 ChatGPT 出口"

echo "━━━ 2. Claude Code (api.anthropic.com / claude.ai) ━━━"
r=$(rule_for anthropic.com); [ "$r" = "🇺🇸Claude专用" ] && ok "规则 anthropic.com → $r" || bad "规则 anthropic.com → ${r:-无}"
now=$(group_now "🇺🇸Claude专用"); ok "🇺🇸Claude专用 当前节点=$now"
c=$(probe https://api.anthropic.com/v1/models); case "$c" in 401|400) ok "api.anthropic.com 可达 (HTTP $c=需鉴权,链路通)";; *) bad "api.anthropic.com HTTP $c";; esac
read -r ip loc <<< "$(trace_ip https://claude.ai)"; if [ "$loc" = "US" ]; then ok "Claude 出口 $ip ($loc)"; else bad "Claude 出口 $ip (${loc:-?}) — 必须是 US"; fi

echo "━━━ 3. 终端 Codex (~/.codex/config.toml) ━━━"
CFG="$HOME/.codex/config.toml"
if /usr/bin/grep -qE '127\.0\.0\.1:15721' "$CFG"; then
  if nc -z -w1 127.0.0.1 15721 2>/dev/null; then warn "codex 仍经 CC Switch 15721 (当前在线;它退出即断——待切官方直连)"; else bad "codex 指向 CC Switch 15721 但端口未监听 → 所有 codex 请求 connection refused"; fi
else
  ok "codex 不依赖本地代理进程 (无 15721 引用)"
fi
lines=$(wc -l < "$CFG"); [ "$lines" -gt 200 ] && ok "config.toml $lines 行 (完整)" || bad "config.toml 仅 $lines 行 — 疑被 CC Switch 旧快照覆盖"
# CC Switch 数据库里 codex 的接管开关必须为 0,否则它每次启动都会覆盖 config.toml/auth.json
tk=$(sqlite3 "$HOME/.cc-switch/cc-switch.db" "select enabled from proxy_config where app_type='codex';" 2>/dev/null)
case "$tk" in 0) ok "CC Switch codex 接管=关 (启动不再覆盖 ~/.codex)";; "") warn "读不到 CC Switch 数据库";; *) bad "CC Switch codex 接管=开 → 它下次启动会覆盖 config.toml/auth.json";; esac
/usr/bin/grep -qE '^model *=' "$CFG" && ok "config.toml 含 model" || bad "config.toml 缺 model 键"
lr=$($JQ -r '.last_refresh // empty' "$HOME/.codex/auth.json" 2>/dev/null)
if [ -n "$lr" ]; then
  age=$(( ( $(date +%s) - $(date -j -f '%Y-%m-%dT%H:%M:%S' "${lr%%.*}" +%s 2>/dev/null || echo 0) ) / 86400 ))
  [ "$age" -le 14 ] && ok "auth.json last_refresh ${age} 天前" || bad "auth.json last_refresh ${age} 天前 → 令牌大概率无法刷新,需 codex login"
else warn "auth.json 无 last_refresh"; fi

echo "━━━ 结果 ━━━"
[ $fail -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "有 FAIL 项"; exit 1; }
