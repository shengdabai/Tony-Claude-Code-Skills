#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTICLE="$SCRIPT_DIR/daily-article.sh"
COMMON="$SCRIPT_DIR/daily-publish-common.sh"

bash -n "$ARTICLE"
bash -n "$COMMON"

if grep -qE '"\$CODEX".*exec[[:space:]]+resume' "$ARTICLE"; then
  echo "unsafe Codex resume path is still executable" >&2
  exit 1
fi

grep -q 'DAILY_ARTICLE_GENERATION_TIMEOUT.*480' "$ARTICLE"
grep -q 'DAILY_ARTICLE_AUDIT_TIMEOUT.*300' "$ARTICLE"
grep -q 'daily_notify_failure_once "daily-article"' "$ARTICLE"
grep -q '\[ -f "$DONE_MARK" \].*exit 1' "$ARTICLE"
grep -q 'daily_run_with_timeout 30 env' "$COMMON"

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

echo "daily-article reliability smoke tests passed"
