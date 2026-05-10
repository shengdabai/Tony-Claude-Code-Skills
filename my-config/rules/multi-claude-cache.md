# Multi-Claude Session & KV Cache Hygiene

## 数据背景（来自 insights 报告）

- **7 次 overlap events** / 11 sessions involved / 17% messages 来自并行会话
- 每开一个新 Claude Code 窗口 = **冷启动** = 全部 prompt cache 失效
- 你的 CLAUDE.md 已 344 行 + 8 个 rules = 每次冷启动重算 ~10K tokens

## Iron Law: 优先 attach 已有会话，不要随手开新窗口

## 何时**应该**多开会话（合理）

- 真的并行不相关任务（Hermes 调试 + Obsidian 整理 — 完全无关）
- 一个会话已经压缩 / 接近 context 上限
- 一个会话被 ralph/autopilot/ultrawork 长时间占用

## 何时**不应该**多开（浪费 cache）

- 同一项目的连续对话（应该回原会话）
- 短问"你是谁"或快速澄清（直接在原会话问）
- 因为"想换个干净的"心理（cache miss 成本远高于复用脏会话）

## 操作建议

- macOS: `claude --continue` 恢复最近会话
- 用 `/history` 查找历史会话再 resume
- 多任务并行时记下哪些 tab 在做什么，避免重复开

## 与 Cardinal Rules 的关系

这条规则**不**属于 Cardinal Rules（不是错误防护，是优化建议）。但与 Cardinal Rule 3（plan-then-execute）配合：长任务用 ledger 记录进度，下次回来 resume，比开新会话效率高 5x。

## Stale-Session 检测

新会话开始时：
- 如果在最近 1 小时内有同项目的活跃 Claude 进程 → 推荐 attach
- 如果上一会话还有未 commit 的 ledger（`.omc/plans/*.md` 含 `[ ]`）→ 推荐 resume

## 预期效果

减少 30-50% 冷启动 → 报告里 270 messages × 0.17 multi-claude = 46 messages 的 cache 浪费可以收回。

## Context Window Hygiene

避免 context 最后 20% 做：
- 大规模 refactor / 多文件 feature implementation
- 复杂调试 / 跨多模块 trace

context 富裕时再做大动作；context 紧张时只做：
- 单文件 edit
- 独立工具创建
- 文档更新
- 简单 bug fix

## 模型选择

CLAUDE.md `<model_routing>` 章节是权威来源。简版：
- **Haiku**：快速查询、frequent 调用、worker agents
- **Sonnet**：默认开发工作、orchestration
- **Opus**：架构决策、深度推理、复杂 trace
