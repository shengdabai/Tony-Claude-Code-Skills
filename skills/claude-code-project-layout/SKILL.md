---
name: claude-code-project-layout
description: Use when initializing a new Claude Code project, auditing an existing project's `.claude/` directory structure, scaffolding CLAUDE.md / settings.json / hooks / agents / skills / plugins / output-styles / rules, or whenever the user asks about Claude Code project conventions, file layout standards, or "标准目录结构".
---

# Claude Code Project Layout — 标准目录结构与配置规范

## Overview

本 skill 是 Claude Code 项目的**标准目录结构与文件职责权威清单**。任何新建项目、检查现有项目、生成脚手架时都必须照此执行。

核心原则:
1. **CLAUDE.md ≤ 200 行**:超出必须拆到 `rules/` 或 `skills/`
2. **个人配置 gitignored**:`CLAUDE.local.md` 与 `settings.local.json` 永远不入仓库
3. **机密文件零信任**:`.env*` / 密钥文件由 PreToolUse hook 硬阻断
4. **职责单一**:每个目录只负责一件事,不混用

## When to Use

**触发场景**:
- 用户说 "新建一个 Claude Code 项目" / "scaffold 一个项目"
- 用户说 "检查我的 .claude 目录结构" / "审查项目配置"
- 用户提到 "项目应该怎么组织" / "标准目录结构" / "CLAUDE.md 怎么写"
- 用户要求 "添加 hook" / "加自定义命令" / "加 skill" / "加 agent"
- 用户问 "我的 CLAUDE.md 太长了怎么办"
- 任何涉及 `.claude/` 目录下文件创建、修改、审计的任务

**不适用**:
- 修改具体业务代码(本 skill 只管配置层)
- 全局 `~/.claude/` 配置(本 skill 针对项目级 `.claude/`,但结构同构)

## 项目根目录标准布局

```
your-project/
├── CLAUDE.md              # 项目规则文件,≤ 200 行
├── CLAUDE.local.md        # 个人自定义配置,gitignored
├── .gitignore             # 规定哪些文件不应被 Claude 读取
├── .mcp.json              # MCP 配置,必须放在根目录
└── .claude/               # Claude 寻找项目上下文时优先级最高的地方
    ├── hooks/             # 脚本钩子,在特定时机一定会触发
    │   ├── PostToolUse.sh     # 在工具使用后自动执行
    │   ├── SessionStart.sh    # 启动会话时加载项目上下文
    │   └── PreCompact.sh      # 在上下文压缩前保存状态
    ├── commands/          # 用于自定义快捷命令
    │   └── ship.md            # 例:一键完成构建、代码检查和部署
    ├── skills/            # 存放模型可以随时调用的具体 skill
    │   ├── carousel/          # 例:自动生成社媒插图/轮播图的 skill
    │   └── drill/             # 例:生成练习或训练教程的 skill
    ├── agents/            # 子 agent 文件夹,每个都具有独立上下文窗口
    │   ├── code-reviewer.md   # 例:代码审查 agent
    │   ├── researcher.md      # 例:研究员 agent,负责抓取并整合网页信息
    │   └── log-analyzer.md    # 例:日志分析 agent,专门解析报错信息
    ├── output-styles/     # 定义 Claude 的回复风格
    │   └── terse.md           # 例:只给代码,不废话
    ├── plugins/           # 通过插件形式集成命令、代理和 MCP
    │   └── vercel/
    ├── rules/             # 局部规则,根据文件路径匹配加载
    │   └── api.md             # 仅当处理 API 相关目录时才加载的规则
    ├── statusline         # 命令行底部状态栏的显示配置
    ├── settings.json      # 权限设置、模型选择及钩子注册中心
    └── settings.local.json    # 本地个人偏好设置,gitignored
```

## 各文件/目录职责详解

### `CLAUDE.md`(项目根目录)

