#!/bin/bash
# fake-toolcall-guard.sh — Stop hook · 伪工具调用安全网
#
# 问题: 模型偶尔把工具调用写成纯文本(形如 invoke / function_calls 标签),
#       这一轮没有真正的 tool_use → 任务假死, 需用户手动催"继续"。
#       Cardinal Rule 7 / tool-discipline 的 prompt 约束防不住(生成层漂移)。
#       研究佐证: anthropics/claude-code#64190(Opus 4.8 /compact 回归) +
#       #66400(漏 antml: 命名空间前缀)。
# 方案: 本轮结束时扫 transcript 最后一条 assistant 消息, 若"伪调用文本 + 本轮
#       零真实 tool_use", 自动 block stop 并提示重做真调用 → 把"用户手动催继续"
#       自动化。这正是 #64190 讨论里官方/社区建议的 harness 层修法。
#
# 覆盖范围: 模式 A(伪调用文本后结束本轮)。模式 B(tool_result 后静默卡死,
#           Stop 不触发, 见 #29881)由 silent-stall-watchdog 另行覆盖。
#
# 误报控制: 必须同时出现【调用开标签】和【参数标签】才算 — 正常讨论本话题的
#           散文(用反引号/打码)几乎不会两者俱全, 故 FP 接近 0。
#
# 注册: settings.json Stop 数组第一项, 与 notify-stop / supervisor-stop 并存。

set -u
LOG="$HOME/.claude/logs/fake-toolcall-guard.log"
mkdir -p "$(dirname "$LOG")"

INPUT=$(cat)

DECISION=$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import sys, json, re

def out(block, reason=""):
    if block:
        print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))
    sys.exit(0)

try:
    hook = json.load(sys.stdin)
except Exception:
    out(False)

if str(hook.get("stop_hook_active", False)).lower() == "true":
    out(False)

tp = hook.get("transcript_path", "")
if not tp:
    out(False)

# 找最后一条 assistant 消息(#1: 每行独立 try, 单行坏不杀全程; msg 必须是 dict)
last = None
try:
    with open(tp, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            if not isinstance(obj, dict):
                continue
            msg = obj.get("message", obj)
            if not isinstance(msg, dict):
                continue
            if msg.get("role") == "assistant":
                last = msg
except Exception:
    out(False)

if last is None:
    out(False)

content = last.get("content", "")
text_parts = []
has_tool_use = False
if isinstance(content, list):
    for b in content:
        if not isinstance(b, dict):
            continue
        t = b.get("type")
        if t == "tool_use":
            has_tool_use = True
        elif t == "text":
            tv = b.get("text", "")
            if isinstance(tv, str):
                text_parts.append(tv)
elif isinstance(content, str):
    text_parts.append(content)

text = "\n".join(text_parts)

# 本轮最后一条 assistant 有真实 tool_use -> 工作在推进, 放行
if has_tool_use:
    out(False)

# #3: regex 判据 — 大小写不敏感 + 容空白 + 含 &lt; HTML 实体转义。
# 低误报核心(#4 取舍): opener 与 param 都要带 name= 引号(=真结构化调用尝试,
# 散文讨论几乎不会两者俱全), 避免误伤"讨论 invoke/parameter 概念"的正常文本。
opener_re = re.compile(r"(antml:invoke|(?:<|&lt;)\s*invoke)\s+name\s*=\s*[\"\x27]"
                       r"|(?:<|&lt;)\s*function_calls\s*(?:>|&gt;)", re.IGNORECASE)
param_re  = re.compile(r"(antml:parameter|(?:<|&lt;)\s*parameter)\s+name\s*=\s*[\"\x27]", re.IGNORECASE)

if opener_re.search(text) and param_re.search(text):
    out(True, "检测到你把工具调用写成了纯文本(出现 invoke/parameter 结构标签却没有真正的 tool_use),这一步实际没执行、任务会假死。请立刻用真正的工具调用接口重新发起刚才那个动作 —— 不要再把调用写进正文。")

out(False)
' 2>/dev/null)

if [ -n "$DECISION" ]; then
  { echo "[$(date '+%F %T')] CAUGHT fake tool-call, blocked stop"; } >> "$LOG" 2>/dev/null || true
  echo "$DECISION"
fi
exit 0
