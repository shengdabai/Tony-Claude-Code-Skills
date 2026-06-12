---
description: 回收闲置的 claude CLI 会话,缓解 swap/内存压力(保护当前会话)
allowed-tools: Bash(bash:*), Bash(~/.claude/scripts/claude-reap.sh:*)
---

# /recycle — 回收闲置 claude 会话

用真正的 Bash 工具调用执行回收脚本,把结果原样转述给用户。

## 参数映射(用户输入 → 命令)

`$ARGUMENTS` 为用户传入的参数:

| 用户输入 | 执行 |
|---|---|
| (空) | `bash ~/.claude/scripts/claude-reap.sh` — 回收运行 >6h 的闲置会话 |
| `12h` / `30m` / `90` | `bash ~/.claude/scripts/claude-reap.sh $ARGUMENTS` — 自定义阈值(纯数字=分钟) |
| `dry` / `--dry` / `预览` | `bash ~/.claude/scripts/claude-reap.sh --dry` — 只列候选不回收 |
| `all` / `--all` / `全部` | `bash ~/.claude/scripts/claude-reap.sh --all` — 回收除当前外所有会话(谨慎) |

## 执行步骤

1. 把 `$ARGUMENTS` 归一化到上表(拿不准按空参数=默认 6h)。
2. **用真正的 Bash 工具调用**对应命令,不要把命令写成文本。
3. 原样转述脚本输出(回收了几个、swap 变化),一句话即可,不展开。

## 说明(供判断,不必每次复述)

- 脚本只动 `~/.local/bin/claude` 主进程,绝不碰 Claude.app 桌面应用和 node MCP 子进程。
- 当前会话整条祖先链自动保护;`~/.claude/reap-keep.txt`(PID 或 cwd 关键字)永不回收。
- SIGTERM 优雅退出,被回收的会话可 `cd <项目> && claude --continue` 恢复。
- swap 打满会掐断模型流式 tool 输出 → 触发 "tool call could not be parsed"。定期 /recycle 是根治手段之一。
