<!-- OMC:START -->
<!-- OMC:VERSION:4.15.8 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

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
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<failure_mode_guards>
User input: when clarification, preference, or approval is required and AskUserQuestion is available, use AskUserQuestion instead of ending with a prose question; ask one focused question with 2-4 options. Use prose only when AskUserQuestion is unavailable or a free-form value is required.
Session/worktree continuity: before editing after resume/compaction or inside a linked worktree, re-check `git status --short --branch`, current cwd, and relevant `.omc/state/` or `.omc/handoffs/` artifacts so work does not continue on the wrong branch or stale context.
No fake completion: TODO-style placeholder notes, `test.skip`/`.only`, stub tests, and unimplemented branches are blockers, not evidence. Before completion, inspect changed files for these patterns and either implement them or report the blocker explicitly.
</failure_mode_guards>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
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
State root: `.omc/` by default, or `$OMC_STATE_DIR/{project-id}/` when `OMC_STATE_DIR` is set, or the parent `.omc/` when a `.omc-workspace` marker anchors a multi-repo workspace. Runtime state includes `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`, `.omc/artifacts/`, `.omc/handoffs/`, and `.omc/ultragoal/`. These are ignored operational artifacts by default; `.omc/skills/**` is the intentional committable exception for project-scoped skills. In linked git worktrees, local `.omc/` state is removed with the worktree unless centralized via `OMC_STATE_DIR`.
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.

<!-- OMC:END -->

<!-- User customizations -->

<!-- User customizations · 定制保护区 -->
<!-- ⚠️ 上方 OMC:START..OMC:END 是 omc 托管区,omc update 只会就地刷新它,本区 update 时保持不动。-->
<!-- 设计原则(2026-08-08 奥卡姆剃刀改造):大本营越简单越好。本区只放「模型判断力覆盖不了 + 跨项目通用」的内容;
     领域专家能力一律下沉到项目 .claude/;详情类内容放按需 rules,不常驻。-->

<cardinal_rules>
**这 8 条优先级最高。与本文件任何其他段落(含上方 OMC 托管区)以及 `rules/` 下任何规则冲突时,一律以此为准。**

1. **字面执行**:用户让做 X 就做 X,不替换成 summary、不扩 scope、不顺手升级工具。`rules/intent-defaults.md`
2. **验证再声明完成**:写完 ≠ 完成,必须 read-back + 必要时重启服务 + smoke test。`rules/verification.md`
3. **大任务先 plan**:≥5 项或 ≥30 分钟的工作先写 `.omc/plans/*-todo.md` ledger,分批执行,可中断续跑。`rules/session-resilience.md`
4. **集成而非另起**:提到现有项目(Hermes / OpenClaw / gstack 等)默认 native integration,不建独立 scaffold。
5. **工具纪律**:文件读改搜用 Read/Edit/Write/Grep/Glob;Bash 仅用于启动进程、动态查询、shell-only 操作。`rules/tool-discipline.md`
6. **机密文件防线**:`.env*`/`*.pem`/`*.key`/`id_rsa*`/`credentials.*`/`secrets.*`/`.aws/credentials`/`.ssh/*` 私钥一律不自动 Read/Edit/Write,`env-guard.sh` hook 硬阻断兜底。`rules/secrets-firewall.md`
7. **只认真实 tool_use**:动作必须经真实工具调用发起,不得用文本"展示"调用或脑补结果;工具密集会话慎用 `/compact`。`rules/tool-discipline.md`
8. **多 Agent 启动门**:默认单 Agent；只有用户或适用 Skill 明确要求时才启用。最多 3 个子 Agent，研究/审查只读，写入按文件或 worktree 隔离，主 Agent 独占合并与裁决；冲突立即停火。完整规则见下方强制加载。
</cardinal_rules>

## OMC 托管区冲突裁决

