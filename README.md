# Tony's Claude Code Skills & MCP Collection

[中文版](#中文版) | [English](#english-version)

---

## English Version

A curated collection of **Claude Code skills and MCP servers** configured for production use. This repo documents every tool, skill, and integration that powers my daily AI-assisted development workflow.

---

### MCP Servers

| Name | Description | Source |
|------|-------------|--------|
| **context7** | Up-to-date library documentation lookup | [upstash/context7-mcp](https://github.com/upstash/context7-mcp) |
| **firecrawl** | Web scraping and crawling with clean content extraction | [mendableai/firecrawl-mcp-server](https://github.com/mendableai/firecrawl-mcp-server) |
| **exa** | AI-powered web search and answer engine | [exa-labs/exa-mcp-server](https://github.com/exa-labs/exa-mcp-server) |
| **github** | Full GitHub API access (repos, issues, PRs, etc.) | [github/github-mcp-server](https://github.com/github/github-mcp-server) |
| **playwright** | Browser automation and web page interaction | [playwright-ai/mcp-server](https://github.com/anthropics/anthropic-cookbook/tree/main/mcp/playwright) |
| **getnote** | Access to GetNote knowledge base (292 Chinese teaching notes from 200h recordings) | Custom — [github.com/tony/getnote-mcp](https://github.com/tony/getnote-mcp) |
| **gbrain** | GBrain AI inference server | Custom — [garrytan/gbrain](https://github.com/garrytan/gbrain) |
| **notebooklm** | Google NotebookLM integration for audio notebooks | Custom npm package (`notebooklm-mcp`) |
| **lark** | Lark (Feishu) CLI integration — IM, docs, sheets, calendar | [lark-mcp](https://github.com/nicepkg/lark-mcp) |
| **airmcp** | AI MCP server for additional AI tool integrations | [airmcp](https://github.com/nicepkg/airmcp) |

---

### Skills

#### Core Workflow

| Skill | Command | Description | Source |
|-------|---------|-------------|--------|
| **gstack** | `/gstack` | Multi-mode workflow orchestration: CEO reviews, engineering reviews, design audits, QA testing, shipping pipeline | [garrytan/gstack](https://github.com/garrytan/gstack) |
| **omc-reference** | `/oh-my-claudecode:*` | Oh-My-ClaudeCode agent catalog, team pipeline routing, commit protocol, skills registry | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **review** | `/review` | Code review with severity-rated feedback, logic defect detection, SOLID principle checks | [gstack](https://github.com/garrytan/gstack) |
| **ship** | `/ship` | One-click release/deploy pipeline with PR creation and verification | [gstack](https://github.com/garrytan/gstack) |
| **qa** | `/qa` | Automated QA testing with browser and auto-fix | [gstack](https://github.com/garrytan/gstack) |
| **qa-only** | `/qa-only` | QA testing, report only (no auto-fix) | [gstack](https://github.com/garrytan/gstack) |
| **investigate** | `/investigate` | Bug investigation using scientific method with evidence tracking | [gstack](https://github.com/garrytan/gstack) |
| **retro** | `/retro` | Weekly retrospective review of work progress | [gstack](https://github.com/garrytan/gstack) |
| **document-release** | `/document-release` | Auto-update documentation after shipping | [gstack](https://github.com/garrytan/gstack) |
| **setup-browser-cookies** | `/setup-browser-cookies` | Configure browser cookies for web-based tools | [gstack](https://github.com/garrytan/gstack) |
| **browse** | `/browse` | Web browsing via browser automation | [gstack](https://github.com/garrytan/gstack) |

#### Code Quality & Architecture

| Skill | Command | Description | Source |
|-------|---------|-------------|--------|
| **plan-ceo-review** | `/plan-ceo-review` | Product-minded review of feature ideas with CEO-level perspective | [gstack](https://github.com/garrytan/gstack) |
| **plan-eng-review** | `/plan-eng-review` | Engineering architecture review for technical decisions | [gstack](https://github.com/garrytan/gstack) |
| **plan-design-review** | `/plan-design-review` | Design audit with 7-dimension scoring | [gstack](https://github.com/garrytan/gstack) |
| **plan-devex-review** | `/plan-devex-review` | Developer experience review | [gstack](https://github.com/garrytan/gstack) |
| **health** | `/health` | Code quality health check | [gstack](https://github.com/garrytan/gstack) |
| **checkpoint** | `/checkpoint` | Save progress, checkpoint, resume | [gstack](https://github.com/garrytan/gstack) |
| **careful** | `/careful` | Careful, methodical execution mode | [gstack](https://github.com/garrytan/gstack) |
| **guard** | `/guard` | Safety guard for risky operations | [gstack](https://github.com/garrytan/gstack) |
| **freeze** | `/freeze` | Freeze current state | [gstack](https://github.com/garrytan/gstack) |
| **unfreeze** | `/unfreeze` | Unfreeze state | [gstack](https://github.com/garrytan/gstack) |
| **verification-gate** | `/verify` | Read-only verification pass to validate completion claims | [gstack](https://github.com/garrytan/gstack) |

#### Design (Impeccable)

| Skill | Command | Description | Source |
|-------|---------|-------------|--------|
| **design-consultation** | `/design-consultation` | Build design systems from scratch, create DESIGN.md | [gstack](https://github.com/garrytan/gstack) |
| **design-review** | `/design-review` | Visual QA with screenshot → fix → verify loop | [gstack](https://github.com/garrytan/gstack) |
| **design-shotgun** | `/design-shotgun` | Explore multiple design variants with comparison board | [gstack](https://github.com/garrytan/gstack) |
| **design-html** | `/design-html` | Implement designs as native Pretext HTML | [gstack](https://github.com/garrytan/gstack) |

#### OMC (Oh-My-ClaudeCode)

| Skill | Command | Description | Source |
|-------|---------|-------------|--------|
| **autopilot** | `/autopilot` | Autonomous execution mode | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **ultrawork** | `/ultrawork` | High-throughput iterative mode | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **ralplan** | `/ralplan` | Strategic planning with interview workflow | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **ccg** | `/ccg` | Claude Code Guide agent | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **deep-interview** | `/deep-interview` | Deep interview mode for requirements analysis | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **ultraqa** | `/ultraqa` | Enhanced QA testing | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **team** | `/team` | Multi-agent team orchestration | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **omc-setup** | `/oh-my-claudecode:setup` | Setup OMC | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |

#### Custom / Personal Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **agent-builder** | Custom | Agent builder for autonomous AI agent creation |
| **architecture-diagram** | Custom | Create professional architecture diagrams as standalone HTML with SVG |
| **code-to-course** | Custom | Turn codebases into interactive HTML courses (bilingual CN/EN) |
| **darwin-skill** | Custom | Autonomous skill optimizer — evaluates, hill-climbs, validates SKILL.md files |
| **dream-memory** | Custom | Consolidate logs/sessions into durable topic memories, prune stale entries |
| **fireworks-tech-graph** | Custom | Tech stack dependency graph visualization |
| **fit-coach** | `/fit-coach` | Professional fitness coach — nutrition planning + adaptive training |
| **json-canvas** | Custom | Create/edit Obsidian JSON Canvas files (.canvas) with nodes, edges, groups |
| **kairos-lite** | Custom | Lightweight background check mode with scheduled checks and sleep intervals |
| **llm-council** | Custom | Multi-model council for decision making |
| **memory-extractor** | Custom | Extract durable memories from conversations into categorized files |
| **obsidian-bases** | Custom | Create/edit Obsidian Bases (.base) with views, filters, formulas |
| **obsidian-cli** | Custom | CLI interaction with Obsidian vaults — notes, tasks, plugins |
| **obsidian-markdown** | Custom | Obsidian Flavored Markdown — wikilinks, embeds, callouts, properties |
| **planning-with-files** | Custom | File-based task planning (Manus-style) — creates task_plan.md, findings.md, progress.md |
| **remote-control** | Custom | Sync terminal Claude Code session to mobile/browser Claude app |
| **rename** | Custom | Rename/refactor operations |
| **risk-guard** | Custom | Risk analysis and mitigation for code changes |
| **structured-context-compressor** | Custom | Compress long agent conversations into nine-part continuation summaries |
| **swarm-coordinator** | Custom | Coordinate multiple agents — research, synthesis, implementation, verification |
| **twitter** | Custom | Twitter/X integration |
| **web-scraper** | Custom | Advanced web scraping with anti-detection |
| **xiaolai** | `/xiaolai` | Xiaolai's Claude tools — Agent SDK + NLPM (Natural-Language Programming Manager) |
| **youtube** | Custom | YouTube video processing and analysis |
| **import-to-obsidian** | Custom | Save web content to Obsidian vault with auto-classification and tagging |
| **limit-continue-work** | Custom | Limit continuation in conversations to prevent context overflow |
| **bb-browser** | Custom | Web scraping via real browser with user login state, form filling, data extraction |
| **galaxy-ui** | Auto | 3,800+ Uiverse UI components — buttons, cards, loaders, inputs, toggles, forms, checkboxes, patterns, radio buttons, notifications, tooltips |

#### Built-in (Claude Code)

36 built-in skills from Claude Code: `algorithmic-art`, `brand-guidelines`, `canvas-design`, `claude-api`, `do`, `doc-coauthoring`, `docx`, `frontend-design`, `internal-comms`, `make-plan`, `mama`, `mcp-builder`, `mem-search`, `p7`, `p9`, `p10`, `pdf`, `pptx`, `pro`, `pua`, `pua-en`, `pua-ja`, `pua-loop`, `shot`, `skill-creator`, `slack-gif-creator`, `smart-explore`, `smux`, `template-skill`, `theme-factory`, `timeline-report`, `web-access`, `web-artifacts-builder`, `webapp-testing`, `xlsx`, `yes`

#### GStack Additional

| Skill | Command | Description | Source |
|-------|---------|-------------|--------|
| **gstack-upgrade** | `/gstack-upgrade` | Upgrade gstack to latest version | [gstack](https://github.com/garrytan/gstack) |
| **learn** | `/learn` | Learn from past patterns | [gstack](https://github.com/garrytan/gstack) |
| **open-gstack-browser** | Custom | Open gstack browser session | [gstack](https://github.com/garrytan/gstack) |
| **pair-agent** | Custom | Pair programming agent | [gstack](https://github.com/garrytan/gstack) |
| **canary** | Custom | Canary testing | [gstack](https://github.com/garrytan/gstack) |
| **devex-review** | Custom | Developer experience review | [gstack](https://github.com/garrytan/gstack) |
| **office-hours** | Custom | Office hours review | [gstack](https://github.com/garrytan/gstack) |
| **codex** | Custom | Codex CLI integration | [gstack](https://github.com/garrytan/gstack) |
| **connect-chrome** | Custom | Connect to Chrome browser | [gstack](https://github.com/garrytan/gstack) |
| **cso** | Custom | CSO (Chief Security Officer) mode | [gstack](https://github.com/garrytan/gstack) |
| **defuddle** | Custom | Clean markdown content extraction | [gstack](https://github.com/garrytan/gstack) |
| **history** | Custom | Session history management | [gstack](https://github.com/garrytan/gstack) |
| **benchmark** | Custom | Benchmarking mode | [gstack](https://github.com/garrytan/gstack) |
| **autoplan** | Custom | Auto planning mode | [gstack](https://github.com/garrytan/gstack) |
| **autoresearch** | Custom | Autonomous ML research agent | [gstack](https://github.com/garrytan/gstack) |
| **setup-deploy** | Custom | Setup and deploy | [gstack](https://github.com/garrytan/gstack) |
| **land-and-deploy** | Custom | Land and deploy workflow | [gstack](https://github.com/garrytan/gstack) |

---

### File Structure

```
Tony-Claude-Code-Skills/
├── README.md              # This file (bilingual)
├── skills/
│   ├── agent-builder/     # Custom skill files
│   ├── architecture-diagram/
│   ├── code-to-course/
│   ├── darwin-skill/
│   ├── dream-memory/
│   ├── fit-coach/
│   ├── json-canvas/
│   ├── kairos-lite/
│   ├── llm-council/
│   ├── memory-extractor/
│   ├── obsidian-bases/
│   ├── obsidian-cli/
│   ├── obsidian-markdown/
│   ├── planning-with-files/
│   ├── remote-control/
│   ├── rename/
│   ├── risk-guard/
│   ├── structured-context-compressor/
│   ├── swarm-coordinator/
│   ├── twitter/
│   ├── web-scraper/
│   ├── xiaolai/
│   └── youtube/
├── mcp-servers/
│   └── README.md          # MCP server configurations
└── .gitignore
```

---

### Usage

1. Clone or download this repository
2. Browse the `skills/` directory for custom skill definitions
3. Check `mcp-servers/` for MCP server configurations
4. External skills reference their GitHub source repos (linked above)
5. Install skills by copying directories to `~/.claude/skills/`
6. Install MCP servers by adding configs to `~/.claude/settings.json`

### Contributing

If you find a skill useful or want to improve one — **issues and PRs welcome**. This collection grows through community feedback.

### License

Individual skills retain their original licenses. Custom skills in this repo are MIT licensed.

---

## 中文版

精心整理的 **Claude Code 技能和 MCP 服务器集合**，用于日常 AI 辅助开发工作流。

---

### MCP 服务器

| 名称 | 说明 | 来源 |
|------|------|------|
| **context7** | 实时查询最新库文档 | [upstash/context7-mcp](https://github.com/upstash/context7-mcp) |
| **firecrawl** | 网页爬取与内容提取 | [mendableai/firecrawl-mcp-server](https://github.com/mendableai/firecrawl-mcp-server) |
| **exa** | AI 驱动的搜索引擎 | [exa-labs/exa-mcp-server](https://github.com/exa-labs/exa-mcp-server) |
| **github** | 完整 GitHub API 访问 | [github/github-mcp-server](https://github.com/github/github-mcp-server) |
| **playwright** | 浏览器自动化 | [Playwright MCP](https://github.com/anthropics/anthropic-cookbook/tree/main/mcp/playwright) |
| **getnote** | GetNote 知识库（292 条中文教学笔记） | 自定义 — [github.com/tony/getnote-mcp](https://github.com/tony/getnote-mcp) |
| **gbrain** | GBrain AI 推理服务 | 自定义 — [garrytan/gbrain](https://github.com/garrytan/gbrain) |
| **notebooklm** | Google NotebookLM 音频笔记本集成 | 自定义 npm 包 (`notebooklm-mcp`) |
| **lark** | 飞书 CLI 集成（IM/文档/表格/日历） | [lark-mcp](https://github.com/nicepkg/lark-mcp) |
| **airmcp** | AI MCP 服务器 | [airmcp](https://github.com/nicepkg/airmcp) |

---

### 技能列表

#### 核心工作流

| 技能 | 命令 | 说明 | 来源 |
|------|------|------|------|
| **gstack** | `/gstack` | 多模式工作流编排：产品审视、工程审查、设计审计、QA 测试、发布管线 | [garrytan/gstack](https://github.com/garrytan/gstack) |
| **omc-reference** | `/oh-my-claudecode:*` | Oh-My-ClaudeCode 代理目录、团队路由、提交协议 | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **review** | `/review` | 代码审查（严重度分级、逻辑缺陷检测） | [gstack](https://github.com/garrytan/gstack) |
| **ship** | `/ship` | 一键发布流程（PR 创建+验证） | [gstack](https://github.com/garrytan/gstack) |
| **qa** | `/qa` | 自动 QA 测试+修复 | [gstack](https://github.com/garrytan/gstack) |
| **qa-only** | `/qa-only` | QA 测试，只报告不修复 | [gstack](https://github.com/garrytan/gstack) |
| **investigate** | `/investigate` | 科学方法 bug 调查+证据追踪 | [gstack](https://github.com/garrytan/gstack) |
| **retro** | `/retro` | 周工作复盘 | [gstack](https://github.com/garrytan/gstack) |
| **document-release** | `/document-release` | 发布后自动更新文档 | [gstack](https://github.com/garrytan/gstack) |
| **setup-browser-cookies** | `/setup-browser-cookies` | 配置浏览器 Cookie | [gstack](https://github.com/garrytan/gstack) |
| **browse** | `/browse` | 浏览器自动化网页浏览 | [gstack](https://github.com/garrytan/gstack) |

#### 代码质量与架构

| 技能 | 命令 | 说明 | 来源 |
|------|------|------|------|
| **plan-ceo-review** | `/plan-ceo-review` | 产品思维功能审视 | [gstack](https://github.com/garrytan/gstack) |
| **plan-eng-review** | `/plan-eng-review` | 工程技术架构审查 | [gstack](https://github.com/garrytan/gstack) |
| **plan-design-review** | `/plan-design-review` | 7 维评分设计审计 | [gstack](https://github.com/garrytan/gstack) |
| **plan-devex-review** | `/plan-devex-review` | 开发者体验审查 | [gstack](https://github.com/garrytan/gstack) |
| **health** | `/health` | 代码健康度检查 | [gstack](https://github.com/garrytan/gstack) |
| **checkpoint** | `/checkpoint` | 保存进度断点 | [gstack](https://github.com/garrytan/gstack) |
| **careful** | `/careful` | 审慎执行模式 | [gstack](https://github.com/garrytan/gstack) |
| **guard** | `/guard` | 高风险操作防护 | [gstack](https://github.com/garrytan/gstack) |
| **freeze** | `/freeze` | 冻结当前状态 | [gstack](https://github.com/garrytan/gstack) |
| **unfreeze** | `/unfreeze` | 解冻状态 | [gstack](https://github.com/garrytan/gstack) |
| **verification-gate** | `/verify` | 只读验证检查 | [gstack](https://github.com/garrytan/gstack) |

#### 设计 (Impeccable)

| 技能 | 命令 | 说明 | 来源 |
|------|------|------|------|
| **design-consultation** | `/design-consultation` | 从零建设计系统，创建 DESIGN.md | [gstack](https://github.com/garrytan/gstack) |
| **design-review** | `/design-review` | 视觉 QA：截图→修复→验证 | [gstack](https://github.com/garrytan/gstack) |
| **design-shotgun** | `/design-shotgun` | 多设计方案对比探索 | [gstack](https://github.com/garrytan/gstack) |
| **design-html** | `/design-html` | 设计转原生 HTML | [gstack](https://github.com/garrytan/gstack) |

#### OMC (Oh-My-ClaudeCode)

| 技能 | 命令 | 说明 | 来源 |
|------|------|------|------|
| **autopilot** | `/autopilot` | 自主执行模式 | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **ultrawork** | `/ultrawork` | 高吞吐迭代模式 | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **ralplan** | `/ralplan` | 战略规划+访谈工作流 | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **ccg** | `/ccg` | Claude Code 指南代理 | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **deep-interview** | `/deep-interview` | 深度需求分析访谈 | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **ultraqa** | `/ultraqa` | 增强型 QA 测试 | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |
| **team** | `/team` | 多代理团队编排 | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) |

#### 自定义/个人技能

| 技能 | 命令 | 说明 |
|------|------|------|
| **agent-builder** | 自定义 | 自主 AI 代理构建器 |
| **architecture-diagram** | 自定义 | 专业架构图（HTML + SVG） |
| **code-to-course** | 自定义 | 代码转交互式双语课程 |
| **darwin-skill** | 自定义 | 技能自动优化器 — 评估、爬山、验证 SKILL.md |
| **dream-memory** | 自定义 | 日志/会话记忆持久化，清理过期条目 |
| **fireworks-tech-graph** | 自定义 | 技术栈依赖图可视化 |
| **fit-coach** | `/fit-coach` | 专业健身教练 — 营养规划+自适应训练 |
| **json-canvas** | 自定义 | Obsidian Canvas 文件编辑（节点/连线/分组） |
| **kairos-lite** | 自定义 | 轻量后台检查模式 — 定时检查+休眠 |
| **llm-council** | 自定义 | 多模型决策委员会 |
| **memory-extractor** | 自定义 | 从对话中提取持久记忆到分类文件 |
| **obsidian-bases** | 自定义 | Obsidian Bases 编辑（视图/过滤器/公式） |
| **obsidian-cli** | 自定义 | Obsidian 笔记库 CLI 交互 |
| **obsidian-markdown** | 自定义 | Obsidian Markdown — 双向链接/嵌入/标注 |
| **planning-with-files** | 自定义 | 文件化任务规划 — 生成 task_plan.md / findings.md / progress.md |
| **remote-control** | 自定义 | 终端 Claude Code 同步到手机/浏览器 |
| **rename** | 自定义 | 重命名/重构操作 |
| **risk-guard** | 自定义 | 代码变更风险分析 |
| **structured-context-compressor** | 自定义 | 长对话压缩为九段续接摘要 |
| **swarm-coordinator** | 自定义 | 多代理协调 — 研究/综合/实现/验证 |
| **twitter** | 自定义 | Twitter/X 集成 |
| **web-scraper** | 自定义 | 高级网页爬取（反检测） |
| **xiaolai** | `/xiaolai` | 李笑来 Claude 工具集 — Agent SDK + NLPM 自然语言编程管理器 |
| **youtube** | 自定义 | YouTube 视频处理与分析 |
| **import-to-obsidian** | 自定义 | 网页内容保存到 Obsidian，自动分类+标签 |
| **limit-continue-work** | 自定义 | 限制对话续传，防止上下文溢出 |
| **bb-browser** | 自定义 | 真实浏览器爬虫 — 登录态、表单填写、数据采集 |

#### 内置技能 (Claude Code)

36 个 Claude Code 内置技能：`algorithmic-art`, `brand-guidelines`, `canvas-design`, `claude-api`, `do`, `doc-coauthoring`, `docx`, `frontend-design`, `internal-comms`, `make-plan`, `mama`, `mcp-builder`, `mem-search`, `p7`, `p9`, `p10`, `pdf`, `pptx`, `pro`, `pua`, `pua-en`, `pua-ja`, `pua-loop`, `shot`, `skill-creator`, `slack-gif-creator`, `smart-explore`, `smux`, `template-skill`, `theme-factory`, `timeline-report`, `web-access`, `web-artifacts-builder`, `webapp-testing`, `xlsx`, `yes`

---

### 使用方法

1. 克隆或下载本仓库
2. 浏览 `skills/` 目录查看自定义技能定义
3. 查看 `mcp-servers/` 了解 MCP 服务器配置
4. 外部技能参考其 GitHub 源仓库（上方已附链接）
5. 安装技能：将目录复制到 `~/.claude/skills/`
6. 安装 MCP 服务器：将配置添加到 `~/.claude/settings.json`

### 反馈与贡献

如果你觉得某个技能有用或想改进它——**欢迎提 Issue 和 PR**。这个集合通过社区反馈不断成长。

### 许可证

各技能保留其原始许可证。本仓库中的自定义技能采用 MIT 许可证。
