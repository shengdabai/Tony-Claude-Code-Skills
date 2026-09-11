---
name: cc
description: Claude × Codex × GPT-5.5 Pro × Gemini 3 Pro 多模型协作流水线(Anthropic/OpenAI/Google 三族交叉互审)。当 Tony 说「cc」「走 cc」「用 cc 做」「cc 这个任务」「cc 流程」「多模型协作做 X」时触发。5 步双循环:① Claude+GPT-5.5 Pro+Gemini 三方并行出规划 ② Codex 整合挑刺,与 Claude 反复 review 到一致 ③ Codex 按定稿执行代码 ④ Claude code review 审一遍 ⑤ Codex 隔离 sub-agent 二次审查(高风险加 Gemini 三审 2/3 多数票),反复到无问题再出最终报告。用于需要高把握、跨模型族互审的编码任务。
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Task, TodoWrite
---

# cc —— Claude Code × Codex × GPT-5.5 Pro × Gemini 3 Pro 协作流水线

把一个编码任务交给四个角色协作完成(Anthropic / OpenAI / Google 三个独立模型族),**maker/checker 严格分离 + 跨模型族互审**,降低单模型盲区。Claude Code(你)是**总编排 + 验收人**,全程串这条线。

## 四个角色与调用方式

> **模型族多样性是 cc 的命门**:Claude=Anthropic 族,GPT-5.5 Pro + Codex 同属 **OpenAI 族**,Gemini=Google 族。真正独立的三族 = Anthropic / OpenAI / Google。Gemini 的差异价值 = 第三族 + ~1M 超大上下文(能吃整个 repo)。所以它只进**规划 ①** 和**高风险二审 ⑤**,不进编排/执行。

- **Claude Code(你)**:编排、独立规划、code review、最终验收。
- **GPT-5.5 Pro**:`gpt5pro "<自包含 prompt>"`(网页独立桶,无痕;长推理 1–5 分钟,调用前报一行进度)。无状态,prompt 必须自带全部上下文。
- **Codex(gpt-5.5)**:OpenAI 族第二意见 + 执行体。
  - 审查/挑刺(只读):`~/.nvm/versions/node/v24.14.0/bin/codex exec "<prompt>" -m gpt-5.5 -s read-only 2>&1 | tail -200`(前台、绝对路径、限流)
  - 执行代码(写):`codex exec "<prompt>" -m gpt-5.5 -s workspace-write 2>&1 | tail -300`(必要时 `--dangerously-bypass-approvals-and-sandbox`)
  - 隔离二审:**全新 codex exec 会话**(不 resume = 干净上下文),prompt 明确"你是独立二审、无前序上下文"。
  - 账号只支持 `-m gpt-5.5`(gpt-5.2/-codex 后缀会 400 拒)。
- **Gemini 3 Pro(agy / Antigravity CLI)**:Google 族第三意见,$20 Gemini 会员桶。非交互调用:`agy -p "<自包含 prompt>" --model gemini-3-pro-high --print-timeout 8m 2>&1 | tail -200`。
  - `-p` = 单轮 print 非交互;`--model gemini-3-pro-high`(深推理档,规划/审查用);默认 sandbox 即只读,**不传 `--dangerously-skip-permissions`**(它不写代码)。
  - 无状态,prompt 必须自包含;长推理可能 >5min,故 `--print-timeout 8m`。
  - **只读角色**:它从不写代码(那是 Codex 的活,防多 writer stomp)。

## Iron Rules(违反即破坏整条流水线)
1. **maker 不自评**:写代码的一方不给自己打分。Codex 写的代码由 Claude 审(步④),再由独立 Codex 二审(步⑤)。
2. **VERDICT 闸门**:每个 review 必须以可解析判词结尾,驱动循环进/退。
3. **循环有预算**:每个循环 ≤5 轮;到顶不收敛 → 记 `[需人工]` 停手,带摘要,**绝不谎称一致/通过**。
4. **状态落盘**:所有产物写进工作目录,中断可恢复(Cardinal Rule 3)。
5. **循环内禁不可逆**:循环里不 push/merge/删数据/发外部;这些留到最终报告后由 Tony 拍板。
6. **验证用证据**:最终"无问题"必须有可执行证据(测试/构建/smoke),没有自动 verifier 就显式标"需人工确认",不默认绿。

