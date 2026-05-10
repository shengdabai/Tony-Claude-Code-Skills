# OPC 一人企业方法论 Skills

Easy（@easychen）的《一人企业方法论 2.1》配套 9 个 Claude Code skills,已全局软链到 `~/.claude/skills/opc-*`。
源位置：`~/Desktop/项目开发/01-Claude生态/Tony-Claude-Code-Skills/opc-methodology/`(已并入 Tony-CCS 主仓,与 Easy 上游脱钩,需要时手工 diff 同步)。

## Skills 清单

| Skill | 阶段 | 触发场景 |
|-------|------|----------|
| `opc-orchestrator` | 总编排 | 入口,串起整套流程,自动判断阶段+模式 |
| `opc-resource-audit` | 01 资源盘点 | 8 类资源逐项确认 |
| `opc-niche-positioning` | 02 利基定位 | 三环合一 + 六维评分找细分入口 |
| `opc-value-proposition` | 03 价值主张 | Jobs/Pains/Gains 拆解 |
| `opc-business-model-design` | 04 商业模式 | Lean Canvas + 高风险假设 |
| `opc-mvp-designer` | 06 MVP 设计 | 最小验证假设和形式 |
| `opc-conversion-loop` | 07 转化闭环 | 触达→承接→成交路径 |
| `opc-asset-ops` | 08 资产沉淀 | 重复成果系统化 |
| `opc-dashboard-review` | 09 经营复盘 | 运营卡住找瓶颈 |

## 触发关键词(自动推荐 `/opc-orchestrator`)

- "一人企业"/"OPC"/"方法论复盘"/"创业方法论"
- "利基"/"定位"/"细分市场"
- "价值主张"/"商业模式"/"Lean Canvas"/"精益画布"
- "MVP 设计"/"最小验证"
- "转化漏斗"/"获客闭环"
- "经营复盘"/"运营瓶颈"

匹配上述关键词时,主动推荐:
> 检测到 OPC 方法论场景,可用 `/opc-orchestrator` 启动总编排(会自动恢复 `opc-doc/` 中的进度),
> 或直接 `/opc-niche-positioning` 等切入特定阶段。

## 与 OMC plan workflow 的互补关系

| 维度 | OMC `.omc/plans/` | OPC `opc-doc/` |
|------|-------------------|----------------|
| 解决的问题 | 任务执行可恢复(写代码/重构/批量操作) | 商业策略可恢复(定位/商业模式/复盘) |
| ledger 内容 | TODO 清单 + `[x]/[ ]/[!]` 状态 | 阶段结论文件 + state JSON |
| 触发条件 | ≥5 任务或 ≥30 分钟工作 | 一人企业策略思考 |
| 可同时使用 | ✅ 互不冲突,两层 ledger 并存 | ✅ |

**典型搭配**:用 `/opc-mvp-designer` 设计完 MVP,把"实现 MVP"作为大任务交给 `.omc/plans/mvp-build-todo.md` ledger 执行。

## 项目集成约定

- 每个使用 OPC 方法论的子项目,在该项目根目录建独立 `opc-doc/`(state/inputs/outputs/reviews)
- **不主动创建** `opc-doc/`:仅当用户在某项目里明确说"用 OPC 跑这个项目"或调用 `/opc-orchestrator` 时,才在当前项目根创建
- 各项目 `opc-doc/` 互不串台,跨项目策略勿混合

## 设计哲学要点(协作时遵守)

- **共创式问询**:默认一次只问一个问题;重要决策给 `A/B/C/4. 我有自己的方案`
- **只给分析不给推荐**:每个方案说明适合什么情况、优点、代价,由用户决策
- **强制阶段边界**:每个 skill 只做自己阶段的事,不滑入下一阶段
- **会话恢复**:每次新会话先读 `opc-doc/state/current-stage.json`,再问问题
- **轮次收口**:第 5 轮提醒收口,第 9 轮强制总结,第 10 轮默认完成阶段

## 更新方式

源已并入 Tony-CCS 主仓(`shengdabai/Tony-Claude-Code-Skills`),不再跟 Easy 上游 git。
要同步上游变更:手工对照 `https://github.com/easychen/opc-methodology/tree/main/skills` diff,
然后在本地编辑 `Tony-CCS/opc-methodology/skills/` 下的对应文件。软链不需重建。
