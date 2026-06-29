#!/usr/bin/env bash
# cpu-throttler — 系统 CPU 持续 >阈值 或 热节流时，把非白名单的 CPU 大户降速。
# 设计原则（与 mem-tamer/mem-guardian 一脉相承）:
#   1. 只 renice +10 + taskpolicy -b（踢到能效核 E-core），永不 kill —— 可逆、零数据丢失风险
#   2. 正向白名单：所有工作进程 / 系统关键进程绝不触碰（命中只记日志供你回看）
#   3. 触发判据 = 系统总 CPU 忙占比 ≥ 阈值（默认 80，对齐 RunCat 的总 CPU 口径）
#      或 pmset 报告 CPU 热节流（CPU_Scheduler_Limit < 100）
#   4. 全部操作记日志，可审计；支持 dry-run
#
# Loop Engineering 五要素:
#   Trigger=launchd 每 120s | Work=throttle 非白名单大户 | Verify=日志+下轮复测
#   Exit=持续守护(无终点) | Budget=每轮 top 采样 ≤4s，单轮幂等不累积

set -u
# launchd 默认 C/POSIX locale，CJK 日志串相邻变量展开会触发 set -u unbound（见 guardian 注释）
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

LOG_DIR="$HOME/.claude/scripts/logs"
LOG_FILE="$LOG_DIR/cpu-throttler.log"
mkdir -p "$LOG_DIR"

# ============ 配置（可用 launchctl setenv 临时覆盖）============
CPU_THRESHOLD="${CPU_THROTTLE_PCT:-80}"        # 系统总 CPU 忙占比触发阈（%）
PROC_MIN_CPU="${CPU_THROTTLE_PROC_MIN:-50}"    # 单进程至少占这么多 %CPU 才被处理（单核口径，可 >100）
NICE_VALUE="${CPU_THROTTLE_NICE:-10}"          # renice 目标值（+10 = 明显让路但不冻结）
MAX_TARGETS="${CPU_THROTTLE_MAX:-4}"           # 单轮最多处理几个大户
TOP_N="${CPU_THROTTLE_TOPN:-25}"               # top 取前 N 个进程
DRY_RUN="${CPU_THROTTLE_DRY_RUN:-0}"           # 1=只记录不执行

# ============ 白名单（绝不 throttle）============
# 工作进程（同 mem-guardian）+ 系统关键进程。命中白名单的大户只记日志，不动。
PROTECT_PATTERNS=(
  # —— 工作进程 ——
  "node" "claude" "codex" "gemini" "tmux" "smux" "ssh" "ports"
  "hermes" "openclaw" "gateway" "gbrain" "ralph"
  "Hermes" "ai.hermes"
  "Cursor" "Code" "iTerm" "Terminal" "Warp"
  "Obsidian" "Lark" "WeCom" "OrbStack" "Docker" "OmniFocus"
  "Mail" "Safari" "Chrome"
  # —— 系统关键进程（动了会黑屏/断连/崩溃）——
  "WindowServer" "kernel_task" "launchd" "loginwindow" "logind"
  "parsecd" "Parsec"          # 远程桌面：动了会卡顿掉线
  "backupd" "mds" "mdworker"  # Spotlight/TimeMachine：短时高峰属正常
  "coreaudiod" "powerd" "bluetoothd" "configd"
)

log() {
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $*" >> "$LOG_FILE"
}

is_protected() {
    # 大小写不敏感子串匹配：claude 也能命中 "Claude Helper"，宁可多保护不可漏保护
    local cmd; cmd=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    [ -z "$cmd" ] && return 0
    local p lp
    for p in "${PROTECT_PATTERNS[@]}"; do
        lp=$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')
        case "$cmd" in *"$lp"*) return 0 ;; esac
    done
    return 1
}

# 系统总 CPU 忙占比（100 - idle），取 top 第二个采样窗口（真实区间值）
get_system_busy() {
    local idle
    idle=$(top -l 2 -n 0 2>/dev/null | grep -E "^CPU usage" | tail -1 \
           | awk '{for(i=1;i<=NF;i++) if($i=="idle"){gsub(/%/,"",$(i-1)); print $(i-1)}}')
    [ -z "$idle" ] && { echo 0; return; }
    awk "BEGIN{printf \"%.0f\", 100-$idle}"
}

