#!/usr/bin/env python3
"""Inspect a memory directory before or after a dream-style consolidation pass."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def build_report(memory_root: Path, transcripts_dir: Path | None, recent: int) -> dict[str, Any]:
    index_path = memory_root / "MEMORY.md"
    index_text = index_path.read_text(encoding="utf-8") if index_path.exists() else ""
    index_lines = index_text.splitlines()

    topic_files = sorted(
        [p for p in memory_root.glob("*.md") if p.name != "MEMORY.md"],
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )

    recent_sources: list[str] = []
    for pattern in ("logs/**/*.md", "sessions/**/*.md"):
        recent_sources.extend(
            str(p.relative_to(memory_root))
            for p in sorted(memory_root.glob(pattern), key=lambda p: p.stat().st_mtime, reverse=True)[:recent]
        )

    if transcripts_dir and transcripts_dir.exists():
        recent_sources.extend(
            str(p)
            for p in sorted(transcripts_dir.glob("**/*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)[:recent]
        )

    return {
        "memory_root": str(memory_root),
        "index": {
            "path": str(index_path),
            "exists": index_path.exists(),
            "line_count": len(index_lines),
            "byte_count": len(index_text.encode("utf-8")),
            "over_line_cap": len(index_lines) > 200,
            "over_byte_cap": len(index_text.encode("utf-8")) > 25_000,
        },
        "topic_files": [
            {
                "name": p.name,
                "path": str(p),
                "size_bytes": p.stat().st_size,
            }
            for p in topic_files[:recent]
        ],
        "recent_sources": recent_sources[:recent],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--memory-root", required=True)
    parser.add_argument("--transcripts-dir")
    parser.add_argument("--recent", type=int, default=10)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    report = build_report(
        Path(args.memory_root).expanduser(),
        Path(args.transcripts_dir).expanduser() if args.transcripts_dir else None,
        args.recent,
    )

    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0

    print(f"memory_root: {report['memory_root']}")
    print("index:")
    for key, value in report["index"].items():
        print(f"  {key}: {value}")
    print("topic_files:")
    for item in report["topic_files"]:
        print(f"  - {item['name']} ({item['size_bytes']} bytes)")
    print("recent_sources:")
    for item in report["recent_sources"]:
        print(f"  - {item}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
