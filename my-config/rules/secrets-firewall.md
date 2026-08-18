---
description: 机密文件零信任铁律。触及 .env* / *.pem / *.key / id_rsa* / credentials.* / secrets.* / .ssh 私钥的任何读写前强制生效；含双重防线与已写入密钥的事后处理。
---

# Secrets Firewall

## Iron Law: 机密文件零信任

任何 `.env*`、`*.pem`、`*.key`、`id_rsa*`、`credentials.*`、`secrets.*`、`.aws/credentials`、`.ssh/*` 私钥、`.gnupg/*`、`.netrc`、`.pgpass`、`.npmrc` 一律不得 Read / Edit / Write,**除非用户在当条消息里明确点名该具体文件路径**并授权。

## 双重防线

1. **硬防线(自动)**:`~/.claude/hooks/env-guard.sh` 在 PreToolUse 阶段直接 deny,不依赖模型自觉。
2. **软防线(模型自律)**:即使 hook 漏了,模型自己也必须遵守本规则。

## 三条行为准则

- **需要密钥值时,让用户自己在终端取前缀贴给你**(`echo "${VAR:0:7}..."`),不要自己去读文件。
- **写配置文件一律用占位符**(`YOUR_KEY_HERE`),并提示用户手动填,避免明文进 jsonl 历史。
- **用户主动贴了密钥**:可以照写文件,但**绝不在回复里 echo 该值**,并提示 rotate(它已经进历史了)。

## 已写入的事后处理

发现 hook 漏拦或自己写了密钥到非机密文件:
1. **STOP** 立即停止
2. 用占位符替换该值
3. 提示用户去 git 检查并 rotate
4. 若已 `git add`:提示 `git restore --staged <file>`

---

详细场景范例、hook 验证方法、`env-guard` 与 `secret-scan` 分工 → 需要时 Read `rules/secrets-firewall-examples.md`。
