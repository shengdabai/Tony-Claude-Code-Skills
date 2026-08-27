#!/bin/bash
# Tony Articles 每日发布链路只读体检：不生成、不提交、不推送、不发飞书。
set -uo pipefail

WORK="${TONY_ARTICLES_WORK:-$HOME/.local/share/tony-articles}"
TODAY="${DAILY_DOCTOR_DATE:-$(date +%Y-%m-%d)}"
SCRIPT_DIR="$HOME/.claude/scripts"
COMMON="$SCRIPT_DIR/daily-publish-common.sh"
PLISTS=(
  "$HOME/Library/LaunchAgents/com.tony.daily-article.plist"
  "$HOME/Library/LaunchAgents/com.tony.daily-ai-news.plist"
  "$HOME/Library/LaunchAgents/com.tony.daily-digest.plist"
)
SCRIPTS=(
  "$COMMON"
  "$SCRIPT_DIR/daily-network-route.sh"
  "$SCRIPT_DIR/daily-article.sh"
  "$SCRIPT_DIR/daily-ai-news.sh"
  "$SCRIPT_DIR/daily-digest.sh"
  "$0"
)

failures=0
warnings=0
pass() { printf 'PASS  %s\n' "$*"; }
warn() { warnings=$((warnings + 1)); printf 'WARN  %s\n' "$*"; }
fail() { failures=$((failures + 1)); printf 'FAIL  %s\n' "$*"; }

if [ ! -r "$COMMON" ]; then
  fail "公共可靠性库不存在"
  exit 1
fi
DAILY_PREFLIGHT_REPAIR=0
# shellcheck source=$HOME/.claude/scripts/daily-publish-common.sh
source "$COMMON"

syntax_ok=1
for script in "${SCRIPTS[@]}"; do
  bash -n "$script" || syntax_ok=0
done
[ "$syntax_ok" -eq 1 ] && pass "6 个发布脚本 Bash 语法" || fail "发布脚本 Bash 语法"

plist_ok=1
for plist in "${PLISTS[@]}"; do
  plutil -lint "$plist" >/dev/null || plist_ok=0
done
[ "$plist_ok" -eq 1 ] && pass "3 个 LaunchAgent plist 语法" || fail "LaunchAgent plist 语法"

if python3 - "${PLISTS[@]}" <<'PY'
import plistlib, sys

seen = {}
expected = {
    "com.tony.daily-article": "daily-article.sh",
    "com.tony.daily-ai-news": "daily-ai-news.sh",
    "com.tony.daily-digest": "daily-digest.sh",
}
for name in sys.argv[1:]:
    with open(name, "rb") as fh:
        data = plistlib.load(fh)
    label = data.get("Label")
    args = data.get("ProgramArguments") or []
    if label not in expected or not args or not str(args[-1]).endswith(expected[label]):
        raise SystemExit(1)
    entries = data.get("StartCalendarInterval") or []
    if isinstance(entries, dict):
        entries = [entries]
    for entry in entries:
        key = (entry.get("Hour"), entry.get("Minute"))
        if key in seen:
            raise SystemExit(2)
        seen[key] = label
PY
then
  pass "LaunchAgent 路由正确且 50 个触发时刻无碰撞"
else
  fail "LaunchAgent 路由或触发时刻冲突"
fi

if daily_infra_preflight "doctor"; then
  pass "代理、GitHub、CC Switch 实时健康"
else
  fail "代理、GitHub 或 CC Switch 实时健康"
fi

# shellcheck source=$HOME/.claude/scripts/daily-network-route.sh
source "$SCRIPT_DIR/daily-network-route.sh"
if daily_generation_preflight "doctor-generation"; then
  pass "GitHub + ChatGPT 生成端实时路由健康"
else
  fail "GitHub 或 ChatGPT 生成端实时路由"
fi

CODEX="${CODEX:-$HOME/.local/bin/codex}"
if DAILY_PREFLIGHT_REPAIR=0 daily_codex_ready "doctor-codex"; then
  pass "Codex CLI 可执行（$CODEX）"
else
  fail "Codex CLI 不可执行——平台二进制缺失，生成任务会全轮空转"
fi
if [ -x "$CODEX" ] && daily_getnote_preflight "$CODEX"; then
  pass "GetNote 配置存在且 Codex MCP 已启用（未读取凭据）"
else
  fail "GetNote 配置或 Codex MCP"
fi

ARTICLE_POLICY="$(DAILY_POLICY_PROBE=1 "$SCRIPT_DIR/daily-article.sh" 2>/dev/null)"
NEWS_POLICY="$(DAILY_POLICY_PROBE=1 "$SCRIPT_DIR/daily-ai-news.sh" 2>/dev/null)"
if [ "$ARTICLE_POLICY" = "article policy ok: readonly exporter + ignore-user-config + workspace-write" ] &&
   [ "$NEWS_POLICY" = "ai-news policy ok: ignore-user-config + plugins/apps disabled + workspace-write" ]; then
  pass "生成任务最小权限策略：只读采集器 + 无用户配置/MCP + 暂存区沙箱"
else
  fail "生成任务最小权限策略或 Codex 配置解析"
fi

