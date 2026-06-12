# 长篇模式：一句话产出 10 万字双语插图小说（实战验证版）

> 2026-06-11 双书实战定型：《老主顾》106,360 字 / 《晚自习》107,780 字，各 22 章，
> 全程 Workflow 编排 + Codex 分担翻译与插图。本文件是操作手册，不是理论。

## 总架构：三引擎分工

| 引擎 | 干什么 | 为什么 |
|---|---|---|
| Claude Workflow | 架构/写章/审校/QC（创作主链） | 文学质量主力，串行连续性 |
| Codex CLI (gpt-5.5) | 英文翻译、gpt-image 插图、机械批量 | 省 Claude 额度；图像生成只有它有 |
| 主会话（你） | 编排、验收、断点恢复、磁盘实测 | 监工不下场写作 |

## Workflow 脚本

可复用脚本：`~/.claude/workflows/xiaolai-novel.js`，调用方式：

```
Workflow({ scriptPath: "~/.claude/workflows/xiaolai-novel.js",
  args: { books: [{ slug, title, dir, nch: 22, specific: "<题材方向建议>", redline: "<隐私红线>" }] } })
```

五阶段：Architect → Chapters → Assemble → Expand → QC。

### 阶段要点（与短篇十阶段的差异）

1. **Architect**（每本书 1 agent）：扩展策略论证（短篇种子如何长成长篇）+ novel bible 五件套
   （新增人物配 Lie/Want/Need/Ghost + 三滑杆）+ **22 章逐章大纲**（对照 Save the Cat 15 拍，
   每章标：POV/场景/开收价值翻转/推进线/目标 4800–5600 纯汉字/章末钩子）+ **rolling-summary.md 初始化**。
2. **Chapters**：**书内严格串行**（写 ch N 必读：bible + 大纲第 N 章 + rolling-summary 全部前情 + 前一章成稿），
   **审校与下一章写作流水线重叠**（审校只动风格层、禁改情节事实，所以可并行）。
   每章写完三件事：落盘正文 → 追加 rolling-summary（梗概+人物状态表+新增实物清单）→ 回写 bible threads。
   多本书之间并行。
3. **Assemble**：脚本拼接 + **python 磁盘实测纯汉字数**（铁律：不信 agent 自报）。
4. **Expand**：实测 < 102,000 才触发，扩最薄章节（场景内加深/新增带翻转的场景，禁形容词注水）。
5. **QC**：全书连续性审计（对照 rolling-summary 逐项核）+ threads 收束核查 + 各章开头句式横向比对 +
   抽样朗读。实战战绩：抓到"二十七年 vs 22 根蜡烛"年限矛盾并全局同步 21 处。

### rolling-summary.md 是整个长篇模式的命根子

它同时是：① 章节作者的前情事实账本 ② 断点恢复的判据 ③ QC 的对照基准 ④ 翻译/插图的内容索引。
格式：每章一条（150–250 字梗概 + 人物状态表变更 + 新增实物/日期/地点/设定清单）。

## 限额断点恢复（必然发生，按此办）

10 万字 ≈ 90+ agent ≈ 1000 万 token 级，**必撞 2–3 次 5 小时限额**。流程：

1. Workflow 因限额死掉 → 收到完成通知带一串 "session limit" failures
2. 限额重置后：**找半成品章** = 字数明显低于 4800 下限 **且** rolling-summary 无对应条目的章节文件 → 删除
   （写手是先写正文、后更账本，被掐死的章一定账本干净）
3. `Workflow({ scriptPath, resumeFromRunId, args: 同款 })` → 已完成 agent 全部缓存命中，从断点续跑
4. 预防性布防：开跑时就用 CronCreate 在下一个限额重置点挂 durable 一次性任务（含链式续排条款），
   额度耗尽时主会话自己也醒不来，没这个保险就会停到天亮

## Codex 分担层（省 Claude 额度的关键）

### 英文翻译（驱动脚本：项目 translate/translate-one.sh 模式）

1. **翻译圣经先行**（每本 1 个 codex exec）：读 bible+rolling-summary+样章 → 产 en/translation-bible.md
   （人名/术语一次定版 + 文体规格 + 教学材料规则 + 章题表 + 10 条自检）。圣经是并行一致性的唯一保障。
2. **章节车队**：每章一个独立 codex exec（`xargs -P 3` 每本书 3 路），prompt 只含：圣经路径 + 源章路径 +
   输出路径 + 硬规则（逐句全译/禁删减/词数 55–95% 自检）。**幂等设计**：输出已存在即 skip，可无脑重跑。
3. 烟测先行：放车队前先单跑 ch01 验质量（词数比、开头质感、人名一致）。
4. 收尾：术语一致性全书扫描 + 抽样回译核对 + 拼装 EN 全本。

### gpt-image 插图（Codex 原生工具，实测可用）

- codex exec 内置 image-gen 工具（ChatGPT 账号即可，无需 OPENAI_API_KEY）。
  **坑**：不逼它就用 PIL 画图敷衍——prompt 必须写明 "FORBIDDEN from drawing programmatically"
- 每本书 1 个 codex 任务循环产 25 张：封面双候选（**无字版**，gpt-image 写中文必错字，
  书名排版阶段矢量压字）+ 22 章章头图（每章从 rolling-summary 取一个实物意象）+ 极淡页面背景
- **风格一致性靠固定前缀**：每张图的 prompt 以同一段风格描述开头（调色板/笔触/构图原则），
  这是跨独立生成调用保持统一的唯一手段
- 过程纪律写进 prompt：顺序生成、每张验文件 >100KB、失败重试一次后记录继续、manifest 边跑边写

## 成书 PDF（双语 + 插图）

md 全本 + art/ 图集 → 排版 HTML（封面图+矢量书名压字、每章首插章头图、page-bg 做背景水印、
正文衬线/章题区分）→ Chrome headless 或 weasyprint 出 PDF。中英各一版。

## 实测成本账（2026-06，Claude Max + ChatGPT Pro）

- 中文双书（21.4 万字）：~94 agent × 3 程 ≈ 3100 万 Claude token，跨 3 个 5 小时限额窗
- 翻译 44 章 + 插图 50 张：全部 Codex/ChatGPT 额度，Claude 近零消耗
- 结论：**创作用 Claude，批量加工用 Codex**，额度结构才撑得住一本书
