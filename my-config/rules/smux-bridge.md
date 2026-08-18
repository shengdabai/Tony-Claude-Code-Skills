---
description: smux 多代理团队协同：在 tmux team 会话中用 tmux-bridge 调度真实 Codex CLI 与 Gemini CLI，而非内置 Agent tool。
---

# smux 多代理团队协同

**在 tmux team 会话中(通过 `smux` 或 `team-start` 启动),必须用 tmux-bridge 调度真实的 Codex CLI 和 Gemini CLI,不要用内置 Agent tool 生成子 agent。**

**Why**:team 会话里那几个 pane 已经是启动好的真实 CLI 进程,各自带独立额度和独立模型族。再用内置 Agent tool 起子 agent,等于在 Claude 额度里重跑一份同样的活,既浪费已开的进程,又把跨模型族互审退化成同族自审。

## 检测方法

运行 `tmux-bridge list 2>/dev/null` — 如果能看到 `codex-build` 和 `gemini-research` 标签的 pane,说明你在 smux 团队环境中。

## 调度规则

在 smux 团队环境中:

- **研究/文档/调研任务** → 通过 tmux-bridge 派给 `gemini-research` pane(真实 Gemini CLI)
- **代码实现/Review 任务** → 通过 tmux-bridge 派给 `codex-build` pane(真实 Codex CLI)
- **构建/测试/git 命令** → 通过 tmux-bridge 在 `shell-ops` pane 执行
- **架构设计/集成/规划** → 自己完成(claude-lead 角色)
- **仅当不在 smux 环境时**,才使用内置 Agent tool 作为 fallback

## tmux-bridge 交互纪律(read-act-read)

```bash
# 1. 先读目标 pane
tmux-bridge read <pane-label> 20
# 2. 发消息
tmux-bridge message <pane-label> "你的任务描述"
# 3. 再读确认
tmux-bridge read <pane-label> 5
# 4. 发送 Enter
tmux-bridge keys <pane-label> Enter
# 5. 等待合理时间后读取结果
tmux-bridge read <pane-label> 50
```

## 注意事项

- 不要 sleep 轮询等待 agent 回复,agent 完成后通过 tmux-bridge 回复到你的 pane
- 派任务前先 read 目标 pane,确认它处于空闲状态(在提示符处)
- 如果目标 pane 中的 AI 正忙,等它完成再派新任务
- 任务描述要清晰完整,包含目标、范围、输出格式
- 角色职责与权限边界以 `~/.config/ai-governance/MULTI_AGENT_GOVERNANCE.md` 为准(`~/TEAM_ROLES.md` 已不存在,2026-08-18 核实;`team-start` 若重新生成该文件,以生成版为准)
