# gpt5pro 桥:GPT-5.5 Pro(网页桶)做战略 + Codex 执行 + Claude Code 编排

## Definition of Done
- Must:
  - 一个全局命令 `gpt5pro "<prompt>"` → 驱动 bb-browser 控制的 Chrome 里**已登录的 ChatGPT Pro 会话**,选 GPT-5.5 Pro,提交,轮询等长推理完成,抓回 markdown 答案到 stdout
  - 接入 Claude Code:包成可调用工具(MCP 工具 / skill / slash 命令之一),让 Claude 自动「战略→gpt5pro 拿方案→Codex 执行」
- Won't(本次不做):多账号、额度池化、逆向 backend API、付费 API 路径(B 方案另议)
- 验收命令:`gpt5pro "用一句话说明 X" ` 能在 ChatGPT 未额外花钱的前提下返回 GPT-5.5 Pro 的回答
- 停止条件:命令能稳定跑通一次真实战略问答 + Claude 能自动调用一次,即交付;UI selector 健壮性后续迭代

## 架构
Claude Code(编排+验收) ── 战略层: gpt5pro → 网页 GPT-5.5 Pro(独立网页桶,免费)
                        └─ 执行层: codex MCP / codex exec(Codex 桶)

## Discovery findings(2026-06-19,对 chatgpt.com 实测)
- bb-browser v0.11.6,驱动**真实 Google Chrome**(CDP),窗口可见可手动操作
- 输入框: `#prompt-textarea`(DIV contenteditable=true,ProseMirror 式) → 注入需 focus + 模拟 input 事件
- 发送键: **有文字后才出现**(空时只有 composer-plus-btn / 语音);待文字注入后再定位(候选 `#composer-submit-button` / `[data-testid=send-button]`)
- 模型选择器: `button[aria-label="模型选择器"]`,当前显示 "ChatGPT"(默认)
- backend API(`/api/auth/session` 等)有反自动化防护、对注入上下文返回脱敏空响应 → **确定走 UI 驱动,不走 API**
- GPT-5.5 Pro 长推理 = 网页内异步后台任务 → 用「提交 + DOM 轮询完成信号」而非等单次响应

## Ledger
- [x] item-1: 确认 bb-browser 连通 + 驱动真实 Chrome
- [x] item-2: discovery — 输入框/发送键/模型选择器 selector
- [x] item-3: 登录已解决(Tony 手动登录 Pro)
- [x] item-4: 登录态下确认 Pro 账号(Adam Sheng/Pro),新对话默认 "Pro 扩展"=高推理桶,无需强制切模型
- [x] item-5: 写 gpt5pro.sh(纯 eval:execCommand 注入 + DOM 轮询,扛 Pro 长推理)
- [x] item-6: 软链 ~/.local/bin/gpt5pro,smoke test 通过(68s 返回真实 GPT-5.5 Pro 答案)
- [x] item-7: 写 /strategy slash 命令(已注册可用)
- [x] item-8: 写说明 + 存 memory reference_gpt5pro-bridge
