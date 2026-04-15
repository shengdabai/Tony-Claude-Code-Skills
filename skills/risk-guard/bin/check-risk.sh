#!/usr/bin/env bash
# Risk Guard — Account ban risk detector for Claude Code
# Checks session stats, config, and usage patterns for ban-worthy behavior

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SESSION_STATS="$CLAUDE_DIR/.session-stats.json"
SETTINGS="$CLAUDE_DIR/settings.json"
RISK_STATE="$CLAUDE_DIR/.risk-guard-state.json"

warnings=()
risk_level=0  # 0=safe, 1=low, 2=medium, 3=high, 4=critical

now=$(date +%s)

# ── 1. Check concurrent sessions (only count actual CLI sessions, not MCP/node subprocesses) ──
active_sessions=$(ps aux | awk '/[c]laude/ && $11 == "claude" {count++} END {print count+0}' 2>/dev/null || echo "0")
if [ "$active_sessions" -gt 8 ]; then
  warnings+=("🔴 CRITICAL: 检测到 ${active_sessions} 个并发 Claude CLI 会话 — 过多并发会被视为账号共享/自动化滥用")
  risk_level=4
elif [ "$active_sessions" -gt 5 ]; then
  warnings+=("🟡 WARNING: 检测到 ${active_sessions} 个并发 Claude CLI 会话 — 建议控制在 5 个以内")
  risk_level=$((risk_level > 2 ? risk_level : 2))
fi

