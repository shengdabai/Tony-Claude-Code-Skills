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
HERMES_PYTHON="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$HOME/Library/LaunchAgents/ai.hermes.gateway.plist")"

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
grep -Fq '"$HERMES_GATEWAY_PY" "$HERMES_SEND_WRAPPER" send' "$DIGEST"
grep -Fq -- '--file "$MSGFILE" --json' "$DIGEST"
grep -q 'env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY' "$DIGEST"
grep -q 'FEISHU_PROFILE="cli_aa80e81017f85bc0"' "$DIGEST"
grep -q '存在未确认的飞书发送尝试' "$DIGEST"
grep -q 'daily_run_with_timeout 120 env' "$DIGEST"
grep -q 'daily-digest-delivery:' "$DIGEST"
grep -q 'MSG_CHARS.*7000' "$DIGEST"
grep -q '_total.*-eq 1' "$DIGEST"
"$HERMES_PYTHON" -m py_compile "$HOME/.claude/scripts/hermes-send-direct-feishu.py"
if grep -q -- '--as user.*messages-send' "$DIGEST"; then
  echo "daily-digest must send as Commander bot" >&2
  exit 1
fi

"$HERMES_PYTHON" - "$HOME/.hermes/config.yaml" <<'PY'
import sys
import yaml
with open(sys.argv[1], encoding="utf-8") as source:
    config = yaml.safe_load(source) or {}
assert config.get("model") == {"default": "gpt-5.6-sol", "provider": "openai-codex"}
assert "fallback_providers" in config and config["fallback_providers"] == []
assert (config.get("agent") or {}).get("reasoning_effort") == "high"
assert (((config.get("platforms") or {}).get("feishu") or {}).get("extra") or {}).get("require_mention") is True
title = ((config.get("auxiliary") or {}).get("title_generation") or {})
assert title.get("provider") == "openai-codex" and title.get("model") == "gpt-5.6-sol"
PY
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
if [ "$(grep -c '^CODEX_MODEL=' "$ARTICLE")" -ne 1 ] ||
   [ "$(grep -c '^CODEX_MODEL=' "$AI_NEWS")" -ne 1 ] ||
   grep -qE 'gpt-5\.6-(terra|luna)' "$ARTICLE" "$AI_NEWS"; then
  echo "daily generation contains a non-Sol or duplicate model selector" >&2
  exit 1
fi

if grep -qE '"\$CODEX".*exec[[:space:]]+resume|exec[[:space:]]+resume[[:space:]]+--last' "$ARTICLE" "$AI_NEWS"; then
  echo "unsafe Codex resume path is still executable in daily generation" >&2
  exit 1
fi

grep -q 'DAILY_ARTICLE_GENERATION_TIMEOUT.*900' "$ARTICLE"
grep -q 'DAILY_ARTICLE_AUDIT_TIMEOUT.*900' "$ARTICLE"
grep -q 'DAILY_AI_NEWS_GENERATION_TIMEOUT.*600' "$AI_NEWS"
grep -q 'DAILY_AI_NEWS_AUDIT_TIMEOUT.*900' "$AI_NEWS"
grep -q -- '--max-cost 3\.0 --model gpt-5\.6-sol' "$ARTICLE"
grep -q -- '--max-cost 3\.0 --model gpt-5\.6-sol' "$AI_NEWS"
grep -Fq 'if [ "$RC" -eq 124 ]; then' "$ARTICLE"
grep -Fq 'if [ "$RC" -eq 124 ]; then' "$AI_NEWS"
grep -q 'CLAUDE_SESSION_LOCK="${DAILY_SESSION_LOCK:-/tmp/daily-ai-news-generation.lock}"' "$AI_NEWS"
grep -q 'timeout/gtimeout 不可用，拒绝无界执行' "$AI_NEWS"
grep -q 'git commit -q --only' "$AI_NEWS"
grep -q 'daily_notify_failure_once "daily-article"' "$ARTICLE"
grep -q '\[ -f "$DONE_MARK" \].*exit 1' "$ARTICLE"
grep -q 'daily_run_with_timeout 30 env' "$COMMON"

python3 - "$ARTICLE_PLIST" "$AI_NEWS_PLIST" "$DIGEST_PLIST" <<'PY'
import plistlib, sys

