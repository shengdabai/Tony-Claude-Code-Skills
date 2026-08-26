#!/bin/bash
# feishu-stack-auto-update.sh — 飞书桥接栈自动更新(带健康门禁 + 自动回滚)
#
# 覆盖三个 npm 全局包:
#   @larksuite/cli       (lark-cli)                  — 直接更新,更新后 `lark-cli --version` 验证
#   lark-channel-bridge  (飞书 Claude bot)            — 快照 → 更新 → kickstart → 健康门禁 → 失败回滚
#   agent-feishu-channel (飞书 Codex bot)             — 同上
#
# 为什么桥接包要门禁:两个包的 dist/ 都有本地手工补丁(健康脚本 check_delivery_contracts /
# check_runtime_code_loaded 依赖这些补丁)。盲目 npm i -g 会把补丁冲掉、bot 连接退化。
# 所以更新后立即跑 feishu-bridge-health;出现「新增 issue」或 bot 没起来 → 从快照回滚,
# 把该版本写入 hold 文件(不再重试同一版本),并推 ntfy 提醒人工合并补丁。
#
# 由 launchd com.tony.feishu-stack-auto-update 每日 04:40 触发(在 cli-auto-update 之后)。
# 手动:bash ~/.claude/scripts/feishu-stack-auto-update.sh [--force-pkg <name>]
set -uo pipefail

NODE_BIN="$HOME/.nvm/versions/node/v24.14.0/bin"
NPM="$NODE_BIN/npm"
NODE_MODULES="$HOME/.nvm/versions/node/v24.14.0/lib/node_modules"
HEALTH="$HOME/.local/bin/feishu-bridge-health"
HEALTH_GATE_LIB="$HOME/.local/lib/feishu-update-health-gate.sh"
LOG_DIR="$HOME/.claude/logs"
LOG="$LOG_DIR/feishu-stack-auto-update.log"
SNAP_DIR="$HOME/.claude/backups/feishu-stack"
HOLD_FILE="$SNAP_DIR/held-versions.txt"
export PATH="$NODE_BIN:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# 与 launchd plist 同款代理,npm view/install 需要出网
export HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:7897}" HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:7897}"
export NO_PROXY="127.0.0.1,localhost,::1,*.local"

mkdir -p "$LOG_DIR" "$SNAP_DIR"
touch "$HOLD_FILE"

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { printf '[%s] %s\n' "$(ts)" "$*" >>"$LOG"; }
[ -r "$HEALTH_GATE_LIB" ] || { log "health gate library missing: $HEALTH_GATE_LIB"; exit 1; }
# shellcheck disable=SC1090
source "$HEALTH_GATE_LIB"
ntfy_send() {
  [ -f "$HOME/.config/ntfy/.env" ] || return 0
  # shellcheck disable=SC1091
  source "$HOME/.config/ntfy/.env"
  [ -n "${NTFY_CLAUDE_TOPIC:-}" ] || return 0
  curl -s -m 5 -d "$1" "ntfy.sh/${NTFY_CLAUDE_TOPIC}" >/dev/null 2>&1 || true
}

installed_version() { # $1=pkg
  "$NODE_BIN/node" -p "require('$NODE_MODULES/$1/package.json').version" 2>/dev/null
}
latest_version() { # $1=pkg
  "$NPM" view "$1" version 2>/dev/null | tail -1
}
is_held() { grep -Fxq "$1@$2" "$HOLD_FILE"; }
hold() { echo "$1@$2" >>"$HOLD_FILE"; }

health_issues() {
  # 只取与桥接连接相关的 issue 前缀,过滤掉与更新无关的噪音
  "$HEALTH" --dry-run 2>/dev/null | tail -1 \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)
keep=("com.tony.afc-codex:","ai.lark-channel-bridge.bot:","runtime_","delivery_contract","codex_config","claude_","codex_live")
print("\n".join(sorted(i for i in d.get("issues",[]) if i.startswith(keep))))' 2>/dev/null
}

label_running() { # $1=label
  launchctl print "gui/$(id -u)/$1" 2>/dev/null | grep -Eq 'pid = [0-9]+'
}

snapshot() { # $1=pkg $2=ver → prints tgz path
  local out
  out="$SNAP_DIR/$1-$2-$(date +%Y%m%d-%H%M%S).tgz"
  tar -C "$NODE_MODULES" -czf "$out" "$1" && echo "$out"
}
restore_snapshot() { # $1=pkg $2=tgz
  rm -rf "${NODE_MODULES:?}/$1" && tar -C "$NODE_MODULES" -xzf "$2"
}

