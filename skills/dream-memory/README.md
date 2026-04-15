# CC Dream Memory

`dream-memory` is a portable memory-consolidation skill for coding agents.

It turns recent logs, session transcripts, and existing memory files into a shorter, more stable long-term memory set. The workflow is inspired by the public `CC` dream-style memory pass, but rewritten to avoid private runtime dependencies.

## Best For

- nightly memory cleanup
- merging duplicate memory notes
- converting relative dates to absolute dates
- keeping `MEMORY.md` short and prompt-friendly

## Included Files

- `SKILL.md`
- `references/prompt-template.md`
- `references/source-notes.md`
- `scripts/dream_memory.py`

## Quick Start

```bash
python3 ./scripts/dream_memory.py \
  --memory-root /path/to/memory \
  --transcripts-dir /path/to/transcripts
```

Then apply the workflow in `SKILL.md` with the prompt template in `references/prompt-template.md`.

## Host Fit

- Claude Code: strong fit
- Codex: strong fit
- OpenClaw: strong fit
