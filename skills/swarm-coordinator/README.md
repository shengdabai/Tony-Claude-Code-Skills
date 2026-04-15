# CC Swarm Coordinator

`swarm-coordinator` is a portable multi-agent coordination skill for tasks that are too large or too noisy for one monolithic agent loop.

It keeps a coordinator focused on planning and synthesis while bounded workers handle research, implementation, and verification. The skill packages the organizational pattern, not a host-specific swarm runtime.

## Best For

- broad codebase exploration
- cross-file bug hunts
- parallel review or research passes
- tasks that need explicit synthesis before implementation

## Included Files

- `SKILL.md`
- `references/prompt-template.md`
- `references/source-notes.md`
- `scripts/task_board.py`

## Quick Start

```bash
python3 ./scripts/task_board.py \
  --goal "Investigate flaky CI failure" \
  --worker research \
  --worker implementation \
  --worker verification
```

Then use the coordinator workflow from `SKILL.md`.

## Host Fit

- Claude Code: strong fit
- Codex: strong fit
- OpenClaw: good fit for lightweight or manually coordinated swarms
