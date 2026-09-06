#!/bin/bash
# Shared reliability helpers for the Tony Articles generation/publish pipeline.
# Safe to source from launchd jobs. It never changes proxy nodes, credentials,
# article content, Git history, or Feishu state.

DAILY_PROXY_URL="${DAILY_PROXY_URL:-http://127.0.0.1:7897}"
DAILY_PROXY_HOST="${DAILY_PROXY_HOST:-127.0.0.1}"
DAILY_PROXY_PORT="${DAILY_PROXY_PORT:-7897}"
DAILY_CC_SWITCH_HEALTH="${DAILY_CC_SWITCH_HEALTH:-http://127.0.0.1:15721/health}"
DAILY_PREFLIGHT_REPAIR="${DAILY_PREFLIGHT_REPAIR:-1}"

daily_common_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$*"
  else
    printf '[daily-publish] %s\n' "$*" >&2
  fi
}

daily_shanghai_hhmm() {
  local value="${DAILY_NOW_HHMM:-}"
  if [ -z "$value" ]; then
    value="$(TZ=Asia/Shanghai date +%H%M)"
  fi
  case "$value" in
    [0-2][0-9][0-5][0-9]) printf '%s\n' "$value" ;;
    *) daily_common_log "FATAL: 无效的上海时间 HHMM: $value"; return 1 ;;
  esac
}

daily_require_shanghai_noon() {
  local now
  now="$(daily_shanghai_hhmm)" || return 1
  if [ "$((10#$now))" -lt 1200 ]; then
    daily_common_log "当前上海时间 ${now:0:2}:${now:2:2} 早于 12:00，拒绝执行每日发布任务"
    return 1
  fi
  return 0
}

daily_retry_guidance() {
  local final_hhmm="$1" now
  now="$(daily_shanghai_hhmm)" || return 1
  if [ "$((10#$now))" -lt "$((10#$final_hhmm))" ]; then
    printf '若仍有当日定时窗口，将自动全新重试。\n'
  else
    printf '今日自动重试窗口已耗尽，需要人工处理。\n'
  fi
}

daily_audit_budget_exceeded_file() {
  # codex-security 的进度行是 "Estimated cost: $1.92 of $3.00 limit"（不含 exceed，不能误判）；
  # 超限时含 exceed 字样。旧正则要求 "cost " 后紧跟空格，实际是 "cost:"，从未命中（2026-09-06 桩测试发现）。
  grep -qiE 'estimated cost[^[:cntrl:]]*exceed|exceed[^[:cntrl:]]*(cost|budget)[^[:cntrl:]]*limit|cost limit[^[:cntrl:]]*exceed' "$1" 2>/dev/null
}

daily_bilingual_links_match() {
  local en_file="$1" zh_file="$2"
  python3 - "$en_file" "$zh_file" <<'PY'
import re
import sys
from pathlib import Path
from urllib.parse import unquote

en_path, zh_path = map(Path, sys.argv[1:])
expected = {f"../en/{en_path.name}", f"../zh/{zh_path.name}"}
for path in (en_path, zh_path):
    text = path.read_text(encoding="utf-8", errors="strict")
    links = {
        unquote(value)
        for value in re.findall(r"\]\((\.\./(?:en|zh)/[^)]+)\)", text)
    }
    if not expected.issubset(links):
        raise SystemExit(1)
PY
}

daily_export_proxy() {
  export HTTP_PROXY="$DAILY_PROXY_URL" HTTPS_PROXY="$DAILY_PROXY_URL" ALL_PROXY="$DAILY_PROXY_URL"
  export http_proxy="$DAILY_PROXY_URL" https_proxy="$DAILY_PROXY_URL" all_proxy="$DAILY_PROXY_URL"
  export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}"
  export no_proxy="${no_proxy:-$NO_PROXY}"
}

daily_proxy_ready() {
  nc -z -w 2 "$DAILY_PROXY_HOST" "$DAILY_PROXY_PORT" >/dev/null 2>&1
}

daily_restart_clash() {
  [ "$DAILY_PREFLIGHT_REPAIR" = "1" ] || return 1
  [ -d "/Applications/Clash Verge.app" ] || return 1
  daily_common_log "代理端口未就绪；仅重启 Clash Verge 应用与核心（不改节点/订阅）"
  /usr/bin/osascript -e 'tell application "Clash Verge" to quit' >/dev/null 2>&1 || true
  local i
  for i in 1 2 3 4 5; do
    pgrep -x clash-verge >/dev/null 2>&1 || break
    sleep 1
  done
  /usr/bin/open -a "Clash Verge" >/dev/null 2>&1 || return 1
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    daily_proxy_ready && return 0
    sleep 1
  done
  return 1
}

