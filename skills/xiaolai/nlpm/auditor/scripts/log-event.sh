#!/bin/bash
# Append a structured JSON event to auditor/logs/events.jsonl
# Usage: source scripts/log-event.sh
#        log_event "discover" "search_complete" '{"candidates": 42, "new": 15}'
#        log_event "audit" "score_computed" '{"repo": "owner/name", "score": 74}'

log_event() {
  local workflow="$1"
  local event="$2"
  local data="$3"
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local run_id="${GITHUB_RUN_ID:-local}"
  local run_num="${GITHUB_RUN_NUMBER:-0}"

  # Pipe data as stdin to jq — avoids all shell quoting issues with --argjson
  # Note: ${var:-{}} is broken in bash (extra }), use a temp variable instead
  local json_data="${data}"
  [ -z "$json_data" ] && json_data='{}'

  printf '%s' "$json_data" | jq -c \
    --arg ts "$timestamp" \
    --arg wf "$workflow" \
    --arg ev "$event" \
    --arg rid "$run_id" \
    --arg rn "${run_num:-0}" \
    '{timestamp: $ts, workflow: $wf, event: $ev, run_id: $rid, run_number: ($rn | tonumber), data: .}' \
    >> auditor/logs/events.jsonl 2>/dev/null || {
    # Fallback: data wasn't valid JSON, wrap as string
    jq -cn \
      --arg ts "$timestamp" \
      --arg wf "$workflow" \
      --arg ev "$event" \
      --arg rid "$run_id" \
      --arg rn "${run_num:-0}" \
      --arg d "$json_data" \
      '{timestamp: $ts, workflow: $wf, event: $ev, run_id: $rid, run_number: ($rn | tonumber), data: {raw: $d}}' \
      >> auditor/logs/events.jsonl
  }

  echo "[$workflow] $event: $data"
}

# Commit log entries (call at end of workflow)
commit_logs() {
  git config user.name "nlpm-auditor[bot]"
  git config user.email "nlpm-auditor[bot]@users.noreply.github.com"
  git add auditor/logs/events.jsonl
  git diff --cached --quiet || {
    git commit -m "log: $(date +%Y-%m-%d) $1"
    git push
  }
}
