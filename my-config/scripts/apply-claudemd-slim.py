#!/usr/bin/env python3
"""幂等地给 ~/.claude/CLAUDE.md 瘦身：把 coding-style / git-workflow 从强制 @import
降为按需加载。由用户直接运行以绕过会话内 ARS scope-guard hook。
用法: python3 apply-claudemd-slim.py [--dry-run]
"""
import os, sys

P = os.path.expanduser("~/.claude/CLAUDE.md")
DRY = "--dry-run" in sys.argv

OLD_BLOCK = """@rules/tool-discipline.md
@rules/coding-style.md
@rules/git-workflow.md

@RTK.md"""

NEW_BLOCK = """@rules/tool-discipline.md

@RTK.md"""

ANCHOR = '- **Spec-Driven Trio（OpenSpec+Superpowers+Agent-Skills）** → `rules/spec-driven-trio.md`（"写 spec"/"propose"/SDD 项目/新功能规划时）'

ADD = ANCHOR + """
- **编码风格（不可变/小文件/错误处理/校验）** → `rules/coding-style.md`(写或重构代码前先 Read)
- **Git 工作流 + commit 安全门** → `rules/git-workflow.md`(commit/push/建 PR 前必先 Read，含 secret 预检)"""

with open(P, "r", encoding="utf-8") as f:
    content = f.read()

# 幂等检查
if "rules/coding-style.md" not in content.split("@RTK.md")[0]:
    print("已应用过（强制块已无 coding-style），无需重复。")
    sys.exit(0)

if OLD_BLOCK not in content:
    print("ERR: 未匹配到强制块，CLAUDE.md 结构可能已变。请人工核对。")
    sys.exit(1)
if ANCHOR not in content:
    print("ERR: 未匹配到按需清单锚点。请人工核对。")
    sys.exit(1)

new = content.replace(OLD_BLOCK, NEW_BLOCK).replace(ANCHOR, ADD)

if DRY:
    print("=== DRY RUN，未写入 ===")
    print("强制块: 删除 @rules/coding-style.md + @rules/git-workflow.md")
    print("按需清单: 追加 coding-style / git-workflow 两条引导")
    print(f"字符数: {len(content)} -> {len(new)} (省 {len(content)-len(new)})")
    sys.exit(0)

with open(P, "w", encoding="utf-8") as f:
    f.write(new)

# read-back 验证
with open(P, "r", encoding="utf-8") as f:
    rb = f.read()
ok = ("rules/coding-style.md" not in rb.split("@RTK.md")[0]) and ("- **编码风格" in rb)
print("写入完成，read-back:", "✓ 通过" if ok else "✗ 异常，请核对")
