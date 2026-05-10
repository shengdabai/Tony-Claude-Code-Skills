---
description: Create a conventional commit message for staged changes
argument-hint: [type] [scope] [description]
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git commit:*)
---

Create a conventional commit for STAGED changes only.

Arguments: $ARGUMENTS

**Workflow:**

1. Check staged changes: `git diff --cached --stat`
   - If nothing staged → inform user to run `git add` first
2. Analyze changes: `git diff --cached`

3. **Auto-detect commit type** (if no arguments provided):
   - `test`: Changes in test/spec files or _.test._, _.spec._
   - `docs`: Only _.md, _.txt, docs/, README
   - `ci`: .github/, .gitlab-ci.yml, CI configs
   - `build`: package.json, requirements.txt, Cargo.toml, go.mod
   - `fix`: Bug fixes (look for: fix, correct, resolve, bug keywords)
   - `feat`: New files or significant new functionality
   - `refactor`: Code restructuring (similar +/- lines, renames)
   - `perf`: Performance optimizations
   - `style`: Whitespace/formatting only
   - `chore`: Linting, gitignore, misc maintenance

4. **Parse arguments** (if provided):
   - First: type (feat, fix, docs, etc.)
   - Second (optional): scope
   - Rest: description

5. **Create commit:**
   - Format: `<type>(<scope>): <description>` or `<type>: <description>`
   - Description: present tense, concise, lowercase start
   - Add body for breaking changes or complex context
   - Execute: `git commit -m "message"`

**Rules:**

- ONLY commit staged files - never stage additional files
- Breaking changes: add `BREAKING CHANGE:` in body
- Description: max ~50 chars for summary
- DO NOT add co-authored-by messages
