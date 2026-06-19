#!/usr/bin/env bash
# gpt5pro —— 驱动 bb-browser 控制的 Chrome 里已登录的 ChatGPT Pro 会话,
# 用 GPT-5.5 Pro(网页"Pro 扩展"高推理桶,独立于 Codex 桶)做战略/规划,把回答打到 stdout。
# 设计:纯 eval(execCommand 注入 + DOM 轮询),不依赖会变动的 @ref;UI 驱动,不碰被防护的 backend API。
#
# 用法:  gpt5pro "你的战略问题"
#         echo "长 prompt" | gpt5pro          # 从 stdin 读
#         GPT5PRO_TIMEOUT=900 gpt5pro "..."   # 自定义超时(秒,默认 600)
#         GPT5PRO_KEEP=1 gpt5pro "..."        # 复用当前对话(默认每次开新对话,避免上下文污染)
set -euo pipefail

# --- NVM-safe 绝对路径(避免 lazy-loading 丢 PATH) ---
BB="$HOME/.nvm/versions/node/v24.14.0/bin/bb-browser"
[ -x "$BB" ] || BB="$(command -v bb-browser || true)"
[ -n "$BB" ] || { echo "❌ 找不到 bb-browser" >&2; exit 127; }

TIMEOUT="${GPT5PRO_TIMEOUT:-600}"
POLL=4
STABLE_NEED=3   # 连续 3 次(~12s)文本不变且无停止键 = 完成

# --- 取 prompt:参数优先,否则 stdin ---
if [ "$#" -gt 0 ]; then PROMPT="$*"; else PROMPT="$(cat)"; fi
[ -n "${PROMPT// /}" ] || { echo "用法: gpt5pro \"<战略问题>\"" >&2; exit 1; }

bbe(){ "$BB" eval "$1" 2>/dev/null; }

# --- 1. 准备对话页 ---
# 默认走【临时聊天】(?temporary-chat=true):无痕,不存进 ChatGPT 历史侧边栏,
# 因此无需事后删除、也无竞态。GPT5PRO_SAVE=1 才用普通(会留记录)对话。
URL="https://chatgpt.com/?temporary-chat=true"
[ "${GPT5PRO_SAVE:-0}" = "1" ] && URL="https://chatgpt.com/"
"$BB" open "$URL" >/dev/null 2>&1
"$BB" wait 4500 >/dev/null 2>&1

# --- 2. 登录态校验(脱敏,不碰 token) ---
login="$(bbe "(async()=>{try{const r=await fetch('/api/auth/session',{credentials:'include'});const j=await r.json();return j.user?'yes':'no';}catch(e){return 'err';}})()" | tr -d '\r\n ')"
if [ "$login" != "yes" ]; then
  echo "❌ bb-browser 的 Chrome 未登录 ChatGPT Pro(session=$login)。请在该 Chrome 窗口登录后重试。" >&2
  exit 2
fi

# --- 3. 注入 prompt(base64 传输,UTF-8/引号/换行全安全) ---
B64="$(printf '%s' "$PROMPT" | base64 | tr -d '\n')"
inj="$(bbe "(()=>{const t=new TextDecoder().decode(Uint8Array.from(atob('$B64'),c=>c.charCodeAt(0)));const el=document.querySelector('#prompt-textarea');if(!el)return 'no-input';el.focus();document.execCommand('selectAll',false,null);document.execCommand('insertText',false,t);return el.innerText.length>0?'ok':'empty';})()" | tr -d '\r\n ')"
[ "$inj" = "ok" ] || { echo "❌ prompt 注入失败(=$inj)" >&2; exit 3; }
"$BB" wait 700 >/dev/null 2>&1

# --- 4. 发送 ---
sent="$(bbe "(()=>{const b=document.querySelector('#composer-submit-button');if(!b)return 'no-btn';if(b.disabled)return 'disabled';b.click();return 'sent';})()" | tr -d '\r\n ')"
[ "$sent" = "sent" ] || { echo "❌ 发送失败(=$sent)" >&2; exit 4; }

# --- 5. 轮询完成(扛 Pro 长推理:思考期 n=0 / 流式期 s=true / 完成=无停止键且文本稳定) ---
elapsed=0; prevlen=-1; stable=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  "$BB" wait $((POLL*1000)) >/dev/null 2>&1
  elapsed=$((elapsed+POLL))
  st="$(bbe "(()=>{const stop=document.querySelector('[data-testid=stop-button],button[aria-label*=\"停止\"]');const m=document.querySelectorAll('[data-message-author-role=assistant]');const last=m[m.length-1];const md=last?.querySelector('.markdown')||last;return JSON.stringify({s:!!stop,n:m.length,len:(md?.innerText||'').length});})()")"
  s="$(printf '%s' "$st" | grep -o '"s":[a-z]*' | cut -d: -f2)"
  n="$(printf '%s' "$st" | grep -o '"n":[0-9]*' | cut -d: -f2)"
  len="$(printf '%s' "$st" | grep -o '"len":[0-9]*' | cut -d: -f2)"
  [ "${n:-0}" -lt 1 ] && continue                         # 还在思考,没出消息
  if [ "$s" = "true" ]; then prevlen="$len"; stable=0; continue; fi   # 流式中
  if [ "$len" = "$prevlen" ]; then stable=$((stable+1)); else stable=0; prevlen="$len"; fi
  [ "$stable" -ge "$STABLE_NEED" ] && break
done
[ "$elapsed" -lt "$TIMEOUT" ] || echo "⚠️ 达到超时 ${TIMEOUT}s,返回当前已生成内容(可能未完)" >&2

# --- 6. 抓取最终回答(base64 回传,保多行/特殊字符) ---
out="$(bbe "(()=>{const m=document.querySelectorAll('[data-message-author-role=assistant]');const last=m[m.length-1];const md=last?.querySelector('.markdown')||last;return btoa(unescape(encodeURIComponent(md?.innerText||'')));})()" | tr -d '\r\n ')"
[ -n "$out" ] || { echo "❌ 未抓到回答" >&2; exit 5; }
printf '%s' "$out" | base64 -d
echo
