---
description: 机密文件防线的场景范例与 hook 验证方法。真要处理密钥 / .env / 证书相关操作时加载（Iron Law 本体在 secrets-firewall.md）。
---

# Secrets Firewall — 场景范例与自检

**遇到下面三类场景时按范例照做,不要临场发挥"我只看一眼不回显"。**

**Why**:密钥泄露没有中间态——读进 context 就等于进了会话 jsonl,即使不回显给用户也已经落盘。这三个范例覆盖了实际最容易踩的三种诱因(任务隐含需要读、用户让你创建、用户主动贴出),每种都有一条不需要碰明文的替代路径。

> 从 `rules/secrets-firewall.md`（强制加载）拆出的详情部分。
> Iron Law 与双重防线在那份文件里；本文件只在**真的要处理密钥/机密文件相关操作时**才需要 Read。

## 三类典型场景与正确响应

### 场景 A：任务隐含需要读 .env

用户：「帮我看下为什么 OpenAI API 调用失败」

❌ 打开 `.env` 找 `OPENAI_API_KEY`

✅ 正确响应：
> 我需要确认 `OPENAI_API_KEY` 是否设置。两个办法：
> 1. 你在终端跑 `echo "${OPENAI_API_KEY:0:7}..."` 把前缀贴给我（避免完整 key 进对话）
> 2. 你明确授权我读 `path/to/.env`，我只检查 key 是否非空，不会把值 echo 出来

### 场景 B：用户主动让你创建 .env

用户：「帮我建个 .env，放 OPENAI_API_KEY=sk-xxx」

❌ 写明文 `sk-xxx` 进文件

✅ 正确响应：
- 文件里写占位符：`OPENAI_API_KEY=YOUR_KEY_HERE`
- 提示：「key 我用占位符替了，请你手动填进去，避免明文 key 进 Claude Code 的 jsonl 历史」

### 场景 C：用户已经把 key 贴在对话里

用户把 `sk-proj-xxx...` 直接贴出来让你写文件

✅ 正确响应：
- 照写文件，但**不要在回复里 echo 这个值**
- 提示：「key 已写入，但建议你 rotate 这个 key —— 它现在已经在 Claude Code jsonl 历史里了」

## 验证 hook 是否生效

```bash
touch /tmp/test.env
# 然后在 Claude 里说「读一下 /tmp/test.env」→ 应该看到 ENV-GUARD: 拒绝访问
```

## 两个 hook 的分工

| Hook | 时机 | 行为 | 作用 |
|------|------|------|------|
| `env-guard.sh` | PreToolUse | **阻断**（exit 2） | 防止读取/写入机密文件（防文件名） |
| `secret-scan.sh` | PostToolUse | **警告**（exit 0） | 写入后扫到密钥模式时提醒（防内容） |
