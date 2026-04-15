# CC Verification Gate

`verification-gate` is a portable read-only review skill that checks whether an implementation is actually done.

It is designed for the moment after coding appears complete: gather context, inspect what changed, and force a separate verification pass to label the result as verified, unverified, or failed.

## Best For

- post-implementation verification
- checking whether tests truly ran
- edge-case review before reporting completion
- preventing optimistic false-finish messages

## Included Files

- `SKILL.md`
- `references/prompt-template.md`
- `references/source-notes.md`
- `scripts/verification_context.py`

## Quick Start

```bash
python3 ./scripts/verification_context.py --repo /path/to/repo
```

Then run the verifier workflow from `SKILL.md`.

## Host Fit

- Claude Code: strong fit
- Codex: strong fit
- OpenClaw: workable, but strongest when the host supports a separate verifier pass
