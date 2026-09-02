#!/usr/bin/env python3
"""skill-router.py — UserPromptSubmit 关键词 → 强制 skill 路由

存在理由：低频路由规则原先常驻 CLAUDE.md（约 2.4KB），每次冷启动都付费。
改成 hook 后：不命中 = 零 context 开销，命中 = 注入的指令更贴近当下 prompt。
dbskill 属于较高频业务路由，另在 CLAUDE.md 保留一行语义兜底，hook 只负责加速发现。

约定：stdout 会被追加进本轮 context；exit 0 放行。
匹配失败或异常一律静默 exit 0，绝不阻塞用户输入。
"""

import json
import re
import sys


def either_order(left: str, right: str, gap: int = 20) -> str:
    """Match common Chinese object→action and action→object word orders."""
    return rf"(?:(?:{left}).{{0,{gap}}}(?:{right})|(?:{right}).{{0,{gap}}}(?:{left}))"


DBS_ROUTE_TEXT = (
    "【dbskill 自动路由】本条消息可能匹配 dontbesilent 的业务工具箱。若这是纯代码、数据库或 "
    "Skill 源码维护任务，立即停止 dbskill 路由。否则比较已安装的 "
    "`~/.claude/skills/dbs/SKILL.md` 与 `~/.claude/skills/dbs-*/SKILL.md` frontmatter description，"
    "直接加载并执行最具体的一个，无需用户手动输入 `/dbs-*`。只有同一最终任务确实需要互补能力时，"
    "才使用 1 个主 Skill + 最多 2 个辅助 Skill，并交付一份结果。`dbs-update` 仅在用户明确要求更新时调用，"
    "更新后必须复验共享真源、32 个入口和软链接去重。"
    "若同时命中审核路由且用户要审核已有产物，以 review-optimizer 为主，dbs Skill 只提供领域评判标准；"
    "若只是创作、澄清或制定验收标准，不要因此启动 review-optimizer。其他更高优先级强制 Skill 仍优先。"
)

DBS_EXPLICIT_PATTERN = (
    r"dbskill|dontbesilent|"
    r"(?<![\w/])/dbs(?:-[a-z0-9-]+)?(?![\w/-])|"
    r"(?<![\w/])dbs(?:-[a-z0-9-]+)?(?![\w/-])"
)

DBS_NATURAL_PATTERN = "|".join(
    [
        either_order(
            r"商业模式|定价|续费率|客户画像|获客",
            r"诊断|分析|优化|检查|判断",
        ),
        either_order(r"对标|竞品", r"找|寻找|筛选|分析|研究|模仿"),
        either_order(
            r"短视频|小红书|公众号|文案|文稿|逐字稿|选题",
            r"选题|标题|开头|钩子|共鸣|传播|发布风险|敏感词|导流|广告|完播率|逻辑断层|逻辑不顺|创作|改稿|做成",
        ),
        r"拖延|执行不下去|知道.{0,8}不做",
        either_order(r"知识库|内容资产", r"建立|搭建|整理|治理|导航|查询|维护"),
        either_order(r"决策|诊断", r"记录|保存|存档|恢复|接着|继续|复盘|报告"),
        either_order(r"目标|问题|概念|JTBD", r"澄清|拆解|改写|重写"),
        either_order(r"[Ss]kill|技能", r"安装|同步|迁移|制作|创建|做个|沉淀"),
        either_order(r"学习|课题|学习文章", r"系列|课程|交互|持续|系统|继续|下一篇"),
        r"标准答案|历史同构|理论锚点",
        r"聊天室|奥派|多角色.{0,10}(?:讨论|对话|辩论)",
        r"AI\s*写作|AI\s*味|AI\s*痕迹|机器味",
        r"公众号\s*HTML|Markdown.{0,10}公众号|排版.{0,10}公众号",
        r"抖音|douyin\.com|小红书.{0,20}(?:数据|文字稿|转录|解析|提取)|"
        r"xiaohongshu\.com|xhslink|视频号.{0,20}(?:数据|文字稿|转录|解析|提取)|weishipin",
        r"发布前.{0,8}排雷|能不能发|会不会违规",
        either_order(r"素材|推文|案例|文稿", r"内容资产|结构化系统"),
        either_order(r"Agent|智能体", r"迁移|工作台|多端一致"),
        r"第一次使用.{0,12}(?:商业工具箱|这个工具箱)|不知道.{0,12}(?:选哪个能力|用哪个工具)",
    ]
)

