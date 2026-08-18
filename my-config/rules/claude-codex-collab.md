---
description: Claude × Codex 双模型协同：按 benchmark 强项分工、通路选择表、交接班协议、5 个配合模式、review loop 与反模式。调 codex / 要第二意见 / 批量自动化时加载。
---

# Claude × Codex 协同（专业分工 + 默契配合）

> 提炼自 2026 工程界实践（Slot Machine / SmartScope review-loop / Ralph / Osmani Loop Engineering）
> + 本机已搭好的 Codex 设施。**目标 = 默认就让两个会员额度各干最擅长的活，Claude 编排验收、Codex 干活当第二意见。**
> 全局事实溯源在 memory `[[reference_claude-codex-collab-protocol]]`，本文件是可操作协议。

## Iron Law: 分工按 benchmark 强项，不按教条；Claude 编排+验收，Codex 执行+批评

没有哪个模型全维度通吃。**默认让每个模型干它最强的事**，Claude 永远是主编排者和最终验收人，Codex 是独立执行体 + 跨模型族第二意见。**写代码的不给自己打分**（maker/checker 分离）。

## 谁干什么（默认分工）

| 活儿 | 默认归谁 | 为什么 |
|------|---------|--------|
| 架构设计 / 根因未知的调试 / 想法发散 / 复杂 diff 评审 / 长上下文整仓理解 | **Claude（主）** | 长上下文、连续深推理、工具/skill 编排 |
| 独立 code review / 安全审查 / 第二意见 / 对抗式审查 | **Codex** | 跨模型族抓单模型盲区，"模型偏爱自己的输出" |
| 卡住 ≥2 次的 bug 的独立根因诊断（rescue） | **Codex** | 换模型族破思维定式 |
| 终端密集 / 脚本化 / 机械重复 / 可无人值守的批量 | **Codex（`codex exec`）** | token≈4× 省、价格≈半、sandbox 更硬；规避 Claude 6/15 programmatic 计费（[[feedback_claude-615-programmatic-billing-alert]]） |
| 定时/launchd 自动化 | **Codex** | 同上，已落地 daily-article/ai-news.codex.sh |
| best-of-N 多方案择优（高价值/方案不明时） | **两者混合** | 不同模型族增加多样性，meta-judge 择优 |

角色可翻转：若某次明显 Codex 实现更顺手、Claude 规划更强，就翻转——**让每个模型干它当下最强的事，别教条**。

## 怎么调 Codex（通路选择，从快到可控）

**默认只用前 3 条**（MCP 只读审查 / rescue agent / `codex exec` 可审计批量）；后 3 条是**进阶/手动**，仅高价值或明确需要时用。

| 通路 | 层级 | 何时用 | 命令/入口 |
|------|------|--------|----------|
| **Codex MCP** | 默认 | 对话内第二意见/review/咨询，求快 | `mcp__plugin_nlpm_codex-cli__codex`（deferred，**先 `ToolSearch` select schema 再调**）。必传 `model: "gpt-5.5"`；**默认 `sandbox: "read-only"`**——Codex 是顾问不是改文件的手。`config: {model_reasoning_effort: "high"}` 做深活。**要 Codex 实际改文件 → 只在隔离 worktree 或明确划定的生成文件里 `workspace-write`；主工作区的修复由 Claude 评估后亲自落（防 stomp）** |
| **`codex:rescue` agent** | 默认 | Claude 卡住、要独立诊断、要第二实现 | Agent `subagent_type: "codex:codex-rescue"` 或 `/codex:rescue` |
| **`codex exec`（shell）** | 默认 | 严格超时/审计/CI gate/无人值守批量 | 绝对路径 `$HOME/.nvm/versions/node/v24.14.0/bin/codex exec "<prompt>" -m gpt-5.5 -s read-only 2>&1 \| head -200`。**前台**、abspath、`head` 限流（[[feedback_codex-gemini-foreground]]）。续轮 `codex exec resume <SID>` 不接受 `-C/--add-dir`，脚本须先 `cd $WORK`（[[reference_codex-exec-resume-flags]]） |
| **cc-suite 命令** | 进阶 | **只做两件事**:①审 NLP 工件(`/cc-suite:audit-skill\|-rules\|-command\|-plugin\|-nlp`) ②Codex job 管理(`/cc-suite:status\|result\|cancel\|continue`)。编码协作流程一律让位给 `cc`(cc-suite 无风险分级/无 VERDICT 闸门/无 UNKNOWN≠通过)。桥接必走 `~/.claude/scripts/cc-suite-bridge.sh`,详见 `rules/cc-suite.md` | 见 `rules/cc-suite.md` 裁决表 |
| **`/oh-my-claudecode:ccg`** | 进阶 | 要 Claude+Codex+Gemini 三方意见再综合 | tri-model 编排 |
| **worktree best-of-N** | 进阶 | 高价值/方案不明，多实现择优 | Agent `isolation: "worktree"` 跑 N 个独立实现 → meta-judge |

