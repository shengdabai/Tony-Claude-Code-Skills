#!/usr/bin/env bash
# session-registry.sh — Claude Code SessionStart/SessionEnd hook 注册器(wrapper)
# 计算父 TTY,把 hook JSON(stdin)原样转给 python 注册器。退出码永远 0。
PYTHON="/opt/homebrew/bin/python3"
REGISTRY_TTY="$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')"
export REGISTRY_TTY
"$PYTHON" "$HOME/.claude/scripts/session-registry.py" 2>/dev/null
exit 0
