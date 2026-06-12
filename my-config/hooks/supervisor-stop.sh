#!/usr/bin/env bash
# supervisor-stop.sh — Claude Code 监工 (Stop hook)
#
# 在 Claude 每次"停下"时判断该不该逼它继续工作,补上 auto-resume 没覆盖的
# 所有"会话内暂停":自然结束就停、提前宣称完成、把工具调用写成纯文本卡死、
# 停下来问无关问题等。
#
# 双模:
#   - 账本守门(默认): 仅当 cwd 有 .omc/plans/*.md 含未完成 [ ] 时才续跑;
#                      普通聊天/任务已完成时完全静默,不烧 token。
#   - 激进常开:        每次停下都续跑,直到完成哨兵 [监工:完成] 或撞上限。
#                      由全局 ~/.claude/state/supervisor.aggressive 或
#                      <cwd>/.omc/supervisor.aggressive 标志开启。
#
# 续跑机制: 输出 {"decision":"block","reason":"..."} 让 Claude 接着干。
#
# 安全兜底(两模都生效):
#   - 硬循环上限   SUPERVISOR_MAX_LOOPS      (账本默认 30 / 激进默认 12)
#   - 墙钟上限     SUPERVISOR_MAX_SECONDS    (默认 7200 = 2h)
#   - 停滞检测     SUPERVISOR_STALL_LIMIT    (账本快照连续 N 次不变 → 放行, 默认 5)
#   - 杀总闸       ~/.claude/state/supervisor.off  或  env DISABLE_SUPERVISOR=1
#   - 完成哨兵     last assistant 文本含 [监工:完成]  或  <cwd>/.omc/supervisor.done
#
# 输入(stdin JSON): { stop_hook_active, cwd, session_id, transcript_path }
# 状态: ~/.claude/state/supervisor-loops.json   日志: ~/.claude/logs/supervisor.log
# 手动测试: echo '{"cwd":"'$PWD'","session_id":"t","stop_hook_active":false}' | bash supervisor-stop.sh

set -uo pipefail

STATE_DIR="${HOME}/.claude/state"
STATE_FILE="${STATE_DIR}/supervisor-loops.json"
OFF_FLAG="${STATE_DIR}/supervisor.off"
AGGR_FLAG_GLOBAL="${STATE_DIR}/supervisor.aggressive"
LOG_DIR="${HOME}/.claude/logs"
LOG_FILE="${LOG_DIR}/supervisor.log"

PY=/usr/bin/python3
JQ=/usr/bin/jq
DATE=/bin/date
GREP=/usr/bin/grep

MAX_SECONDS="${SUPERVISOR_MAX_SECONDS:-7200}"
STALL_LIMIT="${SUPERVISOR_STALL_LIMIT:-5}"
# 账本时效门: 只有最近 N 秒内修改过的 ledger 才算"活跃待办"(默认 24h)。
# 防止三周前废弃的 ledger 一直把会话拽住。设 0 关闭时效门(任何 pending 都触发)。
LEDGER_MAX_AGE="${SUPERVISOR_LEDGER_MAX_AGE:-86400}"

mkdir -p "$STATE_DIR" "$LOG_DIR" 2>/dev/null
[[ -f "$STATE_FILE" ]] || echo '{}' > "$STATE_FILE"

log() { printf '[%s] %s\n' "$($DATE '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE" 2>/dev/null; }

# 发 ntfy(失败静默, 最多等 2s 不拖慢停下)。SUPERVISOR_NTFY_DRYRUN=1 时只打日志不真发。
ntfy_send() {
  local msg="$1"
  if [[ "${SUPERVISOR_NTFY_DRYRUN:-}" == "1" ]]; then
    log "[ntfy-dryrun] $msg"; return 0
  fi
  local env="$HOME/.config/ntfy/.env"
  [[ -f "$env" ]] || return 0
  # shellcheck disable=SC1090
  source "$env" 2>/dev/null
  [[ -n "${NTFY_CLAUDE_TOPIC:-}" ]] && /usr/bin/curl -s -m 2 -d "$msg" "ntfy.sh/${NTFY_CLAUDE_TOPIC}" >/dev/null 2>&1 || true
}

# 放行(允许 Claude 正常停下)。放行 == Claude 真的要停 → 发"任务完成"通知。
# 传 silent 跳过(用于 cap/stall 分支, 它们已自带 🛑/⚠️ 告警, 避免双推送)。
allow_stop() {
  [[ "${1:-}" != "silent" ]] && ntfy_send "✅ 任务完成"
  exit 0
}

# 逼 Claude 续跑(续跑时绝不发完成通知)
force_continue() {
  local reason="$1"
  printf '{"decision":"block","reason":%s}\n' "$($PY -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$reason")"
  exit 0
}

