#!/usr/bin/env bash
# cc-suite-bridge.sh — Tony 体系的 cc-suite 安全入口
#
# 为什么存在:cc-suite 原生 /cc-suite:init 有几个与本机体系冲突的行为,直接用会出事。
#   1. 硬拒绝在 $HOME 或非 git 目录跑(否则污染全局 ~/.codex/config.toml,
#      并把 247 个全局 skill 暴露给 Codex,推翻精选 23 skill 桥接)
#   2. 默认剥离 claude-octopus 反向委派(agy→Claude / Codex→Claude)——
#      那条通路走 headless Claude = 2026-06-15 起的独立 API 计费桶
#   3. 默认 public 模式(private 只是加 gitignore 规则,不是保密措施)
#   4. relink:cc-suite 升级后软链会指向旧版本目录,每个已桥接项目要重跑
#
# 用法:
#   cd <git repo root>
#   bash ~/.claude/scripts/cc-suite-bridge.sh            # 桥接(推荐默认)
#   bash ~/.claude/scripts/cc-suite-bridge.sh --reverse  # 开反向委派(会计费)
#   bash ~/.claude/scripts/cc-suite-bridge.sh --private  # 桥接产物不进版本库
#   bash ~/.claude/scripts/cc-suite-bridge.sh relink     # 升级后修软链
#   bash ~/.claude/scripts/cc-suite-bridge.sh unbridge   # 拆桥 + 清残留 + 关反向通路
#
# 详见 ~/.claude/rules/cc-suite.md

set -euo pipefail

# CC_SUITE_CACHE_ROOT 只为自测留的缝:测「仓库根 == $HOME」这条分支必须改 HOME,
# 而改了 HOME 插件目录就找不到了。日常使用不要设这个变量。
CACHE_ROOT="${CC_SUITE_CACHE_ROOT:-$HOME/.claude/plugins/cache/xiaolai/cc-suite}"
REVERSE_MARKER=".cc-suite-reverse-opt-in"   # 存在 = 用户显式接受反向委派计费

usage() {
  sed -n '/^# 用法:/,/^# 详见/p' "$0" | sed 's/^# \{0,1\}//'
}

die() { printf '✗ %s\n' "$*" >&2; exit 2; }

