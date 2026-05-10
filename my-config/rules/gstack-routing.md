# gstack 智能路由(自动识别 + 菜单推荐)

当对话涉及以下场景时,**主动推荐**对应的 gstack 命令,中文简要说明并给出可点击的命令。

## 自动识别规则

### Plan 阶段(代码前)
- 新功能/产品想法 → `/plan-ceo-review`(产品思维审视)
- 技术方案/架构设计 → `/plan-eng-review`(工程架构审查)
- UI/设计/界面/样式/前端 → `/plan-design-review`(设计审计)或 `/design-consultation`(从零建设计系统)

### Impeccable 设计 skills
- "配色"/"颜色"/"色彩"/"换个颜色" → `impeccable:colorize`
- "布局"/"排版"/"间距"/"太挤了"/"太空了" → `impeccable:layout`
- "字体"/"字太小"/"字太大"/"排版不好看" → `impeccable:typeset`
- "加点动画"/"过渡效果"/"不够流畅" → `impeccable:animate`
- "太平淡了"/"太无聊"/"不够吸引人"/"不够有冲击力" → `impeccable:bolder`
- "太花哨"/"太吵"/"太刺激" → `impeccable:quieter`
- "打磨一下"/"收尾"/"上线前检查" → `impeccable:polish`
- "太复杂"/"简化一下"/"去掉不需要的" → `impeccable:distill`
- "要能自适应"/"手机上看看"/"响应式" → `impeccable:adapt`
- "看看设计有没有问题"/"设计审查"/"设计评估" → `impeccable:critique`
- "做个设计方案"/"先规划一下UI" → `impeccable:shape`
- "空状态"/"错误处理"/"边界情况"/"生产就绪" → `impeccable:harden`
- "太慢了"/"卡顿"/"性能优化" → `impeccable:optimize`
- "让界面更有趣"/"加点惊喜"/"更好玩" → `impeccable:delight`
- "视觉冲击"/"炫酷效果"/"shaders"/"震撼" → `impeccable:overdrive`
- "文案不好"/"提示不清楚"/"错误信息看不懂" → `impeccable:clarify`
- "无障碍"/"可访问性"/"a11y" → `impeccable:audit`

### gstack 主流程
- "看看效果"/"设计变体"/"给我几个方案" → `/design-shotgun`
- "把设计做成HTML"/"实现这个设计" → `/design-html`
- 写完代码/完成功能 → `/review`(代码审查)
- "测试一下"/"看看效果"/提供 URL → `/qa`(自动 QA + 修复)或 `/qa-only`(只报告)
- "发布"/"上线"/"提 PR" → `/ship`
- 回顾本周工作 → `/retro`
- "更新文档" → `/document-release`

## 推荐格式(每次最多 2-3 个最相关的)

```
根据你的需求,建议使用:
• `/plan-ceo-review` — 用产品思维重新审视这个功能,找到更好的方案
• `/plan-eng-review` — 锁定技术架构和边界情况
输入命令即可启动,或告诉我你想做什么,我来帮你选。
```

## 重要约束

- 不要每次都推荐,只在明确匹配场景时才推荐
- 用户已经在执行某个 gstack 命令时不要重复推荐
- 用户说"帮我选"时,根据上下文直接执行最合适的命令

## 设计 Skill 协调矩阵

| 用户需求 | gstack skill | impeccable skill |
|---------|-------------|-----------------|
| 从零建设计系统 | `/design-consultation` | - |
| 设计规划(写代码前) | - | `impeccable:shape` |
| 设计审查(plan模式) | `/plan-design-review` | - |
| 设计审查(代码级) | - | `impeccable:critique` |
| 视觉QA+修复 | `/design-review` | - |
| 技术质量审计 | - | `impeccable:audit` |
| 探索设计方案 | `/design-shotgun` | - |
| 实现设计为HTML | `/design-html` | - |
| 配色/布局/字体优化 | - | `impeccable:colorize/layout/typeset` |
| 动画/视觉冲击 | - | `impeccable:animate/bolder/overdrive` |
| 收敛/精简/打磨 | - | `impeccable:quieter/distill/polish` |
| 响应式/生产加固 | - | `impeccable:adapt/harden` |
| UI性能/愉悦感 | - | `impeccable:optimize/delight` |
| UX文案 | - | `impeccable:clarify` |
