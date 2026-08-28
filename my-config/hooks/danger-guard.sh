#!/bin/bash
# danger-guard.sh — PreToolUse(Bash) 危险命令硬阻断
#
# 存在理由：settings.json 的 defaultMode=bypassPermissions 会跳过所有 ask 规则，
# 只有 deny 生效。而 deny 的 Bash 匹配是前缀匹配，无法区分
# `rm -rf /tmp/foo`（安全）和 `rm -rf /`（灾难）——前者也以 "rm -rf /" 开头。
# 因此不可逆命令的精确判定放在这里。
#
# 约定：exit 2 = 阻断并把 stderr 回传给模型；exit 0 = 放行。
# 只拦「无法撤销且会毁掉真实工作」的操作，日常清理不受影响。

set -uo pipefail

input=$(cat)

cmd=$(printf '%s' "$input" | /usr/bin/python3 -c '
import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    print("")
' 2>/dev/null)

[ -z "$cmd" ] && exit 0

block() {
    printf 'DANGER-GUARD: 已阻断。%s\n' "$1" >&2
    printf '命令: %s\n' "$cmd" >&2
    printf '如确实需要，请在终端手动执行，或用 claude --permission-mode default 起会话逐步确认。\n' >&2
    exit 2
}

# 归一化：压缩连续空白，便于匹配
norm=$(printf '%s' "$cmd" | tr -s '[:space:]' ' ')

# --- 1. rm 递归删除高危目标 ---
# 只在 rm 带 -r/-R/-rf 等递归标志时检查目标
if printf '%s' "$norm" | grep -qE '(^|[;&|]) *(sudo +)?rm +(-[a-zA-Z]*[rR][a-zA-Z]* +)+'; then
    # 提取 rm 之后的所有非选项参数作为删除目标
    targets=$(printf '%s' "$norm" | /usr/bin/python3 -c '
import re,sys,shlex
line = sys.stdin.read()
out = []
for seg in re.split(r"[;&|]+", line):
    seg = seg.strip()
    if not re.match(r"^(sudo\s+)?rm\s", seg):
        continue
    try:
        parts = shlex.split(seg)
    except ValueError:
        parts = seg.split()
    for p in parts:
        if p in ("sudo", "rm") or p.startswith("-"):
            continue
        out.append(p)
print("\n".join(out))
' 2>/dev/null)

    home="$HOME"
    while IFS= read -r t; do
        [ -z "$t" ] && continue
        # 展开 ~ 与 $HOME / ${HOME}，去掉尾部斜杠（/tmp/ 与 /tmp 等价）
        expanded=${t/#\~/$home}
        expanded=${expanded//\$\{HOME\}/$home}
        expanded=${expanded//\$HOME/$home}
        expanded=${expanded%/}
        [ -z "$expanded" ] && expanded="/"

        case "$expanded" in
            "/"|"/*")
                block "rm -rf 根目录。" ;;
            "$home"|"$home/*")
                block "rm -rf 整个 home 目录。" ;;
            "/Users"|"/Users/*"|"/System"|"/Library"|"/Applications"|"/Volumes"|"/etc"|"/usr"|"/bin"|"/sbin"|"/var"|"/opt")
                block "rm -rf 系统级目录 ${expanded}。" ;;
            "$home/Desktop"|"$home/Documents"|"$home/.claude"|"$home/.codex"|"$home/.ssh"|"$home/.config")
                block "rm -rf 关键工作目录 ${expanded}。" ;;
            "/Volumes/2T")
                block "rm -rf 整个 2T 外接硬盘挂载点。" ;;
            "*")
                block "rm -rf 裸通配符 *，删除范围取决于当前目录，不可预测。" ;;
        esac
    done <<< "$targets"
fi

# --- 2. 磁盘级破坏 ---
printf '%s' "$norm" | grep -qE '\bdd\b[^;|&]*\bof=/dev/' \
    && block "dd 直写块设备会摧毁分区。"
printf '%s' "$norm" | grep -qE '\b(mkfs|newfs)[a-z_.]*\b' \
    && block "格式化文件系统。"
printf '%s' "$norm" | grep -qE '\bdiskutil +(erase|reformat|partitionDisk|zeroDisk)' \
    && block "diskutil 抹盘操作。"

# --- 3. fork bomb ---
printf '%s' "$norm" | grep -qE ':\(\) *\{ *: *\| *:& *\} *;:' \
    && block "fork bomb。"

# --- 4. 全局权限破坏 ---
printf '%s' "$norm" | grep -qE 'chmod +(-[a-zA-Z]+ +)*777 +/( |$)' \
    && block "chmod 777 根目录。"
printf '%s' "$norm" | grep -qE 'chown +(-[a-zA-Z]+ +)*[^ ]+ +/( |$)' \
    && block "chown 根目录。"

# --- 5. Git 不可逆操作（deny 规则的补充，覆盖变体写法）---
printf '%s' "$norm" | grep -qE 'git +([a-z-]+ +)*push +([^;|&]* )?(--force\b|-f\b)' \
    && block "git force push 会覆盖远端历史。"
printf '%s' "$norm" | grep -qE 'git +([a-z-]+ +)*reset +([^;|&]* )?--hard' \
    && block "git reset --hard 会丢弃未提交改动。"
printf '%s' "$norm" | grep -qE 'git +([a-z-]+ +)*clean +([^;|&]* )?-[a-zA-Z]*[fd]' \
    && block "git clean 会删除未跟踪文件。"
printf '%s' "$norm" | grep -qE 'git +branch +([^;|&]* )?-D' \
    && block "git branch -D 强制删除分支。"

exit 0
