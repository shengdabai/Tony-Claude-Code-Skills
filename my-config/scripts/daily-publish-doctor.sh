#!/bin/bash
# Tony Articles 每日发布链路只读体检：不生成、不提交、不推送、不发飞书。
set -uo pipefail

WORK="${TONY_ARTICLES_WORK:-$HOME/.local/share/tony-articles}"
TODAY="${DAILY_DOCTOR_DATE:-$(TZ=Asia/Shanghai date +%Y-%m-%d)}"
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
# Read by functions sourced from daily-publish-common.sh.
# shellcheck disable=SC2034
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
schedules = {}
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
    schedules[label] = entries
    for entry in entries:
        key = (entry.get("Hour"), entry.get("Minute"))
        if key in seen:
            raise SystemExit(2)
        seen[key] = label

expected_schedules = {
    "com.tony.daily-article": [(12, 0), (13, 0), (14, 0), (15, 0)],
    "com.tony.daily-ai-news": [(12, 45), (13, 45), (14, 45), (15, 45)],
    "com.tony.daily-digest": [(13, 30), (14, 30), (15, 30), (16, 30)],
}
for label, expected_slots in expected_schedules.items():
    actual_slots = [(entry["Hour"], entry["Minute"]) for entry in schedules[label]]
    if actual_slots != expected_slots:
        raise SystemExit(3)
PY
then
  pass "LaunchAgent 仅在 12:00 后串行生成、补偿和分发，且时刻无碰撞"
else
  fail "LaunchAgent 路由或触发时刻冲突"
fi

if python3 - <<'PY'
import os, re, subprocess

expected = {
    "com.tony.daily-article": {(12, 0), (13, 0), (14, 0), (15, 0)},
    "com.tony.daily-ai-news": {(12, 45), (13, 45), (14, 45), (15, 45)},
    "com.tony.daily-digest": {(13, 30), (14, 30), (15, 30), (16, 30)},
}
uid = os.getuid()
for label, wanted in expected.items():
    text = subprocess.check_output(
        ["launchctl", "print", f"gui/{uid}/{label}"], text=True, stderr=subprocess.DEVNULL
    )
    blocks = re.findall(r"descriptor = \{(.*?)\n\s*\}", text, re.S)
    actual = set()
    for block in blocks:
        minute = re.search(r'"Minute" => (\d+)', block)
        hour = re.search(r'"Hour" => (\d+)', block)
        if minute and hour:
            actual.add((int(hour.group(1)), int(minute.group(1))))
    if actual != wanted:
        raise SystemExit(f"{label}: loaded={sorted(actual)} expected={sorted(wanted)}")
PY
then
  pass "launchd 实际已加载时刻与 plist 契约一致"
else
  fail "launchd 实际已加载时刻与 plist 不一致（可能忘记 reload）"
fi

if [ "$(grep -c '^CODEX_MODEL="gpt-5.6-sol"$' "$SCRIPT_DIR/daily-article.sh")" -eq 1 ] &&
   [ "$(grep -c '^CODEX_MODEL="gpt-5.6-sol"$' "$SCRIPT_DIR/daily-ai-news.sh")" -eq 1 ] &&
   ! grep -qE 'gpt-5\.6-(terra|luna)' "$SCRIPT_DIR/daily-article.sh" "$SCRIPT_DIR/daily-ai-news.sh" &&
   grep -q -- '--max-cost 3.0 --model gpt-5.6-sol --effort low' "$SCRIPT_DIR/daily-article.sh" &&
   grep -q -- '--max-cost 3.0 --model gpt-5.6-sol --effort low' "$SCRIPT_DIR/daily-ai-news.sh"; then
  pass "生成与发布审计唯一模型契约为 gpt-5.6-sol"
else
  fail "生成或发布审计存在非 Sol 模型/旧预算参数"
fi

HERMES_PYTHON="$HOME/.hermes/hermes-agent/venv/bin/python"
if [ -x "$HERMES_PYTHON" ] && "$HERMES_PYTHON" - "$HOME/.hermes/config.yaml" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as source:
    config = yaml.safe_load(source) or {}
