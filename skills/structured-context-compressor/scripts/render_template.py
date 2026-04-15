#!/usr/bin/env python3
"""Render the standard nine-section context-compression template."""

SECTIONS = [
    "1. Primary request and intent",
    "2. Key technical concepts",
    "3. Files and code sections",
    "4. Errors and fixes",
    "5. Problem solving",
    "6. All user messages",
    "7. Pending tasks",
    "8. Current work",
    "9. Next aligned step",
]


def main() -> int:
    for section in SECTIONS:
        print(section)
        print()
        print("-")
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
