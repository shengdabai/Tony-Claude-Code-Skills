# Tony's Claude Code Skills & Codex Workflow Collection

[English](#english) | [中文](#中文)

> This README is generated from the repository contents. The skill index below is always built from `skills/`, so newly synced skills can be browsed directly from the README.
>
> 这个 README 根据仓库内容自动生成。下面的技能索引直接来自 `skills/` 目录，因此每次同步后的技能都能在 README 中直接查看。

## English

This repository mirrors my day-to-day AI workflow assets for Claude Code and Codex.

- `skills/` stores the published skill folders that I sync from my local setup.
- `config/` stores sanitized configuration snapshots such as MCP settings and hooks.
- `tools/` stores the sync helpers that copy local skills into the repo and regenerate this README.

### Why This README Stays Accurate

- The skill index is generated from the actual repository directories, not maintained by hand.
- Running `bash tools/config-sync.sh` or `bash tools/skill-sync.sh` regenerates the README after syncing files.
- That means whatever is pushed under `skills/` is also visible here for quick browsing.

### Repository Snapshot

- Total skill folders: **73**
- MCP servers in sanitized config: **10**
- Main sync command: `bash tools/config-sync.sh`

## 中文

这个仓库用于镜像我日常在 Claude Code 和 Codex 中使用的 AI 工作流资产。

- `skills/` 保存从本地环境同步出来并发布到仓库的技能目录。
- `config/` 保存已经脱敏的配置快照，例如 MCP 设置和 hooks。
- `tools/` 保存同步脚本，以及生成本 README 的辅助工具。

### 为什么 README 能保持同步

- 技能索引是根据仓库里真实存在的目录自动生成的，不再手工维护。
- 运行 `bash tools/config-sync.sh` 或 `bash tools/skill-sync.sh` 时，会在同步后自动重建 README。
- 这样只要新的技能被推送到 `skills/`，README 里也会同步出现，便于查看和检索。

### 仓库快照

- 技能目录总数：**73**
- 已脱敏配置中的 MCP 服务器数量：**10**
- 主要同步命令：`bash tools/config-sync.sh`

## Skill Index / 技能索引

Auto-generated from `skills/`. Descriptions are extracted from each skill's own documentation when available.

根据 `skills/` 自动生成。描述优先取自每个技能自身的文档。

| Skill | Description | Folder |
| --- | --- | --- |
| [`agent-builder`](skills/agent-builder/) | Design and build AI agents for any domain. Use when users: (1) ask to "create an agent", "build an assistant", or "design an AI system" (2) want to understand agent architecture,... | [Open](skills/agent-builder/) |
| [`architecture-diagram`](skills/architecture-diagram/) | Create professional, dark-themed architecture diagrams as standalone HTML files with SVG graphics. Use when the user asks for system architecture diagrams, infrastructure diagrams... | [Open](skills/architecture-diagram/) |
| [`auto-browser`](skills/auto-browser/) | 自动智能网页内容获取工具，根据URL特征智能选择最佳工具组合。 | [Open](skills/auto-browser/) |
| [`autoplan`](skills/autoplan/) | Auto-review pipeline — reads the full CEO, design, eng, and DX review skills from disk and runs them sequentially with auto-decisions using 6 decision principles. Surfaces taste d... | [Open](skills/autoplan/) |
| [`autoresearch`](skills/autoresearch/) | Autonomous ML research agent inspired by Karpathy's autoresearch. Given a training codebase, the agent runs continuous experimentation loops: modify model code, train for 5 minute... | [Open](skills/autoresearch/) |
| [`bb-browser`](skills/bb-browser/) | 网页爬取、爬虫、反爬、scrape、crawler、spider、anti-detection、headless browser、web scraping 工具。通过真实浏览器 + 用户登录态，获取公域和私域信息。可访问任意网页、内部系统、登录后页面，执行表单填写、信息提取、页面操作。支持 site 系统（36 平台 126 命令一键调用）、带登录态的 f... | [Open](skills/bb-browser/) |
| [`benchmark`](skills/benchmark/) | Performance regression detection using the browse daemon. Establishes baselines for page load times, Core Web Vitals, and resource sizes. Compares before/after on every PR. Tracks... | [Open](skills/benchmark/) |
| [`browse`](skills/browse/) | Fast headless browser for QA testing and site dogfooding. Navigate any URL, interact with elements, verify page state, diff before/after actions, take annotated screenshots, check... | [Open](skills/browse/) |
| [`canary`](skills/canary/) | Post-deploy canary monitoring. Watches the live app for console errors, performance regressions, and page failures using the browse daemon. Takes periodic screenshots, compares ag... | [Open](skills/canary/) |
| [`careful`](skills/careful/) | Safety guardrails for destructive commands. Warns before rm -rf, DROP TABLE, force-push, git reset --hard, kubectl delete, and similar destructive operations. User can override ea... | [Open](skills/careful/) |
| [`checkpoint`](skills/checkpoint/) | Save and resume working state checkpoints. Captures git state, decisions made, and remaining work so you can pick up exactly where you left off — even across Conductor workspace h... | [Open](skills/checkpoint/) |
| [`code-to-course`](skills/code-to-course/) | Turn any codebase into a beautiful, interactive single-page HTML course with bilingual (Chinese/English) support. Use this skill whenever someone wants to create an interactive co... | [Open](skills/code-to-course/) |
| [`codex`](skills/codex/) | OpenAI Codex CLI wrapper — three modes. Code review: independent diff review via codex review with pass/fail gate. Challenge: adversarial mode that tries to break your code. Consu... | [Open](skills/codex/) |
| [`connect-chrome`](skills/connect-chrome/) | Launch GStack Browser — AI-controlled Chromium with the sidebar extension baked in. Opens a visible browser window where you can watch every action in real time. The sidebar shows... | [Open](skills/connect-chrome/) |
| [`cso`](skills/cso/) | Chief Security Officer mode. Infrastructure-first security audit: secrets archaeology, dependency supply chain, CI/CD pipeline security, LLM/AI security, skill supply chain scanni... | [Open](skills/cso/) |
| [`darwin-skill`](skills/darwin-skill/) | Autonomous skill optimizer inspired by Karpathy's autoresearch. Evaluates SKILL.md files using an 8-dimension rubric (structure + effectiveness), runs hill-climbing with git versi... | [Open](skills/darwin-skill/) |
| [`defuddle`](skills/defuddle/) | Extract clean markdown content from web pages using Defuddle CLI, removing clutter and navigation to save tokens. Use instead of WebFetch when the user provides a URL to read or a... | [Open](skills/defuddle/) |
| [`design-consultation`](skills/design-consultation/) | Design consultation: understands your product, researches the landscape, proposes a complete design system (aesthetic, typography, color, layout, spacing, motion), and generates f... | [Open](skills/design-consultation/) |
| [`design-html`](skills/design-html/) | Design finalization: generates production-quality Pretext-native HTML/CSS. Works with approved mockups from /design-shotgun, CEO plans from /plan-ceo-review, design review context... | [Open](skills/design-html/) |
| [`design-review`](skills/design-review/) | Designer's eye QA: finds visual inconsistency, spacing issues, hierarchy problems, AI slop patterns, and slow interactions — then fixes them. Iteratively fixes issues in source co... | [Open](skills/design-review/) |
| [`design-shotgun`](skills/design-shotgun/) | Design shotgun: generate multiple AI design variants, open a comparison board, collect structured feedback, and iterate. Standalone design exploration you can run anytime. Use whe... | [Open](skills/design-shotgun/) |
| [`devex-review`](skills/devex-review/) | Live developer experience audit. Uses the browse tool to actually TEST the developer experience: navigates docs, tries the getting started flow, times TTHW, screenshots error mess... | [Open](skills/devex-review/) |
| [`document-release`](skills/document-release/) | Post-ship documentation update. Reads all project docs, cross-references the diff, updates README/ARCHITECTURE/CONTRIBUTING/CLAUDE.md to match what shipped, polishes CHANGELOG voi... | [Open](skills/document-release/) |
| [`dream-memory`](skills/dream-memory/) | Consolidate recent logs, sessions, and existing memory files into durable topic memories, normalize dates, prune stale entries, and keep MEMORY.md short enough for prompt use. | [Open](skills/dream-memory/) |
| [`fireworks-tech-graph`](skills/fireworks-tech-graph/) | Use when the user wants to create any technical diagram - architecture, data flow, flowchart, sequence, agent/memory, or concept map - and export as SVG+PNG. Trigger on: "画图" "帮我画... | [Open](skills/fireworks-tech-graph/) |
| [`fit-coach`](skills/fit-coach/) | Professional fitness coach combining nutrition planning and adaptive training. Use when users mention fitness, workout, gym, exercise, diet, meal plan, weight loss, muscle gain, b... | [Open](skills/fit-coach/) |
| [`freeze`](skills/freeze/) | Restrict file edits to a specific directory for the session. Blocks Edit and Write outside the allowed path. Use when debugging to prevent accidentally "fixing" unrelated code, or... | [Open](skills/freeze/) |
| [`galaxy-ui`](skills/galaxy-ui/) | Browse and retrieve UI components from Uiverse Galaxy — 3,800+ HTML/CSS components including buttons, cards, inputs, loaders, checkboxes, toggles, tooltips, notifications, forms,... | [Open](skills/galaxy-ui/) |
| [`gstack`](skills/gstack/) | Fast headless browser for QA testing and site dogfooding. Navigate pages, interact with elements, verify state, diff before/after, take annotated screenshots, test responsive layo... | [Open](skills/gstack/) |
| [`gstack-upgrade`](skills/gstack-upgrade/) | Upgrade gstack to the latest version. Detects global vs vendored install, runs the upgrade, and shows what's new. Use when asked to "upgrade gstack", "update gstack", or "get late... | [Open](skills/gstack-upgrade/) |
| [`guard`](skills/guard/) | Full safety mode: destructive command warnings + directory-scoped edits. Combines /careful (warns before rm -rf, DROP TABLE, force-push, etc.) with /freeze (blocks edits outside a... | [Open](skills/guard/) |
| [`health`](skills/health/) | Code quality dashboard. Wraps existing project tools (type checker, linter, test runner, dead code detector, shell linter), computes a weighted composite 0-10 score, and tracks tr... | [Open](skills/health/) |
| [`history`](skills/history/) | Browse Claude Code conversation history. List past sessions with concise summaries, view full conversations, and search across all sessions. | [Open](skills/history/) |
| [`import-to-obsidian`](skills/import-to-obsidian/) | Use when user wants to save web content, articles, videos, or any URL to Obsidian vault. Auto-triggers on keywords like "obsidian", "import", "clip", "save to vault", "知识库", "收藏".... | [Open](skills/import-to-obsidian/) |
| [`investigate`](skills/investigate/) | Systematic debugging with root cause investigation. Four phases: investigate, analyze, hypothesize, implement. Iron Law: no fixes without root cause. Use when asked to "debug this... | [Open](skills/investigate/) |
| [`json-canvas`](skills/json-canvas/) | Create and edit JSON Canvas files (.canvas) with nodes, edges, groups, and connections. Use when working with .canvas files, creating visual canvases, mind maps, flowcharts, or wh... | [Open](skills/json-canvas/) |
| [`kairos-lite`](skills/kairos-lite/) | Build a lightweight proactive mode with scheduled checks, sleep intervals, concise user briefs, and expiry safeguards so an agent can work in the background without becoming an un... | [Open](skills/kairos-lite/) |
| [`land-and-deploy`](skills/land-and-deploy/) | Land and deploy workflow. Merges the PR, waits for CI and deploy, verifies production health via canary checks. Takes over after /ship creates the PR. Use when: "merge", "land", "... | [Open](skills/land-and-deploy/) |
| [`learn`](skills/learn/) | Manage project learnings. Review, search, prune, and export what gstack has learned across sessions. Use when asked to "what have we learned", "show learnings", "prune stale learn... | [Open](skills/learn/) |
| [`limit-continue-work`](skills/limit-continue-work/) | 当 Claude Code 遇到 5 小时用量限制（rate limit）时，自动等待用量重置并继续执行之前的任务。 保存任务快照 + 使用 CronCreate 原生定时任务 + 自动恢复执行。 Use when: "limit continue", "auto continue", "等限制重置", "自动继续", "用量限制后继续", "设置限制后自... | [Open](skills/limit-continue-work/) |
| [`llm-council`](skills/llm-council/) | LLM Council — Karpathy 式多模型议会。5 个 AI 顾问并行回答问题， 匿名互评打分，主席综合最佳答案。触发：/llm-council, /council, "开会讨论", "council", "议会模式" | [Open](skills/llm-council/) |
| [`logo-generator`](skills/logo-generator/) | Generate professional SVG logos and high-end showcase images. Use when the user wants to: (1) Create a logo or icon for their product/brand, (2) Generate logo design concepts base... | [Open](skills/logo-generator/) |
| [`memory-extractor`](skills/memory-extractor/) | Extract durable memories from recent conversation turns into user, feedback, project, and reference categories while avoiding stale code-state facts. | [Open](skills/memory-extractor/) |
| [`obsidian-bases`](skills/obsidian-bases/) | Create and edit Obsidian Bases (.base files) with views, filters, formulas, and summaries. Use when working with .base files, creating database-like views of notes, or when the us... | [Open](skills/obsidian-bases/) |
| [`obsidian-cli`](skills/obsidian-cli/) | Interact with Obsidian vaults using the Obsidian CLI to read, create, search, and manage notes, tasks, properties, and more. Also supports plugin and theme development with comman... | [Open](skills/obsidian-cli/) |
| [`obsidian-markdown`](skills/obsidian-markdown/) | Create and edit Obsidian Flavored Markdown with wikilinks, embeds, callouts, properties, and other Obsidian-specific syntax. Use when working with .md files in Obsidian, or when t... | [Open](skills/obsidian-markdown/) |
| [`office-hours`](skills/office-hours/) | YC Office Hours — two modes. Startup mode: six forcing questions that expose demand reality, status quo, desperate specificity, narrowest wedge, observation, and future-fit. Build... | [Open](skills/office-hours/) |
| [`omc-reference`](skills/omc-reference/) | OMC agent catalog, available tools, team pipeline routing, commit protocol, and skills registry. Auto-loads when delegating to agents, using OMC tools, orchestrating teams, making... | [Open](skills/omc-reference/) |
| [`open-gstack-browser`](skills/open-gstack-browser/) | Launch GStack Browser — AI-controlled Chromium with the sidebar extension baked in. Opens a visible browser window where you can watch every action in real time. The sidebar shows... | [Open](skills/open-gstack-browser/) |
| [`pair-agent`](skills/pair-agent/) | Pair a remote AI agent with your browser. One command generates a setup key and prints instructions the other agent can follow to connect. Works with OpenClaw, Hermes, Codex, Curs... | [Open](skills/pair-agent/) |
| [`plan-ceo-review`](skills/plan-ceo-review/) | CEO/founder-mode plan review. Rethink the problem, find the 10-star product, challenge premises, expand scope when it creates a better product. Four modes: SCOPE EXPANSION (dream... | [Open](skills/plan-ceo-review/) |
| [`plan-design-review`](skills/plan-design-review/) | Designer's eye plan review — interactive, like CEO and Eng review. Rates each design dimension 0-10, explains what would make it a 10, then fixes the plan to get there. Works in p... | [Open](skills/plan-design-review/) |
| [`plan-devex-review`](skills/plan-devex-review/) | Interactive developer experience plan review. Explores developer personas, benchmarks against competitors, designs magical moments, and traces friction points before scoring. Thre... | [Open](skills/plan-devex-review/) |
| [`plan-eng-review`](skills/plan-eng-review/) | Eng manager-mode plan review. Lock in the execution plan — architecture, data flow, diagrams, edge cases, test coverage, performance. Walks through issues interactively with opini... | [Open](skills/plan-eng-review/) |
| [`planning-with-files`](skills/planning-with-files/) | Implements Manus-style file-based planning to organize and track progress on complex tasks. Creates task_plan.md, findings.md, and progress.md. Use when asked to plan out, break d... | [Open](skills/planning-with-files/) |
| [`qa`](skills/qa/) | Systematically QA test a web application and fix bugs found. Runs QA testing, then iteratively fixes bugs in source code, committing each fix atomically and re-verifying. Use when... | [Open](skills/qa/) |
| [`qa-only`](skills/qa-only/) | Report-only QA testing. Systematically tests a web application and produces a structured report with health score, screenshots, and repro steps — but never fixes anything. Use whe... | [Open](skills/qa-only/) |
| [`remote-control`](skills/remote-control/) | Claude Code 官方远程控制 — 将终端 Claude Code 会话同步到手机/浏览器 Claude app。当用户说"远程控制"、"remote control"、"手机同步"、"手机连接"、"远程连接"等时触发。 | [Open](skills/remote-control/) |
| [`rename`](skills/rename/) | 重命名当前终端标签页。用法：/rename <名称> 设置后在整个会话中保持不变，不会被任何操作覆盖。 | [Open](skills/rename/) |
| [`retro`](skills/retro/) | Weekly engineering retrospective. Analyzes commit history, work patterns, and code quality metrics with persistent history and trend tracking. Team-aware: breaks down per-person c... | [Open](skills/retro/) |
| [`review`](skills/review/) | Pre-landing PR review. Analyzes diff against the base branch for SQL safety, LLM trust boundary violations, conditional side effects, and other structural issues. Use when asked t... | [Open](skills/review/) |
| [`risk-guard`](skills/risk-guard/) | Account ban risk monitor for Claude Code. Detects dangerous usage patterns that could trigger rate limiting, account suspension, or banning. Auto-triggers on session start. Manual... | [Open](skills/risk-guard/) |
| [`setup-browser-cookies`](skills/setup-browser-cookies/) | Import cookies from your real Chromium browser into the headless browse session. Opens an interactive picker UI where you select which cookie domains to import. Use before QA test... | [Open](skills/setup-browser-cookies/) |
| [`setup-deploy`](skills/setup-deploy/) | Configure deployment settings for /land-and-deploy. Detects your deploy platform (Fly.io, Render, Vercel, Netlify, Heroku, GitHub Actions, custom), production URL, health check en... | [Open](skills/setup-deploy/) |
| [`ship`](skills/ship/) | Ship workflow: detect + merge base branch, run tests, review diff, bump VERSION, update CHANGELOG, commit, push, create PR. Use when asked to "ship", "deploy", "push to main", "cr... | [Open](skills/ship/) |
| [`structured-context-compressor`](skills/structured-context-compressor/) | Compress a long agent conversation into a nine-part continuation summary that preserves request, files, errors, user messages, current work, and the next aligned step. | [Open](skills/structured-context-compressor/) |
| [`swarm-coordinator`](skills/swarm-coordinator/) | Coordinate multiple agents by splitting work into research, synthesis, implementation, and verification, assigning ownership, and keeping the coordinator focused on integration ra... | [Open](skills/swarm-coordinator/) |
| [`twitter`](skills/twitter/) | Launch the X/Twitter Poster Agent to auto-create and publish tweets. Use when: user types /twitter, /x, wants to post tweets, create threads, write X content, or manage Twitter po... | [Open](skills/twitter/) |
| [`unfreeze`](skills/unfreeze/) | Clear the freeze boundary set by /freeze, allowing edits to all directories again. Use when you want to widen edit scope without ending the session. Use when asked to "unfreeze",... | [Open](skills/unfreeze/) |
| [`verification-gate`](skills/verification-gate/) | Run a read-only verification pass after implementation to check whether completion claims are real, validation actually ran, and obvious edge cases or regressions were missed. | [Open](skills/verification-gate/) |
| [`web-scraper`](skills/web-scraper/) | 智能三级降级网页内容提取。当用户发送 URL 链接并要求提取/阅读/总结网页内容时自动触发。 触发场景：用户发送任何 http/https URL 并期望获取其内容（非 GitHub PR/Issue，非搜索请求）。 例如："读取这篇文章"、"帮我看看这个链接"、"总结这个网页"、直接发 URL。 | [Open](skills/web-scraper/) |
| [`xiaolai`](skills/xiaolai/) | Xiaolai's Claude tools collection. Use when user types /xiaolai. Routes to: (1) claude-agent-sdk — Agent SDK reference for building autonomous AI agents, or (2) nlpm — Natural-Lan... | [Open](skills/xiaolai/) |
| [`youtube`](skills/youtube/) | Launch the YouTube Creator Agent to auto-generate videos. Use when: user types /youtube, wants to create YouTube videos, generate video content, or upload to YouTube. Keywords: yo... | [Open](skills/youtube/) |

## Sync Workflow / 同步方式

1. Update or add skills in the local Claude Code setup.
2. Run `bash tools/config-sync.sh` to sync skills, sanitized configs, and regenerate the README.
3. Review the diff, commit, and push.

1. 在本地 Claude Code 环境中新增或更新技能。
2. 运行 `bash tools/config-sync.sh`，同步 skills、脱敏配置，并重新生成 README。
3. 检查 diff 后提交并推送。

## License / 许可证

Individual skills may retain their own upstream licenses. Repository-level scripts and documentation in this repo follow the repository license.

各个技能可能保留其上游许可证；本仓库中的脚本与说明文档遵循仓库自身许可证。
