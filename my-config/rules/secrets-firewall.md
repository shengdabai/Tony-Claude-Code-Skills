# Secrets Firewall

## Iron Law: 机密文件零信任

任何 `.env*`、`*.pem`、`*.key`、`id_rsa*`、`credentials.*`、`secrets.*`、`.aws/credentials`、`.ssh/*` 私钥、`.gnupg/*`、`.netrc`、`.pgpass`、`.npmrc` 一律不得 Read / Edit / Write,**除非用户在当条消息里明确点名该具体文件路径**并授权。

## 双重防线

1. **硬防线(自动)**:`~/.claude/hooks/env-guard.sh` 在 PreToolUse 阶段直接 deny。这是最后兜底,不依赖模型自觉。
2. **软防线(模型自律)**:即使 hook 漏了,模型自己也必须遵守本规则。

## 触发场景与正确响应

### 场景 A:任务隐含需要读 .env
用户:"帮我看下为什么 OpenAI API 调用失败"
错误做法:打开 `.env` 找 `OPENAI_API_KEY`
正确做法:
> 我需要确认 `OPENAI_API_KEY` 是否设置。要么:
> 1. 你在终端跑 `echo "${OPENAI_API_KEY:0:7}..."` 把前缀贴给我(避免完整 key 进对话)
> 2. 你明确授权我读 `path/to/.env`,我只检查 key 是否非空,不会把值 echo 出来

### 场景 B:用户主动让你创建 .env
用户:"帮我建个 .env,放 OPENAI_API_KEY=sk-xxx"
错误做法:写明文 sk-xxx 进文件
正确做法:
- 写文件用 placeholder:`OPENAI_API_KEY=YOUR_KEY_HERE`
- 提示用户:"key 我用占位符替了,请你手动填进去,避免明文 key 进 jsonl 历史"

### 场景 C:用户已经把 key 贴在对话里
用户:把 `sk-proj-xxx...` 直接贴出来让你写文件
错误做法:照写
正确做法:
- 写文件,但**不要在回复里 echo 这个值**
- 提示:"key 已写入,但建议你 rotate 这个 key —— 它现在已经在 Claude Code jsonl 历史里了"

## 已写入的事后处理

如果发现 hook 漏拦或自己手贱写了密钥到非 .env 文件:
1. STOP 立即停止
2. 用 placeholder 替换该值
3. 提示用户去 git 检查并 rotate
4. 如果已 `git add`:提示用户 `git restore --staged <file>`

## 验证 hook 是否生效

```bash
# 任意创建一个 .env 测试文件,然后让 Claude Read 它,应该被 hook 阻止
touch /tmp/test.env
# 在 Claude 里问:"读一下 /tmp/test.env" → 应该看到 ENV-GUARD: 拒绝访问
```

## 与 secret-scan.sh 的区别

| Hook | 时机 | 行为 | 作用 |
|------|------|------|------|
| `env-guard.sh` | PreToolUse | **阻断**(exit 2) | 防止读取/写入机密文件 |
| `secret-scan.sh` | PostToolUse | **警告**(exit 0) | 写入后扫到密钥模式时提醒 |

两层互补:guard 防文件名,scan 防内容。
