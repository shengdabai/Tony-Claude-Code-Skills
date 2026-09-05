#!/usr/bin/env bash
# claude-auto-resume.sh — Claude Code usage-limit 自动恢复 (v2 结构化解析版)
#
# 工作原理:
#   1. 扫 ~/.claude/projects/*/ 下每个项目最新的 jsonl
#   2. 用 jq 提取最后一条 isApiErrorMessage:true 且 text 含 "usage limit" 的事件
#      格式: { type:"assistant", message:{ model:"<synthetic>",
#               content:[{type:"text", text:"...Claude AI usage limit reached|<epoch>..."}] },
#             isApiErrorMessage:true }
#   3. 从该事件 text 抽 epoch, 当 reset_epoch <= now 且后续无 user/assistant 消息：
#      同工作目录无 Claude 进程且状态可确认时，以 --resume 绑定原会话恢复
#   4. 写 (cwd, session_id, reset_epoch) 到 state 防重复；兼容旧去重键
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
# 2026-08-29:改指守卫包装器,不再直调 REAL_BIN。
# 直调 ~/.local/bin/claude 会绕过官方端点强制、第三方 ANTHROPIC_* 剥离、模型改写,
# 以及飞书瘦身分支 —— 恢复出来的会话配置与正常会话不一致。守卫最终 exec 同一个二进制。
CLAUDE_BIN="${HOME}/.claude/bin/claude"
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
RESUME_PS=/bin/ps
RESUME_LSOF=/usr/sbin/lsof

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
# 当前仅识别带 epoch 的旧格式；未知格式跳过，不猜测重置时间。
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

