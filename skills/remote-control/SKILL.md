---
name: remote-control
description: Claude Code 官方远程控制 — 将终端 Claude Code 会话同步到手机/浏览器 Claude app。当用户说"远程控制"、"remote control"、"手机同步"、"手机连接"、"远程连接"等时触发。
---

# Remote Control — Claude Code 远程连接

将本地终端 Claude Code 会话实时同步到手机 Claude app 或浏览器 `claude.ai/code`，支持双向交互。

## 前置条件

- **Claude Code v2.1.51+**（`claude --version` 检查）
- **订阅**: Pro、Max、Team 或 Enterprise
- **认证**: 必须使用 `claude auth login`（API key 不支持）
- **Team/Enterprise**: 管理员需在 `claude.ai/admin-settings/claude-code` 启用 Remote Control

## 三种启动方式

### 方式 A: Server 模式（推荐，长期运行）

```bash
claude remote-control
```

可用参数：
- `--name "项目名"` — 设置会话标题
- `--spawn <mode>` — `same-dir`（默认）或 `worktree`（隔离）
- `--capacity <N>` — 最大并发会话数（默认 32）
- `--verbose` — 显示详细日志
- `--sandbox` / `--no-sandbox` — 启用文件/网络隔离

### 方式 B: 启动新会话时开启

```bash
claude --remote-control
# 或带名称：
claude --remote-control "我的项目"
```

### 方式 C: 在现有会话中开启

```
/remote-control
# 或带名称：
/remote-control 我的项目
```

## 手机连接方式

启动后有三种连接方式：

1. **Session URL** — 在浏览器打开 `claude.ai/code`
2. **QR Code** — 在 `claude remote-control` 模式下按空格键显示 QR 码，用手机 Claude app 扫描
3. **Session 列表** — 在 `claude.ai/code` 中按名称查找（在线会话显示绿点）

## 关键特性

- **双向同步**: 终端和手机任一端发消息，另一端实时可见
- **本地运行**: 代码在你的电脑执行，不上传云端
- **完整环境**: 文件系统、MCP 服务器、工具配置全部远程可用
- **自动重连**: 网络中断自动恢复
- **仅出站连接**: 不开入站端口，通过 HTTPS 走 Anthropic API

## 常用命令

| 命令 | 说明 |
|------|------|
| `/remote-control` 或 `/rc` | 在当前会话开启远程控制 |
| `/rename` | 修改会话标题 |
| `/config` | 切换"所有会话默认开启远程控制" |
| `/mobile` | 显示手机 Claude app 下载二维码 |

## 故障排查

| 错误 | 解决方案 |
|------|---------|
| "requires a claude.ai subscription" | 运行 `claude auth login`（API key 不支持） |
| "requires a full-scope login token" | 使用 `claude auth login` 而非 `CLAUDE_CODE_OAUTH_TOKEN` |
| "disabled by your organization's policy" | 联系管理员在 admin settings 启用 |
| "Remote credentials fetch failed" | 检查网络；用 `--verbose` 查看详情 |

## 限制

- 每个交互进程只支持 1 个远程会话（用 server 模式的 `--spawn` 支持多个）
- 终端必须保持打开（关闭终端 = 结束会话）
- 网络中断超过 10 分钟会超时断开

## Remote Control vs Claude Code on Web

| 特性 | Remote Control | Claude Code on Web |
|------|---------------|-------------------|
| 运行位置 | 你的电脑 | Anthropic 云端 |
| 本地 MCP/工具 | ✅ 支持 | ❌ 不支持 |
| 需要配置 | 需运行 `claude remote-control` | 无需配置 |
| 适合场景 | 进行中的工作、本地环境 | 新任务、无需本地环境 |
