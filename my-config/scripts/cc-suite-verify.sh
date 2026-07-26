#!/usr/bin/env bash
# cc-suite-verify.sh — cc-suite 接入体系的验收脚本
#
# 设计原则:**假通过比不检查更糟**。所以:
#   - 反向计费通路存在且无显式 opt-in 标记 = FAIL,不是 WARN
#   - 桥接不完整(缺 AGENTS.md / CLAUDE.md 没退化 / 软链断 / hooks·MCP 没镜像) = FAIL
#   - TOML 一律用 tomllib 解析判定,不用正则(缩进 / 单引号键 / CRLF 都是合法写法)
#   - 软链验证比对规范化后的真实目标,不做子串匹配(子串可伪造)
#   - grep 前先确认是普通文件(FIFO 会挂,目录会让错误落进「干净」分支)
#   - 闸门自测在隔离 fixture 里做且带超时,绝不真的从 $HOME 跑 bridge
#
# 用法: bash ~/.claude/scripts/cc-suite-verify.sh [--quiet]
#       在某个项目根跑时会额外深检该项目。

set -uo pipefail

QUIET=0
for a in "$@"; do
  case "$a" in
    --quiet|-q) QUIET=1 ;;
    --help|-h)  sed -n '/^# 用法:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf '✗ 未知参数: %s(可用 --quiet / --help)\n' "$a" >&2; exit 2 ;;
  esac
done

PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS+1)); if [ "$QUIET" -eq 0 ]; then printf '✓ %s\n' "$*"; fi; }
bad()  { FAIL=$((FAIL+1)); printf '✗ %s\n' "$*"; }
warn() { WARN=$((WARN+1)); if [ "$QUIET" -eq 0 ]; then printf '⚠ %s\n' "$*"; fi; }
sec()  { if [ "$QUIET" -eq 0 ]; then printf '\n— %s —\n' "$*"; fi; }
note() { if [ "$QUIET" -eq 0 ]; then printf '· %s\n' "$*"; fi; }

CACHE_ROOT="$HOME/.claude/plugins/cache/xiaolai/cc-suite"
BR="$HOME/.claude/scripts/cc-suite-bridge.sh"
MARKER=".cc-suite-reverse-opt-in"
MIN="0.11.1"

# 只在普通文件上 grep:FIFO 会阻塞,目录会让 grep 的错误被当成「没匹配到」。
grep_file() {  # $1=pattern $2=file  → 0 命中 / 1 未命中 / 2 不可用
  [ -f "$2" ] || return 2
  [ -r "$2" ] || return 2
  grep -qE "$1" "$2" 2>/dev/null
}

# tomllib 判定某 TOML 是否注册了 mcp_servers.<name>
# 输出 yes / no / unparsable / missing
toml_has_server() {
  local f="$1" name="$2"
  if [ -e "$f" ] && [ ! -f "$f" ]; then echo notafile; return; fi
  [ -f "$f" ] || { echo missing; return; }
  python3 - "$f" "$name" <<'PY' 2>/dev/null || echo unparsable
import sys, tomllib
try:
    d = tomllib.load(open(sys.argv[1], "rb"))
except Exception:
    print("unparsable"); sys.exit(0)
print("yes" if sys.argv[2] in d.get("mcp_servers", {}) else "no")
PY
}

json_has_server() {  # $1=file $2=name → yes/no/unparsable/missing/notafile
  local f="$1" name="$2"
  if [ -e "$f" ] && [ ! -f "$f" ]; then echo notafile; return; fi
  [ -f "$f" ] || { echo missing; return; }
  python3 - "$f" "$name" <<'PY' 2>/dev/null || echo unparsable
import sys, json
raw = open(sys.argv[1]).read()
if not raw.strip():          # 空文件 = 没有任何 server,不是「解析失败」
    print("no"); sys.exit(0)
try:
    d = json.loads(raw)
except Exception:
    print("unparsable"); sys.exit(0)
print("yes" if sys.argv[2] in (d.get("mcpServers") or {}) else "no")
PY
}

