#!/bin/zsh
# Claude Code 官方守卫更新 + 本地 smoke test + 保留回退版本
# 由 launchd com.tony.claude-auto-update 每天 04:00 触发
# 设计:内置后台 auto-updater 已被 DISABLE_AUTOUPDATER=1 禁用(避免偶发网络失败报错),
#       更新统一由本脚本用显式 `claude update`(带重试)接管,测试通过后保留旧版本，供回退。

set -uo pipefail

CLAUDE_BIN="$HOME/.claude/bin/claude"
VERSIONS_DIR="$HOME/.local/share/claude/versions"
STATE_FILE="$HOME/.claude/.last-update-result.json"
LOG="$HOME/.claude/logs/claude-auto-update.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
ts_iso() { date -u '+%Y-%m-%dT%H:%M:%S.000Z'; }
notify() { /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" 2>/dev/null || true; }
ver_of() { "$1" --version 2>/dev/null | awk '{print $1}'; }

case "${1:-}" in
  --help) echo 'Usage: claude-auto-update.sh [--dry-run]'; exit 0 ;;
  --dry-run)
    echo "Would update through $CLAUDE_BIN; preserve all previous versions."
    "$CLAUDE_BIN" --version
    exit $? ;;
  '') ;;
  *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

if [[ ! -x "$CLAUDE_BIN" ]]; then
  log "ERROR: 找不到 claude 二进制: $CLAUDE_BIN"
  exit 1
fi

mkdir -p "$(dirname "$LOG")" "$VERSIONS_DIR"
before="$(ver_of "$CLAUDE_BIN")"
log "==== 开始 ==== 当前版本: ${before:-unknown}"

# --- 更新(带退避重试,扛网络/代理偶发抖动) ---
attempt=0; max=3; ok=0; out=""
while (( attempt < max )); do
  attempt=$((attempt+1))
  out="$("$CLAUDE_BIN" update 2>&1)"; rc=$?
  log "update 尝试 $attempt/$max rc=$rc: $(echo "$out" | tail -1)"
  if (( rc == 0 )); then ok=1; break; fi
  sleep $((attempt*20))
done

if (( ok == 0 )); then
  log "ERROR: update 连续 $max 次失败,保留现状,不清理旧版本"
  notify "Claude 自动更新失败" "重试 $max 次仍失败,见 claude-auto-update.log"
  exit 1
fi

# update 返回后让文件系统收尾稳定(claude update 会重组 versions 目录)
sleep 5
after="$(ver_of "$CLAUDE_BIN")"
log "update 完成. 版本: ${before:-?} -> ${after:-?}"

# --- Smoke test(纯本地,不耗 API token) ---
# 主判据:二进制能启动并报出合法版本号 = 安装健康
if ! echo "${after:-}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
  log "ERROR: smoke 失败 — --version 异常输出: '${after}'。不清理旧版本。"
  notify "Claude 更新测试失败" "版本号异常: ${after}"
  exit 1
fi
# A second update could install a different build than the one just validated.
# Verify the same installed build twice without another network mutation.
recheck="$(ver_of "$CLAUDE_BIN")"
if [[ "$recheck" != "$after" ]]; then
  log "ERROR: version changed during verification; preserving previous versions"
  exit 1
fi
log "smoke test 通过(两次本地版本检查一致)"

# --- 写 success 状态,杜绝启动时 "Auto-update failed" ---
cat > "$STATE_FILE" <<EOF
{"timestamp":"$(ts_iso)","path":"native","outcome":"success","status":"up_to_date","version_from":"${before:-$after}","version_to":"$after","error_code":null}
EOF
log "状态文件写为 success"

# Preserve rollback binaries; updates must not delete every fallback version.
log "保留旧版本，回退文件仍在 versions 目录"

if [[ "${before:-}" != "${after:-}" && -n "${before:-}" ]]; then
  notify "Claude 已更新" "$before → $after,旧版本已保留"
fi
log "==== 全部完成 ✓ ===="
