---
description: 循环单轮：盯自己的 open PR——CI 红了修、comment 来了改（套 /loop 10m 变循环）
argument-hint: [仓库路径或 owner/repo，默认当前目录]
---

# Loop: Babysit PRs（盯 PR）

loop engineering 循环体（规范见 `~/.claude/rules/loop-engineering.md`）。执行**一轮**：

## 五要素
- Trigger: 被调用即跑一轮（推荐 `/loop 10m /loops:babysit-prs`）
- Work: 处理一个最紧急的 PR 问题（CI 失败 > 待回复 review comment）
- Verify: `gh pr checks <num>` 全 pass 且无未回复 comment
- Exit: 所有自己的 open PR 都绿且无待办 comment → 报告"✅ 全部健康，循环可停"
- Budget: 单 PR 同一 CI 失败连修 3 次 → 标记 `[需人工]`，跳到下一个 PR

## 本轮流程
1. `gh pr list --author @me --state open`（$ARGUMENTS 指定了 repo 则加 `-R`）；无 open PR → 报告"无 PR，循环可停"
2. 逐个 `gh pr checks` + `gh pr view --comments`，按"CI 红 > 新 comment > 全绿"排序
3. 取最紧急的一个：
   - **CI 红**：拉日志找 root cause，在 worktree 里修（不污染当前工作区），修完跑本地等价检查再 push 到该 PR 分支
   - **新 review comment**：逐条评估（receiving-code-review 纪律：先验证对不对，不盲从），合理的改并回复，不合理的礼貌说明理由
4. 追加日志 `.omc/logs/loop-babysit-prs.log`：`<时间> | PR#<num> <动作> | <结果>`
5. 报告：处理了哪个 PR、做了什么、还剩几个待处理（≤ 3 行）

## 禁止（循环内不可逆操作红线）
- **禁止 merge PR**、禁止 close PR、禁止 force-push —— 这些标记 `[需人工]` 等 Tony 确认
- 修 CI 时禁止删测试/skip 测试求绿
