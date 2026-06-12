#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
# ai-archive-daily.sh — launchd 每日驱动:增量导出 + 轻量备份 + 备份轮转
# 用绝对路径,避免 nvm/pyenv lazy-load 在 launchd 环境 PATH 缺失
set -Eeuo pipefail

HOME_DIR="$HOME"
# python3 多级回退(2026-06-12 修复:homebrew 无版本 symlink 消失,导出连续静默失败半个月)
PYTHON=""
for p in /opt/homebrew/bin/python3 /opt/homebrew/bin/python3.13 /usr/bin/python3; do
  [ -x "$p" ] && PYTHON="$p" && break
done
[ -n "$PYTHON" ] || { echo "FATAL: no python3 found" >&2; exit 1; }
LOG="$HOME_DIR/AI-Archive/daily.log"
mkdir -p "$HOME_DIR/AI-Archive"

{
  echo "===== $(date -Iseconds) ====="
  echo "[1/3] 增量导出 ..."
  "$PYTHON" "$HOME_DIR/.claude/scripts/ai-export.py" 2>&1 || echo "导出失败(非致命)"

  echo "[2/3] 轻量备份 ..."
  /bin/bash "$HOME_DIR/.claude/scripts/ai-backup.sh" 2>&1 || echo "备份失败(非致命)"

  echo "[3/3] 备份轮转:只保留最近 7 份 ..."
  ls -t "$HOME_DIR/AI-Session-Backups/"ai-history-*.tar.gz 2>/dev/null \
    | tail -n +8 | while read -r old; do
        echo "删除旧备份: $old"
        rm -f "$old"
      done
  echo "完成 $(date -Iseconds)"
} >> "$LOG" 2>&1
