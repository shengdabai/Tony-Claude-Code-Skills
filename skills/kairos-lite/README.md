# CC Kairos Lite

`kairos-lite` is a portable proactive-agent skill for scheduled checks and short background jobs.

It extracts the useful parts of a proactive mode: schedule, sleep, brief, and expiry. It deliberately avoids assuming a permanent daemon or a private host notification system.

## Best For

- repo patrol jobs
- follow-up checks
- brief-style status messages
- proactive work with a fixed expiry window

## Included Files

- `SKILL.md`
- `references/prompt-template.md`
- `references/source-notes.md`
- `scripts/job_spec.py`

## Quick Start

```bash
python3 ./scripts/job_spec.py \
  --name "daily-repo-check" \
  --prompt "Summarize risky changes in the repo" \
  --schedule "0 9 * * 1-5"
```

Then map the generated job spec into your host automation flow.

## Host Fit

- Claude Code: strong fit
- Codex: workable, but requires host automation around it
- OpenClaw: strong fit
