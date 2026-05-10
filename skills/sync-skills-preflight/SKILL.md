---
name: sync-skills-preflight
description: Run before pushing to Tony-Claude-Code-Skills repo. Validates remote URL, scans tracked files for credentials (.env / api_key / secret patterns), detects nested .git directories that break pushes, and reports all issues. Use when about to commit or push skills/MCP/plugin changes to GitHub.
---

# Sync Skills Preflight

Validates the skills repo state before any push to GitHub. Catches the recurring class of bugs from prior sessions: wrong remote, nested .git, exposed credentials.

## Run These Checks (in order, parallel where possible)

### Check 1: Remote correctness
```bash
cd ~/.claude && git remote -v
```
**Expected**: origin → `Tony-Claude-Code-Skills` (NOT `claude-skills-collection`).
If wrong, STOP and ask user before any fix.

### Check 2: Credential scan
```bash
cd ~/.claude && git ls-files | xargs grep -l -iE 'api[_-]?key|secret|password|token|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{30,}' 2>/dev/null
```
Any output = STOP. Report each file and line. Do not proceed.

### Check 3: Nested .git directories
```bash
find ~/.claude -name .git -not -path '*/.claude/.git*' -not -path '*/node_modules/*' 2>/dev/null
```
Any output = nested repo will break push. Suggest `rm -rf <path>/.git` only after user confirms it's not an intentional submodule.

### Check 4: Uncommitted secrets staged
```bash
cd ~/.claude && git diff --cached | grep -iE 'api[_-]?key|secret|password|sk-|ghp_'
```

### Check 5: Branch is main
```bash
cd ~/.claude && git rev-parse --abbrev-ref HEAD
```

## Report Format

```
✓/✗ Remote: <url>
✓/✗ Credentials: <count> matches in <files>
✓/✗ Nested .git: <count> found at <paths>
✓/✗ Staged diff clean
✓/✗ On main branch
```

If all ✓ → safe to push. If any ✗ → halt, report, wait for user direction.

## What This Skill Does NOT Do

- Does not auto-fix any issues (user decides)
- Does not push (separate command)
- Does not modify .gitignore (suggest only)
