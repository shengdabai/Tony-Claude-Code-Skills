#!/usr/bin/env python3
"""Collect lightweight git context for a verification pass."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any


def run_git(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=repo,
        capture_output=True,
        text=True,
        check=False,
    )
    return proc.stdout.strip()


def build_context(repo: Path) -> dict[str, Any]:
    return {
        "repo": str(repo),
        "status": run_git(repo, "status", "--short"),
        "diff_stat": run_git(repo, "diff", "--stat"),
        "changed_files": run_git(repo, "diff", "--name-only").splitlines(),
        "head": run_git(repo, "rev-parse", "--short", "HEAD"),
        "branch": run_git(repo, "rev-parse", "--abbrev-ref", "HEAD"),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    context = build_context(Path(args.repo).expanduser().resolve())
    if args.json:
        print(json.dumps(context, indent=2, ensure_ascii=False))
        return 0

    print(f"repo: {context['repo']}")
    print(f"branch: {context['branch']}")
    print(f"head: {context['head']}")
    print("status:")
    print(context["status"] or "  <clean>")
    print("diff_stat:")
    print(context["diff_stat"] or "  <none>")
    print("changed_files:")
    for item in context["changed_files"]:
        print(f"  - {item}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
