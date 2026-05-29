---
description: Spec-Driven Trio 入口 — OpenSpec /opsx:propose + Superpowers + Agent-Skills 三件套协同启动
---

# /spec — Spec-Driven Trio 入口

用户在对话中输入 `/spec` 或 `/spec <feature 描述>`,你要做的事:

## 1. 判断项目状态

```bash
test -d openspec && echo "SDD-ready" || echo "not-init"
```

- **SDD-ready** → 直接进 Phase 2
- **not-init** → 先告诉用户项目还没 init,问要不要现在跑 `openspec init`(默认建议:跑)
  - 用户同意 → 执行 `openspec init`,然后进 Phase 2
  - 用户拒绝 → 退回 ad-hoc 模式,只走 superpowers + agent-skills(无 spec 工件)

## 2. 启动三件套流程

### Phase A: 产规格(OpenSpec 层)
执行 `/opsx:propose <feature>` 生成:
- `openspec/changes/<change-name>/proposal.md`
- `openspec/changes/<change-name>/specs/`
- `openspec/changes/<change-name>/design.md`
- `openspec/changes/<change-name>/tasks.md`

### Phase B: 收敛思路(Superpowers 层)
调 superpowers 的 skill:
- `superpowers:brainstorming` — 对 proposal 做发散 + 收敛
- `superpowers:writing-plans` — 把 tasks.md 转成可执行 plan

### Phase C: 横向规范预热(Agent-Skills 层)
按改动类型自动加载对应 skill:
- API/接口相关 → `api-and-interface-design`
- 安全相关 → `security-and-hardening` + `doubt-driven-development`
- UI/前端 → `frontend-ui-engineering`
- 性能相关 → `performance-optimization`

### Phase D: 执行(每个 task 内部)
- `superpowers:test-driven-development` — 红绿循环
- `superpowers:executing-plans` — 按步推进
- `agent-skills:code-simplification` — 收敛代码

### Phase E: 完成前验证
- `superpowers:verification-before-completion` — 证据而非声明
- `agent-skills:code-review-and-quality` — 多维度审查
- `superpowers:requesting-code-review` — 请审

### Phase F: 归档
执行 `/opsx:archive` — change 入库,specs 更新

## 3. 重要约束

- **不要替用户跳过 Phase A**,即使 feature 看起来很小 —— 这是三件套的核心价值
- 如果用户在 `/spec` 后接了 feature 描述(`/spec add dark mode`),把描述直接传给 `/opsx:propose`
- 如果只输了 `/spec` 没接描述,问用户要 feature 描述(这是少数允许打断的场景之一,因为没描述没法 propose)
- 全程不暂停问"要不要继续"—— 每个 phase 衔接处直接走
- 完整规则在 `~/.claude/rules/spec-driven-trio.md`

## 4. 等价的裸词触发

如果用户说 "spec"/"写 spec"/"write spec"/"提案"/"propose this"/"先做规格" 等同义触发词,等同于调用本命令,走同样的 Phase A-F 流程。详见 `rules/spec-driven-trio.md` 的"裸词触发"节。
