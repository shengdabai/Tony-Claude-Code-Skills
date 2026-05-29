#!/usr/bin/env bash
# claude-auto-resume.sh — Claude Code usage-limit 自动恢复 (v2 结构化解析版)
#
# 工作原理:
#   1. 扫 ~/.claude/projects/*/ 下每个项目最新的 jsonl
#   2. 用 jq 提取最后一条 isApiErrorMessage:true 且 text 含 "usage limit" 的事件
#      格式: { type:"assistant", message:{ model:"<synthetic>",
#               content:[{type:"text", text:"...Claude AI usage limit reached|<epoch>..."}] },
#             isApiErrorMessage:true }
#   3. 从该事件 text 抽 epoch, 当 reset_epoch <= now 且后续无新事件(说明会话仍卡着):
#      在该 cwd 执行 `claude -c -p "continue prompt"` 让 Claude 接着干
#   4. 写 (cwd, reset_epoch) 到 state 防重复触发
#   5. 必须有 .omc/plans/*.md 含 pending [ ] ledger 才会触发, 避免唤醒空会话
#
# 由 ~/Library/LaunchAgents/com.tony.claude-auto-resume.plist 每 5 分钟调用
# 日志: ~/.claude/logs/auto-resume.log
# 手动测试: bash ~/.claude/scripts/claude-auto-resume.sh --dry-run
# 自检模式: bash ~/.claude/scripts/claude-auto-resume.sh --self-check

set -uo pipefail

PROJECTS_DIR="${HOME}/.claude/projects"
STATE_DIR="${HOME}/.claude/state"
STATE_FILE="${STATE_DIR}/auto-resume.json"
LOG_DIR="${HOME}/.claude/logs"
LOG_FILE="${LOG_DIR}/auto-resume.log"
CLAUDE_BIN="${HOME}/.local/bin/claude"
NTFY_ENV="${HOME}/.config/ntfy/.env"

# 用绝对路径绕开 RTK/Claude Code 改写的 shell function
JQ=/usr/bin/jq
GREP=/usr/bin/grep
FIND=/usr/bin/find
STAT=/usr/bin/stat
HEAD=/usr/bin/head
TAIL=/usr/bin/tail
SORT=/usr/bin/sort
SED=/usr/bin/sed
CUT=/usr/bin/cut
XARGS=/usr/bin/xargs
DATE=/bin/date
CURL=/usr/bin/curl
MKTEMP=/usr/bin/mktemp
MV=/bin/mv

DRY_RUN=0
SELF_CHECK=0
case "${1:-}" in
  --dry-run)    DRY_RUN=1 ;;
  --self-check) SELF_CHECK=1 ;;
esac

mkdir -p "$STATE_DIR" "$LOG_DIR"
[[ -f "$STATE_FILE" ]] || echo '{"triggered":{}}' > "$STATE_FILE"

