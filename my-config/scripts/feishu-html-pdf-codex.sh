#!/bin/bash
# Codex bot wrapper: bind the sender identity and the triggering chat outside model instructions.
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: feishu-html-pdf-codex.sh <html-path> [extra-css-path]" >&2
  exit 2
fi

chat_id="${FEISHU_CURRENT_CHAT_ID:-${AFC_CHAT_ID:-${AGENT_FEISHU_CHAT_ID:-}}}"
if [ -z "$chat_id" ]; then
  echo "ERR: triggering Feishu chat id is unavailable; refusing to guess a destination" >&2
  exit 3
fi
if [[ ! "$chat_id" =~ ^oc_[[:alnum:]_-]+$ ]]; then
  echo "ERR: invalid Feishu chat id; refusing to send" >&2
  exit 3
fi

export FEISHU_RECEIVE_ID_TYPE="chat_id"
exec bash "$HOME/.claude/scripts/feishu-html-pdf.sh" "$1" "$chat_id" "cli_aa9ae2200e795cb3" "${2:-}"
