---
name: verification-gate
description: Run a read-only verification pass after implementation to check whether completion claims are real, validation actually ran, and obvious edge cases or regressions were missed.
---

# Verification Gate

Use this skill when the implementation should not be accepted without a separate challenge pass.

## Use It For

- post-implementation verification
- checking whether claimed tests really ran
- finding edge cases before reporting completion
- converting "looks done" into "verified" or "unverified"

## Quick Start

Collect a verification context from a git repo:

```bash
python3 {baseDir}/scripts/verification_context.py --repo /path/to/repo
```

Then run the portable verifier prompt from [references/prompt-template.md](./references/prompt-template.md).

## Verifier Rules

- default to read-only
- findings first
- never imply validation ran if it did not
- distinguish verified, unverified, and failed

## Supporting Files

- Prompt template: [references/prompt-template.md](./references/prompt-template.md)
- Source notes: [references/source-notes.md](./references/source-notes.md)
- Helper script: `python3 {baseDir}/scripts/verification_context.py ...`
