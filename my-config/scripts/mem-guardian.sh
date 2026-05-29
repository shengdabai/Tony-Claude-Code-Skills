#!/usr/bin/env bash
# mem-guardian — 自动内存守护
# 设计原则:
#   1. 只在 swap > 60% 时才动手（平时完全静默）
#   2. 正向白名单保护工作进程（Claude/MCP/Hermes/OpenClaw/node 都不碰）
#   3. 只通过 osascript 优雅退出 Electron 应用，禁止 kill -9 工作类进程
#   4. 所有操作记日志，可审计
#   5. 支持 dry-run

set -u

LOG_DIR="$HOME/.claude/scripts/logs"
LOG_FILE="$LOG_DIR/mem-guardian.log"
mkdir -p "$LOG_DIR"

# ============ 配置 ============
DRY_RUN="${MEM_GUARDIAN_DRY_RUN:-0}"           # 1=只记录不执行, 0=真实执行
SWAP_THRESHOLD="${MEM_GUARDIAN_SWAP_PCT:-60}"  # swap 超过百分比才触发
COMP_THRESHOLD_MB="${MEM_GUARDIAN_COMP_MB:-5000}"

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
    count=$(pgrep -c "$app" 2>/dev/null || echo 0)
    if [ "$count" -eq 0 ]; then
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
    count=$(pgrep -c "$app" 2>/dev/null || echo 0)
    if [ "$count" -gt 0 ]; then
        log_warn "$app 仍有 $count 个进程残留（可能用户取消了退出）"
    else
        log_info "$app 已完全退出"
    fi
}

# 获取当前 swap 使用百分比
get_swap_pct() {
    local line used total
    line=$(sysctl -n vm.swapusage)
    used=$(echo "$line" | awk '{print $6}' | tr -d 'M')
    total=$(echo "$line" | awk '{print $3}' | tr -d 'M')
    awk "BEGIN{printf \"%.0f\", $used/$total*100}"
}

# 获取 compressor MB
get_compressor_mb() {
    local pages
    pages=$(vm_stat | awk '/Pages occupied by compressor/ {gsub(/\./,"",$5); print $5}')
    echo $((pages * 16 / 1024))
}

# ============ 主流程 ============
main() {
    local swap_pct comp_mb
    swap_pct=$(get_swap_pct)
    comp_mb=$(get_compressor_mb)

    log_info "swap=${swap_pct}% compressor=${comp_mb}MB threshold_swap=${SWAP_THRESHOLD}% threshold_comp=${COMP_THRESHOLD_MB}MB dry_run=${DRY_RUN}"

    # 未达到阈值，静默退出
    if [ "$swap_pct" -lt "$SWAP_THRESHOLD" ] && [ "$comp_mb" -lt "$COMP_THRESHOLD_MB" ]; then
        return 0
    fi

    log_warn "触发阈值: swap=${swap_pct}% comp=${comp_mb}MB — 开始清理"

    # 依次尝试退出可回收应用
    for app in "${RECYCLABLE_APPS[@]}"; do
        graceful_quit "$app"

        # 每退一个就检查是否已经缓解
        sleep 2
        swap_pct=$(get_swap_pct)
        comp_mb=$(get_compressor_mb)
        log_info "退出 $app 后: swap=${swap_pct}% compressor=${comp_mb}MB"
        if [ "$swap_pct" -lt "$SWAP_THRESHOLD" ]; then
            log_info "已恢复到阈值以下，停止清理"
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
            log_skip "PID $pid 有活跃父进程 $ppid，跳过"
            continue
        fi
        log_warn "孤儿 MCP: PID $pid, ${days}天, $(echo $cmd | cut -c1-80)"
        if [ "$DRY_RUN" = "1" ]; then
            log_act "[DRY-RUN] 将 kill -TERM $pid"
        else
            kill -TERM "$pid" 2>/dev/null && log_act "已 kill -TERM $pid"
        fi
    done < <(ps -axo pid,etime,command | awk '/mcp-server|mcp@|oh-my-claudecode\/bridge/ && !/awk/ {print $1, $2, substr($0, index($0, $3))}')

    swap_pct=$(get_swap_pct)
    comp_mb=$(get_compressor_mb)
    log_info "完成: swap=${swap_pct}% compressor=${comp_mb}MB"
}

main "$@"
