---
description: CLI 工具与外部资源速查：飞书、Obsidian、GetNote、Context7、Firecrawl、端口管理、会话恢复与归档检索。
---

# CLI Tools 与外部资源

**用外部资源前先按本表选工具,并确认该工具在本机真的装着;本表没列的能力不要凭印象编命令。**

**Why**:这些工具的命令名、参数和认证方式各不相同且会变,凭印象编出来的命令要么报错要么静默做错事(典型:用 WebFetch 抓微信链接,拿回一张反爬提示页当正文)。本表只记「本机实测可用」的入口,失效的显式标注。

## 文字工具

- **飞书 (Lark)**: `lark-cli` — 官方 CLI,覆盖 IM/文档/表格/日历等。需先 `lark-cli config init` + `lark-cli auth login --recommend` 配置凭证
- **Obsidian**: 本地 Markdown vault 在 `~/Documents/Tony`。已配 MCP(`mcp__obsidian`,基于 `obsidian-mcp` npm 包),提供 read/edit/create/delete-note + search-vault + tag 管理,优先用 MCP 工具而非裸文件操作
- **GetNote**: 已配置 MCP(`mcp__getnote`),200h 教学录音存储于此
- **NotebookLM**: `nlm` — 社区 CLI,需先 `nlm login` 提取 cookies。支持笔记本/源/音频管理

## 视频工具

> 即梦(`dreamina`)/ PixVerse(`pixverse`)/ LiblibAI 近 30 天零触发,详细用法已移出常驻。用前先 `which dreamina pixverse` 确认装没装——`~/.dreamina_cli/` 已不存在(2026-08-18 核实)。PixVerse:`pixverse auth login` 后 `pixverse --help`;LiblibAI:npm SDK,HMAC 签名。

## Karpathy LLM Wiki(⚠️ 未建,2026-08-18 核实)

`~/wiki/` **不存在**,本机没有这套知识库。要用时先建目录再回来启用本节;在那之前**不要**输出任何 `~/wiki/...` 路径的读写指令。

替代:本机现成的知识库是 Obsidian vault(`~/Documents/Tony`,走 `mcp__obsidian`)和想法工坊(`~/Desktop/02-学习资料/00-想法工坊/`,走 `forge`),两者都实测可用。

## Context7 MCP

When working with external libraries or frameworks, use context7 MCP to look up up-to-date documentation. Call `mcp__context7__resolve-library-id` first to get the library ID, then `mcp__context7__get-library-docs` to fetch the docs.

## Firecrawl MCP — 微信公众号文章抓取

看到 `mp.weixin.qq.com/s/...` 链接,默认用 `mcp__firecrawl__firecrawl_scrape` 抓取,参数:
- `formats: ["markdown"]`
- `onlyMainContent: true`(去掉关注按钮、底部推荐等噪音)

WebFetch 抓微信文章会被反爬挡住,只返回"环境异常"提示页,**不要用 WebFetch 抓微信链接**。

API key 存在 `~/.config/firecrawl/.env`,settings.json 启动 MCP 时自动 source。免费额度 500 次/月。

非微信网页抓取也优先用 firecrawl(自带 stealth proxy + markdown 转换)。

## Port Whisperer

本地端口管理工具,已全局安装。启动新 dev server 前先用 `ports` 检查端口占用,避免冲突。

- `ports` — 查看所有开发端口
- `ports <port>` — 查看某端口详情
- `ports kill <port>` — 释放端口
- `ports clean` — 清理僵尸进程
- `ports watch` — 实时监控

启动 dev server 时,若默认端口已被占用,自动选择下一个可用端口(如 3000→3001→3002)。

## 通知系统

A macOS notification is sent automatically when Claude finishes a task (Stop hook).

## 会话恢复 / 归档(本机工具)

- `recover` — 重开重启前所有 Claude tab。菜单模式(默认,粘贴 cd+resume)或 `recover --auto`(模拟键盘自动开,需辅助功能授权)。详见 memory `reference_ghostty-session-recover`
- `ai-search "关键词"` — 跨 Claude/Codex 历史全文搜。详见 memory `reference_ai-archive-system`
- 注:两者都依赖 hook/launchd,新开会话才登记;改 settings.json 后当前会话不生效

## GetNote · YouTube 逐字稿一句话同步

当上下文指向 GetNote 知识库 `Youtube视频逐字稿`,Tony 只说「更新」「同步」「优化该知识库」或同义表达时,直接加载并完整执行 `~/.agents/skills/youtube-script-sync/SKILL.md`。目标固定 `topic_id=YkWaVRqY`;先 dry-run,再顺序创建或更新父录音笔记的 `YT逐字稿` 子笔记,最后回读并做 missing/duplicate/幂等核验。不得覆盖源录音,不得把第三方录音写成 Tony 第一人称,不得承诺播放量或涨粉。
