#!/bin/bash
# 渲染 Tony-Articles 国内静态站 + rsync 到上海腾讯云。
# 用法: sync-site.sh   (无参,渲染全站并同步)
set -uo pipefail

OUT="$HOME/.local/share/tony-articles-site/dist"
REMOTE_HOST="shanghai"
REMOTE_DIR="/var/www/tony-articles"
RENDER="$HOME/.claude/scripts/render-site.py"

# 1. 渲染
python3 "$RENDER" build || { echo "render 失败" >&2; exit 1; }

# 2. 安全闸:dist 必须有 index.html 且 >= 3 个 html,否则不 rsync(防空目录用 --delete 清空线上)
HTML_N=$(ls "$OUT"/*.html 2>/dev/null | wc -l | tr -d ' ')
if [ ! -f "$OUT/index.html" ] || [ "$HTML_N" -lt 3 ]; then
  echo "dist 异常(index=$([ -f "$OUT/index.html" ] && echo yes || echo no) html数=$HTML_N),中止同步" >&2
  exit 1
fi

# 3. rsync(站点目录专用,--delete 保持与本地一致)
rsync -az --delete --timeout=30 \
  -e "ssh -o ConnectTimeout=15 -o BatchMode=yes" \
  "$OUT/" "${REMOTE_HOST}:${REMOTE_DIR}/" || { echo "rsync 失败" >&2; exit 1; }

echo "同步成功: $HTML_N 个页面 -> ${REMOTE_HOST}:${REMOTE_DIR}"
