#!/usr/bin/env bash
# storage-advisor — 储存巡检 + offload 引导（默认只报告，绝不自动搬文件）
#
# 设计原则:
#   1. 默认 report-only。自动搬移用户文件风险高且不可逆 —— 现在内部盘还有 100GB+ 空闲、
#      2T 盘 1.2TB 空闲，无空间压力，刻意不做破坏性自动搬移（遵守"重要文件可回滚"规则）。
#   2. 报告里给出可一键复制的 offload 命令（搬到 2T / 开 iCloud 优化存储），由你确认后手动跑。
#   3. --apply-downloads 可选：把 Downloads 里 >30 天且 >100MB 的大文件 rsync 到 2T 归档区
#      （rsync 校验通过后才删源，逐个确认前缀），其它一律手动。
#
# Loop Engineering 五要素:
#   Trigger=launchd 每周一次 | Work=巡检出报告 | Verify=报告落盘可读
#   Exit=持续(每周) | Budget=du 扫描限定目录，单轮 ≤30s

set -u
export LC_ALL="en_US.UTF-8" LANG="en_US.UTF-8"

LOG_DIR="$HOME/.claude/scripts/logs"
REPORT="$LOG_DIR/storage-advisor.report.txt"
mkdir -p "$LOG_DIR"

TWO_T="/Volumes/2T"
ARCHIVE_DIR="$TWO_T/编程归档"          # 已存在的归档根（见 memory reference_2t-disk-structure）
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
MODE="${1:-report}"

say() { echo "$@" | tee -a "$REPORT"; }

