#!/usr/bin/env python3
"""Scan a memory directory and print a lightweight manifest for prompt context."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)


def parse_frontmatter(text: str) -> dict[str, str]:
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}
    data: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip('"')
    return data


def build_manifest(memory_root: Path) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for path in sorted(memory_root.glob("*.md")):
        if path.name == "MEMORY.md":
            continue
        text = path.read_text(encoding="utf-8")
        frontmatter = parse_frontmatter(text)
        items.append(
            {
                "file": path.name,
                "type": frontmatter.get("type"),
                "title": frontmatter.get("title"),
                "description": frontmatter.get("description"),
            }
        )
    return items


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--memory-root", required=True)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    manifest = build_manifest(Path(args.memory_root).expanduser())
    if args.json:
        print(json.dumps(manifest, indent=2, ensure_ascii=False))
        return 0

    for item in manifest:
        print(
            f"- {item['file']}"
            f" | type={item['type'] or 'unknown'}"
            f" | title={item['title'] or '-'}"
            f" | description={item['description'] or '-'}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
