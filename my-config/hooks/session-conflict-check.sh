#!/bin/bash
# SessionStart hook — G3 会话冲突检测。
# 检测:① 过去 2 小时内同项目是否有其他活跃 Claude 进程 ② .omc/plans/ 是否有
# 未完成 [ ] 的 ledger。命中则提示「建议 resume 而非新建」收回 cache miss。
# 纯提示,不阻断;输出走 stdout 注入会话上下文。

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
msgs=()

# ① 其他活跃 claude 进程(排除自己)
self=$$
others=$(pgrep -x claude 2>/dev/null | grep -v "^$self$" | wc -l | tr -d ' ')
[ "${others:-0}" -gt 0 ] && msgs+=("检测到 $others 个其他活跃 Claude 进程 — 若在同项目,优先 attach/resume 已有会话以复用 prompt cache(冷启动会全量重算)。")

# ② 未完成 ledger
if [ -d "$CWD/.omc/plans" ]; then
  pending=$(grep -lE '^\s*-\s*\[ \]' "$CWD/.omc/plans/"*.md 2>/dev/null | head -3)
  if [ -n "$pending" ]; then
    names=$(echo "$pending" | xargs -n1 basename 2>/dev/null | tr '\n' ' ')
    msgs+=("发现未完成的 ledger: $names — 若是续做,先读对应 ledger 跳过 [x] 项,别重做。")
  fi
fi

if [ ${#msgs[@]} -gt 0 ]; then
  echo "<session-hint>"
  for m in "${msgs[@]}"; do echo "- $m"; done
  echo "</session-hint>"
fi
exit 0
