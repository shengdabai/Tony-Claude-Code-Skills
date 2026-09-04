#!/bin/bash
# 每日合并推送: 思考(daily-article) + AI 热点(daily-ai-news) 两篇都齐后,
# 渲染国内静态站 → 只推【一条】飞书(双篇摘要 + 国内秒开全文链接)。
# 幂等 + 飞书送达回查。由 launchd 定时触发,也支持 DAILY_DIGEST_DATE=YYYY-MM-DD 补发。
set -uo pipefail

WORK="$HOME/.local/share/tony-articles"
LOG="$HOME/.claude/logs/daily-digest.log"
TODAY="${DAILY_DIGEST_DATE:-$(TZ=Asia/Shanghai date +%Y-%m-%d)}"
SITE_BASE="http://111.229.77.103:8080"
FEISHU_TARGET="feishu:oc_43c5ee271f2b76bd073779a169736142"
FEISHU_CHAT_ID="${FEISHU_TARGET#feishu:}"
RENDER="$HOME/.claude/scripts/render-site.py"
HERMES_GATEWAY_PLIST="$HOME/Library/LaunchAgents/ai.hermes.gateway.plist"
HERMES_GATEWAY_PY="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$HERMES_GATEWAY_PLIST" 2>/dev/null || true)"
HERMES_SEND_WRAPPER="$HOME/.claude/scripts/hermes-send-direct-feishu.py"
DONE="$HOME/.claude/logs/.daily-digest-done-${TODAY}"
FEISHU_DONE="$HOME/.claude/logs/.daily-digest-feishu-${TODAY}"
WECHAT_DISABLED="$HOME/.claude/logs/.daily-digest-wechat-disabled-${TODAY}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
. "$HOME/.claude/scripts/daily-publish-common.sh"
log "===== digest $TODAY ====="