# ---- 杀总闸 ----
[[ -f "$OFF_FLAG" ]] && allow_stop
[[ "${DISABLE_SUPERVISOR:-}" == "1" ]] && allow_stop
[[ "${OMC_SKIP_HOOKS:-}" == *supervisor* ]] && allow_stop

INPUT=$(cat 2>/dev/null || echo '{}')

# ---- 解析输入 ----
# python 逐行输出 4 个字段(每字段独占一行, 天然容忍路径含空格)
{
  IFS= read -r CWD
  IFS= read -r SESSION_ID
  IFS= read -r STOP_ACTIVE
  IFS= read -r TRANSCRIPT
} < <(printf '%s' "$INPUT" | $PY -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
def g(k):
    v=d.get(k,""); return str(v) if v is not None else ""
print(g("cwd") or "'"$PWD"'")
print(g("session_id") or "default")
print("1" if d.get("stop_hook_active") else "0")
print(g("transcript_path"))
' 2>/dev/null)
[[ -z "${CWD:-}" ]] && CWD="$PWD"
[[ -d "$CWD" ]] || allow_stop

# ---- 完成哨兵: <cwd>/.omc/supervisor.done ----
if [[ -f "$CWD/.omc/supervisor.done" ]]; then
  log "完成哨兵文件存在, 放行: $CWD"
  rm -f "$CWD/.omc/supervisor.done" 2>/dev/null
  allow_stop
fi

# ---- 完成哨兵: 最后一条 assistant 文本含 [监工:完成] ----
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  # 只看最后 ~400 行, 避免超大 transcript 读整文件拖慢/超时
  # 用 -c 传脚本, stdin 留给 tail 的管道数据(切勿用 `python - <<EOF`, 会抢占 stdin)
  LAST_DONE="$(/usr/bin/tail -n 400 "$TRANSCRIPT" 2>/dev/null | $PY -c '
import json,sys
last=""
for line in sys.stdin:
    try: e=json.loads(line)
    except Exception: continue
    if e.get("type")=="assistant":
        msg=e.get("message",{})
        parts=msg.get("content",[]) if isinstance(msg,dict) else []
        txt=" ".join(p.get("text","") for p in parts if isinstance(p,dict) and p.get("type")=="text")
        if txt.strip(): last=txt
print("DONE" if ("[监工:完成]" in last or "[SUPERVISOR:DONE]" in last) else "")
' 2>/dev/null)"
  if [[ "$LAST_DONE" == "DONE" ]]; then
    log "检测到 [监工:完成] 哨兵, 放行: $CWD"
    allow_stop
  fi
fi

# ---- 判定模式 ----
MODE="ledger"
if [[ -f "$AGGR_FLAG_GLOBAL" || -f "$CWD/.omc/supervisor.aggressive" ]]; then
  MODE="aggressive"
fi

# ---- 账本快照(用于停滞检测 + 账本守门判定) ----
# 拼接所有 ledger 的 [ ]/[x] 行做指纹; PENDING 标记是否还有未完成项
LEDGER_INFO="$($PY - "$CWD" "$LEDGER_MAX_AGE" <<'PYEOF' 2>/dev/null
import sys,glob,os,hashlib,time
cwd=sys.argv[1]
maxage=float(sys.argv[2]) if len(sys.argv)>2 else 86400.0
now=time.time()
files=sorted(glob.glob(os.path.join(cwd,".omc","plans","*.md")))
lines=[]
pending=False
for fp in files:
    try:
        if maxage>0 and (now-os.path.getmtime(fp))>maxage:
            continue  # 陈旧账本(超过时效门)不触发督促
        with open(fp,encoding="utf-8",errors="ignore") as f:
            for ln in f:
                s=ln.strip()
                if len(s)>=5 and s[2]=="[" and s[4]=="]":  # "- [ ] " / "- [x] " / "- [!] "
                    box=s[2:5]  # "[ ]" / "[x]" / "[!]"
                    lines.append(s)
                    if box=="[ ]": pending=True
    except Exception: pass
h=hashlib.md5(("\n".join(lines)).encode()).hexdigest()[:12] if lines else "none"
print(("PENDING" if pending else "CLEAR")+" "+h)
PYEOF
)"
PENDING_STATE="${LEDGER_INFO%% *}"
LEDGER_HASH="${LEDGER_INFO##* }"
[[ -z "$LEDGER_HASH" ]] && LEDGER_HASH="none"

# ---- 账本守门: 无 pending 直接放行(静默) ----
if [[ "$MODE" == "ledger" ]]; then
  if [[ "$PENDING_STATE" != "PENDING" ]]; then
    allow_stop   # 没有未完成 ledger → 正常聊天/已完成, 不打扰
  fi
  MAX_LOOPS="${SUPERVISOR_MAX_LOOPS:-30}"