## 步骤 0:初始化工作目录(落盘)
```bash
TS=$(date +%Y%m%d-%H%M%S); SLUG=$(echo "<任务关键词>" | tr ' /' '--' | cut -c1-30)
WORK=".omc/cc/${SLUG}-${TS}"; mkdir -p "$WORK"
```
建 ledger `$WORK/ledger.md`,写 DoD(Must / Won't / 验收命令 / 停止条件)+ 5 步勾选项。每步完成即勾 `[x]`,失败 `[!]`。

---

## 步骤 ①:Claude + GPT-5.5 Pro + Gemini 3 Pro 三方并行规划(各自独立,不互相看)
目标:对同一任务,拿到**三份独立**的方案+任务拆解+步骤(Anthropic / OpenAI / Google 三族)。独立性是关键——别让一方影响另一方。

1. **先发两个慢的外部模型**(它们各跑 1–5 min,先发好让它们并行后台跑),prompt 都要自包含(任务、约束、相关文件摘要、要它产出:方案/任务拆解/分步计划/风险):
   ```bash
   gpt5pro "我要做:<任务>。约束:<...>。相关现状:<本地代码摘要>。请给出:1)总体方案 2)任务拆解 3)分步执行计划 4)主要风险。" > "$WORK/plan-gpt5pro.md"
   agy -p "我要做:<任务>。约束:<...>。相关现状:<本地代码摘要/可直接读 repo>。请给出:1)总体方案 2)任务拆解 3)分步执行计划 4)主要风险。" --model gemini-3-pro-high --print-timeout 8m 2>&1 | tail -300 > "$WORK/plan-gemini.md"
   ```
   (报一行进度:"GPT-5.5 Pro + Gemini 3 Pro 并行规划中,约 1–5 分钟"。**Gemini 的甜区:让它读整个 repo**——必要时加 `--add-dir <项目根>` 喂全量代码,而 Claude/GPT 更偏抽象规划。)
2. **同时** Claude 自己独立写一份:方案 / 任务拆解 / 步骤 / 风险 → `$WORK/plan-claude.md`。**先写完自己的再读另两份**,保独立。
3. 三份都就绪后勾 `[x] 步①`。任一外部模型失败按"失败与恢复"处理:重试 1 次仍失败则记 `UNKNOWN`,**用剩余两份继续**(不阻塞整条流水线)。

## 步骤 ②:Codex 整合挑刺 + Claude↔Codex 反复 review 到一致(循环 1,≤5 轮)
目标:产出**一份双方都认可的定稿计划** `$WORK/plan-final.md`。

- **Trigger**:三份计划就绪(失败降级则用就绪的那几份)。
- **每轮 Work**:
  1. 把当前计划交 Codex 整合 + 挑刺(首轮喂三份原始计划;次轮起喂 `plan-final.md` 草稿):
     ```bash
     codex exec "你是资深架构评审。整合并批判下面的计划(来自 Claude/GPT-5.5 Pro/Gemini 三族),找漏洞/缺步骤/风险/不一致,尤其关注三份的分歧点。给出整合后的改进版 + 问题清单(file/步骤级)。结尾必须是恰好一行:VERDICT: CONSENSUS 或 VERDICT: REVISE。\n\n=== 计划 ===\n$(cat \"$WORK/plan-final.md\" 2>/dev/null || cat \"$WORK/plan-claude.md\" \"$WORK/plan-gpt5pro.md\" \"$WORK/plan-gemini.md\" 2>/dev/null)" -m gpt-5.5 -s read-only 2>&1 | tail -250 | tee "$WORK/consensus-round-N-codex.md"
     ```
  2. **Claude 评估 Codex 的批评**(receiving-code-review 纪律:先验证对不对,不盲从)。采纳合理项、驳回不成立项(写明理由),更新 `$WORK/plan-final.md`。
  3. 记录本轮到 `$WORK/consensus-log.md`(轮次/Codex 判词/Claude 取舍)。
- **Verify / Exit**:Codex 给 `VERDICT: CONSENSUS` **且** Claude 也认可定稿 = 一致 → 退出循环。
- **Budget**:≤5 轮。到顶仍 REVISE → 把剩余分歧写进 `plan-final.md` 的"未决分歧"节,标 `[需人工]`,带着定稿继续(或按 Tony 指示停)。
- 勾 `[x] 步②`,定稿 = `$WORK/plan-final.md`。

## 步骤 ③:Codex 按定稿执行代码
- 把 `plan-final.md` 交 Codex 执行(写权限)。大改/并行建议 worktree 隔离防 stomp;主工作区直接改时确认 scope 清晰。
  ```bash
  codex exec "严格按下面定稿计划实现,不要自行扩 scope。每完成一步简述改了什么。\n\n$(cat \"$WORK/plan-final.md\")" -m gpt-5.5 -s workspace-write 2>&1 | tail -300 | tee "$WORK/exec-codex.md"
  ```
- 执行完收集改动:`git --no-pager diff > "$WORK/diff.patch"`。
- 勾 `[x] 步③`。

## 步骤 ④:Claude code review(maker/checker 第一道)
- Claude 亲自审 Codex 的 diff:正确性、边界、回归、bug、是否符合定稿意图、测试是否够。结果 → `$WORK/review-claude.md`,每条带 file:line + 严重度。
- 发现问题 → 交 Codex 修(`codex exec ... -s workspace-write`),修完 Claude 复审。此小循环 ≤3 轮。
- Claude 侧无 High/Critical 遗留 → 勾 `[x] 步④`。

## 步骤 ⑤:Codex 隔离 sub-agent 二次审查(循环 2,≤5 轮)+ 最终报告
目标:**独立干净上下文**再审一遍,直到各独立审查方都无问题(routine:Claude + Codex 两方;高风险:再加 Gemini = 三方)。

- **每轮 Work**:全新 codex 会话(隔离),只喂 diff + 定稿,不喂前面的讨论:
  ```bash
  git --no-pager diff > "$WORK/diff.patch"
  codex exec "你是独立第二审查员,无任何前序上下文。仅依据【定稿计划】和【diff】对抗式审查:找 bug/安全/边界/与计划不符。给问题清单(file:line+严重度)。结尾恰好一行:VERDICT: APPROVED 或 VERDICT: ISSUES_FOUND。\n\n=== 定稿 ===\n$(cat \"$WORK/plan-final.md\")\n\n=== diff ===\n$(cat \"$WORK/diff.patch\")" -m gpt-5.5 -s read-only 2>&1 | tail -250 | tee "$WORK/isolated-review-round-N.md"
  ```
- **高风险任务加 Gemini 第三审(可选)**:当任务触及**安全/认证/支付/数据库/文件系统/网络**,或改动 >80 行,或产出公开资产时,本轮额外跑一个 Google 族独立审,与 Codex 隔离审形成**三族交叉**:
  ```bash
  agy -p "你是独立第三审查员,无任何前序上下文。仅依据【定稿计划】和【diff】对抗式审查:找 bug/安全/边界/与计划不符。给问题清单(file:line+严重度)。结尾恰好一行:VERDICT: APPROVED 或 VERDICT: ISSUES_FOUND。\n\n=== 定稿 ===\n$(cat \"$WORK/plan-final.md\")\n\n=== diff ===\n$(cat \"$WORK/diff.patch\")" --model gemini-3-pro-high --print-timeout 8m 2>&1 | tail -250 | tee "$WORK/isolated-review-round-N-gemini.md"
  ```
  routine(低风险)任务**不加**,Codex 单审即可——避免声音过多反而加剧"幻觉共识"。
- **Claude 处理**:对每个被报问题,Claude 独立判定是否真 issue(分歧处=重点)。真 issue → 交 Codex 修 → 回到本轮重审。
- **Verify / Exit**:
  - routine:Codex 隔离审 `VERDICT: APPROVED` **且** Claude 确认无遗留 → 退出。
  - 高风险:**2-of-3 族多数票**——Claude + Codex + Gemini 三族,至少 2 票 APPROVED 且无 High/Critical 遗留才退出;任一族报 High/Critical 且经 Claude 判定属实 → 必修后重审。
- **Budget**:≤5 轮;到顶仍 ISSUES_FOUND → 列残留 + `[需人工]`,不谎称通过。
- **可执行验证**:跑项目测试/构建/lint(有则),证据写进报告;无 verifier 显式标"需人工确认"。

### 最终报告 → `$WORK/final-report.md`(也回贴给 Tony,简洁)
包含:任务 / 定稿计划要点 / 一致达成轮次 / 改了哪些文件 / Claude 审 + Codex 隔离审结论(高风险含 Gemini 三审 + 2/3 多数票结果)/ 可执行验证证据 / 残留 `[需人工]`(若有) / 下一步(push/merge 由 Tony 决定,**流水线内不做**)。

---

## 失败与恢复
- 任一 `gpt5pro`/`codex`/`agy` 调用失败:重试 1 次,仍失败记 `UNKNOWN` **不当成功**。
  - 规划 ①:外部模型失败 **不阻塞**——用就绪的那几份继续(至少要有 Claude 自己那份 + 一个外部族)。
  - 审查 ⑤:Codex 失败则该轮无法判定,记 `UNKNOWN` 停手等修;Gemini(可选三审)失败则降级为 routine 单审,不阻塞。
  - `gpt5pro` 报 `session=no` → 提示 Tony 在 bb-browser 的 Chrome 登录 ChatGPT Pro。
  - `agy` 报需登录("Please sign in") → 提示 Tony 跑一次裸 `agy` 交互登录 Google/Gemini 账号。
- 中断恢复:新会话读 `$WORK/ledger.md`,跳过 `[x]`,从断点续。
- 轮次计数靠 ledger 落盘强制,不靠记忆。

## 何时用 / 不用
- **用**:有把握要求高、值得跨模型族互审的编码任务(架构落地、关键模块、易错重构)。
- **不用**:一行小改、纯查询、机械批量 —— 直接做,别为仪式感跑五步烧多份额度。

分工背景见 memory `reference_claude-codex-collab-protocol`、`reference_gpt5pro-bridge`;Codex 细节见 `reference_codex-exec-resume-flags`、`reference_codex-mcp-chatgpt-account-model`。