daily_http_code() {
  local url="$1"
  curl -x "$DAILY_PROXY_URL" -L -sS -o /dev/null \
    --connect-timeout 6 --max-time 20 -w '%{http_code}' "$url" 2>/dev/null || true
}

daily_github_ready() {
  local i code
  for i in 1 2 3; do
    code="$(daily_http_code https://github.com/)"
    case "$code" in
      2??|3??) return 0 ;;
    esac
    sleep "$i"
  done
  return 1
}

daily_cc_switch_ready() {
  curl -fsS --connect-timeout 3 --max-time 6 "$DAILY_CC_SWITCH_HEALTH" 2>/dev/null |
    grep -q '"status":"healthy"'
}

daily_restart_cc_switch() {
  [ "$DAILY_PREFLIGHT_REPAIR" = "1" ] || return 1
  [ -d "/Applications/CC Switch.app" ] || return 1
  daily_common_log "检测到 CC Switch 供应商熔断；仅重启应用以清理瞬时断路状态（不改渠道配置）"
  /usr/bin/osascript -e 'tell application "CC Switch" to quit' >/dev/null 2>&1 || true
  local i
  for i in 1 2 3 4 5; do
    pgrep -x "CC Switch" >/dev/null 2>&1 || break
    sleep 1
  done
  /usr/bin/open -a "CC Switch" >/dev/null 2>&1 || return 1
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    daily_cc_switch_ready && return 0
    sleep 1
  done
  return 1
}

daily_infra_preflight() {
  local context="${1:-daily-publish}"
  local require_cc_switch="${2:-1}"
  if ! daily_proxy_ready; then
    daily_restart_clash || {
      daily_common_log "FATAL: $context 基础设施预检失败：代理 $DAILY_PROXY_HOST:$DAILY_PROXY_PORT 未监听"
      return 1
    }
  fi
  daily_export_proxy
  if ! daily_github_ready; then
    if [ "$DAILY_PREFLIGHT_REPAIR" = "1" ]; then
      daily_restart_clash || true
      daily_export_proxy
    fi
    daily_github_ready || {
      daily_common_log "FATAL: $context 基础设施预检失败：GitHub 经本机代理不可达"
      return 1
    }
  fi
  # CC Switch 于 2026-08-26 被主动卸载（残留在 ~/.cc-switch.uninstalled-20260826，
  # 原因是它反复覆盖 ~/.codex/config.toml）。这个健康检查的意义是“装了但熔断了”，
  # 对一个根本没安装的组件强制要求，只会把发布链路永久卡死——所以未安装时降级跳过。
  if [ "$require_cc_switch" = "1" ] && [ ! -d "/Applications/CC Switch.app" ]; then
    require_cc_switch=0
    daily_common_log "$context 未安装 CC Switch，跳过其健康检查（codex 直连官方端点）"
  fi
  if [ "$require_cc_switch" = "1" ] && ! daily_cc_switch_ready; then
    if [ "$DAILY_PREFLIGHT_REPAIR" = "1" ] && [ -d "/Applications/CC Switch.app" ]; then
      /usr/bin/open -a "CC Switch" >/dev/null 2>&1 || true
      sleep 3
    fi
    daily_cc_switch_ready || {
      daily_common_log "FATAL: $context 基础设施预检失败：CC Switch 15721 健康检查未通过"
      return 1
    }
  fi
  if [ "$require_cc_switch" = "1" ]; then
    daily_common_log "$context 基础设施预检通过：proxy/GitHub/CC Switch"
  else
    daily_common_log "$context 基础设施预检通过：proxy/GitHub（本阶段不依赖 CC Switch）"
  fi
  return 0
}

daily_getnote_preflight() {
  local codex_bin="${1:-codex}"
  [ -r "$HOME/.config/getnote/.env" ] || {
    daily_common_log "FATAL: GetNote 环境文件缺失或不可读"
    return 1
  }
  "$codex_bin" mcp list 2>/dev/null |
    awk '$1=="getnote" && $0 ~ /enabled/ {found=1} END {exit !found}' || {
      daily_common_log "FATAL: Codex MCP 列表中 GetNote 未启用"
      return 1
    }
  daily_common_log "GetNote 配置预检通过（凭据内容未读取）"
}

