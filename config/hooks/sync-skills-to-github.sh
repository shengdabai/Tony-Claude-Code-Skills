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

# Sync skills
mkdir -p "$REPO_DIR/skills/follow-builders"
mkdir -p "$REPO_DIR/skills/frontend-slides"
cp -f "$SKILLS_SRC/follow-builders/SKILL.md" "$REPO_DIR/skills/follow-builders/SKILL.md" 2>/dev/null
cp -f "$SKILLS_SRC/frontend-slides/SKILL.md" "$REPO_DIR/skills/frontend-slides/SKILL.md" 2>/dev/null
cp -f "$SKILLS_SRC/frontend-slides/STYLE_PRESETS.md" "$REPO_DIR/skills/frontend-slides/STYLE_PRESETS.md" 2>/dev/null
cp -f "$SKILLS_SRC/frontend-slides/viewport-base.css" "$REPO_DIR/skills/frontend-slides/viewport-base.css" 2>/dev/null
cp -f "$SKILLS_SRC/frontend-slides/html-template.md" "$REPO_DIR/skills/frontend-slides/html-template.md" 2>/dev/null
cp -f "$SKILLS_SRC/frontend-slides/animation-patterns.md" "$REPO_DIR/skills/frontend-slides/animation-patterns.md" 2>/dev/null

# Sync settings
cp -f "$SETTINGS_SRC" "$REPO_DIR/settings.json" 2>/dev/null

# Commit and push if there are changes
if git diff --quiet && git diff --cached --quiet; then
  exit 0
fi

git add -A
git commit -m "auto-sync: update skills and config ($(date '+%Y-%m-%d %H:%M'))" --quiet 2>/dev/null
git push --quiet 2>/dev/null
