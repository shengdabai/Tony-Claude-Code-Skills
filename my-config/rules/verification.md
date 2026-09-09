---
description: 声明完成前的三步验证：read-back、restart-aware、smoke test。任何配置或代码修改在说"已完成"之前强制生效。
---

# Verification Before "Done"

## Iron Law: 写完 ≠ 生效
Edit/Write 成功返回即证明写入成功,不必为此再 Read 一遍。要验证的是**生效**,按风险取用:

1. **Read-back**——仅当写入路径不等于你 Edit 的路径(脚本/模板/间接生成)、做的是盲写(未先 Read 就 Write)、或结果需要贴给用户当证据时。常规 Edit 后不需要。
2. **Restart-aware**——被进程缓存的配置必须重启才生效,这条无条件适用。已知陷阱:Hermes/OpenAI 兼容网关会话、Obsidian 打开时的 graph.json/workspace.json(先关再改)、launchd(改 plist 后 unload+load)、MCP servers(改 settings.json 后 /mcp restart)、CLAUDE.md 与 rules/(新会话才加载)。
3. **Smoke test**——有可执行入口时跑最小端到端调用。纯声明式配置(靠新会话加载、无运行时接口)没有可测点,直接说明"本次不可测,需新会话验证",不要编造测试。

禁止:假设写入即生效而跳过重启;沿用之前会话的"已完成"声明不 re-check;无法验证时默认成功而不说明。

报告格式:**只报本次真正适用的那几项**,不适用的直接不写(不要为凑格式写"无需"占位)。
例:纯 Edit 小改只需 `✓ 已改 <路径>`;动了被进程缓存的配置才加 `✓ 重启 <服务>`;有可执行入口才加 `✓ 测试 <结果>`;
不可测时写 `未测试,原因 X`。四项全列只在四项都真的做了时才出现。

## Secret-Aware Verification
read-back 时同时确认:写入文件不含明文 API key/token/password/私钥;不把秘密 echo 到 stdout/stderr(会进 jsonl 历史);用环境变量引用而非硬编码。发现已写入秘密:STOP → 报告用户 → 占位符替换 → 提示 rotate;已 `git add` 则 `git restore --staged <file>`。
