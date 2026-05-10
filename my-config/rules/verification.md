# Verification Before "Done"

## Iron Law: 写完 ≠ 完成

任何配置/代码修改都不能在仅 Edit/Write 之后就声明完成。必须执行 **read-back + restart + smoke test** 三步验证。

## 强制验证流程

修改任何配置文件、JSON、YAML、settings、hooks、graph.json 类文件后：

1. **Read-back**：用 Read 工具重新读取被修改的部分，把关键字段贴回来确认值正确
2. **Restart-aware**：如果改的是会被进程缓存的配置（gateway、Hermes 会话、模型路由、launchd 服务、MCP 进程），必须重启对应服务，否则旧值仍在内存中
3. **Smoke test**：执行一次最小化端到端调用，确认新行为生效

## 已知缓存陷阱（必须重启的场景）

- Hermes / OpenAI 兼容网关 → 切换模型后会话仍用旧模型
- Obsidian 打开时 → 修改 graph.json/workspace.json 会被覆盖，必须先关 Obsidian
- launchd 服务 → 改 plist 后必须 unload + load
- MCP servers → 改 settings.json 后必须 /mcp restart
- Claude Code 自身 → 改 CLAUDE.md 后当前会话不生效，新会话才加载

## 禁止行为

- 禁止说"已完成"/"已修复"/"已写入"而不附带 read-back 证据
- 禁止假设文件写入即生效，必须验证
- 禁止依赖之前会话的"已完成"声明，必须 re-read 当前状态
- 如果无法验证（例如服务在远程），必须显式说明"未验证"，不能默认成功

## 报告格式

完成时贴出：
```
✓ 写入：<文件路径>
✓ 验证：<read-back 关键片段>
✓ 重启：<已重启的服务，或"无需重启">
✓ 测试：<smoke test 结果，或"未测试，原因 X">
```

## Secret-Aware Verification

read-back 时同时检查：
- 写入文件**不含**明文 API key / token / password / 私钥
- 不要把秘密 echo 到 stderr/stdout（会被 jsonl 记录）
- 用环境变量引用而非硬编码：`process.env.OPENAI_API_KEY` not `"sk-proj-..."`

如果发现已经写入了秘密：
1. STOP 立即停止
2. 报告给用户
3. 用 placeholder 替换并提示用户去环境变量管理
4. 如果已经 git add：`git restore --staged <file>` 阻止 commit
