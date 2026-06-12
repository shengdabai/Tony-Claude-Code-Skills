---
description: 循环单轮：清 .omc/plans/ 未完成 ledger，一轮一批（≤3 项）；套 /loop 或定时跑变循环
argument-hint: [ledger 文件名，默认自动选最旧的含 [ ] 的 ledger]
---

# Loop: Ledger Drain（清账本）

loop engineering 循环体（规范见 `~/.claude/rules/loop-engineering.md`）。执行**一轮**：

## 五要素
- Trigger: 被调用即跑一轮（推荐每天定时一轮，或会话空闲时手动 `/loops:ledger-drain`）
- Work: 从 ledger 取最多 3 个 `[ ]` 项执行
- Verify: 每项按该 ledger 顶部 Definition of Done 的验收命令验证；没有 DoD 的项用 read-back + smoke test
- Exit: 该 ledger 全部 `[x]`/`[!]` → 报告"✅ <ledger> 清完"；所有 ledger 都清完 → "循环可停"
- Budget: 一轮 ≤ 3 项；某项失败 → 标 `[!]` + 原因，不阻塞下一项；同项失败过的不重试，留给人工

## 本轮流程
1. 定位 ledger：$ARGUMENTS 指定则用之；否则扫 `.omc/plans/*-todo.md`（含全局 `~/.omc/plans/`），跳过 `_template.md`，选最旧的仍含 `[ ]` 的文件
2. 读 ledger 顶部 DoD（Must / Won't / 验收命令 / 停止条件），严格按它收口——"还可以更好"不构成继续理由
3. 依次执行 ≤ 3 个 `[ ]` 项：做完一项立即改 `[x]` 落盘（中断可恢复），失败标 `[!]` 写明原因
4. 报告：本轮完成 N 项 / 失败 M 项 / 该 ledger 剩 K 项（≤ 3 行）

## 禁止
- 重做已 `[x]` 项、重新规划整个 ledger（只执行，不推翻）
- 执行 ledger 里标了 `[需人工]` 或涉及不可逆/外发的项（push 公开仓、发消息、删数据）——留给 Tony
- 超过 3 项不收手（防一轮吃掉整个 context）