model = config.get("model") or {}
assert "fallback_providers" in config
fallbacks = config["fallback_providers"]
feishu = (((config.get("platforms") or {}).get("feishu") or {}).get("extra") or {})
agent = config.get("agent") or {}
assert model.get("provider") == "openai-codex"
assert model.get("default") == "gpt-5.6-sol"
assert fallbacks == []
assert feishu.get("require_mention") is True
assert agent.get("reasoning_effort") == "high"
title_generation = ((config.get("auxiliary") or {}).get("title_generation") or {})
assert title_generation.get("provider") == "openai-codex"
assert title_generation.get("model") == "gpt-5.6-sol"
PY
then
  pass "Commander 主回复/fallback/标题生成锁定 GPT-5.6 Sol，群聊侧必须 @提及"
else
  fail "Commander 模型或飞书群聊门禁回归"
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
  pass "Codex CLI 可执行（${CODEX}）"
else
  fail "Codex CLI 不可执行——平台二进制缺失，生成任务会全轮空转"
fi
if [ -x "$CODEX" ] && daily_getnote_preflight "$CODEX"; then
  pass "GetNote 配置存在且 Codex MCP 已启用（未读取凭据）"
else
  fail "GetNote 配置或 Codex MCP"
fi

ARTICLE_POLICY_LOCK="${TMPDIR:-/tmp}/daily-doctor-article-policy.$$"
NEWS_POLICY_LOCK="${TMPDIR:-/tmp}/daily-doctor-news-policy.$$"
ARTICLE_POLICY="$(DAILY_SESSION_LOCK="$ARTICLE_POLICY_LOCK" DAILY_POLICY_PROBE=1 "$SCRIPT_DIR/daily-article.sh" 2>/dev/null)"
NEWS_POLICY="$(DAILY_SESSION_LOCK="$NEWS_POLICY_LOCK" DAILY_POLICY_PROBE=1 "$SCRIPT_DIR/daily-ai-news.sh" 2>/dev/null)"
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
  SHANGHAI_HHMM="$(TZ=Asia/Shanghai date +%H%M)"
  if [ "$((10#$SHANGHAI_HHMM))" -lt 1630 ]; then
    warn "当日 AI 热点尚未完成；12:45–15:45 生成/补偿窗口仍有效"
  else
    fail "当日 AI 热点文件或来源 URL 门槛"
  fi
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
   grep -q '回查工具不可用；不信任单一返回值' "$SCRIPT_DIR/daily-digest.sh" &&
   grep -Fq '"$HERMES_GATEWAY_PY" "$HERMES_SEND_WRAPPER" send' "$SCRIPT_DIR/daily-digest.sh" &&
   grep -q -- '--file "$MSGFILE" --json' "$SCRIPT_DIR/daily-digest.sh" &&
   grep -q 'env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY' "$SCRIPT_DIR/daily-digest.sh" &&
   grep -q 'PlistBuddy.*ProgramArguments:0' "$SCRIPT_DIR/daily-digest.sh" &&
   grep -q 'daily_run_with_timeout 120 env' "$SCRIPT_DIR/daily-digest.sh" &&
   grep -q 'daily-digest-delivery:' "$SCRIPT_DIR/daily-digest.sh" &&
   grep -q 'MSG_CHARS.*7000' "$SCRIPT_DIR/daily-digest.sh" &&
   "$HERMES_PYTHON" -m py_compile "$SCRIPT_DIR/hermes-send-direct-feishu.py" &&
   ! grep -q 'im +messages-send' "$SCRIPT_DIR/daily-digest.sh"; then
  pass "Commander release bot 无模型直发、无代理、发送前查重、发送后精确计数均已启用"
else
  fail "飞书 bot 直发/查重/回查门禁"
fi

if command -v lark-cli >/dev/null 2>&1; then
  LARK_SCOPE_TMP="$(mktemp "${TMPDIR:-/tmp}/daily-doctor-lark-scope.XXXXXX")"
  if lark-cli --profile cli_aa80e81017f85bc0 auth check \
       --scope 'im:message:readonly im:chat:read' \
       --json >"$LARK_SCOPE_TMP" 2>/dev/null &&
     python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
raise SystemExit(0 if d.get("ok") and not d.get("missing") else 1)' "$LARK_SCOPE_TMP"; then
    pass "飞书用户身份仅保留历史回查权限"
  else
    fail "飞书用户身份缺少历史回查权限"
  fi
  rm -f "$LARK_SCOPE_TMP"
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
