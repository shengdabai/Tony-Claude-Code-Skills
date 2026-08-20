#!/usr/bin/env bash
# mem-guardian — 自动内存守护
# 设计原则:
#   1. 只在 compressor 真实超阈(默认7500MB)时动手; swap绝对值在本机是加密残留不可靠（平时完全静默）
#   2. 正向白名单保护工作进程（Claude/MCP/Hermes/OpenClaw/node 都不碰）
#   3. 只通过 osascript 优雅退出 Electron 应用，禁止 kill -9 工作类进程
#   4. 所有操作记日志，可审计
#   5. 支持 dry-run

set -u

# launchd 默认 locale 常为 C/POSIX,会把日志串里全角标点(如 ，)的首字节
# 并进前面的变量名 → "$ppid，" 被解析成未定义变量 → set -u 报 unbound 中断。
# 强制 UTF-8 locale 一次性根治所有 CJK 相邻变量展开问题。
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

LOG_DIR="$HOME/.claude/scripts/logs"
LOG_FILE="$LOG_DIR/mem-guardian.log"
mkdir -p "$LOG_DIR"

# ============ 配置 ============
DRY_RUN="${MEM_GUARDIAN_DRY_RUN:-0}"           # 1=只记录不执行, 0=真实执行
SWAP_THRESHOLD="${MEM_GUARDIAN_SWAP_PCT:-95}"  # swap%触发阈; 默认95=实际禁用(本机swap是encrypted陈旧残留,不反映实时压力,靠compressor判据)
# 36GB 机器:6GB compressor + 71% 空闲属正常,5000 会每 8 分钟假触发空转。
# 提到 7500 让 guardian 只在真正压力(坏 episode 时 comp 常冲 8G+)下动手。
COMP_THRESHOLD_MB="${MEM_GUARDIAN_COMP_MB:-7500}"

# ============ 工作进程白名单（绝对不动） ============
# 这些进程/路径出现时，立即跳过，永不触碰
PROTECT_PATTERNS=(
  "node"                         # 所有 node 进程（MCP、Hermes、OpenClaw）
  "claude"                       # Claude CLI 会话
  "codex"                        # Codex CLI / MCP
  "gemini"                       # Gemini CLI
  "tmux"                         # 终端会话
  "smux"                         # 团队会话
  "ssh"                          # SSH 连接
  "ports"                        # port-whisperer
  "hermes"                       # Hermes 服务
  "openclaw"                     # OpenClaw 服务
  "gateway"                      # Hermes gateway
  "gbrain"                       # gbrain 本地脑
  "ralph"                        # ralph workflow
  "Hermes"
  "ai.hermes"
  "Cursor"                       # Cursor 编辑器（你正在用，不能动）
  "Code"                         # VS Code
  "iTerm"                        # 终端
  "Terminal"
  "Warp"
  "Obsidian"                     # 你的笔记
  "Lark"                         # 飞书
  "WeCom"                        # 企业微信
  "OrbStack"                     # 容器
  "Docker"
  "OmniFocus"
  "Mail"
  "Safari"                       # 主浏览器
  "Chrome"
)

# ============ 可优雅退出的 Electron 应用（按 swap 压力依次退）============
# 这些是「需要时再开」的应用，触发后会按顺序 osascript quit
# 仅在系统压力高时操作，且通过 macOS 标准 quit 信号（用户有未保存内容会提示）
RECYCLABLE_APPS=(
  "Genspark"          # 第一个退（你这台机器上开了 49 个进程）
)

# ============ 工具函数 ============
log() {
    local ts msg
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    msg="$*"
    echo "[$ts] $msg" >> "$LOG_FILE"
}

log_info() { log "INFO  $*"; }
log_warn() { log "WARN  $*"; }
log_act()  { log "ACT   $*"; }
log_skip() { log "SKIP  $*"; }

# 检查 PID 是否在白名单
is_protected_pid() {
    local pid="$1"
    local cmd
    cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
    [ -z "$cmd" ] && return 0  # 进程已不存在，视为受保护
    for pattern in "${PROTECT_PATTERNS[@]}"; do
        if echo "$cmd" | grep -q "$pattern"; then
            return 0  # 受保护
        fi
    done
    return 1  # 不受保护
}

