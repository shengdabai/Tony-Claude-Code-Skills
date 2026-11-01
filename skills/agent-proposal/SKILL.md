---
name: agent-proposal
description: Agents propose edits to a protected document as a reviewable unified diff (.<name>.proposal.diff with a base SHA-256) instead of overwriting it; the owner lists hunks, accepts some or all, and the CLI applies them with a backup and refuses stale or out-of-date hunks. Use when an AI agent (Claude, Codex, a pipeline) must change prose, notes, lesson material, config or any file the user wants to approve hunk by hunk; also use to review or apply an existing proposal. Not for files the agent owns outright (scratch, generated output, its own code branch) — edit those directly.
---

# agent-proposal — 提案而非覆盖

借自 xiaolai/sonovo 的 `MarkdownProposal` 思路,stdlib Python 重写:agent 不直接改受保护的文档,而是在文档旁写一份带原文哈希的 unified diff,人来决定接受哪些 hunk。

## 协议(文件即全部状态)

```
<dir>/.<name>.proposal.diff
# agent-proposal v1
# document: <name>
# base-sha256: <原文字节的 SHA-256>
# author: <claude|codex|pipeline 名>
# summary: <一句意图>
# created: <ISO 时间>
--- a/<name>
+++ b/<name>
@@ -l,c +l,c @@
```

- 原文变了 → 提案 **stale**,`apply` 拒绝;`apply --rebase` 只应用上下文仍精确匹配的 hunk,其余报 out of date。
- 应用前先把原文备份到 `~/.cache/agent-proposal/backups/`(或 `$AGENT_PROPOSAL_BACKUP_DIR`),写入用临时文件 + 原子替换。
- 部分接受后,剩余 hunk 以新原文为基重写进同一提案文件;全部接受或 `reject` 后提案文件删除。
- 提案文件 > 5 MB、版本不对、hunk 行数与头部不符 → malformed,退出码 3。

## 命令(安装后为 `agent-proposal`,或 `python3 -I scripts/proposal.py`)

| 命令 | 作用 |
|---|---|
| `propose <doc> --new <file> [--author X] [--summary S]` | 用完整新稿生成提案(也可从 stdin 读新稿) |
| `show <doc> [--json]` | 列出 hunk、显示 fresh/stale、标出 out of date 的 hunk |
| `check <doc>` | 退出码 0 fresh / 1 无提案 / 2 stale / 3 malformed |
| `apply <doc> --hunks 1,3` 或 `--all` [`--rebase`] [`--dry-run`] | 应用接受的 hunk,带备份 |
| `reject <doc>` | 删除提案,不碰文档 |
| `list [dir] [--json]` | 找出目录下所有提案及状态(跳过 .git / node_modules) |

## Agent 侧用法

1. 判断文档是否受保护:用户的文章稿、笔记、教学材料、CLAUDE.md/AGENTS.md、别人拥有的配置 → 受保护;自己分支里的代码、临时产物 → 不受保护,直接改。
2. 把改好的全文写到临时文件,然后 `agent-proposal propose <doc> --new <tmp> --author <你的名字> --summary "<一句话>"`。
3. 回复里只说「已写提案 N 个 hunk,运行 `agent-proposal show <doc>` 审阅」,**不要**自己 apply。
4. 同一文档已有提案时 `propose` 会拒绝;先 `show` 看旧提案,确认过期再 `--force` 覆盖。

## 人工 / 验收侧用法

```bash
agent-proposal list ~/projects                   # 哪些文档在等裁决
agent-proposal show  path/to/doc.md                # 看 hunk
agent-proposal apply path/to/doc.md --hunks 1,3    # 只收 1 和 3
agent-proposal apply path/to/doc.md --all          # 全收
agent-proposal reject path/to/doc.md               # 全拒
```

## 验证

```bash
cd skills/agent-proposal && python3 -I -m unittest discover -s tests
```

覆盖:propose/show/apply 往返、部分接受后剩余 hunk 重基、stale 拒绝与 `--rebase`、hunk 过期冲突、malformed/超大提案、末行换行变化、首行插入与尾部追加、list 状态。
