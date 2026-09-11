#!/usr/bin/env bash
# cc-run.sh v2 — cc 多模型流水线统一调用 wrapper。
# v2 修复(三方审核 codex/agy/claude 共识):
#   - S1: prompt 走真正的 stdin(< pf),杜绝 $(cat) 的 ARG_MAX(256KB)崩溃 + 进程列表泄露
#   - U3: secret preflight,拒绝把私钥/token 模式喂给外部模型(配 secrets-firewall)
#   - U1/U6: parse_verdict 容忍 \r/空白 + 同时支持 plain 与 JSON footer 判词
#   - U2: 进程组超时清理(gtimeout 优先;fallback 递归杀子进程,不留僵尸 sleep)
#   - U8: resolve_bin() 统一二进制解析(PATH 优先,回退绝对路径)
#   - S10: state.jsonl 机器可读状态(每次 call 追加一条),支撑恢复/审计/服务化
#   - 新增 status 子命令:输出已发生的调用、verdict、下一步提示
#
# 用法:
#   cc-run.sh probe <workdir>
#       探测 codex/gpt5pro/agy 可用性,写 <workdir>/capabilities.md。未通过者不得算有效审查方。
#   cc-run.sh call <role> <cli> <promptfile> <outdir> [sandbox]
#       cli ∈ codex|gpt5pro|agy ; sandbox ∈ read-only(默认)|workspace-write(仅 codex)
#       产出:<outdir>/<role>.full.log(全量) <role>.exit <role>.verdict;追加 <outdir>/state.jsonl
#       stdout 末行打印 "PARSED_VERDICT: X"。X ∈ CONSENSUS|REVISE|APPROVED|ISSUES_FOUND|UNKNOWN|BLOCKED
#   cc-run.sh status <workdir>
#       汇总 state.jsonl:已发生调用 / verdict / 异常,供中断恢复。
#   cc-run.sh slug "<任务关键词>"
#       生成安全目录 slug:中文转拼音(有 pypinyin 则)、保 ascii、截断 24 字符、空则 task。
set -uo pipefail

CODEX_BIN="${CODEX_BIN:-$HOME/.nvm/versions/node/v24.14.0/bin/codex}"
GPT5PRO_BIN="${GPT5PRO_BIN:-$HOME/.local/bin/gpt5pro}"
AGY_BIN="${AGY_BIN:-$HOME/.local/bin/agy}"
CODEX_MODEL="${CODEX_MODEL:-gpt-5.5}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-3-pro-high}"
CALL_TIMEOUT="${CALL_TIMEOUT:-600}"        # 单次调用墙钟上限(秒)
MAX_PROMPT_BYTES="${MAX_PROMPT_BYTES:-800000}"  # prompt 上限,超则拒(stdin 无 ARG_MAX 限制,但超大=喂错东西)
PY="$(command -v python3 || true)"

die() { echo "cc-run: $*" >&2; exit 64; }

# ── 二进制解析:PATH 优先,回退绝对路径(修 U8) ──────────────
resolve_bin() { # <name> <fallback_abs>
  local p; p="$(command -v "$1" 2>/dev/null || true)"
  [ -n "$p" ] && { echo "$p"; return 0; }
  [ -e "$2" ] && { echo "$2"; return 0; }
  return 1
}

# codex 随 nvm node 版本走,硬编码路径会因 node 升级/codex 自动更新而失效。
# 解析顺序:PATH → 配置的 CODEX_BIN → 扫 nvm 任意 node 版本取最新存在者。
find_codex() {
  local p; p="$(command -v codex 2>/dev/null || true)"
  [ -n "$p" ] && { echo "$p"; return 0; }
  [ -e "$CODEX_BIN" ] && { echo "$CODEX_BIN"; return 0; }
  local c; c="$(ls -t "$HOME"/.nvm/versions/node/*/bin/codex 2>/dev/null | head -1)"
  [ -n "$c" ] && [ -e "$c" ] && { echo "$c"; return 0; }
  return 1
}

# ── 跨平台 timeout + 进程组清理(修 U2) ──────────────────────
run_to() { # <secs> <cmd...>(stdin/stdout 由调用方重定向)
  local secs="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 10 "$secs" "$@"; return $?; fi
  if command -v timeout  >/dev/null 2>&1; then timeout  -k 10 "$secs" "$@"; return $?; fi
  # fallback:无 GNU timeout。后台跑 + watchdog,超时递归杀子进程,退出时清 watchdog 的 sleep
  "$@" & local pid=$!
  ( sleep "$secs"
    if kill -0 "$pid" 2>/dev/null; then
      pkill -P "$pid" 2>/dev/null   # 先杀子进程(codex 的 node / agy 的 chrome)
      kill -9 "$pid" 2>/dev/null
    fi ) & local wd=$!
  wait "$pid" 2>/dev/null; local rc=$?
  pkill -P "$wd" 2>/dev/null; kill "$wd" 2>/dev/null   # 清 watchdog 及其 sleep,杜绝僵尸
  return "$rc"
}