if ! [[ "$TODAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  log "ERROR: DAILY_DIGEST_DATE 格式错误: $TODAY"
  exit 2
fi
NEXT_DAY="$(python3 - "$TODAY" <<'PY'
import datetime, sys
print((datetime.date.fromisoformat(sys.argv[1]) + datetime.timedelta(days=1)).isoformat())
PY
)" || { log "ERROR: 无法计算飞书查询结束日期"; exit 2; }

# 两个生成任务完成后会主动触发分发，launchd 也会在 13:30–16:30 每小时补偿。
# 用 mkdir 原子抢锁，并在任何网络/仓库检查之前加锁，避免两个进程同时
# 查重后都发送，或重复执行昂贵的站点同步。
LOCK_DIR="$HOME/.claude/logs/.daily-digest-${TODAY}.lock.d"
if ! daily_lock_acquire "$LOCK_DIR" 1200; then
  log "该日 digest 已有实例运行或锁仍在宽限期，本次幂等跳过"
  exit 0
fi
DIGEST_LOCK_OWNER="$DAILY_LOCK_OWNER"
digest_cleanup() {
  daily_lock_release "$LOCK_DIR" "$DIGEST_LOCK_OWNER" 2>/dev/null || true
}
trap digest_cleanup EXIT

# 生成任务可在中午前完成并主动触发本脚本，但当天飞书合并摘要必须等到
# 12:00 才发送。历史补发不受限制；紧急人工恢复可显式覆盖。
CURRENT_DATE="$(TZ=Asia/Shanghai date +%Y-%m-%d)"
CURRENT_HOUR="$(TZ=Asia/Shanghai date +%H)"
if [ "$TODAY" = "$CURRENT_DATE" ] &&
   [ "${CURRENT_HOUR#0}" -lt 12 ] &&
   [ "${DAILY_DIGEST_FORCE_EARLY:-0}" != "1" ]; then
  log "当天内容已进入分发检查，但未到 12:00，等待正式定时触发"
  exit 0
fi

# 已完成日期的定时重入必须完全无副作用；dry-run 仍执行全链路只读检查。
if [ -f "$DONE" ] && [ "${DAILY_DIGEST_DRY_RUN:-0}" != "1" ]; then
  log "该日已推送, 跳过"
  exit 0
fi

for dep in git python3 lark-cli "$RENDER" "$HERMES_GATEWAY_PY"; do
  if [ "${dep#/}" = "$dep" ]; then
    command -v "$dep" >/dev/null 2>&1 || { log "ERROR: 依赖不存在: $dep"; exit 1; }
  elif [ ! -x "$dep" ]; then
    log "ERROR: 依赖不可执行: $dep"; exit 1
  fi
done

daily_infra_preflight "daily-digest" 0 || { log "ERROR: 发布基础设施预检失败，等待下个窗口"; exit 1; }

# launchd 独立触发时也先同步 GitHub main。只允许干净 checkout 做安全快进。
cd "$WORK" || { log "FATAL: 工作目录不存在 $WORK"; exit 1; }
if [ -z "$(git status --porcelain)" ]; then
  if daily_git_retry fetch -q origin main; then
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
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || {
    log "ERROR: 本地 HEAD 领先或不同于 origin/main，拒绝用未发布内容生成站点或飞书摘要"
    exit 1
  }
else
  log "ERROR: 主发布 checkout 有未提交改动，拒绝用不确定状态推送飞书"
  exit 1
fi

# 中英文各自的思考+热点是否齐；只在远端 main 四文件齐全后分发。
ZH_ART=$(find "$WORK/articles/zh" -maxdepth 1 -type f -name "${TODAY}-*.md" -print | head -1)
ZH_NEWS=$(find "$WORK/ai-news/zh" -maxdepth 1 -type f -name "${TODAY}-*.md" -print | head -1)
EN_ART=$(find "$WORK/articles/en" -maxdepth 1 -type f -name "${TODAY}-*.md" -print | head -1)
EN_NEWS=$(find "$WORK/ai-news/en" -maxdepth 1 -type f -name "${TODAY}-*.md" -print | head -1)
if [ -z "$ZH_ART" ] || [ -z "$ZH_NEWS" ] || [ -z "$EN_ART" ] || [ -z "$EN_NEWS" ]; then
  log "中英文四文件未齐(中文思考=${ZH_ART:-无} 中文热点=${ZH_NEWS:-无} 英文思考=${EN_ART:-无} 英文热点=${EN_NEWS:-无}), 等后续触发"; exit 0
fi
log "中英文双篇齐: 思考=$(basename "$ZH_ART") 热点=$(basename "$ZH_NEWS")"

ART_REL="${ZH_ART#"$WORK"/}"
NEWS_REL="${ZH_NEWS#"$WORK"/}"
EN_ART_REL="${EN_ART#"$WORK"/}"
EN_NEWS_REL="${EN_NEWS#"$WORK"/}"
if ! git cat-file -e "origin/main:${ART_REL}" 2>/dev/null ||
   ! git cat-file -e "origin/main:${NEWS_REL}" 2>/dev/null ||
   ! git cat-file -e "origin/main:${EN_ART_REL}" 2>/dev/null ||
   ! git cat-file -e "origin/main:${EN_NEWS_REL}" 2>/dev/null; then
  log "ERROR: 中英文双篇未同时进入 origin/main，拒绝提前推送飞书"
  exit 1
fi

# dry-run 覆盖路由、依赖、日期、文章齐备和远端发布门槛，不产生外部写入。
if [ "${DAILY_DIGEST_DRY_RUN:-0}" = "1" ]; then
  log "DRY_RUN: 中英文双篇已在 origin/main，飞书目标与依赖检查通过；未同步站点、未发送消息"
  exit 0
fi

# 渲染 + 同步国内站；失败时摘要仍可阅读，因此继续发送并记录告警。
if bash "$HOME/.claude/scripts/sync-site.sh" >>"$LOG" 2>&1; then
  log "站点同步成功"
else
  log "WARN: 站点同步失败, 仍推送(摘要可读, 链接稍后生效)"
fi

ntfy_send() {
  [ -f "$HOME/.config/ntfy/.env" ] || return 0
  source "$HOME/.config/ntfy/.env"
  [ -n "${NTFY_CLAUDE_TOPIC:-}" ] || return 0
  curl -s -m 3 -d "$1" "ntfy.sh/${NTFY_CLAUDE_TOPIC}" >/dev/null 2>&1 || true
}

MSGFILE="$HOME/.claude/logs/.digest-msg-${TODAY}.txt"
python3 "$RENDER" message "$TODAY" "$SITE_BASE" > "$MSGFILE" 2>>"$LOG"
if [ ! -s "$MSGFILE" ]; then log "ERROR: 合并消息为空, 退出"; exit 1; fi
DIGEST_FINGERPRINT="daily-digest-delivery:${TODAY}"
printf '\n\n— delivery-id: %s\n' "$DIGEST_FINGERPRINT" >> "$MSGFILE"
MSG="$(cat "$MSGFILE")"
MSG_CHARS="$(python3 -c 'import sys; print(len(sys.stdin.read()))' <<<"$MSG")"
if [ "$MSG_CHARS" -gt 7000 ]; then
  log "FATAL: 合并摘要 ${MSG_CHARS} 字超过单条安全上限 7000，拒绝分片发送"
  ntfy_send "⚠️ daily-digest: 当日摘要超过 7000 字($TODAY)，已拒绝分片发送。"
  exit 1
fi

# 返回 0=恰好 1 条, 1=0 条, 2=回查不可用, 3=超过 1 条。
feishu_confirm() {
  command -v lark-cli >/dev/null 2>&1 || return 2
  local _i _page _token _out _rc _page_data _page_count _complete _total
  for _i in 1 2 3; do
    _token=""
    _page=0
    _complete=0
    _total=0
    while [ "$_page" -lt 20 ]; do
      _page=$((_page + 1))
      if [ -n "$_token" ]; then
        _out="$(LARK_CLI_NO_PROXY=1 lark-cli --profile cli_aa80e81017f85bc0 --as user \
          im +chat-messages-list --chat-id "$FEISHU_CHAT_ID" \
          --start "$TODAY" --end "$NEXT_DAY" --sort desc --page-size 50 \
          --page-token "$_token" --format json 2>/dev/null)"
      else
        _out="$(LARK_CLI_NO_PROXY=1 lark-cli --profile cli_aa80e81017f85bc0 --as user \
          im +chat-messages-list --chat-id "$FEISHU_CHAT_ID" \
          --start "$TODAY" --end "$NEXT_DAY" --sort desc --page-size 50 \
          --format json 2>/dev/null)"
      fi
      _rc=$?
      [ "$_rc" -eq 0 ] || break
      _page_data="$(python3 -c 'import json,sys
d=json.load(sys.stdin).get("data") or {}
needle, fingerprint=sys.argv[1:3]
print(sum(1 for m in (d.get("messages") or [])
          if needle in str(m.get("content") or "")
          and fingerprint in str(m.get("content") or "")))
print(d.get("page_token") or "-")' "盛大白每日 · ${TODAY}" "$DIGEST_FINGERPRINT" <<<"$_out" 2>/dev/null)" || { _success=0; break; }
      _page_count="${_page_data%%$'\n'*}"
      _total=$((_total + _page_count))
      _token="${_page_data#*$'\n'}"
      [ "$_token" != "-" ] || _token=""
      if [ -z "$_token" ]; then
        _complete=1
        break
      fi
    done
    if [ "$_complete" -eq 1 ]; then
      [ "$_total" -eq 1 ] && return 0
      [ "$_total" -eq 0 ] && return 1
      log "FATAL: 飞书历史中当日 digest 出现 ${_total} 条，停止自动发送"
      return 3
    fi
    sleep 3
  done
  return 2
}

# 发送前先查飞书真实历史。这样即使上一次发送后进程崩溃、marker 未落盘，
# 也只会补齐本地状态，绝不会再发第二条。
feishu_confirm; pre_cf=$?
if [ "$pre_cf" -eq 0 ]; then
  touch "$FEISHU_DONE" "$WECHAT_DISABLED" "$DONE"
  rm -f "$HOME/.claude/logs/.daily-digest-send-attempt-${TODAY}" 2>/dev/null || true
  log "飞书历史已存在该日 digest，已补齐本地完成标记并跳过发送"
  exit 0
elif [ "$pre_cf" -eq 2 ]; then
  log "ERROR: 发送前飞书回查不可用；为避免重复推送，本窗口暂停发送"
  ntfy_send "⚠️ daily-digest: 发送前无法回查飞书($TODAY)，已安全暂停，未发送。"
  exit 1
elif [ "$pre_cf" -eq 3 ]; then
  ntfy_send "⚠️ daily-digest: 飞书历史中当日摘要不止 1 条($TODAY)，已停止自动发送。"
  exit 1
fi

if [ ! -f "$FEISHU_DONE" ]; then
  SEND_ATTEMPT="$HOME/.claude/logs/.daily-digest-send-attempt-${TODAY}"
  if [ -f "$SEND_ATTEMPT" ]; then
    log "ERROR: 存在未确认的飞书发送尝试；停止自动重发，需人工核验后清除 marker"
    ntfy_send "⚠️ daily-digest: 上一次飞书发送结果未确认($TODAY)，已 fail closed，需人工核验。"
    exit 1
  else
    if ! (set -C; date +%s > "$SEND_ATTEMPT") 2>/dev/null; then
      log "ERROR: 无法原子建立飞书发送 marker，停止发送"
      exit 1
    fi
  fi
  # 通过 Commander bot 直接发送；hermes send 不运行 LLM/Agent loop。
  # 禁止以 Tony 用户身份向 Commander 私聊发送，否则会被当成新指令。
  SEND_ERR="$HOME/.claude/logs/.daily-digest-send-${TODAY}.stderr.log"
  OUT="$(daily_run_with_timeout 120 env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
    -u http_proxy -u https_proxy -u all_proxy \
    "$HERMES_GATEWAY_PY" "$HERMES_SEND_WRAPPER" send \
    --to "feishu:${FEISHU_CHAT_ID}" --file "$MSGFILE" --json \
    2>"$SEND_ERR")"; rc=$?
  send_ok="$(python3 -c 'import json,sys