# 带超时执行:闸门若因回归卡住,verify 不能无限等
# 注意:必须杀「进程组」。裸 alarm 只跟随被 exec 的直接进程,
# 它的子进程仍会持有 stdout,让上游 pipeline 继续等待。
run_bounded() {
  local secs="$1"; shift
  if command -v perl >/dev/null 2>&1; then
    perl -e '
      my $t = shift @ARGV;
      my $pid = fork();
      if (!defined $pid) { exec @ARGV; exit 127 }
      if ($pid == 0) { setpgrp(0, 0); exec @ARGV; exit 127 }
      $SIG{ALRM} = sub {
        kill("-TERM", $pid); sleep 1; kill("-KILL", $pid); exit 124;
      };
      alarm $t;
      waitpid($pid, 0);
      my $rc = $? >> 8;
      alarm 0;
      exit $rc;
    ' "$secs" "$@"
  else
    "$@"
  fi
}

# 递归快照(名字 + 大小),用于「零写入」断言;只比顶层名字会漏掉已有目录内部的改动
snap() {
  ( cd "$1" 2>/dev/null || return 0
    find . -mindepth 1 2>/dev/null | LC_ALL=C sort | while IFS= read -r p; do
      if [ -L "$p" ]; then printf '%s|L:%s\n' "$p" "$(readlink "$p")"
      elif [ -f "$p" ]; then printf '%s|F:%s\n' "$p" "$(shasum "$p" 2>/dev/null | cut -d" " -f1)"
      elif [ -d "$p" ]; then printf '%s|D\n' "$p"
      else printf '%s|O\n' "$p"; fi
    done )
}

# ---------------------------------------------------------------- 1. 插件
sec "1. 插件安装"
CUR=""
for d in "$CACHE_ROOT"/*/; do
  [ -d "$d" ] || continue
  if [ -L "${d%/}" ]; then continue; fi
  [ -f "${d}scripts/init.sh" ] || continue
  b="$(basename "${d%/}")"
  # 与 bridge 同一判据:严格点分数字。`.1` `1.` `1..2` 这类串也能通过
  # 「只含数字和点」的粗筛,却会让 sort -V 给出无意义结果
  printf '%s' "$b" | grep -qE '^[0-9]+(\.[0-9]+)+$' || continue
  if [ -z "$CUR" ]; then CUR="$b"; else
    CUR="$(printf '%s\n%s\n' "$CUR" "$b" | sort -V | tail -1)"
  fi
done
if [ -z "$CUR" ]; then
  bad "找不到 cc-suite 稳定版插件目录 ($CACHE_ROOT)"
  N=""
else
  N="$CACHE_ROOT/$CUR"
  if [ "$(printf '%s\n%s\n' "$MIN" "$CUR" | sort -V | head -1)" = "$MIN" ]; then
    ok "cc-suite $CUR (≥ $MIN)"
  else
    bad "cc-suite $CUR 低于要求的 $MIN — claude plugin update cc-suite@xiaolai --scope project"
  fi
fi

SET="$HOME/.claude/settings.json"
if [ -f "$SET" ]; then
  # 用 JSON 解析而不是 grep 字面量:settings.json 重排格式后 grep 会假失败
  if python3 -c "
import json,sys
sys.exit(0 if json.load(open('$SET')).get('enabledPlugins',{}).get('cc-suite@xiaolai') is True else 1)" 2>/dev/null; then
    ok "settings.json 中已启用"
  else
    bad "settings.json 中未启用 cc-suite@xiaolai"
  fi
else
  bad "找不到 $SET"
fi

# ---------------------------------------------------------------- 2. 后端
sec "2. 委派后端"
if [ -n "$N" ] && command -v codex >/dev/null 2>&1; then
  CJ="$(run_bounded 120 bash "$N/scripts/codex-preflight.sh" 2>/dev/null | tail -1)"
  if printf '%s' "$CJ" | grep -q '"status":"ok"'; then
    ok "codex 就绪,默认模型 $(printf '%s' "$CJ" | sed -n 's/.*"default_model":"\([^"]*\)".*/\1/p')"
  else
    bad "codex preflight 未 ok"
  fi
