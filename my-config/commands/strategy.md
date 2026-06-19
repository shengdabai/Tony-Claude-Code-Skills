---
description: 用 GPT-5.5 Pro(网页独立桶)做战略规划,再由 Codex 执行,Claude 编排验收
argument-hint: <战略问题 / 要规划或决策的任务>
allowed-tools: Bash(gpt5pro:*), Bash(~/.local/bin/gpt5pro:*), Task, Read, Edit, Write, Grep, Glob
---

# /strategy —— GPT-5.5 Pro 战略层 × Codex 执行层 × Claude 编排

把高价值的**战略/架构/决策**甩给 GPT-5.5 Pro(走 `gpt5pro` 命令 = ChatGPT 网页"Pro 扩展"高推理桶,**独立于 Codex 桶,等于白嫖第二个额度池**),拿回方案后由 Claude 编排、必要时交 Codex 执行,最后 Claude 验收。

## 输入
战略问题 / 任务:**$ARGUMENTS**

## 执行步骤(严格按序)

1. **提炼战略 prompt**。把 $ARGUMENTS 连同必要的本地上下文(相关文件摘要、约束、目标),浓缩成一个**自包含**的战略问题——因为 `gpt5pro` 是无状态新对话,看不到本会话上下文。把背景、已知约束、要它产出什么(方案对比 / 架构 / 决策建议 / 分步计划)讲清楚。

2. **调用 GPT-5.5 Pro**(进度提示:Pro 长推理通常 1–5 分钟,先告诉用户在等):
   ```
   gpt5pro "<提炼后的自包含战略 prompt>"
   ```
   - 复杂战略问题可设 `GPT5PRO_TIMEOUT=900`。
   - 失败处理:`session=no` → 提示用户在 bb-browser 的 Chrome 登录 ChatGPT Pro;其它非 0 退出 → 报错并回退到 Claude 自己规划,**不要谎称成功**。

3. **Claude 评估而非照搬**(maker/checker 分离 + receiving-code-review 纪律)。GPT-5.5 Pro 的方案是**第二意见**,不是命令:
   - 标出它和你自己判断一致 / 分歧之处;分歧点 = 重点复核。
   - 结合本地代码事实校验它的假设(它没看过你的仓库)。
   - 产出一份融合后的方案,注明哪些采纳了 Pro 的建议、哪些没采纳及原因。

4. **执行编排**(若任务需要落地):按 `rules/claude-codex-collab.md` 分工——
   - 机械批量 / 独立实现 / 第二实现 → 交 Codex(`codex exec` 或 codex MCP `gpt-5.5`,Codex 桶)。
   - 复杂语义改动 → Claude 自己落,关键节点交 Codex 独立 review。

5. **验收**(Cardinal Rule 2):read-back / smoke test / 看图,有证据再声明完成。

## 何时用
- 架构设计、技术选型、商业/产品决策、复杂重构方案、风险评估等**高价值、想要顶配推理 + 跨模型族第二意见**的场景。
- 日常小改、机械任务**不用** —— 直接 Claude/Codex 做,别为仪式感烧 Pro 桶。

## 分桶原理(为什么这么做省额度)
- GPT-5.5 Pro 走 ChatGPT 网页桶,Codex 走 Codex 桶,Claude 走 Claude Max —— **三个独立额度池分工**,战略不挤占执行额度,等效扩容。
- `gpt5pro` 实现见 `~/.claude/scripts/gpt5pro/`(bb-browser UI 驱动真实 Chrome 登录态)。
