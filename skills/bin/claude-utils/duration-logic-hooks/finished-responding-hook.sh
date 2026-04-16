#!/usr/bin/env bash

# Claude応答完了時に実行されるhook
# 最終的なdurationを記録してstatusをfinishedに変更

# 入力からセッションIDを取得
session_data=$(cat)
session_id=$(echo "$session_data" | jq -r '.session_id // empty')

if [ -z "$session_id" ]; then
    exit 0
fi

# tmpファイルのパス
tmp_file="${TMPDIR:-/tmp}/claude-code-duration-${session_id}.json"

# ファイルが存在しない場合は何もしない
if [ ! -f "$tmp_file" ]; then
    exit 0
fi

# 既存データを読み込み
existing_data=$(cat "$tmp_file")
start_timestamp=$(echo "$existing_data" | jq -r '.startTimestamp')

if [ -z "$start_timestamp" ] || [ "$start_timestamp" = "null" ]; then
    exit 0
fi

# 現在のタイムスタンプとdurationを計算
# 現在のUTC時刻をISO8601形式で取得 (例: "2025-08-21T18:06:30Z")
current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ISO8601文字列をUnixエポック秒に変換 (例: "2025-08-21T18:04:18Z" → 1755767058)
# macOS: date -j -f で指定フォーマットで解析、Linux: date -d で解析
start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start_timestamp" +%s 2>/dev/null || date -d "$start_timestamp" +%s 2>/dev/null)

# 現在時刻をUnixエポック秒で取得 (例: 1755767190)
# UTCタイムスタンプに合わせるため、現在時刻もISO8601形式経由で変換
current_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$current_timestamp" +%s 2>/dev/null || date -d "$current_timestamp" +%s 2>/dev/null)

# 経過時間を計算してミリ秒単位に変換 (例: (1755767190 - 1755767058) * 1000 = 132000)
duration=$(( (current_epoch - start_epoch) * 1000 ))

# データを更新（statusをfinishedに）
echo "$existing_data" | jq \
  --arg current_timestamp "$current_timestamp" \
  --argjson duration "$duration" \
  '.lastUpdate = $current_timestamp | .duration = $duration | .status = "finished"' \
  > "$tmp_file"

exit 0
