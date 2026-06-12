#!/bin/zsh
# Gumroad 自动续建：确保调试 Chrome 在跑 → 检查是否全部完成 → 跑 batch 续建剩余
# 由 launchd com.tony.gumroad-resume 每 2 小时触发；全部建成后自动 unload。
NODE="$HOME/.nvm/versions/node/v24.14.0/bin/node"
[ -x "$NODE" ] || NODE="$(command -v node)"
DATA="$HOME/.claude/scripts/gumroad-data"
LOG="$DATA/auto-resume.log"
PLIST="$HOME/Library/LaunchAgents/com.tony.gumroad-resume.plist"

echo "=== $(date) ===" >> "$LOG"

# 1. 调试 Chrome 9222 在否，不在则启动
if ! "$NODE" -e 'fetch("http://127.0.0.1:9222/json/version").then(()=>process.exit(0)).catch(()=>process.exit(1))' 2>/dev/null; then
  echo "Chrome 9222 down → launching" >> "$LOG"
  open -na "Google Chrome" --args --remote-debugging-port=9222 --user-data-dir="$HOME/.cdp-chrome-profile" --remote-allow-origins=* --no-first-run --no-default-browser-check 2>/dev/null
  sleep 10
fi

# 2. 全部完成则自停
DONE=$("$NODE" -e "const p=require('$DATA/gumroad-progress.json');console.log(Object.values(p).filter(v=>v.permalink).length)" 2>/dev/null)
TOTAL=$("$NODE" -e "console.log(require('$DATA/books.json').length)" 2>/dev/null)
echo "progress $DONE/$TOTAL" >> "$LOG"
if [ -n "$DONE" ] && [ -n "$TOTAL" ] && [ "$DONE" -ge "$TOTAL" ]; then
  echo "ALL $TOTAL DONE → unloading launchd" >> "$LOG"
  launchctl unload "$PLIST" 2>/dev/null
  exit 0
fi

# 3. 跑 batch 续建（自动跳过已建）
GUMROAD_DATA="$DATA" "$NODE" "$HOME/.claude/scripts/gumroad-batch.mjs" >> "$LOG" 2>&1
NOW=$("$NODE" -e "const p=require('$DATA/gumroad-progress.json');console.log(Object.values(p).filter(v=>v.permalink).length)" 2>/dev/null)
echo "after run: $NOW/$TOTAL" >> "$LOG"
