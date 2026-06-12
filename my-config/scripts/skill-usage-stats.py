#!/usr/bin/env python3
"""扫 ~/.claude/projects 下所有 jsonl，统计 skill / slash-command 真实调用频次。

产出三档（高频/低频/零调用对照需配合已装清单），用于识别「僵尸 skill」。
两类信号：
  A) tool_use 且 name == "Skill" 的 input.skill / input.command
  B) user 消息里的 <command-name>/xxx</command-name>（slash 触发）
用法: python3 skill-usage-stats.py [--days N] [--out report.md]
"""
import json, os, re, sys, glob
from collections import Counter
from datetime import datetime, timedelta, timezone

ROOT = os.path.expanduser("~/.claude/projects")
DAYS = None
OUT = "/tmp/skill-usage-report.md"
args = sys.argv[1:]
for i, a in enumerate(args):
    if a == "--days" and i + 1 < len(args):
        DAYS = int(args[i + 1])
    if a == "--out" and i + 1 < len(args):
        OUT = args[i + 1]

cutoff = None
if DAYS:
    cutoff = datetime.now(timezone.utc) - timedelta(days=DAYS)

cmd_re = re.compile(r"<command-name>\s*/?([\w:.-]+)", re.I)

skill_calls = Counter()      # Skill 工具调用
slash_calls = Counter()      # slash command
sessions_with = set()
files = glob.glob(os.path.join(ROOT, "**", "*.jsonl"), recursive=True)
n_lines = 0

def walk_content(content, sess):
    """从 message.content（list 或 str）提取信号"""
    global n_lines
    if isinstance(content, str):
        for m in cmd_re.findall(content):
            slash_calls[m] += 1
            sessions_with.add(sess)
        return
    if not isinstance(content, list):
        return
    for block in content:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "tool_use" and block.get("name") == "Skill":
            inp = block.get("input", {}) or {}
            name = inp.get("skill") or inp.get("command") or inp.get("name")
            if name:
                skill_calls[str(name)] += 1
                sessions_with.add(sess)
        # user 文本块里可能也含 command-name
        if block.get("type") == "text":
            for m in cmd_re.findall(block.get("text", "")):
                slash_calls[m] += 1
                sessions_with.add(sess)

for f in files:
    sess = os.path.basename(f)
    try:
        with open(f, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                n_lines += 1
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                msg = rec.get("message")
                if isinstance(msg, dict):
                    walk_content(msg.get("content"), sess)
                # 顶层也可能直接带 content
                elif "content" in rec:
                    walk_content(rec.get("content"), sess)
    except Exception:
        continue

# 合并两类信号
combined = Counter()
combined.update(skill_calls)
for k, v in slash_calls.items():
    combined[k] += v

total = sum(combined.values())
lines = []
lines.append("# Skill / Command 使用频次报告")
lines.append(f"\n生成: {datetime.now().strftime('%Y-%m-%d %H:%M')}  | 扫描 {len(files)} 个 jsonl / {n_lines} 行")
if DAYS:
    lines.append(f"窗口: 近 {DAYS} 天")
lines.append(f"总调用 {total} 次 | 去重 skill/command {len(combined)} 个 | 涉及会话 {len(sessions_with)}\n")

def tier(name, items):
    lines.append(f"\n## {name}（{len(items)} 个）\n")
    if not items:
        lines.append("（无）")
        return
    lines.append("| skill/command | 次数 |")
    lines.append("|---|---|")
    for k, v in items:
        lines.append(f"| {k} | {v} |")

ranked = combined.most_common()
high = [(k, v) for k, v in ranked if v >= 10]
mid = [(k, v) for k, v in ranked if 3 <= v < 10]
low = [(k, v) for k, v in ranked if 1 <= v < 3]

tier("高频（≥10 次，肌肉记忆区，重点打磨）", high)
tier("中频（3-9 次，价值已验证）", mid)
tier("低频（1-2 次，可能一次性试用）", low)

lines.append("\n---\n")
lines.append("> 注：本表只含「被调用过」的。已装但**从未出现**的 skill = 僵尸，需对照已装全集（npx skills list / 插件清单）人工标记。")
lines.append("> Skill 工具调用 vs slash 命令两类信号已合并。OMC 经 mcp load 的 skill 不一定计入。")

report = "\n".join(lines)
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write(report)

# stdout 摘要
print(f"扫描 {len(files)} jsonl / {n_lines} 行")
print(f"被调用 skill/command: {len(combined)} 个，总 {total} 次")
print(f"高频 {len(high)} / 中频 {len(mid)} / 低频 {len(low)}")
print(f"报告: {OUT}")
print("\nTop 20:")
for k, v in ranked[:20]:
    print(f"  {v:>4}  {k}")
