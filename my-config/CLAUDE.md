<!-- OMC:START -->
<!-- OMC:VERSION:4.9.1 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<cardinal_rules>
**这 6 条 Cardinal Rules 优先级最高,与下方任何规则冲突时以此为准。**

1. **字面执行**:用户让做 X 就做 X。不要替换为 summary、不要扩 scope、不要顺手升级工具。详见 `rules/intent-defaults.md`
2. **验证再声明完成**:写完 ≠ 完成。必须 read-back + 必要时 restart + smoke test。详见 `rules/verification.md`
3. **大任务先 plan**:≥ 5 个 item 或 ≥ 30 分钟的工作必须先写 `.omc/plans/*-todo.md` ledger,再分批执行,中断可恢复。详见 `rules/session-resilience.md`
4. **集成而非另起**:用户提到现有项目(Hermes / OpenClaw / gstack 等)默认 native integration,不要创建独立 scaffold
5. **工具纪律**:文件读改搜用 Read/Edit/Write/Grep/Glob,不要走 Bash 的 cat/sed/echo/find/grep。Bash 仅用于启动进程、动态查询、shell-only 操作。详见 `rules/tool-discipline.md`
6. **机密文件防线**:`.env*`、`*.pem`、`*.key`、`id_rsa*`、`credentials.*`、`secrets.*`、`.aws/credentials`、`.ssh/*` 私钥一律不得自动 Read/Edit/Write。`env-guard.sh` PreToolUse hook 会硬阻断,模型也必须自律。详见 `rules/secrets-firewall.md`
</cardinal_rules>

<operating_principles>
- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` (use `model=opus` for complex work). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
**项目结构权威规范** = `claude-code-project-layout` skill。任何涉及 `.claude/` 目录、CLAUDE.md、settings.json、hooks、agents、skills、plugins、output-styles、rules 创建/审查时,**必须先调用此 skill**,以图片标准为准。
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State: `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.

## Environment

- Node.js tools, MCP servers, hooks 中优先使用完整 node 路径(如 `~/.nvm/versions/node/v20.x.x/bin/node`),避免 NVM lazy-loading 导致 PATH 解析失败
- 遇到 node/npm 相关错误时,首先检查 NVM lazy-loading 问题:`source ~/.nvm/nvm.sh` 或用绝对路径

## Tech Stack

- Primary: TypeScript, Next.js (web apps default)
- Secondary: Python, JavaScript
- Deploy: Vercel (frontend), Railway (backend)

## Interaction Preferences

- 编码/构建过程中不要停下来问澄清问题,除非真的被阻断无法继续
- 做合理假设并简要标注,不要反复 AskUserQuestion
- 用户对可迭代修复的 bug 有耐心,但对浪费时间的阻断性问题零容忍

## Prompt Cache Hygiene

保持 prefix 稳定是 token 节省核心。缓存命中 90%+ 时 Opus 长会话成本降 80%。

**会话中避免**(破坏缓存前缀 = 全量重算):
- 切换模型(Opus/Sonnet/Haiku 各自独立缓存)
- 修改 CLAUDE.md / 添加 MCP servers / 100K context 以下用 /compact

**会话习惯**:
- 同一会话持续工作:10 轮会话 ≈ 10 个单轮的 1/5 成本
- >5 分钟不操作缓存过期,发一条消息续存(Pro/Max 1 小时 TTL)
- 一次多问几个相关问题,减少来回轮次

## Token Efficiency (Caveman Mode)

极简输出,砍废话不砍信息。

**禁止**:客套话 / 动作预告 / 尾部总结 / 复述用户问题 / 过渡句 / 解释工具行为

**要求**:结果优先 / 状态极简("完成"/"已修复"/"改了 3 个文件")/ 一句能说清的不用三句

**不牺牲**:错误诊断、root cause、技术决策理由、breaking change、安全 warning

## Language & Thinking

- User input: Chinese
- Internal thinking & reasoning: English (for efficiency and precision)
- All output/responses: Chinese
- Code, commands, identifiers: always English

## Model Usage Guidance

When the user asks you to perform tasks involving complex architecture design, multi-step planning, deep reasoning, or system-level decisions, proactively suggest: "这个任务比较复杂,建议先用 `/model opus` 切换到 Opus 4.6 以获得更好的推理质量。" Do NOT switch automatically.

## gstack 集成

Use /browse from gstack for all web browsing. Never use mcp__claude-in-chrome__* tools.

可用 skills: /plan-ceo-review, /plan-eng-review, /plan-design-review, /design-consultation, /design-review, /review, /ship, /browse, /qa, /qa-only, /setup-browser-cookies, /retro, /document-release, /gstack-upgrade.

智能路由规则详见 `@rules/gstack-routing.md`(场景识别 + 命令推荐 + 设计 skill 协调矩阵)。

## 引用的扩展规则

@rules/secrets-firewall.md
@rules/intent-defaults.md
@rules/verification.md
@rules/session-resilience.md
@rules/tool-discipline.md
@rules/coding-style.md
@rules/git-workflow.md
@rules/multi-claude-cache.md
@rules/patterns.md
@rules/gstack-routing.md
@rules/gbrain-routing.md
@rules/design-systems.md
@rules/cli-tools.md
@rules/smux-bridge.md
@rules/project-conventions.md
@rules/opc-methodology.md

@RTK.md
@CLAUDE.local.md