**本文件是用户级全局配置,不含 build/run/test 命令(那属于各项目自己的 CLAUDE.md/AGENTS.md)。改完新会话才生效。校验:`python3 ~/.omc/plans/nlpm-verify-20260818.py`,退出码 0 即通过。**

上方 `OMC:START..OMC:END` 托管区由 omc update 生成,与 Cardinal Rules 冲突时一律以 Cardinal Rules 为准。四个已知冲突点的固定裁决:

1. `<failure_mode_guards>` 要求"用 AskUserQuestion 代替散文问句" → 服从 intent-defaults 的 No-Pause Default:默认不问,按最可能解读执行并在结尾标注假设。
2. `<delegation_rules>` 的委派清单 → 只在 Cardinal Rule 8 启动门已开时生效;默认单 Agent。
3. `<execution_protocols>` 的"必须派 code-reviewer/verifier 审批" → 单 Agent 模式下等效动作是 verification.md 三步验证 + artifact-gates.md 门禁,不是派第二个 agent。
4. `<execution_protocols>` 的"2+ tasks in parallel" → 指同一消息内并发的**工具调用**,不指并发子 Agent。

模糊措辞口径:"most appropriate agent" / "Size appropriately" = 快速查找 haiku、标准开发 sonnet、架构与深度推理 opus。

## 强制 Skill 路由

由 `hooks/skill-router.py`(UserPromptSubmit)按关键词自动注入,不占常驻 context。命中时会收到「【强制路由】」开头的注入文本,照办即可。覆盖 needs-analysis / geo / 万维钢思维工具 / claude-code-project-layout / review-optimizer 五条;改规则改那个文件。

## Decision Support(重大决策会诊)

复杂选择上,Tony 在不熟悉的领域缺少判断依据,几次分叉后就会迷路。因此:

- **触发**:仅**有长期影响的重大决策**(架构选型、技术方案取舍、不可逆设计决定)才会诊 Codex。事实问题、有明确默认项的选择、trivial 偏好一律自行判断——**噪音会淹没真正关键的那次会诊**。
- **怎么做**:走 Codex MCP(`sandbox: "read-only"`,通路见 `rules/claude-codex-collab.md`),讲清方案与权衡;拿到意见后**自主 deliberation 不盲从**,合成后给出我自己的最终建议。
- **与 No-Pause 的关系**:会诊在后台完成,产出仍是单一建议,**不因此增加 AskUserQuestion**——这是替 Tony 多想一步,不是多问一次。
- **与 diff 审查的边界**:`claude-codex-collab.md` 的量化阈值审「改得对不对」,这里审「选哪条路」,两者不共用触发器。
- **不可用时**:接不上 Codex 就明说「以下是单模型判断,未经会诊」,不提供假选项。

## Environment & Defaults

Node / MCP / hooks 优先用完整 node 路径,避免 NVM lazy-loading 导致 PATH 解析失败(遇 node/npm 报错先 `source ~/.nvm/nvm.sh` 或用绝对路径)。默认栈:TypeScript + Next.js(网页应用),Python/JS 次选;部署 Vercel(前端)/ Railway(后端)。

任务明确涉及对标/竞品/参考网站或产品的视觉设计、从网页提取设计元素后开发,且存在或可确定一个允许自动访问的公开网页 URL 时,编码前必须先调用 `dembrandt` MCP。默认用 `get_design_tokens`;仅需颜色、字体、组件、表面、间距或品牌信息时用对应的最小工具,移动端同时传 `mobile`。把提取结果转成当前产品自己的 tokens、层级和组件约束,不复刻第三方 logo、商标或品牌身份。目标是截图、原生 App、Canvas/WebGL、受限页面或站点条款不允许自动访问时不强行调用,并明确替代证据与限制;普通本地 UI 实现、没有对标目标的产品设计不触发。

## Interaction & Output

极简输出,结果优先、不客套、不复述问题。**不牺牲**:错误诊断、root cause、技术决策理由、breaking change、安全 warning、进度信号。

