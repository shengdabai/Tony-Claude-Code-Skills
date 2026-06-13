#!/bin/bash
# Auto-sync ~/Desktop/01-项目开发/01-Claude生态/Tony-claude-plugins to GitHub
# (private repo shengdabai/Tony-claude-plugins). Stop hook, async.
#
# Only commits + pushes when there are real changes. Pre-push secret scan
# blocks the push if any tracked file matches high-confidence credential
# patterns (private repo, but defense-in-depth per secrets-firewall rule).

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
REPO="$HOME/Desktop/01-项目开发/01-Claude生态/Tony-claude-plugins"

[ -d "$REPO/.git" ] || exit 0
cd "$REPO" || exit 0

# Nothing changed → fast exit.
git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ] && exit 0

# Pre-push secret scan on the pending diff.
if git add -A 2>/dev/null && git diff --cached \
   | grep -qiE 'sk-[a-zA-Z0-9]{20}|ghp_[a-zA-Z0-9]{36}|AKIA[0-9A-Z]{16}|-----BEGIN[A-Z ]+PRIVATE KEY-----'; then
  echo "ENV-GUARD: sync-plugins aborted — credential pattern detected in staged diff" >&2
  git reset -q
  exit 0
fi

TS=$(date '+%Y-%m-%d %H:%M')
git commit -q -m "chore: sync plugins ($TS)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" 2>/dev/null

git push -q origin HEAD 2>/dev/null || echo "[$(date "+%Y-%m-%d %H:%M")] push failed: sync-plugins-to-github.sh" >> "$HOME/.claude/logs/sync-push-fail.log"
exit 0
