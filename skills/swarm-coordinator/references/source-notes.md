# Source Notes

This skill was derived from these Claude Code areas:

- `src/tasks/InProcessTeammateTask/`
- `src/utils/swarm/permissionSync.ts`
- teammate mailbox and leader-mediated permission patterns

Portable extraction decisions:

- keep coordinator-worker role separation
- keep research → synthesis → implementation → verification
- drop host-specific pane management and AppleScript automation
