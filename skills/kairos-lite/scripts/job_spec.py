#!/usr/bin/env python3
"""Create a portable proactive-job specification."""

from __future__ import annotations

import argparse
import json


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--schedule", required=True)
    parser.add_argument("--mode", choices=["recurring", "one-shot"], default="recurring")
    parser.add_argument("--expiry-days", type=int, default=7)
    parser.add_argument("--brief-status", choices=["normal", "proactive"], default="proactive")
    args = parser.parse_args()

    spec = {
        "name": args.name,
        "prompt": args.prompt,
        "schedule": args.schedule,
        "mode": args.mode,
        "expiry_days": args.expiry_days,
        "brief_status": args.brief_status,
    }
    print(json.dumps(spec, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
