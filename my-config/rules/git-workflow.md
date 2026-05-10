# Git Workflow

## Commit Message Format

```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

Note: Attribution disabled globally via `~/.claude/settings.json`.

## PR Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit) — `git log base..HEAD`
2. Use `git diff base...HEAD` to see all changes
3. Title < 70 chars; body has Summary + Test plan
4. Push with `-u` flag if new branch

## Pre-Commit Security Gate

Before any `git commit`:
- [ ] No hardcoded secrets — scan with `git diff --cached | grep -iE 'sk-|ghp_|api[_-]?key|secret|password'`
- [ ] `.env` / `*.key` / `*.pem` not staged
- [ ] No `console.log` / `print()` debug statements

If secrets found: STOP, rotate the leaked key first, then `git restore --staged <file>`.

## Pre-Push Sanity

Before any `git push`:
- Verify remote: `git remote -v` matches expected repo
- Check for nested `.git` directories: `find . -name .git -not -path './.git*'`
- For public repos: re-scan for credentials in tracked files (Cardinal Rule 4 of `sync-skills-preflight` skill)
