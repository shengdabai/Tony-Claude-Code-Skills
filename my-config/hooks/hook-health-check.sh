#!/bin/bash
# hook-health-check.sh — G7 周度 Hook 健康监控
#
# 目的:在 Claude 会话之外(由 launchd 每周一 10:00 触发),体检 ~/.claude/hooks/
# 下所有顶层 hook 脚本的语法 + env-guard 机密防线是否仍在工作。纯监控,只在发现
# 非已知故障时发通知,绝不阻断任何东西,永远 exit 0。
#
# 检查项:
#   1. 所有顶层 *.sh 跑 `bash -n` 语法检查(跳过 lib/ .omc/ 子目录)
#   2. 所有顶层 *.js 跑 `node --check` 语法检查
#   3. env-guard.sh 烟雾测试:喂一个伪造的 PreToolUse JSON(Read 一个 .env 路径),
#      断言它返回 DENY 退出码 2。不 deny = CRITICAL(机密防线失效)
#   4. launchctl 体检:扫描 com.tony.* 任务,标记非零 LastExitStatus
#      (com.tony.lark-deepseek / com.tony.lark-agy 的 -15/15 是已知死亡,不算新故障)
#   5. 写带时间戳的日志到 ~/.omc/logs/
#   6. 有任何非已知故障 → osascript 通知 +(若存在)ntfy 推送
#
# Exit code: 永远 0(监控器不能弄坏任何东西)

# === 0. 固定 PATH(launchd 环境无 NVM lazy-loading,必须用绝对 node 路径)===
export PATH="$HOME/.nvm/versions/node/v24.14.0/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

HOOKS_DIR="$HOME/.claude/hooks"
LOG_DIR="$HOME/.omc/logs"
ENV_GUARD="$HOOKS_DIR/env-guard.sh"
NTFY_ENV="$HOME/.config/ntfy/.env"

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/hook-health-$(date +%Y%m%d).log"

# 失败汇总(每条一行,最后用于通知)
FAILURES=()
# 仅信息(已知死亡的 launchd 任务等,不触发通知)
NOTES=()

log() { echo "$1" | tee -a "$LOG_FILE"; }

# 日志头
{
  echo "========================================"
  echo "Hook Health Check — $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "hooks dir: $HOOKS_DIR"
  echo "node: $(node --version 2>/dev/null || echo 'NOT FOUND')"
  echo "========================================"
} > "$LOG_FILE"

# === 1. bash -n 语法检查所有顶层 *.sh(跳过 lib/ .omc/)===
log ""
log "--- [1] bash -n 语法检查 (顶层 *.sh) ---"
while IFS= read -r f; do
  name=$(basename "$f")
  if bash -n "$f" 2>/tmp/hh-bashn-err; then
    log "  OK   $name"
  else
    err=$(cat /tmp/hh-bashn-err)
    log "  FAIL $name — $err"
    FAILURES+=("bash -n 失败: $name")
  fi
done < <(find "$HOOKS_DIR" -maxdepth 1 -type f -name '*.sh' | sort)
rm -f /tmp/hh-bashn-err

# === 2. node --check 语法检查所有顶层 *.js ===
log ""
log "--- [2] node --check 语法检查 (顶层 *.js) ---"
js_found=0
while IFS= read -r f; do
  js_found=1
  name=$(basename "$f")
  if node --check "$f" 2>/tmp/hh-nodechk-err; then
    log "  OK   $name"
  else
    err=$(cat /tmp/hh-nodechk-err)
    log "  FAIL $name — $err"
    FAILURES+=("node --check 失败: $name")
  fi
done < <(find "$HOOKS_DIR" -maxdepth 1 -type f -name '*.js' | sort)
[ "$js_found" -eq 0 ] && log "  (无顶层 *.js 文件)"
rm -f /tmp/hh-nodechk-err

