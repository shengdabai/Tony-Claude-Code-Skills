---
description: Intelligently group unstaged changes and commit them systematically
argument-hint: "[--auto-commit] [--dry-run]"
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Read, Edit
model: openai/gpt-5.2-pro
---

Please help me intelligently group unstaged changes and commit them systematically.

**Arguments:**

- `--auto-commit`: Skip confirmation for each group (review all, then auto-commit)
- `--dry-run`: Show groups without committing anything

Arguments provided: $ARGUMENTS

## Phase 1: Analyze Unstaged Changes

1. **Check for unstaged changes:**

   ```bash
   git status --short
   git diff --name-status
   ```

2. **If no unstaged changes exist:**
   - Inform the user there's nothing to commit
   - Exit gracefully

3. **Get detailed diff for analysis:**
   ```bash
   git diff --stat
   git diff
   ```

## Phase 2: Intelligent Grouping

Analyze all unstaged files and group them using this **hybrid strategy**:

### Priority 1: Infrastructure Files (Always Separate)

Group these files separately as they often deserve their own commits:

- Package managers: `package.json`, `package-lock.json`, `requirements.txt`, `Pipfile`, `Cargo.toml`, `go.mod`
- Build configs: `Makefile`, `webpack.config.*`, `vite.config.*`, `rollup.config.*`
- Docker: `Dockerfile`, `docker-compose.yml`, `.dockerignore`
- CI/CD: `.github/workflows/*`, `.gitlab-ci.yml`, `Jenkinsfile`

### Priority 2: Commit Type Classification

For remaining files, determine commit type based on:

**test** - Test file changes:

- `test/`, `tests/`, `spec/`, `__tests__/`
- `*.test.*`, `*.spec.*`, `*_test.*`

**docs** - Documentation changes:

- `*.md`, `*.txt`, `docs/`, `README*`, `CHANGELOG*`, `LICENSE`
- JSDoc/docstring-only changes

**fix** - Bug fixes:

- Look for keywords in diffs: `fix`, `correct`, `resolve`, `patch`, `repair`, `bug`
- Files with small, targeted changes that correct issues

**feat** - New features:

- New files being added
- Significant new functionality (look for new functions/classes/components)
- Major additions to existing files

**refactor** - Code restructuring:

- Similar insertion/deletion ratios
- Moved/renamed files
- Code reorganization without functionality changes

**perf** - Performance improvements:

- Optimizations, caching, algorithm improvements
- Look for keywords: `optimize`, `cache`, `performance`, `faster`

**style** - Code style/formatting:

- Whitespace-only changes
- Linting fixes
- Formatting changes without logic modifications

**chore** - Maintenance tasks:

- `.gitignore`, editor configs
- Minor tooling updates
- Cleanup tasks

### Priority 3: Directory-Based Sub-grouping

Within each commit type, further group by:

- Top-level directory (e.g., `frontend/`, `backend/`, `src/`, `lib/`)
- If too granular, group by common parent directory
- Keep related files together (e.g., a component and its test)

### Grouping Constraints:

- **Min 1 file per group** (don't skip single files)
- **Max 20 files per group** (prevent massive commits)
- **If a group exceeds 20 files**, split by subdirectory or file type

## Phase 3: Present Groups to User

Display all groups in this format:

```
📊 Found X unstaged files grouped into Y commits:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GROUP 1: 🏗️ build (infrastructure) - 2 files
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📦 package.json
  📦 package-lock.json

Suggested commit: build: update dependencies for security patches

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GROUP 2: ✨ feat (backend/api) - 5 files
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✨ backend/api/routes/telemetry.py
  ✨ backend/api/models/telemetry.py
  ✨ backend/api/schemas/telemetry.py
  ✨ backend/core/telemetry_processor.py
  ✨ backend/tests/test_telemetry.py

Suggested commit: feat(api): add telemetry ingestion endpoints

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GROUP 3: 📝 docs - 3 files
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📄 README.md
  📄 docs/api/telemetry.md
  📄 CHANGELOG.md

Suggested commit: docs: add telemetry API documentation

```

**If `--dry-run` is provided:** Stop here and exit.

## Phase 4: Interactive Commit Process

For each group (unless `--auto-commit` is provided):

1. **Show current group details:**

   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   📌 Processing GROUP X of Y
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Type: <commit-type>
   Files: X files
   Suggested: <suggested-commit-message>
   ```

2. **Ask for confirmation:**

   ```
   Options:
   - 'y' or Enter: Proceed with this group
   - 'n' or 'skip': Skip this group
   - 'split': Split this group into smaller groups
   - 'edit': Manually modify file list for this group
   - 'quit': Stop processing (remaining files stay unstaged)
   ```

3. **Based on user response:**

   **If 'y' or Enter:**
   - Stage all files in the group: `git add <files>`
   - Run the commit command: `/commit <type> <scope> <description>`
   - Wait for commit completion (handle pre-commit hooks as per commit.md)
   - Proceed to next group

   **If 'n' or 'skip':**
   - Leave files unstaged
   - Proceed to next group

   **If 'split':**
   - Re-analyze the group and split it (by subdirectory or size)
   - Present the new sub-groups
   - Process each sub-group with same interactive flow

   **If 'edit':**
   - Show numbered file list
   - Ask which files to include (e.g., "1,3,5-7" or "all except 2,4")
   - Create new group with selected files
   - Process remaining files as a separate decision

   **If 'quit':**
   - Report: "X groups committed, Y groups skipped, Z files remain unstaged"
   - Exit

## Phase 5: Summary

After processing all groups:

```
✅ Commit Grouping Complete!

📊 Statistics:
   • Groups committed: X
   • Groups skipped: Y
   • Total commits created: Z
   • Files remaining unstaged: N

Next steps:
   • Run `git log --oneline -n Z` to review commits
   • Run `git status` to see remaining unstaged files
```

## Edge Cases to Handle:

1. **No unstaged changes**: Inform user and exit
2. **Staged changes exist**: Warn user that staged files will be ignored (only process unstaged)
3. **Binary files**: Include in groups but note they're binary
4. **Deleted files**: Include in groups with 🗑️ indicator
5. **Renamed files**: Group with their commit type, note the rename
6. **Large groups (>20 files)**: Automatically split and inform user
7. **Merge conflicts**: Detect and warn user to resolve first
8. **Pre-commit hooks**: Handle gracefully as per commit.md (never amend)

## Implementation Notes:

- Use `git diff --name-status` to get file operation types (M=modified, A=added, D=deleted, R=renamed)
- Parse `git diff` content to analyze change patterns for smarter grouping
- For scope determination, extract the most specific common directory or component name
- Prioritize user feedback - if a grouping seems off, offer to regroup
- Save grouping decisions for learning (future enhancement: remember user preferences)

---

**Pro Tips:**

- Run with `--dry-run` first to review the grouping strategy
- Use `--auto-commit` when confident in the grouping
- Consider running after major refactoring sessions to systematically organize commits
- Pairs well with `git add -p` for fine-grained staging before grouping
