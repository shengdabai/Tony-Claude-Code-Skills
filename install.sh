#!/usr/bin/env bash
# install.sh — Tony's Claude Code Workstation installer
#
# 把这个仓库的内容部署到本机 ~/.claude/ 下，使用软链/拷贝模式。
# Deploy this repo into your local ~/.claude/.
#
# Usage:
#   bash install.sh                 # interactive
#   bash install.sh --link          # symlink mode (跟仓库同步)
#   bash install.sh --copy          # copy mode (独立副本)
#   bash install.sh --dry-run       # 看会做什么不实际做

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
MODE="ask"
DRY=0

for arg in "$@"; do
  case "$arg" in
    --link) MODE="link" ;;
    --copy) MODE="copy" ;;
    --dry-run) DRY=1 ;;
    --help|-h)
      sed -n '2,15p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
  esac
done

echo "🤖 Tony's Claude Code Workstation Installer"
echo "Repo:   $REPO_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

if [[ "$MODE" == "ask" ]]; then
  if [[ $DRY -eq 1 ]]; then
    MODE="link"
    echo "[dry-run] mode defaulted to: link"
  else
    echo "Pick install mode:"
    echo "  1) link  - symlink to repo (auto-update on git pull)"
    echo "  2) copy  - copy independent files"
    read -rp "[1/2]: " choice
    [[ "$choice" == "2" ]] && MODE="copy" || MODE="link"
  fi
fi

run() {
  if [[ $DRY -eq 1 ]]; then
    echo "  [DRY] $*"
  else
    eval "$@"
  fi
}

mkdir -p "$CLAUDE_DIR"

# Step 1: my-config → ~/.claude/{rules,scripts,agents,commands,hooks,output-styles}
echo ""
echo "[1/4] Deploying my-config to ~/.claude/..."
for sub in rules scripts agents commands hooks output-styles; do
  src="$REPO_DIR/my-config/$sub"
  dst="$CLAUDE_DIR/$sub"
  if [[ -d "$src" ]]; then
    if [[ "$MODE" == "link" ]]; then
      run "ln -sfn '$src' '$dst'"
      echo "  ✓ ~/.claude/$sub → repo (linked)"
    else
      run "mkdir -p '$dst' && cp -R '$src/.' '$dst/'"
      echo "  ✓ ~/.claude/$sub (copied)"
    fi
  fi
done

# Step 2: skills/ → ~/.claude/skills/
echo ""
echo "[2/4] Deploying 100+ skills to ~/.claude/skills/..."
mkdir -p "$CLAUDE_DIR/skills"
for skill_dir in "$REPO_DIR/skills"/*/; do
  name=$(basename "$skill_dir")
  dst="$CLAUDE_DIR/skills/$name"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "  ⊘ ~/.claude/skills/$name exists (skip)"
    continue
  fi
  if [[ "$MODE" == "link" ]]; then
    run "ln -sfn '$skill_dir' '$dst'"
  else
    run "cp -R '$skill_dir' '$dst'"
  fi
done
echo "  ✓ $(ls "$REPO_DIR/skills" | wc -l | tr -d ' ') skills deployed"

# Step 3: opc-methodology → ~/.claude/skills/opc-*
echo ""
echo "[3/4] Deploying OPC methodology skills..."
for opc_skill in "$REPO_DIR/opc-methodology/skills"/opc-*/; do
  name=$(basename "$opc_skill")
  dst="$CLAUDE_DIR/skills/$name"
  if [[ "$MODE" == "link" ]]; then
    run "ln -sfn '$opc_skill' '$dst'"
  else
    run "cp -R '$opc_skill' '$dst'"
  fi
done
echo "  ✓ 9 opc-* skills deployed"

# Step 4: CLAUDE.md template
echo ""
echo "[4/4] CLAUDE.md..."
if [[ -e "$CLAUDE_DIR/CLAUDE.md" ]]; then
  echo "  ⊘ ~/.claude/CLAUDE.md exists, NOT overwriting"
  echo "    (review my-config/CLAUDE.md and merge manually if needed)"
else
  if [[ "$MODE" == "link" ]]; then
    run "ln -sfn '$REPO_DIR/my-config/CLAUDE.md' '$CLAUDE_DIR/CLAUDE.md'"
  else
    run "cp '$REPO_DIR/my-config/CLAUDE.md' '$CLAUDE_DIR/CLAUDE.md'"
  fi
  echo "  ✓ CLAUDE.md installed"
fi

echo ""
echo "🎉 Done. Restart Claude Code to load new config."
echo ""
echo "Next steps:"
echo "  - Review ~/.claude/CLAUDE.md and customize"
echo "  - Setup MCP servers (see my-config/mcp-servers/ or settings.template.json)"
echo "  - Try a skill: /opc-orchestrator (one-person business methodology)"
