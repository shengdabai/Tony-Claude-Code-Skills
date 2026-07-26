#!/usr/bin/env bash
# cc-suite-selftest.sh — cc-suite 接入层的回归测试(fixture 驱动)
#
# 为什么需要:cc-suite-bridge.sh 的价值全在「拦住不该发生的事」,
# 而这类代码一旦回归是静默的——桥接照样成功,只是护栏没了。
# 所以每次改 bridge/verify 脚本、或 cc-suite 升级后,跑一次本脚本。
#
# 边界(准确说法):所有**写操作**只发生在 mktemp 目录里,不改任何真实项目。
# 但它会调用真实的 verify,而 verify 会读真实的 ~/.codex、~/.gemini、~/Desktop,
# 并执行真实的 codex/agy preflight(那会读账号状态、可能写 codex 自己的缓存)。
# 所以它不是完全 hermetic 的——只是不会写坏你的东西。
# 用法: bash ~/.claude/scripts/cc-suite-selftest.sh

set -uo pipefail

BR="$HOME/.claude/scripts/cc-suite-bridge.sh"
VF="$HOME/.claude/scripts/cc-suite-verify.sh"
CACHE_ROOT="$HOME/.claude/plugins/cache/xiaolai/cc-suite"
MARKER=".cc-suite-reverse-opt-in"

T=""
cleanup() { [ -n "${T:-}" ] && [ -d "$T" ] && rm -rf "$T"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# mktemp 失败绝不能继续:$T 为空会让下面的 "$T/p1" 变成 "/p1",
# 而 mkfixture 第一步就是 rm -rf "$p" —— 那是往根目录动手。
T="$(mktemp -d 2>/dev/null)" || T=""
case "$T" in
  /|"") printf '✗ mktemp -d 失败或返回根路径,拒绝继续(否则会对 / 下路径动手)\n' >&2; exit 3 ;;
esac
[ -d "$T" ] || { printf '✗ 临时目录不存在: %s\n' "$T" >&2; exit 3; }

