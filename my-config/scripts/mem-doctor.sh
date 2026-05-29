#!/usr/bin/env bash
# mem-doctor — 只读诊断，随时跑，无任何副作用
# Usage: ~/.claude/scripts/mem-doctor.sh

set -u

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
warn() { printf "\033[33m%s\033[0m\n" "$*"; }
err()  { printf "\033[31m%s\033[0m\n" "$*"; }
ok()   { printf "\033[32m%s\033[0m\n" "$*"; }

bold "===== 硬件 & 内存压力 ====="
total_gb=$(sysctl -n hw.memsize | awk '{printf "%.0f", $1/1024/1024/1024}')
echo "RAM: ${total_gb} GB"

# Swap
swap_line=$(sysctl -n vm.swapusage)
swap_used=$(echo "$swap_line" | awk '{print $6}' | tr -d 'M')
swap_total=$(echo "$swap_line" | awk '{print $3}' | tr -d 'M')
swap_pct=$(awk "BEGIN{printf \"%.0f\", $swap_used/$swap_total*100}")
swap_msg="Swap: ${swap_used} MB / ${swap_total} MB (${swap_pct}%)"
if   [ "$swap_pct" -gt 70 ]; then err "🔴 $swap_msg — 严重 thrashing"
elif [ "$swap_pct" -gt 40 ]; then warn "🟡 $swap_msg — 偏高"
else ok "🟢 $swap_msg"; fi

# Compressor (page size 16K on Apple Silicon)
comp_pages=$(vm_stat | awk '/Pages occupied by compressor/ {gsub(/\./,"",$5); print $5}')
comp_mb=$((comp_pages * 16 / 1024))
if   [ "$comp_mb" -gt 6000 ]; then err "🔴 Compressor: ${comp_mb} MB — 系统在拼命压缩"
elif [ "$comp_mb" -gt 3000 ]; then warn "🟡 Compressor: ${comp_mb} MB"
else ok "🟢 Compressor: ${comp_mb} MB"; fi

echo
bold "===== Top 15 内存进程 ====="
ps -axo rss,pid,comm | awk 'NR>1 && $1>50000' | sort -rn | head -15 | \
  awk '{rss=$1; pid=$2; $1=""; $2=""; sub(/^  /,""); printf "%6.0f MB  %6s  %s\n", rss/1024, pid, $0}'

echo
bold "===== 应用进程数（Electron 容易爆炸的）====="
for app in Genspark Cursor "Claude.app" Slack Notion Obsidian Chrome Safari; do
    count=$(ps -axo command | grep -c "$app" 2>/dev/null)
    count=$((count > 0 ? count - 1 : 0))  # 减掉 grep 自身
    total_mb=$(ps -axo rss,command | grep "$app" | grep -v grep | awk '{sum+=$1} END {printf "%.0f", sum/1024}')
    [ "$count" -gt 0 ] && printf "%-15s %3d 进程  %5s MB\n" "$app" "$count" "${total_mb:-0}"
done

echo
bold "===== MCP / Node 进程 ====="
mcp_count=$(ps -axo command | grep -E "mcp-server|mcp@" | grep -v grep | wc -l | tr -d ' ')
node_count=$(ps -axo command | grep -E "^.*node " | grep -v grep | wc -l | tr -d ' ')
claude_cli=$(ps -axo command | grep "/.local/bin/claude" | grep -v grep | wc -l | tr -d ' ')
echo "MCP server 进程: $mcp_count"
echo "node 总进程:    $node_count"
echo "Claude CLI 会话: $claude_cli"

echo
bold "===== 僵尸候选（运行 >2 天的 MCP）====="
ps -axo pid,etime,rss,command | awk '
  /mcp-server|mcp@|oh-my-claudecode\/bridge/ && !/awk/ {
    # etime 格式: dd-hh:mm:ss 或 hh:mm:ss 或 mm:ss
    split($2, t, "-")
    days = (length(t) > 1) ? t[1] : 0
    if (days+0 >= 2) {
      printf "  PID %s  %s天  %5.0f MB  %s\n", $1, days, $3/1024, $4" "$5" "$6
    }
  }
'

echo
bold "===== Pageins 速率（越高越卡）====="
pi1=$(vm_stat | awk '/Pageins/ {gsub(/\./,"",$2); print $2}')
sleep 2
pi2=$(vm_stat | awk '/Pageins/ {gsub(/\./,"",$2); print $2}')
rate=$(( (pi2 - pi1) / 2 ))
if   [ "$rate" -gt 1000 ]; then err "🔴 ${rate} pages/sec — 严重 swap thrashing"
elif [ "$rate" -gt 200 ]; then  warn "🟡 ${rate} pages/sec"
else ok "🟢 ${rate} pages/sec"; fi
