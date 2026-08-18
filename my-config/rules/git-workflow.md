---
description: Git commit message 格式、PR 工作流、提交前安全门与推送前 sanity 检查。commit / push / 建 PR 前加载。
---

# Git Workflow

**commit / push / 建 PR 前按本文件的格式与安全门逐项过,不要跳过安全门直接提交。**

**Why**:git 历史是不可逆的——密钥一旦进了 commit,即便下一提交删掉,它仍在历史里,补救成本是 rotate 密钥加改写历史。提交前 10 秒的扫描换的是这个。

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