# 优雅退出应用（仅对 RECYCLABLE_APPS）
graceful_quit() {
    local app="$1"
    local count
    # macOS BSD pgrep 没有 -c(count) 选项(那是 Linux pgrep),且不带 -f 只匹配
    # comm 字段,匹配不到 "Genspark Helper" 这类带空格子进程 → 历史 bug:永远判"未运行"。
    # 改用 -f 全命令匹配 + wc -l 计数,macOS/Linux 通用。
    count=$(pgrep -f "$app" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${count:-0}" -eq 0 ]; then
        log_skip "$app 未运行"
        return 0
    fi

    log_warn "$app 有 $count 个进程，准备优雅退出"
    if [ "$DRY_RUN" = "1" ]; then
        log_act "[DRY-RUN] 将执行: osascript -e 'quit app \"$app\"'"
        return 0
    fi

    # 二次保护：确认这个 app 名不在 PROTECT_PATTERNS 里
    for pattern in "${PROTECT_PATTERNS[@]}"; do
        if [ "$app" = "$pattern" ]; then
            log_skip "$app 在白名单内，拒绝退出"
            return 1
        fi
    done

    osascript -e "quit app \"$app\"" 2>/dev/null || true
    log_act "已发送 quit 信号给 $app"
    sleep 5

    # 还有残留？再等一次
    count=$(pgrep -f "$app" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${count:-0}" -gt 0 ]; then
        log_warn "$app 仍有 $count 个进程残留（可能用户取消了退出）"
    else
        log_info "$app 已完全退出"
    fi
}

# 获取当前 swap 使用百分比
get_swap_pct() {
    local line used total
    line=$(sysctl -n vm.swapusage 2>/dev/null || true)
    used=$(echo "$line" | awk '{print $6}' | tr -d 'M')
    total=$(echo "$line" | awk '{print $3}' | tr -d 'M')
    awk -v used="$used" -v total="$total" 'BEGIN {
        if (used == "" || total == "" || (total + 0) <= 0) {
            print 0
            exit
        }
        printf "%.0f", (used + 0) / (total + 0) * 100
    }'
}

# 获取 compressor MB
get_compressor_mb() {
    local pages
    pages=$(vm_stat | awk '/Pages occupied by compressor/ {gsub(/\./,"",$5); print $5}')
    case "$pages" in
        ''|*[!0-9]*) echo 0 ;;
        *) echo $((pages * 16 / 1024)) ;;
    esac
}

# 是否仍超阈值(swap 或 compressor 任一超标都算"仍有压力")。
# 历史根因 bug:原"已恢复"判断与 reap 升级门槛都只看 swap,导致
# compressor 驱动的压力(swap 仍低)下 guardian 早退、reap 永不触发。
still_over() {
    local sp cp
    sp=$(get_swap_pct)
    cp=$(get_compressor_mb)
    if [ "$sp" -ge "$SWAP_THRESHOLD" ] || [ "$cp" -ge "$COMP_THRESHOLD_MB" ]; then
        return 0   # 仍有压力
    fi
    return 1       # 两项都已回落
}

