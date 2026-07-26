# Verification Before "Done"

## Iron Law: 写完 ≠ 完成
任何配置/代码修改必须三步验证后才可声明完成:
1. **Read-back**:用 Read 重读被改部分,贴关键字段确认值正确。
2. **Restart-aware**:被进程缓存的配置必须重启对应服务才生效——已知陷阱:Hermes/OpenAI 兼容网关会话、Obsidian 打开时的 graph.json/workspace.json(先关再改)、launchd(改 plist 后 unload+load)、MCP servers(改 settings.json 后 /mcp restart)、CLAUDE.md(新会话才加载)。
3. **Smoke test**:最小化端到端调用确认新行为生效。

禁止:无 read-back 证据就说"已完成/已修复";假设写入即生效;沿用之前会话的"已完成"声明不 re-read;无法验证时必须显式说明"未验证",不能默认成功。

报告格式:`✓ 写入 <路径> / ✓ 验证 <read-back 关键片段> / ✓ 重启 <服务,或"无需"> / ✓ 测试 <结果,或"未测试,原因 X">`

## Secret-Aware Verification
read-back 时同时确认:写入文件不含明文 API key/token/password/私钥;不把秘密 echo 到 stdout/stderr(会进 jsonl 历史);用环境变量引用而非硬编码。发现已写入秘密:STOP → 报告用户 → 占位符替换 → 提示 rotate;已 `git add` 则 `git restore --staged <file>`。
