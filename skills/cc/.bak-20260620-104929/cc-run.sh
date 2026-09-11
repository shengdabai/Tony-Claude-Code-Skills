#!/usr/bin/env bash
# cc-run.sh — cc 多模型流水线的统一调用 wrapper。
# 解决 SKILL 评审发现的 Critical:全量日志(不截断)、捕获 exit code、
# VERDICT 机器解析、任何异常(空输出/超时/非零退出/拒答/解析失败)一律 UNKNOWN(≠通过)、
# prompt 一律走文件(杜绝引号/反引号/$() 注入破命令)。
#
# 用法:
#   cc-run.sh probe <workdir>
#       探测 codex/gpt5pro/agy 可用性,写 <workdir>/capabilities.md。未通过的模型不得算有效审查方。
#   cc-run.sh call <role> <cli> <promptfile> <outdir> [sandbox]
#       cli ∈ codex|gpt5pro|agy ; sandbox ∈ read-only(默认)|workspace-write(仅 codex)
#       产出:<outdir>/<role>.full.log(全量) <role>.exit <role>.verdict
#       stdout 末行打印 "PARSED_VERDICT: X" 供编排读取。X ∈ CONSENSUS|REVISE|APPROVED|ISSUES_FOUND|UNKNOWN
set -uo pipefail

CODEX_BIN="${CODEX_BIN:-$HOME/.nvm/versions/node/v24.14.0/bin/codex}"
GPT5PRO_BIN="${GPT5PRO_BIN:-$HOME/.local/bin/gpt5pro}"
AGY_BIN="${AGY_BIN:-$HOME/.local/bin/agy}"
CODEX_MODEL="${CODEX_MODEL:-gpt-5.5}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-3-pro-high}"
CALL_TIMEOUT="${CALL_TIMEOUT:-600}"   # 单次调用墙钟上限(秒)

die() { echo "cc-run: $*" >&2; exit 64; }

# 跨平台 timeout(macOS 默认无 GNU timeout 时退化为后台+kill)
run_to() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return $?; fi
  "$@" & local pid=$!
  ( sleep "$secs"; kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null ) & local wd=$!
  wait "$pid" 2>/dev/null; local rc=$?; kill -9 "$wd" 2>/dev/null; return $rc
}

# 从全量日志里提取最后一个合法 VERDICT(容忍 CLI 尾部 chrome 行)
parse_verdict() {
  local log="$1"
  [ -s "$log" ] || { echo UNKNOWN; return; }
  local v
  v="$(grep -oE 'VERDICT: (CONSENSUS|REVISE|APPROVED|ISSUES_FOUND)' "$log" 2>/dev/null | tail -1 | awk '{print $2}')"
  [ -n "$v" ] && echo "$v" || echo UNKNOWN
}

cmd="${1:-}"; shift 2>/dev/null || die "missing subcommand (probe|call)"

case "$cmd" in
  probe)
    OUT="${1:?workdir}"; mkdir -p "$OUT"
    cap="$OUT/capabilities.md"
    { echo "# cc capabilities probe"; echo "_探测时间见文件 mtime_"; echo; } > "$cap"
    # codex
    if [ -x "$CODEX_BIN" ]; then
      if run_to 120 "$CODEX_BIN" exec "reply with exactly one line: VERDICT: APPROVED" \
           --skip-git-repo-check -m "$CODEX_MODEL" -s read-only </dev/null >"$OUT/probe-codex.log" 2>&1 \
         && grep -q 'VERDICT: APPROVED' "$OUT/probe-codex.log"; then
        echo "- **codex**: OK ($CODEX_BIN, $CODEX_MODEL)" >> "$cap"
      else echo "- **codex**: UNAVAILABLE → 见 probe-codex.log(不得算有效审查方)" >> "$cap"; fi
    else echo "- **codex**: NOT FOUND at $CODEX_BIN" >> "$cap"; fi
    # gpt5pro
    if [ -x "$GPT5PRO_BIN" ] || command -v gpt5pro >/dev/null 2>&1; then
      echo "- **gpt5pro**: PRESENT(网页桶,实际可用性看首次调用是否 session=no)" >> "$cap"
    else echo "- **gpt5pro**: NOT FOUND" >> "$cap"; fi
    # agy / gemini
    if [ -x "$AGY_BIN" ] || command -v agy >/dev/null 2>&1; then
      local_agy="$(command -v agy 2>/dev/null || echo "$AGY_BIN")"
      if run_to 90 "$local_agy" -p "reply with exactly one line: VERDICT: APPROVED" \
           --model "$GEMINI_MODEL" --print-timeout 60s </dev/null >"$OUT/probe-agy.log" 2>&1 \
         && grep -q 'VERDICT: APPROVED' "$OUT/probe-agy.log"; then
        echo "- **agy/gemini**: OK ($GEMINI_MODEL)" >> "$cap"
      else echo "- **agy/gemini**: UNAVAILABLE(多半 token 过期,需裸跑 \`agy\` 登录)→ 见 probe-agy.log" >> "$cap"; fi
    else echo "- **agy/gemini**: NOT FOUND" >> "$cap"; fi
    cat "$cap"
    ;;

  call)
    role="${1:?role}"; cli="${2:?cli}"; pf="${3:?promptfile}"; out="${4:?outdir}"; sandbox="${5:-read-only}"
    [ -s "$pf" ] || die "prompt file empty/missing: $pf"
    mkdir -p "$out"
    full="$out/${role}.full.log"; exitf="$out/${role}.exit"; vf="$out/${role}.verdict"
    rc=0
    case "$cli" in
      codex)
        run_to "$CALL_TIMEOUT" "$CODEX_BIN" exec "$(cat "$pf")" \
          --skip-git-repo-check -m "$CODEX_MODEL" -s "$sandbox" </dev/null >"$full" 2>&1 || rc=$?
        ;;
      gpt5pro)
        run_to "$CALL_TIMEOUT" "${GPT5PRO_BIN}" "$(cat "$pf")" </dev/null >"$full" 2>&1 || rc=$?
        ;;
      agy)
        agybin="$(command -v agy 2>/dev/null || echo "$AGY_BIN")"
        run_to "$CALL_TIMEOUT" "$agybin" -p "$(cat "$pf")" \
          --model "$GEMINI_MODEL" --print-timeout 8m </dev/null >"$full" 2>&1 || rc=$?
        ;;
      *) die "unknown cli: $cli (codex|gpt5pro|agy)";;
    esac
    echo "$rc" > "$exitf"
    if [ "$rc" -ne 0 ] || [ ! -s "$full" ]; then
      echo "UNKNOWN" > "$vf"
    else
      parse_verdict "$full" > "$vf"
    fi
    echo "PARSED_VERDICT: $(cat "$vf")"
    ;;

  *) die "unknown subcommand: $cmd (probe|call)";;
esac
