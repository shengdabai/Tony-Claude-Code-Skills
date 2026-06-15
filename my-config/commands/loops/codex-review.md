---
description: 循环单轮：把当前 diff 交 Codex(gpt-5.5) 独立审一轮，按 VERDICT 修（套 /loop 或 ralph 变循环）
argument-hint: [可选：要审的路径/范围，默认当前 git diff]
---

# Loop: Codex Review（跨模型族独立审查）

loop engineering 循环体（规范见 `~/.claude/rules/loop-engineering.md`，分工见 `~/.claude/rules/claude-codex-collab.md`）。执行**一轮** implement→review→fix。

## 五要素
- Trigger: 被调用即跑一轮（持续审用 `/loop 10m /loops:codex-review` 或 `ralph: 审到 Codex APPROVED 且测试绿`）
- Work: 当前 diff 交 Codex 独立审，按 VERDICT 决定修不修
- Verify（硬判据）: Codex 返回 `VERDICT: APPROVED` **且** 本地 verifier exit 0
- Exit: APPROVED + verifier 绿 → 报告"✅ 已通过 Codex 审查"，并提示收敛后可跑一次全新 session 终审
- Budget: **≤5 轮**；同一问题 Codex 连续 3 轮仍 REVISE → 标 `[需人工]` 停手

## 本轮流程

**0. 预算闸（防失控，先做）** — 算本轮 key：`diff_hash = git diff | sha1 前 8 位`、`branch = git branch --show-current`。读 `.omc/logs/loop-codex-review.log`（结构化格式见步 6），按 `repo|branch|diff_hash` 过滤：
- 该 key 已有 ≥5 行（轮）→ 停，报告 `[需人工] 已达 5 轮上限`，不再调 Codex
- 某 `issue_key`（`file:行:问题短摘要` 归一）在该 key 下出现在 ≥3 个 `verdict=REVISE` 行 → 停，标 `[需人工] 反复未收敛`
- diff 变了（新 diff_hash）→ 轮数从 1 重新计（算新一组）

**1. 取 diff**：`git diff --function-context --find-renames`（$ARGUMENTS 指定范围则附加）；并备 `git diff --name-only`。无改动 → 报告"无 diff，循环可停"

**2. Secret 预检（强制，不可跳）** — 扫 diff 是否含：`.env*` 内容、API key（`sk-`/`ghp_`/`AKIA` 等）、token、私钥、cookie、客户 PII、机密文件绝对路径、大段专有数据。命中 → **停，不发 Codex**，向 Tony 报告并要么脱敏后再审、要么显式授权（对齐 secrets-firewall 铁律）

**3. 调 Codex**：先 `ToolSearch` select `mcp__plugin_nlpm_codex-cli__codex`（deferred 工具必须先加载 schema），再调：
- `model: "gpt-5.5"`（ChatGPT 账号唯一可用，gpt-5.2/-codex 会 400）
- `sandbox: "read-only"`，`config: {model_reasoning_effort: "high"}`
- prompt 模板（非平凡改动**随 diff 附 ≤20 行意图/不变量/非目标**，让 Codex 抓"实现对了但需求错了"）：
  > Independent senior review of this change. **Intent/invariants/non-goals**: <Claude 写的简短规格>. Flag real bugs, security holes, edge cases, broken invariants, **and any mismatch against the stated intent** — not style. Cite new-file `file:line`; if ambiguous, cite hunk header + symbol name. Be terse. End with exactly one line: `VERDICT: APPROVED` or `VERDICT: REVISE`.
  > ```diff
  > <粘贴 diff>
  > ```

**4. 解析末行 `VERDICT:`**（容错，**UNKNOWN 绝不当 APPROVED**）：
- 调用失败 / 429 限额 / 超时 / 无 VERDICT 行 / 格式坏 → 原样重试 **一次**（prompt 末加 "Your previous reply lacked a final VERDICT line"）；仍失败 → 日志记 `UNKNOWN`，停，标 `[需人工]`
- **APPROVED** → 跑 verifier（见步 5）。绿 → Exit；红 → 修测试暴露的问题（不 skip 测试求绿）
- **REVISE** → 按 receiving-code-review 纪律逐条评估（**先验证 Codex 说得对不对，不盲从**），合理的改、不合理的记理由。改完本轮结束

**5. Verifier 解析**（确定性，避免"没命令=默认绿"）：优先项目 AGENTS.md/README 指定的检查命令；否则按 `typecheck → lint → test → build` 找 package script；否则框架最小 smoke；都没有 → 记 `无自动 verifier`，APPROVED 需人工确认才算收敛

**6. 日志** 追加 `.omc/logs/loop-codex-review.log`，**结构化一行**（让步 0 可机读自我执行预算闸）：
`<ISO时间>|repo=<目录名>|branch=<b>|diff=<8位hash>|round=<N>|verdict=<APPROVED|REVISE|UNKNOWN>|issues=<key1,key2>|<≤一句摘要>`
（`issues` = 本轮 Codex 提的问题 key 列表，格式 `file:行:短摘要`，无则留空）

**7. 报告**（≤3 行）：本轮 VERDICT、改了什么、是否收敛

## 禁止（循环内红线）
- 禁止把 secret/机密内容塞进 Codex prompt（步 2 命中即停）
- 禁止为求 APPROVED 而删测试 / skip 测试 / 改断言迁就
- 禁止盲目照搬 Codex 建议——Codex 是第二意见不是最终裁决，Claude 验收
- 禁止把 `UNKNOWN`/出错当成 APPROVED 放行
- 不可逆操作（push/merge/删数据）标 `[需人工]`，循环不自动做
