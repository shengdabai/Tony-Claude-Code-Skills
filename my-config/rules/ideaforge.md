# 想法工坊 · HTML 深度页生成与自动归档

本地知识系统：引擎在 `~/Desktop/02-学习资料/00-想法工坊/`（IdeaForge），知识库根 = `~/Desktop/02-学习资料/`。把 想法/链接/图片 炼成专业可视化深度页 + 结合 Tony 背景的"能做什么"启发，全部本地存储、可检索。

**所有 AI 本地生成的 HTML 都走想法工坊流程**：用 `forge` 生成 → 自动落盘 `00-想法工坊/pages/` 并进 `pages.json` 索引；手写/外来的 html 一律分类整理进 `~/Desktop/02-学习资料/` 的编号子目录（01~11），由 PostToolUse hook 自动登记。

## 何时用
- 用户要"把某链接/想法/图片做成深度分析页/学习页/可视化页" → 用 `forge`，**不要手写一次性 html**。
- 用户要"把已有 html 纳入/导入知识系统" → `forge import`。

## 命令（全局 `forge`，任意目录可用）
- `forge "想法文字"` / `forge <url>` / `forge <图片路径>` — 生成深度页存入 `pages/`，自动带个性化启发板块、自动进索引、自动 open。
- `forge import <目录> [--copy] [--category=X] [--exclude=a,b]` — 批量纳入已有 html。不带 `--copy` 登记原路径；带则复制进 `pages/<分类>/`。也支持单个 .html。
- `forge serve` 或双击桌面「启动想法工坊.command」— 起 dashboard（http://127.0.0.1:8765，含搜索/分类折叠/分页，扛数千页面）。

## 自动归档（已配，无需手动维护索引）
PostToolUse hook `~/.claude/hooks/ideaforge-archive.sh`：任何写入的 `.html` 自动登记进系统（category=自动归档）。已排除：引擎目录 `00-想法工坊/` 自身 / tmp / node_modules / .git / .Trash / 待分类。所以"制作 html 默认保存在这个系统内"是自动保障的。

## 引擎与计费（重要）
- 默认 **codex**（省额度）。
- **2026-06-15 起 `claude -p` 走独立 $200 额度按 API 计费 → 勿设默认。**
- 离线免费兜底：ollama。

## 个性化
启发板块质量取决于 `~/Desktop/02-学习资料/00-想法工坊/profile.md`（Tony 画像）。启发不准 → 改 profile.md，不改引擎。

## 结构 / 维护
- 索引 `pages.json`：{slug,title,type,source,tags,category,createdAt,htmlPath}。
- 生成提示词 `engine/prompt.md`、视觉范本 `templates/golden.html`、设计契约 `SPEC.md`。
- 全局命令安装：`bash ~/Desktop/02-学习资料/00-想法工坊/install-forge.sh`（装到 ~/.local/bin/forge）。
- Codex 被派来改系统时读 `SPEC.md`。
