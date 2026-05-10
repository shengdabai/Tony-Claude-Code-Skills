# CLI Tools 与外部资源

## 文字工具

- **飞书 (Lark)**: `lark-cli` — 官方 CLI,覆盖 IM/文档/表格/日历等。需先 `lark-cli config init` + `lark-cli auth login --recommend` 配置凭证
- **Obsidian**: 本地 Markdown vault,通过文件系统直接操作。MCP 可选安装
- **GetNote**: 已配置 MCP(`mcp__getnote`),200h 教学录音存储于此
- **NotebookLM**: `nlm` — 社区 CLI,需先 `nlm login` 提取 cookies。支持笔记本/源/音频管理

## 视频工具

- **即梦 (Dreamina)**: `dreamina` — 字节官方 CLI,Skill 在 `~/.dreamina_cli/dreamina/SKILL.md`。文生图/文生视频/图生视频
- **PixVerse**: `pixverse` — 官方 CLI,需先 `pixverse auth login`。文生视频/转场/唇形同步/音效
- **LiblibAI**: 无 CLI,有 npm SDK `liblibai`,API 需 HMAC 签名认证

## Karpathy LLM Wiki

个人知识库在 `~/wiki/`,基于 Karpathy 的 LLM Wiki 模式。

- `raw/` — 不可变原始素材(文章、论文、录音转录)
- `wiki/` — LLM 生成维护的结构化页面(实体、概念、摘要、对比、分析)
- 三大操作:**Ingest**(摄入源文件→更新 wiki 多个页面)、**Query**(基于 wiki 回答问题)、**Lint**(健康检查)
- Schema 定义在 `~/wiki/CLAUDE.md`
- 搭配 Obsidian 实时浏览图谱视图

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
