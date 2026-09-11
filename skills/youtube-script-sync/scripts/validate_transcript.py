#!/usr/bin/env python3
"""Validate a generated GetNote YouTube child-note before live write."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


REQUIRED = [
    "# 拍摄定位",
    "# 可直接录制逐字稿",
    "## 中文逐字稿",
    "## English verbatim script",
    "# 拍摄提示",
    "# 标题、封面与传播设计",
    "# 发布前核验",
    "# 同步元数据",
]

FORBIDDEN = [
    "保证爆",
    "必火",
    "一定涨粉",
    "保证涨粉",
    "算法喜欢",
    "对新人一视同仁",
    "惩罚断更",
    "guaranteed to go viral",
    "the algorithm loves",
    "guaranteed views",
    "guaranteed subscribers",
    "smash that like button",
]

CHINGLISH = [
    "with the development of",
    "as we all know",
    "in today's society",
    "more and more people",
    "very convenient",
    "let us discuss",
]


def section(text: str, start: str, following: list[str]) -> str:
    begin = text.find(start)
    if begin < 0:
        return ""
    begin += len(start)
    ends = [text.find(marker, begin) for marker in following]
    ends = [value for value in ends if value >= 0]
    return text[begin : min(ends) if ends else len(text)].strip()


def validate(text: str) -> dict[str, object]:
    errors: list[str] = []
    warnings: list[str] = []

    for heading in REQUIRED:
        if heading not in text:
            errors.append(f"missing heading: {heading}")

    metadata = {}
    for key in ("schema", "source_note_id", "source_updated_at", "format", "language", "generated_by"):
        match = re.search(rf"(?m)^{re.escape(key)}:\s*(.+?)\s*$", text)
        if not match:
            errors.append(f"missing metadata: {key}")
        else:
            metadata[key] = match.group(1).strip()

    if metadata.get("schema") not in (None, "youtube-script-sync/v2"):
        errors.append("unsupported schema")
    source_id = str(metadata.get("source_note_id", ""))
    if source_id and not re.fullmatch(r"\d{16,22}", source_id):
        errors.append("source_note_id must be the exact long numeric string")

    fmt = metadata.get("format")
    if fmt not in (None, "long", "short"):
        errors.append("format must be long or short")
    if metadata.get("language") not in (None, "zh+en"):
        errors.append("language must be zh+en")

    chinese = section(text, "## 中文逐字稿", ["## English verbatim script"])
    english = section(text, "## English verbatim script", ["# 拍摄提示"])
    chinese_chars = len(re.findall(r"[\u3400-\u9fff]", chinese))
    english_words = len(re.findall(r"\b[A-Za-z]+(?:['’][A-Za-z]+)?\b", english))
    if fmt == "short" and not 100 <= chinese_chars <= 450:
        errors.append(f"short Chinese body should be 100-450 characters; got {chinese_chars}")
    if fmt == "long" and not 700 <= chinese_chars <= 3500:
        errors.append(f"long Chinese body should be 700-3500 characters; got {chinese_chars}")
    if fmt == "short" and not 90 <= english_words <= 220:
        errors.append(f"short English script should be 90-220 words; got {english_words}")
    if fmt == "long" and not 650 <= english_words <= 1500:
        errors.append(f"long English script should be 650-1500 words; got {english_words}")

    short_metrics: list[dict[str, int | str]] = []
    if fmt == "long" and "# 可独立发布的双语 Shorts" not in text:
        errors.append("long format requires two standalone bilingual Shorts")
    if fmt == "long":
        expected_shorts = [
            "## Shorts 1 · 中文",
            "## Shorts 1 · English",
            "## Shorts 2 · 中文",
            "## Shorts 2 · English",
        ]
        for heading in expected_shorts:
            if heading not in text:
                errors.append(f"missing bilingual Shorts heading: {heading}")
        if all(heading in text for heading in expected_shorts):
            short_1_zh = section(text, expected_shorts[0], [expected_shorts[1]])
            short_1_en = section(text, expected_shorts[1], [expected_shorts[2]])
            short_2_zh = section(text, expected_shorts[2], [expected_shorts[3]])
            short_2_en = section(text, expected_shorts[3], ["# 同步元数据"])
            for label, body in (("Shorts 1", short_1_zh), ("Shorts 2", short_2_zh)):
                count = len(re.findall(r"[\u3400-\u9fff]", body))
                short_metrics.append({"name": f"{label} · 中文", "count": count})
                if not 100 <= count <= 450:
                    errors.append(f"{label} Chinese script should be 100-450 characters; got {count}")
            for label, body in (("Shorts 1", short_1_en), ("Shorts 2", short_2_en)):
                count = len(re.findall(r"\b[A-Za-z]+(?:['’][A-Za-z]+)?\b", body))
                short_metrics.append({"name": f"{label} · English", "count": count})
                if not 90 <= count <= 220:
                    errors.append(f"{label} English script should be 90-220 words; got {count}")

    for phrase in FORBIDDEN:
        if phrase.lower() in text.lower():
            errors.append(f"unsupported growth guarantee/claim: {phrase}")

    for phrase in CHINGLISH:
        if phrase.lower() in english.lower():
            warnings.append(f"possible translated/essay English: {phrase}")

    contractions = len(
        re.findall(
            r"\b(?:it's|don't|doesn't|isn't|I'm|I've|that's|here's|can't|won't|I'd|I'll)\b",
            english,
            re.I,
        )
    )
    if fmt == "long" and contractions < 3:
        warnings.append("long English script may sound formal or translated; fewer than three natural contractions")

    sentence_lengths = []
    for sentence in re.split(r"(?<=[.!?])\s+", english):
        count = len(re.findall(r"\b[A-Za-z]+(?:['’][A-Za-z]+)?\b", sentence))
        if count:
            sentence_lengths.append(count)
    average_sentence_words = (
        round(sum(sentence_lengths) / len(sentence_lengths), 1) if sentence_lengths else 0.0
    )
    max_sentence_words = max(sentence_lengths, default=0)
    if average_sentence_words > 24:
        warnings.append(f"English may be dense for speech; average sentence length is {average_sentence_words} words")
    if max_sentence_words > 45:
        warnings.append(f"English contains a sentence longer than 45 words; max is {max_sentence_words}")

    if re.search(r"对对对|然后然后|嗯嗯嗯", text):
        warnings.append("repetitive filler remains in the candidate")
    if "待核验：无" in text:
        warnings.append("explicitly confirm that names, dates, prices, and claims really need no checks")

    return {
        "ok": not errors,
        "format": fmt,
        "source_note_id": source_id or None,
        "chinese_body_chars": chinese_chars,
        "english_script_words": english_words,
        "english_contractions": contractions,
        "english_average_sentence_words": average_sentence_words,
        "english_max_sentence_words": max_sentence_words,
        "short_metrics": short_metrics,
        "errors": errors,
        "warnings": warnings,
    }


def self_test() -> int:
    valid = """# 拍摄定位
