#!/bin/bash
# script-lint.sh — PostToolUse hook (Write|Edit), 警告不阻断 (exit 0)
#
# 针对 /insights 报告的 #1 friction:27 个 session 因脚本 bug 反复 debug
# (printf 格式注入 / set -u 下未定义变量 / CJK 破 shell 解析 / stdlib 同名冲突)。
# 这些错误此前**只有运行时才暴露**,常常已经产出了空白或错误结果。
# 本 hook 在文件刚落盘时静态检查,把发现直接注入 system-reminder。
#
# 检查项:
#   *.sh / *.bash → bash -n(语法) + shellcheck -S warning(若已装)
#   *.py          → ruff check(若已装) + stdlib 同名文件冲突(html.py / json.py …)
#
# 设计原则:永不阻断(exit 0),永不改文件,输出限量避免刷屏。

set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

FILE_PATH=$(printf '%s' "$INPUT" | /usr/bin/python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# 跳过第三方 / 缓存目录,只检查自己写的代码
case "$FILE_PATH" in
    */node_modules/*|*/.git/*|*/venv/*|*/.venv/*|*/site-packages/*|*/__pycache__/*|*/plugins/cache/*)
        exit 0 ;;
esac

MAX_LINES=25
FINDINGS=""

emit() { FINDINGS="${FINDINGS}$1"$'\n'; }

case "$FILE_PATH" in
    *.sh|*.bash)
        # 1) 语法检查 — 最硬的判据,零依赖
        if ! SYNTAX=$(bash -n "$FILE_PATH" 2>&1); then
            emit "❌ bash -n 语法错误:"
            emit "$(printf '%s' "$SYNTAX" | head -n "$MAX_LINES")"
        fi

        # 2) shellcheck — 抓未引用变量 / 未定义变量 / 格式注入
        #    级别必须是 info:SC2086(未引用变量→分词/glob,CJK 路径的头号杀手)
        #    是 note/info 级,-S warning 会把它整个滤掉。style 级噪音仍被排除。
        if command -v shellcheck >/dev/null 2>&1; then
            if ! SC=$(shellcheck -S info -f gcc "$FILE_PATH" 2>&1); then
                if [ -n "$SC" ]; then
                    COUNT=$(printf '%s\n' "$SC" | grep -c . || true)
                    emit "⚠️ shellcheck 报告 ${COUNT} 处 warning+ 问题(前 ${MAX_LINES} 行):"
                    emit "$(printf '%s' "$SC" | head -n "$MAX_LINES")"
                fi
            fi
        fi
        ;;

    *.py)
        # 1) stdlib 同名冲突 — 报告里 html.py 那类坑,import 会静默拿错模块
        #    硬编码高风险名单:macOS 自带 python3 是 3.9,没有 sys.stdlib_module_names,
        #    动态检测恒为假。这批名字几十年不变,写死反而最可靠且零依赖。
        BASE=$(basename "$FILE_PATH" .py)
        CLASH=""
        case "$BASE" in
            abc|argparse|ast|base64|calendar|cgi|cmd|code|codecs|collections|colorsys|\
config|contextlib|copy|csv|dataclasses|datetime|decimal|difflib|dis|email|enum|\
filecmp|fnmatch|fractions|ftplib|functools|getopt|getpass|gettext|glob|graphlib|\
gzip|hashlib|heapq|hmac|html|http|imaplib|imp|inspect|io|ipaddress|itertools|json|\
keyword|linecache|locale|logging|mailbox|math|mimetypes|numbers|operator|os|parser|\
pathlib|pickle|pipes|platform|plistlib|poplib|pprint|profile|pty|queue|random|re|\
sched|secrets|select|selectors|shelve|shlex|shutil|signal|site|smtplib|socket|\
socketserver|sqlite3|ssl|stat|statistics|string|stringprep|struct|subprocess|symbol|\
sys|tarfile|telnetlib|tempfile|test|textwrap|threading|time|timeit|token|tokenize|\
trace|traceback|tty|types|typing|unittest|urllib|uu|uuid|venv|warnings|wave|weakref|\
webbrowser|xml|zipfile|zlib)
                CLASH="CLASH" ;;
        esac
        if [ "$CLASH" = "CLASH" ]; then
            emit "❌ 文件名与 Python 标准库模块同名: ${BASE}.py"
            emit "   同目录下任何 'import ${BASE}' 都会拿到这个文件而非标准库,导致难查的静默错误。改名后再继续。"
        fi

        # 2) ruff — 未定义名 / 未使用导入 / 语法
        if command -v ruff >/dev/null 2>&1; then
            if ! RF=$(ruff check --quiet --output-format concise "$FILE_PATH" 2>&1); then
                if [ -n "$RF" ]; then
                    COUNT=$(printf '%s\n' "$RF" | grep -c . || true)
                    emit "⚠️ ruff 报告 ${COUNT} 处问题(前 ${MAX_LINES} 行):"
                    emit "$(printf '%s' "$RF" | head -n "$MAX_LINES")"
                fi
            fi
        else
            # 无 ruff 时至少保证能编译
            if ! PY=$(/usr/bin/python3 -m py_compile "$FILE_PATH" 2>&1); then
                emit "❌ Python 语法错误:"
                emit "$(printf '%s' "$PY" | head -n "$MAX_LINES")"
            fi
        fi
        ;;

    *)
        exit 0 ;;
esac

if [ -n "${FINDINGS// /}" ] && [ "$FINDINGS" != $'\n' ]; then
    cat >&1 <<EOF
<system-reminder>
🔍 script-lint 检查了刚写入的 $FILE_PATH:

${FINDINGS}
这是静态检查结果,不阻断执行。运行该脚本前请先修掉 ❌ 项;⚠️ 项自行判断。
不要在未修复 ❌ 的情况下向用户声明脚本已完成。
</system-reminder>
EOF
fi

exit 0
