---
description: 大任务先建可恢复 ledger。命中条件：≥5 个独立文件或子任务、预计 ≥30 分钟、多轮 sub-agent、用户说 audit/批量/全部/所有。
---

# Session Resilience: Plan-Then-Execute

## Iron Law: 大任务先建可恢复 ledger
usage limit / API 失败 / 上下文压缩都会中断会话。触发条件(任一):≥5 个独立文件/repo/子任务、预计 ≥30 分钟、多轮 sub-agent 调度、用户说 "audit"/"批量"/"全部"/"所有"。

**Plan(cheap)**:扫描范围识别 work item → 写 `.omc/plans/<task>-todo.md`,顶部先写 DoD 契约(Must 1-3 条 / Won't 防 scope 漂移 / 一条可执行验收命令 / 停止条件),再列 `- [ ] item-N: <对象> — <动作>`。收口纪律:验收命令通过 + Must 全勾 = 完成立即交付,「还可以更好」不构成继续理由。

**Execute**:每完成一项立即改 `[x]` 并保存;每批最多 3-5 项;失败标 `[!]` 写明原因,不阻塞后续项。

**Resume**:新会话第一步读 ledger,报告「共 N 项,已完成 M,从 item-X 继续」;不重做已完成项,不重新规划。

**Sub-agent 扇出**:每个 sub-agent 写结构化报告到文件,只返回 3 行摘要防 context 爆炸;先返回 finding 经审批再 fix,不让 sub-agent 直接修复。

**防过度**:≤5 项小任务直接做;用户已给清晰 todo 列表的不再另建;一次性命令(git push / build)不需要 ledger。