观众：想理解中国日常科技的人
# 可直接录制逐字稿
## 中文逐字稿
我最近和一位朋友聊到一个很具体的问题：AI 到底什么时候才算真的进入生活？我觉得答案不是模型跑分，而是它能不能帮普通人完成一个真实动作。比如翻译、导航或者支付。说白了，技术只有离开演示页面，进入一天的生活，才开始有意义。我的判断不一定对，但这正是我接下来想亲自验证的事情：选一个真实场景，只看结果，不看宣传。你最希望我先测试哪一个场景？
## English verbatim script
When does AI actually become part of daily life? I don't think the answer is a benchmark. The real test is whether an ordinary person can use it to finish a real task. Can it translate a menu, find the right train, or help someone pay without creating three new problems? That's what I want to test. A polished demo can make almost anything look effortless, but real life includes weak signals, confusing accents, permissions, and mistakes. So I'm going to choose one ordinary situation and use the product from start to finish. I'll show what works, what fails, and where I still need to take control. Which test should I try first: translation, navigation, or payment?
# 拍摄提示
本人出镜；只拍实际拥有或能使用的工具。
# 标题、封面与传播设计
Title: When AI Leaves the Chatbox
# 发布前核验
核验产品名称；不出现私人信息。
# 同步元数据
schema: youtube-script-sync/v2
source_note_id: 1901355488706725360
source_updated_at: 2026-02-11 09:00:19
format: short
language: zh+en
generated_by: codex
"""
    invalid = valid.replace("format: short", "format: viral").replace("我最近", "必火。我最近")
    first = validate(valid)
    second = validate(invalid)
    ok = bool(first["ok"]) and not bool(second["ok"])
    print(json.dumps({"ok": ok, "valid_case": first, "invalid_case": second}, ensure_ascii=False, indent=2))
    return 0 if ok else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", help="Markdown candidate path; omit with --stdin")
    parser.add_argument("--stdin", action="store_true", help="Read candidate Markdown from stdin")
    parser.add_argument("--self-test", action="store_true", help="Run built-in positive and negative tests")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if args.stdin:
        text = sys.stdin.read()
    elif args.path:
        text = Path(args.path).read_text(encoding="utf-8")
    else:
        parser.error("provide a path, --stdin, or --self-test")

    result = validate(text)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
