#!/usr/bin/env bash
# mem-tamer — 给后台 Electron renderer 降 CPU 优先级
# 只 renice，永不 kill。等价于 App Tamer 的 "Slow Down" 功能。
# 对工作进程零影响（白名单保护）。

set -u

LOG_DIR="$HOME/.claude/scripts/logs"
LOG_FILE="$LOG_DIR/mem-tamer.log"
mkdir -p "$LOG_DIR"

NICE_VALUE="${MEM_TAMER_NICE:-10}"   # +10 = 明显降速但不冻结

# 目标进程：常见 Electron renderer 子进程
# 只 renice 这些应用的 Helper 子进程，不动主进程（主进程响应 UI）
TARGETS=(
  "Genspark Helper"
  "Cursor Helper"
  "Claude Helper"
  "Slack Helper"
  "Notion Helper"
  "Discord Helper"
  "Electron Helper"
)

# 白名单：以下进程绝不 renice
PROTECT=(
  "node"
  "Claude"
  "ChatGPT"
  "Codex"
  "Hermes"
  "OpenClaw"
  "gateway"
  "tmux"
  "ssh"
)

log() {
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $*" >> "$LOG_FILE"
}

is_protected() {
    local cmd="$1"
    for p in "${PROTECT[@]}"; do
        echo "$cmd" | grep -q "$p" && return 0
    done
    return 1
}

renice_count=0
skip_count=0

for target in "${TARGETS[@]}"; do
    # 找匹配的进程
    while read -r pid; do
        [ -z "$pid" ] && continue
        cmd=$(ps -p "$pid" -o command= 2>/dev/null) || continue

        # 双重保护
        if is_protected "$cmd"; then
            ((skip_count++))
            continue
        fi

        # 当前 nice 值
        current_nice=$(ps -p "$pid" -o nice= 2>/dev/null | tr -d ' ')
        if [ "$current_nice" -ge "$NICE_VALUE" ] 2>/dev/null; then
            continue  # 已经降过了，跳过
        fi

        # renice（失败也无所谓，不影响进程运行）
        if renice "$NICE_VALUE" "$pid" >/dev/null 2>&1; then
            ((renice_count++))
        fi
    done < <(pgrep -f "$target" 2>/dev/null)
done

[ "$renice_count" -gt 0 ] && log "renice +$NICE_VALUE: $renice_count 个进程，跳过 $skip_count 个受保护进程"
exit 0
