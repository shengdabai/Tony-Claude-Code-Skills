# Spec-Driven Trio: OpenSpec + Superpowers + Agent-Skills

## 三件套定位

| 角色 | 工具 | 触发 |
|------|------|------|
| **记忆与规格层** | OpenSpec(`/opsx:*` + `openspec` CLI) | 项目根有 `openspec/` 目录,或用户说 "写 spec"/"propose"/"先规划" |
| **执行与纪律层** | Superpowers(`superpowers:*` skills,v5.1.0) | 任何动手前(brainstorm → plan → TDD → verify),superpowers:using-superpowers 在会话起点已自动加载 |
| **大厂代码标准层** | Agent-Skills(addyosmani/agent-skills 23 个 skill) | 代码相关的横向规范:`code-review-and-quality`、`api-and-interface-design`、`security-and-hardening`、`performance-optimization` 等 |

## Iron Law: 三层分工不串台

- OpenSpec **不写代码**,只产 proposal / specs / design / tasks(markdown 工件)
- Superpowers **不定规范**,只管"怎么动手才不出错"(TDD / 验证 / 增量 / 分发)
- Agent-Skills **不管流程**,只提供"代码该长什么样"(API 形态、安全、性能、可维护性)

三层**叠加生效**,不互相覆盖。

## 自动检测协议(全局生效)

### 项目级检测(动手前先扫)
进任意目录开始工作前,先扫一眼:

```bash
test -d openspec && echo "spec-driven" || echo "ad-hoc"
```

- **检测到 `openspec/`** → 进入 SDD 模式:任何新功能/重构必须先走 `/opsx:propose`,不要直接动代码
- **没有 `openspec/`** → ad-hoc 模式,按 superpowers 的 brainstorming → planning → TDD 流程走,但**不强制**生成 spec 工件
- **用户明确说 "写 spec"/"先规划"/"propose"** → 即便没 openspec/ 目录,也建议先 `cd <project> && openspec init`

### 任务级检测(决定调哪些 skill)

| 任务类型 | OpenSpec | Superpowers | Agent-Skills |
|---------|----------|-------------|--------------|
| 新功能开发 | `/opsx:propose` → `/opsx:apply` | brainstorming + writing-plans + TDD | api-and-interface-design + frontend-ui-engineering |
| Bug 修复 | (跳过,小改不立 spec) | systematic-debugging + TDD | debugging-and-error-recovery |
| 重构 | `/opsx:propose` 标注 breaking | incremental-implementation + TDD | code-simplification + code-review-and-quality |
| 安全相关 | `/opsx:propose` 强制 design.md | verification-before-completion | security-and-hardening + doubt-driven-development |
| API 设计 | `/opsx:propose` 强制 specs/ | writing-plans | api-and-interface-design |
| 性能优化 | (按情况) | systematic-debugging | performance-optimization |
| Pre-merge | (跳过) | requesting-code-review | code-review-and-quality |
| 发布上线 | `/opsx:archive` | finishing-a-development-branch | shipping-and-launch + ci-cd-and-automation |

## SDD 项目工作流(检测到 openspec/ 后默认)

```
用户描述需求
  ↓
/opsx:propose <feature>          ← OpenSpec 生成 proposal/specs/design/tasks
  ↓
[superpowers:brainstorming]      ← 对 proposal 做发散+收敛
  ↓
[superpowers:writing-plans]      ← 把 tasks.md 转成可执行 plan
  ↓
[agent-skills:api-and-interface-design] ← API/接口形态评审 (如涉及)
  ↓
/opsx:apply                       ← 按 tasks 执行,每个 task 用 TDD
  ↓ (每个 task 内部)
  [superpowers:test-driven-development] → 写测试
  [superpowers:executing-plans]          → 实施
  [agent-skills:code-simplification]     → 收敛
  ↓
[superpowers:verification-before-completion] ← 完成前验证
  ↓
[agent-skills:code-review-and-quality]       ← 多维度审查
  ↓
[superpowers:requesting-code-review]         ← 请审
  ↓
/opsx:archive                     ← 归档 change,specs 入库
```

## Ad-hoc 项目工作流(无 openspec/)

```
用户描述需求
  ↓
[superpowers:brainstorming]      ← 发散+收敛
  ↓
[superpowers:writing-plans]      ← 写 .omc/plans/*-todo.md
  ↓
[agent-skills:相关 skill]         ← 横向规范预热
  ↓
[superpowers:executing-plans + TDD]
  ↓
[superpowers:verification-before-completion]
  ↓
[agent-skills:code-review-and-quality]
```

## 触发关键词清单(主动建议用户启 OpenSpec)

听到以下任一,先问用户要不要 `openspec init`:
- "我想做一个新功能 X"
- "帮我规划一下 Y"
- "这个项目要重构"
- "想做 spec"/"写 spec"
- "/opsx" 字面提到

## Anti-Pattern(三层混淆)

- ❌ 跳过 OpenSpec 直接动代码(SDD 项目里),理由是 "我看 spec 我都懂了"
- ❌ 用 OpenSpec 当代码生成器(它只产 markdown,代码归 superpowers + agent-skills)
- ❌ 用 superpowers 的 brainstorming 取代 `/opsx:propose`(brainstorming 输出对话纪要,不是工件)
- ❌ 直接套 agent-skills 而跳过 superpowers 的纪律层(skill 是规范,纪律是执行,缺一不可)

## 与 Cardinal Rules 的关系

- 不替换 Cardinal Rule 1 字面执行 — 用户没说要 spec 就别强塞
- 配合 Cardinal Rule 3 plan-then-execute — OpenSpec 的 `tasks.md` 就是天然的 SDD 版 ledger,但 `.omc/plans/` 仍负责中断恢复
- 配合 Cardinal Rule 2 验证再声明完成 — superpowers:verification-before-completion + agent-skills 的 code-review-and-quality 是双层验证

## 检测命令速查

```bash
# 项目是否 SDD 化
test -d openspec && echo SDD || echo ad-hoc

# OpenSpec 是否已装(全局)
which openspec && openspec --version

# 当前 change 列表
openspec list

# 当前 spec 列表
openspec list --specs

# 看某个 change 详情
openspec show <change-name>
```