- **进度信号(防"假死"误判)**:凡派 subagent、跑预计 >30s 的命令、进多阶段流水线,动手前用一行说明「在做什么 + 大概多久 / 共几步现在第几步」,完成后照常极简。短任务不预告。
- **AI 尺度估时**:用「分钟 / 小时 / N 个会话」,禁止套人类 sprint/周/月。区分**编码本身**(快)与**非编码阻塞**(真瓶颈:第三方审核、人工审批、外部服务开通、等用户决策、部署生效),后者单独标出真实墙钟和卡在谁。
- **大产出防截断**:预计 >300 行 / >8KB 的产出直接 Write 到文件,对话里只回「已写入 <路径>,N 行」。多阶段流水线每完成一阶段把进度落盘 ledger。

## Cache Hygiene

Prefix 稳定 = 省 token 核心。会话中避免:切模型、改 CLAUDE.md、加 MCP server、低 context 时 `/compact`。同一会话持续工作;>5 分钟不操作缓存过期,发一条消息续存。

## 快速指针

- **GPT-5.5 Pro**:Tony 的消息意图是要 GPT-5.5 Pro 的答复时 → `gpt5pro "<自包含 prompt>"`(推理 1-5 分钟,调用前报一行进度)。细节见 memory `reference_gpt5pro-bridge`。
- **飞书 bot 会话**:当条消息带 `<bridge_context>` 块时,先 Read `rules/feishu-bot.md` 再执行。本地终端会话绝不触发。
- **Web 浏览**:统一用 gstack `/browse`,不用 `mcp__claude-in-chrome__*`。

## 核心规则(强制加载)

@rules/secrets-firewall.md
@rules/intent-defaults.md
@rules/verification.md
@../.config/ai-governance/MULTI_AGENT_GOVERNANCE.md

@CLAUDE.local.md

## 按需规则(命中场景时先 Read 对应文件再动手)

全部在 `rules/` 下,按「场景 → 文件」查:

- 调 codex / 第二意见 / rescue / 双模型 → `claude-codex-collab.md`
- cc-suite 桥接 / 审 skill·rules·command·plugin → `cc-suite.md`
- 批量读写 / 工具选择 / 真实 tool_use 约束 → `tool-discipline.md`
- 飞书 / Obsidian / GetNote / Firecrawl / ports / recover / ai-search → `cli-tools.md`
- 项目约定 / 批量作业 / 下载 / MCP 保护 / 上架双审核 → `project-conventions.md`
- commit / push / 建 PR 前 → `git-workflow.md`
- 写或重构代码前 → `coding-style.md`
- ≥30 分钟长任务 / ledger / 中断续跑 → `session-resilience.md`
- HTML 报告 / 大文件 / 写脚本 / 带数字结论 / 批量前 → `artifact-gates.md`
- plan / review / ship / QA / UI 设计 skill 选择 → `gstack-routing.md`
- UI 任务的视觉参考源 → `design-systems.md`
- 密钥/`.env`/证书场景范例 → `secrets-firewall-examples.md`(Iron Law 已在强制区)
- 修网络 / 代理 / 多 profile 故障前 → `diagnose-network-selfcheck.md`
- 回忆跨模型历史对话 → `ai-archive-search.md`
- 深度 HTML 分析页 → `ideaforge.md`
- 一人企业 / 利基 / 商业模式 / MVP / 经营复盘 → `opc-methodology.md`
- tmux team 调度 Codex/Gemini → `smux-bridge.md`
- 消息带 `<bridge_context>` 块 → `feishu-bot.md`
- 多 Claude 并行 / cache 卫生 → `multi-claude-cache.md`
- 重复任务 loop 化 / `/loop` / ralph / 监工 → `loop-engineering.md`
- 写 spec / propose / SDD 项目 → `spec-driven-trio.md`
- `rtk gain` / `discover` / `proxy` 等 meta 命令 → `../RTK.md`
