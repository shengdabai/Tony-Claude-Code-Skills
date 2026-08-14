#!/bin/bash
# Start complaint radar from stdin without interpolating user text into a shell command.
set -euo pipefail

chat_id="${FEISHU_CURRENT_CHAT_ID:-${AFC_CHAT_ID:-${AGENT_FEISHU_CHAT_ID:-}}}"
if [ -z "$chat_id" ]; then
  echo "ERR: triggering Feishu chat id is unavailable; refusing to guess a destination" >&2
  exit 3
fi
if [[ ! "$chat_id" =~ ^oc_[[:alnum:]_-]+$ ]]; then
  echo "ERR: invalid Feishu chat id; refusing to send" >&2
  exit 3
fi

seed="$(cat)"
if [ -z "${seed//[[:space:]]/}" ]; then
  echo "ERR: complaint seed is empty" >&2
  exit 2
fi
if [ "${#seed}" -gt 4000 ]; then
  echo "ERR: complaint seed exceeds 4000 characters" >&2
  exit 2
fi

export FEISHU_CURRENT_CHAT_ID="$chat_id"
export FEISHU_RECEIVE_ID_TYPE="chat_id"
nohup bash "$HOME/Desktop/01-项目开发/36-抱怨搜集系统/bin/on_demand.sh" \
  "$seed" --bot codex >/dev/null 2>&1 &
echo "STARTED complaint radar pid=$!"