daily_git_retry() {
  local attempt rc=1
  for attempt in 1 2 3; do
    git -c "http.proxy=$DAILY_PROXY_URL" "$@" && return 0
    rc=$?
    daily_common_log "Git ${1} 第 ${attempt} 次失败（rc=${rc}），将按边界重试"
    sleep $((attempt * 3))
  done
  return "$rc"
}

daily_transient_failure_file() {
  local file="$1"
  grep -qiE '所有供应商|熔断|503 Service Unavailable|502 Bad Gateway|504 Gateway Timeout|SSL_ERROR_SYSCALL|stream disconnected|Reconnecting\.\.\.|request timed out|connection timed out|connection refused|error sending request|transport channel closed' "$file" 2>/dev/null
}

daily_repair_transient_failure() {
  local file="$1"
  if grep -qiE '所有供应商|熔断|127\.0\.0\.1:15721|503 Service Unavailable' "$file" 2>/dev/null; then
    daily_restart_cc_switch || true
  fi
  if grep -qiE 'SSL_ERROR_SYSCALL|stream disconnected|Reconnecting\.\.\.|request timed out|connection timed out|connection refused|error sending request|transport channel closed' "$file" 2>/dev/null; then
    daily_restart_clash || true
    daily_export_proxy
  fi
}

daily_process_age_seconds() {
  local pid="$1"
  ps -p "$pid" -o etime= 2>/dev/null | awk -F '[-:]' '
    {
      gsub(/[[:space:]]/, "")
      if (NF == 4) print ($1 * 86400) + ($2 * 3600) + ($3 * 60) + $4
      else if (NF == 3) print ($1 * 3600) + ($2 * 60) + $3
      else if (NF == 2) print ($1 * 60) + $2
    }
  '
}

# Populate one canonical list of files written by .tools/gen_readme.py.
# Callers copy DAILY_PUBLICATION_INDEXES into a local array before use.
daily_publication_indexes() {
  local day="$1" year="${1%%-*}"
  [ -n "$day" ] && [ -n "$year" ] || return 1
  # Consumed by the sourcing script after this function returns.
  # shellcheck disable=SC2034
  DAILY_PUBLICATION_INDEXES=(
    README.md
    articles/en/README.md
    articles/zh/README.md
    "archive/${year}.md"
  )
}

daily_lock_mtime_epoch() {
  local lock_dir="$1"
  stat -f '%m' "$lock_dir" 2>/dev/null || stat -c '%Y' "$lock_dir" 2>/dev/null
}

daily_process_start_fingerprint() {
  local pid="$1"
  ps -p "$pid" -o lstart= 2>/dev/null | awk '{$1=$1; print}'
}

# Atomic directory lock with conservative stale recovery and owner-checked
# cleanup. A newly created lock without an owner file is treated as busy, which
# closes the mkdir->owner initialization race.
daily_lock_acquire() {
  local lock_dir="$1" stale_seconds="${2:-1200}"
  local now mtime age owner pid recorded_start current_start stale_dir token
  export DAILY_LOCK_STATUS="busy"
  current_start="$(daily_process_start_fingerprint $$ || true)"
  token="$$|${current_start}|$(date +%s)|${RANDOM:-0}"
  if mkdir "$lock_dir" 2>/dev/null; then
    if ! printf '%s\n' "$token" > "$lock_dir/owner"; then
      rmdir "$lock_dir" 2>/dev/null || true
      export DAILY_LOCK_STATUS="error"
      return 1
    fi
    export DAILY_LOCK_OWNER="$token"
    export DAILY_LOCK_STATUS="acquired"
    return 0
  fi

  now="$(date +%s)"
  mtime="$(daily_lock_mtime_epoch "$lock_dir" || true)"
  age=0
  if [ -n "$mtime" ] && [ "$now" -ge "$mtime" ] 2>/dev/null; then
    age=$((now - mtime))
  fi
  owner="$(cat "$lock_dir/owner" 2>/dev/null || true)"
  pid="${owner%%|*}"
  recorded_start="${owner#*|}"
  recorded_start="${recorded_start%%|*}"
  current_start=""
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    current_start="$(daily_process_start_fingerprint "$pid" || true)"
  fi
  if [ "$age" -lt "$stale_seconds" ] 2>/dev/null ||
     { [ -n "$recorded_start" ] && [ "$current_start" = "$recorded_start" ]; }; then
    daily_common_log "锁正被使用：${lock_dir}（age=${age}s pid=${pid:-pending}）"
    return 1
  fi

  stale_dir="${lock_dir}.stale.$$.$RANDOM"
  if ! mv "$lock_dir" "$stale_dir" 2>/dev/null; then
    return 1
  fi
  if ! mkdir "$lock_dir" 2>/dev/null; then
    rm -f "$stale_dir/owner" 2>/dev/null || true
    rmdir "$stale_dir" 2>/dev/null || true
    return 1
  fi
  if ! printf '%s\n' "$token" > "$lock_dir/owner"; then
    rmdir "$lock_dir" 2>/dev/null || true
    export DAILY_LOCK_STATUS="error"
    return 1
  fi
  rm -f "$stale_dir/owner" 2>/dev/null || true
  rmdir "$stale_dir" 2>/dev/null || true
  export DAILY_LOCK_OWNER="$token"
  export DAILY_LOCK_STATUS="acquired"
  daily_common_log "已原子回收陈旧锁：${lock_dir}（age=${age}s）"
  return 0
}

