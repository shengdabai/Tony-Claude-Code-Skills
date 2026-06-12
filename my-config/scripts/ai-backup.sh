#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
# ai-backup.sh — 轻量备份 Claude + Codex 对话历史(跳过 sqlite/images 大件)
# 输出: ~/AI-Session-Backups/ai-history-<ts>.tar.gz (chmod 600)
set -Eeuo pipefail

ts="$(date +%Y%m%d-%H%M%S)"
out_dir="${HOME}/AI-Session-Backups"
stage="$(mktemp -d "${TMPDIR:-/tmp}/aibackup.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$out_dir"
chmod 700 "$out_dir"

log(){ printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

# --- Claude: 全部 jsonl(完整对话原文) ---
if [ -d "$HOME/.claude/projects" ]; then
  log "复制 Claude jsonl ..."
  mkdir -p "$stage/claude"
  # 只拷 jsonl,保留项目目录结构(rsync include/exclude)
  rsync -a --include='*/' --include='*.jsonl' --exclude='*' \
    "$HOME/.claude/projects/" "$stage/claude/" 2>/dev/null || true
fi

# --- Codex: sessions/ + history.jsonl + session_index.jsonl(跳过 173M sqlite) ---
if [ -d "$HOME/.codex" ]; then
  log "复制 Codex 会话 ..."
  mkdir -p "$stage/codex"
  [ -d "$HOME/.codex/sessions" ] && rsync -a "$HOME/.codex/sessions/" "$stage/codex/sessions/" 2>/dev/null || true
  for f in history.jsonl session_index.jsonl; do
    [ -f "$HOME/.codex/$f" ] && cp -p "$HOME/.codex/$f" "$stage/codex/" 2>/dev/null || true
  done
fi

# --- 元信息 ---
{
  echo "backup_at=$(date -Iseconds)"
  echo "host=$(hostname)"
  echo "claude_jsonl=$(find "$stage/claude" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')"
  echo "codex_session_files=$(find "$stage/codex" -type f 2>/dev/null | wc -l | tr -d ' ')"
} > "$stage/MANIFEST.txt"

archive="$out_dir/ai-history-${ts}.tar.gz"
log "打包 -> $archive"
tar -czf "$archive" -C "$stage" .
chmod 600 "$archive"

size="$(du -h "$archive" | cut -f1)"
log "完成: $archive ($size)"
echo "$archive"