else
  MAX_LOOPS="${SUPERVISOR_MAX_LOOPS:-12}"
fi

NOW="$($DATE +%s)"

# ---- 读/更新循环状态 (per session_id) ----
# state: { "<sid>": {count, started, hash, stall} }
read -r COUNT STARTED PREV_HASH STALL <<<"$(
  $JQ -r --arg s "$SESSION_ID" '
    (.[$s] // {}) as $e
    | "\(($e.count // 0)) \(($e.started // 0)) \(($e.hash // "init")) \(($e.stall // 0))"
  ' "$STATE_FILE" 2>/dev/null
)"
COUNT="${COUNT:-0}"; STARTED="${STARTED:-0}"; PREV_HASH="${PREV_HASH:-init}"; STALL="${STALL:-0}"
[[ "$STARTED" == "0" ]] && STARTED="$NOW"

COUNT=$((COUNT + 1))

# 停滞计数: ledger 模式下指纹不变 → stall+1; 变了 → 归零(有进展)
if [[ "$MODE" == "ledger" ]]; then
  if [[ "$LEDGER_HASH" == "$PREV_HASH" ]]; then
    STALL=$((STALL + 1))
  else
    STALL=0
  fi
fi

# 写回状态
TMP="$($JQ -n --arg s "$SESSION_ID" --argjson c "$COUNT" --argjson st "$STARTED" \
  --arg h "$LEDGER_HASH" --argjson sl "$STALL" --slurpfile cur "$STATE_FILE" \
  '($cur[0] // {}) | .[$s] = {count:$c, started:$st, hash:$h, stall:$sl}' 2>/dev/null)"
if [[ -n "$TMP" ]]; then
  _stf="$(/usr/bin/mktemp)" && printf '%s' "$TMP" > "$_stf" && /bin/mv "$_stf" "$STATE_FILE"
fi

ELAPSED=$((NOW - STARTED))

# ---- 兜底放行条件(自带告警通知, 放行用 silent 避免重复发完成通知) ----
if (( COUNT > MAX_LOOPS )); then
  log "放行(循环上限 $MAX_LOOPS): sid=$SESSION_ID mode=$MODE cwd=$CWD"
  ntfy_send "🛑 监工: 达到循环上限($MAX_LOOPS)已停, $(basename "$CWD")"
  allow_stop silent
fi
if (( ELAPSED > MAX_SECONDS )); then
  log "放行(墙钟上限 ${MAX_SECONDS}s): sid=$SESSION_ID cwd=$CWD"
  ntfy_send "🛑 监工: 达到时间上限已停, $(basename "$CWD")"
  allow_stop silent
fi
if [[ "$MODE" == "ledger" ]] && (( STALL >= STALL_LIMIT )); then
  log "放行(停滞 $STALL 次账本无进展): sid=$SESSION_ID cwd=$CWD"
  ntfy_send "⚠️ 监工: 进度停滞($STALL 轮无变化)疑似卡住, $(basename "$CWD")"
  allow_stop silent
fi

# ---- 续跑 ----
if [[ "$MODE" == "ledger" ]]; then
  REASON="你停下了,但 .omc/plans/ 里还有未完成的 [ ] 任务(第 ${COUNT}/${MAX_LOOPS} 轮续跑)。请:
1. 读所有含 [ ] 的 ledger,选最相关的一个,继续执行下一项未完成任务。
2. 每完成一项立即把 [ ] 改成 [x] 并保存;失败的标 [!] 写明原因,不阻塞后续。
3. ⚠️ 如果你上一轮把工具调用写成了纯文本/代码块而没有真正调用工具,那是无效的——请用真正的工具调用重做这一步。
4. 当所有 [ ] 都已处理完(或确实无法继续),输出一行 [监工:完成] 即可正常停下。"
else
  REASON="监工激进模式生效(第 ${COUNT}/${MAX_LOOPS} 轮续跑)。请继续推进用户的原始任务直到真正完成:
1. 回顾用户最初的需求,检查是否还有未做完、未验证、可深化的部分,有就接着做。
2. ⚠️ 如果你上一轮把工具调用写成了纯文本而没有真正调用,请用真正的工具调用重做。
3. 完成验证后,如果任务确实已彻底做完、无可继续,输出一行 [监工:完成] 即可停下。
4. 不要为了凑轮数编造无意义的工作——真做完了就立刻发 [监工:完成]。"
fi

log "续跑: sid=$SESSION_ID mode=$MODE count=$COUNT stall=$STALL hash=$LEDGER_HASH cwd=$CWD"
force_continue "$REASON"