# ============ 主流程 ============
main() {
    local swap_pct comp_mb
    swap_pct=$(get_swap_pct)
    comp_mb=$(get_compressor_mb)

    # 未达到阈值，静默退出
    if [ "$swap_pct" -lt "$SWAP_THRESHOLD" ] && [ "$comp_mb" -lt "$COMP_THRESHOLD_MB" ]; then
        return 0
    fi

    log_info "swap=${swap_pct}% compressor=${comp_mb}MB threshold_swap=${SWAP_THRESHOLD}% threshold_comp=${COMP_THRESHOLD_MB}MB dry_run=${DRY_RUN}"
    log_warn "触发阈值: swap=${swap_pct}% comp=${comp_mb}MB — 开始清理"

    # 依次尝试退出可回收应用
    for app in "${RECYCLABLE_APPS[@]}"; do
        graceful_quit "$app"

        # 每退一个就检查是否已经缓解(macOS 回收 page 需几秒,沉降 5s 再测,
        # 否则刚 quit 立即重测会读到旧 swap,"已恢复"早退逻辑失灵)
        sleep 5
        swap_pct=$(get_swap_pct)
        comp_mb=$(get_compressor_mb)
        log_info "退出 $app 后: swap=${swap_pct}% compressor=${comp_mb}MB"
        # 必须 swap 与 compressor 都回落才算恢复;只看 swap 会在 compressor
        # 仍高时早退,跳过后续 MCP 清理 + reap 升级(历史复发根因)。
        if ! still_over; then
            log_info "swap+compressor 均回落到阈值以下，停止清理"
            return 0
        fi
    done

    # 清理跑了 >3 天的僵尸 MCP（只动 mcp-server 类，且不在白名单的）
    log_info "扫描 >3 天的僵尸 MCP 进程"
    while read -r pid etime cmd; do
        [ -z "$pid" ] && continue
        # 解析天数
        local days=0
        if [[ "$etime" == *-* ]]; then
            days=${etime%%-*}
        fi
        if [ "$days" -lt 3 ]; then
            continue
        fi
        # 二次确认是 MCP 类
        if ! echo "$cmd" | grep -qE "mcp-server|mcp@|oh-my-claudecode/bridge"; then
            continue
        fi
        # 检查是否是当前活跃 Claude CLI 的子进程
        local ppid
        ppid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
        if [ -n "$ppid" ] && [ "$ppid" != "1" ]; then
            # 有活的父进程，可能仍在用，跳过
            log_skip "PID ${pid} 有活跃父进程 ${ppid}，跳过"
            continue
        fi
        log_warn "孤儿 MCP: PID $pid, ${days}天, $(echo $cmd | cut -c1-80)"
        if [ "$DRY_RUN" = "1" ]; then
            log_act "[DRY-RUN] 将 kill -TERM $pid"
        else
            kill -TERM "$pid" 2>/dev/null && log_act "已 kill -TERM $pid"
        fi
    done < <(ps -axo pid,etime,command | awk '/mcp-server|mcp@|oh-my-claudecode\/bridge/ && !/awk/ {print $1, $2, substr($0, index($0, $3))}')

    # ============ 升级兜底:swap 仍高 + claude CLI 会话堆积 → 回收过老闲置会话 ============
    # 解决 mem-guardian 盲区:Electron/MCP 清完仍高时,压力多来自堆积的 claude CLI 会话。
    # 保守策略:仅当 ≥4 个 CLI 会话(堆积特征)且 swap 仍超阈值时,reap >12h 的老会话。
    # SIGTERM 优雅退出(可 claude --continue 恢复)+ reap-keep.txt 白名单双保险。
    # 升级门槛同样改为 swap 或 compressor 任一仍超标即触发(原只看 swap,
    # compressor 驱动压力下 reap 永不执行 = 复发根因之一)。
    if still_over; then
        swap_pct=$(get_swap_pct)
        comp_mb=$(get_compressor_mb)
        local cli_count
        cli_count=$(ps -axo command= | grep -cE '/\.local/bin/claude($| )')
        if [ "${cli_count:-0}" -ge 4 ] && [ -x "$HOME/.claude/scripts/claude-reap.sh" ]; then
            log_warn "压力仍在(swap=${swap_pct}% comp=${comp_mb}MB)且 ${cli_count} 个 claude CLI 会话堆积 — 调用 claude-reap 12h"
            if [ "$DRY_RUN" = "1" ]; then
                bash "$HOME/.claude/scripts/claude-reap.sh" 12h --dry 2>&1 | while IFS= read -r l; do log_act "[reap] $l"; done
            else
                bash "$HOME/.claude/scripts/claude-reap.sh" 12h 2>&1 | while IFS= read -r l; do log_act "[reap] $l"; done
            fi
        elif [ "${cli_count:-0}" -ge 4 ]; then
            log_skip "claude-reap.sh 不存在或不可执行,跳过会话回收"
        fi
    fi

    swap_pct=$(get_swap_pct)
    comp_mb=$(get_compressor_mb)
    log_info "完成: swap=${swap_pct}% compressor=${comp_mb}MB"
}

main "$@"
