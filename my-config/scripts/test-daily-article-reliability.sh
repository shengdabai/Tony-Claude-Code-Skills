#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTICLE="$SCRIPT_DIR/daily-article.sh"
AI_NEWS="$SCRIPT_DIR/daily-ai-news.sh"
COMMON="$SCRIPT_DIR/daily-publish-common.sh"
DIGEST="$SCRIPT_DIR/daily-digest.sh"
DOCTOR="$SCRIPT_DIR/daily-publish-doctor.sh"
ARTICLE_PLIST="$HOME/Library/LaunchAgents/com.tony.daily-article.plist"
AI_NEWS_PLIST="$HOME/Library/LaunchAgents/com.tony.daily-ai-news.plist"
DIGEST_PLIST="$HOME/Library/LaunchAgents/com.tony.daily-digest.plist"

bash -n "$ARTICLE"
bash -n "$AI_NEWS"
bash -n "$COMMON"
bash -n "$DIGEST"
bash -n "$DOCTOR"
grep -q 'Codex CLI 可执行（${CODEX}）' "$DOCTOR"

# gen_readme.py writes four index files. The article and every generated index
# must be staged, committed, and verified on origin/main as one publication.
grep -q '^PUBLICATION_INDEXES=(' "$ARTICLE"
grep -q '"${PUBLICATION_INDEXES\[@\]}"' "$ARTICLE"
grep -q 'remote_publication_complete' "$ARTICLE"
grep -q 'git rebase origin/main' "$ARTICLE"
grep -q 'git rebase origin/main' "$AI_NEWS"
grep -q 'daily_publication_indexes "$TODAY"' "$ARTICLE"
grep -q 'daily_publication_indexes "$TODAY"' "$AI_NEWS"
grep -q 'remote_news_publication_complete' "$AI_NEWS"

python3 - "$AI_NEWS" <<'PY'
import pathlib, sys

text = pathlib.Path(sys.argv[1]).read_text()
recovery = text.index("# 2. 幂等恢复")
initial_sync = text.index('sync_main_checkout || { log "FATAL: 启动时')
if recovery > initial_sync:
    raise SystemExit("daily-ai-news recovery still runs after clean-tree sync")
PY

# Two launch sources can invoke daily-digest in the same minute. Its lock must
# be an atomic mkdir lock and must be acquired before infrastructure preflight.
grep -q 'daily_lock_acquire "$LOCK_DIR"' "$DIGEST"
grep -q -- '--idempotency-key "$FEISHU_IDEMPOTENCY_KEY"' "$DIGEST"
grep -q -- '--start "$TODAY" --end "$NEXT_DAY"' "$DIGEST"
grep -q 'git rev-parse HEAD.*git rev-parse origin/main' "$DIGEST"
grep -q '_complete=1' "$DIGEST"
python3 - "$DIGEST" <<'PY'
import pathlib, sys

text = pathlib.Path(sys.argv[1]).read_text()
lock = text.index('daily_lock_acquire "$LOCK_DIR"')
preflight = text.index('daily_infra_preflight "daily-digest"')
if lock > preflight:
    raise SystemExit("daily-digest lock is acquired too late")
PY

python3 - "$ARTICLE" "$AI_NEWS" <<'PY'
import pathlib, sys

for name in sys.argv[1:]:
    text = pathlib.Path(name).read_text()
    start = text.index("发布单元不完整")
    end = text.index("git commit -q --only", start)
    segment = text[start:end]
    audit = segment.index("release_audit_ok")
    refresh = segment.index("refresh_")
    stage = segment.index("git add")
    if not audit < refresh < stage:
        raise SystemExit(f"{name}: recovery mutates indexes before audit passes")
PY

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

seen = {}
for name in sys.argv[1:]:
    with open(name, "rb") as source:
        data = plistlib.load(source)
    slots = data.get("StartCalendarInterval") or []
    if not isinstance(slots, list) or not slots:
        raise SystemExit(f"{name}: missing StartCalendarInterval list")
    minutes = sorted({int(slot["Minute"]) for slot in slots})
    if len(minutes) != 2 or (minutes[1] - minutes[0]) % 60 != 30:
        raise SystemExit(f"{name}: retry minutes are not 30 minutes apart: {minutes}")
    for slot in slots:
        key = (int(slot["Hour"]), int(slot["Minute"]))
        if key in seen:
            raise SystemExit(f"schedule collision at {key}: {seen[key]} and {name}")
        seen[key] = name

with open(sys.argv[1], "rb") as source:
    article = plistlib.load(source)