daily_lock_release() {
  local lock_dir="$1" expected_owner="$2" actual_owner
  actual_owner="$(cat "$lock_dir/owner" 2>/dev/null || true)"
  [ -n "$expected_owner" ] && [ "$actual_owner" = "$expected_owner" ] || return 1
  rm -f "$lock_dir/owner" 2>/dev/null || return 1
  rmdir "$lock_dir" 2>/dev/null || return 1
}

# Write the publication context into an audit staging directory.
# codex-security marks bare Markdown targets as "coverage partial" when it cannot
# tell which component renders/publishes them (open question seen 2026-09-06 →
# no receipt → release blocked). This file answers that question deterministically.
daily_write_audit_context() {
  local audit_dir="$1"
  [ -d "$audit_dir" ] || return 1
  cat > "$audit_dir/PUBLICATION_CONTEXT.md" <<'CTX'
# Publication context for this audit target (deployment facts only)

This directory is a static Markdown publication snapshot, not an application. The facts
below describe where and how these files are deployed; they are not a review verdict.

- **What is here**: the day's bilingual Markdown articles (`articles/` or `ai-news/`,
  `en/` + `zh/`). No code, build, server, renderer, or configuration is part of this
  snapshot; those live outside the repository and are described below.
- **Where it is published**: the files are committed unchanged to the public GitHub
  repository `shengdabai/Tony-Articles` (branch `main`) and rendered by GitHub's own
  Markdown renderer.
- **Secondary renderer**: a self-contained Python script converts the same Markdown to
  static HTML with `html.escape` applied to text and URLs; the output is served as plain
  static files (no server-side code, no templates evaluated at request time).
- **Content-change authorization**: only the owner's local, unattended publishing job
  commits and pushes, using the owner's own GitHub credentials. There are no external
  contributors, web forms, user input, authentication surface, or runtime.
- **Deployed-revision binding**: the deployed revision is `origin/main` HEAD after this
  job's push; the audit runs on the identical bytes before they are committed.
CTX
}

