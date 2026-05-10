#!/bin/bash
# Auto-sync Claude Code skills to GitHub on session end.
# Installed as a Stop hook in ~/.claude/settings.json.
#
# Sync policy (updated 2026-04-25):
# - Only skills/ is synced. settings.json is NEVER pushed (it contains
#   internal paths, ntfy topic, MCP layout — not for public repo).
# - Pre-push secret scan blocks the push if any tracked file matches
#   high-confidence credential patterns.

REPO_DIR="$HOME/Desktop/项目开发/01-Claude生态/Tony-Claude-Code-Skills"
SKILLS_SRC="$HOME/.claude/skills"

# Ensure local repo exists
if [ ! -d "$REPO_DIR/.git" ]; then
  mkdir -p "$REPO_DIR"
  gh repo clone shengdabai/Tony-Claude-Code-Skills "$REPO_DIR" -- --quiet 2>/dev/null
  [ ! -d "$REPO_DIR/.git" ] && exit 0
fi

cd "$REPO_DIR" || exit 0
git pull --rebase --quiet 2>/dev/null

# Ensure .gitignore excludes settings + secret-bearing files
GITIGNORE="$REPO_DIR/.gitignore"
ensure_ignore() {
  grep -qxF "$1" "$GITIGNORE" 2>/dev/null || echo "$1" >> "$GITIGNORE"
}
touch "$GITIGNORE"
ensure_ignore "settings.json"
ensure_ignore "settings.local.json"
ensure_ignore ".env"
ensure_ignore ".env.*"
ensure_ignore "*.key"
ensure_ignore "*.pem"
ensure_ignore "config/settings.json"

# Sync all skills (exclude .git to avoid nested repos)
# Use --checksum so identical content is NOT re-touched (avoids spurious commits
# from mtime-only changes during normal conversations).
if [ -d "$SKILLS_SRC" ]; then
  for skill_dir in "$SKILLS_SRC"/*/; do
    [ ! -d "$skill_dir" ] && continue
    skill_name=$(basename "$skill_dir")
    mkdir -p "$REPO_DIR/skills/$skill_name"
    rsync -rlpt --checksum --exclude='.git' --exclude='.env' --exclude='*.key' --exclude='*.pem' "$skill_dir" "$REPO_DIR/skills/$skill_name/" 2>/dev/null
  done
fi

# Remove any tracked nested .git references
git ls-files --error-unmatch skills/.git 2>/dev/null && git rm --cached -r skills/.git 2>/dev/null
git ls-files --error-unmatch 'skills/*/.git' 2>/dev/null && git rm --cached -r 'skills/*/.git' 2>/dev/null

# Pre-push secret scan: block push if tracked files contain high-risk credentials.
# Patterns are conservative (high-confidence only) to avoid false positives.
SECRET_HITS=$(git ls-files | xargs grep -lE \
  'sk-[a-zA-Z0-9]{32,}|ghp_[a-zA-Z0-9]{30,}|gho_[a-zA-Z0-9]{30,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9a-zA-Z]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----' \
  2>/dev/null | head -5)

if [ -n "$SECRET_HITS" ]; then
  # Log to a sentinel file so the user can find it; do NOT push
  mkdir -p "$HOME/.omc/logs" 2>/dev/null
  printf "[%s] sync-skills aborted — secrets in:\n%s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$SECRET_HITS" \
    >> "$HOME/.omc/logs/sync-skills-secret-block.log"
  exit 0
fi

# Commit and push if there are changes
if git diff --quiet && git diff --cached --quiet; then
  exit 0
fi

git add -A
git commit -m "auto-sync: update skills ($(date '+%Y-%m-%d %H:%M'))" --quiet 2>/dev/null
git push --quiet 2>/dev/null
