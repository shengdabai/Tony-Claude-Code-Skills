#!/bin/bash
# 每日合并推送: 思考(daily-article) + AI 热点(daily-ai-news) 两篇都齐后,
# 渲染国内静态站 → 只推【一条】飞书(双篇摘要 + 国内秒开全文链接)。
# 幂等 + 飞书送达回查。由 launchd 定时触发,也支持 DAILY_DIGEST_DATE=YYYY-MM-DD 补发。
set -uo pipefail

WORK="$HOME/.local/share/tony-articles"
LOG="$HOME/.claude/logs/daily-digest.log"
TODAY="${DAILY_DIGEST_DATE:-$(date +%Y-%m-%d)}"
SITE_BASE="http://111.229.77.103:8080"
FEISHU_TARGET="feishu:oc_43c5ee271f2b76bd073779a169736142"
FEISHU_CHAT_ID="${FEISHU_TARGET#feishu:}"
HERMES="$HOME/.local/bin/hermes"
RENDER="$HOME/.claude/scripts/render-site.py"
DONE="$HOME/.claude/logs/.daily-digest-done-${TODAY}"
FEISHU_DONE="$HOME/.claude/logs/.daily-digest-feishu-${TODAY}"
WECHAT_DISABLED="$HOME/.claude/logs/.daily-digest-wechat-disabled-${TODAY}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
log "===== digest $TODAY ====="

if ! [[ "$TODAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  log "ERROR: DAILY_DIGEST_DATE 格式错误: $TODAY"
  exit 2
fi
for dep in git python3 "$HERMES" "$RENDER"; do
  if [ "${dep#/}" = "$dep" ]; then
    command -v "$dep" >/dev/null 2>&1 || { log "ERROR: 依赖不存在: $dep"; exit 1; }
  elif [ ! -x "$dep" ]; then
    log "ERROR: 依赖不可执行: $dep"; exit 1
  fi
done

# launchd 独立触发时也先同步 GitHub main。只允许干净 checkout 做安全快进。
cd "$WORK" || { log "FATAL: 工作目录不存在 $WORK"; exit 1; }
if [ -z "$(git status --porcelain)" ]; then
  if git fetch -q origin main 2>>"$LOG"; then
    log "已刷新 origin/main"
  elif git rev-parse --verify origin/main >/dev/null 2>&1; then
    log "WARN: fetch origin/main 暂时失败；仅使用已有远端跟踪引用做对象级校验"
  else
    log "ERROR: 无法 fetch 且没有可校验的 origin/main"
    exit 1
  fi
  if [ "$(git symbolic-ref --short HEAD 2>/dev/null)" != "main" ]; then
    git switch -q main 2>>"$LOG" || { log "ERROR: 无法切换到 main"; exit 1; }
  fi
  git merge -q --ff-only origin/main 2>>"$LOG" || { log "ERROR: main 无法安全快进到 origin/main"; exit 1; }
else
  log "ERROR: 主发布 checkout 有未提交改动，拒绝用不确定状态推送飞书"
  exit 1
fi

# 幂等
[ -f "$DONE" ] && { log "该日已推送, 跳过"; exit 0; }

# 按日期加锁，补发历史日期时不与今日发送互相覆盖。
LOCK="$HOME/.claude/logs/.daily-digest-${TODAY}.lock"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  log "该日 digest 仍在跑 (PID $(cat "$LOCK")), 跳过"; exit 0
fi
echo $$ > "$LOCK"; trap 'rm -f "$LOCK"' EXIT

# 两篇是否齐；创作脚本负责生成并发布，本脚本只在远端 main 齐全后分发。
ZH_ART=$(find "$WORK/articles/zh" -maxdepth 1 -type f -name "${TODAY}-*.md" -print | head -1)
ZH_NEWS=$(find "$WORK/ai-news/zh" -maxdepth 1 -type f -name "${TODAY}-*.md" -print | head -1)
if [ -z "$ZH_ART" ] || [ -z "$ZH_NEWS" ]; then
  log "两篇未齐(思考=${ZH_ART:-无} 热点=${ZH_NEWS:-无}), 等后续触发"; exit 0
fi
log "两篇齐: 思考=$(basename "$ZH_ART") 热点=$(basename "$ZH_NEWS")"

ART_REL="${ZH_ART#"$WORK"/}"
NEWS_REL="${ZH_NEWS#"$WORK"/}"
if ! git cat-file -e "origin/main:${ART_REL}" 2>/dev/null ||
   ! git cat-file -e "origin/main:${NEWS_REL}" 2>/dev/null; then
  log "ERROR: 两篇未同时进入 origin/main，拒绝提前推送飞书"
  exit 1
fi

# dry-run 覆盖路由、依赖、日期、文章齐备和远端发布门槛，不产生外部写入。
if [ "${DAILY_DIGEST_DRY_RUN:-0}" = "1" ]; then
  log "DRY_RUN: 两篇已在 origin/main，飞书目标与依赖检查通过；未同步站点、未发送消息"
  exit 0
fi

# 渲染 + 同步国内站；失败时摘要仍可阅读，因此继续发送并记录告警。
if bash "$HOME/.claude/scripts/sync-site.sh" >>"$LOG" 2>&1; then
  log "站点同步成功"
else
  log "WARN: 站点同步失败, 仍推送(摘要可读, 链接稍后生效)"
fi

MSGFILE="$HOME/.claude/logs/.digest-msg-${TODAY}.txt"
python3 "$RENDER" message "$TODAY" "$SITE_BASE" > "$MSGFILE" 2>>"$LOG"
if [ ! -s "$MSGFILE" ]; then log "ERROR: 合并消息为空, 退出"; exit 1; fi
MSG="$(cat "$MSGFILE")"

ntfy_send() {
  [ -f "$HOME/.config/ntfy/.env" ] || return 0
  source "$HOME/.config/ntfy/.env"
  [ -n "${NTFY_CLAUDE_TOPIC:-}" ] || return 0
  curl -s -m 3 -d "$1" "ntfy.sh/${NTFY_CLAUDE_TOPIC}" >/dev/null 2>&1 || true
}

# 返回 0=已确认落地, 1=未见消息, 2=回查工具不可用。
feishu_confirm() {
  command -v lark-cli >/dev/null 2>&1 || return 2
  local _i
  for _i in 1 2 3; do
    if LARK_CLI_NO_PROXY=1 lark-cli --profile cli_aa80e81017f85bc0 --as user \
         im +chat-messages-list --chat-id "$FEISHU_CHAT_ID" --page-size 20 2>/dev/null \
         | grep -q "盛大白每日 · ${TODAY}"; then
      return 0
    fi
    sleep 3
  done
  return 1
}

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
      log "WARN: 飞书 rc=0 但回查 3 次未见该日 digest, 不标记完成, 后续自动重推"
      ntfy_send "⚠️ daily-digest: 飞书报成功但回查未确认送达($TODAY), 已留待下个窗口自动重推。"
    fi
  else
    log "飞书推送失败 (rc=$rc): ${OUT:-<空>}"
  fi
else
  log "飞书该日已送达, 跳过"
fi

# 微信通道保持关闭。
touch "$WECHAT_DISABLED"
log "微信通道已关闭,只走飞书"

if [ -f "$FEISHU_DONE" ]; then
  touch "$DONE"; log "已标记该日完成(GitHub 已发布 + 飞书送达)"
else
  log "飞书未送达, 不标记完成, 后续定时重试"
  exit 1
fi
log "===== digest 结束 ====="
