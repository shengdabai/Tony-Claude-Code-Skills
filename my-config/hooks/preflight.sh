#!/bin/bash
# preflight.sh — 长任务开工前的 10 秒环境自检
#
# 来源:/insights 报告统计,至少 5 个 session 被环境问题拖垮或整场报废:
#   - 整场 UNKNOWN_CERTIFICATE_VERIFICATION_ERROR(TLS 被中间层拦截)
#   - Bash 被 macOS TCC 挡在 Desktop/Documents 外
#   - Clash TUN 劫持导致误报"服务离线"
#   - 7 个后台爬虫进程互相竞争同一个限流站点
# 这些都是 10 秒可测、40 分钟后才发现代价极高的问题。
#
# 用法:
#   bash ~/.claude/hooks/preflight.sh          # 全部检查
#   bash ~/.claude/hooks/preflight.sh --quiet  # 只在有 FAIL/WARN 时输出
#
# 退出码: 0 = 全通过或仅 WARN;1 = 有 FAIL(不要开始长任务)

set -uo pipefail

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

PASS=0; WARN=0; FAIL=0
OUT=""

log() { OUT="${OUT}$1"$'\n'; }
ok()   { PASS=$((PASS+1)); log "  ✅ $1"; }
warn() { WARN=$((WARN+1)); log "  ⚠️  $1"; }
bad()  { FAIL=$((FAIL+1)); log "  ❌ $1"; }

log "🚦 Preflight — $(date '+%Y-%m-%d %H:%M:%S')"
log ""