**铁律**：ChatGPT 账号可用 `gpt-5.5`/`gpt-5.6` 系（以 `~/.codex/config.toml` 当前 `model` 为准；`gpt-5.2` 等旧型号与 `-codex` 后缀 400 拒，[[reference_codex-mcp-chatgpt-account-model]]）。sub-agent 报 "Codex unavailable" 几乎都是没 `ToolSearch` 加载 deferred 工具，不是真不可用——主会话直调正常。

## 交接班协议（Claude ⇄ Codex 换手必走，2026-07-23 增补）

换手锚点在**仓库文件**不在聊天记录，两侧命令同源（`~/.claude/commands/{handoff,pickup}.md`，symlink 到 `~/.codex/prompts/`，两边都用 `/handoff` `/pickup` 调用）：
- **收工/换工具/额度快到/预感封号** → `/handoff`：交接单插 `.omc/handoffs/HANDOFF.md` 顶部（分支/已完成/进行中/下一步/坑/验证方式），同步勾 ledger，未提交改动打 WIP commit（`wip: xxx [cc]`/`[codex]`，不 push）。来不及跑命令时手写两行「在干嘛/下一步」也比不留强。
- **开工/接手另一工具的活** → `/pickup`：git status/log → 读交接单 → 读 ledger → ≤5 句汇报后直接从「下一步」继续（仅高风险动作等确认）。
- 交接单不进 git（全局 gitignore 已含 `.omc/handoffs/`）；与 `.omc/plans/` ledger 分工：ledger 管任务清单进度，交接单管「现场快照 + 坑 + 下一步」。
- **一支笔原则**：同一时刻同一分支只有一个工具在写；第二个工具只读（评审/答疑）或去独立 worktree（与"同文件并发 stomp"反模式同源）。
- Codex 侧同款协议已写入 `~/.codex/AGENTS.md`「跨工具交接协议」节——改本节时两边同步（防 convention 漂移）。

## 5 个默契配合模式

**1. Implement→Review 握手（最高频，默认开启）**
Claude 写完一段有意义的代码 → 派 Codex 独立审。**非平凡改动随 diff 附 ≤20 行意图/不变量/非目标**（让 Codex 抓"实现对了但需求错了"，单看 diff 抓不到）：
> review prompt 必须含："Review this git diff for bugs, security, edge cases, **and mismatch against the stated intent**. Cite file:line. End with exactly `VERDICT: APPROVED` or `VERDICT: REVISE`."
Claude 收到 REVISE 后按 receiving-code-review 纪律评估（先验证对不对，不盲从），改完可再审。
**复杂/高风险 diff 的边界**：Claude 做主语义评审（懂全局意图），Codex 做独立对抗式 bug/安全 pass，**两者分歧处 = 重点复核清单**。

**2. Rescue 触发器（换模型解卡）**
同一 bug 修 **2 次失败** → 用 Codex MCP 只读做**独立**根因诊断（起 rescue sub-agent 需 Tony 点头，见下方启动门边界表）（给它现象+相关文件，不给我的失败假设，避免污染）。**Codex 答复不直接采纳**——Claude 合成"原问题 + Codex 逐字结论 + 与我自己分析是否一致"后二次裁决。

**3. 对抗式 diff（高风险变更）**
关键重构让两边各出独立方案 → diff 两份输出，**分歧处就是风险点**，重点审分歧。

**4. 跨模型校验（事实/翻译/独立性）**
翻译、fact-check、独立性检查走 Codex 二次意见（xiaolai-write 已内置）。

**5. best-of-N + meta-judge（高价值/方案不明）**
≤3-5 个 worktree 隔离实现（部分派 Codex 部分 Claude 增加多样性）→ judge 在**单一 context 内联合推理所有候选** → 选明确赢家 / 合成各家最优 / 全部 reject。

## Review Loop（循环工程，五要素齐全）

