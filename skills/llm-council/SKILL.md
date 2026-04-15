---
name: llm-council
version: 2.0.0
description: |
  LLM Council — Karpathy 式多模型议会。5 个 AI 顾问并行回答问题，
  匿名互评打分，主席综合最佳答案。触发：/llm-council, /council,
  "开会讨论", "council", "议会模式"
allowed-tools:
  - Agent
  - Bash
  - Read
  - Write
  - Grep
  - Glob
  - AskUserQuestion
---

# LLM Council — 多模型议会决策系统

灵感来自 [Andrej Karpathy 的 LLM Council](https://github.com/karpathy/llm-council)。

## 核心流程

```
用户提问 → Stage 1: 5个顾问分批回答 (3 Agent 并行 → Codex → Gemini 顺序)
         → Stage 2: 匿名互评打分 (3 Agent 并行)
         → Stage 3: 主席综合最终答案
```

---

## Step 0: 解析输入

用户输入格式：
- `/council <问题>` — 直接提问
- `/llm-council <问题>` — 同上
- `/council` 无参数 — 用 AskUserQuestion 询问问题

如果用户没有提供问题，用 AskUserQuestion 询问：
> 请输入你想让 AI 议会讨论的问题。可以是技术决策、架构选择、方案对比等任何需要多角度分析的问题。

---

## Step 1: 检查工具可用性 + 环境预热

**必须用绝对路径检查**，不要用 `which`（shell PATH 不可靠）：

```bash
CODEX="/Users/adam/.local/bin/codex"
GEMINI="/Users/adam/.nvm/versions/node/v24.14.0/bin/gemini"
CODEX_OK=$($CODEX --version 2>&1 && echo "OK" || echo "FAIL")
GEMINI_OK=$($GEMINI --version 2>&1 && echo "OK" || echo "FAIL")
echo "Codex: $CODEX_OK"
echo "Gemini: $GEMINI_OK"
```

至少需要 Claude（内置）。Codex 和 Gemini 不可用时，用额外的 Claude subagent 补位。
目标始终是 5 个顾问。

---

## Step 2: Stage 1 — 分批征集意见

向用户展示：

```
🏛️ LLM COUNCIL 已召集
════════════════════════════════════════════════════════════
议题: <用户的问题>
顾问: Advisor A (Claude Opus) | Advisor B (Claude Sonnet) | Advisor C (GPT/Codex) | Advisor D (Gemini) | Advisor E (Claude Haiku)
════════════════════════════════════════════════════════════
Stage 1/3: 征集独立意见中...
```

### ⚠️ 关键调度规则（必须严格遵守）

Codex 和 Gemini 是前台 Bash 命令，**不能**和 Agent subagent 在同一条消息中并行派发。
必须分两批执行：

**第一批（并行）**：3 个 Agent subagent 同时派发
- Advisor A (Opus) + Advisor B (Sonnet) + Advisor E (Haiku)

**第二批（顺序）**：等第一批完成后，依次执行 Codex 和 Gemini
- Advisor C (Codex) → Advisor D (Gemini)

### Advisor A — Claude Opus (Agent subagent)
```
Agent(model=opus, subagent_type=general-purpose):
"你是 LLM Council 的一位独立顾问。请对以下问题给出你的深度分析和建议。
要求：独立思考，给出有理有据的回答，包含优缺点分析。
回答控制在 500 字以内。

问题: <用户的问题>"
```

### Advisor B — Claude Sonnet (Agent subagent)
```
Agent(model=sonnet, subagent_type=general-purpose):
"你是 LLM Council 的一位独立顾问。请对以下问题给出你的深度分析和建议。
要求：独立思考，给出有理有据的回答，包含优缺点分析。
回答控制在 500 字以内。

问题: <用户的问题>"
```

### Advisor E — Claude Haiku (Agent subagent)
```
Agent(model=haiku, subagent_type=general-purpose):
"你是 LLM Council 的一位独立顾问。请对以下问题给出你的深度分析和建议。
要求：独立思考，注重实用性和可行性，给出简洁直接的建议。
回答控制在 300 字以内。

问题: <用户的问题>"
```

### Advisor C — GPT (via Codex CLI)

**等前三个 Agent 完成后再执行。** 使用绝对路径，不用 --json，直接读纯文本输出：

```bash
/Users/adam/.local/bin/codex exec "你是 LLM Council 的一位独立顾问。请对以下问题给出你的深度分析和建议。要求：独立思考，给出有理有据的回答，包含优缺点分析。回答控制在 500 字以内。问题: <用户的问题>" -s read-only 2>&1 | head -200
```

Bash 参数：`timeout: 180000`（3 分钟）

**Codex 输出验证**：如果输出为空或只有错误信息（不含中文实质内容），视为失败，立即用 Claude Sonnet Agent 补位（prompt 加"从工程实践角度"）。

### Advisor D — Gemini (via Gemini CLI)

**等 Codex 完成后再执行。** 使用绝对路径：

```bash
/Users/adam/.nvm/versions/node/v24.14.0/bin/gemini -p "你是 LLM Council 的一位独立顾问。请对以下问题给出你的深度分析和建议。要求：独立思考，给出有理有据的回答，包含优缺点分析。回答控制在 500 字以内。问题: <用户的问题>" 2>&1 | head -200
```

Bash 参数：`timeout: 180000`（3 分钟）

**Gemini 输出验证**：如果输出为空或 exit code 非 0 或只有错误信息，视为失败，立即用 Claude Sonnet Agent 补位（prompt 加"从产品思维角度"）。

收集所有 5 个回答，记为 Response A ~ E。

---

## Step 3: Stage 2 — 匿名互评

向用户展示：
```
Stage 2/3: 匿名互评中...
```

**核心规则：匿名化**
- 将 5 个回答编号为 Response 1 ~ 5（随机打乱顺序，不对应 A~E）
- 每个评审者看到的是**除自己之外的 4 个回答**
- 评审者不知道哪个回答来自哪个模型

**并行派发 3 个评审者**（全部用 Agent subagent，确保并行可靠）：

### Reviewer 1 — Claude Opus (Agent subagent)
```
Agent(model=opus):
"你是 LLM Council 的匿名评审员。以下是针对同一问题的多个独立回答。
请从准确性、深度、实用性、逻辑性四个维度评分（1-10），并给出简短评语。
最后给出你的总排名（从最好到最差）。

原始问题: <问题>

Response 1: <打乱后的回答>
Response 2: <打乱后的回答>
Response 3: <打乱后的回答>
Response 4: <打乱后的回答>
Response 5: <打乱后的回答>

输出格式:
| Response | 准确性 | 深度 | 实用性 | 逻辑性 | 总分 | 评语 |
排名: [最佳 → 最差]"
```

### Reviewer 2 — Claude Sonnet (Agent subagent)
同样的 prompt，通过 Agent(model=sonnet) 执行。

### Reviewer 3 — Claude Haiku (Agent subagent)
同样的 prompt，通过 Agent(model=haiku) 执行。

**注意**：Stage 2 评审全部使用 Agent subagent 而非 Codex/Gemini CLI。
原因：评审 prompt 很长（包含5个完整回答），Codex/Gemini CLI 对超长 prompt 不稳定。
多模型多样性已在 Stage 1 顾问阶段体现，评审阶段优先保证可靠性。

收集所有评审结果。

---

## Step 4: Stage 3 — 主席综合

**主席由 Claude Opus 担任**（当前对话的主 agent 直接执行，不再派子 agent）。

综合所有评审结果，生成最终答案：

```
🏛️ LLM COUNCIL 最终裁决
════════════════════════════════════════════════════════════

📊 评审得分汇总:
| 顾问 | 模型 | R1评分 | R2评分 | R3评分 | 平均分 |
|------|------|--------|--------|--------|--------|
| A    | Opus | 8.5    | 9.0    | 8.0    | 8.5    |
| B    | Sonnet| 7.0   | 7.5    | 8.0    | 7.5    |
| C    | GPT  | 8.0    | 8.5    | 7.5    | 8.0    |
| D    | Gemini| 7.5   | 7.0    | 7.5    | 7.3    |
| E    | Haiku | 6.5   | 7.0    | 6.0    | 6.5    |

🏆 最佳回答: Advisor X (模型名)
📉 共识度: X% (评审排名一致性)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 主席综合意见:

<综合所有顾问的最佳观点，形成一个完整、准确、有深度的最终答案>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 关键分歧点:
<列出顾问之间的主要分歧，以及主席的判断>

🔍 各顾问原始回答可在上方 Stage 1 输出中查看
════════════════════════════════════════════════════════════
```

---

## 输出规范

1. **Stage 1 结果**：展示每个顾问的完整回答（标记模型来源）
2. **Stage 2 结果**：展示评审打分表（此时揭示匿名编号对应哪个顾问）
3. **Stage 3 结果**：主席综合最终裁决

---

## 降级策略

| 情况 | 处理 |
|------|------|
| Codex 输出为空/报错 | 立即用 Claude Sonnet Agent 补位（prompt 加"从工程实践角度"） |
| Gemini 输出为空/报错 | 立即用 Claude Sonnet Agent 补位（prompt 加"从产品思维角度"） |
| 两者都不可用 | 5 个顾问全部用 Claude（Opus×1 + Sonnet×2 + Haiku×2），不同 prompt 角度 |
| 某个顾问超时 | 标记为"缺席"，用 4 个顾问继续 |
| 评审超时 | 用 2 个评审结果继续 |

### 输出验证规则

Codex/Gemini 的输出必须通过以下检查才算成功：
1. **非空**：输出不为空字符串
2. **有实质内容**：包含至少 50 个中文字符或 200 个英文字符
3. **非纯错误**：不是纯粹的错误信息（如 "Error:", "FATAL", "command not found"）

任何一项不通过，立即启动对应的 Claude Agent 补位，不要重试 CLI。

---

## CLI 调用铁律（必须遵守）

1. **绝对路径**：Codex 用 `/Users/adam/.local/bin/codex`，Gemini 用 `/Users/adam/.nvm/versions/node/v24.14.0/bin/gemini`
2. **不用 --json**：Codex 直接读纯文本输出，不做 JSON 解析
3. **不用 2>/dev/null**：用 `2>&1` 保留错误信息用于诊断
4. **管道 head -200**：限制输出长度，防止上下文爆炸
5. **timeout: 180000**：Bash 工具的 timeout 参数设为 180 秒
6. **前台执行**：不用 `run_in_background`（后台模式 PATH 丢失导致 exit 127）
7. **顺序执行**：Codex 和 Gemini 不能互相并行，必须一个完成后再执行下一个
8. **不与 Agent 并行**：Codex/Gemini 的 Bash 调用不要和 Agent subagent 放在同一条消息中

---

## 注意事项

- **分批调度**：Stage 1 分两批（3 Agent 并行 → Codex/Gemini 顺序），Stage 2 全部用 Agent 并行
- **匿名化是核心**：Stage 2 中评审者不能看到模型名称，防止偏见
- **打乱顺序**：每个评审者看到的回答顺序应不同，避免位置偏见
- **主席不参与评审**：主席只在 Stage 3 综合，不给自己的回答打分
- **成本意识**：整个流程约消耗 5 次顾问调用 + 3 次评审调用 = 8 次 LLM 调用
- **失败即补位**：CLI 调用失败不重试，直接用 Agent 补位，保证流程不阻塞