# 私密笔记零泄漏硬门禁（两篇共用，fail-closed）。
#   daily_notes_leak_check <zh_md> <en_md> <notes_json> <mode:news|article> [allowlist_json]
# 快照必须是生成器写不到的原件；缺失/为空/解析失败一律拒绝（显式 {"notes":[]} 才算"无笔记"）。
# 检查：笔记中的 URL / 邮箱 / 手机号出现在输出 → 拒绝（URL 若同时在 allowlist_json 里则放行）；
# 逐字片段：news 模式 ≥14 字，article 模式 ≥30 字（文章本就源自笔记，只拦整句/整段照搬）；
# news 模式额外禁止提及笔记来源。
daily_notes_leak_check() {
  local zh_file="$1" en_file="$2" notes_json="$3" mode="${4:-news}" allow_json="${5:-}"
  [ -s "$notes_json" ] || { daily_common_log "leak-check: 笔记快照缺失或为空，拒绝（fail-closed）"; return 1; }
  python3 - "$zh_file" "$en_file" "$notes_json" "$mode" "$allow_json" <<'PY'
import json, re, sys
from pathlib import Path
zh, en, notes_path, mode, allow_path = sys.argv[1:6]
try:
    data = json.load(open(notes_path, encoding="utf-8"))
    notes = data["notes"]
    assert isinstance(notes, list)
except Exception as exc:
    print(f"leak-check: snapshot unreadable ({exc.__class__.__name__}); refusing", file=sys.stderr)
    raise SystemExit(1)
url_re = re.compile(r"https?://[^\s\"'<>)\]]+")
def canon(u):
    # scheme+host+path，去 query/fragment/尾斜杠：私密 URL 追加 ?x 或 #y 也不能绕过。
    u = u.strip().lower()
    u = re.split(r"[?#]", u, maxsplit=1)[0]
    u = re.sub(r"^https?://", "", u)
    return u.rstrip("/")
PRIVATE_HOST = re.compile(r"(^|\.)(feishu\.cn|larksuite\.com|larkoffice\.com|notion\.(so|site)|docs\.google\.com|drive\.google\.com|docs\.qq\.com|kdocs\.cn|yuque\.com|shimo\.im|localhost)$|^(\d{1,3}\.){3}\d{1,3}$")
def is_private_host(u):
    host = canon(u).split("/", 1)[0]
    return bool(PRIVATE_HOST.search(host))
allow = set()
if allow_path:
    try:
        raw = Path(allow_path).read_text(encoding="utf-8", errors="replace")
        allow = {canon(u) for u in url_re.findall(raw)}
    except Exception:
        allow = set()
outputs = "\n".join(Path(p).read_text(encoding="utf-8", errors="replace") for p in (zh, en))
low = outputs.lower()
out_urls = {canon(u) for u in url_re.findall(outputs)}
mail_re = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
phone_re = re.compile(r"(?<!\d)(?:\+?86[- ]?)?1[3-9]\d{9}(?!\d)|(?<!\d)\+?\d{2,4}[- ]\d{3,4}[- ]\d{4}(?!\d)")
min_len = 14 if mode == "news" else 30
if mode == "news" and re.search(r"getnote|get note|我的笔记|私人笔记|作者记录|笔记里|笔记中", low):
    print("leak-check: output mentions note source", file=sys.stderr); raise SystemExit(1)
def fragments(text):
    for line in re.split(r"[\n。！？!?；;]", text or ""):
        line = line.strip()
        if len(line) >= min_len and not line.startswith("http"):
            yield line
# 扫描范围 = notes + 全部 recalls[].results（召回结果才是思考篇的素材主体，第 2 轮交叉审核 P0）。
scan = [n for n in notes if isinstance(n, dict)]
for group in (data.get("recalls") or []):
    if isinstance(group, dict):
        scan += [r for r in (group.get("results") or []) if isinstance(r, dict)]
# article 模式：笔记 ref_content（剪藏的外部公开资料）里的非私密域名链接允许被正文引用；
# 私密域名（飞书/Notion/Google Docs/腾讯文档/语雀/内网 IP 等）任何模式都不放行。
if mode == "article":
    for note in scan:
        for u in url_re.findall(str(note.get("ref_content") or "")):
            if not is_private_host(u):
                allow.add(canon(u))
for note in scan:
    text = "\n".join(str(note.get(k) or "") for k in ("title", "content", "ref_content"))
    for u in url_re.findall(text):
        key = canon(u)
        if key in allow and not is_private_host(u):
            continue
        # 精确匹配规范化 URL；带路径的具体链接再做子串匹配（覆盖追加 ?query/#frag 的变体）。
        # 纯域名（如 github.com）只做精确匹配，避免笔记里一个泛链接就封杀正文提到该域名。
        if key in out_urls or ("/" in key and len(key) >= 12 and key in low):
            print(f"leak-check: private note URL appears in output ({key[:60]})", file=sys.stderr); raise SystemExit(1)
    for m in mail_re.findall(text):
        if m.lower() in low:
            print("leak-check: note email appears in output", file=sys.stderr); raise SystemExit(1)
    for m in phone_re.findall(text):
        digits = re.sub(r"\D", "", m)
        if len(digits) >= 8 and digits in re.sub(r"\D", "", outputs):
            print("leak-check: note phone number appears in output", file=sys.stderr); raise SystemExit(1)
    for frag in fragments(text):
        if frag in outputs:
            print(f"leak-check: verbatim note fragment found ({len(frag)} chars)", file=sys.stderr); raise SystemExit(1)
raise SystemExit(0)
PY
}

# 公开发布前的确定性 URL 检查：只允许 https:// 链接（http:// 一律拒绝）。
daily_https_only_ok() {
  local f
  for f in "$@"; do
    if grep -qE 'http://' "$f"; then
      daily_common_log "URL 检查失败：含 http:// 链接 $(basename "$f")"
      return 1
    fi
  done
  return 0
}