# Only resume if the last user/assistant event is the recognised quota failure.
# Metadata events do not reset it; any later conversation event does.
session_stuck_after_limit() {
  local jsonl="$1"
  $JQ -en '
    reduce inputs as $event (false;
      if ($event.type == "user" or $event.type == "assistant") then
        ($event.type == "assistant"
          and $event.isApiErrorMessage == true
          and (($event.message.model // "") == "<synthetic>")
          and ((($event.message.content // [] | map(select(.type == "text") | .text) | join(" "))
            | test("usage limit reached\\|[0-9]+"; "i"))))
      else . end)
  ' "$jsonl" >/dev/null 2>&1
}

resume_session_id() {
  local name="${1##*/}"
  name="${name%.jsonl}"
  [[ "$name" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || return 1
  printf '%s\n' "$name"
}

valid_reset_epoch() {
  [[ "$1" =~ ^[1-9][0-9]{9}$ ]]
}

# Conservative workspace-level guard: 0 active, 1 idle, 2 unknown.
# Never treat a failed process/cwd inspection as permission to resume.
workspace_claude_state() {
  local target_cwd="$1" snapshot pid command cwd_records record
  [[ -x "$RESUME_PS" && -x "$RESUME_LSOF" ]] || return 2
  target_cwd="$(cd "$target_cwd" && pwd -P)" || return 2
  snapshot="$("$RESUME_PS" -axo pid=,comm= 2>/dev/null)" || return 2
  while read -r pid command; do
    case "$command" in claude|*/claude) ;; *) continue ;; esac
    if ! cwd_records="$("$RESUME_LSOF" -a -p "$pid" -d cwd -Fn 2>/dev/null)"; then
      "$RESUME_PS" -p "$pid" -o pid= >/dev/null 2>&1 && return 2
      continue
    fi
    [[ "$cwd_records" == *$'\nn'* || "$cwd_records" == n* ]] || return 2
    while IFS= read -r record; do
      [[ "$record" == n* && "${record#n}" == "$target_cwd" ]] && return 0
    done <<< "$cwd_records"
  done <<< "$snapshot"
  return 1
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

  session_stuck_after_limit "$latest_jsonl" || continue
  resume_id="$(resume_session_id "$latest_jsonl")" || {
    log "跳过: 会话文件名不能确定精确 session ID"
    continue
  }

  # jq 结构化解析 limit 事件
  result="$(extract_limit_event "$latest_jsonl")"
  [[ -z "$result" || "$result" == "|" ]] && continue

  reset_epoch="${result%%|*}"
  cwd="${result#*|}"
  [[ -z "$reset_epoch" || -z "$cwd" ]] && continue

  valid_reset_epoch "$reset_epoch" || {
    log "跳过: reset_epoch 格式非法"
    continue
  }

  # epoch 合法性: [now-24h, now+24h]
  if (( reset_epoch < now_epoch - 86400 || reset_epoch > now_epoch + 86400 )); then
    log "跳过脏数据: $latest_jsonl reset_epoch=$reset_epoch 超出合法范围"
    continue
  fi

  [[ ! -d "$cwd" ]] && { log "跳过: cwd 不存在 $cwd"; continue; }

  # Honor old dedupe entries during migration; new entries are session-specific.
  already_triggered "${cwd}|${reset_epoch}" && continue
  key="${cwd}|${resume_id}|${reset_epoch}"
  already_triggered "$key" && continue

  if (( reset_epoch > now_epoch )); then
    log "等待中: $cwd 还需 $(( (reset_epoch - now_epoch) / 60 )) 分钟解锁 (key=$key)"
    continue
  fi

  if workspace_claude_state "$cwd"; then
    log "跳过: 同一工作目录仍有 Claude 进程"
    continue
  else
    resume_process_state=$?
    if [[ "$resume_process_state" != 1 ]]; then
      log "跳过: 无法确认工作目录内 Claude 进程状态"
      continue
    fi
  fi

  if ! has_pending_ledger "$cwd"; then
    log "跳过: $cwd 解锁但无 .omc/plans/*.md 含 [ ] pending"
    mark_triggered "$key"
    continue
  fi

  log "触发恢复: cwd=$cwd reset_epoch=$reset_epoch jsonl=$(basename "$latest_jsonl")"

  if (( DRY_RUN == 1 )); then
    printf '[DRY-RUN] 会执行: cd %q && %s --resume %q --model claude-opus-5 -p "..."\n' "$cwd" "$CLAUDE_BIN" "$resume_id"
    continue
  fi

  prompt="usage limit 已解除。仅继续本会话中已授权且被限额中断的原任务。根据本会话明确的任务名、范围或既有 ledger 路径定位唯一对应的 .omc/plans/ 进度文件；没有唯一明确匹配时停止并报告，不按修改时间或相关性猜测，不执行其他任务。逐项继续 - [ ] item-N: 未完成项，完成后改成 - [x] 并保存。"

  # 飞书 workspace 的恢复:这条会话不经过 bridge,产出默认回不到聊天里 ——
  # Tony 只会看到任务"没动静"。让它自己用 lark-cli 把结果发回原 chat。
  # --resume 绑定发生限额的会话；chat_id 仍须从该会话可靠确认。
  slim_env=()
  case "$cwd" in
    *"/.lark-channel-workspaces/"*|*"/.agent-feishu-channel/"*)
      prompt="${prompt} 本会话来自飞书:全部做完后,从上下文里的 <bridge_context> 取 chatId,用 lark-cli 把一段不超过 450 字的完成摘要发回**同一个** chat(私聊回私聊、群聊回群聊);取不到 chatId 就不要外发,只在 ledger 里记录完成情况。"
      # 恢复出来的会话同样吃瘦身配置,与正常飞书会话保持一致
      slim_env=(CLAUDE_LARK_SLIM=1)
      ;;
  esac

  # 后台启动：nohup + & + disown；不宣称创建独立进程会话。
  log_stem="$LOG_DIR/resume-$($DATE +%Y%m%d-%H%M%S)-$(basename "$cwd")"
  (
    cd "$cwd" || exit 1
    nohup env ${slim_env[@]+"${slim_env[@]}"} "$CLAUDE_BIN" --resume "$resume_id" --model claude-opus-5 -p "$prompt" \
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