# ── 2. Check session tool call velocity ──
if [ -f "$SESSION_STATS" ]; then
  # Get the most recent session's stats
  latest_session=$(python3 -c "
import json, sys
with open('$SESSION_STATS') as f:
    data = json.load(f)
sessions = data.get('sessions', {})
if not sessions:
    sys.exit(0)
# Find most recent session
latest = max(sessions.items(), key=lambda x: x[1].get('updated_at', 0))
sid, info = latest
total = info.get('total_calls', 0)
started = info.get('started_at', 0)
updated = info.get('updated_at', 0)
duration = max(updated - started, 1)
rate = total / (duration / 3600)  # calls per hour
print(f'{total}|{duration}|{rate:.1f}')
" 2>/dev/null || echo "0|0|0")

  if [ -n "$latest_session" ] && [ "$latest_session" != "0|0|0" ]; then
    total_calls=$(echo "$latest_session" | cut -d'|' -f1)
    duration=$(echo "$latest_session" | cut -d'|' -f2)
    rate=$(echo "$latest_session" | cut -d'|' -f3)

    # More than 500 calls per hour is suspicious
    rate_int=${rate%.*}
    if [ "${rate_int:-0}" -gt 500 ]; then
      warnings+=("🔴 CRITICAL: 当前会话工具调用速率 ${rate}/小时 (${total_calls} calls in ${duration}s) — 极高频率可能触发速率限制或自动化检测")
      risk_level=$((risk_level > 4 ? risk_level : 4))
    elif [ "${rate_int:-0}" -gt 200 ]; then
      warnings+=("🟡 WARNING: 当前会话工具调用速率 ${rate}/小时 — 建议适当降低自动化频率")
      risk_level=$((risk_level > 2 ? risk_level : 2))
    fi
  fi
fi

# ── 3. Check for automation loop patterns ──
if [ -f "$SESSION_STATS" ]; then
  agent_count=$(python3 -c "
import json
with open('$SESSION_STATS') as f:
    data = json.load(f)
sessions = data.get('sessions', {})
if not sessions:
    print(0)
else:
    latest = max(sessions.items(), key=lambda x: x[1].get('updated_at', 0))
    print(latest[1].get('tool_counts', {}).get('Agent', 0))
" 2>/dev/null || echo "0")

  if [ "${agent_count:-0}" -gt 30 ]; then
    warnings+=("🟠 HIGH: 当前会话派发了 ${agent_count} 个子 Agent — 过度并行可能消耗大量 token 并触发限流")
    risk_level=$((risk_level > 3 ? risk_level : 3))
  fi
fi

# ── 4. Check session count in recent hours ──
if [ -f "$SESSION_STATS" ]; then
  recent_sessions=$(python3 -c "
import json, time
with open('$SESSION_STATS') as f:
    data = json.load(f)
sessions = data.get('sessions', {})
now = time.time()
one_hour_ago = now - 3600
count = sum(1 for s in sessions.values() if s.get('started_at', 0) > one_hour_ago)
print(count)
" 2>/dev/null || echo "0")

  if [ "${recent_sessions:-0}" -gt 10 ]; then
    warnings+=("🟠 HIGH: 过去 1 小时创建了 ${recent_sessions} 个会话 — 频繁创建新会话可能触发异常检测")
    risk_level=$((risk_level > 3 ? risk_level : 3))
  elif [ "${recent_sessions:-0}" -gt 5 ]; then
    warnings+=("🟡 WARNING: 过去 1 小时创建了 ${recent_sessions} 个会话 — 建议减少会话创建频率")
    risk_level=$((risk_level > 2 ? risk_level : 2))
  fi
fi

# ── 5. Check config risks ──
if [ -f "$SETTINGS" ]; then
  has_bypass=$(grep -c "bypassPermissions" "$SETTINGS" 2>/dev/null || echo "0")
  has_skip_dangerous=$(grep -c "skipDangerousModePermissionPrompt" "$SETTINGS" 2>/dev/null || echo "0")

  if [ "$has_bypass" -gt 0 ] && [ "$has_skip_dangerous" -gt 0 ]; then
    warnings+=("🔵 INFO: bypassPermissions + skipDangerousModePermissionPrompt 已开启 — 这是官方功能不会封号，但会降低对恶意插件/hooks 的防护")
  fi
fi

# ── 6. Check for exposed secrets in git ──
if cd "$HOME" 2>/dev/null && git rev-parse --git-dir &>/dev/null; then
  unignored_secrets=""
  for f in .claude.json .claude/settings.json .env; do
    if [ -f "$HOME/$f" ] && ! git check-ignore -q "$f" 2>/dev/null; then
      unignored_secrets="$unignored_secrets $f"
    fi
  done
  if [ -n "$unignored_secrets" ]; then
    warnings+=("🟠 HIGH: 以下含密钥的文件未被 gitignore 保护:${unignored_secrets} — 可能导致密钥泄露")
    risk_level=$((risk_level > 3 ? risk_level : 3))
  fi
fi

# ── 7. Check telemetry data accumulation ──
telemetry_files=$(find "$CLAUDE_DIR/telemetry" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
if [ "${telemetry_files:-0}" -gt 0 ]; then
  warnings+=("🟡 WARNING: 发现 ${telemetry_files} 个遥测数据文件残留 — 包含个人信息，建议清理: rm ~/.claude/telemetry/*.json")
  risk_level=$((risk_level > 2 ? risk_level : 2))
fi

# ── 8. Check file permissions ──
for f in "$CLAUDE_DIR/settings.json" "$HOME/.claude.json" "$CLAUDE_DIR/.env.secrets"; do
  if [ -f "$f" ]; then
    perms=$(stat -f "%Lp" "$f" 2>/dev/null || stat -c "%a" "$f" 2>/dev/null || echo "unknown")
    if [ "$perms" != "600" ] && [ "$perms" != "unknown" ]; then
      warnings+=("🟡 WARNING: $f 权限为 $perms（应为 600）— 其他用户可读取你的密钥")
      risk_level=$((risk_level > 2 ? risk_level : 2))
    fi
  fi
done

# ── Output ──
if [ ${#warnings[@]} -eq 0 ]; then
  echo "✅ 风险检查通过 — 未发现账号安全隐患"
  echo ""
  echo "检查项目: 并发进程(${active_sessions}), 调用频率, 会话数量, 配置安全, 密钥保护, 遥测数据, 文件权限"
  exit 0
fi

# Map risk level to label
case $risk_level in
  1) level_label="🟢 LOW" ;;
  2) level_label="🟡 MEDIUM" ;;
  3) level_label="🟠 HIGH" ;;
  4) level_label="🔴 CRITICAL" ;;
  *) level_label="🟢 SAFE" ;;
esac

echo "⚠️  风险等级: $level_label"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for w in "${warnings[@]}"; do
  echo "$w"
  echo ""
done
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 处理建议:"
if [ $risk_level -ge 4 ]; then
  echo "  → 立即减少并发进程数或降低自动化频率"
  echo "  → 考虑暂停高频操作 10-15 分钟"
fi
if [ $risk_level -ge 3 ]; then
  echo "  → 检查并修复上述 HIGH/CRITICAL 问题"
  echo "  → 清理敏感数据残留"
fi
if [ $risk_level -ge 2 ]; then
  echo "  → 关注上述 WARNING 项，择机处理"
fi

# Save state for trend tracking
mkdir -p "$(dirname "$RISK_STATE")"
python3 -c "
import json, time
state = {}
try:
    with open('$RISK_STATE') as f:
        state = json.load(f)
except: pass
checks = state.get('checks', [])
checks.append({'ts': int(time.time()), 'level': $risk_level, 'warnings': ${#warnings[@]}})
# Keep last 100 checks
state['checks'] = checks[-100:]
state['last_check'] = int(time.time())
state['last_level'] = $risk_level
with open('$RISK_STATE', 'w') as f:
    json.dump(state, f, indent=2)
" 2>/dev/null || true

exit 0
