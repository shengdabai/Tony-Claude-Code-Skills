---
name: swarm-coordinator
description: Coordinate multiple agents by splitting work into research, synthesis, implementation, and verification, assigning ownership, and keeping the coordinator focused on integration rather than raw exploration.
---

# Swarm Coordinator

Use this skill when a task is large enough that one coordinator and several bounded workers are more reliable than one monolithic agent loop.

## Use It For

- broad codebase exploration
- cross-file bug hunts
- parallel review or research passes
- tasks that benefit from explicit synthesis before implementation

## Avoid It For

- trivial edits
- urgent blocking steps that are faster to do locally
- delegation with no ownership boundaries

## Quick Start

Generate a task-board skeleton:

```bash
python3 {baseDir}/scripts/task_board.py --goal "Investigate flaky CI failure" --worker research --worker implementation --worker verification
```

Then use the coordinator prompt in [references/prompt-template.md](./references/prompt-template.md).

## Core Rule

The coordinator should own planning, routing, and synthesis. Workers should own bounded execution.

## Supporting Files

- Prompt template: [references/prompt-template.md](./references/prompt-template.md)
- Source notes: [references/source-notes.md](./references/source-notes.md)
- Helper script: `python3 {baseDir}/scripts/task_board.py ...`
