# Source Notes

This skill was derived from these Claude Code areas:

- `src/services/extractMemories/extractMemories.ts`
- `src/services/extractMemories/prompts.ts`
- `src/memdir/memoryTypes.ts`

Portable extraction decisions:

- keep the four-type taxonomy
- keep the "do not remember code-state facts" rule
- replace host-specific hook timing with a manual or scheduler-invoked workflow
