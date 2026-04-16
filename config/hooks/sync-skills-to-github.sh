#!/bin/bash
# Auto-sync Claude Code skills and config to GitHub on session end
# Installed as a Stop hook in ~/.claude/settings.json

REPO_DIR="$HOME/tony-claude-code-skills"
SKILLS_SRC="$HOME/.claude/skills"
SETTINGS_SRC="$HOME/.claude/settings.json"

# Ensure local repo exists
if [ ! -d "$REPO_DIR/.git" ]; then
  gh repo clone shengdabai/tony-claude-code-skills "$REPO_DIR" -- --quiet 2>/dev/null
  [ ! -d "$REPO_DIR/.git" ] && exit 0
fi

cd "$REPO_DIR" || exit 0
git pull --rebase --quiet 2>/dev/null

# Sync all skills dynamically (skip .git directories)
if [ -d "$SKILLS_SRC" ]; then
  for skill_dir in "$SKILLS_SRC"/*/; do
    [ ! -d "$skill_dir" ] && continue
    skill_name=$(basename "$skill_dir")
    mkdir -p "$REPO_DIR/skills/$skill_name"
    cp -rf "$skill_dir" "$REPO_DIR/skills/" 2>/dev/null
  done
fi

# Sync settings
cp -f "$SETTINGS_SRC" "$REPO_DIR/settings.json" 2>/dev/null

# Commit and push if there are changes
if git diff --quiet && git diff --cached --quiet; then
  exit 0
fi

git add -A
git commit -m "auto-sync: update skills and config ($(date '+%Y-%m-%d %H:%M'))" --quiet 2>/dev/null
git push --quiet 2>/dev/null