- **作用**:项目规则文件,Claude Code 启动时自动加载到每个会话上下文。
- **长度限制**:**≤ 200 行**。超出立即拆分:
  - 长尾业务规则 → `.claude/rules/<topic>.md`(用 `@rules/topic.md` 引用)
  - 可复用流程 → `.claude/skills/<skill-name>/SKILL.md`
  - 工具/命令清单 → `.claude/commands/<cmd>.md`
- **必含内容**:Cardinal Rules、tech stack、interaction preferences、引用块
- **可入仓库**:✅ 是,作为团队共识

### `CLAUDE.local.md`(项目根目录)

- **作用**:个人本地配置覆盖,优先级高于 CLAUDE.md
- **gitignored**:✅ 必须,**永远不入仓库**
- **典型内容**:本机绝对路径、个人偏好、临时调试开关、私有 SSH alias

### `.gitignore`(项目根目录)

- **作用**:同时是 git 忽略清单 + Claude 读取范围限制(配合工具白名单)
- **必含**:`CLAUDE.local.md`、`settings.local.json`、`.env*`、`*.bak`、各类缓存目录

### `.mcp.json`(项目根目录)

- **作用**:项目级 MCP server 配置,必须在根目录,`.claude/` 内不识别
- **格式**:与 `settings.json` 的 `mcpServers` 字段同构
- **可入仓库**:✅ 团队共享 MCP(如 Context7、GitHub),个人 token 走 env var

### `.claude/hooks/`

- **作用**:特定时机强制触发的 shell 脚本(不依赖模型自觉)
- **核心三件套**:
  - `PreToolUse.sh` / `PreToolUse.<matcher>.sh` — 工具调用前拦截(env-guard、secret-scan 必备)
  - `PostToolUse.sh` — 工具调用后处理(日志、缓存失效、二次扫描)
  - `SessionStart.sh` — 会话启动时注入项目上下文(env、git status、TODO)
  - `PreCompact.sh` — 上下文压缩前保存关键状态到磁盘
- **注册方式**:在 `settings.json` 的 `hooks` 字段绑定 matcher
- **退出码约定**:`0` 放行(可附 stderr 警告),`2` 阻断(stderr 作为拒绝原因)

### `.claude/commands/`

- **作用**:自定义 slash command,通过 `/<filename>` 触发
- **格式**:`<cmd>.md`,frontmatter + 命令模板
- **典型例子**:`/ship`(构建+检查+部署)、`/review`(diff 审查)、`/qa`(端到端 QA)
- **可入仓库**:✅ 团队共享工作流

### `.claude/skills/`

- **作用**:可被 Skill 工具按需加载的复用流程或参考资料
- **结构**:每个 skill 一个目录,内含 `SKILL.md`(必需)+ 支持文件
- **frontmatter**:`name` + `description`(以 "Use when..." 开头)
- **可入仓库**:✅ 通用 skill 团队共享,私人 skill 放 `~/.claude/skills/`

### `.claude/agents/`

- **作用**:子 agent 定义,每个 agent 有独立上下文窗口与工具集
- **格式**:`<agent-name>.md`,frontmatter 含 `description` + `tools`
- **典型 agent**:`code-reviewer`、`researcher`、`log-analyzer`、`executor`、`planner`
- **触发方式**:主 Claude 通过 Agent tool + `subagent_type` 派发

### `.claude/output-styles/`

- **作用**:回复风格模板,运行时切换
- **典型**:`terse.md`(极简,只给代码)、`tutor.md`(教学语气)、`pr-review.md`(评审格式)
- **切换**:`/output-style <name>`

### `.claude/plugins/`

- **作用**:打包的命令/agent/MCP 集合,通过 plugin manager 安装
- **不入仓库**:由 plugin manager 拉取,加 `.gitignore`

### `.claude/rules/`