else
  bad "codex 不在 PATH 或插件缺失"
fi

AGY_CLAUDE_MCP="unknown"
if [ -n "$N" ] && command -v agy >/dev/null 2>&1; then
  AJ="$(run_bounded 120 bash "$N/scripts/agy-preflight.sh" 2>/dev/null | tail -1)"
  if printf '%s' "$AJ" | grep -q '"status":"ok"'; then
    ok "agy 就绪,默认模型 $(printf '%s' "$AJ" | sed -n 's/.*"default_model":"\([^"]*\)".*/\1/p')"
  else
    warn "agy preflight 未 ok(可能需要裸跑一次 agy 登录)"
  fi
  if printf '%s' "$AJ" | grep -q '"claude_mcp_registered":true'; then AGY_CLAUDE_MCP=true
  elif printf '%s' "$AJ" | grep -q '"claude_mcp_registered":false'; then AGY_CLAUDE_MCP=false
  fi
else
  warn "agy 不在 PATH(Google 那条腿不可用)"
fi

if command -v grok >/dev/null 2>&1; then
  warn "检测到 grok — 本体系未采纳该通路"
else
  ok "grok 未安装(符合预期)"
fi

# ---------------------------------------------------------------- 3. 接入层
sec "3. 接入层"
# 必须自己初始化:绝不能让继承来的 TMPD 走到下面的 rm -rf
TMPD=""
if [ -f "$BR" ]; then
  if bash -n "$BR" 2>/dev/null; then ok "cc-suite-bridge.sh 语法正常"; else bad "cc-suite-bridge.sh 语法错误"; fi

  # 闸门自测在隔离 fixture 里做。绝不从真 $HOME 跑 bridge——
  # 那等于用「可能造成损害的动作」去测「防止损害的机制」。
  TMPD="$(mktemp -d 2>/dev/null)" || TMPD=""
  case "$TMPD" in
    /|"") bad "mktemp -d 失败 — 跳过闸门自测(绝不退化成在真实目录里测)"; TMPD="" ;;
  esac
fi
if [ -n "${TMPD:-}" ]; then
  trap 'rm -rf "$TMPD"' EXIT
  trap 'rm -rf "$TMPD"; exit 130' INT
  trap 'rm -rf "$TMPD"; exit 143' TERM

  # (a) 非 git 目录:拒绝 + 退出码 2 + 零写入
  B1="$(snap "$TMPD")"
  OUT_A="$(cd "$TMPD" && run_bounded 30 bash "$BR" 2>&1)"; RC_A=$?
  A1="$(snap "$TMPD")"
  if [ "$RC_A" -eq 2 ] && printf '%s' "$OUT_A" | grep -q "不是 git 仓库" && [ "$B1" = "$A1" ]; then
    ok "闸门(a) 非 git 目录:拒绝 + 退出码 2 + 零写入"
  else
    bad "闸门(a) 失效 — rc=$RC_A(期望 2),文件树变化=$([ "$B1" = "$A1" ] && echo 无 || echo 有)"
  fi

  # (b) 仓库根 == $HOME(用假 HOME 触发真分支)
  FH="$TMPD/fakehome"; mkdir -p "$FH"; (cd "$FH" && git init -q 2>/dev/null)
  B2="$(snap "$FH")"
  OUT_B="$(cd "$FH" && CC_SUITE_CACHE_ROOT="$CACHE_ROOT" HOME="$FH" run_bounded 30 bash "$BR" 2>&1)"; RC_B=$?
  A2="$(snap "$FH")"
  if [ "$RC_B" -eq 2 ] && printf '%s' "$OUT_B" | grep -q 'HOME' && [ "$B2" = "$A2" ]; then
    ok "闸门(b) 仓库根==\$HOME:拒绝 + 退出码 2 + 零写入"
  else
    bad "闸门(b) 失效 — rc=$RC_B(期望 2),文件树变化=$([ "$B2" = "$A2" ] && echo 无 || echo 有)"
  fi

  # (c) GIT_DIR 污染
  OUT_C="$(cd "$TMPD" && GIT_DIR="$TMPD/nope" run_bounded 30 bash "$BR" 2>&1)"; RC_C=$?
  if [ "$RC_C" -eq 2 ] && printf '%s' "$OUT_C" | grep -q "GIT_DIR"; then
    ok "闸门(c) GIT_DIR/GIT_WORK_TREE 污染:拒绝"
  else
    bad "闸门(c) 失效 — rc=$RC_C(期望 2)"
  fi

  # (d) 未知参数不得静默降级成默认桥接
  OUT_D="$(cd "$TMPD" && run_bounded 30 bash "$BR" --privte 2>&1)"; RC_D=$?
  if [ "$RC_D" -eq 2 ] && printf '%s' "$OUT_D" | grep -q "未知参数"; then
    ok "闸门(d) 拼错的参数:报错而非按默认桥接"
  else
    bad "闸门(d) 失效 — rc=$RC_D(期望 2)"
  fi

  # 再确认一次:只删我们自己 mktemp 出来的那个目录
  case "$TMPD" in
    /var/folders/*|/tmp/*|/private/var/folders/*|/private/tmp/*)
      if ! rm -rf "$TMPD" 2>/dev/null; then
        warn "临时目录未能删除,可能泄漏: $TMPD"
      fi ;;
    *)
      warn "临时目录路径不像 mktemp 产物,拒绝删除: $TMPD" ;;
  esac
  trap - EXIT INT TERM
fi
if [ ! -f "$BR" ]; then
  bad "缺少 $BR"
fi

if [ -f "$HOME/.claude/rules/cc-suite.md" ]; then ok "规则文件 rules/cc-suite.md 存在"; else bad "缺少 rules/cc-suite.md"; fi
if grep_file "rules/cc-suite\.md" "$HOME/.claude/CLAUDE.md"; then
  ok "CLAUDE.md 已挂载规则指针"
else
  bad "CLAUDE.md 未挂载 rules/cc-suite.md 指针"
fi

# ---------------------------------------------------------------- 4. 全局未污染
sec "4. 全局配置未被污染"
GC="$HOME/.codex/config.toml"
case "$(toml_has_server "$GC" claude-code)" in
  yes)        bad "全局 ~/.codex/config.toml 注册了 claude-code 反向委派(计费通路)" ;;
  unparsable) bad "全局 ~/.codex/config.toml 无法解析 — 无法判断是否被污染,手工检查" ;;
  missing)    warn "$GC 不存在(Codex 尚未配置?)" ;;
  notafile)   bad "$GC 存在但不是普通文件 — 无法判定是否被污染" ;;
  no)
    if grep_file "cc-suite" "$GC"; then
      bad "全局 ~/.codex/config.toml 出现 cc-suite 标记 — 说明在 \$HOME 跑过 init,需回滚"
    else
      ok "全局 ~/.codex/config.toml 干净"
    fi ;;
esac

if [ -e "$HOME/AGENTS.md" ]; then bad "\$HOME/AGENTS.md 存在 — 疑似在 home 桥接过"; else ok "无 \$HOME/AGENTS.md"; fi
if [ -L "$HOME/.claude/skills/cc-suite" ]; then bad "全局 .claude/skills/cc-suite 软链存在 — 会把 cc-suite skill 灌进每个会话"; else ok "全局 skills 未被注入"; fi

# 全局 agy 反向通路:项目级剥离对它无效,必须单独查
GA="$HOME/.gemini/config/mcp_config.json"
case "$(json_has_server "$GA" claude-code)" in
  yes)        bad "全局 agy ($GA) 注册了 claude-code 反向委派 — 项目级剥离管不到,手工删除" ;;
  unparsable) bad "全局 agy 配置无法解析 ($GA) — 手工检查" ;;
  notafile)   bad "$GA 存在但不是普通文件 — 无法判定,手工检查" ;;
  no|missing) ok "全局 agy MCP 配置无反向通路" ;;
esac
if [ "$AGY_CLAUDE_MCP" = true ]; then
  bad "agy preflight 报 claude_mcp_registered=true — 反向通路在 agy 侧仍开着"
elif [ "$AGY_CLAUDE_MCP" = false ]; then
  ok "agy preflight 报 claude_mcp_registered=false"
fi

# ---------------------------------------------------------------- 5. 项目深检
sec "5. 已桥接项目健康度"

check_project() {
  local proj="$1" name link tgt sz expected
  name="$(basename "$proj")"
  link="$proj/.claude/skills/cc-suite"
  expected="$([ -n "$N" ] && cd "$N/skills/cc-suite" 2>/dev/null && pwd -P || true)"

  # a) 软链必须真的指向当前插件的 skill 目录(子串匹配可伪造)
  if [ -d "$link" ]; then
    tgt="$(cd "$link" 2>/dev/null && pwd -P || true)"
    if [ -n "$expected" ] && [ "$tgt" = "$expected" ]; then
      ok "$name: skills 软链 → 当前版本 $CUR"
    else
      bad "$name: skills 软链指向 ${tgt:-?}(期望 ${expected:-?})— cd '$proj' && bash $BR relink"
    fi
  else
    bad "$name: skills 软链缺失或悬空 — cd '$proj' && bash $BR relink"
  fi

  # b) 单源约定:AGENTS.md 在 + CLAUDE.md 已退化成纯 import
  if [ -f "$proj/AGENTS.md" ]; then
    sz=$(wc -c < "$proj/AGENTS.md" | tr -d ' ')
    if [ "$sz" -gt 32768 ]; then
      bad "$name: AGENTS.md ${sz}B 超过 Codex 32KiB 静默截断线"
    else
      ok "$name: AGENTS.md ${sz}B 在 32KiB 内"
    fi
  else
    bad "$name: 缺少 AGENTS.md — 桥接不完整"
  fi
  if [ -f "$proj/CLAUDE.md" ]; then
    if [ "$(tr -d '[:space:]' < "$proj/CLAUDE.md")" = "@AGENTS.md" ]; then
      ok "$name: CLAUDE.md 已退化为 @AGENTS.md"
    else
      bad "$name: CLAUDE.md 不是纯 @AGENTS.md import — 双源漂移风险"
    fi
  else
    bad "$name: 缺少 CLAUDE.md"
  fi

  # c) Codex/agy 的 skill 扫描路径必须是软链且解析到 .claude/skills
  local as="$proj/.agents/skills" as_t cs_t
  if [ -L "$as" ] && [ -d "$as" ]; then
    as_t="$(cd "$as" && pwd -P)"; cs_t="$(cd "$proj/.claude/skills" 2>/dev/null && pwd -P || true)"
    if [ -n "$cs_t" ] && [ "$as_t" = "$cs_t" ]; then
      ok "$name: .agents/skills → .claude/skills"
    else
      bad "$name: .agents/skills 解析到 $as_t,不是 .claude/skills"
    fi
  else
    bad "$name: .agents/skills 不是可用软链 — Codex/agy 看不到 skill"
  fi

  # d) hooks 镜像:Claude 侧有 hooks 就必须有 Codex 侧
  local cs="$proj/.claude/settings.json" ch="$proj/.codex/hooks.json" hres
  if [ -e "$cs" ]; then
    hres="$(python3 - "$cs" "$ch" <<'PY' 2>/dev/null || echo "ERR internal"
import json, sys, os
SHARED = {"PreToolUse", "PostToolUse", "Stop", "SessionStart", "UserPromptSubmit"}
try:
    src = json.load(open(sys.argv[1])).get("hooks") or {}
except Exception as e:
    print(f"ERR Claude 侧 settings.json 无法解析: {e}"); sys.exit(0)
want = SHARED & set(src)
if not want:
    print("NONE"); sys.exit(0)
if not os.path.isfile(sys.argv[2]):
    print("MISSING"); sys.exit(0)
try:
    dst = json.load(open(sys.argv[2])).get("hooks") or {}
except Exception as e:
    print(f"ERR Codex 侧 hooks.json 无法解析: {e}"); sys.exit(0)
# 只要求事件层面对齐:少一个事件就是没镜像全({} 之类空壳会在这里被抓住)
missing = sorted(want - set(k for k, v in dst.items() if v))
print("MISSING_EVENTS " + " ".join(missing) if missing else "OK")
PY
)"
    case "$hres" in
      OK)             ok "$name: hooks 事件已镜像到 .codex/hooks.json" ;;
      NONE)           : ;;
      MISSING)        bad "$name: 有共享 hooks 但 .codex/hooks.json 缺失" ;;
      MISSING_EVENTS*) bad "$name: hooks 未镜像全,缺: ${hres#MISSING_EVENTS }" ;;
      ERR*)           bad "$name: hooks parity 无法判定 — ${hres#ERR }" ;;
    esac
  fi

  # e) MCP parity:.mcp.json 的 server(除 codex-cli 自身)必须出现在 Codex 侧
  local mj="$proj/.mcp.json"
  if [ -f "$mj" ]; then
    local missing
    missing="$(python3 - "$mj" "$proj/.codex/config.toml" "$proj/.agents/mcp_config.json" <<'PY' 2>/dev/null || echo "ERR internal"
import sys, json, tomllib, os
try:
    src = json.load(open(sys.argv[1])).get("mcpServers") or {}
    if not isinstance(src, dict):
        raise ValueError("mcpServers 不是对象")
except Exception as e:
    # source 坏了就是「判不了」,绝不能报告 parity 一致
    print(f"ERR .mcp.json 无法解析: {e}"); sys.exit(0)
try:
    cdx = tomllib.load(open(sys.argv[2], "rb")).get("mcp_servers", {})
except Exception as e:
    print(f"ERR .codex/config.toml 无法解析: {e}"); sys.exit(0)
gaps = [f"codex:{k}" for k in sorted(src) if k != "codex-cli" and k not in cdx]
agy_path = sys.argv[3]
if os.path.exists(agy_path) and not os.path.isfile(agy_path):
    print("ERR .agents/mcp_config.json 不是普通文件"); sys.exit(0)
if not os.path.exists(agy_path):
    # 缺 artifact 不能报「一致」——桥接就是要生成它
    print("ERR .agents/mcp_config.json 缺失(agy 侧未镜像)"); sys.exit(0)
try:
    agy = json.load(open(agy_path)).get("mcpServers") or {}
except Exception as e:
    print(f"ERR .agents/mcp_config.json 无法解析: {e}"); sys.exit(0)
gaps += [f"agy:{k}" for k in sorted(src) if k not in agy]
print(" ".join(gaps))
PY
)"
    case "$missing" in
      ERR*) bad "$name: MCP parity 无法判定 — ${missing#ERR }" ;;
      "")   ok "$name: MCP parity 一致(Codex + agy)" ;;
      *)    bad "$name: MCP 未镜像: $missing — 重跑 bash $BR" ;;
    esac
  fi

  # f) 反向计费通路:无显式 opt-in 标记就是 FAIL
  local rev=0 rev_unknown=0
  case "$(json_has_server "$proj/.agents/mcp_config.json" claude-code)" in
    yes) rev=1 ;;
    unparsable) rev_unknown=1; bad "$name: .agents/mcp_config.json 无法解析 — 反向通路无法判定" ;;
    notafile)   rev_unknown=1; bad "$name: .agents/mcp_config.json 不是普通文件 — 反向通路无法判定" ;;
  esac
  case "$(toml_has_server "$proj/.codex/config.toml" claude-code)" in
    yes) rev=1 ;;
    unparsable) rev_unknown=1; bad "$name: .codex/config.toml 无法解析 — 反向通路无法判定" ;;
    notafile)   rev_unknown=1; bad "$name: .codex/config.toml 不是普通文件 — 反向通路无法判定" ;;
  esac
  if [ "$rev_unknown" -eq 1 ] && [ "$rev" -eq 0 ]; then
    :   # 判不了就别下结论——已经 bad 过了,不能再打印「无反向通路」
  elif [ "$rev" -eq 1 ]; then
    if [ -f "$proj/$MARKER" ]; then
      warn "$name: 反向委派已开(有 $MARKER,视为你显式接受计费)"
    else
      bad "$name: 反向委派开着但没有 $MARKER 标记 — 意外开启的计费通路,跑 bash $BR 重新桥接"
    fi
  else
    ok "$name: 无反向计费通路"
  fi
}

FOUND=0
CWD_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$CWD_ROOT" ]; then
  CWD_ROOT="$(cd "$CWD_ROOT" && pwd -P)"
  if [ "$CWD_ROOT" = "$(cd "$HOME" && pwd -P)" ]; then
    CWD_ROOT=""
  else
    # 桥接痕迹:任一出现就说明这个仓库被桥过,必须深检。
    # 只认 skill link / AGENTS.md 的话,「桥过但产物被删剩一半」会伪装成「从没桥过」。
    EV=0
    for m in ".claude/skills/cc-suite" "AGENTS.md" ".agents" ".codex/config.toml" ".cc-suite.md" "$MARKER"; do
      [ -e "$CWD_ROOT/$m" ] && EV=$((EV+1))
    done
    grep_file '>>> cc-suite >>>' "$CWD_ROOT/.gitignore" && EV=$((EV+1))
    if [ "$EV" -gt 0 ]; then
      FOUND=1
      note "当前项目: $CWD_ROOT(检出 $EV 处桥接痕迹)"
      check_project "$CWD_ROOT"
    else
      note "当前项目 $CWD_ROOT 无任何桥接痕迹 —— 跳过深检(这不是错误)"
    fi
  fi
fi

if [ -d "$HOME/Desktop" ]; then
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    proj="$(cd "$(dirname "$link")/../.." 2>/dev/null && pwd -P)" || continue
    [ "$proj" = "$CWD_ROOT" ] && continue
    FOUND=$((FOUND+1))
    check_project "$proj"
  done < <(find "$HOME/Desktop" -maxdepth 6 -path "*/.claude/skills/cc-suite" 2>/dev/null)
else
  warn "$HOME/Desktop 不存在 — 跳过工作区扫描"
fi

if [ "$FOUND" -eq 0 ]; then
  note "尚无已桥接项目(正常,按需桥接)。注意:扫描只覆盖 ~/Desktop 6 层内,"
  note "其他位置的项目请 cd 进去再跑一次本脚本做深检。"
fi

# ---------------------------------------------------------------- 汇总
printf '\n══ 通过 %d / 失败 %d / 警告 %d ══\n' "$PASS" "$FAIL" "$WARN"
if [ "$FAIL" -eq 0 ]; then printf '全部通过。\n'; exit 0; else printf '存在失败项,见上方 ✗。\n'; exit 1; fi
