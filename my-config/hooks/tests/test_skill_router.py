#!/usr/bin/env python3
"""Regression probes for dbskill routing in the UserPromptSubmit hook."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import unittest


HOOK = Path(__file__).resolve().parents[1] / "skill-router.py"
DBS_MARKER = "【dbskill 自动路由】"
REVIEW_MARKER = "【强制路由】本条消息要求审核/评审"


def route(prompt: str) -> str:
    completed = subprocess.run(
        ["/usr/bin/python3", str(HOOK)],
        input=json.dumps({"prompt": prompt}),
        text=True,
        capture_output=True,
        check=True,
    )
    return completed.stdout


class DbskillRoutingTests(unittest.TestCase):
    def test_each_installed_capability_has_a_natural_language_probe(self) -> None:
        prompts = {
            "dbs": "第一次使用这个商业工具箱，不知道选哪个能力",
            "dbs-action": "我知道该做但就是不做",
            "dbs-agent-migration": "把现有 Agent 工作台迁移到 Claude Code 和 Codex，保持多端一致",
            "dbs-ai-check": "检查这段文案有没有 AI 味",
            "dbs-benchmark": "帮我找几个值得模仿的对标账号",
            "dbs-chatroom-austrian": "进入奥派聊天室聊聊通货膨胀",
            "dbs-chatroom": "开个聊天室聊聊这个话题",
            "dbs-content-risk-check": "这条小红书发布前帮我排雷",
            "dbs-content-system": "把我的旧素材整理成内容资产",
            "dbs-content": "这个选题该怎么做成好内容",
            "dbs-decision": "记录这次决策",
            "dbs-deconstruct": "帮我拆解一下这个概念",
            "dbs-diagnosis": "帮我全面检查一下我的商业模式",
            "dbs-goal": "帮我澄清这个目标",
            "dbs-good-question": "帮我改写这个问题",
            "dbs-hook": "帮我优化这段短视频开头",
            "dbs-install-skill": "把这个技能同步到 Claude Code",
            "dbs-jtbd": "用 JTBD 重写提示词",
            "dbs-knowledge": "把这个文件夹搭建成知识库",
            "dbs-learning": "我想系统学习定价",
            "dbs-report": "把几次诊断整理成报告",
            "dbs-resonate": "检查这篇文稿有没有共鸣",
            "dbs-restore": "接着上次的诊断继续",
            "dbs-save": "保存一下这次诊断的结论",
            "dbs-script-flow": "这段逐字稿有逻辑不顺吗",
            "dbs-skill-maker": "帮我做个 skill",
            "dbs-spread": "分析这段文稿的传播机制",
            "dbs-standard-answer": "找出这个问题的历史同构和标准答案",
            "dbs-update": "更新 dbskill",
            "dbs-video-extract": "https://v.douyin.com/xxx 帮我提取文字稿",
            "dbs-wechat-html": "把 Markdown 转成公众号 HTML",
            "dbs-xhs-title": "帮我给这篇小红书写标题",
        }
        for skill, prompt in prompts.items():
            with self.subTest(skill=skill):
                self.assertIn(DBS_MARKER, route(prompt))

    def test_engineering_and_name_collision_probes_do_not_route(self) -> None:
        prompts = [
            "给 React 页面加一个客户画像分析按钮",
            "实现一个内容创作模块的 API",
            "帮我 review 这段 SQL 内容的逻辑",
            "修复 dbs-action/SKILL.md 里的 Python 示例",
            "重构 skill 安装脚本的单测",
            "续费率分析的 SQL 内容逻辑",
            "请看 DBS-BANK 报表",
            "看下 /var/dbs/ 目录",
            "数据库dbs表结构",
            "只修改这个 React 组件的按钮颜色",
        ]
        for prompt in prompts:
            with self.subTest(prompt=prompt):
                self.assertNotIn(DBS_MARKER, route(prompt))

    def test_review_and_goal_routes_are_disambiguated(self) -> None:
        review = route("帮我审核这篇内容的选题")
        self.assertIn(REVIEW_MARKER, review)
        self.assertNotIn(DBS_MARKER, review)

        goal = route("帮我把这个目标澄清成可验收的交付物")
        self.assertIn(DBS_MARKER, goal)
        self.assertNotIn(REVIEW_MARKER, goal)

    def test_needs_route_precedes_dbskill(self) -> None:
        output = route("需求：给 SaaS 定价做诊断")
        self.assertLess(output.index("需求 / needs"), output.index(DBS_MARKER))


if __name__ == "__main__":
    unittest.main()
