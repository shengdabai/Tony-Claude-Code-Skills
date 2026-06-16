#!/bin/bash
# reap-codex-turn-ended.sh
# 清理泄漏的 Codex Computer Use "turn-ended" 通知进程。
# 这些进程由 Codex 每轮 turn 结束触发,本应秒退,但会卡死堆积(实测见过 186 个 / 单个存活 8 天),
# 拖累进程表与 fork/spawn(飞书 claude -p 每条消息都 fork)。
# 只清理存活 > 阈值的,给刚产生的正常进程留退出窗口。
# 只读匹配独特字符串 'SkyComputerUseClient turn-ended',绝不误伤 claude/codex 主进程。

set -euo pipefail

THRESHOLD_MIN=5                       # 只杀存活超过这么多分钟的
PATTERN='SkyComputerUseClient turn-ended'
LOG="${HOME}/.claude/logs/reap-codex-turn-ended.log"
mkdir -p "$(dirname "$LOG")"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

# 把 etime (mm:ss | hh:mm:ss | dd-hh:mm:ss) 转成总秒数
etime_to_sec() {
  local e="$1" days=0 hms
  if [[ "$e" == *-* ]]; then
    days="${e%%-*}"; hms="${e#*-}"
  else
    hms="$e"
  fi
  local IFS=:; read -ra p <<< "$hms"
  local sec=0
  if   [[ ${#p[@]} -eq 3 ]]; then sec=$((10#${p[0]}*3600 + 10#${p[1]}*60 + 10#${p[2]}))
  elif [[ ${#p[@]} -eq 2 ]]; then sec=$((10#${p[0]}*60 + 10#${p[1]}))
  else sec=$((10#${p[0]})); fi
  echo $(( days*86400 + sec ))
}

killed=0
threshold_sec=$(( THRESHOLD_MIN * 60 ))

while read -r pid etime; do
  [[ -z "${pid:-}" ]] && continue
  age=$(etime_to_sec "$etime")
  if (( age > threshold_sec )); then
    # 防 PID 重用竞态:kill 前再确认该 PID 仍是 turn-ended 进程
    cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
    if [[ "$cmd" == *"$PATTERN"* ]] && kill "$pid" 2>/dev/null; then
      killed=$((killed+1))
    fi
  fi
done < <(ps -axo pid,etime,command | grep "$PATTERN" | grep -v grep | awk '{print $1, $2}')

# 给 SIGTERM 一点时间,残留的强杀
sleep 2
while read -r pid etime; do
  [[ -z "${pid:-}" ]] && continue
  age=$(etime_to_sec "$etime")
  if (( age > threshold_sec )); then
    cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
    [[ "$cmd" == *"$PATTERN"* ]] && kill -9 "$pid" 2>/dev/null || true
  fi
done < <(ps -axo pid,etime,command | grep "$PATTERN" | grep -v grep | awk '{print $1, $2}')

remaining=$(ps -axo command | grep "$PATTERN" | grep -vc grep || true)
echo "$(ts) reaped=$killed remaining=$remaining (threshold=${THRESHOLD_MIN}m)" >> "$LOG"

# 日志滚动,只留最后 500 行
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 600 ]]; then
  tail -n 500 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
