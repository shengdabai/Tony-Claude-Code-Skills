#!/bin/bash
# Secret scan hook — runs after Edit/Write tools.
# Scans the tool's modified file for common secret patterns and warns inline.
# Non-blocking: warnings are advisory, never fail the tool call.

set -e

# Read tool input from stdin (Claude Code passes JSON)
INPUT=$(cat 2>/dev/null || echo "{}")

# Extract file path (Edit / Write tools have file_path field)
FILE_PATH=$(echo "$INPUT" | /usr/bin/python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')
    print(fp)
except Exception:
    print('')
" 2>/dev/null)

# No file path → silent exit
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# Skip non-text files (binaries, images, lockfiles)
case "$FILE_PATH" in
    *.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.tar|*.gz|*.lock|*.lockb|*.svg|*.ico|*.woff*|*.ttf|*.mp4|*.mp3) exit 0 ;;
esac

# Skip files inside .git, node_modules, dist, build
case "$FILE_PATH" in
    */.git/*|*/node_modules/*|*/dist/*|*/build/*|*/.next/*|*/target/*) exit 0 ;;
esac

# Skip large files to keep within 2s timeout (median scan time grows linearly with size).
# Threshold: 1 MB (1048576 bytes). Larger files = manual review only.
SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null || echo 0)
[ "$SIZE" -gt 1048576 ] && exit 0

# Patterns to flag (high-confidence — minimize false positives)
PATTERNS=(
    'sk-[a-zA-Z0-9]{32,}'                                          # OpenAI / Anthropic keys
    'sk-ant-[a-zA-Z0-9_-]{50,}'                                    # Anthropic API key
    'sk-proj-[a-zA-Z0-9_-]{50,}'                                   # OpenAI project key
    'ghp_[a-zA-Z0-9]{30,}'                                         # GitHub personal token
    'gho_[a-zA-Z0-9]{30,}'                                         # GitHub OAuth token
    'ghs_[a-zA-Z0-9]{30,}'                                         # GitHub server token
    'github_pat_[a-zA-Z0-9_]{30,}'                                 # GitHub fine-grained PAT
    'AKIA[0-9A-Z]{16}'                                             # AWS access key
    'AIza[0-9A-Za-z\-_]{35}'                                       # Google API key
    'AGNT[a-zA-Z0-9]{30,}'                                         # Anthropic agent token
    'xox[baprs]-[0-9a-zA-Z]{10,}'                                  # Slack tokens
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'                           # Private keys
    '(?i)(api[_-]?key|apikey)\s*[:=]\s*["'\''][a-zA-Z0-9_-]{20,}["'\'']'  # Generic api_key="..."
    '(?i)(secret|password|passwd|pwd)\s*[:=]\s*["'\''][^"'\''[:space:]]{8,}["'\'']'  # password="..."
    '(?i)(access[_-]?token|auth[_-]?token|bearer)\s*[:=]\s*["'\''][a-zA-Z0-9_.-]{20,}["'\'']'  # token="..."
    '(?i)anthropic[_-]?api[_-]?key\s*[:=]'                         # ANTHROPIC_API_KEY=
    '(?i)openai[_-]?api[_-]?key\s*[:=]'                            # OPENAI_API_KEY=
)

# 文件名警示:即使没匹配到密钥模式,如果用户在写 .env / *.key / *.pem 等文件,也提醒一下
case "$(basename "$FILE_PATH")" in
    .env|.env.*|*.env|*.pem|*.key|id_rsa*|id_ed25519*|credentials.json|secrets.*)
        printf "⚠️  SECRET-FILE: 你刚刚写入了 %s — 请确认未把明文密钥留在文件中,且文件已加入 .gitignore\n" "$FILE_PATH" >&2
        ;;
esac

MATCHES=""
for pattern in "${PATTERNS[@]}"; do
    HIT=$(grep -nE "$pattern" "$FILE_PATH" 2>/dev/null | head -3 || true)
    [ -n "$HIT" ] && MATCHES="${MATCHES}${HIT}\n"
done

if [ -n "$MATCHES" ]; then
    # stderr is shown to Claude as additional context (non-blocking)
    printf "⚠️  SECRET-SCAN: possible credential in %s\n%b\nIf intentional, ignore. Otherwise consider .gitignore + env var.\n" "$FILE_PATH" "$MATCHES" >&2
fi

exit 0