log() {
  printf '[%s] %s\n' "$($DATE '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

notify() {
  local msg="$1"
  [[ -f "$NTFY_ENV" ]] || return 0
  # shellcheck source=/dev/null
  source "$NTFY_ENV"
  [[ -n "${NTFY_CLAUDE_TOPIC:-}" ]] || return 0
  $CURL -s -d "$msg" "ntfy.sh/${NTFY_CLAUDE_TOPIC}" >/dev/null 2>&1 || true
}

# ----- self-check 模式: 验证所有依赖, 不扫描 jsonl -----
if (( SELF_CHECK == 1 )); then
  echo "=== claude-auto-resume self-check ==="
  ok=1
  for tool in "$JQ" "$GREP" "$FIND" "$STAT" "$HEAD" "$TAIL" "$SORT" "$SED" "$CUT" "$XARGS" "$DATE" "$CURL" "$MKTEMP" "$MV" "$CLAUDE_BIN"; do
    if [[ -x "$tool" ]]; then echo "  OK: $tool"; else echo "  ❌ MISSING: $tool"; ok=0; fi
  done
  [[ -d "$PROJECTS_DIR" ]] && echo "  OK: $PROJECTS_DIR" || { echo "  ❌ MISSING: $PROJECTS_DIR"; ok=0; }
  [[ -w "$STATE_FILE" ]] && echo "  OK: $STATE_FILE writable" || { echo "  ❌ state file not writable"; ok=0; }
  if "$CLAUDE_BIN" --version >/dev/null 2>&1; then
    echo "  OK: claude --version works"
  else
    echo "  ❌ claude --version failed"; ok=0
  fi
  # 测试 claude 非交互 + 无 TTY 是否能 auth
  if echo "" | "$CLAUDE_BIN" -p "reply ok" 2>/dev/null | $GREP -q .; then
    echo "  OK: claude -p (non-interactive auth) works"
  else
    echo "  ⚠️  claude -p in non-interactive mode may have auth issue (test inconclusive)"
  fi
  (( ok == 1 )) && { echo "全部 OK"; exit 0; } || { echo "失败项见上"; exit 1; }
fi

# ----- 主流程 -----

already_triggered() {
  local key="$1"
  $JQ -e --arg k "$key" '.triggered[$k] // empty' "$STATE_FILE" >/dev/null 2>&1
}

mark_triggered() {
  local key="$1"
  local tmp
  tmp="$($MKTEMP)"
  $JQ --arg k "$key" --arg t "$($DATE '+%Y-%m-%d %H:%M:%S')" \
    '.triggered[$k] = $t' "$STATE_FILE" > "$tmp" && $MV "$tmp" "$STATE_FILE"
}

prune_state() {
  local cutoff
  cutoff="$($DATE -v-7d '+%Y-%m-%d %H:%M:%S' 2>/dev/null || $DATE -d '7 days ago' '+%Y-%m-%d %H:%M:%S')"
  local tmp
  tmp="$($MKTEMP)"
  $JQ --arg c "$cutoff" \
    '.triggered |= with_entries(select(.value > $c))' "$STATE_FILE" > "$tmp" && $MV "$tmp" "$STATE_FILE"
}

# 项目目录是否有 pending TODO (含 [ ] 的 ledger)
has_pending_ledger() {
  local cwd="$1"
  [[ -d "$cwd/.omc/plans" ]] || return 1
  local found
  found="$($GREP -lE '^[[:space:]]*-[[:space:]]*\[ \]' "$cwd"/.omc/plans/*.md 2>/dev/null | $HEAD -1)"
  [[ -n "$found" ]]
}

# 从 jsonl 用 jq 抽最后一条 limit 事件: 返回 "<epoch>|<cwd>" 或空字符串
# 真实事件结构 (基于 isApiErrorMessage:true + model:<synthetic>):
#   { type:"assistant",
#     message:{ model:"<synthetic>",
#               content:[{type:"text", text:"<含 'usage limit reached|<epoch>' 的字符串>"}] },
#     isApiErrorMessage:true, cwd:"<path>" }
# 兼容 text 里可能的两种格式:
#   "Claude AI usage limit reached|1736000000"  (经典)
#   "5-hour limit reached. Resets at 2026-05-16T14:00:00Z"  (新版可能)
extract_limit_event() {
  local jsonl="$1"
  $JQ -r '
    select(
      .type == "assistant"
      and (.isApiErrorMessage == true)
      and ((.message.model // "") == "<synthetic>")
    )
    | (.message.content // [] | map(select(.type=="text") | .text) | join(" ")) as $txt
    | select($txt | test("usage limit reached\\|[0-9]+"; "i"))
    | ($txt | capture("usage limit reached\\|(?<e>[0-9]+)"; "i").e) as $epoch
    | "\($epoch)|\(.cwd // "")"
  ' "$jsonl" 2>/dev/null | $TAIL -1
}

# 检测是否在 limit 事件后会话仍处于 stuck 状态:
#   limit 事件后, 没有任何 user/assistant message 时间戳更晚
# 这个不容易做精确, 我们简化为: limit 事件后超过 60 秒没有新事件 = stuck
session_stuck_after_limit() {
  local jsonl="$1"
  local file_mtime; file_mtime="$($STAT -f '%m' "$jsonl")"
  # 拿最后一条 limit 事件的 timestamp 字符串
  local limit_ts
  limit_ts="$($JQ -r '
    select(.type=="assistant" and .isApiErrorMessage==true and (.message.model // "")=="<synthetic>")
    | (.message.content // [] | map(select(.type=="text")|.text) | join(" ")) as $t
    | select($t | test("usage limit reached"; "i"))
    | .timestamp // empty
  ' "$jsonl" 2>/dev/null | $TAIL -1)"
  [[ -z "$limit_ts" ]] && return 1
  # 把 ISO timestamp 转 epoch
  local limit_epoch
  limit_epoch="$($DATE -j -f '%Y-%m-%dT%H:%M:%S' "${limit_ts%.*}" '+%s' 2>/dev/null || echo 0)"
  (( limit_epoch == 0 )) && return 1
  # 文件最后修改时间距离 limit 事件 < 60s 视为 stuck (没有新事件继续写入)
  local diff=$((file_mtime - limit_epoch))
  (( diff >= -5 && diff <= 60 ))
}

now_epoch="$($DATE +%s)"
prune_state

shopt -s nullglob
fired_count=0
scanned=0
errors=0

for project_dir in "$PROJECTS_DIR"/*/; do
  [[ -d "$project_dir" ]] || continue
  # memory/ 子目录跳过
  [[ "$(basename "$project_dir")" == "memory" ]] && continue

  # 该项目最新的 jsonl
  latest_jsonl="$($FIND "$project_dir" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null \
    | $XARGS -0 $STAT -f '%m %N' 2>/dev/null \
    | $SORT -rn | $HEAD -1 | $CUT -d' ' -f2-)"
  [[ -z "$latest_jsonl" || ! -f "$latest_jsonl" ]] && continue
  scanned=$((scanned + 1))

  file_mtime="$($STAT -f '%m' "$latest_jsonl")"
  age=$((now_epoch - file_mtime))
  (( age > 86400 )) && continue   # > 24h 老会话不管
  (( age < 60 )) && continue       # < 60s 当前活跃会话, 让它自己跑

  # jq 结构化解析 limit 事件
  result="$(extract_limit_event "$latest_jsonl")"
  [[ -z "$result" || "$result" == "|" ]] && continue

  reset_epoch="${result%%|*}"
  cwd="${result#*|}"
  [[ -z "$reset_epoch" || -z "$cwd" ]] && continue

  # epoch 合法性: [now-24h, now+24h]
  if (( reset_epoch < now_epoch - 86400 || reset_epoch > now_epoch + 86400 )); then
    log "跳过脏数据: $latest_jsonl reset_epoch=$reset_epoch 超出合法范围"
    continue
  fi

  [[ ! -d "$cwd" ]] && { log "跳过: cwd 不存在 $cwd"; continue; }

  key="${cwd}|${reset_epoch}"
  already_triggered "$key" && continue

  if (( reset_epoch > now_epoch )); then
    log "等待中: $cwd 还需 $(( (reset_epoch - now_epoch) / 60 )) 分钟解锁 (key=$key)"
    continue
  fi

  if ! has_pending_ledger "$cwd"; then
    log "跳过: $cwd 解锁但无 .omc/plans/*.md 含 [ ] pending"
    mark_triggered "$key"
    continue
  fi

  log "触发恢复: cwd=$cwd reset_epoch=$reset_epoch jsonl=$(basename "$latest_jsonl")"

  if (( DRY_RUN == 1 )); then
    printf '[DRY-RUN] 会执行: cd %q && %s -c -p "..."\n' "$cwd" "$CLAUDE_BIN"
    continue
  fi

  prompt="usage limit 已解除。请读 .omc/plans/ 里所有含 [ ] 的 ledger 文件,选最相关的一个,逐项继续执行未完成的任务。每完成一项把 [ ] 改成 [x] 并保存。"

  # 用 setsid 让子进程完全脱离 launchd, 不会被它当成超时回收
  # 后台模式: nohup + & + disown
  log_stem="$LOG_DIR/resume-$($DATE +%Y%m%d-%H%M%S)-$(basename "$cwd")"
  (
    cd "$cwd" || exit 1
    nohup "$CLAUDE_BIN" -c -p "$prompt" \
      > "${log_stem}.stdout.log" \
      2> "${log_stem}.stderr.log" < /dev/null &
    disown
  )

  mark_triggered "$key"
  fired_count=$((fired_count + 1))
  notify "🤖 Claude 自动恢复: $(basename "$cwd")"
done

log "扫描 $scanned 个项目, 触发 $fired_count 次恢复, 错误 $errors"
exit 0
