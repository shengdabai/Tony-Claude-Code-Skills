---
name: limit-continue-work
preamble-tier: 3
version: 3.0.0
description: |
  当 Claude Code 遇到 5 小时用量限制（rate limit）时，自动等待用量重置并继续执行之前的任务。
  保存任务快照 + 使用 CronCreate 原生定时任务 + 自动恢复执行。
  Use when: "limit continue", "auto continue", "等限制重置", "自动继续", "用量限制后继续",
  "设置限制后自动恢复", "limit reset continue"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - CronCreate
  - CronDelete
  - CronList
---

## What This Skill Does

当用户即将耗尽 Claude Code 用量限制时，此 skill 会：
1. **保存当前任务快照** — 记录任务描述、进度、下一步、关键上下文
2. **设置 CronCreate 原生定时任务** — durable + one-shot，在指定时间触发恢复
3. **自动恢复** — Claude Code 在定时时间读取快照并继续执行

## Architecture (v3 — Native CronCreate)

```
CronCreate (durable: true, recurring: false)
  → 到时间后 Claude Code 自动执行 prompt
  → prompt 读取快照文件
  → 继续未完成的工作
```

**为什么不用 launchd？**
- launchd 没有 TTY，Claude Code 需要终端环境
- osascript 打开 Terminal.app 不可靠（权限问题、PATH 问题）
- CronCreate 是 Claude Code 原生功能，durable 模式写入 `.claude/scheduled_tasks.json`，重启后自动恢复
- One-shot durable 任务如果错过（REPL 关闭期间），下次启动时会补执行

## Execution Steps

当用户触发此 skill 时，按以下步骤严格执行：

### Step 1: 收集任务上下文

从当前对话上下文中提取（不要额外询问用户，除非信息严重不足）：
- **Task Description**: 用户原始任务描述
- **Progress**: 已完成的步骤（列出具体文件修改、命令执行等）
- **Next Steps**: 接下来需要做的事情（越具体越好）
- **Key Context**: 重要的文件路径、变量名、架构决策、API key 位置等
- **Resume Time**: 用户指定的恢复时间（如 "2am"、"5小时后"），默认 5 小时后

### Step 2: 写入任务快照

```bash
mkdir -p ~/.claude/limit-continue-work/snapshots
```

写入文件 `~/.claude/limit-continue-work/snapshots/snapshot-$(date +%Y%m%d-%H%M%S).md`：

```markdown
---
created: {当前 ISO 时间}
working_directory: {pwd 输出}
resume_after: {恢复时间, ISO 格式}
status: pending
---

## Task Description
{从对话上下文提取}

## Progress So Far
{已完成的具体步骤}

## Next Steps
{接下来要做的事情，尽量具体到命令级别}

## Key Context
{文件路径、决策、注意事项}
```

### Step 3: 设置 CronCreate 定时恢复

**计算 cron 表达式**：根据用户指定的恢复时间，生成对应的 cron 表达式。

示例：
- "2am" → `"3 2 10 4 *"` (4月10日 2:03am，避开整点)
- "5小时后" → 计算目标时间的 minute hour day month
- "明天早上" → `"57 8 {tomorrow_day} {tomorrow_month} *"`

**调用 CronCreate**：

```
CronCreate({
  cron: "{计算出的 cron 表达式}",
  prompt: "我之前的任务因为用量限制中断了，现在用量已经重置。\n\n请读取任务快照文件了解完整上下文: {快照文件绝对路径}\n\n执行步骤：\n1. 用 Read 工具读取上面的快照文件\n2. 理解之前的任务、进度和下一步\n3. cd 到 working_directory 指定的目录\n4. 从 Next Steps 部分继续执行未完成的工作\n5. 全部完成后运行: sed -i '' 's/^status: pending/status: completed/' '{快照文件路径}'",
  durable: true,
  recurring: false
})
```

**关键参数**：
- `durable: true` — 写入 `.claude/scheduled_tasks.json`，重启后保留
- `recurring: false` — 一次性任务，执行后自动删除
- 避开 :00 和 :30 分钟，减少 API 拥堵

### Step 4: 验证并确认

```bash
# 确认快照已写入
ls -la ~/.claude/limit-continue-work/snapshots/

# 确认 scheduled_tasks.json 已更新
cat ~/.claude/scheduled_tasks.json 2>/dev/null | head -20
```

同时调用 `CronList` 确认任务已注册。

向用户输出确认信息：
- 快照保存位置
- 预计恢复时间（精确到分钟）
- 恢复方式：CronCreate (durable, one-shot) → Claude Code 自动执行 prompt → 读取快照 → 继续工作
- 取消命令：`CronDelete({id: "{job_id}"})`
- **重要提醒**：Claude Code 需要保持运行（REPL idle 状态）或在恢复时间之前重新启动。如果 REPL 关闭，下次启动时会补执行错过的 durable one-shot 任务。

### Step 5: 清理旧数据

```bash
# 清理 7 天前的旧快照
find ~/.claude/limit-continue-work/snapshots/ -name "snapshot-*.md" -mtime +7 -delete 2>/dev/null

# 清理旧的 launchd 残留（v2 遗留）
rm -f ~/Library/LaunchAgents/com.claude.limit-continue-work.plist 2>/dev/null
launchctl bootout gui/$(id -u) com.claude.limit-continue-work 2>/dev/null || true
rm -f ~/.claude/limit-continue-work/resume.sh 2>/dev/null
rm -f ~/.claude/limit-continue-work/run-session.command 2>/dev/null
rm -f ~/.claude/limit-continue-work/resume-prompt.txt 2>/dev/null
```

## Cancel Scheduled Resume

用户说"取消恢复"时：
1. 调用 `CronList` 找到对应的 job ID
2. 调用 `CronDelete({id: "job_id"})` 取消
3. 可选：将快照 status 改为 `cancelled`

## Manual Resume

如果用户想手动恢复（不等定时任务）：
1. 读取最新的 pending 快照：`ls -t ~/.claude/limit-continue-work/snapshots/snapshot-*.md | head -1`
2. 读取快照内容
3. 按 Next Steps 继续执行

## Debugging

如果恢复没有触发：
1. `CronList` — 检查任务是否还在
2. `cat ~/.claude/scheduled_tasks.json` — 检查 durable 任务文件
3. 确认 Claude Code REPL 在恢复时间点是否运行（或之后是否重新启动过）
4. 检查快照文件 status 是否仍为 `pending`

常见问题：
- **任务没触发**：Claude Code REPL 必须在运行中（idle 状态）或在恢复时间后重新启动
- **7天过期**：recurring 任务 7 天后自动过期，但 one-shot (recurring: false) 不受此限制
- **错过的任务**：durable one-shot 任务如果在 REPL 关闭时错过，下次启动会补执行

## Notes

- v3 完全使用 Claude Code 原生 CronCreate，不依赖 launchd、osascript、Terminal.app
- durable 模式持久化到 `.claude/scheduled_tasks.json`
- one-shot 模式执行一次后自动删除
- 快照自动保留 7 天
- 如果用户关闭了 Claude Code，下次打开时错过的 durable one-shot 任务会自动补执行
- 用户可以在任意 Claude Code 会话中手动恢复（读取快照文件即可）

## Migration from v2

v3 会自动清理 v2 遗留的 launchd 相关文件（Step 5），无需用户手动操作。