# ── 1. TLS / 代理拦截 ────────────────────────────────────────
log "1) API 连通性与 TLS 完整性"
CODE=$(curl -sS --max-time 8 -o /dev/null -w '%{http_code}' https://api.anthropic.com 2>&1)
if printf '%s' "$CODE" | grep -qE '^[0-9]{3}$'; then
    ok "api.anthropic.com 可达 (HTTP $CODE),TLS 未被拦截"
else
    bad "api.anthropic.com 连接异常: ${CODE}"
    log "     → 证书类错误多半是 TUN/中间人代理。切直连或稳定节点后再开工。"
    log "     → 别用正在坏的链路去诊断这条链路(rules/diagnose-network-selfcheck.md 关 1)。"
fi

# ── 2. macOS TCC 磁盘权限 ────────────────────────────────────
log ""
log "2) Bash 对受保护目录的写权限 (TCC)"
for DIR in "$HOME/Desktop" "$HOME/Documents"; do
    PROBE="$DIR/.preflight-$$"
    if touch "$PROBE" 2>/dev/null; then
        rm -f "$PROBE" 2>/dev/null
        ok "$(basename "$DIR") 可写"
    else
        bad "$(basename "$DIR") 不可写 — 终端缺「完整磁盘访问权限」"
        log "     → 产物先落 /tmp 或已授权目录,别在这里跑长任务。"
    fi
done

# ── 3. 代理 / TUN 状态 ───────────────────────────────────────
log ""
log "3) 网络代理层"
if pgrep -qi 'clash|mihomo|surge|v2ray' 2>/dev/null; then
    PROXY_APP=$(pgrep -li 'clash|mihomo|surge|v2ray' 2>/dev/null | head -1 | awk '{print $2}')
    if ifconfig 2>/dev/null | grep -q '^utun'; then
        warn "检测到代理进程 ($PROXY_APP) + utun 接口 = TUN 模式可能生效"
        log "     → TUN 会劫持 SMTP / 飞书 / 本地服务探测,导致假的「离线」结论。"
        log "     → 涉及邮件、飞书、本地端口探测时先确认是否需切 rule 模式。"
    else
        ok "代理进程 ($PROXY_APP) 在跑,未见 utun(非 TUN 模式)"
    fi
else
    ok "未检测到本地代理进程"
fi

# ── 4. 残留后台任务 ──────────────────────────────────────────
log ""
log "4) 残留后台作业(防多进程抢同一限流站点)"
# 分两类:一次性抓取脚本(会互抢限流) vs 常驻浏览器/MCP 实例(吃内存)。
# 混在一起统计会把 Playwright MCP + Chrome 渲染子进程全算成"爬虫",几十个全是误报。
# shellcheck disable=SC2009  # 需要 etime(已跑多久)判断是否残留,pgrep 给不了
STRAY=$(ps -eo pid,etime,command 2>/dev/null \
    | grep -iE 'scrap|crawl|spider|yt-dlp|aria2c' \
    | grep -viE 'grep|preflight|[-]-type=|mcp' || true)
if [ -z "$STRAY" ]; then
    ok "无残留一次性抓取脚本"
else
    N=$(printf '%s\n' "$STRAY" | grep -c . || true)
    warn "发现 ${N} 个抓取脚本仍在跑:"
    # 注意:必须用 here-string,不能 `... | while read`——管道会开 subshell,
    # 循环里对 OUT 的追加会随 subshell 一起丢掉(明细永远打不出来)。
    while IFS= read -r line; do
        [ -n "$line" ] && log "       $(printf '%s' "$line" | cut -c1-150)"
    done <<< "$(printf '%s\n' "$STRAY" | head -5)"
    log "     → 新开抓取前先确认是否重复;并发打同一站点会触发限流(历史:7 进程互抢)。"
fi

# 常驻 MCP 实例泄漏:每个 Claude 会话都会起自己的一份,退出没清就堆积。
# 只数主进程(Chrome helper 带 --type= 的不算)。
# shellcheck disable=SC2009
MCP_N=$(ps -eo command 2>/dev/null \
    | grep -iE 'playwright|puppeteer|firecrawl|mcp-server|/mcp/' \
    | grep -viE 'grep|preflight|[-]-type=' | grep -c . || true)
if [ "${MCP_N:-0}" -gt 8 ] 2>/dev/null; then
    warn "${MCP_N} 个常驻 MCP / 浏览器自动化进程 — 疑似泄漏堆积"
    log "     → 多会话各起一份,退出未清就累积;吃满内存会掐断流式输出"
    log "       (历史根因:swap 打满 → tool call 解析报错)。"
    log "     → 回收:/recycle,或 ~/.claude/scripts/mem-doctor.sh 诊断。"
elif [ "${MCP_N:-0}" -gt 0 ]; then
    ok "${MCP_N} 个常驻 MCP 进程,正常范围"
fi

# ── 5. 磁盘与内存余量 ────────────────────────────────────────
log ""
log "5) 资源余量"
AVAIL=$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')
if [ -n "${AVAIL:-}" ] && [ "$AVAIL" -lt 10 ] 2>/dev/null; then
    bad "根分区仅剩 ${AVAIL}GB — 大产出/构建可能中途失败"
elif [ -n "${AVAIL:-}" ]; then
    ok "根分区剩余 ${AVAIL}GB"
fi
SWAP=$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $6}' | tr -d 'M')
if [ -n "${SWAP:-}" ]; then
    SWAP_INT=${SWAP%.*}
    if [ "${SWAP_INT:-0}" -gt 8000 ] 2>/dev/null; then
        warn "swap 使用 ${SWAP}M 偏高 — 流式输出可能被掐断(历史:tool call 解析报错真因)"
        log "     → 可跑 /recycle 回收闲置会话。"
    else
        ok "swap 使用 ${SWAP}M,正常"
    fi
fi

# ── 汇总 ─────────────────────────────────────────────────────
log ""
log "──────────────────────────────────────"
log "结果: ${PASS} 通过 / ${WARN} 警告 / ${FAIL} 阻断"
if [ "$FAIL" -gt 0 ]; then
    log "🛑 有阻断项 — 先修环境再开始长任务,否则大概率半途报废。"
elif [ "$WARN" -gt 0 ]; then
    log "🟡 可以开工,但留意上面的警告项。"
else
    log "🟢 环境干净,放心跑长任务。"
fi

if [ "$QUIET" -eq 1 ] && [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    exit 0
fi
printf '%s' "$OUT"

[ "$FAIL" -gt 0 ] && exit 1
exit 0
