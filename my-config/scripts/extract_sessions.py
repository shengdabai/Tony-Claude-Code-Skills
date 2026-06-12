#!/usr/bin/env python3
"""提取过去7天 Claude Code 主会话(排除 subagent/workflow)的用户消息脉络。"""
import json, os, glob, time, re
from collections import Counter

ROOT = os.path.expanduser("~/.claude/projects")
OUT = os.path.expanduser("~/.claude/scripts/sessions_extracted.json")
CUTOFF = time.time() - 7 * 86400

def clean_text(s):
    if not isinstance(s, str):
        return ""
    s = s.strip()
    if s.startswith("<") and any(t in s[:60] for t in
        ["system-reminder", "command-name", "command-message", "command-args",
         "local-command", "command-output", "user-prompt-submit"]):
        return ""
    s = re.sub(r"<system-reminder>.*?</system-reminder>", "", s, flags=re.S).strip()
    return s

def extract_user_text(msg):
    content = msg.get("content")
    if isinstance(content, str):
        return clean_text(content)
    if isinstance(content, list):
        parts = []
        for b in content:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "tool_result":
                return ""
            if b.get("type") == "text":
                parts.append(clean_text(b.get("text", "")))
        return "\n".join(p for p in parts if p).strip()
    return ""

sessions = []
for path in glob.glob(os.path.join(ROOT, "**", "*.jsonl"), recursive=True):
    if "/subagents/" in path or "/workflows/" in path:
        continue
    try:
        if os.path.getmtime(path) < CUTOFF:
            continue
    except OSError:
        continue
    project = os.path.basename(os.path.dirname(path))
    user_msgs, assistant_snips = [], []
    n_total = 0
    first_ts = last_ts = None
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                n_total += 1
                ts = obj.get("timestamp")
                if ts:
                    if not first_ts:
                        first_ts = ts
                    last_ts = ts
                t = obj.get("type")
                msg = obj.get("message") or {}
                if t == "user" and isinstance(msg, dict) and msg.get("role") == "user":
                    txt = extract_user_text(msg)
                    if txt:
                        user_msgs.append(txt[:500])
                elif t == "assistant" and isinstance(msg, dict):
                    c = msg.get("content")
                    if isinstance(c, list):
                        for b in c:
                            if isinstance(b, dict) and b.get("type") == "text":
                                tx = b.get("text", "").strip()
                                if tx:
                                    assistant_snips.append(tx[:200])
                                    break
    except OSError:
        continue
    if not user_msgs:
        continue
    sessions.append({
        "id": os.path.basename(path).replace(".jsonl", ""),
        "project": project,
        "mtime": os.path.getmtime(path),
        "first_ts": first_ts, "last_ts": last_ts,
        "n_total": n_total, "n_user": len(user_msgs),
        "first_prompt": user_msgs[0],
        "user_msgs": user_msgs[:25],
        "assistant_snips": assistant_snips[:6],
    })

sessions.sort(key=lambda s: s["mtime"], reverse=True)
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(sessions, f, ensure_ascii=False, indent=1)

print(f"主会话数(含真实用户消息): {len(sessions)}")
print("项目分布:")
for proj, cnt in Counter(s["project"] for s in sessions).most_common():
    print(f"  {cnt:3d}  {proj}")
print(f"用户消息总数: {sum(s['n_user'] for s in sessions)}")
print(f"输出: {OUT}")
