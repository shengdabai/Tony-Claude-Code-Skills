# Source Notes

This skill was derived from these Claude Code concepts:

- forked agent review flows
- task-based separation between implementation and verification
- stricter internal prompt rules around honesty and explicit validation

Portable extraction decisions:

- keep verifier behavior read-only by default
- keep "findings first" output
- avoid host-specific task APIs in the public version
