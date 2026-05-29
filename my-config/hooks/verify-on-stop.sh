#!/bin/bash
# verify-on-stop.sh — PostToolUse hook (Soft mode)
# 在 Edit / Write 之后,扫描刚被改写的文件是否真的有预期内容。
# 检测以下"假完成"模式:
#   - 文件 size = 0
#   - 文件全是空白/注释
#   - JSON 顶层是空对象 {} 或空数组 []
#   - JSON 里存在已知"应该有数据"的 key 却为空(colorGroups, hooks, mcpServers, plugins)
#
# Soft 模式:发现可疑时通过 stdout 注入 system-reminder,不阻断 (exit 0)。
# 这让模型在下一轮自动回读验证,而不是停在错误"已完成"状态。
#
# 输入: Claude Code stdin {tool_input: {file_path: "..."}, tool_response: {...}}

set -e

INPUT=$(cat 2>/dev/null || echo "{}")

FILE_PATH=$(echo "$INPUT" | /usr/bin/python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')
    print(fp)
except Exception:
    print('')
" 2>/dev/null)

# 没拿到路径 → 跳过
[ -z "$FILE_PATH" ] && exit 0

# 文件不存在(可能被 rm) → 跳过
[ ! -f "$FILE_PATH" ] && exit 0

# 只检查配置类文件,避免代码文件误报
case "$FILE_PATH" in
    *.json|*.yaml|*.yml|*.toml|*.plist|*CLAUDE.md|*settings.json|*config|*.conf|*.ini|*.env.example)
        ;;
    *)
        # 非配置文件,只做最基础的 size=0 检测
        if [ ! -s "$FILE_PATH" ]; then
            cat >&1 <<EOF
<system-reminder>
⚠️ verify-on-stop: 刚写入的文件大小为 0:
  $FILE_PATH
如果你预期这是空文件请忽略;否则下一轮请 Read 该文件确认内容是否真的写入。
</system-reminder>
EOF
        fi
        exit 0
        ;;
esac

# === 检测 1: 文件大小 ===
SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null || echo 0)

if [ "$SIZE" -eq 0 ]; then
    cat >&1 <<EOF
<system-reminder>
⚠️ verify-on-stop: 配置文件 size=0:
  $FILE_PATH
你刚才声明已写入,但实际是空文件。请下一轮 Read 该文件并补回真实内容。
</system-reminder>
EOF
    exit 0
fi

# === 检测 2: 全空白/注释 ===
# 去掉空行和注释行(#, //) 之后还有没有实质内容
NON_EMPTY=$(grep -vE '^\s*$|^\s*#|^\s*//' "$FILE_PATH" 2>/dev/null | wc -l | tr -d ' ')
if [ "$NON_EMPTY" -eq 0 ]; then
    cat >&1 <<EOF
<system-reminder>
⚠️ verify-on-stop: 文件除空行和注释外没有任何内容:
  $FILE_PATH
如果是预期模板请忽略;否则下一轮请 Read 确认配置项是否真的写入。
</system-reminder>
EOF
    exit 0
fi

# === 检测 3: JSON 特定字段空(Obsidian colorGroups / settings.json hooks / mcpServers 等) ===
case "$FILE_PATH" in
    *.json)
        # 是合法 JSON 才检查
        if /usr/bin/python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$FILE_PATH" 2>/dev/null; then
            EMPTY_FIELDS=$(/usr/bin/python3 <<PYEOF 2>/dev/null
import json, sys
try:
    data = json.load(open("$FILE_PATH"))
except Exception:
    sys.exit(0)

empty = []
WATCH_KEYS = ['colorGroups', 'hooks', 'mcpServers', 'enabledPlugins', 'permissions', 'plugins']

def scan(obj, path=''):
    if isinstance(obj, dict):
        for k, v in obj.items():
            sub = f"{path}.{k}" if path else k
            if k in WATCH_KEYS:
                if v in (None, [], {}, ''):
                    empty.append(sub)
            scan(v, sub)

scan(data)
if empty:
    print(','.join(empty))
PYEOF
)
            if [ -n "$EMPTY_FIELDS" ]; then
                cat >&1 <<EOF
<system-reminder>
⚠️ verify-on-stop: JSON 中以下"应该有数据"的字段为空:
  $FILE_PATH
  空字段: $EMPTY_FIELDS
如果是有意清空请忽略;否则你可能写入了未完成的 JSON,下一轮请 Read 并补全。
</system-reminder>
EOF
            fi
        fi
        ;;
esac

exit 0
