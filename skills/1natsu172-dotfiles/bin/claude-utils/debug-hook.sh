#!/usr/bin/env bash

# Claude Code hooks debug script
# Outputs hook input to debug-claude-hook-{sessionId}.json in cwd

set -euo pipefail

# Read input from stdin
input=$(cat)

# Extract session_id and cwd from JSON input
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
cwd=$(echo "$input" | jq -r '.cwd // "."')

# Create output filename with session ID
output_file="$cwd/debug-claude-hook-$session_id.json"

# Add timestamp to the input JSON
timestamp=$(date -Iseconds)
enhanced_input=$(echo "$input" | jq --arg timestamp "$timestamp" '. + {debug_timestamp: $timestamp}')

# Append to the debug file (create if it doesn't exist)
if [[ -f "$output_file" ]]; then
    # File exists, append as array element
    tmp_file=$(mktemp)
    jq --argjson new_entry "$enhanced_input" '. + [$new_entry]' "$output_file" > "$tmp_file"
    mv "$tmp_file" "$output_file"
else
    # File doesn't exist, create new array
    echo "[$enhanced_input]" > "$output_file"
fi

# Optional: Log to stderr for debugging
echo "Debug: Hook input saved to $output_file" >&2
