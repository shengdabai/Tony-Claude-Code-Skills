# CC Memory Extractor

`memory-extractor` is a portable skill for extracting durable collaboration memory from recent turns.

It stores four stable classes of memory: `user`, `feedback`, `project`, and `reference`. The key design rule is simple: remember durable preferences and constraints, but do not store drifting code facts that should be re-read from source.

## Best For

- capturing user preferences
- saving working-style feedback
- recording non-code project constraints
- storing stable external references

## Included Files

- `SKILL.md`
- `references/prompt-template.md`
- `references/source-notes.md`
- `scripts/memory_manifest.py`

## Quick Start

```bash
python3 ./scripts/memory_manifest.py --memory-root /path/to/memory
```

Then use the extraction flow in `SKILL.md`.

## Host Fit

- Claude Code: strong fit
- Codex: strong fit
- OpenClaw: strong fit