- **作用**:**根据文件路径匹配加载**的局部规则,避免 CLAUDE.md 全量加载所有规则
- **触发机制**:Claude 编辑某路径时自动注入对应规则
- **典型用法**:
  - `api.md` — 仅 API 相关目录加载
  - `frontend.md` — 仅前端目录加载
  - `tests.md` — 仅测试目录加载
- **优势**:CLAUDE.md 保持精简,规则按需加载

### `.claude/statusline`

- **作用**:命令行底部状态栏配置(token 用量、模型、git 分支等)
- **格式**:可执行脚本,stdout 为状态栏文本

### `.claude/settings.json`

- **作用**:**权限 / 模型 / 钩子注册中心**,Claude Code 启动核心配置
- **关键字段**:
  - `permissions.allow` — Bash 命令白名单(避免每次确认)
  - `permissions.defaultMode` — `dontAsk` / `acceptEdits` / `default`
  - `hooks` — PreToolUse / PostToolUse / SessionStart / PreCompact 注册
  - `mcpServers` — MCP 配置(若不用 `.mcp.json` 单独文件)
  - `env` — 环境变量
- **可入仓库**:✅ 团队共享,但**敏感字段走 `settings.local.json`**

### `.claude/settings.local.json`

- **作用**:个人本地偏好,覆盖 `settings.json`
- **gitignored**:✅ 必须
- **典型内容**:个人 API key、本机路径、个人 hook 启用开关

## 创建新项目时的执行步骤

按顺序执行(用 TodoWrite 跟踪):

1. **根目录文件**:
   ```bash
   touch CLAUDE.md CLAUDE.local.md .gitignore .mcp.json
   ```
2. **`.claude/` 目录树**:
   ```bash
   mkdir -p .claude/{hooks,commands,skills,agents,output-styles,plugins,rules}
   touch .claude/{statusline,settings.json,settings.local.json}
   ```
3. **填入 `.gitignore` 必备项**:
   ```
   CLAUDE.local.md
   .claude/settings.local.json
   .claude/plugins/
   .env*
   *.bak
   *.bak.*
   ```
4. **写 `CLAUDE.md` 主文件**(≤ 200 行):
   - Cardinal Rules
   - Tech stack
   - Interaction preferences
   - `@rules/xxx.md` 引用
5. **写 `settings.json` 最小配置**:
   - `permissions.defaultMode`: `default`
   - `hooks.PreToolUse`: 注册 env-guard.sh(若有机密文件需求)
6. **创建必要 hook**:
   - `hooks/env-guard.sh`(机密文件防线,优先级 P0)
   - `hooks/secret-scan.sh`(写入后扫密钥,优先级 P1)

## 审计现有项目的检查清单

逐项核对:

- [ ] `CLAUDE.md` 存在且 ≤ 200 行(超了立即拆 rules)
- [ ] `CLAUDE.local.md` 存在(可空)且在 `.gitignore`
- [ ] `.gitignore` 包含 `CLAUDE.local.md` / `settings.local.json` / `.env*`
- [ ] `.mcp.json` 存在(若用 MCP)
- [ ] `.claude/hooks/` 至少有 PreToolUse 拦截 .env(env-guard.sh)
- [ ] `.claude/commands/` 含项目核心工作流命令(`ship` / `review` / `qa`)
- [ ] `.claude/skills/` 内每个 skill 都有 SKILL.md + 合规 frontmatter
- [ ] `.claude/agents/` 至少有 `code-reviewer` 与 `executor`
- [ ] `.claude/output-styles/` 至少有 `terse.md`
- [ ] `.claude/rules/` 按业务领域拆分(api / frontend / tests / data)
- [ ] `.claude/settings.json` 钩子全部注册,无悬空脚本
- [ ] `.claude/settings.local.json` 在 `.gitignore`

## 常见错误与修复