自动化 generate→review→fix→until-approved，**从 Level-1 起步不要一上来搞重流水线**：

- **Trigger**：写完一段代码 / `/loops:codex-review` 被调用 / 套 `/loop` 周期跑
- **Work**：当前 diff 交 Codex 审一轮，按 VERDICT 决定修不修
- **Verify**（可执行，硬判据）：`VERDICT: APPROVED` 字符串匹配 **且** verifier exit 0。verifier 解析顺序：项目 AGENTS.md/README 指定命令 → `typecheck/lint/test/build` package script → 框架最小 smoke → **都没有则记"无自动 verifier"，需人工确认才算收敛**（不把"没命令"默认成绿）
- **Exit**：APPROVED + verifier 绿 → 停；**收敛后跑一次全新 session 终审**（破 resume 的上下文偏见）
- **Budget**：**≤5 轮**（循环体步 0 读 log 强制计数，非靠模型自觉）；同一问题 Codex 反复改 3 轮仍不过 → 标 `[需人工]`；Codex 调用失败/429/无 VERDICT → 重试 1 次仍坏记 `UNKNOWN` 停手，**绝不当 APPROVED**

循环体 = `/loops:codex-review`（套 `/loop` 或 `ralph` 变持续循环）。日志落 `.omc/logs/loop-codex-review.log`。

## 反模式（双模型协同特有的坑）

- **幻觉共识**：两边"看起来都同意"但都错了——比无限循环更阴险。高风险变更别只靠互评，留人工 diff gate。
- **无限互评循环**：缺 VERDICT 退出条件 / resume 上下文偏见让 Codex 抗拒重提问题 → 硬上 ≤5 轮 + 终审用全新 session。
- **Token 二次方螺旋**：每轮全量重算 history，20 步 loop 可烧 10× 估算。大输出存外部文件，context 只传短引用；循环必有 Budget。
- **convention 漂移**：`CLAUDE.md`（Claude 侧）与 `~/.codex/AGENTS.md`（Codex 侧）各自演化 → 两模型认知不一致。改护栏/分工时两边同步（90 天主战场护栏已在两侧顶部）。
- **同文件并发 stomp**：Claude 和 Codex 同时改同一批文件互相覆盖 → 并行必用 worktree 隔离。
- **过度工具化**：只需一个工具的活别上两个。简单任务 Claude 直接做完，不为仪式感派 Codex。
- **交接灌全量 transcript**：让前一方"总结现状"再交接，不要把整段对话塞给对方。

## 默认触发（什么时候主动派 Codex，不用等用户说）

**与 Cardinal Rule 8「多 Agent 启动门」的边界（先读这条再看阈值）**：启动门管的是**子 Agent 并发**，不是跨模型咨询。两者不冲突，因为触发的是不同东西：

| 通路 | 是否受启动门约束 | 说明 |
|------|----------------|------|
| Codex MCP（`sandbox: read-only`）、`codex exec -s read-only` | **不受约束** | 单进程只读咨询，不并发、不写文件、不产生第二个决策主体；等同于查文档 |
| `codex:codex-rescue` sub-agent、worktree best-of-N、`/oh-my-claudecode:ccg` | **受约束** | 这些真的起子 Agent，需用户或适用 Skill 明确要求才启用 |
| Codex `workspace-write`（让 Codex 实际改文件） | **受约束** | 产生第二个写入主体，必须走隔离 worktree 且由 Tony 明确要求 |

下面的自动触发阈值**只对第一行的只读通路生效**；命中第二、三行时改为向 Tony 说明"建议派 X，需要你点头"，不自行启用。

**自动 Codex 只读审查的量化阈值**（满足任一即派，避免"重要代码"过于模糊导致过/欠触发）：
- 改动 **> 80 行**，或
- 触及 **安全/认证/支付/数据库/文件系统/网络** 任一，或
- 产出**公开资产**（要 push/发布的代码），或
- **改了测试**，或
- 同一 bug 已 **≥2 次** 修复失败（→ 先用 Codex MCP 只读诊断；要起 `codex:codex-rescue` sub-agent 需 Tony 点头）

以上之外的小改动，Claude 自审即可，不为仪式感派 Codex。
机械批量 / 定时自动化 / 长 headless 跑批 → 默认 `codex exec`。
**派完必验收**（read-back / 看图 / smoke test）再交付——分工是"Codex 干活、Claude 编排验收"。
