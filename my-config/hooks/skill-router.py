#!/usr/bin/env python3
"""skill-router.py — UserPromptSubmit 关键词 → 强制 skill 路由

存在理由：这些路由规则原先常驻 CLAUDE.md（约 2.4KB），每次冷启动都付费，
但 90 天实测触发约 1 次。改成 hook 后：不命中 = 零 context 开销，
命中 = 注入的指令比原文更贴近当下这条 prompt。

约定：stdout 会被追加进本轮 context；exit 0 放行。
匹配失败或异常一律静默 exit 0，绝不阻塞用户输入。
"""

import json
import re
import sys

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
        r"审核|审查|评审|复核|验收|润色|\breview\b|\baudit\b|\bcritique\b|\bpolish\b",
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

    hits = [
        text
        for pattern, ignore_case, text in ROUTES
        if re.search(pattern, prompt, re.IGNORECASE if ignore_case else 0)
    ]
    if hits:
        print("\n".join(hits))
    return 0


if __name__ == "__main__":
    sys.exit(main())
