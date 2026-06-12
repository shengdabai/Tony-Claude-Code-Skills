#!/usr/bin/env bash
# supervisor-session-start.sh — 监工 SessionStart hook
#
# 新会话启动时(任何终端 / Ghostty 都会触发):
#   1. 为本 session_id 重置循环计数(避免沿用上次会话的计数)
#   2. 顺手 prune 掉 state 里 7 天前的陈旧 session 条目
#   3. 通过 stdout 注入一行 system-reminder, 告知当前监工模式 + 是否有 pending ledger
#
# 输入(stdin JSON): { cwd, session_id }
# 静默失败, 永远 exit 0(绝不阻断会话启动)

set -uo pipefail

STATE_DIR="${HOME}/.claude/state"
STATE_FILE="${STATE_DIR}/supervisor-loops.json"
OFF_FLAG="${STATE_DIR}/supervisor.off"
AGGR_FLAG_GLOBAL="${STATE_DIR}/supervisor.aggressive"

PY=/usr/bin/python3
JQ=/usr/bin/jq

mkdir -p "$STATE_DIR" 2>/dev/null
[[ -f "$STATE_FILE" ]] || echo '{}' > "$STATE_FILE"

INPUT=$(cat 2>/dev/null || echo '{}')
{
  IFS= read -r CWD
  IFS= read -r SESSION_ID
} < <(printf '%s' "$INPUT" | $PY -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print(str(d.get("cwd") or "'"$PWD"'"))
print(str(d.get("session_id") or "default"))
' 2>/dev/null)
[[ -z "${CWD:-}" ]] && CWD="$PWD"
[[ -z "${SESSION_ID:-}" ]] && SESSION_ID="default"

# 为本会话重置计数 + prune 7 天前旧条目(用 epoch started 判断)
NOW="$(/bin/date +%s)"
CUTOFF=$((NOW - 604800))
TMP="$($JQ --arg s "$SESSION_ID" --argjson cut "$CUTOFF" '
  with_entries(select((.value.started // 0) >= $cut))
  | del(.[$s])
' "$STATE_FILE" 2>/dev/null)"
[[ -n "$TMP" ]] && printf '%s' "$TMP" > "$STATE_FILE"

# 关闭则不打印状态
[[ -f "$OFF_FLAG" || "${DISABLE_SUPERVISOR:-}" == "1" ]] && exit 0

# 模式 + pending 判定
MODE="账本守门"
[[ -f "$AGGR_FLAG_GLOBAL" || -f "$CWD/.omc/supervisor.aggressive" ]] && MODE="激进常开"

PENDING="$($PY - "$CWD" "${SUPERVISOR_LEDGER_MAX_AGE:-86400}" <<'PYEOF' 2>/dev/null
import sys,glob,os,time
cwd=sys.argv[1]
maxage=float(sys.argv[2]) if len(sys.argv)>2 else 86400.0
now=time.time()
for fp in glob.glob(os.path.join(cwd,".omc","plans","*.md")):
    try:
        if maxage>0 and (now-os.path.getmtime(fp))>maxage:
            continue  # 陈旧账本不算活跃待办
        with open(fp,encoding="utf-8",errors="ignore") as f:
            for ln in f:
                s=ln.strip()
                if s.startswith("- [ ]"): print("YES"); sys.exit(0)
    except Exception: pass
print("NO")
PYEOF
)"

if [[ "$MODE" == "激进常开" ]]; then
  echo "<system-reminder>监工: 激进常开模式生效——任务做完后请输出一行 [监工:完成] 以正常停下。关闭: 监工 ledger / 监工 off。</system-reminder>"
elif [[ "$PENDING" == "YES" ]]; then
  echo "<system-reminder>监工: 账本守门模式,检测到 .omc/plans/ 有未完成 [ ] 任务,停下时会自动督促续跑直到清空或卡住。完成全部后输出 [监工:完成] 可提前释放。</system-reminder>"
fi
# 账本守门 + 无 pending → 完全静默, 不打印

exit 0
