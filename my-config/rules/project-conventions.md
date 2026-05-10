# Project Conventions

汇总项目约定、批量操作、网络下载、MCP 保护、常见陷阱等通用规则。

## Project Conventions

- 大多数项目是双语的(中文/英文)— UI、README、文档默认支持两种语言,除非明确说不需要
- Python 项目默认用 `pipx` 或 `venv`,禁止裸 `pip install`(PEP 668)
- 启动 dev server 默认先检查端口占用(用 `ports`),避免冲突

## Batch Operations

- 任何批量操作(提取、生成、转换):先用 3-5 个样本验证逻辑正确,确认后再跑全量
- 批量处理管道:验证每一阶段的输出后再进入下一阶段,不要一口气跑到底才发现第一步就错了
- PDF 生成:**禁止并行 subprocess**,必须顺序生成。先用单文件 dry run 测试,再批量

## Working With Chinese Content

- Regex 处理中文文本必须考虑:全角标点(。．、:;)、编号格式混用(1. vs 1．vs (1))、字间空格(如 '听 力')
- 批量提取前必须用实际中文源文件测试 regex,不要用英文/数字假设
- 所有涉及中文的文件操作显式使用 UTF-8 编码

## Download & Network

- 大文件下载(Ollama models, datasets 等):使用支持断点续传的工具(`curl -C -`、`wget -c`、`huggingface-cli download`)
- 下载完成后必须验证(checksum 或 load test),不要假设成功
- 下载脚本必须包含重试逻辑(至少 3 次带退避)
- API 调用失败 3 次(403/rate limit/content filter):立即停止重试,提出 2 个绕过该 API 的替代方案
- **超过 1GB 的下载/部署必须先征得用户同意**(避免流量超量)

## MCP & Tool Protection

- 不要删除或禁用 MCP servers,除非用户明确要求
- 修改 `.claude/settings.json` 时保留所有现有 MCP 条目,只增改被请求的部分
- 依赖 MCP 工具前先测试可用性;准备 fallback 方案(如直接 API 调用)

## Common Pitfalls

- **沙箱环境**(n8n Code nodes, Chrome extensions 等):写代码前先调查可用 API,不要假设 process/fetch/fs 等 Node.js globals 可用
- **系统级任务**(窗口管理、工具配置等):先列 2-3 个方案对比,再选择实施,避免走错路浪费多轮迭代
- **API 集成**:先确认字段名/参数名的准确性,不要凭记忆猜测

## Quality Standards

- 构建/修改功能后,运行完整设计审计:accessibility, dark mode, performance, typography
- 每项满分 5 分,总分 /20,迭代修复直到满分
- 未达满分不算完成

## UI 改动自动验证

- 网页/前端改动部署后必须主动 headless 截图三视口(desktop/tablet/mobile),不要让用户截图反馈
- 用 `/browse` 或 Playwright MCP

## GitHub 发布检查

- 推 public 仓库前先 secret scan
- 推后自动加 `homepage=zturnsgo.com` / 描述 / 开发者向加 `FUNDING.yml`

## Vercel 部署陷阱

- `vercel link` 裸跑会误建空项目
- codebase 目录名 ≠ Vercel 项目名时,必须 `--project <真名> --scope <team>`
