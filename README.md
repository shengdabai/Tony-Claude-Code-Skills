# 🤖 Tony's Claude Code Workstation

> A complete, battle-tested Claude Code setup — **381 skills, 16 rules, 15 hooks, 9 agents, 16 commands** — used daily by a Chinese language educator running a one-person business.
>
> 一个完整的、实战检验过的 Claude Code 配置 —— **381 个 skills、16 条 rules、15 个 hooks、9 个 agents、16 个 commands** —— 由一位运营独立业务的中文教育者每日使用。

[![GitHub stars](https://img.shields.io/github/stars/shengdabai/Tony-Claude-Code-Skills?style=social)](https://github.com/shengdabai/Tony-Claude-Code-Skills/stargazers)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20mixed-blue.svg)](NOTICE.md)
[![Skills](https://img.shields.io/badge/skills-381-brightgreen.svg)](#-skill-categories--技能分类部分)
[![Languages](https://img.shields.io/badge/lang-EN%20%2F%20中文-orange.svg)](#)

[**English**](#english) · [**中文**](#中文) · [**Quick Install**](#-quick-install--一键安装) · [**What's Inside**](#-whats-inside--里面有什么)

---

## 🚀 Quick Install / 一键安装

```bash
git clone https://github.com/shengdabai/Tony-Claude-Code-Skills.git
cd Tony-Claude-Code-Skills
bash install.sh --link    # symlink mode (auto-update on git pull)
# or
bash install.sh --copy    # independent copy mode
```

Restart Claude Code. Done. / 重启 Claude Code,完成。

---

## English

### Why This Repo Exists

After ~16 daily Claude Code sessions for months, I built a workstation that integrates **three layers**:

1. **Strategy** — [easychen/opc-methodology](https://github.com/easychen/opc-methodology): 9 skills that walk you through "one-person business" planning (niche → MVP → ops review)
2. **Execution** — [garrytan/gstack](https://github.com/garrytan/gstack): browser-based QA, design review, deploy automation (`/qa`, `/ship`, `/browse`, `/design-review`)
3. **Memory** — [garrytan/gbrain](https://github.com/garrytan/gbrain): persistent knowledge graph with hybrid search; your agent stops forgetting

Plus my own glue: **16 enforcement rules** (secrets firewall, intent defaults, verification gates), **15 hooks** (env-guard, secret-scan, RTK token-killer integration), MCP server configs, and a **gbrain ↔ OPC bridge** that auto-syncs strategy decisions into long-term memory.

### What Makes It Different

| Most "awesome" lists | This repo |
|---|---|
| Curated skill links you have to install one by one | **One `install.sh` deploys 381 skills + my full `~/.claude/`** |
| Generic recommendations | **Battle-tested by a daily power user** (16 sessions/day) |
| English only | **Bilingual rules + skills** (EN/中文) |
| Skills only | **Skills + rules + hooks + agents + commands + MCP configs** |
| No safety story | **Three-layer secrets firewall** (env-guard hook, secret-scan hook, gitleaks pre-commit) |

### Highlights

- 🎯 **OPC × gstack × gbrain** three-stack integration (see `my-config/rules/gbrain-routing.md`, `gstack-routing.md`, `opc-methodology.md`)
- 🛡️ **Secrets firewall** with PreToolUse hooks (`my-config/hooks/env-guard.sh`, `secret-scan.sh`)
- 🔄 **OPC → gbrain auto-sync** (`my-config/scripts/opc-to-gbrain.sh`) — strategy decisions become searchable long-term memory
- 🚀 **RTK proxy** integration for 60-90% token savings on dev operations
- 📦 **15 hooks** including session-start, prompt-guard, statusline, log-rotate
- 🌏 **Bilingual** rules and many skills (Chinese-friendly, English-fluent)

---

## 中文

### 为什么有这个仓

每天 ~16 次 Claude Code 会话用了几个月,我搭出来一个**三层集成**的工作站:

1. **策略层** — [easychen/opc-methodology](https://github.com/easychen/opc-methodology):9 个 skill 串联"一人企业"规划全流程(利基→MVP→复盘)
2. **执行层** — [garrytan/gstack](https://github.com/garrytan/gstack):浏览器自动化 QA、设计审查、部署(`/qa`、`/ship`、`/browse`、`/design-review`)
3. **记忆层** — [garrytan/gbrain](https://github.com/garrytan/gbrain):持久知识图谱+混合搜索,agent 不再失忆

加上我的胶水代码:**16 条规则**(密钥防火墙、意图默认、验证门控)、**15 个 hook**(env-guard、secret-scan、RTK token 节流)、**MCP 服务配置**、**OPC ↔ gbrain 双向桥**(策略决策自动入长期记忆)。

### 跟其他"awesome 列表"的区别

| 大部分"精选清单" | 本仓 |
|---|---|
| 给你 skill 链接,你一个个手动装 | **一条 `install.sh` 部署 381 个 skill + 我整套 `~/.claude/`** |
| 泛泛推荐 | **重度用户实战检验**(每天 16 次会话) |
| 只有英文 | **中英双语 rules + skill** |
| 只有 skill | **skill + rules + hooks + agents + commands + MCP 配置** |
| 没有安全方案 | **三层密钥防火墙**(env-guard hook、secret-scan hook、gitleaks pre-commit) |

### 亮点

- 🎯 **OPC × gstack × gbrain** 三栈集成(详见 `my-config/rules/gbrain-routing.md`、`gstack-routing.md`、`opc-methodology.md`)
- 🛡️ **密钥防火墙**用 PreToolUse hook 实现(`my-config/hooks/env-guard.sh`、`secret-scan.sh`)
- 🔄 **OPC → gbrain 自动同步**(`my-config/scripts/opc-to-gbrain.sh`)——策略决策变成可搜索的长期记忆
- 🚀 **RTK 代理**集成,开发命令省 60-90% token
- 📦 **15 个 hook**:session-start、prompt-guard、statusline、log-rotate 等
- 🌏 **中英双语** rules 和大量 skill(中文友好,英文流畅)

---

## 📦 What's Inside / 里面有什么

```
Tony-Claude-Code-Skills/
├── install.sh                    ← One-command installer / 一键安装
├── my-config/                    ← My personal ~/.claude/ (412KB)
│   ├── CLAUDE.md                 ← Global rules entry / 全局规则入口
│   ├── rules/        (16)        ← Cardinal rules + integrations
│   ├── scripts/       (5)        ← OPC bridge, etc.
│   ├── agents/        (9)        ← architect, code-reviewer, planner...
│   ├── commands/     (16)        ← /tdd, /code-review, /verify...
│   ├── hooks/        (15)        ← env-guard, secret-scan, statusline...
│   ├── output-styles/ (1)        ← terse mode
│   └── mcp-servers/              ← MCP server configs
├── opc-methodology/              ← One-person business methodology (CC-BY-NC-SA)
│   └── skills/       (9)         ← /opc-orchestrator + 8 stage skills
├── skills/         (372)         ← Curated third-party skills
└── NOTICE.md                     ← Attribution & license info / 来源与协议
```

### Skill Categories / 技能分类（部分）

- **Design** — `frontend-design`, `huashu-design`, `design-consultation`, `design-shotgun`, `design-review`
- **Browser** — `browse`, `connect-chrome`, `setup-browser-cookies`, `qa`, `qa-only`
- **Planning** — `plan-ceo-review`, `plan-eng-review`, `plan-design-review`, `office-hours`
- **Memory** — `gbrain-*` series (40+ skills for persistent knowledge)
- **OPC** — `opc-orchestrator`, `opc-niche-positioning`, `opc-mvp-designer`, etc. (9 skills)
- **Anthropic Official** — `anthropics-pdf`, `anthropics-xlsx`, `anthropics-pptx`, `anthropics-docx`, `anthropics-mcp-builder`
- **Workflow** — `autoplan`, `ralph`, `team`, `ultrawork`, `ultraqa`
- **Quality** — `audit`, `cso`, `review`, `verify`, `test-coverage`
- **Deploy** — `ship`, `land-and-deploy`, `canary`, `setup-deploy`
- **Polish** — `polish`, `delight`, `clarify`, `harden`, `optimize`

(See full list under [`skills/`](skills/) / 完整列表见 [`skills/`](skills/) 目录)

---

## 🔌 Required External Tools / 需要的外部工具

| Tool | Why | Install |
|---|---|---|
| Claude Code | The host / 宿主 | https://claude.com/claude-code |
| [gstack](https://github.com/garrytan/gstack) | Browser automation, QA, deploy | Already vendored in `skills/gstack/` |
| [gbrain](https://github.com/garrytan/gbrain) | Persistent memory + knowledge graph | `bun install -g github:garrytan/gbrain` |
| [gitleaks](https://github.com/gitleaks/gitleaks) | Pre-commit secret scan (optional) | `brew install gitleaks` |

---

## 🤝 Contributing / 贡献

This is a personal config repo, but if you spot bugs, outdated upstream pointers, or missing attributions, please [open an issue](https://github.com/shengdabai/Tony-Claude-Code-Skills/issues).

If you're an author and want your skill removed from this collection, please open an issue — I will remove within 24 hours.

这是个人配置仓,但如果你发现 bug、过时的上游链接、或缺少 attribution,请[提 issue](https://github.com/shengdabai/Tony-Claude-Code-Skills/issues)。

如果你是某个 skill 的作者并希望移除你的作品,请提 issue,24 小时内移除。

---

## 📜 License

- **My original work** (`my-config/`, `install.sh`, `README.md`, `NOTICE.md`): MIT
- **Third-party skills** (`skills/*`, `opc-methodology/`): each subdirectory keeps its own LICENSE (mostly MIT, Apache 2.0, or CC-BY variants). See [NOTICE.md](NOTICE.md).

---

## 🙏 Acknowledgments / 致谢

Built on the shoulders of giants:

- [@easychen](https://github.com/easychen) — for OPC methodology that helped me think strategically about my one-person business
- [@garrytan](https://github.com/garrytan) — for gstack and gbrain, the execution and memory backbone
- [Anthropic](https://github.com/anthropics) — for the official skills (pdf/xlsx/docx/pptx/mcp-builder)
- All other authors in `skills/` — too many to list individually, see each skill's own README

---

<div align="center">

**Star this repo ⭐ if it saves you a week of setup time.**

**如果省了你一周搭配置的时间,给个 star ⭐**

[Issues](https://github.com/shengdabai/Tony-Claude-Code-Skills/issues) · [Discussions](https://github.com/shengdabai/Tony-Claude-Code-Skills/discussions) · [@shengdabai](https://github.com/shengdabai)

</div>
