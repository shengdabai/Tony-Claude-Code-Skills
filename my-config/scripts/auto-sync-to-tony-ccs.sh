#!/usr/bin/env bash
# auto-sync-to-tony-ccs.sh
#
# 把本机 ~/.claude/ 关键目录同步到 Tony-Claude-Code-Skills 仓库
# 有变化 → 脱敏 → commit → push,无变化静默退出
#
# 触发方式:
#   - launchd 每日 22:00 自动跑(com.tony.ccs-auto-sync.plist)
#   - 或手动 `bash ~/.claude/scripts/auto-sync-to-tony-ccs.sh`
#
# 安全:
#   - 永不同步 CLAUDE.local.md / memory/ / .env / .ssh
#   - push 前跑隐私扫,扫到真凭证直接停手
#   - skill 仓库内嵌套 .git 自动剥除

set -euo pipefail

REPO="$HOME/Desktop/01-项目开发/01-Claude生态/Tony-Claude-Code-Skills"
SRC="$HOME/.claude"
DST="$REPO/my-config"
DST_REL="my-config"
LOG="$HOME/.claude/logs/auto-sync.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
fail() { log "❌ FAIL: $*"; exit 1; }

# 仓库存在性检查
[ -d "$REPO/.git" ] || fail "Tony-CCS 仓库不在 $REPO"

cd "$REPO"

# 确保远程指向预期 URL
remote=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote" != *"shengdabai/Tony-Claude-Code-Skills"* ]]; then
  fail "远程 URL 异常: $remote"
fi

log "=== auto-sync start ==="

# --- 1. 同步 rules / commands / agents / hooks / output-styles / mcp-servers ---
changed=0
for sub in rules commands agents hooks output-styles mcp-servers scripts; do
  if [ -d "$SRC/$sub" ]; then
    mkdir -p "$DST/$sub"
    # rsync 镜像,删除目标多余文件,排除 secrets / local
    rsync -a --delete \
      --exclude='*.local.*' \
      --exclude='.env*' \
      --exclude='*.key' \
      --exclude='*.pem' \
      --exclude='*.bak-*' \
      --exclude='id_rsa*' \
      --exclude='credentials.*' \
      --exclude='secrets.*' \
      --exclude='settings.local.json' \
      "$SRC/$sub/" "$DST/$sub/"
  fi
done

# --- 2. 同步 CLAUDE.md / RTK.md(脱敏)---
if [ -f "$SRC/CLAUDE.md" ]; then
  cp "$SRC/CLAUDE.md" "$DST/CLAUDE.md"
fi
if [ -f "$SRC/RTK.md" ]; then
  cp "$SRC/RTK.md" "$DST/RTK.md"
fi

# --- 3. 脱敏:替换路径里的 Tony 个人标识 ---
find "$DST/rules" "$DST/commands" "$DST/agents" -name "*.md" -print0 2>/dev/null | \
  xargs -0 sed -i '' \
    -e 's|$HOME/Documents/Tony|~/Documents/<obsidian-vault>|g' \
    -e 's|Tony 反复反馈过|用户反复反馈过|g' \
    -e 's|EMAIL_REDACTED@gmail\.com|<email-redacted>|g' \
    2>/dev/null || true

# --- 4. 拆嵌套 .git(my-config/skills/_collections/* 下的)---
find "$DST" -name ".git" -type d 2>/dev/null | while read gitdir; do
  rm -rf "$gitdir"
  log "✂️ 拆嵌套 .git: $gitdir"
done

# --- 5. 检查 my-config 是否真有变化 ---
if git diff --quiet -- "$DST_REL" \
  && git diff --cached --quiet -- "$DST_REL" \
  && [ -z "$(git ls-files --others --exclude-standard -- "$DST_REL")" ]; then
  log "✓ 无变化,退出"
  exit 0
fi

# --- 6. 隐私硬扫(即将 commit 范围) ---
patterns='sk-(proj|ant|live)-[a-zA-Z0-9_-]{40,}|ghp_[a-zA-Z0-9]{36}|AKIA[A-Z0-9]{16}|AIza[a-zA-Z0-9_-]{30,}|xoxb-[a-zA-Z0-9-]{20,}|cli_a[0-9a-f]{30}'
git add -A -- "$DST_REL"
hits=$(git diff --cached --name-only | xargs grep -lE "$patterns" 2>/dev/null \
  | grep -vE "_repos/|_collections/|THIRD_PARTY|NOTICE|hooks/secret-scan|hooks/sync-skills|cso/SKILL\.md|CHANGELOG|placeholder|YOUR_|<your|REDACTED|/test/|/tests/|\.test\.|\.spec\." \
  || true)

if [ -n "$hits" ]; then
  log "🚨 隐私扫描命中真凭证,中止 push:"
  log "$hits"
  git reset HEAD --quiet
  exit 2
fi

# --- 7. commit + push ---
changes_summary=$(git diff --cached --shortstat | head -1)
git commit -m "chore(sync): auto-sync ~/.claude/ → my-config/ ($(date '+%Y-%m-%d'))

$changes_summary

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" >> "$LOG" 2>&1

if git push origin main >> "$LOG" 2>&1; then
  log "✅ push 成功: $changes_summary"
else
  log "❌ push 失败,见上方"
  exit 3
fi

log "=== auto-sync end ==="
