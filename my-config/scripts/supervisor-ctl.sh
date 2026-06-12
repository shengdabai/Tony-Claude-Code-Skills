#!/usr/bin/env bash
# supervisor-ctl.sh — 监工开关控制
#
# 用法:
#   监工 status       查看当前模式 + 循环状态 + 最近日志
#   监工 aggressive   切到激进常开(全局)
#   监工 ledger       回到账本守门(默认)
#   监工 off          总闸关闭(连账本守门也不续跑)
#   监工 on           取消总闸关闭(回到账本守门)
#   监工 done         给当前目录打完成哨兵(下次停下时放行一次)
#   监工 reset        清空所有会话的循环计数
#
# 终端别名见 ~/.zshrc(监工 / supervisor)。

set -uo pipefail
STATE_DIR="${HOME}/.claude/state"
OFF_FLAG="${STATE_DIR}/supervisor.off"
AGGR_FLAG="${STATE_DIR}/supervisor.aggressive"
STATE_FILE="${STATE_DIR}/supervisor-loops.json"
LOG_FILE="${HOME}/.claude/logs/supervisor.log"
mkdir -p "$STATE_DIR" 2>/dev/null

cmd="${1:-status}"
case "$cmd" in
  aggressive|aggr|激进)
    rm -f "$OFF_FLAG"; : > "$AGGR_FLAG"
    echo "✅ 监工 → 激进常开(全局)。每次停下都续跑,直到 [监工:完成] 或撞上限。"
    echo "   回退: 监工 ledger"
    ;;
  ledger|账本|normal)
    rm -f "$AGGR_FLAG"
    echo "✅ 监工 → 账本守门(默认)。仅当 .omc/plans/*.md 有 [ ] 时才续跑。"
    ;;
  off|关|停)
    : > "$OFF_FLAG"
    echo "🛑 监工 → 总闸关闭。所有续跑停止(账本和激进都不生效)。"
    echo "   恢复: 监工 on"
    ;;
  on|开)
    rm -f "$OFF_FLAG"
    echo "✅ 监工 → 已恢复(账本守门)。"
    ;;
  done|完成)
    target="${2:-$PWD}"
    mkdir -p "$target/.omc" 2>/dev/null
    : > "$target/.omc/supervisor.done"
    echo "🏁 已在 $target 打完成哨兵,下次停下放行一次。"
    ;;
  reset|重置)
    echo '{}' > "$STATE_FILE"
    echo "🔄 已清空所有会话循环计数。"
    ;;
  status|状态|*)
    mode="账本守门(默认)"
    [[ -f "$AGGR_FLAG" ]] && mode="激进常开(全局)"
    [[ -f "$OFF_FLAG" ]] && mode="总闸关闭"
    echo "监工状态: $mode"
    echo "  上限: MAX_LOOPS=${SUPERVISOR_MAX_LOOPS:-默认(账本30/激进12)}  MAX_SECONDS=${SUPERVISOR_MAX_SECONDS:-7200}  STALL=${SUPERVISOR_STALL_LIMIT:-5}"
    echo "  账本时效门: LEDGER_MAX_AGE=${SUPERVISOR_LEDGER_MAX_AGE:-86400}s (仅最近此时长内改过的 ledger 才触发; 0=关)"
    if [[ -s "$STATE_FILE" ]]; then
      echo "  活跃会话计数:"
      /usr/bin/jq -r 'to_entries[]? | "    \(.key[0:12])…  count=\(.value.count) stall=\(.value.stall)"' "$STATE_FILE" 2>/dev/null | head -10
    fi
    if [[ -f "$LOG_FILE" ]]; then
      echo "  最近日志:"
      /usr/bin/tail -5 "$LOG_FILE" 2>/dev/null | /usr/bin/sed 's/^/    /'
    fi
    ;;
esac