# ---------- 1. lark-cli:直接更新 ----------
update_lark_cli() {
  local pkg="@larksuite/cli" cur latest
  cur="$(installed_version "$pkg")"; latest="$(latest_version "$pkg")"
  if [ -z "$latest" ]; then log "lark-cli: 无法查询最新版(网络?),跳过"; return; fi
  if [ "$cur" = "$latest" ]; then log "lark-cli: 已是最新 $cur"; return; fi
  log "lark-cli: $cur -> $latest 更新中"
  if "$NPM" install -g "$pkg@$latest" >>"$LOG" 2>&1 && "$NODE_BIN/lark-cli" --version >/dev/null 2>&1; then
    log "lark-cli: 更新成功 $(installed_version "$pkg")"
  else
    log "lark-cli: 更新失败,回退到 $cur"
    "$NPM" install -g "$pkg@$cur" >>"$LOG" 2>&1 || true
    ntfy_send "⚠️ lark-cli 自动更新 $cur→$latest 失败,已回退"
  fi
}

# ---------- 2. 桥接包:快照 → 更新 → 门禁 → 回滚 ----------
update_bridge_pkg() { # $1=pkg $2=launchd label $3=force(0/1)
  local pkg="$1" label="$2" force="${3:-0}" cur latest snap after bridge_state
  cur="$(installed_version "$pkg")"; latest="$(latest_version "$pkg")"
  if [ -z "$latest" ]; then log "$pkg: 无法查询最新版,跳过"; return; fi
  if [ "$cur" = "$latest" ]; then log "$pkg: 已是最新 $cur"; return; fi
  if [ "$force" -eq 0 ] && is_held "$pkg" "$latest"; then
    log "$pkg: $latest 已被 hold(上次门禁失败),跳过;人工合并补丁后删除 $HOLD_FILE 中对应行"; return
  fi

  snap="$(snapshot "$pkg" "$cur")" || { log "$pkg: 快照失败,放弃更新"; return; }
  log "$pkg: $cur -> $latest,快照 $snap"

  if ! "$NPM" install -g "$pkg@$latest" >>"$LOG" 2>&1; then
    log "$pkg: npm install 失败,回滚"
    restore_snapshot "$pkg" "$snap"; launchctl kickstart -k "gui/$(id -u)/$label" 2>/dev/null || true
    ntfy_send "⚠️ $pkg 更新 $cur→$latest 安装失败,已回滚"; return
  fi

  launchctl kickstart -k "gui/$(id -u)/$label" 2>/dev/null || true
  sleep 25
  after="$(health_issues)"
  bridge_state="stopped"
  label_running "$label" && bridge_state="running"

  if feishu_update_health_gate "$bridge_state" "$after"; then
    log "$pkg: 更新到 $latest 并通过健康门禁"
    ntfy_send "✅ $pkg 自动更新 $cur→$latest,健康门禁通过"
  else
    log "$pkg: 门禁失败(state=$bridge_state; 剩余 issue: ${after//$'\n'/, }),回滚到 $cur"
    restore_snapshot "$pkg" "$snap"
    launchctl kickstart -k "gui/$(id -u)/$label" 2>/dev/null || true
    sleep 10
    if label_running "$label"; then log "$pkg: 回滚后 bot 已恢复"; else log "$pkg: 回滚后 bot 仍未运行!需人工介入"; fi
    hold "$pkg" "$latest"
    ntfy_send "⚠️ $pkg 新版 $latest 未通过健康门禁(本地补丁可能被覆盖),已回滚到 $cur 并 hold。剩余 issue: ${after//$'\n'/, }"
  fi
}

# ---------- main ----------
FORCE_PKG=""
while [ $# -gt 0 ]; do
  case "$1" in --force-pkg) FORCE_PKG="$2"; shift ;; esac; shift
done

log "=== feishu-stack-auto-update start ==="
update_lark_cli
update_bridge_pkg "lark-channel-bridge" "ai.lark-channel-bridge.bot" "$([ "$FORCE_PKG" = lark-channel-bridge ] && echo 1 || echo 0)"
update_bridge_pkg "agent-feishu-channel" "com.tony.afc-codex" "$([ "$FORCE_PKG" = agent-feishu-channel ] && echo 1 || echo 0)"
# 收尾:再跑一次健康检查(带自动修复),确保连接可用
final="$("$HEALTH" --repair-safe 2>/dev/null | tail -1)"
final_status="$(printf '%s' "$final" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status", ""))' 2>/dev/null || true)"
log "final health: $final"
# 只保留最近 5 个快照/包
for p in lark-channel-bridge agent-feishu-channel; do
  ls -t "$SNAP_DIR"/"$p"-*.tgz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
done
if feishu_stack_final_health_gate "$final_status"; then
  log "=== feishu-stack-auto-update done ==="
  exit 0
fi

log "=== feishu-stack-auto-update failed: final status=${final_status:-invalid} ==="
ntfy_send "⚠️ 飞书桥自动更新收尾健康检查失败: $final"
exit 1
