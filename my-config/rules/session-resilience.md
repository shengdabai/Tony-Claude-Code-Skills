# Session Resilience: Plan-Then-Execute

## Iron Law: 大型任务必须先生成可恢复的 TODO ledger

usage limit、API 失败、上下文压缩都会中断会话。任何超过 5 个独立子任务的工作，必须先产出持久化 TODO 文件，然后再批量执行。

## 触发条件

任一满足即必须 plan-first：
- 涉及 ≥ 5 个独立文件/repo/项目
- 预计 ≥ 30 分钟执行时间
- 涉及多轮 sub-agent 调度
- 用户用了 "audit"/"批量"/"全部"/"所有" 等词

## 工作流

### Phase 1: Plan（cheap）
1. 扫描范围，识别所有 work item
2. 写到 `.omc/plans/<task-name>-todo.md`，格式：
   ```markdown
   # <Task>
   - [ ] item-1: <repo/file> — <action>
   - [ ] item-2: ...
   ```
3. 估算总成本，向用户确认后才进 Phase 2
4. **不**修改任何代码

### Phase 2: Execute（expensive）
1. 每完成一个 item 立即把 `[ ]` 改成 `[x]` 并 commit/save
2. 每批最多 3-5 个 item，做完一批就保存 progress
3. 失败的 item 标记 `[!]` 并写明原因，不阻塞后续 item
4. 中断时下次会话只需读 ledger 跳过 `[x]` 项

### Phase 3: Resume（如果中断）
1. 新会话第一步：读 `.omc/plans/<task-name>-todo.md`
2. 报告："共 N 项，已完成 M 项，剩余 K 项，从 item-X 继续"
3. 不重做已完成项，不重新规划

## Sub-agent 派发模式

并行扫多 repo 时：
- 每个 sub-agent 写结构化报告到 `/tmp/<task>-<repo>.md`
- 只返回 3 行摘要给主 agent，避免 context 爆炸
- 主 agent 汇总各报告 → 一份 executive summary
- **禁止**让 sub-agent 直接修复，先返回 finding，由用户审批后再 fix

## 防过度

- ≤ 5 个 item 的小任务直接做，不要为了仪式感写 ledger
- 用户已经给了清晰 todo 列表的，不要再额外生成 ledger
- 一次性命令（git push、build）不需要 ledger
