#!/usr/bin/env bash

# ユーザーがプロンプトをサブミットした時に実行されるhook
# セッション開始時刻を記録し、既存のセッションデータをクリア

# 入力からセッションIDとトランスクリプトパスを取得
session_data=$(cat)
session_id=$(echo "$session_data" | jq -r '.session_id // empty')
transcript_path=$(echo "$session_data" | jq -r '.transcript_path // empty')

if [ -z "$session_id" ]; then
    exit 0
fi

# tmpファイルのパス
tmp_file="${TMPDIR:-/tmp}/claude-code-duration-${session_id}.json"

# transcript_pathのJSONLファイルからinterrupt情報を検出する関数
check_interrupt_in_transcript() {
    local transcript_path="$1"
    
    if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
        return 1  # interruptなし
    fi
    
    # 空行を除外してJSONLファイルの最後のJSON行を取得
    local last_line=$(grep -v '^$' "$transcript_path" | tail -n 1)
    
    if [ -z "$last_line" ]; then
        return 1  # interruptなし
    fi
    
    # JSON解析してmessage.contentをチェック
    # 配列形式とstring形式の両方をサポート
    local content=$(echo "$last_line" | jq -r '.message.content[0].text // .message.content // empty' 2>/dev/null)
    
    if [ "$content" = "[Request interrupted by user]" ]; then
        return 0  # interruptあり
    fi
    
    return 1  # interruptなし
}

# 現在のタイムスタンプをISO8601形式のUTC時刻で取得
# 例: "2025-08-21T18:04:18Z"
current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# interrupt判定と処理分岐
if check_interrupt_in_transcript "$transcript_path" && [ -f "$tmp_file" ]; then
    # interrupt後の継続：既存データを保持して一部更新
    existing_session_id=$(cat "$tmp_file" | jq -r '.sessionId // empty')
    existing_start=$(cat "$tmp_file" | jq -r '.startTimestamp // empty')
    existing_duration=$(cat "$tmp_file" | jq -r '.duration // 0')
    
    cat > "$tmp_file" << EOF
{
  "sessionId": "$existing_session_id",
  "startTimestamp": "$existing_start",
  "lastUpdate": "$current_timestamp",
  "duration": $existing_duration,
  "status": "interrupted"
}
EOF
else
    # 新規セッション（interruptなし or tmpファイルなし）
    cat > "$tmp_file" << EOF
{
  "sessionId": "$session_id",
  "startTimestamp": "$current_timestamp",
  "lastUpdate": "$current_timestamp",
  "duration": 0,
  "status": "active"
}
EOF
fi

exit 0
