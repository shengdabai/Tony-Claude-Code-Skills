---
name: memory-extractor
description: Extract durable memories from recent conversation turns into user, feedback, project, and reference categories while avoiding stale code-state facts.
---

# Memory Extractor

Use this skill when you want to persist durable collaboration context from the latest conversation turns.

## Use It For

- capturing user preferences
- saving feedback about how to work
- recording non-code project constraints or deadlines
- storing pointers to external systems

## Avoid It For

- storing code structure or file locations
- saving short-lived task state that belongs in a plan
- duplicating an existing memory topic without checking first

## Quick Start

Build a manifest of existing memories:

```bash
python3 {baseDir}/scripts/memory_manifest.py --memory-root /path/to/memory
```

Then use the portable prompt in [references/prompt-template.md](./references/prompt-template.md).

## Four Types

- `user`
- `feedback`
- `project`
- `reference`

## Rules

- save only durable signals
- avoid code-state facts that can drift
- prefer updating an existing topic file
- organize by topic, not chronology

## Supporting Files

- Prompt template: [references/prompt-template.md](./references/prompt-template.md)
- Source notes: [references/source-notes.md](./references/source-notes.md)
- Helper script: `python3 {baseDir}/scripts/memory_manifest.py ...`
