#!/bin/bash
# feishu-html-pdf.sh — HTML → 单页不分页 PDF → 以指定飞书 bot 身份把 PDF 发回聊天
#
# 用法: feishu-html-pdf.sh <html路径> [chat_id] [app_id] [extra-css路径]
#   chat_id 省略 = 只转换不发送
#   app_id  省略 = Claude bot (cli_aa9a8b56bbfbdcc7)
#     Claude bot: cli_aa9a8b56bbfbdcc7   Codex bot:    cli_aa9ae2200e795cb3
#     agy bot:    cli_aa9b9e38c1f8dbd3   DeepSeek bot: cli_aa9b9ee68d38dbe9
#
# 依赖: onepage-pdf skill + pymupdf + Chrome + lark-channel keystore(取 app secret)
# 注意: 发送方 bot 必须是目标 chat 的成员;飞书 API 直连(--noproxy)
set -euo pipefail

HTML="$1"
CHAT="${2:-}"
APP="${3:-cli_aa9a8b56bbfbdcc7}"
CSS="${4:-}"

PY="/usr/local/bin/python3"
CONVERTER="$HOME/.claude/skills/onepage-pdf/scripts/onepage_pdf.py"
KEYSTORE="$HOME/.lark-channel/secrets-getter"
PDF="${HTML%.html}.pdf"

args=("$HTML" -o "$PDF" --width 1280)
[ -n "$CSS" ] && args=("${args[@]}" --extra-css "$CSS")
"$PY" "$CONVERTER" "${args[@]}" >&2

if [ -z "$CHAT" ]; then
  echo "PDF $PDF"
  exit 0
fi

SEC=$(echo "{\"ids\":[\"app-$APP\"]}" | "$KEYSTORE" | "$PY" -c "import sys,json;print(json.load(sys.stdin)['values']['app-$APP'])")
TOK=$(curl -s --noproxy '*' -X POST https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal \
  -H 'Content-Type: application/json' -d "{\"app_id\":\"$APP\",\"app_secret\":\"$SEC\"}" |
  "$PY" -c "import sys,json;print(json.load(sys.stdin).get('tenant_access_token',''))")
[ -n "$TOK" ] || { echo "ERR: tenant token 获取失败 (app=$APP)" >&2; exit 1; }

FK=$(curl -s --noproxy '*' -X POST https://open.feishu.cn/open-apis/im/v1/files \
  -H "Authorization: Bearer $TOK" \
  -F file_type=pdf -F "file_name=$(basename "$PDF")" -F "file=@$PDF" |
  "$PY" -c "import sys,json;d=json.load(sys.stdin);print(d.get('data') and d['data'].get('file_key') or '');import sys as s;d.get('code')==0 or print(d,file=s.stderr)")
[ -n "$FK" ] || { echo "ERR: 文件上传失败 (app=$APP)" >&2; exit 1; }

RES=$(curl -s --noproxy '*' -X POST 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id' \
  -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
  -d "{\"receive_id\":\"$CHAT\",\"msg_type\":\"file\",\"content\":\"{\\\"file_key\\\":\\\"$FK\\\"}\"}" |
  "$PY" -c "import sys,json;d=json.load(sys.stdin);print(d.get('code'),d.get('msg'))")
case "$RES" in
  "0 success") echo "SENT $PDF -> $CHAT" ;;
  *) echo "ERR: 发送失败: $RES" >&2; exit 1 ;;
esac
