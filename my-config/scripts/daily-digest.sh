#!/bin/bash
# 每日合并推送: 思考(daily-article) + AI 热点(daily-ai-news) 两篇都齐后,
# 渲染国内静态站 → 推【一条】微信(双篇摘要 + 国内秒开全文链接)。
# 幂等 + 限流退避重试。由 launchd 定时触发,也由两个创作脚本结尾顺手调用。
set -uo pipefail

WORK="$HOME/.local/share/tony-articles"
LOG="$HOME/.claude/logs/daily-digest.log"
TODAY="$(date +%Y-%m-%d)"
SITE_BASE="http://111.229.77.103:8080"
WEIXIN_CHANNEL="o9cq80_JAkxB7DYoj-ljixOpFdWY@im.wechat"
# 飞书主送达通道(可靠)。若目标不对,改这一行即可:
#   军团群 = feishu:oc_2c48fc2edefd4d3d82c4bbd54d2e9680
#   另一个 DM = feishu:oc_b4cc31551e0d67fb5888edcbfcfb7f20
FEISHU_TARGET="feishu:oc_43c5ee271f2b76bd073779a169736142"
HERMES="$HOME/.local/bin/hermes"
RENDER="$HOME/.claude/scripts/render-site.py"
DONE="$HOME/.claude/logs/.daily-digest-done-${TODAY}"
FEISHU_DONE="$HOME/.claude/logs/.daily-digest-feishu-${TODAY}"
WECHAT_DONE="$HOME/.claude/logs/.daily-digest-wechat-${TODAY}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
log "===== digest $TODAY ====="

# 幂等
[ -f "$DONE" ] && { log "今日已推送, 跳过"; exit 0; }

# 进程锁
LOCK="$HOME/.claude/logs/.daily-digest.lock"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  log "上次 digest 仍在跑 (PID $(cat "$LOCK")), 跳过"; exit 0
fi
echo $$ > "$LOCK"; trap 'rm -f "$LOCK"' EXIT

# 两篇是否齐(本地中文版即可判定; 创作脚本已在本机 commit/push)
ZH_ART=$(ls "$WORK"/articles/zh/${TODAY}-*.md 2>/dev/null | head -1)
ZH_NEWS=$(ls "$WORK"/ai-news/zh/${TODAY}-*.md 2>/dev/null | head -1)
if [ -z "$ZH_ART" ] || [ -z "$ZH_NEWS" ]; then
  log "两篇未齐(思考=${ZH_ART:-无} 热点=${ZH_NEWS:-无}), 等后续触发"; exit 0
fi
log "两篇齐: 思考=$(basename "$ZH_ART") 热点=$(basename "$ZH_NEWS")"

# 渲染 + 同步国内站(失败仍继续推送, 内嵌摘要不依赖链接)
if bash "$HOME/.claude/scripts/sync-site.sh" >>"$LOG" 2>&1; then
  log "站点同步成功"
else
  log "WARN: 站点同步失败, 仍推送(摘要可读, 链接稍后生效)"
fi

# 构建合并消息(Python 内构建 + surrogate 全量过滤, 经文件传给 hermes, 不走 bash 裸参)
MSGFILE="$HOME/.claude/logs/.digest-msg-${TODAY}.txt"
python3 "$RENDER" message "$TODAY" "$SITE_BASE" > "$MSGFILE" 2>>"$LOG"
if [ ! -s "$MSGFILE" ]; then log "ERROR: 合并消息为空, 退出"; exit 1; fi
MSG="$(cat "$MSGFILE")"

# --- ntfy 告警(回查未确认时提醒, 避免静默漏推) ---
ntfy_send() {
  [ -f "$HOME/.config/ntfy/.env" ] || return 0
  source "$HOME/.config/ntfy/.env"
  [ -n "${NTFY_CLAUDE_TOPIC:-}" ] || return 0
  curl -s -m 3 -d "$1" "ntfy.sh/${NTFY_CLAUDE_TOPIC}" >/dev/null 2>&1 || true
}

# 飞书送达回查:发完查该 chat 近期消息确认 digest 真落地(防"hermes 报成功但实际没到")
# 返回 0=已确认落地, 1=未见消息(需重推), 2=回查工具不可用(回退信任 rc=0)
FEISHU_CHAT_ID="${FEISHU_TARGET#feishu:}"
feishu_confirm() {
  command -v lark-cli >/dev/null 2>&1 || return 2
  local _i
  for _i in 1 2 3; do
    if LARK_CLI_NO_PROXY=1 lark-cli --profile cli_aa80e81017f85bc0 --as user \
         im +chat-messages-list --chat-id "$FEISHU_CHAT_ID" --page-size 8 2>/dev/null \
         | grep -q "盛大白每日 · ${TODAY}"; then
      return 0
    fi
    sleep 3
  done
  return 1
}

# --- 飞书主通道(可靠;整体"完成"以它送达为准, 且发后回查确认真落地)---
if [ ! -f "$FEISHU_DONE" ]; then
  OUT="$("$HERMES" send -t "$FEISHU_TARGET" "$MSG" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && ! echo "$OUT" | grep -qiE "fail|error"; then
    sleep 5
    feishu_confirm; cf=$?
    if [ "$cf" -eq 0 ]; then
      touch "$FEISHU_DONE"; log "飞书推送成功+回查确认落地 -> $FEISHU_TARGET"
    elif [ "$cf" -eq 2 ]; then
      touch "$FEISHU_DONE"; log "飞书 rc=0(回查工具缺失, 信任发送结果) -> $FEISHU_TARGET"
    else
      log "WARN: 飞书 rc=0 但回查 3 次未见今日 digest, 不标记完成, 下个 launchd 时刻自动重推"
      ntfy_send "⚠️ daily-digest: 飞书报成功但回查未确认送达($TODAY), 已留待下个窗口自动重推。若长时间未到可手动跑 ~/.claude/scripts/daily-digest.sh"
    fi
  else
    log "飞书推送失败 (rc=$rc): ${OUT:-<空>}"
  fi
else
  log "飞书今日已送达, 跳过"
fi

# --- 微信(尽力;每次 tick 仅 1 发, 全天靠 launchd 多时刻重试拉高命中)---
if [ ! -f "$WECHAT_DONE" ]; then
  OUT="$("$HERMES" send -t "weixin:$WEIXIN_CHANNEL" "$MSG" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && ! echo "$OUT" | grep -qiE "fail|error|rate.?limit|surrogate"; then
    touch "$WECHAT_DONE"; log "微信推送成功"
  else
    log "微信本次未通(尽力, 后续 tick 再试): ${OUT:-<空>}"
  fi
else
  log "微信今日已送达, 跳过"
fi

# 整体完成 = 飞书已送达(可靠通道);微信通不通不阻塞
if [ -f "$FEISHU_DONE" ]; then
  touch "$DONE"; log "已标记今日完成(飞书送达; 微信 $([ -f "$WECHAT_DONE" ] && echo 已通 || echo 仍尽力))"
else
  log "飞书未送达, 不标记完成, 后续 launchd 时刻重试"
fi
log "===== digest 结束 ====="
