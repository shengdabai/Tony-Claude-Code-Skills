---
name: structured-context-compressor
description: Compress a long agent conversation into a nine-part continuation summary that preserves request, files, errors, user messages, current work, and the next aligned step.
---

# Structured Context Compressor

Use this skill when a free-form summary is too lossy and you need a reliable continuation artifact.

## Use It For

- long coding conversations
- session handoff
- agent-to-agent continuation
- preserving user intent under context pressure

## Quick Start

Render the standard template:

```bash
python3 {baseDir}/scripts/render_template.py
```

Then apply the prompt in [references/prompt-template.md](./references/prompt-template.md).

## Nine Sections

1. primary request and intent
2. key technical concepts
3. files and code sections
4. errors and fixes
5. problem solving
6. all user messages
7. pending tasks
8. current work
9. next aligned step

## Highest-Value Rule

Preserve all user messages or an accurate equivalent. Do not compress away the corrections that changed the direction of work.

## Supporting Files

- Prompt template: [references/prompt-template.md](./references/prompt-template.md)
- Source notes: [references/source-notes.md](./references/source-notes.md)
- Helper script: `python3 {baseDir}/scripts/render_template.py`