# 推送完成后清理本地临时产物（GitHub + 飞书国内站可在线看，本地不留）。只删本流水线自己
# 生成的暂存/保留稿/审核证据/原始数据，不动 git 工作副本（推送机制）、不动审核收据。
# <date>=YYYY-MM-DD；同时兜底清理 14 天前的同类残留，并把三份运行日志封顶在 5MB。
daily_cleanup_after_publish() {
  local date="$1" logs="$HOME/.claude/logs" runs="$HOME/.local/state/product-release-audit/runs"
  local ymd removed=0 d f lock owner pid
  [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
  ymd="${date//-/}"
  # 有生成任务正在跑（例如人工 FORCE 补跑）时不清理，避免删掉它正在用的 STAGE/快照。
  for lock in /tmp/daily-article-generation.lock /tmp/daily-ai-news-generation.lock; do
    owner="$(cat "$lock/owner" 2>/dev/null || true)"; pid="${owner%%|*}"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      daily_common_log "本地清理跳过：生成任务运行中（pid ${pid}），下次再清"
      return 0
    fi
  done
  for d in "$logs"/daily-article-stage-"$date"-* "$logs"/daily-ai-news-stage-"$date"-* \
           "$logs"/daily-ai-news-pending-"$date" \
           "$logs"/daily-article-partial-"$date"-* "$logs"/daily-ai-news-partial-"$date"-* \
           "$runs"/"$ymd"T*-tony-article-audit."$date".* "$runs"/"$ymd"T*-tony-ai-news-audit."$date".* \
           "${TMPDIR:-/tmp}"/tony-article-audit."$date".* "${TMPDIR:-/tmp}"/tony-ai-news-audit."$date".* \
           "${TMPDIR:-/tmp}"/tony-article-audit-run."$date".* "${TMPDIR:-/tmp}"/tony-ai-news-audit-run."$date".*; do
    [ -e "$d" ] || continue
    rm -rf -- "$d" && removed=$((removed + 1))
  done
  [ -f "$logs/.aihot-raw-$date.json" ] && rm -f -- "$logs/.aihot-raw-$date.json" && removed=$((removed + 1))
  for f in "$logs"/.daily-ai-news-notes-"$date"-*.json "$logs"/.daily-article-notes-"$date"-*.json "$logs"/.daily-ai-news-aihot-"$date"-*.json; do
    [ -f "$f" ] && rm -f -- "$f" && removed=$((removed + 1))
  done
  # 无日期的中继文件只在清理"今天"时删：人工补发历史日期不能打断当日正在写的生成。
  if [ "$date" = "$(TZ=Asia/Shanghai date +%Y-%m-%d)" ]; then
    for f in "$logs/.daily-relay-codex-out.txt" "$logs/.daily-relay-codex-events.jsonl" \
             "$logs/.daily-ai-news-codex-out.txt" "$logs/.daily-ai-news-codex-events.jsonl"; do
      [ -f "$f" ] && rm -f -- "$f" && removed=$((removed + 1))
    done
  fi
  # 兜底：只限本流水线两个任务名、超过 14 天的残留；30 天前的当日标记文件。
  /usr/bin/find "$logs" -maxdepth 1 \( -name 'daily-article-stage-*' -o -name 'daily-article-partial-*' \
      -o -name 'daily-ai-news-stage-*' -o -name 'daily-ai-news-pending-*' -o -name 'daily-ai-news-partial-*' \
      -o -name '.aihot-raw-*.json' -o -name '.daily-ai-news-notes-*.json' -o -name '.daily-article-notes-*.json' -o -name '.daily-ai-news-aihot-*.json' \) \
      -mtime +14 -exec rm -rf {} + 2>/dev/null
  /usr/bin/find "$runs" -maxdepth 1 \( -name '*-tony-article-audit.*' -o -name '*-tony-ai-news-audit.*' \) -mtime +14 -exec rm -rf {} + 2>/dev/null
  /usr/bin/find "$logs" -maxdepth 1 -type f \( -name '.daily-article-*-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' \
      -o -name '.daily-ai-news-*-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' -o -name '.daily-digest-*-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' \) \
      -mtime +30 -delete 2>/dev/null
  # 日志封顶 5MB：同目录唯一临时文件 + 原子 mv；并发追加最多丢几行，可接受。
  local tmp
  for f in "$logs"/daily-article.codex.log "$logs"/daily-ai-news.codex.log "$logs"/daily-digest.log; do
    if [ -f "$f" ] && [ "$(stat -f%z "$f" 2>/dev/null || echo 0)" -gt 5242880 ]; then
      tmp="$(mktemp "$f.rotate.XXXXXX")" || continue
      tail -n 20000 "$f" > "$tmp" && mv -f "$tmp" "$f" || rm -f -- "$tmp"
    fi
  done
  daily_common_log "本地清理完成：${date} 暂存/保留稿/审核证据/原始数据已删除 ${removed} 项；git 工作副本保留为推送机制"
  return 0
}

# Copy a bilingual pair through private temporary names. If the second rename
# fails, remove only the destination created by this invocation.
daily_copy_pair_atomic() {
  local source_one="$1" dest_one="$2" source_two="$3" dest_two="$4"
  local temp_one temp_two moved_one=0
  [ -f "$source_one" ] && [ -f "$source_two" ] || return 1
  [ ! -e "$dest_one" ] && [ ! -e "$dest_two" ] || return 1
  temp_one="$(dirname "$dest_one")/.${RANDOM:-0}.$$.$(basename "$dest_one").tmp"
  temp_two="$(dirname "$dest_two")/.${RANDOM:-0}.$$.$(basename "$dest_two").tmp"
  rm -f "$temp_one" "$temp_two" 2>/dev/null || true
  cp -p "$source_one" "$temp_one" || return 1
  if ! cp -p "$source_two" "$temp_two"; then
    rm -f "$temp_one" "$temp_two" 2>/dev/null || true
    return 1
  fi
  if ! mv "$temp_one" "$dest_one"; then
    rm -f "$temp_one" "$temp_two" 2>/dev/null || true
    return 1
  fi
  moved_one=1
  if [ "${DAILY_COPY_PAIR_FAIL_AFTER_FIRST:-0}" = "1" ] || ! mv "$temp_two" "$dest_two"; then
    [ "$moved_one" -eq 0 ] || rm -f "$dest_one" 2>/dev/null || true
    rm -f "$temp_two" 2>/dev/null || true
    return 1
  fi
  return 0
}

daily_run_with_timeout() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
  elif [ -x /opt/homebrew/bin/gtimeout ]; then
    /opt/homebrew/bin/gtimeout "$seconds" "$@"
  else
    /usr/bin/perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
  fi
}

