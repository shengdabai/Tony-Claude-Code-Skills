#!/usr/bin/env bash

# 古いブランチを削除するスクリプト
# Usage: ./clean-old-branches.sh [days] [--force]

set -euo pipefail

# 引数の検証
DAYS=${1:-30}
FORCE_DELETE=${2:-""}

# DAYSが数値かチェック
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "❌ エラー: 日数は正の整数で指定してください (指定値: $DAYS)"
  exit 1
fi

# Git リポジトリかチェック
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "❌ エラー: Gitリポジトリではありません"
  exit 1
fi

# 保護するブランチ
PROTECTED_BRANCHES="main|master|develop|dev|staging|production"

echo "🔍 ${DAYS}日より古いブランチを検索中..."

# 現在の日時（Unix timestamp）
CUTOFF_DATE=$(date -v-"${DAYS}"d +%s)

# 削除対象のブランチを確認（修正版）
OLD_BRANCHES=""
while IFS= read -r line; do
  if [[ -z "$line" ]]; then
    continue
  fi

  # 削除対象のブランチを確認
  OLD_BRANCHES=""
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi

    # git for-each-refの出力を正しく解析
    # 形式: "2025-06-16 22:47:51 +0900 branch-name"
    read -r date time timezone branch_name <<<"$line"

    # 保護ブランチかチェック
    if [[ "$branch_name" =~ ^(${PROTECTED_BRANCHES})$ ]]; then
      continue
    fi

    # Unix timestampに変換（macOS対応）
    commit_timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$date $time $timezone" +%s 2>/dev/null || echo "0")

    # 古いブランチの場合のみ追加
    if [[ "$commit_timestamp" -ne 0 ]] && [[ "$commit_timestamp" -lt "$CUTOFF_DATE" ]]; then
      if [[ -n "$OLD_BRANCHES" ]]; then
        OLD_BRANCHES="$OLD_BRANCHES\n$branch_name"
      else
        OLD_BRANCHES="$branch_name"
      fi
    fi
  done < <(git for-each-ref --format='%(committerdate:iso8601) %(refname:short)' refs/heads/)
done < <(git for-each-ref --format='%(committerdate:iso8601) %(refname:short)' refs/heads/)

if [[ -z "$OLD_BRANCHES" ]]; then
  echo "✅ 削除対象のブランチはありません"
  exit 0
fi

echo "📋 削除対象のブランチ:"
echo -e "$OLD_BRANCHES" | sed 's/^/  - /'

# worktreeでチェックアウトされているブランチを確認
WORKTREE_BRANCHES=""
if command -v git >/dev/null 2>&1; then
  WORKTREE_BRANCHES=$(git worktree list --porcelain 2>/dev/null | grep "^branch " | sed 's/^branch //' || true)
fi

# 確認プロンプト
if [[ "$FORCE_DELETE" != "--force" ]]; then
  echo ""
  read -p "⚠️  これらのブランチを削除しますか？ (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ キャンセルされました"
    exit 0
  fi
fi

# 削除実行
echo ""
echo "🗑️  ブランチを削除中..."

# まずはマージ済みブランチのみ安全に削除
DELETED_COUNT=0
FAILED_BRANCHES=""
WORKTREE_PROTECTED=""

while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue

  # worktreeでチェックアウトされているかチェック
  if [[ -n "$WORKTREE_BRANCHES" ]] && echo "$WORKTREE_BRANCHES" | grep -Fxq "$branch"; then
    echo "  ⚠️  $branch (worktreeでチェックアウト中)"
    WORKTREE_PROTECTED="$WORKTREE_PROTECTED$branch\n"
    continue
  fi

  if git branch -d "$branch" 2>/dev/null; then
    echo "  ✅ $branch"
    ((DELETED_COUNT++))
  else
    echo "  ⚠️  $branch (マージされていません)"
    FAILED_BRANCHES="$FAILED_BRANCHES$branch\n"
  fi
done <<<"$(echo -e "$OLD_BRANCHES")"

echo ""
echo "✨ 完了: ${DELETED_COUNT}個のブランチを削除しました"

# worktreeで保護されたブランチがある場合の案内
if [[ -n "$WORKTREE_PROTECTED" ]]; then
  echo ""
  echo "🔒 以下のブランチはworktreeでチェックアウト中のため削除されませんでした："
  echo -e "$WORKTREE_PROTECTED" | sed 's/^/  - /'
  echo ""
  echo "💡 削除したい場合は、まず該当のworktreeを削除してください："
  echo "   git worktree remove <path>"
fi

# マージされていないブランチがある場合の案内
if [[ -n "$FAILED_BRANCHES" ]]; then
  echo ""
  echo "⚠️  以下のブランチはマージされていないため削除されませんでした："
  echo -e "$FAILED_BRANCHES" | sed 's/^/  - /'
  echo ""
  echo "💡 強制削除したい場合は以下のコマンドを使用してください："
  echo -e "$FAILED_BRANCHES" | sed 's/^/git branch -D /'
fi