if ! grep -q 'dangerously-bypass-approvals-and-sandbox' "$SCRIPT_DIR/daily-article.sh" "$SCRIPT_DIR/daily-ai-news.sh"; then
  pass "生成任务已移除无沙箱权限绕过"
else
  fail "生成任务仍含无沙箱权限绕过"
fi

if [ -d "$WORK/.git" ]; then
  cd "$WORK" || exit 1
  if [ -z "$(git status --porcelain)" ]; then
    pass "发布仓库工作区干净"
  else
    fail "发布仓库存在未提交改动"
  fi
  if daily_git_retry fetch -q origin main >/dev/null 2>&1 &&
     [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
    pass "本地 HEAD 与 origin/main 一致"
  else
    fail "无法确认本地 HEAD 与 origin/main 一致"
  fi
else
  fail "发布仓库不存在"
fi

if python3 - "$WORK" "$TODAY" <<'PY'
import re, sys
from pathlib import Path

root, day = Path(sys.argv[1]), sys.argv[2]
zh = list((root / "ai-news/zh").glob(f"{day}-*.md"))
en = list((root / "ai-news/en").glob(f"{day}-*.md"))
if len(zh) != 1 or len(en) != 1:
    raise SystemExit(1)
sets = []
for path in (zh[0], en[0]):
    urls = set(re.findall(r"\[source\]\((https?://[^)]+)\)", path.read_text(encoding="utf-8", errors="replace"), re.I))
    if not 5 <= len(urls) <= 8:
        raise SystemExit(2)
    sets.append(urls)
if sets[0] != sets[1]:
    raise SystemExit(3)
PY
then
  pass "当日 AI 热点中英双版均含 5–8 个相同来源 URL"
else
  fail "当日 AI 热点文件或来源 URL 门槛"
fi

if node --check "$SCRIPT_DIR/getnote-readonly-export.mjs" >/dev/null 2>&1 &&
   [ "$(rg -o 'client\.[A-Za-z]+\(' "$SCRIPT_DIR/getnote-readonly-export.mjs" | sort -u | tr '\n' ' ')" = "client.listNotes( client.recall( " ]; then
  pass "GetNote 固定采集器仅调用 listNotes + recall，Node 语法通过"
else
  fail "GetNote 只读采集器越权或语法错误"
fi

AIHOT_TMP="$(mktemp "${TMPDIR:-/tmp}/daily-doctor-aihot.XXXXXX")"
trap 'rm -f "$AIHOT_TMP"' EXIT
SINCE="$(python3 - <<'PY'
import datetime
print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(hours=24)).isoformat(timespec="seconds").replace("+00:00", "Z"))
PY
)"
if curl -x "$DAILY_PROXY_URL" -fsS --connect-timeout 8 --max-time 30 \
  "https://aihot.virxact.com/api/public/items?mode=selected&since=$SINCE&take=60" > "$AIHOT_TMP"; then
  HOT_COUNT="$(python3 - "$AIHOT_TMP" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    print(len(data.get("items") or []))
except Exception:
    print(-1)
PY
)"
  if [ "$HOT_COUNT" -ge 5 ] 2>/dev/null; then
    pass "aihot 过去 24h 返回 $HOT_COUNT 条候选"
  elif [ "$HOT_COUNT" -ge 0 ] 2>/dev/null; then
    warn "aihot 过去 24h 仅 $HOT_COUNT 条；流程会强制联网补齐至 5–8 条"
  else
    fail "aihot 返回非 JSON"
  fi
else
  warn "aihot 暂不可达；流程会在下一窗口重试并使用联网补全"
fi

if grep -q '发送前先查飞书真实历史' "$SCRIPT_DIR/daily-digest.sh" &&
   grep -q '回查工具不可用；不信任单一返回值' "$SCRIPT_DIR/daily-digest.sh"; then
  pass "飞书发送前查重、发送后回查均为 fail-closed"
else
  fail "飞书双重幂等门"
fi

if command -v lark-cli >/dev/null 2>&1; then
  LARK_TMP="$(mktemp "${TMPDIR:-/tmp}/daily-doctor-lark.XXXXXX")"
  if LARK_CLI_NO_PROXY=1 lark-cli --profile cli_aa80e81017f85bc0 --as user \
       im +chat-messages-list --chat-id oc_43c5ee271f2b76bd073779a169736142 --page-size 50 >"$LARK_TMP" 2>/dev/null; then
    DIGEST_COUNT="$(grep -o "盛大白每日 · ${TODAY}" "$LARK_TMP" | wc -l | tr -d ' ')"
    if [ "$DIGEST_COUNT" -eq 1 ]; then
      pass "飞书历史中当日 digest 恰好 1 条"
    elif [ "$DIGEST_COUNT" -eq 0 ]; then
      warn "飞书历史中尚未发现当日 digest"
    else
      fail "飞书历史中当日 digest 出现 $DIGEST_COUNT 次"
    fi
  else
    fail "飞书历史回查不可用"
  fi
  rm -f "$LARK_TMP"
else
  fail "lark-cli 不可用"
fi

printf '\nSUMMARY failures=%d warnings=%d\n' "$failures" "$warnings"
[ "$failures" -eq 0 ]
