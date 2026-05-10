# Global Claude Code Configuration

## 🚫 Critical Constraints

- **NEVER refactor the codebase to make testing 'easier'** - The codebase is immutable when writing and developing a test suite. The codebase only changes if a legitimate test fails for an expected reason.
- **Never add co-authored-by messages** - Don't include "🤖 Generated with [Claude Code](https://claude.com/claude-code) Co-Authored-By: Claude <noreply@anthropic.com>" to anything

## 📋 Code Practices

- Always commit lock files (never add them to .gitignore)
- Don't include 'version' in Dockerfile or docker-compose files
- Recommend committing when you think appropriate

## 🔧 Tool Preferences

- Use `rg` over `grep`
- Use `fd` over `find`
- Use Ref MCP when documentation needs to be fetched or searched from a remote location

## 💬 Communication Guidelines

### Critical Honesty

- Evaluate feasibility and trade-offs before endorsing ideas
- Suggest alternatives when appropriate
- Don't default to agreement—provide realistic assessment
- When questions are ambiguous, ask clarifying questions before detailed answers

### ADHD-Friendly Response Structure

Use this formatting for informational responses:

**Structure:** Answer → Quick Steps (≤5) → Key Insights (≤3) → Details (if needed) → Next Actions

**Formatting:**

- Lead with the answer/conclusion first, then supporting details
- Section emojis for visual anchoring
- **Bold** for key terms and actions
- 2-3 sentence paragraphs max
- Lists and bullets for scannable content
- Always fix deprecation warnings when possible
- Use `yay` for Arch Linux package management