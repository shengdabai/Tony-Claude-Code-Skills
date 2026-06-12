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

## Constitution Gate(propose 阶段治理约束)

> 提炼自 GitHub spec-kit 的 constitution 治理思路,白嫖其精华而**不引入第二套工具**。
> 核心 = **少量不可变原则 + 阶段门禁 + 显式豁免论证**。OpenSpec 本身没有这层,这里补上。

### 三条治理机制(propose 时强制)

1. **不可变原则集**:下方 5 条核心原则是项目宪法,所有 proposal 默认遵守,不逐项重新讨论。
2. **阶段门禁(phase gate)**:proposal 的 `## Constitution Check` 没全部勾选 → **不得进入 `/opsx:apply`**。
3. **显式豁免**:任何违反必须在 proposal 里写明「为什么必须违反 + 更简方案为何不够」;无法论证就回去改设计,而不是放行。

### 5 条核心原则(对照清单)

- **简洁优先**:不为"将来可能用到"提前引入抽象/依赖/分层;现有能力够用就不新建。
- **测试先行**:每个新 capability 的验收标准能写成测试(TDD 可落地),并在 tasks 中标注。
- **接口契约稳定**:对外 API / 模块边界变更显式列入 `## Impact`,无隐式 breaking change。
- **安全默认**:输入/认证/存储/外部集成有对应硬化项;密钥/PII 绝不写进工件(配合 secrets-firewall)。
- **可逆可观测**:破坏性/不可逆操作有回滚或迁移路径;关键行为有日志或验证点。

### 落地方式

- **权威源 = 本节**(持久、全局、不被 npm 升级冲掉)。
- **即时模板**:已把对应 `## Constitution Check` 章节追加进 OpenSpec 包内 `schemas/spec-driven/templates/proposal.md`,下次 `openspec` 生成 proposal 自动带上。
- ⚠️ **包模板会被 `npm update @fission-ai/openspec` 覆盖**。升级后若该章节丢失,从下方模板块复制回包模板即可:

```markdown
## Constitution Check

<!-- 治理门禁(提炼自 spec-kit constitution)。propose 阶段逐条过,违反项不得进入 apply。 -->

### 核心原则对照
- [ ] 简洁优先:未为"将来可能用到"引入抽象/依赖/分层
- [ ] 测试先行:每个新 capability 的验收标准可写成测试,已在 tasks 标注
- [ ] 接口契约稳定:对外 API/模块边界变更已列入 Impact,无隐式 breaking change
- [ ] 安全默认:输入/认证/存储/外部集成有硬化项,未把密钥/PII 写进工件
- [ ] 可逆可观测:破坏性/不可逆操作有回滚或迁移路径;关键行为有日志/验证点

### 违反与豁免(Complexity Tracking)
<!-- 任一未勾选 = 违反。论证「为什么必须违反 + 更简方案为何不够」,否则回去改设计。 -->
- 违反项:<原则> — 必须违反的理由:<...> — 已排除的更简方案:<...>
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

## 触发关键词清单

### 强触发(等同 /spec 命令,直接进 Phase A-F)

听到以下任一,**立刻**走 `/spec` 命令同款流程(详见 `~/.claude/commands/spec.md`):
- `/spec`(slash 命令)
- "spec"(裸词,需上下文是"做某功能",纯讨论 spec 概念不触发)
- "写 spec"/"做 spec"/"起 spec"
- "write spec"/"write a spec"
- "propose this"/"提案"/"先做规格"/"先出规格"
- "spec-driven"/"SDD this"

### 弱触发(先问用户要不要启 SDD)

听到以下,先用一句话问"这次要走 SDD 流程吗?默认 yes":
- "我想做一个新功能 X"
- "帮我规划一下 Y"
- "这个项目要重构 X"
- 提到 `/opsx` 但没说具体哪个 subcommand

用户回 yes → 进 Phase A-F;用户回 no → ad-hoc 模式

### 非触发(不要误启 SDD)

以下情况**不要**当 SDD 触发:
- "这个 spec 是什么意思"/"解释一下 spec"(纯概念讨论)
- "看看 openspec/ 目录"(只查看不动手)
- "spec 写完了"(已完成态)
- 用户在调试 bug / 改文档 / 写脚本,即便说了 "spec"

判据:**用户是不是在说"我现在要开始做一个新东西"** —— 是 → 触发,否 → 不触发

## 关于裸词 "spec" 的歧义

"spec" 单词太短,容易误触。判断规则:
1. 用户消息只有 "spec" 一个字 → 问"你是想启动 SDD 流程吗?如果是,告诉我做什么功能"
2. "spec 这个 feature" / "写 spec for X" → 强触发
3. "openspec / OpenSpec" 词面出现 → 看上下文,讨论工具不触发,讨论"用它做事"才触发

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