# pmset 是否报告 CPU 热节流（返回 0=节流中）
is_thermal_throttled() {
    local lim
    lim=$(pmset -g therm 2>/dev/null | awk -F= '/CPU_Scheduler_Limit/ {gsub(/ /,"",$2); print $2}')
    [ -n "$lim" ] && [ "$lim" -lt 100 ] 2>/dev/null
}

# 输出 "pid<TAB>cpu<TAB>command"，按 CPU 降序，取 top 第二采样窗口
list_cpu_hogs() {
    top -l 2 -n "$TOP_N" -o cpu -stats pid,cpu,command 2>/dev/null | awk '
        /^Processes:/ { blk++; next }
        blk>=2 && $1 ~ /^[0-9]+$/ {
            pid=$1; cpu=$2; $1=""; $2=""; cmd=$0; sub(/^[ \t]+/,"",cmd);
            print pid "\t" cpu "\t" cmd
        }'
}

throttle_one() {
    local pid="$1" cpu="$2" cmd="$3"
    local short; short=$(echo "$cmd" | cut -c1-60)
    if [ "$DRY_RUN" = "1" ]; then
        log "[DRY-RUN] 将 renice +$NICE_VALUE + taskpolicy -b: PID $pid (${cpu}% CPU) $short"
        return 0
    fi
    # renice 与 taskpolicy 各自如实记录，不谎报（Codex review 修正）
    local nice_msg tp_msg current_nice effective=0
    current_nice=$(ps -p "$pid" -o nice= 2>/dev/null | tr -d ' ')
    if [ -n "$current_nice" ] && [ "$current_nice" -lt "$NICE_VALUE" ] 2>/dev/null; then
        if renice "$NICE_VALUE" "$pid" >/dev/null 2>&1; then nice_msg="renice✓"; effective=1
        else nice_msg="renice✗(无权限)"; fi
    else
        nice_msg="renice略(已≥${NICE_VALUE}或读不到)"
    fi
    if taskpolicy -b -p "$pid" >/dev/null 2>&1; then tp_msg="taskpolicy-b✓"; effective=1
    else tp_msg="taskpolicy-b✗"; fi
    if [ "$effective" -eq 1 ]; then
        log "ACT  $nice_msg $tp_msg PID $pid (${cpu}% CPU) $short"
    else
        log "SKIP 无权限(root/系统进程，需 sudo)，未动: PID $pid (${cpu}%) [$nice_msg $tp_msg] $short"
    fi
}

main() {
    local busy thermal=0
    busy=$(get_system_busy)
    is_thermal_throttled && thermal=1

    # 既没超 CPU 阈值、也没热节流 → 静默退出（绝大多数轮次走这里，零噪音）
    if [ "$busy" -lt "$CPU_THRESHOLD" ] && [ "$thermal" -eq 0 ]; then
        return 0
    fi

    log "触发: 系统CPU=${busy}% (阈值${CPU_THRESHOLD}%) thermal_throttle=${thermal} dry_run=${DRY_RUN}"

    local acted=0 protected_hot=""
    while IFS=$'\t' read -r pid cpu cmd; do
        [ -z "$pid" ] && continue
        [ "$acted" -ge "$MAX_TARGETS" ] && break
        # CPU 不够大的不处理（用整数比较，cpu 可能是 53.2）
        awk "BEGIN{exit !($cpu >= $PROC_MIN_CPU)}" || continue
        if is_protected "$cmd"; then
            protected_hot="${protected_hot}\n  - PID $pid (${cpu}%) $(echo "$cmd" | cut -c1-50)"
            continue
        fi
        throttle_one "$pid" "$cpu" "$cmd"
        acted=$((acted+1))
    done < <(list_cpu_hogs)

    if [ "$acted" -eq 0 ]; then
        log "无非白名单大户可处理（CPU 高占用来自工作/系统进程，不触碰）"
    fi
    # 白名单内的大户也记一笔，供你判断是否手动处理
    if [ -n "$protected_hot" ]; then
        log "白名单内高占用（不动，供你回看）:$(printf '%b' "$protected_hot")"
    fi
}

main "$@"
exit 0
