# Loop Engineering（循环工程）

> 范式来源：2026-06 Addy Osmani / Boris Cherny（Claude Code 负责人）——
> "不要再给 agent 写 prompt，要写驱动 agent 的循环。"
> 本规则把该范式映射到本机已有设施（OMC / 监工 / ledger / launchd），**不引入新框架**。

## Iron Law: 重复 ≥ 2 次的任务必须 loop 化，loop 必须有五要素

凡是"做完还要再做"的工作（盯 PR、修测试、清 ledger、日常巡检），不要手动反复发 prompt——
设计一个循环，让循环替你发。但**没有五要素的循环禁止启动**（无验证的循环 = 无人看管地犯错）。

## 循环五要素（启动前逐项写明）

| 要素 | 问题 | 例 |
|------|------|----|
| **Trigger** | 何时跑一轮？ | 每 10 分钟 / 每天 09:00 / 测试一红 |
| **Work** | 每轮做什么？ | 修最小 root cause / 处理一条 review comment |
| **Verify** | 用什么**可执行命令**判断成了？ | `npm test` exit 0 / `gh pr checks` 全绿 |
| **Exit** | 何时停？ | Verify 通过 / ledger 全 [x] / 撞 Budget |
| **Budget** | 最多几轮/多久？ | ≤ 10 轮 / ≤ 2 小时 / 失败 3 次升级人工 |

缺任何一项 → 先用 `/loop-design` 补全再启动。

## 路由表（用现成工具，按循环形态选）

| 循环形态 | 工具 | 用法 |
|---------|------|------|
| **周期循环**（每 N 分钟重跑，会话内） | 内置 `/loop` | `/loop 10m /loops:babysit-prs` |
| **条件循环**（跑到 X 成立为止，会话内） | `/oh-my-claudecode:ralph` 或 `/oh-my-claudecode:ultragoal` | "ralph: 修到 npm test 全绿" |
| **断点续跑**（暂停自动续，兜底层） | 监工 Stop hook | `监工 status` / 会话内 `/监工`（已常驻） |
| **会话外定时**（每天/每周，无需开着终端） | CronCreate 工具 或 launchd | "每天 09:00 起会话跑 /loops:ledger-drain" |
| **多 agent 扇出**（一轮内并行多任务） | Workflow 工具 | ultracode / "用 workflow" 显式触发 |
| **并行互斥**（多 loop 同时改文件） | worktree 隔离 | Agent `isolation: "worktree"` |

## Maker/Checker 分离（强制）

写代码的 agent 不给自己打分。每轮 Verify 优先级：
1. **可执行命令**（test/build/lint exit code）——最硬，首选
2. 独立 verifier/code-reviewer agent（与 CLAUDE.md "Never self-approve" 一致）
3. 主循环自查——仅限琐碎改动

## 状态必须落盘（循环记忆）

- 循环进度 → `.omc/plans/<loop-name>-todo.md` ledger（`[ ]/[x]/[!]`），每轮更新
- 循环日志 → `.omc/logs/loop-<name>.log`（每轮一行：时间 / 动作 / verify 结果）
- 中断恢复 = 新会话读 ledger 续跑（配合 Cardinal Rule 3），**不重做已完成轮次**

## 安全护栏（循环内禁止事项）

- **禁止**在循环内做不可逆/外发操作：`git push --force`、merge PR、发消息、删数据、付费 API 大额调用 → 这些步骤标记 `[需人工]`，循环停在该步等确认
- **禁止**无 Budget 的循环（失控成本）；撞 Budget 后输出摘要 + ntfy 通知,不静默续跑
- **失败 3 次同一错误** → 停止重试，写 `[!]` + 两个替代方案，升级人工（与 project-conventions 一致）
- 循环产出照常过质量审核（memory: review-audit-every-task），**不因为是循环产物就免检**
- 警惕**理解债**（comprehension debt）：循环每 ship 一批，主动给 Tony 3 行内的"这轮改了什么 + 为什么"摘要

## 现成循环库

`~/.claude/commands/loops/` 下即用循环（`/loops:<name>` 单跑一轮，套上路由表工具变循环）：
- `/loops:green` — 修到测试/构建全绿
- `/loops:babysit-prs` — 盯自己的 PR：CI 红了修，comment 来了改
- `/loops:ledger-drain` — 清 `.omc/plans/` 未完成 ledger，一轮一批
- `/loops:codex-review` — 当前 diff 交 Codex(gpt-5.5) 独立审，VERDICT 驱动 implement→review→fix（分工见 `rules/claude-codex-collab.md`）
- 设计新循环 → `/loop-design <一句话目标>`
