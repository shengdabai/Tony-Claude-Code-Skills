# 刘小排推崇的工具栈（选型 + 时效核验 + 选型卡片）

> 用户问"用什么工具"、纠结技术选型、或要落地开发时读本文件。核心立场：**已有定论，直接给，别说"也可以考虑"**——因为新手把时间花在选工具上就是没在做产品。

---

## 默认工具栈（用户问就直接给）

| 环节 | 工具 |
|------|------|
| 出原型 | Bolt.new / V0 / Lovable |
| 主力开发 | Cursor（$20/月，必装 Context7 MCP + stagewise） |
| 重活/通用 Agent | Claude Code（"它不只是写代码，是通用 Agent，任何能 SOP 的事都能做"） |
| 框架 | Next.js + TypeScript + Tailwind + Shadcn |
| 数据库+Auth | Supabase（"我自用三年，初期免费够"） |
| 支付 | **Creem**（"国内护照可注册的唯一靠谱"），别用 Stripe 个人户 |
| 部署 | Vercel + Namecheap |
| 分析 | Plausible + Microsoft Clarity（免费录像 + 热力图） |
| 选品 | Toolify + TAAFT |
| 复刻整站 | same.new（"先大后小打法的核心"） |
| 模板 | ShipAny / Raphael Starter Kit |

**用户问"为什么不用 X"**：回 "X 也行，但你现在浪费时间在工具选择上 = 没在做产品。先用这套半年。"

---

## 🔗 引用工具前快查时效（工具栈时效核验）

Creem / Supabase / Cursor / same.new / Toolify 这些工具的**可用性和定价会变**。用户真要落地（不是泛泛问）时，引用前 `WebSearch` 核一次"该工具还在不在、价格变没变、有没有更换的必要"。

- 核到变化 → 更新口径再给。
- 核不到 → 标"我用的时候是 X，你注册前自己再确认下价格"。

**但别因为查工具把'先做产品'的节奏拖没了——查一次，给结论，往下走。**

---

## 用卡片快确认选型（AskUserQuestion）

仅当用户在多个已有定论项间犹豫时用。这张卡片是**收敛**用的——把纠结选型的用户快速拉回某一环节，确认完立刻推 ta 去做，不是让 ta 慢慢挑。

```
question: "技术栈别纠结了，这套我自用半年不换。你现在卡在哪个环节要落地？"
header: "选型确认"
options:
  - label: "出原型"      description: "Bolt.new / V0 / Lovable —— 10分钟出第一版"
  - label: "主力开发"    description: "Cursor $20/月，装 Context7 MCP + stagewise"
  - label: "支付"        description: "Creem（国内护照可注册的唯一靠谱），别用 Stripe 个人户"
  - label: "数据库+部署" description: "Supabase（初期免费）+ Vercel + Namecheap"
```
