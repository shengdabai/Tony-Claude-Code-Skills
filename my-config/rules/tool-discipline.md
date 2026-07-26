# Tool Discipline

## Bash 是最后选择
文件读/改/搜/列一律用 Read/Edit/Write/Grep/Glob,不走 Bash 的 cat/sed/echo/find/grep/ls;输出文字直接说话,不 echo。Bash 只用于:启动进程、动态状态查询(git status / docker ps / ports)、编译测试、系统级命令、真正需要的多步管道。例外:用户明确要求 bash、一次性诊断(which/stat)、无对应 dedicated tool(chmod 等)。

Edit 失败三大原因:没先 Read 就 Edit;old_string 不唯一(加上下文);空白不匹配(Read 行号前缀是 tab 分隔,勿带入)。

## 禁止伪工具调用(Cardinal Rule 7 细则)
动作(改文件/跑命令/读状态)必须经真正的 tool_use 通道发起;把调用写成纯文本/markdown/伪代码"展示"= 不执行、会话假死。历史根因是 Opus 4.8 模型级回归(anthropics/claude-code#64190),Claude 5 代已修复,但纪律保留:

- 每个真调用只认真实返回的 result,绝不脑补"成功"。
- 别机械堆叠大量近乎重复的工具调用;工具密集的长会话宁可开新会话(配 ledger 续跑)也别 `/compact`——压缩会把旧 tool_use 序列化成文本,诱发续写伪调用。
- 兜底:`~/.claude/hooks/fake-toolcall-guard.sh`(Stop hook)自动拦「伪调用文本 + 本轮零真实 tool_use」。它是安全网,不是依赖。

## 任务中断后的恢复
| 场景 | 操作 |
|------|------|
| 恢复最近会话 | `claude --continue` 或会话内 `/resume` |
| 选历史会话 | `claude --resume` |

配合 Cardinal Rule 3 的 `.omc/plans/*-todo.md` ledger:恢复后跳过 `[x]` 项从 `[ ]` 继续,不重做。
