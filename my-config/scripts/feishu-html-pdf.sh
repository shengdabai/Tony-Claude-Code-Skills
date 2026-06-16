#!/bin/bash
# feishu-html-pdf.sh — HTML → 本地 PDF/图片 → 以指定飞书 bot 身份发回聊天
#
# 用法: feishu-html-pdf.sh <html路径> [chat_id] [app_id] [extra-css路径]
#   chat_id 省略 = 只转换不发送
#   app_id  省略 = Claude bot (cli_aa9a8b56bbfbdcc7)
#     Claude bot: cli_aa9a8b56bbfbdcc7   Codex bot:    cli_aa9ae2200e795cb3
#     agy bot:    cli_aa9b9e38c1f8dbd3   DeepSeek bot: cli_aa9b9ee68d38dbe9
#   FEISHU_PDF_MODE=safe    默认。扁平化 A4 图片页 *.feishu.pdf + 逐页图片，避免飞书预览闪退
#   FEISHU_PDF_MODE=onepage 只在明确需要时用单页长 PDF
#   FEISHU_SEND_FORMAT=longimage 默认。整页渲成一张竖长图一条消息发完，不碰 PDF 预览器；超长/超限自动回退逐页图片
#   FEISHU_SEND_FORMAT=images    逐页发送图片
#   FEISHU_SEND_FORMAT=pdf       只在明确需要时发送 PDF 文件
#
# 本机始终保留: <name>.pdf(单页归档) <name>.feishu.pdf(A4图片版) <name>.feishu-images/(逐页) <name>.feishu-long.jpg(长图)
# 依赖: onepage-pdf skill + pymupdf + Chrome + lark-channel keystore(取 app secret)
# 注意: 发送方 bot 必须是目标 chat 的成员;飞书 API 直连(--noproxy)
set -euo pipefail

HTML="$1"
CHAT="${2:-}"
APP="${3:-cli_aa9a8b56bbfbdcc7}"
CSS="${4:-}"

PY="/usr/local/bin/python3"
CONVERTER="$HOME/.claude/skills/onepage-pdf/scripts/onepage_pdf.py"
FEISHU_CONVERTER="$HOME/.claude/scripts/feishu-safe-pdf.py"
LONG_CONVERTER="$HOME/.claude/scripts/feishu-long-image.py"
KEYSTORE="$HOME/.lark-channel/secrets-getter"
PDF="${HTML%.html}.pdf"
SAFE_PDF="${HTML%.html}.feishu.pdf"
IMAGE_DIR="${HTML%.html}.feishu-images"
LONG_IMG="${HTML%.html}.feishu-long.jpg"
MODE="${FEISHU_PDF_MODE:-safe}"
SEND_FORMAT="${FEISHU_SEND_FORMAT:-longimage}"
HTMLW="${FEISHU_HTML_WIDTH:-1280}"   # 渲染画布宽度;设窄(如 720)= 手机竖版长图

args=("$HTML" -o "$PDF" --width "$HTMLW")
[ -n "$CSS" ] && args=("${args[@]}" --extra-css "$CSS")
"$PY" "$CONVERTER" "${args[@]}" >&2

SEND_PDF="$PDF"
if [ "$MODE" = "safe" ]; then
  safe_args=("$HTML" -o "$SAFE_PDF" --width "$HTMLW" --page-height 1800 --images-dir "$IMAGE_DIR")
  [ -n "$CSS" ] && safe_args=("${safe_args[@]}" --extra-css "$CSS")
  "$PY" "$FEISHU_CONVERTER" "${safe_args[@]}" >&2
  SEND_PDF="$SAFE_PDF"
elif [ "$MODE" != "onepage" ]; then
  echo "ERR: FEISHU_PDF_MODE must be safe or onepage (got: $MODE)" >&2
  exit 1
fi

if [ -z "$CHAT" ]; then
  if [ "$MODE" = "safe" ]; then
    echo "PDF $PDF"
    echo "FEISHU_PDF $SAFE_PDF"
    echo "FEISHU_IMAGES $IMAGE_DIR"
    [ -f "$LONG_IMG" ] && echo "FEISHU_LONG $LONG_IMG"
  else
    echo "PDF $PDF"
  fi
  exit 0
fi

SEC=$(echo "{\"ids\":[\"app-$APP\"]}" | "$KEYSTORE" | "$PY" -c "import sys,json;print(json.load(sys.stdin)['values']['app-$APP'])")
TOKEN_BODY=$(curl -sS --fail-with-body --retry 2 --retry-all-errors --connect-timeout 10 --max-time 30 --noproxy '*' \
  -X POST https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal \
  -H 'Content-Type: application/json' -d "{\"app_id\":\"$APP\",\"app_secret\":\"$SEC\"}" |
  "$PY" -c "import sys; print(sys.stdin.read())")
