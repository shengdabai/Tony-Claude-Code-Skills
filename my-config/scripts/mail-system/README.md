# QQ + Gmail 低打扰邮件系统

目标：两个邮箱保留一份原始邮件，每天 8:00 收到一份能替代逐封打开邮件的中文晨报。

## 当前策略

- 每小时扫描未读邮件，正文只读取最多 128 KiB，不下载附件、不访问邮件链接；用于晨报的正文片段在本机最多保留 96 小时，权限固定为 0600。
- Gmail 与 QQ 使用 `Message-ID` + 发件人/主题/正文指纹去重；同一封 Gmail 转发件优先保留 Gmail 原件，QQ 副本移到垃圾箱（30 天可恢复）。
- 明确促销自动标已读并移到垃圾箱；带 `List-Unsubscribe` 的普通订阅不再一律当广告。
- AI、科技、开发者、SaaS、独立开发等订阅进入重点关注。
- 每天 8:00 使用 Codex 的 GPT-5.6 Sol 生成统一晨报；失败时依次降级到本地 Ollama 和规则列表。若 8:00 投递失败，9:00 后的整点扫描会自动补发，直到当天成功。
- 邮件正文视为不可信数据：摘要模型不能执行其中指令、调用工具、访问链接或补充外部事实。

## 晨报结构

1. 昨日核心：2–4 条全局结论
2. 今天需要处理：原因、下一步、明确期限
3. AI / 科技 / 重点订阅：发生了什么、为什么值得关注
4. 其他有价值信息
5. 收件、去重、广告过滤数量与实际摘要引擎

## 定时任务

| 任务 | 频率 | 作用 |
|------|------|------|
| `com.tony.mail-sweep` | 每小时整点（08:00 自动让位） | 分类、标已读、过滤广告 |
| `com.tony.mail-digest` | 每天 08:00 | 扫描、跨邮箱去重、GPT 晨报 |

`run.sh` 使用系统文件锁避免 sweep/digest 并发重复处理。

## 安全预览与维护

```bash
cd ~/.claude/scripts/mail-system
python3 mail_agent.py --mode digest --dry-run
python3 mail_agent.py --mode dedupe --hours 30 --dry-run
python3 -m unittest discover -s tests -v
tail -f run.log
```

去重确认无误后，可手动整理最近 30 小时：

```bash
python3 mail_agent.py --mode dedupe --hours 30
```

凭证仍只保存在本地 `.env`（权限 600）；本次系统不读取、不修改、不复制其内容。

## 调整关注方向

- `rules.py` 的 `URGENT_KEYWORDS`：安全、失败、到期等高风险邮件
- `ACTION_KEYWORDS`：账单、订单、邀请、审批等待办
- `FOCUS_KEYWORDS`：AI / 科技 / 开发者重点订阅
- `PROMO_KEYWORDS`：只有明确营销信号才进垃圾箱

退订链接不会自动点击，因为发件人和链接可能伪造；若要永久退订，应先审核具体发件人再操作。