report() {
    : > "$REPORT"
    say "===== Mac Studio 储存巡检 $(date '+%Y-%m-%d %H:%M') ====="
    say ""
    say "【磁盘总览】"
    df -h / /System/Volumes/Data "$TWO_T" 2>/dev/null | tee -a "$REPORT" >/dev/null
    df -h / /System/Volumes/Data "$TWO_T" 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT" >/dev/null

    # 可用空间预警
    local avail_gb
    avail_gb=$(df -g /System/Volumes/Data 2>/dev/null | awk 'NR==2{print $4}')
    say ""
    if [ -n "${avail_gb:-}" ]; then
        if [ "$avail_gb" -lt 30 ]; then
            say "⚠️  内部盘可用 ${avail_gb}GB —— 偏低，建议执行下方 offload"
        elif [ "$avail_gb" -lt 80 ]; then
            say "🟡 内部盘可用 ${avail_gb}GB —— 尚可，关注大户"
        else
            say "🟢 内部盘可用 ${avail_gb}GB —— 充裕，无需搬移（报告仅供参考）"
        fi
    fi

    say ""
    say "【home 目录占用 top 15】（扫描 ~ 一级子目录，约 10-20s）"
    du -sh "$HOME"/* 2>/dev/null | sort -rh | head -15 | sed 's/^/  /' | tee -a "$REPORT"

    say ""
    say "【>500MB 大文件 top 20】（~/Desktop ~/Downloads ~/Movies ~/Documents）"
    find "$HOME/Desktop" "$HOME/Downloads" "$HOME/Movies" "$HOME/Documents" \
        -type f -size +500M 2>/dev/null -exec du -h {} + 2>/dev/null \
        | sort -rh | head -20 | sed 's/^/  /' | tee -a "$REPORT"

    say ""
    say "【iCloud 优化存储状态】"
    local opt
    opt=$(defaults read com.apple.bird optimize-storage 2>/dev/null || echo "未读到")
    say "  com.apple.bird optimize-storage = ${opt} （1=已开启自动 evict 本地副本）"
    say "  开启入口: 系统设置 → Apple 账户 → iCloud → 优化 Mac 储存空间"

    say ""
    say "【可选 offload 命令（确认后手动执行，脚本默认不自动搬）】"
    say "  # 把某大目录搬到 2T 归档并留软链（可回滚：源先改名 .migrated 再删）:"
    say "  #   rsync -a --info=progress2 \"<源目录>/\" \"$ARCHIVE_DIR/<名>/\" && \\"
    say "  #   diff -rq \"<源目录>\" \"$ARCHIVE_DIR/<名>\" && mv \"<源目录>\" \"<源目录>.migrated\""
    say "  #   确认无误后再 rm -rf \"<源目录>.migrated\""
    say "  # 把已同步的 iCloud 文件从本地缓存逐出（释放本地空间、云端保留）:"
    say "  #   brctl evict \"$ICLOUD/<路径>\""
    say "  # 半自动：把 Downloads 里 >30天 且 >100MB 的搬到 2T 归档:"
    say "  #   $HOME/.claude/scripts/storage-advisor.sh --apply-downloads"
    say ""
    say "报告已存: $REPORT"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 巡检完成 内部盘可用=${avail_gb:-?}GB 报告=$REPORT" >> "$LOG_DIR/storage-advisor.log"
}

apply_downloads() {
    local dst="$ARCHIVE_DIR/Downloads-archive"
    if [ ! -d "$TWO_T" ]; then
        echo "❌ $TWO_T 不存在，中止"; exit 1
    fi
    if ! mkdir -p "$dst"; then
        echo "❌ 无法创建目标目录 $dst（权限/空间问题），中止"; exit 1
    fi
    # 强校验：检查【解析软链后的真实落地目录 $dst】的 device id，必须与 $HOME 不同。
    # $ARCHIVE_DIR 是软链（→05-编程归档），仅校验 $TWO_T 会漏掉软链被改向内部盘的情况
    # → 直接校验真实写入目录（Codex review round3 修正）。
    local dev_dst dev_home
    dev_dst=$(stat -f %d "$dst" 2>/dev/null)
    dev_home=$(stat -f %d "$HOME" 2>/dev/null)
    if [ -z "$dev_dst" ] || [ "$dev_dst" = "$dev_home" ]; then
        echo "❌ 实际落地目录 $dst 在内部盘上（2T 未挂载或软链被改向），中止以防误写内部盘"; exit 1
    fi
    # 源不真删：移到带时间戳的回收区（可恢复），由你确认后再手动清空
    local quarantine="$HOME/.Trash/downloads-offload-$(date +%Y%m%d-%H%M%S)"
    echo "把 ~/Downloads 中 >30天 且 >100MB 的文件搬到 $dst"
    echo "源不直接删除，校验通过后移到回收区: $quarantine（确认无误后手动清空）"
    local moved=0
    # -print0 + read -d ''：文件名含空格/换行也安全（Codex review 修正）
    while IFS= read -r -d '' f; do
        [ -z "$f" ] && continue
        # 保留相对路径，避免同名文件互相覆盖（Codex review 修正）
        local rel="${f#"$HOME/Downloads/"}"
        local target="$dst/$rel"
        local tdir; tdir=$(dirname "$target")
        echo "→ $rel"
        if [ -e "$target" ]; then
            echo "  ⚠️ 目标已存在同路径文件，跳过（防覆盖）: $target"
            continue
        fi
        mkdir -p "$tdir" || { echo "  ⚠️ 建目标子目录失败，跳过"; continue; }
        if rsync -a "$f" "$target" && cmp -s "$f" "$target"; then
            local qpath="$quarantine/$rel"
            if ! mkdir -p "$(dirname "$qpath")"; then
                echo "  ⚠️ 建回收区目录失败，已在 2T 留副本，源保留"; continue
            fi
            if mv "$f" "$qpath"; then
                moved=$((moved+1)); echo "  ✓ 已搬移并校验，源移入回收区（可恢复）"
            else
                echo "  ⚠️ 源移入回收区失败，已在 2T 留副本，源保留"
            fi
        else
            echo "  ⚠️ rsync/校验失败，源保留，未动"
            rm -f "$target" 2>/dev/null   # 清掉不完整的目标副本
        fi
    done < <(find "$HOME/Downloads" -type f -size +100M -mtime +30 -print0 2>/dev/null)
    echo "完成：搬移 $moved 个文件到 $dst；源在 $quarantine"
}

case "$MODE" in
    --apply-downloads) apply_downloads ;;
    *) report ;;
esac