# === 3. env-guard 烟雾测试(机密防线)===
# env-guard.sh 从 stdin 读 JSON,解析 tool_input.file_path,命中黑名单则 exit 2。
# 喂一个 Read 一个 .env 路径的 PreToolUse payload,断言 deny(exit 2)。
log ""
log "--- [3] env-guard 烟雾测试 (机密防线) ---"
SMOKE_PAYLOAD='{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/hook-health-smoke.env"}}'
if [ ! -f "$ENV_GUARD" ]; then
  log "  CRITICAL env-guard.sh 不存在: $ENV_GUARD"
  FAILURES+=("CRITICAL: env-guard.sh 文件缺失")
else
  echo "$SMOKE_PAYLOAD" | bash "$ENV_GUARD" >/dev/null 2>/tmp/hh-eg-stderr
  rc=$?
  if [ "$rc" -eq 2 ]; then
    log "  OK   env-guard 对 /tmp/hook-health-smoke.env 返回 DENY (exit 2) — 机密防线正常"
  else
    log "  CRITICAL env-guard 未 deny .env 路径,退出码=$rc — 机密防线失效!"
    FAILURES+=("CRITICAL: env-guard 未拦截 .env (exit=$rc) — 机密防线下线")
  fi
  rm -f /tmp/hh-eg-stderr
fi

# === 4. launchctl 体检(com.tony.* 任务退出码)===
# 两个已知死亡任务的 -15/15(SIGTERM)不算新故障,只列出标 KNOWN-DEAD。
log ""
log "--- [4] launchctl com.tony.* 任务退出码 ---"
KNOWN_DEAD="com.tony.lark-deepseek com.tony.lark-agy com.tony.daily-ai-news"  # daily-ai-news 的 -15 是 launchd 回收"脚本成功跑完后"残留的 claude/MCP 子进程,非真故障
while IFS= read -r line; do
  # launchctl list 输出列: PID  LastExitStatus  Label
  label=$(echo "$line" | awk '{print $3}')
  status=$(echo "$line" | awk '{print $2}')
  [ -z "$label" ] && continue
  # 退出码非 0 且非 "-"(从未运行)才关注
  if [ "$status" != "0" ] && [ "$status" != "-" ]; then
    if echo "$KNOWN_DEAD" | grep -qw "$label"; then
      log "  KNOWN-DEAD $label (exit=$status) — 已知死亡,忽略"
      NOTES+=("KNOWN-DEAD: $label (exit=$status)")
    else
      log "  FAIL $label (exit=$status) — 非已知故障"
      FAILURES+=("launchd 任务异常: $label (exit=$status)")
    fi
  else
    log "  OK   $label (exit=$status)"
  fi
done < <(launchctl list 2>/dev/null | grep -i 'com.tony')

# === 5. 结果汇总 ===
log ""
log "--- 汇总 ---"
log "失败项: ${#FAILURES[@]}  |  已知死亡: ${#NOTES[@]}"
for x in "${FAILURES[@]}"; do log "  [FAIL] $x"; done
for x in "${NOTES[@]}"; do log "  [NOTE] $x"; done

# === 6. 仅在有非已知故障时通知 ===
if [ "${#FAILURES[@]}" -gt 0 ]; then
  SUMMARY=$(printf '%s; ' "${FAILURES[@]}")
  # macOS 通知(转义双引号防止 osascript 语法错误)
  SAFE_MSG=$(echo "$SUMMARY" | sed 's/"/\\"/g')
  osascript -e "display notification \"$SAFE_MSG\" with title \"Hook Health\"" 2>/dev/null || true

  # ntfy 推送(best-effort,缺失不报错)
  if [ -f "$NTFY_ENV" ]; then
    # shellcheck disable=SC1090
    set +e
    source "$NTFY_ENV" 2>/dev/null
    if [ -n "${NTFY_TOPIC:-}" ]; then
      NTFY_URL="${NTFY_SERVER:-https://ntfy.sh}/${NTFY_TOPIC}"
      curl -fsS -m 10 \
        -H "Title: Hook Health 异常" \
        -H "Priority: high" \
        -d "$SUMMARY" \
        "$NTFY_URL" >/dev/null 2>&1 || true
    fi
    set -e 2>/dev/null || true
  fi
  log "通知已发送 (${#FAILURES[@]} 个故障)"
else
  log "全部正常,无需通知"
fi

# 监控器永远不破坏任何东西
exit 0