DBS_ENGINEERING_PATTERN = (
    r"React|Vue|Svelte|Next\.js|SQL|PostgreSQL|MySQL|SQLite|database|schema|"
    r"数据库|API|函数|代码|脚本|单测|测试|CI|SKILL\.md|组件|索引|查询性能"
)

# (正则, 是否忽略大小写, 注入文本)。按列表顺序输出 —— needs-analysis 必须排第一。
ROUTES = [
    (
        r"需求|(?<![A-Za-z])needs(?![A-Za-z])",
        True,
        "【强制路由】本条消息命中「需求 / needs」→ 第一步必须调用 `needs-analysis` skill，"
        "它优先于 superpowers:brainstorming 等通用构思/规划 skill。"
        "完成需求真伪、证据、广泛/刚需/高频判断后，才可继续调用其他 skill。",
    ),
    (
        r"\bGEO\b|生成式引擎优化|Generative Engine Optimization|AI\s*搜索(优化|可见度)|AI\s*答案.*(引用|可见)",
        True,
        "【强制路由】本条消息命中 GEO → 必须调用 `geo` skill，先让 GEOHub 路由器选最小可执行能力；"
        "它优先于通用 SEO / 内容 / brainstorming skill。若同时命中「需求」，先 needs-analysis 再 geo。"
        "纯地理/定位/地图/GIS/GeoJSON 不属于此类；planned 能力只报告边界，不得模拟执行。",
    ),
    (
        r"万维钢|万维刚|现代思维工具|重尾分布|非遍历性|参考类预测|凯利公式|WOOP|效果推理|激励相容|古德哈特|指挥官意图|邻近可能|二阶意愿",
        False,
        "【强制路由】本条消息点名万维钢《现代思维工具100讲》相关概念 → 必须加载 "
        "`~/.claude/skills/wan-weigang-modern-thinking-tools-100/SKILL.md`。不冒充作者本人。",
    ),
    (
        r"\.claude/|CLAUDE\.md|CLAUDE\.local\.md|settings\.json|settings\.local\.json|output-style",
        False,
        "【强制路由】本条消息涉及 Claude Code 配置结构 → 创建或审查 hooks / agents / skills / "
        "plugins / rules / settings 前，先调用 `claude-code-project-layout` skill（权威规范）。",
    ),
    (
        DBS_EXPLICIT_PATTERN + "|" + DBS_NATURAL_PATTERN,
        False,
        DBS_ROUTE_TEXT,
    ),
    (
        r"审核|审查|评审|复核|(?<!可)验收|润色|\breview\b|\baudit\b|\bcritique\b|\bpolish\b",
        True,
        "【强制路由】本条消息要求审核/评审且存在待检查产物 → 加载 "
        "`~/.claude/skills/review-optimizer/SKILL.md`，由当前主会话协调 Codex 与 Claude 做只读交叉审核，"
        "不再询问用户选哪个 AI。用户明确只用单模型或禁止外部模型时不触发。",
    ),
]


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0

    prompt = data.get("prompt") or ""
    if not isinstance(prompt, str) or not prompt.strip():
        return 0

    hits = []
    for pattern, ignore_case, route_text in ROUTES:
        if not re.search(pattern, prompt, re.IGNORECASE if ignore_case else 0):
            continue
        if route_text == DBS_ROUTE_TEXT:
            explicitly_requested = re.search(DBS_EXPLICIT_PATTERN, prompt) is not None
            engineering_task = re.search(DBS_ENGINEERING_PATTERN, prompt, re.IGNORECASE) is not None
            if engineering_task and not explicitly_requested:
                continue
        hits.append(route_text)
    if hits:
        print("\n".join(hits))
    return 0


if __name__ == "__main__":
    sys.exit(main())
