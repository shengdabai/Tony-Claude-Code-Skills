# Source Notes

This skill was derived from these Claude Code areas:

- `src/tools/SleepTool/`
- `src/tools/BriefTool/`
- `src/tools/ScheduleCronTool/`
- `src/tools.ts`

Portable extraction decisions:

- keep sleep, brief, schedule, and expiry as the core loop
- drop Anthropic-only feature gating and push-notification internals
- express proactive work as a portable job spec
