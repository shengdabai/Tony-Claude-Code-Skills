---
description: 飞书 bot 专用规则。仅当条用户消息顶部带 <bridge_context> 块时加载；本地终端会话永不触发。含记忆查询、用量卡片、群历史、HTML→PDF、设备指挥、回复格式六节。
---

# 飞书 Bot 专用规则(仅 `<bridge_context>` 会话加载)

**先确认当条用户消息顶部有 `<bridge_context>` 块,再执行本文件任何一节;没有该块就当本文件不存在。**

**Why**:本文件的每一节都会触发真实外部动作——发消息到某个 chat、渲染长图推送、指挥远程设备。在本地终端会话里误触发,轻则把无关内容推到飞书,重则对着错误的 chat_id 外发。`<bridge_context>` 是唯一可靠的来源判据。

> 本文件从 CLAUDE.md 正文抽出。**本地终端会话永不需要本文件**——只有当条用户消息顶部带 `<bridge_context>` 块(来自飞书 lark-channel-bridge bot)时,才 Read 本文件并按下列章节执行。
> 抽离原因:这 6 段飞书规则对 96%+ 的本地会话是死重量(近 30 天仅 3.7% 会话含 bridge_context),不该常驻 CLAUDE.md。

<!-- AI_LANGUAGE_PROTOCOL:BEGIN -->
## Language Protocol

- When a substantive user request is in Chinese, silently create a faithful English task representation before analysis; do not alter intent, scope, constraints, names, or quoted text.
- Use English by default for internal planning, technical reasoning, evaluation, web-search formulation, tool instructions, and subagent prompts. For Chinese-first domains or sources, query and read the source language when that improves accuracy.
- Keep code, commands, identifiers, filenames, API fields, proper nouns, and user-provided literals in their original or technically correct form; never translate them mechanically.
- An explicit user request for an output language takes precedence. Otherwise, for a request whose primary user-facing language is Chinese, return all user-visible progress updates, clarification questions, explanations, and final answers in concise Simplified Chinese; when another language is primary, match it; when mixed or unclear, default to Simplified Chinese.
- Do not reveal hidden chain-of-thought or private scratch work. If a client exposes an opt-in reasoning summary or tool trace, keep it concise and in English; for Chinese-primary requests, provide Chinese conclusions, key reasons, evidence, assumptions, risks, and verification results in the user-facing answer.
- Generated artifacts follow their intended audience and the user's explicit language requirement; the accompanying chat handoff matches the conversation's primary language, defaulting to Chinese when mixed or unclear.
- A higher-priority system/developer instruction or a more specific project rule may override this protocol. When relevant, state the chosen output language briefly.
<!-- AI_LANGUAGE_PROTOCOL:END -->

## 🧠 飞书记忆查询

**仅当**本条用户消息顶部带有 `<bridge_context>` 块(即来自飞书 lark-channel-bridge bot),
且正文正好是「记忆」「查看记忆」「看记忆」「查看所有ai对话记录」「ai对话记录」「我的记忆」之一时:
直接用 Bash 运行 `/Volumes/2T/ai-memory-system/bin/ai-mem-feishu`,把它的 stdout **原样**回复
(已含飞书文档链接 + 状态,勿改写、勿追加解释、勿再贴 markdown)。约 7 秒,耐心等它跑完。
**没有 `<bridge_context>` 块的会话(本地终端交互)绝不触发本规则**——那只是普通对话里出现了"记忆"二字。

## 📊 飞书用量查询

**仅当**本条消息顶部带 `<bridge_context>` 块,且用户问 **codex / claude code 的用量 / 余额 / 还剩多少 / 限额 / quota / 5 小时 / 本周** 时:
用 Bash 跑 `~/.hermes/bin/usage-card.sh <chat_id> <all|claude|codex> [app_id]`(全问省第二参或填 `all`、只问 codex 填 `codex`、只问 claude 填 `claude`;`chat_id` 取 `<bridge_context>` 里的值;`app_id` 取当前触发 bot 的 app_id,拿不到就省略走默认 Claude bot)。脚本会把用量渲成**一张精美竖长图自动发回该聊天**(走图片通道不碰 PDF 预览器),你只需回一句「📊 用量卡片已发」,**不要**再贴文字报告。数据来自本机 Vibe Island.app 实时缓存。
- 失败兜底:`usage-card.sh` 报错(网络/渲染失败)时,退回 `~/.hermes/bin/usage-report.sh`(同样支持 `codex`/`claude` 参数)取文字报告原样回复。
- 本地终端会话不触发本节。

## 👁 飞书群历史 / 看图

**仅当**本条消息顶部带 `<bridge_context>` 块时生效(本地会话不触发)。`<bridge_context>` 里有当前 `chat_id`。

用户让你"总结刚才群里聊的 / 看看别的 bot 怎么回的 / 看群历史"时,**自己用 Bash 拉**,不用让用户复制粘贴:
```bash
LARK_CLI_NO_PROXY=1 lark-cli --profile cli_aa80e81017f85bc0 --as user \
  im +chat-messages-list --chat-id <bridge_context 里的 chat_id> --page-size 20
```
返回 JSON,每条含 sender(app_id=哪个 bot / open_id=哪个人)、content、create_time、msg_type。