try:
    print("yes" if (json.load(sys.stdin) or {}).get("success") is True else "no")
except Exception:
    print("no")' <<<"$OUT")"
  if [ "$rc" -eq 0 ] && [ "$send_ok" = "yes" ]; then
    sleep 5
    feishu_confirm; cf=$?
    if [ "$cf" -eq 0 ]; then
      touch "$FEISHU_DONE"
      rm -f "$SEND_ATTEMPT" 2>/dev/null || true
      log "Commander bot 直发成功+发送前查重+回查确认落地 -> $FEISHU_TARGET"
    elif [ "$cf" -eq 2 ]; then
      log "WARN: 飞书 rc=0 但回查工具不可用；不信任单一返回值，不标记完成"
      ntfy_send "⚠️ daily-digest: 飞书返回成功但无法回查($TODAY)，已停止标记，后续先查重。"
    else
      log "WARN: Commander bot 直发 rc=0 但未确认当日 digest 恰好 1 条；保留 marker 并 fail closed"
      ntfy_send "⚠️ daily-digest: Commander bot 直发后未确认当日摘要恰好 1 条($TODAY)，已 fail closed。"
    fi
  else
    stderr_len="$(wc -c < "$SEND_ERR" 2>/dev/null | tr -d ' ' || echo 0)"
    log "飞书推送失败 (rc=$rc stdout_len=${#OUT} stderr_len=${stderr_len})"
    ntfy_send "⚠️ daily-digest: Commander bot 直发失败($TODAY, rc=$rc)，已保留 marker 并停止自动重发。"
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
