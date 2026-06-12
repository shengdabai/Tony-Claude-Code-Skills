#!/usr/bin/env python3
"""把 sessions_extracted.json 按会话拆成若干 batch 文件,供并行 subagent 总结。"""
import json, os, math

SRC = os.path.expanduser("~/.claude/scripts/sessions_extracted.json")
OUTDIR = os.path.expanduser("~/.claude/scripts/session_batches")
os.makedirs(OUTDIR, exist_ok=True)

with open(SRC, encoding="utf-8") as f:
    sessions = json.load(f)

# 去掉纯噪音用户消息,加全局序号(按时间倒序,即最新=1)
NOISE_PREFIXES = ("Your tool call was malformed", "<task-notification>", "API Error",
                  "[Request interrupted", "The model's tool call")
for i, s in enumerate(sessions, 1):
    s["seq"] = i
    s["user_msgs"] = [m for m in s["user_msgs"]
                      if not any(m.startswith(p) for p in NOISE_PREFIXES)][:15]

BATCH = 9
n_batches = math.ceil(len(sessions) / BATCH)
for b in range(n_batches):
    chunk = sessions[b * BATCH:(b + 1) * BATCH]
    path = os.path.join(OUTDIR, f"batch_{b+1}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(chunk, f, ensure_ascii=False, indent=1)
    print(f"batch_{b+1}.json: {len(chunk)} 会话 (seq {chunk[0]['seq']}-{chunk[-1]['seq']})")

print(f"共 {len(sessions)} 会话 → {n_batches} 批 → {OUTDIR}")
