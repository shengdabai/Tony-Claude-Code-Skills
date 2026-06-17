# Tool Discipline

## Iron Law: Bash 是最后选择，不是默认选择

报告数据：921 Bash : 50 Edit = 18:1 比例 + 48 次 Bash 命令失败 + 4 次 Edit 失败。说明 Bash 用得**远超必要**。

## 必须用 dedicated tool 的场景

| 操作 | ✅ 正确工具 | ❌ 错误的 Bash 写法 |
|------|----------|------------------|
| 读文件 | `Read` | `cat /path/to/file` / `head` / `tail` |
| 改文件 | `Edit`（精确替换）/ `Write`（全文重写） | `sed -i` / `awk` / `echo > file` / `cat <<EOF` |
| 找文件 | `Glob` | `find` |
| 搜代码 | `Grep` | `grep -r` / `rg` |
| 列文件 | `Glob` 或 `Read directory` | `ls` |
| 打印输出 | 直接 text response | `echo "已完成"` |

## Bash 真正合适的场景

- 启动进程：`npm run dev`、`gh pr create`、`git commit`
- 查询动态状态：`git status`、`docker ps`、`ports`
- 编译/测试：`tsc`、`pytest`、`make`
- 系统级命令：`brew install`、`launchctl`、`xcrun`
- 多步骤管道：`jq ... | xargs ... | head`（确实需要的）

## Edit 失败 4 次 — 修复方法

报告显示 4 次 Edit 失败，最常见原因：
1. **没先 Read 就 Edit** → Edit tool 强制要求先 Read
2. **old_string 不唯一** → 加更多 surrounding context 让其唯一
3. **空白字符不匹配** → 注意 cat -n 行号前缀和实际内容的 tab 分隔

## 自检（执行前问自己）

如果我准备调 Bash，问：
- 这是文件读 / 改 / 搜索吗？→ 用 Read/Edit/Write/Grep/Glob
- 这是输出文本给用户吗？→ 直接说话
- 这是 echo/cat/head/tail？→ 99% 时候用错了

只有真的需要 shell 行为（启动进程、动态查询、多步管道）才用 Bash。

## 例外（允许 Bash）

- 用户明确说"用 bash"/"运行命令"
- 验证脚本（如 `bash -n`、`jq empty`）
- 一次性诊断（`which`、`file`、`stat`）
- 确实没有对应 dedicated tool（如 `chmod`、`xcrun simctl`）

## 禁止伪工具调用（Cardinal Rule 7 的执行细则）

### Iron Law: 工具调用必须走真正的调用通道,文本"展示"不算调用

这是高频致命错误:把工具调用写成纯文本/markdown 代码块/伪代码,而不是真正发起调用。后果是**任务在该步暂停假死**——系统以为你只是在说话,等用户手动催"继续",一个任务被切成十几段。

### 反模式(全部禁止)

以下都是"假装调用"——它们只是文本,不会真正执行:

- 把"调用包裹标签 + 参数标签"那套尖括号结构当正文打出来(invoke / function_calls 那类标签)——**本规则刻意不写出完整标签字面量,因为研究证实(anthropics/claude-code#64190/#66400)上下文里的标签样例会加重 pattern-contamination,诱发模型在文本通道续写伪调用**
- 用 markdown 代码块"演示"要跑的命令,然后停下
- 写"我现在调用 Bash 执行 X"然后没有真正的 tool_use
- 描述"接下来会用 Edit 改这个文件"却不发起 Edit

### 正确做法

准备执行任何动作(改文件 / 跑命令 / 查状态 / 读文件)时,**直接通过工具的原生调用接口发起**,不要先"叙述"再调用,更不要用文本替代调用。工具调用和解释文字是两个独立通道:解释可以有,但动作必须走真正的 tool_use。

### 动手前的自检(每次执行动作前问)

1. 我现在是在**真正调用**工具,还是在**打印**一段看起来像调用的文本?
2. 如果我输出的"调用"出现在给用户看的正文里(能被当 markdown 渲染),那它就不是调用,是文本 → 停,改用真正的工具调用
3. 我是不是在"预告"动作而非"执行"动作?预告完要立刻真的执行,不要停在预告

### 为什么 caveman/简洁模式下更容易犯

精简输出时容易把"调用"和"说明"混为一谈,直接打一段命令文本就以为做完了。**简洁针对的是解释文字,不是工具调用方式**——再简洁,动作也必须走真正的 tool_use 通道。

### 已知触发器 — 主动规避(研究 anthropics/claude-code#64190 实证)

伪调用是 **Opus 4.8 的模型级回归**(area:model,4.7 无),prompt 治不了根,但有明确触发器,**主动规避能大幅降低发作率**:

1. **不堆叠大量近乎重复的工具调用**:transcript 被重复调用主导时,模型最易在文本通道 pattern-complete 出伪调用。要并行多个就并行,但别机械重复同一调用十几次。
2. **工具密集的长会话不要 `/compact`**:`/compact` 把旧 tool_use 块序列化成字面标记写进 summary,压缩后模型照着续写伪调用。宁可**开新会话**(配合 Cardinal Rule 3 的 ledger 续跑)。
3. **每个真调用后只认真实返回的 result**,绝不脑补"成功"——脑补假 result 会让你在错误地基上越叠越歪。
4. **极端复发**:某会话严重时可临时切 Opus 4.7(#64190 指其无此回归)。

### 兜底安全网(2026-06 起)

`~/.claude/hooks/fake-toolcall-guard.sh`(Stop hook)在每轮结束时扫最后一条 assistant 消息,检测到"伪调用标签 + 本轮零真实 tool_use"会自动 block 并要求重发真调用——把"用户手动催继续"自动化。**仅覆盖模式 A(伪调用文本后结束本轮);模式 B(tool_result 后静默卡死,#29881 指 Stop 不触发)需另设 watchdog。这是兜底,模型仍须自律,不得依赖它。**

## 任务中断后的无缝恢复

如果指令偶尔还是被输出成了文本导致任务暂停,**不需要从头重做**,用 Claude Code 内置恢复:

| 场景 | 操作 | 效果 |
|------|------|------|
| 恢复最近会话 | 终端 `claude --continue`,或交互模式内 `/resume` | 自动拉取最近会话记录,接着上下文和工具状态继续 |
| 选特定历史会话 | 终端 `claude --resume` | 列出所有历史会话选择器,选中中断前那次即可恢复完整上下文 |

配合 Cardinal Rule 3 的 `.omc/plans/*-todo.md` ledger:大任务中断后,恢复会话 + 读 ledger,跳过 `[x]` 已完成项,从 `[ ]` 继续,不重做。
