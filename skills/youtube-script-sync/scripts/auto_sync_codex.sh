#!/bin/bash
# GetNote Youtube视频逐字稿：轻量轮询，只有发现新源笔记才启动 Codex。
set -euo pipefail

export TZ="Asia/Shanghai"

CODEX_BIN="/Users/tonysheng/.nvm/versions/node/v24.14.0/bin/codex"
GETNOTE_BIN="/Users/tonysheng/.nvm/versions/node/v24.14.0/bin/getnote"
GETNOTE_ENV="/Users/tonysheng/.config/getnote/.env"
SKILL_DIR="/Users/tonysheng/.agents/skills/youtube-script-sync"
TOPIC_ID="YkWaVRqY"
TOPIC_NAME="Youtube视频逐字稿"
LOG_DIR="/Users/tonysheng/Library/Logs/yt-script-sync"
REPORT_DIR="/Volumes/2T/03-ai-memory-system/command-center/reports/yt-script-sync"
STATE_DIR="$SKILL_DIR/scripts/.state"
STATE_FILE="$STATE_DIR/processed-source-ids.txt"
LOCK_DIR="$STATE_DIR/run.lock"
FAIL_COUNT_FILE="$STATE_DIR/fails.count"
TIMEOUT_SECS=1200
BATCH_LIMIT=3
MODE="${1:---scheduled}"

usage() {
  echo "Usage: $0 [--dry-run|--init-baseline|--scheduled|--self-test|--help]"
  echo "  --dry-run       只列出尚未处理的源笔记，不启动 Codex，不改状态"
  echo "  --init-baseline 将当前源笔记记为基线，不生成或修改 GetNote 笔记"
  echo "  --scheduled     发现新源笔记后调用 Codex，成功核验后写入本地状态"
  echo "  --self-test     用 5 条内置样本测试源笔记过滤与去重"
}

