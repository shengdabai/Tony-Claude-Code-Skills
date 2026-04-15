# Source Notes

This skill was derived from these Claude Code areas:

- `src/services/autoDream/autoDream.ts`
- `src/services/autoDream/consolidationPrompt.ts`
- `src/memdir/memdir.ts`

Portable extraction decisions:

- keep the workflow and gating ideas
- drop Anthropic-specific feature flags and analytics
- replace host-specific task wiring with a plain helper script plus a portable prompt