article_slots = article["StartCalendarInterval"]
if min(int(slot["Hour"]) * 60 + int(slot["Minute"]) for slot in article_slots) > 10 * 60 + 35:
    raise SystemExit("daily-article has no pre-noon generation window")

with open(sys.argv[2], "rb") as source:
    news = plistlib.load(source)
news_slots = news["StartCalendarInterval"]
if min(int(slot["Hour"]) * 60 + int(slot["Minute"]) for slot in news_slots) > 10 * 60 + 40:
    raise SystemExit("daily-ai-news starts too late for a 12:00 retry budget")

with open(sys.argv[3], "rb") as source:
    digest = plistlib.load(source)
digest_slots = digest["StartCalendarInterval"]
if not any(int(slot["Hour"]) == 12 and int(slot["Minute"]) == 0 for slot in digest_slots):
    raise SystemExit("daily-digest is missing the 12:00 delivery window")
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

# A freshly created lock with no owner is busy, not stale. Only the recorded
# owner may release it.
LOCK_PROBE="$(mktemp -d "${TMPDIR:-/tmp}/daily-lock-probe.XXXXXX")"
rmdir "$LOCK_PROBE"
LOCK_PROBE="$LOCK_PROBE" bash -c '
  set -euo pipefail
  log() { :; }
  source "$1"
  daily_lock_acquire "$LOCK_PROBE" 1200
  owner="$DAILY_LOCK_OWNER"
  if DAILY_LOCK_OWNER=other daily_lock_release "$LOCK_PROBE" other; then
    exit 1
  fi
  [ -d "$LOCK_PROBE" ]
  daily_lock_release "$LOCK_PROBE" "$owner"
  [ ! -e "$LOCK_PROBE" ]
  mkdir "$LOCK_PROBE"
  if daily_lock_acquire "$LOCK_PROBE" 1200; then
    exit 1
  fi
  rmdir "$LOCK_PROBE"
  mkdir "$LOCK_PROBE"
  printf "%s|reused-process|0|test\n" "$$" > "$LOCK_PROBE/owner"
  touch -t 200001010000 "$LOCK_PROBE"
  daily_lock_acquire "$LOCK_PROBE" 1
  reused_owner="$DAILY_LOCK_OWNER"
  daily_lock_release "$LOCK_PROBE" "$reused_owner"
  [ ! -e "$LOCK_PROBE" ]
' _ "$COMMON"

# Pair publication must roll back the first destination if the second move
# fails, so a retry never sees a one-sided dirty checkout.
PAIR_PROBE="$(mktemp -d "${TMPDIR:-/tmp}/daily-pair-probe.XXXXXX")"
PAIR_PROBE="$PAIR_PROBE" bash -c '
  set -euo pipefail
  log() { :; }
  source "$1"
  printf left > "$PAIR_PROBE/left.src"
  printf right > "$PAIR_PROBE/right.src"
  if DAILY_COPY_PAIR_FAIL_AFTER_FIRST=1 daily_copy_pair_atomic \
       "$PAIR_PROBE/left.src" "$PAIR_PROBE/left.dst" \
       "$PAIR_PROBE/right.src" "$PAIR_PROBE/right.dst"; then
    exit 1
  fi
  [ ! -e "$PAIR_PROBE/left.dst" ]
  [ ! -e "$PAIR_PROBE/right.dst" ]
  daily_copy_pair_atomic \
    "$PAIR_PROBE/left.src" "$PAIR_PROBE/left.dst" \
    "$PAIR_PROBE/right.src" "$PAIR_PROBE/right.dst"
  cmp "$PAIR_PROBE/left.src" "$PAIR_PROBE/left.dst"
  cmp "$PAIR_PROBE/right.src" "$PAIR_PROBE/right.dst"
' _ "$COMMON"
find "$PAIR_PROBE" -depth -delete

TEST_LOCK="${TMPDIR:-/tmp}/daily-article-policy-probe.$$"
probe_output="$(DAILY_SESSION_LOCK="$TEST_LOCK" DAILY_POLICY_PROBE=1 bash "$ARTICLE")"
grep -q 'article policy ok' <<<"$probe_output"
[ ! -d "$TEST_LOCK" ]

TEST_LOCK="${TMPDIR:-/tmp}/daily-ai-news-policy-probe.$$"
probe_output="$(DAILY_SESSION_LOCK="$TEST_LOCK" DAILY_POLICY_PROBE=1 bash "$AI_NEWS")"
grep -q 'ai-news policy ok' <<<"$probe_output"
[ ! -d "$TEST_LOCK" ]

echo "daily-article reliability smoke tests passed"