# 兜底:所有 fixture 路径必须落在 $T 之内
in_tmp() { case "$1" in "$T"/*) return 0 ;; *) printf '✗ 路径越界: %s\n' "$1" >&2; exit 3 ;; esac; }

PASS=0; FAIL=0
t_ok()   { PASS=$((PASS+1)); printf '  ✓ %s\n' "$*"; }
t_bad()  { FAIL=$((FAIL+1)); printf '  ✗ %s\n' "$*"; }
case_() { printf '\n[%s]\n' "$*"; }

# 判定 TOML / JSON 里是否注册了 claude-code
has_toml() { python3 -c "
import sys,tomllib
try: d=tomllib.load(open(sys.argv[1],'rb'))
except Exception: print('ERR'); sys.exit()
print('YES' if 'claude-code' in d.get('mcp_servers',{}) else 'NO')" "$1" 2>/dev/null || echo ERR; }
# 失败一律回 ERR,绝不把「判不了」伪装成「没有」
has_json() { python3 -c "
import sys,json,os
p=sys.argv[1]
if not os.path.isfile(p): print('MISSING'); sys.exit()
raw=open(p).read()
if not raw.strip(): print('NO'); sys.exit()
try: d=json.loads(raw)
except Exception: print('ERR'); sys.exit()
srv=d.get('mcpServers')
if not isinstance(srv,dict): print('ERR'); sys.exit()
print('YES' if 'claude-code' in srv else 'NO')" "$1" 2>/dev/null || echo ERR; }

# 断言 verify 输出里出现/不出现某条具体结论。
# 只看 verify 的总退出码是不可靠的:真实全局配置或其他 Desktop 项目的失败
# 也会让退出码变 1,测试就会「因为错误的原因通过」。
# 实现要点:不能写成 `bash verify | grep -q`。grep -q 命中即关闭管道,
# verify 拿到 SIGPIPE 退出 141,`set -o pipefail` 就把整条管道判成失败,
# 于是「明明匹配到了」也会返回 false。先落到变量,再用 here-string 匹配。
verify_says() {   # $1=项目目录 $2=期望匹配的正则
  local out
  out="$( cd "$1" && bash "$VF" 2>&1 )"
  grep -qE "$2" <<< "$out"
}

mkfixture() {   # $1 = 目录名 → 造一个像真项目的 git repo
  local p="$T/$1"
  in_tmp "$p"
  # mkdir / cd 失败必须立刻停:否则子 shell 里的 `> CLAUDE.md` `> .mcp.json`
  # 会落在「跑 selftest 的那个目录」,直接覆盖用户真实文件。
  rm -rf "$p" || { printf '✗ 无法清理 fixture: %s\n' "$p" >&2; exit 3; }
  mkdir -p "$p/.claude/skills/demo-skill" || { printf '✗ 无法创建 fixture: %s\n' "$p" >&2; exit 3; }
  [ -d "$p" ] || { printf '✗ fixture 目录不存在: %s\n' "$p" >&2; exit 3; }
  ( cd "$p" || exit 9
    git init -q; git config user.email t@t; git config user.name t
    printf '# Fixture\n\n中文内容测试。\n' > CLAUDE.md
    printf -- '---\nname: demo-skill\ndescription: fixture\n---\n\n# demo\n' > .claude/skills/demo-skill/SKILL.md
    printf '{\n "hooks": {\n  "PreToolUse": [{"matcher":"Bash","hooks":[{"type":"command","command":"echo pre"}]}],\n  "Stop": [{"hooks":[{"type":"command","command":"echo stop"}]}]\n }\n}\n' > .claude/settings.json
    printf '{"mcpServers":{"fixture-server":{"command":"node","args":["s.js"],"env":{"API_KEY":"MUST_NOT_LEAK"}}}}\n' > .mcp.json
    printf 'node_modules/\n' > .gitignore
    git add -A >/dev/null 2>&1; git commit -qm init >/dev/null 2>&1 ) || {
    printf '✗ fixture 初始化失败(cd 或 git 失败): %s\n' "$p" >&2; exit 3; }
  # 不能只靠子 shell 的退出码——最后那个 printf 会把整体状态洗成成功
  [ -f "$p/CLAUDE.md" ] && [ -d "$p/.git" ] || {
    printf '✗ fixture 内容不完整: %s\n' "$p" >&2; exit 3; }
  printf '%s' "$p"
}

# 关键:mkfixture 是在 command substitution 里跑的,它内部的 exit 只结束子 shell,
# 父脚本会拿到空路径继续执行 —— "$P/AGENTS.md" 就成了 "/AGENTS.md"。
# 所以所有 fixture 创建都必须走 mk():在父 shell 里判空、判边界、失败即整体退出。
mk() {   # $1 = fixture 名 → 打印路径;任何异常直接终止整个 selftest
  local out rc
  out="$(mkfixture "$1")"; rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
    printf '✗ fixture 创建失败(rc=%s, path=%s),终止测试\n' "$rc" "${out:-<空>}" >&2
    exit 3
  fi
  in_tmp "$out"
  printf '%s' "$out"
}

printf '== cc-suite 接入层回归测试 ==\n(临时目录: %s)\n' "$T"

# ---------------------------------------------------------------- 闸门
case_ "闸门:不该动手的场合必须拒绝"
in_tmp "$T/plain"; mkdir -p "$T/plain"
( cd "$T/plain" && bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] && t_ok "非 git 目录 → 退出码 2" || t_bad "非 git 目录 → 退出码 $rc(期望 2)"
[ -z "$(/bin/ls -A "$T/plain")" ] && t_ok "非 git 目录 → 零写入" || t_bad "非 git 目录 → 有文件被写入"

in_tmp "$T/fh"; mkdir -p "$T/fh" && ( cd "$T/fh" && git init -q )
( cd "$T/fh" && CC_SUITE_CACHE_ROOT="$CACHE_ROOT" HOME="$T/fh" bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] && t_ok "仓库根==\$HOME → 退出码 2" || t_bad "仓库根==\$HOME → 退出码 $rc(期望 2)"
[ ! -e "$T/fh/AGENTS.md" ] && t_ok "仓库根==\$HOME → 未写 AGENTS.md" || t_bad "仓库根==\$HOME → 竟然桥接了"

# $HOME 是 symlink 且带尾斜杠 —— 纯字符串比较会漏掉这种别名
in_tmp "$T/fh-alias"; ln -s "$T/fh" "$T/fh-alias"
( cd "$T/fh" && CC_SUITE_CACHE_ROOT="$CACHE_ROOT" HOME="$T/fh-alias/" bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] && t_ok "\$HOME 是 symlink + 尾斜杠 → 仍拒绝" || t_bad "\$HOME 别名绕过了闸门(rc=$rc)"

( cd "$T/plain" && GIT_DIR="$T/nope" bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] && t_ok "GIT_DIR 污染 → 拒绝" || t_bad "GIT_DIR 污染 → 退出码 $rc(期望 2)"

( cd "$T/plain" && bash "$BR" --privte >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] && t_ok "拼错参数 → 报错而非按默认桥接" || t_bad "拼错参数 → 退出码 $rc(期望 2)"

( bash "$BR" --help >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && t_ok "--help → 只打帮助不桥接" || t_bad "--help → 退出码 $rc"

# ---------------------------------------------------------------- 默认桥接
case_ "默认桥接:四条桥 + 反向通路默认关闭 + 密钥不外泄"
P="$(mk p1)" || exit $?
# fixture 自带的 .mcp.json 本来就含密钥且已 tracked。要问的是「桥接有没有把它
# 复制进新的 tracked 文件」,所以先记基线,桥接后比差集。
LEAK_BEFORE="$( cd "$P" && git ls-files -z | xargs -0 grep -l "MUST_NOT_LEAK" 2>/dev/null | LC_ALL=C sort )"
( cd "$P" && bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && t_ok "桥接退出码 0" || t_bad "桥接失败(rc=$rc)"
[ -f "$P/AGENTS.md" ] && t_ok "桥 1: AGENTS.md 生成" || t_bad "桥 1: 缺 AGENTS.md"
[ "$(tr -d '[:space:]' < "$P/CLAUDE.md")" = "@AGENTS.md" ] && t_ok "桥 1: CLAUDE.md 退化为 @AGENTS.md" || t_bad "桥 1: CLAUDE.md 未退化"
[ -d "$P/.agents/skills" ] && t_ok "桥 2: .agents/skills 可解析" || t_bad "桥 2: .agents/skills 断"
[ -f "$P/.codex/hooks.json" ] && t_ok "桥 3: hooks 已镜像" || t_bad "桥 3: hooks 未镜像"
[ "$(has_toml "$P/.codex/config.toml")" = NO ] && t_ok "桥 4: Codex 侧无反向通路" || t_bad "桥 4: Codex 侧有反向通路"
[ "$(has_json "$P/.agents/mcp_config.json")" = NO ] && t_ok "反向: agy 侧已剥离" || t_bad "反向: agy 侧仍在"
[ ! -f "$P/$MARKER" ] && t_ok "反向: 无 opt-in 标记" || t_bad "反向: 不该有标记"
# 首轮就该齐:codex-cli 要出现在 agy 配置里(原生顺序有坑,要跑两遍)
python3 -c "
import json,sys;d=json.load(open('$P/.agents/mcp_config.json'))
sys.exit(0 if 'codex-cli' in d['mcpServers'] else 1)" 2>/dev/null \
  && t_ok "顺序: 首轮 agy 已看到 codex-cli" || t_bad "顺序: 首轮 agy 没看到 codex-cli"
# 桥接不得把密钥复制进新的 git-tracked 文件
LEAK_AFTER="$( cd "$P" && git ls-files -z | xargs -0 grep -l "MUST_NOT_LEAK" 2>/dev/null | LC_ALL=C sort )"
NEW_LEAK="$( comm -13 <(printf '%s\n' "$LEAK_BEFORE") <(printf '%s\n' "$LEAK_AFTER") )"
[ -z "$NEW_LEAK" ] && t_ok "桥接未把密钥复制进新的 git-tracked 文件" || t_bad "密钥新泄漏到: $NEW_LEAK"
# agy 配置确实需要明文值才能工作,但必须被 gitignore 掉
if [ "$( cd "$P" && git check-ignore -q .agents/mcp_config.json && echo ignored )" = ignored ]; then
  t_ok ".agents/mcp_config.json 已被 gitignore(它含明文 env)"
else
  t_bad ".agents/mcp_config.json 未被 gitignore — 明文 env 有进版本库风险"
fi
if verify_says "$P" "^✗ .*$(basename "$P")"; then
  t_bad "verify 对本 fixture 报了失败项"
else
  t_ok "verify 对本 fixture 无失败项"
fi

# ---------------------------------------------------------------- --reverse
case_ "--reverse:两条反向通路 + 标记 + verify 降为 warning"
( cd "$P" && bash "$BR" --reverse >/dev/null 2>&1 )
[ "$(has_toml "$P/.codex/config.toml")" = YES ] && t_ok "Codex→Claude 已注册" || t_bad "Codex→Claude 未注册"
[ "$(has_json "$P/.agents/mcp_config.json")" = YES ] && t_ok "agy→Claude 已注册" || t_bad "agy→Claude 未注册"
[ -f "$P/$MARKER" ] && t_ok "opt-in 标记已写入" || t_bad "opt-in 标记缺失"
if verify_says "$P" "^⚠ .*反向委派已开"; then
  t_ok "有标记时 verify 降为 warning"
else
  t_bad "有标记时 verify 未按 warning 处理"
fi
if verify_says "$P" "^✗ .*反向委派开着但没有"; then
  t_bad "有标记时仍被判为意外开启"
else
  t_ok "有标记时未被误判为意外开启"
fi

# ---------------------------------------------------------------- sentinel 完整性
case_ "回归:strip 必须删 sentinel 整块,不能留孤立 sentinel"
( cd "$P" && bash "$BR" >/dev/null 2>&1 )
# grep -c 未命中时自己就打印 0 并返回 1;再 `|| echo 0` 会拼出 "0\n0" 把算术表达式弄坏
OPEN=$(grep -c '^# >>> cc-suite-claude-mcp >>>' "$P/.codex/config.toml" 2>/dev/null | head -1); OPEN=${OPEN:-0}
CLOSE=$(grep -c '^# <<< cc-suite-claude-mcp <<<' "$P/.codex/config.toml" 2>/dev/null | head -1); CLOSE=${CLOSE:-0}
[ "$OPEN" -eq 0 ] && [ "$CLOSE" -eq 0 ] && t_ok "sentinel 两端都被清掉(无孤立)" || t_bad "残留 sentinel: open=$OPEN close=$CLOSE"
[ "$(has_toml "$P/.codex/config.toml")" = NO ] && t_ok "反向通路确已关闭" || t_bad "反向通路仍开"
# 孤立 sentinel 会让下一次 mcp_claude.sh 把后续配置一起吞掉,所以再走一轮 --reverse 验证不丢内容
printf '\n[mcp_servers.canary]\ncommand = "echo"\n' >> "$P/.codex/config.toml"
( cd "$P" && bash "$BR" --reverse >/dev/null 2>&1 )
python3 -c "
import sys,tomllib;d=tomllib.load(open('$P/.codex/config.toml','rb'))
sys.exit(0 if 'canary' in d.get('mcp_servers',{}) else 1)" 2>/dev/null \
  && t_ok "再开 --reverse 未吞掉后续配置(canary 仍在)" || t_bad "后续配置被吞掉了(canary 丢失)"

# ---------------------------------------------------------------- 合法 TOML 变体
case_ "回归:合法 TOML 变体(缩进/单引号键)不能骗过检测"
P2="$(mk p2)" || exit $?
( cd "$P2" && bash "$BR" >/dev/null 2>&1 )
printf "\n  [mcp_servers.'claude-code']\n  command = \"npx\"\n" >> "$P2/.codex/config.toml"
[ "$(has_toml "$P2/.codex/config.toml")" = YES ] && t_ok "变体确实是合法 TOML 且已注册" || t_bad "测试前提不成立"
( cd "$P2" && bash "$BR" >/dev/null 2>&1 )
[ "$(has_toml "$P2/.codex/config.toml")" = YES ] && t_ok "sentinel 外的用户自有条目未被误删" || t_bad "误删了用户自有配置"
if verify_says "$P2" "^✗ .*反向委派开着但没有"; then
  t_ok "verify 抓到变体形式的计费通路(具体条目匹配)"
else
  t_bad "verify 假通过了变体形式"
fi

# ---------------------------------------------------------------- unbridge
case_ "unbridge:回滚 + 关反向通路 + 幂等"
P3="$(mk p3)" || exit $?
BEFORE="$( cd "$P3" && git ls-files | LC_ALL=C sort )"
ORIG_MD="$( cat "$P3/CLAUDE.md" )"
( cd "$P3" && bash "$BR" --reverse >/dev/null 2>&1 )
( cd "$P3" && bash "$BR" unbridge >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && t_ok "unbridge 退出码 0" || t_bad "unbridge 失败(rc=$rc)"
[ "$ORIG_MD" = "$( cat "$P3/CLAUDE.md" )" ] && t_ok "CLAUDE.md 原文恢复" || t_bad "CLAUDE.md 未恢复原文"
[ ! -e "$P3/AGENTS.md" ] && t_ok "AGENTS.md 已移除" || t_bad "AGENTS.md 残留"
[ ! -L "$P3/.claude/skills/cc-suite" ] && t_ok "skills 软链残留已清(原生 unbridge 会留)" || t_bad "skills 软链残留"
[ ! -f "$P3/$MARKER" ] && t_ok "opt-in 标记已清" || t_bad "opt-in 标记残留"
if [ -f "$P3/.codex/config.toml" ]; then
  [ "$(has_toml "$P3/.codex/config.toml")" = NO ] && t_ok "反向通路已关闭" || t_bad "反向通路仍开"
else
  t_ok "反向通路已关闭(config.toml 一并移除)"
fi
( cd "$P3" && bash "$BR" unbridge >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && t_ok "二次 unbridge 幂等(退出码 0)" || t_bad "二次 unbridge 失败(rc=$rc)"

# ---------------------------------------------------------------- 桥接不完整
case_ "回归:桥接不完整必须 FAIL,不能假通过"
P4="$(mk p4)" || exit $?
( cd "$P4" && bash "$BR" >/dev/null 2>&1 )
rm -f "$P4/AGENTS.md"
if verify_says "$P4" "^✗ .*缺少 AGENTS\\.md"; then
  t_ok "缺 AGENTS.md → verify 报出具体失败项"
else
  t_bad "缺 AGENTS.md 未被报出"
fi
P5="$(mk p5)" || exit $?
( cd "$P5" && bash "$BR" >/dev/null 2>&1 )
rm -f "$P5/.agents/skills"
if verify_says "$P5" "^✗ .*\\.agents/skills 不是可用软链"; then
  t_ok "断了 .agents/skills → verify 报出具体失败项"
else
  t_bad "断链未被报出"
fi

# ---------------------------------------------------------------- relink
case_ "relink:软链重指"
P6="$(mk p6)" || exit $?
( cd "$P6" && bash "$BR" >/dev/null 2>&1 )
rm -f "$P6/.claude/skills/cc-suite"
ln -s /nonexistent/0.0.1/skills/cc-suite "$P6/.claude/skills/cc-suite"
if verify_says "$P6" "^✗ .*skills 软链(缺失或悬空|指向)"; then
  t_ok "悬空软链 → verify 报出具体失败项"
else
  t_bad "悬空软链未被报出"
fi
( cd "$P6" && bash "$BR" relink >/dev/null 2>&1 )
if verify_says "$P6" "^✗ .*$(basename "$P6")"; then
  t_bad "relink 后本 fixture 仍有失败项"
else
  t_ok "relink 后本 fixture 无失败项"
fi
( cd "$P6" && bash "$BR" relink --bogus >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] && t_ok "relink 拒绝多余参数" || t_bad "relink 忽略了多余参数(rc=$rc)"

# ---------------------------------------------------------------- 覆盖补齐
case_ "回归:CRLF 与 provenance 授权"
P7="$(mk p7)" || exit $?
( cd "$P7" && bash "$BR" >/dev/null 2>&1 )
# CRLF 行尾的合法 TOML —— 正则派实现在这里会漏
printf '\r\n[mcp_servers."claude-code"]\r\ncommand = "npx"\r\n' >> "$P7/.codex/config.toml"
[ "$(has_toml "$P7/.codex/config.toml")" = YES ] && t_ok "CRLF 变体是合法 TOML 且被识别" || t_bad "CRLF 变体识别失败"
if verify_says "$P7" "^✗ .*反向委派开着但没有"; then
  t_ok "CRLF 变体被 verify 抓到"
else
  t_bad "CRLF 变体骗过了 verify"
fi
( cd "$P7" && bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 1 ] && t_ok "反向通路关不掉时桥接返回失败(不谎称完成)" || t_bad "桥接仍声称完成(rc=$rc)"

# provenance schema 不对时不构成删除授权
P8="$(mk p8)" || exit $?
( cd "$P8" && bash "$BR" --reverse >/dev/null 2>&1 )
python3 -c "
import json;p='$P8/.agents/.cc-suite-mcp.provenance.json';d=json.load(open(p))
d['schema']=999;json.dump(d,open(p,'w'),indent=2)"
( cd "$P8" && bash "$BR" >/dev/null 2>&1 ) || true
[ "$(has_json "$P8/.agents/mcp_config.json")" = YES ] \
  && t_ok "provenance schema 错误 → 未越权删除用户配置" || t_bad "错误 schema 仍授权了删除"

# provenance 缺失时同样不动手
P9="$(mk p9)" || exit $?
( cd "$P9" && bash "$BR" --reverse >/dev/null 2>&1 )
rm -f "$P9/.agents/.cc-suite-mcp.provenance.json"
( cd "$P9" && bash "$BR" >/dev/null 2>&1 ) || true
[ "$(has_json "$P9/.agents/mcp_config.json")" = YES ] \
  && t_ok "provenance 缺失 → 未越权删除" || t_bad "无 provenance 仍删了用户配置"

case_ "回归:sentinel 结构异常必须拒绝改动"
PA="$(mk pa)" || exit $?
( cd "$PA" && bash "$BR" --reverse >/dev/null 2>&1 )
# 抹掉 close sentinel → 孤立 open,必须拒绝而不是硬改
python3 -c "
p='$PA/.codex/config.toml'
t=open(p).read().replace('# <<< cc-suite-claude-mcp <<<','# unrelated comment')
open(p,'w').write(t)"
# 注意:不能断言整个 config.toml 的哈希不变 —— bridge_mcp.sh 会合法改写
# 它自己的 `>>> cc-suite-mcp >>>` 块。要断言的是 strip 没有动 claude-code 那段。
OUT_PA="$( cd "$PA" && bash "$BR" 2>&1 )" || true
printf '%s' "$OUT_PA" | grep -q "只有开头没有结尾" \
  && t_ok "孤立 sentinel → 报出结构异常" || t_bad "孤立 sentinel 未被识别"
[ "$(has_toml "$PA/.codex/config.toml")" = YES ] \
  && t_ok "孤立 sentinel → 拒绝删除 claude-code 段(不硬改)" || t_bad "孤立 sentinel 下仍删了 claude-code"
grep -q '>>> cc-suite-claude-mcp >>>' "$PA/.codex/config.toml" \
  && t_ok "孤立 sentinel 原样保留,交人工处理" || t_bad "孤立 sentinel 被吞掉了"
( cd "$PA" && bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -ne 0 ] && t_ok "结构异常时桥接返回失败(rc=$rc)" || t_bad "结构异常时桥接仍报成功"

case_ "回归:hooks / MCP parity 的假通过防线"
PB="$(mk pb)" || exit $?
( cd "$PB" && bash "$BR" >/dev/null 2>&1 )
printf '{"hooks":{}}\n' > "$PB/.codex/hooks.json"      # 可解析但是空壳
if verify_says "$PB" "^✗ .*hooks 未镜像全"; then
  t_ok "空壳 hooks.json → verify 抓到(不只看能否解析)"
else
  t_bad "空壳 hooks.json 假通过了"
fi
PC="$(mk pc)" || exit $?
( cd "$PC" && bash "$BR" >/dev/null 2>&1 )
printf '{ not json\n' > "$PC/.mcp.json"                # source 损坏
if verify_says "$PC" "^✗ .*MCP parity 无法判定"; then
  t_ok "损坏的 .mcp.json → 报「判不了」而非「一致」"
else
  t_bad "损坏的 .mcp.json 被报成 parity 一致"
fi

case_ "回归:AGENTS.md 32KiB 截断线"
PD="$(mk pd)" || exit $?
( cd "$PD" && bash "$BR" >/dev/null 2>&1 )
python3 -c "open('$PD/AGENTS.md','w').write('x'*40000)"
if verify_says "$PD" "^✗ .*超过 Codex 32KiB"; then
  t_ok "AGENTS.md 超 32KiB → verify 报出"
else
  t_bad "AGENTS.md 超限未被报出"
fi

case_ "回归:闸门边角"
( cd "$T/plain" && GIT_WORK_TREE="$T/plain" bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] && t_ok "只设 GIT_WORK_TREE 也拒绝" || t_bad "GIT_WORK_TREE 单独设置未被拦(rc=$rc)"
PE="$(mk pe)" || exit $?
mkdir -p "$PE/deep/sub"
( cd "$PE/deep/sub" && bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && [ -f "$PE/AGENTS.md" ] && t_ok "从子目录运行 → 自动切到仓库根后桥接" || t_bad "子目录运行失败(rc=$rc)"
# 非法版本目录不得参与版本选择
in_tmp "$T/fakecache"; mkdir -p "$T/fakecache/1..2/scripts" "$T/fakecache/.1/scripts" "$T/fakecache/garbage/scripts"
for v in "1..2" ".1" "garbage"; do : > "$T/fakecache/$v/scripts/init.sh"; done
OUT_V="$( cd "$T/plain" && CC_SUITE_CACHE_ROOT="$T/fakecache" bash "$BR" 2>&1 )"
printf '%s' "$OUT_V" | grep -q "找不到 cc-suite 稳定版" \
  && t_ok "非法版本目录被排除(不当成可用版本)" || t_bad "非法版本目录参与了版本选择"

case_ "回归:sentinel 文本出现在 TOML 多行字符串里不得截删用户内容"
PF="$(mk pf)" || exit $?
( cd "$PF" && bash "$BR" >/dev/null 2>&1 )
# 构造:多行字符串里含两条 sentinel 文本 + 文件另有用户自有 claude-code。
# 纯按行删除会把字符串中间的内容吃掉;结构等价性校验必须拦下并拒绝写入。
python3 - "$PF/.codex/config.toml" <<'PYX'
import sys
p = sys.argv[1]
q = chr(34) * 3
extra = (
    "\n[tool.note]\n"
    "text = " + q + "\n"
    "# >>> cc-suite-claude-mcp >>>\n"
    "KEEP_THIS_USER_DATA\n"
    "# <<< cc-suite-claude-mcp <<<\n"
    + q + "\n\n"
    "[mcp_servers.'claude-code']\n"
    "command = \"npx\"\n"
)
open(p, "a").write(extra)
PYX
python3 -c "
import tomllib,sys
d=tomllib.load(open('$PF/.codex/config.toml','rb'))
sys.exit(0 if d['tool']['note']['text'].count('KEEP_THIS_USER_DATA')==1 else 1)" \
  && t_ok "构造成功:多行字符串含 sentinel 文本 + 用户自有 claude-code" || t_bad "测试前提不成立"
( cd "$PF" && bash "$BR" >/dev/null 2>&1 ) || true
python3 -c "
import tomllib,sys
try: d=tomllib.load(open('$PF/.codex/config.toml','rb'))
except Exception: sys.exit(1)
sys.exit(0 if 'KEEP_THIS_USER_DATA' in d.get('tool',{}).get('note',{}).get('text','') else 1)" \
  && t_ok "多行字符串内的用户数据未被截删" || t_bad "多行字符串里的用户数据被吃掉了"

case_ "回归:上游先写入 claude-code 再返回非零时,strip 仍必须执行"
# 用 stub 插件模拟 bridge_mcp.sh 的真实坑:它有「已写入 claude-code 之后才返回非零」
# 的路径。若让 set -e 在那里杀掉 wrapper,strip 不跑,计费通路就留下了。
FC="$T/stubcache/9.9.9/scripts"; in_tmp "$T/stubcache"; mkdir -p "$FC"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FC/init.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FC/mcp_codex.sh"
printf 'import sys\nsys.exit(0)\n' > "$FC/bridge_hooks.py"
cat > "$FC/bridge_mcp.sh" <<'STUB'
#!/usr/bin/env bash
# 先写入反向通路 + provenance(模拟真实上游行为),然后以非零退出
mkdir -p .agents
cat > .agents/mcp_config.json <<JSON
{"mcpServers": {"claude-code": {"command": "npx", "args": ["-y", "claude-octopus@1.2.0"]}}}
JSON
cat > .agents/.cc-suite-mcp.provenance.json <<JSON
{"schema": 1, "managed_servers": ["claude-code"], "source": ".mcp.json"}
JSON
echo "stub: wrote claude-code then failing"
exit 1
STUB
PG="$(mk pg)" || exit $?
( cd "$PG" && CC_SUITE_CACHE_ROOT="$T/stubcache" bash "$BR" >/dev/null 2>&1 ); rc=$?
[ "$rc" -ne 0 ] && t_ok "上游失败 → 桥接返回非零(rc=$rc)" || t_bad "上游失败却报成功"
[ "$(has_json "$PG/.agents/mcp_config.json")" = NO ] \
  && t_ok "上游失败时 strip 仍执行了(反向通路已剥离)" || t_bad "strip 被跳过,计费通路留下了"

case_ "回归:verify 不得删除继承来的 TMPD"
# 必须用「缺少 cc-suite-bridge.sh 的假 HOME」:真实 HOME 下 $BR 存在,
# TMPD 会被新的 mktemp 结果覆盖,canary 根本进不了删除路径 —— 那样测试是空洞的。
CANARY="$T/canary-keepme"; in_tmp "$CANARY"; mkdir -p "$CANARY"; : > "$CANARY/keep.txt"
FAKEHOME="$T/fakehome-nobr"; in_tmp "$FAKEHOME"; mkdir -p "$FAKEHOME/.claude/scripts"
[ ! -f "$FAKEHOME/.claude/scripts/cc-suite-bridge.sh" ] \
  && t_ok "测试前提:假 HOME 里没有 bridge 脚本" || t_bad "假 HOME 前提不成立"
TMPD="$CANARY" HOME="$FAKEHOME" bash "$VF" --quiet >/dev/null 2>&1 || true
[ -f "$CANARY/keep.txt" ] \
  && t_ok "\$BR 缺失 + 继承 TMPD → canary 未被删除" || t_bad "verify 删掉了继承来的 TMPD"

# ---------------------------------------------------------------- 汇总
printf '\n══ 回归测试:通过 %d / 失败 %d ══\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then printf '全部通过。\n'; exit 0; else printf '有失败项,接入层存在回归。\n'; exit 1; fi
