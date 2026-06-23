#!/usr/bin/env bash
# webshare / 住宅 IP 稳定性监控 loop
# 2026-06-23 by Claude。配套: ~/.omc/plans/clash-residential-ip-todo.md
#
# 用途: 在终端随时验证「当前 Clash 出口 → Claude API」的稳定性,不依赖任何 AI 会话。
# 典型用法: 切到 CloudX profile + 选中 webshare 节点后,跑本脚本确认 US-E 第一跳修复是否生效。
#
# 五要素: Trigger=手动/cron | Work=curl 代理→anthropic | Verify=HTTP 405 |
#          Exit=跑完 N 轮 或 达标 | Budget=轮数/超时可配
#
# 用法:
#   webshare-stability-loop.sh            # 默认 20 轮快测,出报告
#   webshare-stability-loop.sh 50         # 50 轮
#   webshare-stability-loop.sh watch      # 持续监控模式(每 30s 一轮, Ctrl-C 停)
#   webshare-stability-loop.sh health     # 仅测 webshare 服务器本身健康(直连 webshare 凭据)

set -u
PROXY="http://127.0.0.1:7897"
API="https://api.anthropic.com/v1/messages"
TIMEOUT=12
PASS_CODE="405"   # GET 该端点返回 405 = 链路通(端点要 POST)
CFG="$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"

green(){ printf "\033[32m%s\033[0m\n" "$1"; }
red(){ printf "\033[31m%s\033[0m\n" "$1"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$1"; }

one_probe(){
  # $1=label  返回 "code|time"
  curl -s -o /dev/null -w "%{http_code}|%{time_total}" --max-time "$TIMEOUT" -x "$PROXY" "$API" 2>/dev/null
}

run_rounds(){
  local n="$1" ok=0 fail=0 sum=0 maxt=0 mint=999
  echo "=== 稳定性测试: $n 轮 (出口走当前 Clash 选中节点) ==="
  for i in $(seq 1 "$n"); do
    r=$(one_probe); code="${r%%|*}"; t="${r##*|}"
    if [ "$code" = "$PASS_CODE" ]; then
      ok=$((ok+1)); sum=$(echo "$sum + $t" | bc -l)
      awk "BEGIN{exit !($t>$maxt)}" && maxt=$t
      awk "BEGIN{exit !($t<$mint)}" && mint=$t
      printf "  #%-3s ✅ %s  %ss\n" "$i" "$code" "$t"
    else
      fail=$((fail+1)); red "  #$i ❌ $code (超时/断连)  ${t}s"
    fi
  done
  echo "----------------------------------------"
  local rate=$(awk "BEGIN{printf \"%.0f\", $ok/$n*100}")
  echo "成功率: ${ok}/${n} = ${rate}%"
  if [ "$ok" -gt 0 ]; then
    local avg=$(echo "scale=2; $sum/$ok" | bc -l)
    echo "延迟: 均 ${avg}s | 最快 ${mint}s | 最慢 ${maxt}s"
  fi
  echo ""
  if [ "$rate" -ge 95 ]; then green "✅ 达标 (≥95%): 当前出口可稳定跑 Claude Code"
  elif [ "$rate" -ge 80 ]; then yellow "⚠️ 勉强 (80-95%): 偶有断连,建议换更稳的第一跳/节点"
  else red "❌ 不达标 (<80%): 当前节点不稳, 换 webshare 第一跳节点 (US-E→US-G/US-N/US-S) 或换出口"
  fi
}

health_check(){
  echo "=== webshare 服务器本身健康检查 (直连 webshare 凭据, 验服务器非第一跳) ==="
  local srv prt usr pw
  srv=$(grep -E '^\s*server:' "$CFG/webshare-proxies.yaml" 2>/dev/null | head -1 | awk '{print $2}')
  prt=$(grep -E '^\s*port:' "$CFG/webshare-proxies.yaml" 2>/dev/null | head -1 | awk '{print $2}')
  usr=$(grep -E '^\s*username:' "$CFG/webshare-proxies.yaml" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"')
  pw=$(grep -E '^\s*password:' "$CFG/webshare-proxies.yaml" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"')
  [ -z "$srv" ] && { red "读不到 webshare 配置"; return 1; }
  echo "webshare = ${srv}:${prt} (经当前出口套娃到达)"
  local ok=0
  for i in 1 2 3 4 5; do
    r=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" --max-time 18 -x "http://${usr}:${pw}@${srv}:${prt}" "$API" 2>/dev/null)
    [ "${r%%|*}" = "$PASS_CODE" ] && { ok=$((ok+1)); green "  #$i ✅ $r"; } || red "  #$i ❌ $r"
  done
  echo "→ webshare 服务器 ${ok}/5 $([ $ok -ge 4 ] && echo '健康✅' || echo '异常❌(可能IP轮换,去 proxy.webshare.io 取新IP)')"
}

case "${1:-20}" in
  watch)
    yellow "持续监控模式, 每 30s 一轮, Ctrl-C 停止"
    while true; do
      r=$(one_probe); code="${r%%|*}"; t="${r##*|}"
      ts=$(date '+%H:%M:%S')
      [ "$code" = "$PASS_CODE" ] && green "[$ts] ✅ $code ${t}s" || red "[$ts] ❌ $code ${t}s 断连!"
      sleep 30
    done ;;
  health) health_check ;;
  ''|*[!0-9]*) run_rounds 20 ;;
  *) run_rounds "$1" ;;
esac