# --- 版本解析 -------------------------------------------------------------
# 只接受纯数字点分版本:sort -V 对 prerelease 的排序与 SemVer 相反,
# 目录名是 garbage 时也不能让它参与「最低版本」判断。
resolve_plugin() {
  local best="" b
  for d in "$CACHE_ROOT"/*/; do
    [ -d "$d" ] || continue
    if [ -L "${d%/}" ]; then continue; fi
    [ -f "${d}scripts/init.sh" ] || continue
    b="$(basename "${d%/}")"
    # 必须是严格的点分数字(N.N[.N...]);`.1` `1.` `1..2` 这类非法串
    # 也能通过「只含数字和点」的粗筛,却会让 sort -V 给出无意义的结果
    printf '%s' "$b" | grep -qE '^[0-9]+(\.[0-9]+)+$' || continue
    if [ -z "$best" ]; then best="$b"; continue; fi
    best="$(printf '%s\n%s\n' "$best" "$b" | sort -V | tail -1)"
  done
  [ -n "$best" ] || die "找不到 cc-suite 稳定版插件目录 ($CACHE_ROOT)"
  printf '%s' "$CACHE_ROOT/$best"
}

N="$(resolve_plugin)"
VER="$(basename "$N")"

# --- 安全闸门 -------------------------------------------------------------
guard() {
  # 继承的 GIT_DIR/GIT_WORK_TREE 会让 git 把任意目录当成仓库根,
  # 桥接文件就会写到不该写的地方。直接拒绝,不猜用户意图。
  if [ -n "${GIT_DIR:-}" ] || [ -n "${GIT_WORK_TREE:-}" ]; then
    printf '✗ 拒绝执行:环境里设了 GIT_DIR/GIT_WORK_TREE,git 仓库根不可信。\n' >&2
    die "先 unset GIT_DIR GIT_WORK_TREE 再跑。"
  fi

  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$root" ]; then
    printf '✗ 拒绝执行:当前目录不是 git 仓库。\n' >&2
    die "cc-suite 桥接必须在项目仓库根目录进行。"
  fi

  # 规范化后再比:$HOME 可能带尾斜杠 / 是 symlink,
  # 而 git 返回物理路径,纯字符串比较会漏掉「其实就是 home」这一情况。
  local root_p home_p
  root_p="$(cd "$root" 2>/dev/null && pwd -P)" || root_p="$root"
  home_p="$(cd "$HOME" 2>/dev/null && pwd -P)" || home_p="$HOME"
  if [ "$root_p" = "$home_p" ]; then
    printf '✗ 拒绝执行:仓库根就是 $HOME (%s)。\n' "$home_p" >&2
    die "在这里桥接会改写全局 ~/.codex/config.toml 和 ~/.claude/,不可接受。"
  fi

  if [ "$(pwd -P)" != "$root_p" ]; then
    echo "→ 切到仓库根:$root_p"
    cd "$root_p"
  fi
  REPO_ROOT="$root_p"
}

no_extra_args() {
  [ "$#" -eq 0 ] || { printf '✗ 该子命令不接受额外参数: %s\n' "$*" >&2; echo >&2; usage >&2; exit 2; }
}

# --- 反向委派处理 ---------------------------------------------------------
# 三条反向通路,只关一条等于没关:
#   a) 项目 .agents/mcp_config.json           → agy→Claude(bridge_mcp.sh 每次都塞回)
#   b) 项目 .codex/config.toml                → Codex→Claude(mcp_claude.sh 写入)
#   c) 全局 ~/.gemini/config/mcp_config.json  → 全局 agy,项目级剥离管不到
#
# 设计要点:
#   - TOML 用 tomllib 判定「在不在」(正则挡不住缩进 / 单引号键 / CRLF 等合法写法),
#     但删除只删 cc-suite 自己的 sentinel 整块;sentinel 外的 claude-code 是用户自己写的,
#     只报警不动手(与上游 mcp_claude.sh 的语义一致)。
#   - 只删 sentinel 整块(含两条 sentinel 行)。只删 section 会留下孤立的 open sentinel,
#     下次 mcp_claude.sh 找不到 close sentinel,可能把后面的配置一起吞掉。
#   - JSON 侧要求 provenance 真的把 claude-code 列进 managed_servers 才动手,
#     光「文件存在」不够——损坏的 provenance 不构成删除用户配置的授权。
strip_reverse() {
  python3 - "$REPO_ROOT" "$HOME" <<'PY'
import copy, json, sys, pathlib, tomllib

root = pathlib.Path(sys.argv[1])
home = pathlib.Path(sys.argv[2])
done, warn, hard = [], [], []

SENT_OPEN = "# >>> cc-suite-claude-mcp >>>"
SENT_CLOSE = "# <<< cc-suite-claude-mcp <<<"

def toml_has_claude_code(text):
    """靠解析而不是正则:缩进、单/双引号键、CRLF 都是合法 TOML。"""
    try:
        return "claude-code" in tomllib.loads(text).get("mcp_servers", {}), None
    except Exception as e:
        return None, f"{e}"

def _removal_is_safe(before_text, after_text):
    """按行删 sentinel 块是文本操作,可能误伤 TOML 多行字符串里的同名文本。
    所以删完必须做结构等价性校验:新结构必须恰好等于「旧结构去掉
    mcp_servers.claude-code」。任何其他差异(某个键的值被截断等)都拒绝写入。"""
    try:
        before = tomllib.loads(before_text)
    except Exception as e:
        return False, f"原文件无法解析: {e}"
    try:
        after = tomllib.loads(after_text)
    except Exception as e:
        return False, f"删除后 TOML 不合法: {e}"
    expected = copy.deepcopy(before)
    srv = expected.get("mcp_servers")
    if isinstance(srv, dict):
        srv.pop("claude-code", None)
        if not srv:
            expected.pop("mcp_servers", None)
    after_cmp = copy.deepcopy(after)
    if isinstance(after_cmp.get("mcp_servers"), dict) and not after_cmp["mcp_servers"]:
        after_cmp.pop("mcp_servers", None)
    if after_cmp != expected:
        return False, "除 claude-code 之外还有内容发生了变化"
    return True, None

# ---- b) 项目 Codex 配置 ----
c = root / ".codex" / "config.toml"
if c.exists() and c.is_file():
    text = c.read_text()
    present, err = toml_has_claude_code(text)
    if err:
        warn.append(f"{c} 不是合法 TOML({err})—— 未改动,请手工检查反向通路")
    elif present:
        # 只切 sentinel 整块。sentinel 必须是「注释行」——不加这个条件,
        # 合法多行字符串里恰好出现同样文本时会把用户数据当控制标记删掉。
        lines = text.splitlines(keepends=True)
        out, removed, inside, malformed, pairs = [], False, False, None, 0
        for ln in lines:
            s = ln.strip()
            is_comment = s.startswith("#")
            if is_comment and s == SENT_OPEN:
                if inside:
                    malformed = "出现嵌套的 open sentinel"
                pairs += 1
                # 结构等价性校验基于 tomllib,而 tomllib 会丢掉注释。
                # 多于一对 sentinel 时,「只含用户注释的那一块」被删掉也检查不出来,
                # 所以直接拒绝,交人工。
                if pairs > 1:
                    malformed = "出现多于一对 cc-suite sentinel"
                inside, removed = True, True
                continue
            if is_comment and s == SENT_CLOSE and not inside:
                malformed = "close sentinel 出现在 open 之前或有多余 close"
                continue
            if inside:
                if is_comment and s == SENT_CLOSE:
                    inside = False
                continue
            out.append(ln)
        if malformed:
            hard.append(f"{c} 的 cc-suite sentinel 结构异常({malformed})—— 拒绝改动,请手工修复")
        elif inside:
            hard.append(f"{c} 里 cc-suite sentinel 只有开头没有结尾 —— 拒绝改动,请手工修复")
        elif removed:
            new = "".join(out)
            ok_struct, why = _removal_is_safe(text, new)
            if not ok_struct:
                hard.append(f"{c} 按行删除 sentinel 块会改变 TOML 语义({why})—— 已放弃写入,请手工处理")
            else:
                still, _ = toml_has_claude_code(new)
                if still:
                    warn.append(f"{c} 仍有 sentinel 外的 claude-code(用户自有)—— 未删除,请自行确认")
                c.write_text(new); done.append(str(c))
        else:
            warn.append(f"{c} 的 claude-code 不在 cc-suite sentinel 内(用户自有)—— 未改动,请自行确认")

# ---- a) 项目 agy 工作区配置 ----
target = root / ".agents" / "mcp_config.json"
prov = root / ".agents" / ".cc-suite-mcp.provenance.json"
if target.exists() and target.is_file():
    try:
        d = json.loads(target.read_text() or "{}")
    except Exception as e:
        d = None
        warn.append(f"{target} 不是合法 JSON({e})—— 未改动")
    if d is not None and "claude-code" in d.get("mcpServers", {}):
        managed = None
        if prov.exists() and prov.is_file():
            try:
                pd = json.loads(prov.read_text())
                v = pd.get("managed_servers")
                # 对齐上游 bridge_agy_mcp.py 的契约:schema 必须是 1,
                # managed_servers 必须是纯字符串列表。伪造 / 旧 schema 不构成删除授权。
                if pd.get("schema") != 1:
                    warn.append(f"{prov} schema={pd.get('schema')!r} 不是 1 —— 不视为授权")
                elif isinstance(v, list) and all(isinstance(x, str) for x in v):
                    managed = v
                else:
                    warn.append(f"{prov} managed_servers 不是纯字符串列表 —— 不视为授权")
            except Exception as e:
                warn.append(f"{prov} 解析失败({e})")
        if managed is not None and "claude-code" in managed:
            del d["mcpServers"]["claude-code"]
            target.write_text(json.dumps(d, indent=2) + "\n")
            done.append(str(target))
            pd["managed_servers"] = [x for x in managed if x != "claude-code"]
            prov.write_text(json.dumps(pd, indent=2) + "\n")
            done.append(str(prov))
        else:
            warn.append(
                f"{target} 含 claude-code,但 provenance 未把它列为 cc-suite 托管 "
                f"—— 视为用户自有配置,未改动,请自行确认"
            )

# ---- c) 全局 agy 配置(用户自有,只报不动) ----
g = home / ".gemini" / "config" / "mcp_config.json"
if g.exists() and g.is_file() and g.stat().st_size > 0:
    try:
        if "claude-code" in json.loads(g.read_text() or "{}").get("mcpServers", {}):
            warn.append(f"{g} 全局 agy 反向通路开着 —— 项目级剥离管不到,请手工删除")
    except Exception:
        pass

# 复查:处理完之后到底还有没有开着的反向通路。
# 「只打了个 warning 然后宣布桥接完成」是规则文件明令禁止的语义。
remaining = []
c2 = root / ".codex" / "config.toml"
if c2.exists() and c2.is_file():
    pres, err3 = toml_has_claude_code(c2.read_text())
    if err3:
        remaining.append(f"{c2}(无法解析,无法确认已关闭)")
    elif pres:
        remaining.append(str(c2))
t2 = root / ".agents" / "mcp_config.json"
if t2.exists() and t2.is_file():
    try:
        if "claude-code" in json.loads(t2.read_text() or "{}").get("mcpServers", {}):
            remaining.append(str(t2))
    except Exception:
        remaining.append(f"{t2}(无法解析,无法确认已关闭)")
g2 = home / ".gemini" / "config" / "mcp_config.json"
if g2.exists() and g2.is_file() and g2.stat().st_size > 0:
    try:
        if "claude-code" in json.loads(g2.read_text() or "{}").get("mcpServers", {}):
            remaining.append(str(g2))
    except Exception:
        pass

for w in warn:
    print(f"⚠ {w}")
for h in hard:
    print(f"✗ {h}", file=sys.stderr)
print("· 已剥离反向委派: " + (", ".join(sorted({pathlib.Path(x).name for x in done})) if done else "无需处理"))
if remaining:
    print("✗ 反向计费通路仍开着: " + ", ".join(remaining), file=sys.stderr)
if hard:
    sys.exit(1)
sys.exit(3 if remaining else 0)
PY
}

# --- 子命令 ---------------------------------------------------------------
cmd_relink() {
  no_extra_args "$@"
  guard
  rm -f .claude/skills/cc-suite .agents/skills
  bash "$N/scripts/bridge_skills.sh"
  echo "✓ 软链已重指到 cc-suite $VER"
}

cmd_unbridge() {
  no_extra_args "$@"
  guard
  # marker 先删:strip 万一失败,也不能留下「已显式 opt-in」的假象
  rm -f "$REVERSE_MARKER"
  bash "$N/scripts/unbridge.sh"
  if [ -L .claude/skills/cc-suite ]; then
    rm -f .claude/skills/cc-suite
    echo "✓ 清理残留软链 .claude/skills/cc-suite"
  fi
  local src=0 leftover=0
  strip_reverse || src=$?
  if [ "$src" -eq 3 ]; then
    leftover=1
  elif [ "$src" -ne 0 ]; then
    die "剥离反向委派时出错(退出码 $src)"
  fi
  rmdir .codex 2>/dev/null || true
  [ -d .codex ] || echo "✓ 清理空目录 .codex/"
  echo "⚠ .mcp.json 里的 codex-cli 条目由原生 unbridge 保留,如不需要请手工删除"
  if [ "$leftover" -eq 1 ]; then
    # 拆桥却没能关掉计费通路 —— 必须以非零退出,不能静静地「成功」
    printf '\n✗ 拆桥完成,但仍有反向计费通路无法自动关闭(见上方 ⚠),需手工处理。\n' >&2
    exit 1
  fi
}

cmd_bridge() {
  local private_flag=() reverse=0 a
  for a in "$@"; do
    case "$a" in
      --private) private_flag=(--private) ;;
      --reverse) reverse=1 ;;
      --help|-h) usage; exit 0 ;;
      *) printf '✗ 未知参数: %s\n' "$a" >&2; echo >&2; usage >&2; exit 2 ;;
    esac
  done
  guard

  echo "== cc-suite $VER → $REPO_ROOT =="
  bash "$N/scripts/init.sh" --description "$(basename "$REPO_ROOT")" "${private_flag[@]+"${private_flag[@]}"}"

  # 顺序要点:先把 codex-cli 写进 .mcp.json,再镜像 .mcp.json,
  # 否则首轮 agy 看不到 codex-cli(bridge_agy_mcp 不跳过它),要跑两遍才齐。
  bash "$N/scripts/mcp_codex.sh"
  python3 "$N/scripts/bridge_hooks.py"
  # 关键:bridge_mcp.sh 有「已经写入 claude-code 之后才返回非零」的路径
  # (例如某个 server 形态它不支持)。这里绝不能让 set -e 直接杀掉脚本,
  # 否则 strip 不会执行,agy→Claude 计费通路就留在那里了。
  local mcp_rc=0
  bash "$N/scripts/bridge_mcp.sh" || mcp_rc=$?

  if [ "$reverse" -eq 1 ]; then
    bash "$N/scripts/mcp_claude.sh"     # Codex→Claude,bridge_mcp 不负责这条
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$REVERSE_MARKER"
    echo "⚠ --reverse:已注册 claude-octopus 反向委派(agy→Claude + Codex→Claude)。"
    echo "  每次反向调用走 headless Claude,计入 2026-06-15 起的独立 API 计费桶,自己盯用量。"
    echo "  标记文件 $REVERSE_MARKER 已写入(verify 靠它区分「显式开启」和「意外开启」)。"
  else
    rm -f "$REVERSE_MARKER"             # 先删标记,再剥离:失败时不留假 opt-in
    local src=0
    strip_reverse || src=$?
    if [ "$src" -eq 3 ]; then
      # 规则文件承诺「每次桥接都清前两条」。清不掉就不能宣布桥接完成,
      # 否则计费通路开着而输出一片绿。
      printf '\n✗ 桥接未达成默认约定:反向计费通路仍开着(见上方 ⚠)。\n' >&2
      printf '  这通常是 .codex/config.toml 里有 sentinel 外的用户自有 claude-code,\n' >&2
      printf '  或某个配置无法解析。手工处理后重跑,或用 --reverse 显式接受计费。\n' >&2
      exit 1
    elif [ "$src" -ne 0 ]; then
      die "剥离反向委派时出错(退出码 $src)"
    fi
  fi

  # bridge_mcp.sh 的失败在 strip 之后才报,确保先把通路关掉再退出
  if [ "$mcp_rc" -ne 0 ]; then
    printf '\n✗ MCP 镜像步骤失败(bridge_mcp.sh 退出码 %s)。\n' "$mcp_rc" >&2
    printf '  反向通路已按当前模式处理完(见上方),但 MCP parity 可能不完整。\n' >&2
    printf '  跑 bash ~/.claude/scripts/cc-suite-verify.sh 看具体缺什么。\n' >&2
    exit 1
  fi

  echo
  echo "✓ 桥接完成。检查:bash ~/.claude/scripts/cc-suite-verify.sh"
}

main() {
  local sub="${1:-bridge}"
  case "$sub" in
    relink)    shift || true; cmd_relink "$@" ;;
    unbridge)  shift || true; cmd_unbridge "$@" ;;
    # $# 为 0 时 ${1:-bridge} 也会走到这里,裸 shift 会失败并被 set -e 杀掉
    bridge)    shift || true; cmd_bridge "$@" ;;
    --help|-h) usage ;;
    --*)       cmd_bridge "$@" ;;
    *)         printf '✗ 未知子命令: %s\n' "$sub" >&2; echo >&2; usage >&2; exit 2 ;;
  esac
}

main "$@"
