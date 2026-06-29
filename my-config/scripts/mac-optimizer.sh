#!/usr/bin/env bash
# mac-optimizer — Mac Studio 优化系统统一面板（只读）
# 一屏看：CPU / 内存 / 热 / 磁盘 + 三个守护 loop 的健康状态。
#
# 用法:
#   mac-optimizer.sh status     # 默认，整机健康一屏（只读）
#   mac-optimizer.sh logs       # 各 loop 最近动作日志
#   mac-optimizer.sh storage    # 跑一次储存巡检报告
#
# 守护体系（全部 launchd 驱动，只 renice/优雅退出，永不 kill 工作进程）:
#   mem-tamer     每3min  给后台 Electron renderer 降优先级
#   mem-guardian  每15min compressor 超阈时优雅退出 Genspark / 清孤儿 MCP
#   cpu-throttler 每2min  系统CPU>80% 或热节流时 renice+taskpolicy 非白名单大户
#   storage-advisor 每周  储存巡检报告

set -u
export LC_ALL="en_US.UTF-8" LANG="en_US.UTF-8"
SCRIPTS="$HOME/.claude/scripts"
LOGS="$SCRIPTS/logs"
MODE="${1:-status}"

bar() { printf '%s\n' "────────────────────────────────────────────"; }

status() {
    bar; echo "🖥  Mac Studio 优化面板  $(date '+%Y-%m-%d %H:%M:%S')"; bar

    # —— CPU ——
    local idle busy
    idle=$(top -l 2 -n 0 2>/dev/null | grep -E "^CPU usage" | tail -1 \
           | awk '{for(i=1;i<=NF;i++) if($i=="idle"){gsub(/%/,"",$(i-1)); print $(i-1)}}')
    busy=$(awk "BEGIN{printf \"%.0f\", 100-${idle:-100}}")
    echo "🔥 CPU 忙占比: ${busy}%  (阈值 80% 触发自动降速)"
    echo "   当前 CPU top5:"
    top -l 2 -n 5 -o cpu -stats command,cpu 2>/dev/null | awk '
        /^Processes:/ {blk++; cap=0; next}
        blk>=2 && /^COMMAND/ {cap=1; next}
        cap && NF>=2 {print "     " $0}' | head -5

    # —— 热 ——
    local therm
    therm=$(pmset -g therm 2>/dev/null | grep -E "CPU_Scheduler_Limit|CPU_Speed_Limit" | head -1)
    if [ -n "$therm" ]; then
        echo "🌡  热状态: $therm  (<100 = 正在热节流)"
    else
        echo "🌡  热状态: 🟢 无热节流警告"
    fi

    # —— 内存 ——
    echo ""
    local freepct comp_mb
    freepct=$(memory_pressure 2>/dev/null | awk -F: '/free percentage/ {gsub(/[ %]/,"",$2); print $2}')
    comp_mb=$(vm_stat | awk '/Pages occupied by compressor/ {gsub(/\./,"",$5); print $5*16/1024}')
    echo "🧠 内存空闲: ${freepct:-?}%   compressor: ${comp_mb%.*}MB  (>7500MB guardian 介入)"
    echo "   swap: $(sysctl -n vm.swapusage)"

    # —— 磁盘 ——
    echo ""
    echo "💾 磁盘:"
    df -h / /System/Volumes/Data /Volumes/2T 2>/dev/null | awk 'NR==1 || /Data|2T|disk3s1s1/ {print "   " $0}'

    # —— loop 健康 ——
    echo ""; echo "⚙️  守护 loop 状态:"
    for svc in mem-tamer mem-guardian cpu-throttler storage-advisor; do
        local line st
        line=$(launchctl list 2>/dev/null | grep "com.tony.$svc")
        if [ -n "$line" ]; then
            st=$(echo "$line" | awk '{print $2}')
            local logf="$LOGS/$svc.log"
            local last="(无日志)"
            [ -f "$logf" ] && last=$(tail -1 "$logf" 2>/dev/null | cut -c1-70)
            echo "   ✅ $svc (exit=$st)  最近: $last"
        else
            echo "   ❌ $svc 未加载"
        fi
    done
    bar
}

logs() {
    for svc in cpu-throttler mem-guardian mem-tamer storage-advisor; do
        echo "===== $svc.log (最近10行) ====="
        tail -10 "$LOGS/$svc.log" 2>/dev/null || echo "(无日志)"
        echo ""
    done
}

case "$MODE" in
    status) status ;;
    logs)   logs ;;
    storage) bash "$SCRIPTS/storage-advisor.sh" report ;;
    *) echo "用法: mac-optimizer.sh [status|logs|storage]"; exit 1 ;;
esac