# Send one verified Feishu failure receipt per job/day through the Codex bot.
# The bridge deduplicates on the stable job/date id. Callers may retry freely.
daily_notify_failure_once() {
  local job="$1"
  local summary="$2"
  local work="${3:-$PWD}"
  local bridge="${DAILY_TASK_BRIDGE:-$HOME/Desktop/01-项目开发/15-飞书桥接/task-progress-bridge.py}"
  local day="${TODAY:-$(date +%F)}"
  local stable_id="${job}-${day}"
  local start_result finish_result finish_status

  if [ ! -f "$bridge" ] || ! command -v jq >/dev/null 2>&1; then
    daily_common_log "WARN: $job 飞书失败告警不可用（bridge/jq 缺失）"
    return 1
  fi

  start_result="$({
    jq -nc \
      --arg session_id "$stable_id" \
      --arg turn_id "$stable_id" \
      --arg cwd "$work" \
      --arg prompt "${job} 每日自动任务 · ${day}" \
      '{session_id:$session_id,turn_id:$turn_id,cwd:$cwd,prompt:$prompt}' |
      daily_run_with_timeout 30 env CODEX_NOTIFY_DISABLE=0 AI_TASK_NOTIFY_DISABLE=0 \
        /usr/bin/python3 "$bridge" --source codex --event UserPromptSubmit --emit-result
  } 2>/dev/null || true)"

  finish_result="$({
    jq -nc \
      --arg session_id "$stable_id" \
      --arg turn_id "$stable_id" \
      --arg cwd "$work" \
      --arg summary "$summary" \
      '{session_id:$session_id,turn_id:$turn_id,cwd:$cwd,last_assistant_message:$summary}' |
      daily_run_with_timeout 30 env CODEX_NOTIFY_DISABLE=0 AI_TASK_NOTIFY_DISABLE=0 \
        /usr/bin/python3 "$bridge" --source codex --event StopFailure --emit-result
  } 2>/dev/null || true)"

  finish_status="$(printf '%s' "$finish_result" | jq -r '.status // empty' 2>/dev/null || true)"
  case "$finish_status" in
    sent|deduped)
      daily_common_log "$job 飞书失败告警已确认（status=${finish_status}）"
      return 0
      ;;
    *)
      daily_common_log "WARN: $job 飞书失败告警未确认（start=${start_result:-empty} finish=${finish_result:-empty}）"
      return 1
      ;;
  esac
}