| 错误 | 后果 | 修复 |
|------|------|------|
| CLAUDE.md > 200 行 | Token 浪费,缓存命中率低 | 拆 `rules/`,主文件用 `@rules/x.md` 引用 |
| `.env` 没被 hook 拦截 | 模型可能读出 API key 进 jsonl | 加 `hooks/env-guard.sh` PreToolUse |
| 个人路径写进 `CLAUDE.md` | 团队成员每次冲突 | 挪到 `CLAUDE.local.md` |
| `settings.json` 写明文 token | 入仓库泄露 | 挪 `settings.local.json` 或 env var |
| 多个 hook 用同一 matcher 互相覆盖 | 行为不可预测 | 每个 matcher 唯一,串联用脚本内部链式调用 |
| `hooks/` 脚本无可执行权限 | 钩子静默失效 | `chmod +x .claude/hooks/*.sh` |
| `skills/<n>/` 没有 SKILL.md | Skill 工具找不到 | 必有 SKILL.md + frontmatter |
| `agents/<n>.md` 没有 description | Agent 无法被路由 | frontmatter 必填 description |

## 全局 vs 项目 配置优先级

```
~/.claude/CLAUDE.md          ← 全局基线,所有项目共享
↓ override
项目/CLAUDE.md               ← 项目共识
↓ override
项目/CLAUDE.local.md         ← 个人本地(gitignored)
↓
~/.claude/CLAUDE.local.md    ← 全局个人(gitignored)
```

设置同名键时,**越靠下越优先**。

## Quick Reference

| 想做的事 | 应该改哪个文件 |
|---------|--------------|
| 加全局规则(所有项目) | `~/.claude/CLAUDE.md` 或 `~/.claude/rules/` |
| 加项目规则(团队共享) | `项目/CLAUDE.md` 或 `项目/.claude/rules/` |
| 加个人偏好(不入仓库) | `项目/CLAUDE.local.md` |
| 加自定义命令 | `项目/.claude/commands/<cmd>.md` |
| 加复用流程 | `项目/.claude/skills/<n>/SKILL.md` |
| 加子 agent | `项目/.claude/agents/<n>.md` |
| 改回复风格 | `项目/.claude/output-styles/<n>.md` |
| 加工具拦截 | `项目/.claude/hooks/PreToolUse.sh` + `settings.json` 注册 |
| 加 MCP server | `项目/.mcp.json` 或 `项目/.claude/settings.json` 的 `mcpServers` |
| 改权限白名单 | `项目/.claude/settings.json` 的 `permissions.allow` |

## Red Flags — 立即停手

发现以下情况立即纠正,不要绕过:

- 准备把 API key / token 明文写进 `settings.json` 或 `CLAUDE.md` → 改用 env var 或 `settings.local.json`
- 准备把 `.env` 路径加入 `permissions.allow` → 走 env-guard 阻断,而非放行
- `CLAUDE.md` 已经 200+ 行还在加内容 → 必须先拆才能加
- 一个 skill 没有 `SKILL.md` 只放零散文件 → Skill 工具找不到
- hook 脚本写完没 `chmod +x` 就 commit → 必失效
- 个人路径 / 私有 alias 写进 `CLAUDE.md` 入仓库 → 立即挪到 `CLAUDE.local.md`

## 与本人 `~/.claude/` 现状对照

本机 `~/.claude/` 已按本 skill 标准配置完成(2026-05-09 硬化):
- ✅ `CLAUDE.md` 153 行(原 345)
- ✅ `CLAUDE.local.md` + `.gitignore` 已创建
- ✅ `hooks/env-guard.sh` PreToolUse 拦截机密文件
- ✅ `hooks/secret-scan.sh` PostToolUse 扫密钥模式
- ✅ `output-styles/terse.md` 极简回复风格
- ✅ `rules/` 14 个分领域规则文件,主文件 `@rules/xxx.md` 引用
- ✅ Cardinal Rules 6 条,新增"机密文件防线"

任何新项目都应复制此模式。
