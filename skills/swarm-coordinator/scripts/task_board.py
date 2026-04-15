#!/usr/bin/env python3
"""Generate a simple coordinator task board."""

from __future__ import annotations

import argparse
import json


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--goal", required=True)
    parser.add_argument("--worker", action="append", default=[])
    parser.add_argument("--format", choices=["json", "markdown"], default="json")
    args = parser.parse_args()

    workers = args.worker or ["research", "synthesis", "implementation", "verification"]
    board = {
        "goal": args.goal,
        "phases": [
            {"phase": "research", "owner": workers[0] if len(workers) > 0 else None, "deliverable": "facts and evidence"},
            {"phase": "synthesis", "owner": workers[1] if len(workers) > 1 else None, "deliverable": "conclusions and plan"},
            {"phase": "implementation", "owner": workers[2] if len(workers) > 2 else None, "deliverable": "bounded code changes"},
            {"phase": "verification", "owner": workers[3] if len(workers) > 3 else None, "deliverable": "findings and gate decision"},
        ],
    }

    if args.format == "json":
        print(json.dumps(board, indent=2, ensure_ascii=False))
        return 0

    print(f"# Goal\n\n{board['goal']}\n")
    print("## Phases")
    for phase in board["phases"]:
        print(f"- {phase['phase']}: owner={phase['owner'] or '-'}; deliverable={phase['deliverable']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
