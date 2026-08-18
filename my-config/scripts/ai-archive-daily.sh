#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
# ai-archive-daily.sh — launchd 每日驱动:轻量备份 + 备份轮转
# 会话归一化与搜索已统一交给 /Volumes/2T/03-ai-memory-system/bin/ai-mem；
# 此任务不再写入 ~/AI-Archive/normalized，避免长期生成第二套会话库。
# 用绝对路径,避免 nvm/pyenv lazy-load 在 launchd 环境 PATH 缺失
set -Eeuo pipefail

HOME_DIR="$HOME"
LOG="$HOME_DIR/AI-Archive/daily.log"
mkdir -p "$HOME_DIR/AI-Archive"

{
  echo "===== $(date -Iseconds) ====="
  echo "[1/3] 旧归一化导出已停用（统一索引由 com.tony.ai-mem-fast 维护）"

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
