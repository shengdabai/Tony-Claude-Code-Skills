#!/bin/bash
# launchd 入口。launchd 环境 PATH 极简,这里显式补全(含 python3 / ollama)。
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$HOME/.local/ollama-dist"
# 不让代理拦截本地 Ollama
export no_proxy="localhost,127.0.0.1"
export NO_PROXY="localhost,127.0.0.1"

DIR="$HOME/.claude/scripts/mail-system"
cd "$DIR" || exit 1

MODE="${1:-sweep}"
LOG="$DIR/run.log"

# The hourly sweep and daily digest used to race at exactly 08:00. The digest
# already includes a sweep, so the hourly job deliberately yields that slot.
CURRENT_HOUR="${MAIL_SYSTEM_NOW_HOUR:-$(date '+%H')}"
if [ "$MODE" = "sweep" ] && [ "$CURRENT_HOUR" = "08" ]; then
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') mode=sweep skipped(digest owns 08:00) =====" >> "$LOG"
  exit 0
fi

echo "===== $(date '+%Y-%m-%d %H:%M:%S') mode=$MODE =====" >> "$LOG"
LOCK_WAIT=0
[ "$MODE" = "digest" ] && LOCK_WAIT=600
/usr/bin/lockf -t "$LOCK_WAIT" "$DIR/.run.lock" \
  /usr/local/bin/python3 "$DIR/mail_agent.py" --mode "$MODE" >> "$LOG" 2>&1
RC=$?
if [ "$RC" -eq 75 ]; then
  echo "----- skipped: another mail job holds the lock -----" >> "$LOG"
  [ "$MODE" = "sweep" ] && exit 0
  exit 75
fi
echo "----- exit $RC -----" >> "$LOG"

# 日志超过 2000 行则截断,保留最后 1000 行
if [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 2000 ]; then
  tail -n 1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
exit $RC
