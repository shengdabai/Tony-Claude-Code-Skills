# 邮件自动化系统

两个邮箱(QQ + Gmail)统一治理:广告/不重要邮件自动「标已读 + 移垃圾箱」(保守,30 天可恢复),
所有新邮件默认标已读,每天 8:00 用本机 Ollama 生成过去 24h 总结发到 QQ 邮箱。
不再被一条条邮件打扰,每天看一封日报即可。

## 架构

```
QQ / Gmail ──IMAP──> mail_client ──> rules 分类 ──┬─ 广告 → 标已读+移垃圾箱
                                                  └─ 重要 → 标已读 → summarize(Ollama)
                                                                          └─ SMTP → QQ 日报
```

- **零第三方依赖**:仅 Python 标准库 + 本机 Ollama
- **零外泄**:总结由本地模型生成,邮件内容不出本机
- **凭证安全**:授权码经 `setup_credentials.py` 隐藏录入,只进 `.env`(600 权限,git 忽略),不进对话/日志

## 安装(三步)

```bash
cd ~/.claude/scripts/mail-system

# 1. 录入凭证(隐藏输入,不回显)
python3 setup_credentials.py

# 2. 安全预览(不动任何邮件,只分析 + 打印总结)
python3 mail_agent.py --mode digest --dry-run

# 3. 确认无误后加载定时任务
launchctl load ~/Library/LaunchAgents/com.tony.mail-sweep.plist
launchctl load ~/Library/LaunchAgents/com.tony.mail-digest.plist
```

## 凭证怎么拿

- **QQ 授权码**:QQ 邮箱设置 → 账号 → 开启「IMAP/SMTP 服务」→ 生成授权码(16 位,不是登录密码)
- **Gmail 应用专用密码**:先开 Google 账号两步验证 → https://myaccount.google.com/apppasswords → 生成 16 位密码

## 日常命令

```bash
python3 mail_agent.py --mode sweep              # 手动清理一次
python3 mail_agent.py --mode digest             # 手动清理+发总结
python3 mail_agent.py --mode digest --dry-run   # 预览不动手

tail -f run.log                                 # 看运行日志
```

## 定时任务

| 任务 | 频率 | 作用 |
|------|------|------|
| `com.tony.mail-sweep` | 每小时整点 | 新邮件标已读 + 广告移垃圾箱 |
| `com.tony.mail-digest` | 每天 8:00 | 清理 + 发过去 24h 总结到 QQ |

## 调整规则

编辑 `rules.py`:
- `WHITELIST_KEYWORDS` — 这些词命中则永远视为重要(安全/账单/验证码),绝不清理
- `PROMO_KEYWORDS` — 营销关键词,命中则判广告
- `BULK_SENDER_HINTS` — 群发发件人特征

策略保守:**宁可漏判(留收件箱)也不误判(误清重要邮件)**。

## 卸载

```bash
launchctl unload ~/Library/LaunchAgents/com.tony.mail-sweep.plist
launchctl unload ~/Library/LaunchAgents/com.tony.mail-digest.plist
```

## 排错

- **发信失败**:本机 Clash TUN 会劫持 SMTP,`mailer.py` 已内置 DoH+绑物理网卡绕过,通常自动生效
- **总结是纯列表不是智能摘要**:Ollama 没跑或模型缺失 → `ollama serve` + `ollama pull qwen3:8b`
- **IMAP 登录失败**:确认用的是授权码/应用专用密码而非登录密码;QQ 需已开 IMAP 服务
