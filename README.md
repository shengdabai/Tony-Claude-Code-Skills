# 🛠️ Tony's Claude Code Skills, Agents & Codex Workflow Collection

**[English](#english) | [中文](#中文)**

[![Last commit](https://img.shields.io/github/last-commit/shengdabai/Tony-Claude-Code-Skills?logo=github)](https://github.com/shengdabai/Tony-Claude-Code-Skills/commits)
[![Stars](https://img.shields.io/github/stars/shengdabai/Tony-Claude-Code-Skills?style=social)](https://github.com/shengdabai/Tony-Claude-Code-Skills/stargazers)
[![Follow @shengdabai](https://img.shields.io/github/followers/shengdabai?style=social)](https://github.com/shengdabai)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## English

> A curated, battle-tested mirror of my day-to-day AI workflow — **320+ Claude Code skills, 9 agents, 39 slash commands, sanitized configs, and a Codex bridge** — synced straight from my live setup and auto-indexed so the README never goes stale.

### Why this repo

I'm a full-time Chinese-language teacher (6,000+ students) building AI + teaching tools in public. Everything I lean on inside Claude Code and Codex every day — skills, agents, commands, hooks, MCP snapshots, and a few full methodology books — lives here so it's reproducible, browsable, and reusable. Nothing is invented for show: it's whatever I actually run.

### What it is

- **Skills** — the largest piece: reusable capability folders (`SKILL.md` + assets) covering DTC e-commerce, knowledge-brain ops, Lark/Feishu automation, frontend/design, video, writing, security, and more.
- **Agents & commands** — my Claude Code sub-agents and slash commands, plus the rules / hooks / output-styles that wire them together.
- **Codex workflow** — the config and bridge that let the same skill surface drive Codex CLI alongside Claude Code.

### ✨ What's inside

The skill index below is generated **directly from `skills/`** — so the counts are real, not aspirational.

| Family | Count | What it does |
| --- | --- | --- |
| `gbrain-*` | 40 | Personal knowledge-brain ops — ingest, enrich, query, maintain |
| `afa-*` | 30 | Full-funnel DTC / independent-site operating system |
| `lark-*` | 26 | Feishu / Lark automation — docs, sheets, IM, calendar, base |
| `hyperframes-*` | 15 | HTML-based video composition, captions, transitions, motion |
| `real-engineer-*` | 14 | Engineering discipline — TDD, diagnose, grill, handoff |
| `opc-*` | 9 | One-person-company methodology (niche → MVP → ops review) |
| standalone | 170+ | frontend/design, browsing, research, security, writing, MCP-building, and many single-purpose skills |

- **~320 skill folders** in total (312 ship a `SKILL.md`).
- **`skills/_collections/`** — 19 vendored upstream collections kept for reference (dotfiles, awesome-skill lists, superpowers, etc.), namespaced under `_collections/` so they never collide with my own skills.
- **`my-config/`** — 9 agents, 39 commands, hooks, rules, output-styles, and MCP snapshots.
- **`opc-methodology/` & `xiaolai-methodology/`** — full methodology mdBooks with their own bundled skills.

### 🧱 How it's organized

```
skills/              ~320 skill folders (each: SKILL.md + assets)
  _collections/      19 vendored upstream skill collections (reference)
my-config/           agents, commands, hooks, rules, output-styles, mcp-servers
opc-methodology/     one-person-company methodology book + skills
xiaolai-methodology/ writing/learning methodology book + skill
config/              sanitized hooks & MCP config snapshots
tools/               sync helpers + generate-readme.js (auto-index)
mcp-servers/         MCP server notes
install.sh           helper to drop skills into your ~/.claude
```

### 🚀 How to use these skills

A skill is a self-contained folder with a `SKILL.md`. To use one, copy its folder into your Claude Code skills directory:

```bash
# Clone the repo
git clone https://github.com/shengdabai/Tony-Claude-Code-Skills.git
cd Tony-Claude-Code-Skills

# Copy a single skill into your personal Claude Code setup
cp -R skills/<skill-name> ~/.claude/skills/

# …or use the bundled helper
bash install.sh
```

Restart Claude Code (or start a new session) and the skill becomes discoverable. Each `SKILL.md` frontmatter describes when it triggers. Skills are model-agnostic — they work in Claude Code and, via the Codex bridge in `my-config/`, in Codex CLI too.

### 📖 Browse the index

There's no separate site — **browse the live skill index right here**: the table further down (and in [`skills/`](skills/)) is auto-generated from the directory on every sync, so it always matches what's actually published.

### 🗺️ Status

Active and continuously synced from my real setup. Skills come and go as my workflow evolves; the auto-index keeps this README honest. Treat it as a working mirror, not a frozen release.

### 🤝 Connect & about

I build AI + Chinese-teaching tools in public. If any of this saves you time, a ⭐ **Star** and a **Follow [@shengdabai](https://github.com/shengdabai)** genuinely help.

Sibling repos worth a look:

- **[everything-claude-code](https://github.com/shengdabai/everything-claude-code)** — broader Claude Code resource hub
- **[claude-code-config](https://github.com/shengdabai/claude-code-config)** — my Claude Code configuration
- **Tony-claude-plugins** — private Claude Code plugin marketplace

> 🤖 **Maintainer note:** this README is also produced by [`tools/generate-readme.js`](tools/generate-readme.js), which rebuilds the skill index from `skills/` during `bash tools/config-sync.sh`. If you regenerate it, the prose above will be replaced by the generator's template — keep both in sync (or update the template in `generate-readme.js`).

### License

MIT — see [LICENSE](LICENSE). Individual skills under `skills/_collections/` and the methodology folders may retain their own upstream licenses; see each folder and [NOTICE.md](NOTICE.md).

---

## 中文

> 一份精选、经过实战检验的日常 AI 工作流镜像 —— **320+ 个 Claude Code 技能、9 个 agent、39 个 slash 命令、脱敏配置，以及一座 Codex 桥** —— 全部从我的实时环境同步而来，并自动建立索引，让 README 永不过时。

### 为什么有这个仓库

我是一名全职中文老师（6000+ 学员），在公开构建 AI + 教学工具。我每天在 Claude Code 和 Codex 里真正依赖的一切 —— 技能、agent、命令、hooks、MCP 快照，以及几本完整的方法论书 —— 都放在这里，便于复现、浏览和复用。没有一项是为了好看而编造的：全是我实际在跑的东西。

### 这是什么

- **Skills（技能）** —— 占比最大：可复用的能力目录（`SKILL.md` + 资源），覆盖 DTC 电商、知识脑运维、飞书/Lark 自动化、前端/设计、视频、写作、安全等。
- **Agents 与命令** —— 我的 Claude Code 子 agent 和 slash 命令，以及把它们串起来的 rules / hooks / output-styles。
- **Codex 工作流** —— 让同一套技能面也能驱动 Codex CLI（与 Claude Code 并行）的配置与桥接。

### ✨ 里面有什么

下面的技能索引**直接从 `skills/` 生成** —— 所以数字是真实的，不是吹出来的。

| 系列 | 数量 | 作用 |
| --- | --- | --- |
| `gbrain-*` | 40 | 个人知识脑运维 —— 摄入、富化、查询、维护 |
| `afa-*` | 30 | DTC / 独立站全链路操盘系统 |
| `lark-*` | 26 | 飞书 / Lark 自动化 —— 文档、表格、IM、日历、多维表 |
| `hyperframes-*` | 15 | 基于 HTML 的视频合成、字幕、转场、动效 |
| `real-engineer-*` | 14 | 工程纪律 —— TDD、诊断、拷问、交接 |
| `opc-*` | 9 | 一人企业方法论（利基 → MVP → 经营复盘） |
| 独立技能 | 170+ | 前端/设计、浏览、研究、安全、写作、MCP 构建等众多单一用途技能 |

- 总计 **约 320 个技能目录**（其中 312 个带 `SKILL.md`）。
- **`skills/_collections/`** —— 19 个保留作参考的上游技能合集（dotfiles、awesome 清单、superpowers 等），统一收在 `_collections/` 下，绝不与我自己的技能冲突。
- **`my-config/`** —— 9 个 agent、39 个命令，以及 hooks、rules、output-styles、MCP 快照。
- **`opc-methodology/` 与 `xiaolai-methodology/`** —— 完整的方法论 mdBook，各自附带专属技能。

### 🧱 目录结构

```
skills/              约 320 个技能目录（每个含 SKILL.md + 资源）
  _collections/      19 个上游技能合集（参考用）
my-config/           agents、commands、hooks、rules、output-styles、mcp-servers
opc-methodology/     一人企业方法论书 + 技能
xiaolai-methodology/ 写作/学习方法论书 + 技能
config/              脱敏后的 hooks 与 MCP 配置快照
tools/               同步脚本 + generate-readme.js（自动索引）
mcp-servers/         MCP 服务器说明
install.sh           把技能装进 ~/.claude 的辅助脚本
```

### 🚀 如何使用这些技能

每个技能都是一个含 `SKILL.md` 的自包含目录。使用时，把对应目录复制到你的 Claude Code 技能目录即可：

```bash
# 克隆仓库
git clone https://github.com/shengdabai/Tony-Claude-Code-Skills.git
cd Tony-Claude-Code-Skills

# 把单个技能复制到你的 Claude Code 环境
cp -R skills/<skill-name> ~/.claude/skills/

# …或使用自带的辅助脚本
bash install.sh
```

重启 Claude Code（或开新会话），技能即可被发现。每个 `SKILL.md` 的 frontmatter 描述了它的触发时机。技能与模型无关 —— 可在 Claude Code 中使用，并通过 `my-config/` 里的 Codex 桥接在 Codex CLI 中使用。

### 📖 浏览索引

没有单独的站点 —— **直接在这里浏览实时技能索引**：下方的表格（以及 [`skills/`](skills/) 目录）在每次同步时都从目录自动生成，因此始终与真正发布的内容一致。

### 🗺️ 状态

活跃维护，持续从我的真实环境同步。技能会随我的工作流演进而增删；自动索引保证这份 README 诚实可信。请把它当作一个动态镜像，而非冻结的发行版。

### 🤝 关于 & 联系

我在公开构建 AI + 中文教学工具。如果这些东西帮你省了时间，一个 ⭐ **Star** 和 **关注 [@shengdabai](https://github.com/shengdabai)** 对我真的很有帮助。

值得一看的姊妹仓库：

- **[everything-claude-code](https://github.com/shengdabai/everything-claude-code)** —— 更广的 Claude Code 资源汇总
- **[claude-code-config](https://github.com/shengdabai/claude-code-config)** —— 我的 Claude Code 配置
- **Tony-claude-plugins** —— 私有 Claude Code 插件市场

> 🤖 **维护者提示：** 本 README 同时由 [`tools/generate-readme.js`](tools/generate-readme.js) 生成，它会在 `bash tools/config-sync.sh` 时从 `skills/` 重建技能索引。若你重新生成，上面的正文会被生成器模板覆盖 —— 请保持两者同步（或直接更新 `generate-readme.js` 里的模板）。

### 许可证

MIT —— 见 [LICENSE](LICENSE)。`skills/_collections/` 下的各个技能以及方法论目录可能保留其上游许可证；详见各目录与 [NOTICE.md](NOTICE.md)。