seen = {}
expected = {
    "com.tony.daily-article": [(12, 0), (13, 0), (14, 0), (15, 0)],
    "com.tony.daily-ai-news": [(12, 0), (13, 0), (14, 0), (15, 0)],
    "com.tony.daily-digest": [(m // 60, m % 60) for m in range(725, 991, 5)],
}
for name in sys.argv[1:]:
    with open(name, "rb") as source:
        data = plistlib.load(source)
    slots = data.get("StartCalendarInterval") or []
    if not isinstance(slots, list) or not slots:
        raise SystemExit(f"{name}: missing StartCalendarInterval list")
    label = data.get("Label")
    actual = [(int(slot["Hour"]), int(slot["Minute"])) for slot in slots]
    if actual != expected.get(label):
        raise SystemExit(f"{label}: unexpected schedule {actual}")
    for slot in slots:
        key = (int(slot["Hour"]), int(slot["Minute"]))
        # Both generation jobs intentionally start at noon; per-job locks allow it.
        seen[key] = name
PY

DAILY_NOW_HHMM=1159 bash -c '
  log() { :; }
  source "$1"
  ! daily_require_shanghai_noon
' _ "$COMMON"
DAILY_NOW_HHMM=1200 bash -c '
  log() { :; }
  source "$1"
  daily_require_shanghai_noon
' _ "$COMMON"

LINK_PROBE="$(mktemp -d "${TMPDIR:-/tmp}/daily-link-probe.XXXXXX")"
printf '# English\n\n[Chinese](../zh/%%E4%%B8%%AD%%20%%E6%%96%%87.md) [English](../en/english.md)\n' > "$LINK_PROBE/english.md"
printf '# 中文\n\n[Chinese](../zh/%%E4%%B8%%AD%%20%%E6%%96%%87.md) [English](../en/english.md)\n' > "$LINK_PROBE/中 文.md"
LINK_PROBE="$LINK_PROBE" bash -c '
  log() { :; }
  source "$1"
  daily_bilingual_links_match "$LINK_PROBE/english.md" "$LINK_PROBE/中 文.md"
' _ "$COMMON"
find "$LINK_PROBE" -depth -delete

python3 - "$ARTICLE" "$AI_NEWS" <<'PY'
import pathlib, sys
for name in sys.argv[1:]:
    text = pathlib.Path(name).read_text()
    guard = text.index("daily_require_shanghai_noon")
    lock = text.index("daily_lock_acquire")
    if guard > lock:
        raise SystemExit(f"{name}: noon guard runs after lock acquisition")
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

python3 - "$COMMON" <<'PYTEST'
import os, subprocess, sys, tempfile, time
from pathlib import Path
common=sys.argv[1]
with tempfile.TemporaryDirectory(prefix="daily-parallel-test-") as tmp:
    root=Path(tmp)
    worker=r'''set -euo pipefail
source "$1"
log() { :; }
DAILY_PUBLICATION_LOCK="$2/checkout.lock"
daily_lock_acquire "$2/$3.generation.lock" 1200
generation_owner="$DAILY_LOCK_OWNER"
trap 'daily_checkout_release; daily_lock_release "$2/$3.generation.lock" "$generation_owner"' EXIT
touch "$2/$3.ready"
for i in {1..100}; do
  [ -f "$2/article.ready" ] && [ -f "$2/news.ready" ] && break
  sleep 0.05
done
[ -f "$2/article.ready" ] && [ -f "$2/news.ready" ]
daily_checkout_acquire
mkdir "$2/writing"
sleep 0.15
rmdir "$2/writing"
daily_checkout_release
touch "$2/$3.done"
'''
    procs=[subprocess.Popen(['bash','-c',worker,'_',common,tmp,name]) for name in ['article','news']]
    assert all(p.wait(timeout=15)==0 for p in procs), 'parallel generation or serialized publishing failed'
    assert all((root/(name+'.done')).exists() for name in ['article','news'])
    assert not (root/'checkout.lock').exists(), 'publication lock leaked'
    # A busy shared checkout times out instead of proceeding unlocked.
    (root/'checkout.lock').mkdir()
    probe='source "$1"; log() { :; }; DAILY_PUBLICATION_LOCK="$2/checkout.lock"; DAILY_CHECKOUT_WAIT_SECONDS=0; ! daily_checkout_acquire'
    assert subprocess.run(['bash','-c',probe,'_',common,tmp]).returncode==0
print('parallel generation / serialized checkout / lock timeout tests passed')
PYTEST

echo "daily-article reliability smoke tests passed"
