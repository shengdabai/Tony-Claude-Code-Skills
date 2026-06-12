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

echo "===== $(date '+%Y-%m-%d %H:%M:%S') mode=$MODE =====" >> "$LOG"
/usr/local/bin/python3 "$DIR/mail_agent.py" --mode "$MODE" >> "$LOG" 2>&1
RC=$?
echo "----- exit $RC -----" >> "$LOG"

# 日志超过 2000 行则截断,保留最后 1000 行
if [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 2000 ]; then
  tail -n 1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
exit $RC
