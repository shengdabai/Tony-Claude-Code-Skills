# CC Context Compressor

`structured-context-compressor` is a portable continuation-summary skill for long coding sessions.

Instead of a vague free-form summary, it produces a nine-part artifact that preserves request, files, errors, user messages, pending work, current work, and the next aligned step.

## Best For

- long coding conversations
- agent handoff
- continuation after context pressure
- preserving user corrections and constraints

## Included Files

- `SKILL.md`
- `references/prompt-template.md`
- `references/source-notes.md`
- `scripts/render_template.py`

## Quick Start

```bash
python3 ./scripts/render_template.py
```

Then fill the generated structure using the workflow from `SKILL.md`.

## Host Fit

- Claude Code: strong fit
- Codex: strong fit
- OpenClaw: strong fit
