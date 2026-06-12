#!/bin/zsh
# Claude Code 自动更新 + smoke test + 删除旧版本
# 由 launchd com.tony.claude-auto-update 每天 04:00 触发
# 设计:内置后台 auto-updater 已被 DISABLE_AUTOUPDATER=1 禁用(避免偶发网络失败报错),
#       更新统一由本脚本用显式 `claude update`(带重试)接管,测试通过后清理旧版本。

set -uo pipefail

CLAUDE_BIN="$HOME/.local/bin/claude"
VERSIONS_DIR="$HOME/.local/share/claude/versions"
STATE_FILE="$HOME/.claude/.last-update-result.json"
LOG="$HOME/.claude/logs/claude-auto-update.log"
mkdir -p "$(dirname "$LOG")" "$VERSIONS_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
ts_iso() { date -u '+%Y-%m-%dT%H:%M:%S.000Z'; }
notify() { /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" 2>/dev/null || true; }
ver_of() { "$1" --version 2>/dev/null | awk '{print $1}'; }

# native 安装的每个版本是 versions/ 下的单文件可执行二进制(文件名=版本号),不是目录。
# 删除前确认当前版本文件存在(连续 2 次探测都在),作为安全保险。
wait_target_stable() {
  local target="$1" i hits=0
  for i in 1 2 3 4 5 6; do
    if [[ -e "$target" ]]; then
      hits=$((hits+1))
      (( hits >= 2 )) && return 0
    else
      hits=0
    fi
    sleep 1
  done
  [[ -e "$target" ]]
}

if [[ ! -x "$CLAUDE_BIN" ]]; then
  log "ERROR: 找不到 claude 二进制: $CLAUDE_BIN"
  exit 1
fi

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
# 加强:update 子系统复检健康
recheck="$("$CLAUDE_BIN" update 2>&1)"; rrc=$?
if (( rrc != 0 )); then
  log "ERROR: smoke 失败 — update 复检 rc=$rrc: $(echo "$recheck" | tail -1)。不清理旧版本。"
  notify "Claude 更新测试失败" "update 复检异常"
  exit 1
fi
sleep 5
log "smoke test 通过(版本号合法 + update 复检 OK)"

# --- 写 success 状态,杜绝启动时 "Auto-update failed" ---
cat > "$STATE_FILE" <<EOF
{"timestamp":"$(ts_iso)","path":"native","outcome":"success","status":"up_to_date","version_from":"${before:-$after}","version_to":"$after","error_code":null}
EOF
log "状态文件写为 success"

# --- 测试通过 → 删除旧版本(保留当前) ---
# 删除前确认当前版本文件存在,避免误判/误删
if wait_target_stable "$VERSIONS_DIR/$after"; then
  deleted=0
  for f in "$VERSIONS_DIR"/*(N); do
    [[ -e "$f" ]] || continue
    v="$(basename "$f")"
    [[ "$v" == "$after" ]] && continue                 # 保留当前版本
    echo "$v" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+' || continue   # 只删形如 X.Y.Z 的版本文件,防误删其他
    rm -f "$f" && { log "删除旧版本: $v"; deleted=$((deleted+1)); }
  done
  log "清理完成:删除 $deleted 个旧版本,保留当前 $after"
else
  log "WARN: 当前版本文件 $after 未稳定出现,跳过本次清理(更新本身已成功,下次运行再清理)"
fi

if [[ "${before:-}" != "${after:-}" && -n "${before:-}" ]]; then
  notify "Claude 已更新" "$before → $after,旧版本已清理"
fi
log "==== 全部完成 ✓ ===="