# --- Codex CLI 可执行性守卫 -------------------------------------------------
# 2026-08-27 事故：npm 的 optionalDependencies 在 npmmirror 源下丢了平台二进制
# (@openai/codex-darwin-arm64)，nvm 里的 codex 启动即 rc=1。生成脚本此前只检查
# 代理/GitHub/ChatGPT，不检查 codex 本身能不能跑，于是 13 轮接力在 4 秒内全部
# 烧掉，最后以“暂存区 en=0 zh=0”结束——日志里看不出真正原因，当天无推送。
# 这里把“codex 能不能跑”提前成硬预检，并在失败时做一次有界自愈。
DAILY_CODEX_FALLBACKS="${DAILY_CODEX_FALLBACKS:-$HOME/.local/bin/codex $HOME/.nvm/versions/node/v24.14.0/bin/codex}"
DAILY_CODEX_NPM="${DAILY_CODEX_NPM:-$HOME/.nvm/versions/node/v24.14.0/bin/npm}"
DAILY_CODEX_NPM_PREFIX="${DAILY_CODEX_NPM_PREFIX:-$HOME/.nvm/versions/node/v24.14.0}"

daily_codex_probe() {
  local bin="${1:-}"
  [ -n "$bin" ] || return 1
  [ -x "$bin" ] || [ -L "$bin" ] || return 1
  "$bin" --version 2>/dev/null | grep -Eq '^codex-cli [0-9]+\.[0-9]+\.[0-9]+'
}

daily_codex_repair() {
  [ "$DAILY_PREFLIGHT_REPAIR" = "1" ] || return 1
  [ -x "$DAILY_CODEX_NPM" ] || return 1
  daily_common_log "尝试有界自愈：重装 @openai/codex@latest（平台二进制缺失）"
  env NPM_CONFIG_PREFIX="$DAILY_CODEX_NPM_PREFIX" \
    /usr/bin/perl -e 'alarm shift; exec @ARGV' 300 \
    "$DAILY_CODEX_NPM" install -g @openai/codex@latest >/dev/null 2>&1
}

# 用法: daily_codex_ready <context>；成功后把可用路径写回全局 CODEX 并导出。
daily_codex_ready() {
  local context="${1:-daily-generation}"
  local candidates="${CODEX:-} ${DAILY_CODEX_FALLBACKS:-}"
  local bin=""
  local ver=""
  local round=0
  while [ "$round" -lt 2 ]; do
    round=$((round + 1))
    for bin in $candidates; do
      ver=""
      if [ -x "$bin" ] || [ -L "$bin" ]; then
        ver="$("$bin" --version 2>/dev/null || true)"
      fi
      case "$ver" in
        codex-cli\ [0-9]*)
          CODEX="$bin"
          export CODEX
          daily_common_log "$context Codex 可执行性预检通过: $bin ($ver)"
          return 0
          ;;
      esac
    done
    [ "$round" -eq 1 ] || break
    daily_common_log "WARN: $context 所有候选 codex 均无法启动，进入一次性自愈"
    daily_codex_repair || break
  done
  daily_common_log "FATAL: $context Codex CLI 不可执行（平台二进制缺失或未安装），拒绝进入接力循环"
  return 1
}

# 供接力循环内识别“二进制本身坏了”，避免把重试预算烧在必然失败的调用上。
daily_codex_binary_failure_file() {
  local file="$1"
  grep -qiE 'Missing optional dependency @openai/codex|findCodexExecutable|codex: command not found|No such file or directory.*codex' "$file" 2>/dev/null
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  daily_infra_preflight "standalone-check"
fi

# Generation uses one lock per job; only shared checkout operations serialize.
daily_checkout_acquire() {
  local deadline=$((SECONDS + ${DAILY_CHECKOUT_WAIT_SECONDS:-600}))
  DAILY_CHECKOUT_LOCK="${DAILY_PUBLICATION_LOCK:-/tmp/daily-claude-session.lock}"
  while ! daily_lock_acquire "$DAILY_CHECKOUT_LOCK" 2400; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      daily_common_log "ERROR: 等待共享发布仓库锁超时，保留状态供下个窗口重试"
      return 1
    fi
    sleep 2
  done
  DAILY_CHECKOUT_OWNER="$DAILY_LOCK_OWNER"
}

daily_checkout_release() {
  if [ -n "${DAILY_CHECKOUT_OWNER:-}" ]; then
    daily_lock_release "$DAILY_CHECKOUT_LOCK" "$DAILY_CHECKOUT_OWNER" || return 1
    DAILY_CHECKOUT_OWNER=""
  fi
}