看图/多图(从历史结果取 msg_type=image/post 的 message_id;用户当前消息直接发的图 bridge 已下载好附件,无需此步):
```bash
LARK_CLI_NO_PROXY=1 lark-cli --profile cli_aa80e81017f85bc0 --as user \
  im +messages-resources-download --message-id <om_xxx> --dir /tmp/feishu-img
```
一条消息里的多张图都会下载,再用文件路径读图。

## 🖨 飞书 HTML→PDF

**仅当**本条消息带 `<bridge_context>` 块,且用户要求制作 HTML/网页/页面/海报/报告页/可视化页/长图时(本地终端会话不触发):

1. 按 `onepage-pdf` skill 规范生成**桌面布局** HTML(设计宽 1280px;避免 `min-height:100vh` 撑高;`@media (max-width:N≥741px)` 断点会在打印时塌陷,需配 print 修正 css),保存到 `~/Desktop/03-内容创作/16-飞书HTML/<YYYYMMDD>-<标题>.html`
2. 跑 `bash ~/.claude/scripts/feishu-html-pdf.sh <html路径> <bridge_context 里的 chat_id>`(第 4 参可传修正 css 路径)——自动保留本地单页归档 PDF 和 `*.feishu.pdf`，脚本会把 HTML 连同 `.pdf`/`.feishu.pdf`/逐页图/`.feishu-long.jpg` 全部留在本机，并**默认做成一张竖长图发到飞书**（走图片通道不碰 PDF 预览器，绝不闪退；超长或超 9.5MB 自动回退逐页图片）。只有明确要逐页图或 PDF 文件时才临时设 `FEISHU_SEND_FORMAT=images` / `FEISHU_SEND_FORMAT=pdf`
3. 转完用 pymupdf 渲染低 dpi 缩略图自检一眼(布局没塌、底部没截断),再回复:「🖨 HTML 已存 <本机路径>,长图已发」。不要把 HTML 源码贴进飞书。

## 🎛 飞书全设备指挥

**仅当**本条消息带 `<bridge_context>` 块,且用户要求**操作/查看/重启设备、服务器、定时任务、agent、会话、健康状态**(如"看下上海云""重跑日报""服务器状态""Air 在线吗""现在有什么任务在跑""把 X 任务重启")时:
先 Read `/Volumes/2T/ai-memory-system/command-center/docs/commander-playbook.md`(设备直达表 + 任务控制命令 + 安全红线),按手册执行。
要点:双云走 ssh 别名 shanghai / silicon-valley;破坏性操作必须先复述等用户回"确认";长任务先回"在跑了"再报结果;本地终端会话不触发本节。

## ✅ 飞书任务完成回复格式

**仅当**本条用户消息顶部带 `<bridge_context>` 块时生效(本地终端会话**绝不**触发,本地照常 caveman 简洁风)。

通过飞书 bot 完成一个编码/操作类任务后,用户在**手机**上看回复。**绝不**把完整代码、整段 diff、终端日志原文贴回飞书。改用下面这套简洁卡片式摘要,用大白话讲清"做完了什么、结果如何":

```
✅ **完成** · <一句话说清这次干了啥>

**做了什么**
- <要点,口语化,一条一句>

**改动文件**
- `相对路径` — <一句话说明改了什么>

**结果**
- <构建/测试/运行的结论>

> 想看代码或细节回我"看代码",我整理成飞书文档发你
```

硬规则(同 codex bot,见 `~/.agent-feishu-channel/codex-workspace/AGENTS.md`):
- `**` 两侧留空格(飞书 markdown 卡片才渲染加粗);用 `###`/`-`/emoji 排版
- 全长尽量 **< 250 字**,手机一屏读完;长了只留最关键 3-5 条
- **禁止**贴 >15 行代码块;内容多/用户要完整代码 → 建飞书云文档,回复只给链接 + 一句摘要
- 失败:`❌ **没成功** · <原因>` + 一行下一步,挑关键 1-2 行报错,别贴一大坨
- 纯闲聊/问答(无实际任务)→ 正常自然回答,本模板不适用

## 🛰️ 抱怨雷达按需触发(bridge_context 会话)

**仅当**本条消息带 `<bridge_context>` 块,且用户在**表达一个抱怨/痛点/"我希望有/缺个/为什么没有/someone should build"类产品诉求**,或明确说「搜集抱怨/查下有没有人也这样/这个能做产品吗/抱怨雷达 X」时:
把用户原话当种子,**后台**就地搜集真实反馈并出信息图回推到当前 chat(脚本自带"正在搜集"回执 + 最终图片,2-4 分钟):
```bash
nohup bash "$HOME/Desktop/01-项目开发/36-抱怨搜集系统/bin/on_demand.sh" \
  "<用户这条消息的原话>" --bot claude --chat <bridge_context 里的 chat_id> >/dev/null 2>&1 &
```
发起后**立刻**回一句「🛰️ 收到,正在就地搜集真实抱怨+出图,稍等几分钟」即可,**不要**自己 sleep 等它、不要重复跑。本地终端会话(无 bridge_context)用 `抱怨 "<主题>"` 命令,不走本节。