# ── secret preflight:拒绝把真实密钥喂给外部模型(修 U3) ──────
secret_scan() { # <promptfile> → 命中真实密钥模式则 die
  local pf="$1"
  if grep -qE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$pf" 2>/dev/null; then
    die "SECRET DETECTED(private key)in $pf — 拒绝外发,请脱敏后重试"
  fi
  # OpenAI sk-/ghp_/AWS AKIA/Slack xox 等高置信 token 模式(长度门槛降误报)
  if grep -qE '(sk-[A-Za-z0-9]{24,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,})' "$pf" 2>/dev/null; then
    die "SECRET DETECTED(api token)in $pf — 拒绝外发,请脱敏后重试"
  fi
}

# ── VERDICT 解析:容忍 \r/空白,同时吃 plain 与 JSON footer(修 U1/U6) ──
parse_verdict() { # <logfile>
  local log="$1" v
  [ -s "$log" ] || { echo UNKNOWN; return; }
  # 同时匹配  VERDICT: APPROVED  和  "verdict":"APPROVED"  ,取最后一个,强制大写去空白
  v="$(grep -oiE '(verdict"?[": ]+|VERDICT: *)(CONSENSUS|REVISE|APPROVED|ISSUES_FOUND)' "$log" 2>/dev/null \
        | grep -oiE '(CONSENSUS|REVISE|APPROVED|ISSUES_FOUND)' | tail -1 | tr -d '[:space:]' \
        | tr '[:lower:]' '[:upper:]')"
  [ -n "$v" ] && echo "$v" || echo UNKNOWN
}

# ── state.jsonl 追加一条机器可读记录(修 S10) ────────────────
state_append() { # <outdir> <role> <cli> <exit> <verdict> <bytes>
  [ -n "$PY" ] || return 0
  "$PY" - "$1/state.jsonl" "$2" "$3" "$4" "$5" "$6" <<'PYEOF' 2>/dev/null || true
import sys,json,time
path,role,cli,rc,verdict,by=sys.argv[1:7]
rec={"ts":int(time.time()),"role":role,"cli":cli,"exit":int(rc),"verdict":verdict,"bytes":int(by)}
open(path,"a").write(json.dumps(rec,ensure_ascii=False)+"\n")
PYEOF
}

cmd="${1:-}"; shift 2>/dev/null || die "missing subcommand (probe|call|status|slug)"

case "$cmd" in
  probe)
    OUT="${1:?workdir}"; mkdir -p "$OUT"
    cap="$OUT/capabilities.md"
    { echo "# cc capabilities probe"; echo "_探测时间见文件 mtime_"; echo; } > "$cap"
    cb="$(find_codex || true)"
    if [ -n "$cb" ]; then
      if run_to 120 "$cb" exec --skip-git-repo-check -m "$CODEX_MODEL" -s read-only \
           <<<"reply with exactly one line: VERDICT: APPROVED" >"$OUT/probe-codex.log" 2>&1 \
         && grep -q 'VERDICT: APPROVED' "$OUT/probe-codex.log"; then
        echo "- **codex**: OK ($cb, $CODEX_MODEL)" >> "$cap"
      else echo "- **codex**: UNAVAILABLE → 见 probe-codex.log(不得算有效审查方)" >> "$cap"; fi
    else echo "- **codex**: NOT FOUND" >> "$cap"; fi
    gb="$(resolve_bin gpt5pro "$GPT5PRO_BIN" || true)"
    [ -n "$gb" ] && echo "- **gpt5pro**: PRESENT($gb;实际可用看首调是否 session=no)" >> "$cap" \
                  || echo "- **gpt5pro**: NOT FOUND" >> "$cap"
    ab="$(resolve_bin agy "$AGY_BIN" || true)"
    if [ -n "$ab" ]; then
      if run_to 120 "$ab" -p --model "$GEMINI_MODEL" --print-timeout 90s \
           <<<"reply with exactly one line: VERDICT: APPROVED" >"$OUT/probe-agy.log" 2>&1 \
         && grep -q 'VERDICT: APPROVED' "$OUT/probe-agy.log"; then
        echo "- **agy/gemini**: OK ($GEMINI_MODEL)" >> "$cap"
      else echo "- **agy/gemini**: UNAVAILABLE(多半 token 过期,裸跑 \`agy\` 登录)→ 见 probe-agy.log" >> "$cap"; fi
    else echo "- **agy/gemini**: NOT FOUND" >> "$cap"; fi
    cat "$cap"
    ;;

  call)
    role="${1:?role}"; cli="${2:?cli}"; pf="${3:?promptfile}"; out="${4:?outdir}"; sandbox="${5:-read-only}"
    [ -s "$pf" ] || die "prompt file empty/missing: $pf"
    mkdir -p "$out"
    # preflight:大小 + secret
    bytes="$(wc -c < "$pf" | tr -d ' ')"
    [ "$bytes" -gt "$MAX_PROMPT_BYTES" ] && die "prompt too large(${bytes}B > ${MAX_PROMPT_BYTES}B)— 先裁剪上下文"
    secret_scan "$pf"
    full="$out/${role}.full.log"; exitf="$out/${role}.exit"; vf="$out/${role}.verdict"
    rc=0
    case "$cli" in
      codex)
        cb="$(find_codex)" || die "codex not found(PATH/nvm 均无)"
        run_to "$CALL_TIMEOUT" "$cb" exec --skip-git-repo-check -m "$CODEX_MODEL" -s "$sandbox" \
          <"$pf" >"$full" 2>&1 || rc=$?
        ;;
      gpt5pro)
        gb="$(resolve_bin gpt5pro "$GPT5PRO_BIN")" || die "gpt5pro not found"
        run_to "$CALL_TIMEOUT" "$gb" "$(cat "$pf")" </dev/null >"$full" 2>&1 || rc=$?
        ;;
      agy)
        ab="$(resolve_bin agy "$AGY_BIN")" || die "agy not found"
        # AGY_ADD_DIR 透传 Gemini 1M 上下文甜区:--add-dir <项目根> 喂全 repo 做全局回归审
        if [ -n "${AGY_ADD_DIR:-}" ]; then
          run_to "$CALL_TIMEOUT" "$ab" -p --model "$GEMINI_MODEL" --print-timeout 8m --add-dir "$AGY_ADD_DIR" \
            <"$pf" >"$full" 2>&1 || rc=$?
        else
          run_to "$CALL_TIMEOUT" "$ab" -p --model "$GEMINI_MODEL" --print-timeout 8m \
            <"$pf" >"$full" 2>&1 || rc=$?
        fi
        ;;
      *) die "unknown cli: $cli (codex|gpt5pro|agy)";;
    esac
    echo "$rc" > "$exitf"
    outbytes="$(wc -c < "$full" 2>/dev/null | tr -d ' ' || echo 0)"
    if [ "$rc" -ne 0 ] || [ ! -s "$full" ]; then
      echo "UNKNOWN" > "$vf"
    else
      parse_verdict "$full" > "$vf"
    fi
    state_append "$out" "$role" "$cli" "$rc" "$(cat "$vf")" "$outbytes"
    echo "PARSED_VERDICT: $(cat "$vf")"
    ;;

  status)
    OUT="${1:?workdir}"
    sj="$OUT/state.jsonl"
    [ -s "$sj" ] || { echo "cc status: 无 state.jsonl(尚未发生 call)于 $OUT"; exit 0; }
    if [ -n "$PY" ]; then
      "$PY" - "$sj" <<'PYEOF'
