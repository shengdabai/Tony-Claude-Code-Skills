# Tony's Claude Code Skills

> **A curated, production-ready collection of 334+ Claude Code skills, agents, hooks, and configuration** — built around the **Spec-Driven Trio** (OpenSpec + Superpowers + addyosmani agent-skills).
>
> **334+ 个精选 Claude Code 技能、agent、hook 与配置** — 围绕 **Spec-Driven 三件套**(OpenSpec + Superpowers + addyosmani agent-skills)组织。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Skills](https://img.shields.io/badge/skills-334+-brightgreen)](skills/)
[![Collections](https://img.shields.io/badge/_collections-47%20more-blue)](skills/_collections/)
[![CI](https://github.com/shengdabai/Tony-Claude-Code-Skills/actions/workflows/ci.yml/badge.svg)](https://github.com/shengdabai/Tony-Claude-Code-Skills/actions/workflows/ci.yml)

---

## 📊 By the Numbers / 项目现状

| Metric / 指标 | Value / 数值 |
|---|---|
| Skill directories (first-party + curated) / skill 目录 | **334** |
| `SKILL.md` files incl. nested / SKILL.md 文件 | **1,201** |
| Subagents / 子 agent | **630** |
| Slash commands / 斜杠命令 | **349** |
| Bundled third-party collections / 内置第三方合集 | **19** |
| Commits / 提交 | **32** |
| Active maintenance / 活跃维护 | **2026-04 → present, weekly pushes** |
| License / 协议 | **MIT** (first-party) + per-skill upstream (third-party) |
| CI / 持续集成 | ✅ Credential + frontmatter gate on every push |
| Install / 安装 | One command, ≈ 30 seconds |

**Status / 现状:** Early-stage but actively maintained. Distribution is via direct
`git clone` + `install.sh` (no package registry yet); every push is CI-gated for
leaked credentials and skill-frontmatter integrity. Issues and PRs welcome.

早期但持续维护,通过 `git clone` + 一键安装传播(尚未上架包管理器),每次 push 都跑
CI 扫凭证泄漏与 frontmatter 完整性。欢迎 issue / PR。

---

## 🚀 Quick Install / 一键安装

```bash
# Clone & install (≈ 30 seconds)
git clone https://github.com/shengdabai/Tony-Claude-Code-Skills.git ~/Tony-CCS
cd ~/Tony-CCS && bash install.sh

# Or just grab the skills directory
git clone --depth=1 https://github.com/shengdabai/Tony-Claude-Code-Skills.git
cp -R Tony-Claude-Code-Skills/skills/* ~/.claude/skills/
```

After install, open a new Claude Code session and you can immediately use:

安装后开新 Claude Code 会话即可使用:

```
/spec add a new auth flow         ← Spec-Driven Trio 全流程
/opc-orchestrator                  ← 一人企业方法论
/xiaolai-write                     ← 长文写作流水线
/tdd                               ← TDD 强制流程
... and 300+ more skills
```

---

## 🧬 The Spec-Driven Trio / 三件套核心

This repo is organized around a **three-layer collaboration model** that turns Claude Code into a disciplined SDD engineer:

本仓库围绕 **三层协作模型** 组织,让 Claude Code 变成有纪律的 SDD 工程师:

| Layer / 层 | Tool / 工具 | Role / 角色 |
|---|---|---|
| **🧠 Memory & Spec** | [**OpenSpec**](https://github.com/Fission-AI/OpenSpec) (`/opsx:*`) | Generates `proposal.md` / `specs/` / `design.md` / `tasks.md` artifacts. **Spec lives in the repo, not chat history.**<br>把规格落在仓库里,不是聊天历史里。 |
| **⚙️ Execution & Discipline** | [**Superpowers**](https://github.com/obra/superpowers) plugin | brainstorm → plan → TDD → verify-before-completion. **Evidence over assertions.**<br>证据优先,纪律严格。 |
| **📐 Code Standards** | [**addyosmani/agent-skills**](https://github.com/addyosmani/agent-skills) (23 skills) | Cross-cutting code quality: `api-and-interface-design`, `security-and-hardening`, `code-review-and-quality`, `performance-optimization`, etc.<br>横向代码规范。 |

### Why a trio? / 为什么是三件套?

- **OpenSpec ≠ code generator** — it produces markdown artifacts; code generation belongs to the other two.<br>OpenSpec 只产规格,不产代码。
- **Superpowers ≠ code rules** — it governs *how* to act safely; *what* the code should look like is the third layer.<br>Superpowers 管"怎么做",不管"做成什么样"。
- **agent-skills ≠ workflow** — it codifies standards (security, performance, API design); flow control is the other two.<br>agent-skills 是横切规范,不是流程。

The three layers stack without overlap. See [`my-config/rules/spec-driven-trio.md`](my-config/rules/spec-driven-trio.md) for the full task-routing table.

三层完全不重叠,详见上面的 rule 文件。

### Install the trio / 一键三装

```bash
# 1. OpenSpec (global CLI + /opsx:* slash commands)
npm install -g @fission-ai/openspec@latest

# 2. Superpowers (Claude Code plugin)
/plugin install superpowers@superpowers-dev

# 3. addyosmani agent-skills — already vendored here
cp -R skills/code-review-and-quality skills/doubt-driven-development \
      skills/interview-me skills/test-driven-development \
      skills/using-agent-skills ~/.claude/skills/
```

### How to trigger / 怎么触发

```
/spec                              ← Slash command, ask for feature
/spec add dark mode toggle         ← Direct kickoff
"spec 这个功能" / "write spec for X" / "propose this" ← Bare-word trigger
```

Auto-detection: if a project root contains `openspec/`, SDD mode kicks in automatically. Otherwise it gracefully falls back to brainstorm → plan → TDD without forcing spec artifacts.

自动检测:项目根有 `openspec/` 就自动进 SDD 模式,没有就降级到 brainstorm → plan → TDD,不强塞规格工件。

---

## 📦 What's Inside / 里面有什么

```
Tony-Claude-Code-Skills/
├── install.sh                    ← One-command installer / 一键安装
│
├── my-config/                    ← My personal ~/.claude/ — copy directly
│   │                                我的本机配置,可直接覆盖你的 ~/.claude/
│   ├── CLAUDE.md                 ← Global rules entry (7 Cardinal Rules)
│   ├── rules/        (17)        ← Cardinal rules + integration rules
│   │   └── spec-driven-trio.md   ← ⭐ The trio's routing rules
│   ├── commands/     (17)        ← /tdd, /code-review, /verify, /spec ...
│   ├── agents/        (9)        ← architect, code-reviewer, planner ...
│   ├── hooks/        (15)        ← env-guard, secret-scan, statusline ...
│   ├── output-styles/ (1)        ← terse mode
│   └── mcp-servers/              ← MCP server configs
│
├── skills/                       ← 312 production-ready skills (flat)
│   │                                312 个一目录一 skill 的生产 skill
│   ├── code-review-and-quality/  ← addyosmani trio member
│   ├── doubt-driven-development/ ← addyosmani trio member
│   ├── interview-me/             ← addyosmani trio member
│   ├── test-driven-development/  ← addyosmani trio member
│   ├── using-agent-skills/       ← addyosmani trio member
│   ├── frontend-design/          ← gstack family
│   ├── lark-* (25 skills)        ← Feishu/Lark CLI integration
│   ├── afa-* (30 skills)         ← DTC marketing methodology
│   ├── hyperframes-* (13 skills) ← HyperFrames video composition
│   ├── real-engineer-* (14)      ← Matt Pocock skills
│   ├── gbrain-* (40+)            ← Persistent memory + knowledge graph
│   ├── opc-* (9)                 ← One-person business methodology
│   └── ...                       ← 200+ more, see skills/ for full list
│
├── skills/_collections/          ← 47 skills from third-party repos
│   │                                第三方合集(整 repo 引入,供调研)
│   ├── anthropics-skills/        ← Official Anthropic skills
│   ├── superpowers/              ← Superpowers plugin source
│   ├── claude-code/              ← Official Claude Code patterns
│   ├── document-skills/          ← xlsx/docx/pdf/pptx
│   ├── wshobson-agents/          ← Sam Wshobson's agents
│   ├── travisvn-awesome-claude-skills/
│   ├── ComposioHQ-awesome-claude-skills/
│   ├── 1natsu172-dotfiles/       ← Personal dotfiles examples
│   ├── d-kimuson-dotfiles/
│   ├── rghamilton3-dotfiles/
│   ├── JamesPrial-github-skills/
│   ├── plugins/                  ← Plugin templates & start kits
│   └── ...
│
├── opc-methodology/              ← One-person business (CC-BY-NC-SA)
│   └── skills/       (9)         ← /opc-orchestrator + 8 stage skills
│
├── xiaolai-methodology/          ← Li Xiaolai coaching methodology
│
└── NOTICE.md                     ← Attribution & license info / 来源与协议
```

### Skill Categories / 技能分类

| Category / 分类 | Skills | Highlights / 代表 skill |
|---|---|---|
| **Design / UI** | 25+ | `frontend-design`, `imagegen-frontend-web`, `imagegen-frontend-mobile`, `huashu-design`, `industrial-brutalist-ui`, `minimalist-ui`, `gpt-taste` |
| **Workflow / 工作流** | 30+ | `autopilot`, `ralph`, `team`, `ultrawork`, `ultraqa`, `ralplan`, `tdd-guardian:*` |
| **Memory / 记忆** | 40+ | `gbrain-*` series, `notebooklm`, `wiki`, `echo-sleuth:*`, `decision-tracker` |
| **Browser / 浏览器** | 15+ | `browse`, `bb-browser`, `bb-browser-openclaw`, `connect-chrome`, `qa`, `playwright-*` |
| **Planning / 规划** | 20+ | `plan-ceo-review`, `plan-eng-review`, `plan-design-review`, `interview-me`, `office-hours` |
| **Quality / 质量** | 25+ | `audit`, `cso`, `review`, `verify`, `test-coverage`, `code-review-and-quality` |
| **Lark / 飞书** | 25 | Full Feishu CLI integration: docs, sheets, base, im, calendar, OKR, approval ... |
| **AFA (DTC)** | 30 | `afa-foundation`, `afa-creative`, `afa-paid`, `afa-organic`, `afa-cx`, `afa-dashboard` ... |
| **HyperFrames** | 13 | Video composition with audio-reactive animation, transitions, TTS, ASS captions |
| **Real-Engineer** | 14 | `real-engineer-tdd`, `real-engineer-diagnose`, `real-engineer-grill-me`, ... |
| **OPC** | 9 | One-person business: niche → MVP → conversion → assets → dashboard |
| **Anthropic Official** | 5 | `pdf`, `xlsx`, `pptx`, `docx`, `mcp-builder` |

→ Full list: [`skills/`](skills/) directory

---

## 🔌 Required External Tools / 需要的外部工具

| Tool | Why | Install |
|---|---|---|
| **Claude Code** | The host / 宿主 | https://claude.com/claude-code |
| [**OpenSpec**](https://github.com/Fission-AI/OpenSpec) | Spec-Driven Trio layer 1 | `npm i -g @fission-ai/openspec@latest` |
| [**Superpowers**](https://github.com/obra/superpowers) | Spec-Driven Trio layer 2 | `/plugin install superpowers@superpowers-dev` |
| [gstack](https://github.com/garrytan/gstack) | Browser automation, QA, deploy | Vendored in `skills/gstack/` |
| [gbrain](https://github.com/garrytan/gbrain) | Persistent memory + knowledge graph | `bun install -g github:garrytan/gbrain` |
| [lark-cli](https://github.com/larksuite/larkutil-cli) | Feishu/Lark CLI for `lark-*` skills | `npm i -g @larksuite/larkutil-cli` |
| [gitleaks](https://github.com/gitleaks/gitleaks) | Pre-commit secret scan (optional) | `brew install gitleaks` |

---

## 🎯 Recommended Starting Points / 推荐起步路径

### For new Claude Code users / 新手

1. Copy `my-config/CLAUDE.md` to `~/.claude/CLAUDE.md` — get the 7 Cardinal Rules
2. Install the trio: OpenSpec + Superpowers + agent-skills (commands above)
3. Try `/spec add a simple feature` in any project — experience the full SDD flow

### For experienced users / 有经验用户

- Cherry-pick rules from `my-config/rules/` — especially `intent-defaults.md`, `verification.md`, `secrets-firewall.md`
- Browse `skills/_collections/` for full third-party repos to study
- Read [`my-config/rules/spec-driven-trio.md`](my-config/rules/spec-driven-trio.md) for the task-routing matrix

### For specific workflows / 特定工作流

| If you want... / 想要... | Try... / 试试 |
|---|---|
| Spec-driven development | `/spec <feature>` |
| Long-form writing | `/xiaolai-write` |
| One-person business strategy | `/opc-orchestrator` |
| Multi-agent parallel work | `/ultrawork` or `/team` |
| Autonomous loop until done | `/autopilot` or `/ralph` |
| Feishu/Lark integration | `lark-doc`, `lark-base`, `lark-im` skills |
| DTC marketing | `afa-*` skill series |
| Video composition | `hyperframes-*` skill series |
| Persistent project memory | `gbrain-*` skill series |

---

## 🛡 Privacy & Security / 隐私与安全

This repo is **CI-scanned** for:
- ❌ Real credentials (sk-/ghp_/AKIA/cli_a/AIza/xoxb patterns)
- ❌ Nested `.git` directories (which silently break content sync)
- ❌ Missing `name:` / `description:` frontmatter on any SKILL.md
- ❌ Build artifacts (`dist/`, `build/`, `node_modules/`, `browser_state/`)

All `.env*`, `*.pem`, `*.key`, `id_rsa*`, `credentials.*`, `secrets.*`, `.aws/`, `.ssh/` are blocked by `.gitignore` **and** by the `env-guard.sh` hook at runtime (see `my-config/hooks/`).

本仓库每次 push 都跑 CI 扫真凭证、嵌套 .git、缺失 frontmatter、build 产物;运行时由 hook 双重防御。

→ See full security model: [`my-config/rules/secrets-firewall.md`](my-config/rules/secrets-firewall.md)

---

## 🤝 Contributing / 贡献

This is a personal config repo, but PRs/issues are welcome if you:

- 找到了 bug / 错位 / 死链
- 有 skill 建议想加
- 发现了真凭证泄漏(请直接邮件 issue,不要 PR)

Before contributing, please:
1. Run `bash tools/validate-skills.sh` locally
2. Make sure new skills have `SKILL.md` with `name:` and `description:` YAML frontmatter
3. No real secrets in test fixtures — use `<placeholder>` or `YOUR_KEY_HERE`

---

## 📜 License / 协议

- **My config (`my-config/`, `skills/_collections/orphan-skills/`, README, rules)** — MIT
- **`opc-methodology/`** — CC-BY-NC-SA (Easy Chen, attribution required, non-commercial)
- **`xiaolai-methodology/`** — Educational use, see `xiaolai-methodology/LICENSE`
- **Third-party skills in `skills/` and `skills/_collections/`** — Each skill keeps its original license. See [`NOTICE.md`](NOTICE.md) for full attribution.

每个 skill 保留原作者协议,详见 NOTICE.md。

---

## 🙏 Acknowledgments / 致谢

This repo wouldn't exist without:

- [@addyosmani](https://github.com/addyosmani) — The original 23 agent-skills
- [@obra](https://github.com/obra) — Superpowers plugin
- [@Fission-AI](https://github.com/Fission-AI) — OpenSpec
- [@garrytan](https://github.com/garrytan) — gstack & gbrain
- [@anthropics](https://github.com/anthropics) — Claude Code itself + official skills
- [@easychen](https://github.com/easychen) — One-person business methodology
- [@xiaolai](https://github.com/xiaolai) — Self-taught everything methodology
- [@mattpocock](https://github.com/mattpocock) — real-engineer skills
- [@wshobson](https://github.com/wshobson) — agents collection
- [@1natsu172](https://github.com/1natsu172), [@d-kimuson](https://github.com/d-kimuson), [@rghamilton3](https://github.com/rghamilton3), [@JamesPrial](https://github.com/JamesPrial), [@ComposioHQ](https://github.com/ComposioHQ), [@travisvn](https://github.com/travisvn), [@FrancyJGLisboa](https://github.com/FrancyJGLisboa) — dotfiles and skill collections in `_collections/`

— Tony Sheng ([@shengdabai](https://github.com/shengdabai))