TOK=$(printf '%s' "$TOKEN_BODY" | "$PY" -c "import sys,json; raw=sys.stdin.read();
try: d=json.loads(raw)
except Exception as e: print('ERR: tenant token 响应不是 JSON', file=sys.stderr); sys.exit(1)
code=d.get('code')
if code!=0: print(f\"ERR: tenant token 获取失败: code={code} msg={d.get('msg')}\", file=sys.stderr); sys.exit(1)
tok=d.get('tenant_access_token') or ''
if not tok: print('ERR: tenant token 为空', file=sys.stderr); sys.exit(1)
print(tok)")

# 上传一张图片并作为图片消息发到 chat;参数: 图片路径
upload_and_send_image() {
  local img="$1" IMAGE_BODY IK SEND_BODY RES
  IMAGE_BODY=$(curl -sS --fail-with-body --retry 2 --retry-all-errors --connect-timeout 10 --max-time 60 --noproxy '*' \
    -X POST https://open.feishu.cn/open-apis/im/v1/images \
    -H "Authorization: Bearer $TOK" \
    -F image_type=message -F "image=@$img")
  IK=$(printf '%s' "$IMAGE_BODY" | "$PY" -c "import sys,json; raw=sys.stdin.read();
try: d=json.loads(raw)
except Exception: print('ERR: 图片上传响应不是 JSON', file=sys.stderr); sys.exit(1)
code=d.get('code')
if code!=0: print(f\"ERR: 图片上传失败: code={code} msg={d.get('msg')}\", file=sys.stderr); sys.exit(1)
ik=(d.get('data') or {}).get('image_key') or ''
if not ik: print('ERR: 图片上传未返回 image_key', file=sys.stderr); sys.exit(1)
print(ik)")
  SEND_BODY=$(curl -sS --fail-with-body --retry 2 --retry-all-errors --connect-timeout 10 --max-time 30 --noproxy '*' \
    -X POST 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id' \
    -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
    -d "{\"receive_id\":\"$CHAT\",\"msg_type\":\"image\",\"content\":\"{\\\"image_key\\\":\\\"$IK\\\"}\"}")
  RES=$(printf '%s' "$SEND_BODY" | "$PY" -c "import sys,json; raw=sys.stdin.read();
try: d=json.loads(raw)
except Exception: print('ERR: 图片发送响应不是 JSON', file=sys.stderr); sys.exit(1)
print(d.get('code'), d.get('msg'))")
  [ "$RES" = "0 success" ] || { echo "ERR: 图片发送失败: $RES" >&2; return 1; }
}

# 逐页发送 IMAGE_DIR 里的页面图片
send_page_images() {
  [ "$MODE" = "safe" ] || { echo "ERR: 逐页图片需 FEISHU_PDF_MODE=safe" >&2; return 1; }
  shopt -s nullglob
  local image_files=("$IMAGE_DIR"/page-*.jpg "$IMAGE_DIR"/page-*.png)
  shopt -u nullglob
  [ "${#image_files[@]}" -gt 0 ] || { echo "ERR: 没有可发送的页面图片: $IMAGE_DIR" >&2; return 1; }
  local sent=0 IMG
  for IMG in "${image_files[@]}"; do
    upload_and_send_image "$IMG" || return 1
    sent=$((sent + 1))
    sleep 0.2
  done
  echo "SENT_IMAGES $sent from $IMAGE_DIR -> $CHAT"
}

if [ "$SEND_FORMAT" = "longimage" ]; then
  LONG_OUT=""
  if "$PY" "$LONG_CONVERTER" "$PDF" -o "$LONG_IMG" >&2; then
    if [ -f "$LONG_IMG" ]; then LONG_OUT="$LONG_IMG"
    elif [ -f "${LONG_IMG%.jpg}.png" ]; then LONG_OUT="${LONG_IMG%.jpg}.png"; fi
  fi
  if [ -n "$LONG_OUT" ]; then
    upload_and_send_image "$LONG_OUT"
    echo "SENT_LONG_IMAGE $LONG_OUT -> $CHAT"
    exit 0
  fi
  echo "WARN: 长图不可用(超长或超 9.5MB),自动回退逐页图片" >&2
  send_page_images
  exit 0
elif [ "$SEND_FORMAT" = "images" ]; then
  send_page_images
  exit 0
elif [ "$SEND_FORMAT" != "pdf" ]; then
  echo "ERR: FEISHU_SEND_FORMAT must be longimage, images or pdf (got: $SEND_FORMAT)" >&2
  exit 1
fi

UPLOAD_BODY=$(curl -sS --fail-with-body --retry 2 --retry-all-errors --connect-timeout 10 --max-time 60 --noproxy '*' \
  -X POST https://open.feishu.cn/open-apis/im/v1/files \
  -H "Authorization: Bearer $TOK" \
  -F file_type=pdf -F "file_name=$(basename "$SEND_PDF")" -F "file=@$SEND_PDF")
FK=$(printf '%s' "$UPLOAD_BODY" | "$PY" -c "import sys,json; raw=sys.stdin.read();
try: d=json.loads(raw)
except Exception: print('ERR: 文件上传响应不是 JSON', file=sys.stderr); sys.exit(1)
code=d.get('code')
if code!=0: print(f\"ERR: 文件上传失败: code={code} msg={d.get('msg')}\", file=sys.stderr); sys.exit(1)
fk=(d.get('data') or {}).get('file_key') or ''
if not fk: print('ERR: 文件上传未返回 file_key', file=sys.stderr); sys.exit(1)
print(fk)")

SEND_BODY=$(curl -sS --fail-with-body --retry 2 --retry-all-errors --connect-timeout 10 --max-time 30 --noproxy '*' \
  -X POST 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id' \
  -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
  -d "{\"receive_id\":\"$CHAT\",\"msg_type\":\"file\",\"content\":\"{\\\"file_key\\\":\\\"$FK\\\"}\"}")
RES=$(printf '%s' "$SEND_BODY" | "$PY" -c "import sys,json; raw=sys.stdin.read();
try: d=json.loads(raw)
except Exception: print('ERR: 发送响应不是 JSON', file=sys.stderr); sys.exit(1)
print(d.get('code'), d.get('msg'))")
case "$RES" in
  "0 success") echo "SENT $SEND_PDF -> $CHAT" ;;
  *) echo "ERR: 发送失败: $RES" >&2; exit 1 ;;
esac
