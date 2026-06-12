#!/usr/bin/env bash
# 通用网页/公众号抓取共享技术栈。Firecrawl 主力（自带 stealth + markdown），
# 失败自动 fallback Jina Reader（境外代抓，走 Clash 7897）。
# 用法: webfetch.sh <URL> [out.md]
#   微信公众号、反爬站、普通网页统一入口。被多个 skill 复用，避免重复拼 curl。
set -euo pipefail

URL="${1:?usage: webfetch.sh <URL> [out.md]}"
OUT="${2:-}"

emit() {  # $1=markdown
  if [ -n "$OUT" ]; then
    printf '%s' "$1" > "$OUT"
    echo "written: $OUT ($(printf '%s' "$1" | wc -l | tr -d ' ') lines)" >&2
  else
    printf '%s' "$1"
  fi
}

# --- 1) Firecrawl ---
set -a; source ~/.config/firecrawl/.env 2>/dev/null || true; set +a
KEY="${FIRECRAWL_API_KEY:-${FIRECRAWL_KEY:-}}"
if [ -n "$KEY" ]; then
  resp=$(curl -s --max-time 60 -X POST https://api.firecrawl.dev/v1/scrape \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d "{\"url\":\"$URL\",\"formats\":[\"markdown\"],\"onlyMainContent\":true}" 2>/dev/null || true)
  md=$(printf '%s' "$resp" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if d.get('success') and d.get('data', {}).get('markdown'):
        print(d['data']['markdown'])
except Exception:
    pass
" 2>/dev/null || true)
  if [ -n "$md" ]; then emit "$md"; exit 0; fi
  echo "WARN: firecrawl 空/失败，fallback jina" >&2
fi

# --- 2) Jina Reader fallback（境外代抓，需 Clash 7897）---
jina=$(curl -s --max-time 60 -x 127.0.0.1:7897 "https://r.jina.ai/$URL" 2>/dev/null || true)
if [ -n "$jina" ]; then emit "$jina"; exit 0; fi

echo "ERR: firecrawl + jina 均失败，URL=$URL" >&2
exit 1
