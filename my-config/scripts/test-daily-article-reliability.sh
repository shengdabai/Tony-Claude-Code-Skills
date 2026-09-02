#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTICLE="$SCRIPT_DIR/daily-article.sh"
AI_NEWS="$SCRIPT_DIR/daily-ai-news.sh"
COMMON="$SCRIPT_DIR/daily-publish-common.sh"
ARTICLE_PLIST="$HOME/Library/LaunchAgents/com.tony.daily-article.plist"
AI_NEWS_PLIST="$HOME/Library/LaunchAgents/com.tony.daily-ai-news.plist"
DIGEST_PLIST="$HOME/Library/LaunchAgents/com.tony.daily-digest.plist"

bash -n "$ARTICLE"
bash -n "$AI_NEWS"
bash -n "$COMMON"

grep -q '^CODEX_MODEL="gpt-5\.6-sol"$' "$ARTICLE"
grep -q '^CODEX_MODEL="gpt-5\.6-sol"$' "$AI_NEWS"
if grep -q '^CODEX_MODEL="gpt-5\.5"$' "$ARTICLE" "$AI_NEWS"; then
  echo "daily generation still selects gpt-5.5" >&2
  exit 1
fi

if grep -qE '"\$CODEX".*exec[[:space:]]+resume|exec[[:space:]]+resume[[:space:]]+--last' "$ARTICLE" "$AI_NEWS"; then
  echo "unsafe Codex resume path is still executable in daily generation" >&2
  exit 1
fi

grep -q 'DAILY_ARTICLE_GENERATION_TIMEOUT.*480' "$ARTICLE"
grep -q 'DAILY_ARTICLE_AUDIT_TIMEOUT.*300' "$ARTICLE"
grep -q 'DAILY_AI_NEWS_GENERATION_TIMEOUT.*600' "$AI_NEWS"
grep -q 'DAILY_AI_NEWS_AUDIT_TIMEOUT.*600' "$AI_NEWS"
grep -q 'CLAUDE_SESSION_LOCK="${DAILY_SESSION_LOCK:-/tmp/daily-claude-session.lock}"' "$AI_NEWS"
grep -q 'timeout/gtimeout 不可用，拒绝无界执行' "$AI_NEWS"
grep -q 'git commit -q --only' "$AI_NEWS"
grep -q 'daily_notify_failure_once "daily-article"' "$ARTICLE"
grep -q '\[ -f "$DONE_MARK" \].*exit 1' "$ARTICLE"
grep -q 'daily_run_with_timeout 30 env' "$COMMON"

python3 - "$ARTICLE_PLIST" "$AI_NEWS_PLIST" "$DIGEST_PLIST" <<'PY'
import plistlib, sys

for name in sys.argv[1:]:
    with open(name, "rb") as source:
        data = plistlib.load(source)
    slots = data.get("StartCalendarInterval") or []
    if not isinstance(slots, list) or not slots:
        raise SystemExit(f"{name}: missing StartCalendarInterval list")
    minutes = sorted({int(slot["Minute"]) for slot in slots})
    if len(minutes) != 2 or (minutes[1] - minutes[0]) % 60 != 30:
        raise SystemExit(f"{name}: retry minutes are not 30 minutes apart: {minutes}")
PY

DAILY_TASK_BRIDGE=/nonexistent bash -c '
  log() { :; }
  source "$1"
  if daily_run_with_timeout 1 /bin/sleep 5; then
    exit 1
  fi
  if daily_notify_failure_once test-job "simulated failure" /tmp; then
    exit 1
  fi
' _ "$COMMON"

TEST_LOCK="${TMPDIR:-/tmp}/daily-article-policy-probe.$$"
probe_output="$(DAILY_SESSION_LOCK="$TEST_LOCK" DAILY_POLICY_PROBE=1 bash "$ARTICLE")"
grep -q 'article policy ok' <<<"$probe_output"
[ ! -d "$TEST_LOCK" ]

TEST_LOCK="${TMPDIR:-/tmp}/daily-ai-news-policy-probe.$$"
probe_output="$(DAILY_SESSION_LOCK="$TEST_LOCK" DAILY_POLICY_PROBE=1 bash "$AI_NEWS")"
grep -q 'ai-news policy ok' <<<"$probe_output"
[ ! -d "$TEST_LOCK" ]

echo "daily-article reliability smoke tests passed"