extract_source_ids() {
  /usr/bin/jq -r '
    (.data.notes // .notes // [])[]
    | . as $note
    | (($note.title // "") | tostring) as $title
    | (($note.tags // []) | map(if type == "object" then (.name // "") else tostring end)) as $tags
    | select(($note.is_child_note // false) == false)
    | select(($title | contains("YT逐字稿·源")) | not)
    | select(($tags | index("YT逐字稿")) == null)
    | (($note.note_id // $note.id // "") | tostring)
    | select(test("^[0-9]+$") and . != "0")
  ' | /usr/bin/sort -u
}

self_test() {
  local actual expected
  actual="$({
    printf '%s\n' '{"data":{"notes":['
    printf '%s\n' '{"note_id":101,"title":"新想法","tags":[]},'
    printf '%s\n' '{"note_id":102,"title":"第二条源笔记","tags":["录音转写"]},'
    printf '%s\n' '{"note_id":201,"title":"YT逐字稿·源101｜版本","tags":["YT逐字稿"]},'
    printf '%s\n' '{"note_id":202,"title":"普通标题","tags":[{"name":"YT逐字稿"}]},'
    printf '%s\n' '{"note_id":203,"title":"子笔记","is_child_note":true,"tags":[]}'
    printf '%s\n' ']}}'
  } | extract_source_ids)"
  expected=$'101\n102'
  if [ "$actual" != "$expected" ]; then
    echo "SELF_TEST_FAIL expected=101,102 actual=$(printf '%s' "$actual" | tr '\n' ',')" >&2
    return 1
  fi
  echo "SELF_TEST_OK samples=5 sources=2 generated_or_child=3"
}

case "$MODE" in
  --help|-h) usage; exit 0 ;;
  --self-test) self_test; exit $? ;;
  --dry-run|--init-baseline|--scheduled) ;;
  *) usage >&2; exit 2 ;;
esac

for required_bin in "$CODEX_BIN" "$GETNOTE_BIN" /usr/bin/jq; do
  if [ ! -x "$required_bin" ]; then
    echo "ERROR: required executable missing: $required_bin" >&2
    exit 1
  fi
done
if [ ! -r "$GETNOTE_ENV" ]; then
  echo "ERROR: GetNote credential file is missing or unreadable" >&2
  exit 1
fi

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$STATE_DIR"

# 单写入者。仅在锁记录的进程已不存在时回收精确锁目录。
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  lock_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
    echo "SKIP_ACTIVE_RUN pid=$lock_pid"
    exit 0
  fi
  rm -f "$LOCK_DIR/pid" 2>/dev/null || true
  rmdir "$LOCK_DIR" 2>/dev/null || true
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "SKIP_LOCK_RACE"
    exit 0
  fi
fi
printf '%s\n' "$$" > "$LOCK_DIR/pid"
cleanup() {
  rm -f "$LOCK_DIR/pid" 2>/dev/null || true
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 授权仅进入本进程环境，不打印、不持久化。
set -a
# shellcheck disable=SC1090
source "$GETNOTE_ENV"
set +a

topics_json="$("$GETNOTE_BIN" kbs -o json)"
topic_matches="$(printf '%s' "$topics_json" | /usr/bin/jq --arg name "$TOPIC_NAME" '[.data.topics[]? | select(.name == $name)] | length')"
resolved_topic_id="$(printf '%s' "$topics_json" | /usr/bin/jq -r --arg name "$TOPIC_NAME" '.data.topics[]? | select(.name == $name) | (.topic_id // .id)' | head -1)"
if [ "$topic_matches" != "1" ] || [ "$resolved_topic_id" != "$TOPIC_ID" ]; then
  echo "ERROR: topic mismatch name=$TOPIC_NAME expected_id=$TOPIC_ID matches=$topic_matches resolved_id=${resolved_topic_id:-none}" >&2
  exit 1
fi

notes_json="$("$GETNOTE_BIN" kb "$TOPIC_ID" --all -o json)"
current_ids="$(printf '%s' "$notes_json" | extract_source_ids)"

write_state() {
  local ids="$1" temp_state
  temp_state="$(mktemp "$STATE_DIR/processed.XXXXXX")"
  printf '%s\n' "$ids" | /usr/bin/sed '/^$/d' | /usr/bin/sort -u > "$temp_state"
  chmod 600 "$temp_state"
  mv "$temp_state" "$STATE_FILE"
}

if [ "$MODE" = "--init-baseline" ]; then
  write_state "$current_ids"
  echo "BASELINE_INITIALIZED sources=$(printf '%s\n' "$current_ids" | sed '/^$/d' | wc -l | tr -d ' ') state=$STATE_FILE"
  exit 0
fi

if [ ! -s "$STATE_FILE" ]; then
  if [ "$MODE" = "--dry-run" ]; then
    echo "DRY_RUN state=missing baseline_sources=$(printf '%s\n' "$current_ids" | sed '/^$/d' | wc -l | tr -d ' ')"
    printf '%s\n' "$current_ids"
    exit 0
  fi
  echo "ERROR: checkpoint missing; run --dry-run, then --init-baseline after verifying current sources" >&2
  exit 1
fi

seen_ids="$(sed '/^$/d' "$STATE_FILE" | sort -u)"
new_ids="$(comm -23 <(printf '%s\n' "$current_ids" | sed '/^$/d' | sort -u) <(printf '%s\n' "$seen_ids" | sed '/^$/d' | sort -u))"

if [ -z "$new_ids" ]; then
  echo "NO_NEW_NOTES"
  exit 0
fi

if [ "$MODE" = "--dry-run" ]; then
  echo "DRY_RUN new_sources=$(printf '%s\n' "$new_ids" | wc -l | tr -d ' ')"
  printf '%s\n' "$new_ids"
  exit 0
fi

batch_ids="$(printf '%s\n' "$new_ids" | head -n "$BATCH_LIMIT")"
batch_csv="$(printf '%s\n' "$batch_ids" | paste -sd, -)"
quota_json="$("$GETNOTE_BIN" quota -o json)"
write_remaining="$(printf '%s' "$quota_json" | /usr/bin/jq -r '.data.write_note.daily.remaining // 0')"
if ! [[ "$write_remaining" =~ ^[0-9]+$ ]] || [ "$write_remaining" -lt 1 ]; then
  echo "ERROR: insufficient GetNote write_note quota remaining=${write_remaining:-unknown}" >&2
  exit 1
fi

run_ts="$(date +%Y%m%d-%H%M%S)"
run_log="$LOG_DIR/run-$run_ts.log"
report_path="$REPORT_DIR/$run_ts.md"
prompt="$(cat <<EOF
执行 $SKILL_DIR/SKILL.md 的完整流程，同步 GetNote 知识库 $TOPIC_NAME（topic_id=$TOPIC_ID），模式=更新。本次严格只处理 source_note_ids=$batch_csv。生成前读取 editorial-system.md 和 tony-voice-profile.md。

这是无人值守增量任务：
1. 先 dry-run；只为没有任何 YT逐字稿 子笔记的合格源笔记创建一个 plain_text 子笔记，parent_id 必须等于源笔记 ID。
2. 不更新、不删除、不覆盖任何已有笔记。若目标源笔记已经有生成子笔记，记为 unchanged，不再创建。
3. 历史父笔记可能保留两个已获准版本，不处理、不删除；本批新源笔记仍须一源一稿。
4. 写前运行 validate_transcript.py，errors 必须为 0；写后回读子笔记、父子链接、元数据，并再次 dry-run 证明本批幂等。
5. 禁止读取或回显任何凭据文件、密钥、个人路径清单；除 GetNote 新建子笔记外不做外部写入。
6. 最后一行必须严格输出：SUMMARY: status=ok processed=$batch_csv created=N unchanged=M skipped=K blocked=0 missing=0 duplicates=0
若无法满足，最后一行输出同格式但 status=blocked，并给出实际 blocked/missing/duplicates 数量；不要伪报成功。
EOF
)"

set +e
"$CODEX_BIN" exec \
  --ephemeral \
  --approve-for-me \
  --skip-git-repo-check \
  -C "$SKILL_DIR" \
  -c 'model_reasoning_effort="medium"' \
  "$prompt" </dev/null > "$run_log" 2>&1 &
codex_pid=$!
( sleep "$TIMEOUT_SECS"; kill -TERM "$codex_pid" 2>/dev/null; sleep 10; kill -KILL "$codex_pid" 2>/dev/null ) &
watchdog_pid=$!
wait "$codex_pid"
codex_rc=$?
kill "$watchdog_pid" 2>/dev/null || true
wait "$watchdog_pid" 2>/dev/null || true
set -e

summary="$(grep -Eo 'SUMMARY: status=(ok|blocked) processed=[0-9,]+ created=[0-9]+ unchanged=[0-9]+ skipped=[0-9]+ blocked=[0-9]+ missing=[0-9]+ duplicates=[0-9]+' "$run_log" | tail -1 || true)"
expected_summary_prefix="SUMMARY: status=ok processed=$batch_csv"

if [ "$codex_rc" -eq 0 ] && [[ "$summary" == "$expected_summary_prefix"* ]] && [[ "$summary" == *" blocked=0 missing=0 duplicates=0" ]]; then
  write_state "$(printf '%s\n%s\n' "$seen_ids" "$batch_ids")"
  rm -f "$FAIL_COUNT_FILE"
  {
    echo "# YT Script Sync $run_ts"
    echo
    echo "- Result: success"
    echo "- Source IDs: $batch_csv"
    echo "- $summary"
    echo "- Log: $run_log"
  } > "$report_path"
  echo "$summary"
else
  fail_count=$(( $(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0) + 1 ))
  printf '%s\n' "$fail_count" > "$FAIL_COUNT_FILE"
  {
    echo "# YT Script Sync $run_ts"
    echo
    echo "- Result: failed"
    echo "- Exit code: $codex_rc"
    echo "- Source IDs: $batch_csv"
    echo "- Summary: ${summary:-missing}"
    echo "- Consecutive failures: $fail_count"
    echo "- Log: $run_log"
  } > "$report_path"
  echo "SYNC_FAILED rc=$codex_rc failures=$fail_count report=$report_path" >&2
  # 23:00-08:00 静默，只留报告；白天连续失败 3 次才通知。
  current_hour="$(date +%H)"
  current_hour=$((10#$current_hour))
  if [ "$fail_count" -ge 3 ] && [ "$current_hour" -ge 8 ] && [ "$current_hour" -lt 23 ]; then
    osascript -e "display notification \"连续失败 $fail_count 次，见 $report_path\" with title \"YT逐字稿自动同步异常\"" 2>/dev/null || true
    printf '0\n' > "$FAIL_COUNT_FILE"
  fi
fi

# 运行明细最多保留 30 份；汇总报告长期保留。
ls -1t "$LOG_DIR"/run-*.log 2>/dev/null | tail -n +31 | while IFS= read -r old_log; do rm -f "$old_log"; done

# launchd 周期任务总是正常返回，失败由连续计数、报告和下轮重试处理。
exit 0
