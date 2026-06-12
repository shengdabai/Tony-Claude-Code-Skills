---
description: 设计一个新的 loop engineering 循环：补全五要素 → 生成 /loops:<name> 循环体 → 给出启动命令
argument-hint: <一句话目标，如"每天早上把昨天的飞书群消息总结发给我">
---

# /loop-design — 循环设计器

把一句话目标变成一个合规的 loop engineering 循环。规范 = `~/.claude/rules/loop-engineering.md`（先 Read 它）。

## 流程

### 1. 补全五要素（不挨个问，按 no-pause 原则做合理假设并标注）
从 "$ARGUMENTS" 推导：
- **Trigger**：周期（每 N 分钟/每天几点）还是条件（X 一坏就修）？
- **Work**：每轮的最小动作单元（一轮只做一件事/一批 ≤3 件）
- **Verify**：必须是**可执行命令**（exit code 判定）。推不出可执行验证 → 这是本设计的第一短板，明确告知 Tony 并给出最接近的替代（如独立 verifier agent）
- **Exit**：成功条件 + "循环可停"的报告措辞
- **Budget**：默认 同一错误 ≤3 次重试 / 单轮 ≤30 分钟 / 撞限即停 + ntfy 通知
仅当多个解读差异巨大且不可逆时才问（白名单见 intent-defaults）。

### 2. 安全审查
- Work 里含不可逆/外发操作（push 公开仓 / merge / 发消息 / 删数据 / 大额付费 API）？→ 该步改为 `[需人工]` 停点
- 多循环并行改同一批文件？→ 注明用 worktree 隔离
- 会话外定时？→ 提醒 Claude Code 本身不能定时，方案走 CronCreate 或 launchd 起 `claude` 会话

### 3. 生成循环体
写 `~/.claude/commands/loops/<kebab-name>.md`，结构对齐现有循环体（frontmatter description/argument-hint + 五要素表 + 本轮流程 + 禁止清单 + 日志行 `.omc/logs/loop-<name>.log`）。参考 `loops/green.md` 的骨架。

### 4. 交付
报告（≤ 6 行）：
- 五要素表（含我做的假设标注）
- 启动命令，按形态给一条：
  - 周期：`/loop <间隔> /loops:<name>`
  - 条件：`ralph: <目标>，verify 用 <命令>`（或 `/oh-my-claudecode:ultragoal`）
  - 会话外：CronCreate 排程 或 launchd plist（>5 项工作量则按 Cardinal Rule 3 先立 ledger）
- 停止方式：`/loop` 停掉排程 / `cancelomc` / `监工 off`
