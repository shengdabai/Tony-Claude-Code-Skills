#!/usr/bin/env python3
"""omc update / plugin 更新后重放：删除与 Cardinal Rules 矛盾的指令。

背景：Anthropic 官方降本指南把「矛盾的规则」列为拖累前沿模型的反模式
（前沿模型更严格执行指令，互相矛盾的指令会被同时执行，成本上升、准确率下降）。
OMC 托管区由 `omc update` 就地刷新，superpowers 的 SessionStart 注入由 plugin 更新恢复。

**fail-closed 设计**（2026-09-09 两轮 Codex 交叉审核后加固）。每个 patch 声明：
  block     —— 定位所属区块（判定只在区块内进行，避免同名短语在别处命中导致误判 ok）
  source    —— 改动前的原文
  forbidden —— 该区块内绝不该出现的语义（矛盾指令的特征），命中即 FAILED
  repl      —— 替换文本（删除型为空串）

判定（严格按区块内文本）：
  ok      —— 区块存在、source 不在、forbidden 不在
  PATCHED —— source 命中并替换成功（替换后复验 source 消失）
  FAILED  —— 区块找不到 / forbidden 命中 / 替换后复验不通过

早期版本的三个真实漏洞（均由交叉审核复现）：
  1. target 探针做全文件搜索，同一短语存在于另一区块 → 删掉目标块仍判 ok
  2. 删除型 patch 只验区块首行 → 在锚点后插入改写过的强制委派句仍判 ok
  3. `--check` 发现 PENDING 时仍返回 0；superpowers 多副本的状态互相覆盖

用法：python3 ~/.claude/scripts/omc-block-depatch.py [--check]
退出码：0 = 全部已是目标态；1 = 有 FAILED，或 --check 下有 PENDING（待打）
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

HOME = pathlib.Path.home()
MD = HOME / ".claude" / "CLAUDE.md"
PLUGIN_CACHE = HOME / ".claude" / "plugins" / "cache"

Patch = tuple[str, re.Pattern, re.Pattern, re.Pattern, str]

PATCHES: list[Patch] = [
    (
        "delegation_rules: 强制委派清单 → 单 Agent 默认（冲突 Cardinal 8）",
        re.compile(r"<delegation_rules>.*?</delegation_rules>", re.S),
        re.compile(r"Delegate for: multi-file changes.*?Route code to `executor`.*?\n", re.S),
        # 区块内出现任何「按任务类型强制委派」的措辞都算矛盾复活
        re.compile(r"Delegate for:|Hand off .{0,40}(subagent|agent)|always delegate", re.I),
        "<delegation_rules>\n"
        "Single agent by default (Cardinal 8). When that gate is open: route code to `executor` "
        "(`model=opus` for complex work); uncertain SDK usage → `document-specialist` "
        "(repo docs first, web fallback).\n"
        "</delegation_rules>",
    ),
    (
        "operating_principles: 删「Delegate specialized work」（冲突 Cardinal 8）",
        re.compile(r"<operating_principles>.*?</operating_principles>", re.S),
        re.compile(r"^- Delegate specialized work to the most appropriate agent\.\n", re.M),
        re.compile(r"[Dd]elegate .{0,40}(work|task).{0,30}agent|Route .{0,20}to .{0,20}agent"),
        "",
    ),
    (
        "verification: 分级验证取代按体量派 agent（冲突 Cardinal 8 + 验证仪式）",
        re.compile(r"<verification>.*?</verification>", re.S),
        re.compile(r"Verify before claiming completion\. Size appropriately:.*?\n", re.S),
        re.compile(r"Size appropriately|small→haiku|verify twice|double-check", re.I),
        "<verification>\n"
        "Verify before claiming completion, at the depth the change's risk warrants "
        "(`rules/verification.md`). If verification fails, keep iterating.\n"
        "</verification>",
    ),
    (
        "failure_mode_guards: 删 AskUserQuestion 提问义务（冲突 No-Pause / intent-defaults）",
        re.compile(r"<failure_mode_guards>.*?</failure_mode_guards>", re.S),
        re.compile(r"^User input: when clarification, preference, or approval is required.*?\n", re.M),
        re.compile(r"AskUserQuestion|ask one focused question|instead of ending with a prose question"),
        "",
    ),
    (
        "execution_protocols: 删强制 code-reviewer 审批 + 并行歧义澄清为工具调用（冲突 Cardinal 8）",
        re.compile(r"<execution_protocols>.*?</execution_protocols>", re.S),
        re.compile(
            r"Broad requests: explore first, then plan\. 2\+ independent tasks in parallel\..*?"
            r"Before concluding: zero pending tasks, tests passing, verifier evidence collected\.",
            re.S,
        ),
        re.compile(r"Never self-approve|code-reviewer|verifier for the approval|"
                   r"2\+ independent tasks in parallel|tests passing"),
        "Broad requests: explore first, then plan. Issue independent **tool calls** concurrently "
        "in one message. `run_in_background` for builds/tests.\n"
        "Before concluding: zero pending tasks, verification evidence collected at the depth "
        "the change's risk warrants.",
    ),
]

SEVERITY = {"ok": 0, "patched": 1, "pending": 2, "failed": 3}


def worst(a: str, b: str) -> str:
    return a if SEVERITY[a] >= SEVERITY[b] else b


def apply_patches(text: str, check_only: bool) -> tuple[str, str]:
    """返回 (新文本, 最严重状态)。判定严格限定在各自区块内。"""
    state = "ok"
    for label, block_re, src, forbidden, repl in PATCHES:
        m = block_re.search(text)
        if not m:
            print(f"  FAILED   {label}\n             ↑ 区块未找到（OMC 结构已变），需人工复核")
            state = worst(state, "failed")
            continue
        block = m.group(0)

        if src.search(block):
            if check_only:
                print(f"  PENDING  {label}")
                state = worst(state, "pending")
                continue
            new_block = src.sub(repl, block, count=1)
            # 后置复验：替换后 source 必须消失，forbidden 也必须消失
            if src.search(new_block) or forbidden.search(new_block):
                print(f"  FAILED   {label}\n             ↑ 替换后复验不通过，未写入")
                state = worst(state, "failed")
                continue
            text = text[:m.start()] + new_block + text[m.end():]
            print(f"  PATCHED  {label}")
            state = worst(state, "patched")
        elif forbidden.search(block):
            # source 不匹配但矛盾语义仍在 → 官方改写了措辞，矛盾复活
            print(f"  FAILED   {label}\n             ↑ 区块内仍含矛盾语义（官方措辞已改写），需人工复核")
            state = worst(state, "failed")
        else:
            print(f"  ok       {label}")
    return text, state


def find_superpowers_hooks() -> list[pathlib.Path]:
    """动态解析（早期版本写死 6.3.0，实测漏掉了并存的 5.1.0 副本）。"""
    return sorted(PLUGIN_CACHE.glob("*/superpowers/*/hooks/hooks.json"))


def patch_superpowers(check_only: bool) -> str:
    """关闭 superpowers 的 SessionStart 强注入（实测 3,530 字符 / 1,267 tok 每会话）。

    注入正文是反模式集合：「You ABSOLUTELY MUST」「YOU DO NOT HAVE A CHOICE」
    「This is not negotiable」(全力以赴式强调) + 12 行 Red Flags 自我质询表 (验证仪式)；
    且「skill 优先于任何响应，包括澄清问题」与 Cardinal 1 字面执行 / No-Pause 直接矛盾。
    skill 本体保留，`/superpowers:brainstorming` 等仍可正常调用。
    """
    paths = find_superpowers_hooks()
    if not paths:
        print("  FAILED   superpowers hooks.json 未找到（已卸载？路径已变？）需人工复核")
        return "failed"
    state = "ok"
    for p in paths:
        ver = p.parts[-3]
        try:
            d = json.loads(p.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"  FAILED   superpowers({ver}) hooks.json 解析失败: {e}")
            state = worst(state, "failed")
            continue
        if "hooks" not in d:
            print(f"  FAILED   superpowers({ver}) 缺 hooks 键（结构已变），需人工复核")
            state = worst(state, "failed")
            continue
        if not d["hooks"]:
            print(f"  ok       superpowers({ver}) SessionStart 强注入已关闭")
            continue
        if check_only:
            print(f"  PENDING  superpowers({ver}) SessionStart 强注入待关闭")
            state = worst(state, "pending")
            continue
        d["hooks"] = {}
        p.write_text(json.dumps(d, indent=2) + "\n", encoding="utf-8")
        print(f"  PATCHED  superpowers({ver}) SessionStart 强注入已关闭")
        state = worst(state, "patched")
    return state


def main() -> int:
    check_only = "--check" in sys.argv
    original = MD.read_text(encoding="utf-8")
    text, state = apply_patches(original, check_only)
    state = worst(state, patch_superpowers(check_only))

    if text != original and not check_only:
        MD.write_text(text, encoding="utf-8")
        print(f"\n已写入 {MD}。新会话生效。")

    if state == "failed":
        print("\nFAILED —— 不要当作已是目标态，请人工复核 CLAUDE.md 的 OMC 托管区。")
        return 1
    if state == "pending":
        print("\nPENDING —— 有待打的 patch，去掉 --check 重跑。")
        return 1
    if state == "patched":
        print("\n已打上，现为目标态。")
        return 0
    print("\n已是目标态，无需改动。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