import sys,json
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
print(f"# cc run status — {len(rows)} 次调用")
bad=[r for r in rows if r["verdict"] in ("UNKNOWN","BLOCKED") or r["exit"]!=0]
for r in rows:
    flag="⚠️ " if (r["verdict"] in ("UNKNOWN","BLOCKED") or r["exit"]!=0) else "✓ "
    print(f'{flag}{r["role"]:<22} {r["cli"]:<8} exit={r["exit"]} verdict={r["verdict"]:<13} {r["bytes"]}B')
if bad:
    print(f"\n下一步:有 {len(bad)} 个异常调用(UNKNOWN/BLOCKED/非零退出),需重跑或人工裁定,绝不当通过。")
else:
    print("\n下一步:所有调用有有效 verdict;按 SKILL 步骤推进闸门判定。")
PYEOF
    else
      echo "(无 python3,原始 state.jsonl):"; cat "$sj"
    fi
    ;;

  slug)
    raw="${1:-}"
    if [ -n "$PY" ]; then
      "$PY" - "$raw" <<'PYEOF'
import sys,re
t=(sys.argv[1] if len(sys.argv)>1 else "").strip()
try:
    from pypinyin import lazy_pinyin
    if re.search('[一-鿿]',t): t=' '.join(lazy_pinyin(t))
except Exception: pass
print(re.sub(r'[^0-9A-Za-z._-]+','-',t).strip('-')[:24].strip('-') or 'task')
PYEOF
    else
      printf '%s' "$raw" | tr -c 'A-Za-z0-9._-' '-' | sed 's/-\{2,\}/-/g;s/^-//;s/-$//' | cut -c1-24 | grep . || echo task
    fi
    ;;

  *) die "unknown subcommand: $cmd (probe|call|status|slug)";;
esac
