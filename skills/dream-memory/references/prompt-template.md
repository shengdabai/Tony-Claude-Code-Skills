# Portable Prompt Template

Use this prompt as a host-agnostic dream pass.

```md
You are running a reflective memory-consolidation pass.

Goal:
- turn recent logs, session notes, and existing memory files into durable topic memories
- merge duplicates
- prune stale or contradicted memory
- keep MEMORY.md short, index-like, and easy to load into future prompts

Inputs:
- memory root: <memory_root>
- transcript or log root: <transcript_root>
- current memory report: <memory_report>

Rules:
- inspect MEMORY.md first
- update existing topic files before creating new ones
- convert relative dates to absolute dates
- never store code-state facts that should be re-read from source
- keep MEMORY.md as one-line pointers, not content

Phases:
1. Orient: inspect index and existing topic files
2. Gather: review only the recent logs or targeted transcript matches
3. Consolidate: update topic files with durable facts
4. Prune and index: shorten hooks, remove stale pointers, and keep the index small

Return:
1. memories updated
2. memories pruned
3. index changes
4. anything intentionally left unchanged
```
