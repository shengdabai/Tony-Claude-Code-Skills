#!/bin/bash
# lark-bridge-patch-timeouts.sh — 给 lark-channel-bridge 的 dist/cli.js 打「分级超时」补丁
#
# 背景(2026-08-28):
#   bridge 原生只有两档超时:
#     1) idle  探活   = preferences.runIdleTimeoutMinutes(默认 15 分钟)
#     2) hard  硬顶   = LARK_BRIDGE_HARD_TIMEOUT_MS(本机 plist 设 6 小时)
#   缺陷在 armOrPauseIdle():
#       if (inFlightTools.size > 0) return;      // 有工具在飞 -> idle 计时器完全不武装
#   若某个 tool_use 的 tool_result 因断网/SDK 崩溃永不返回,inFlightTools 永不清空,
#   idle 探活就永久失效,任务静默卡死直到撞满 hard timeout(实测有 2 次 60m 空耗)。
#
# 本补丁把「有工具在飞 = 不计时」改成「有工具在飞 = 用更长的 stall 计时」:
#     无工具在飞 : idle  超时(默认 15m 无事件 -> kill)     模型侧假死
#     有工具在飞 : stall 超时(默认 40m 无事件 -> kill)     工具侧卡死
#     兜底       : hard  超时(6h)                          全局硬顶
#   只要 stream 还有任何事件(工具进出/文本输出),计时器每次都被重置 -> 正常长任务不受影响。
#
# 幂等:已打过补丁会直接跳过。npm update 冲掉后重跑本脚本即可。
# 用法: bash ~/.claude/scripts/lark-bridge-patch-timeouts.sh
# 生效: 需重启 daemon -> bash ~/.claude/scripts/lark-bridge-reload.sh

set -uo pipefail

CLI="${LARK_BRIDGE_CLI:-$HOME/.nvm/versions/node/v24.14.0/lib/node_modules/lark-channel-bridge/dist/cli.js}"
LOG="$HOME/.claude/logs/lark-bridge-patch-timeouts.log"
mkdir -p "$(dirname "$LOG")"
ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { printf '[%s] %s\n' "$(ts)" "$*" | tee -a "$LOG"; }

[ -f "$CLI" ] || { log "FAIL: 找不到 cli.js: $CLI"; exit 1; }

BAK="$CLI.bak-graded-timeout-$(date +%Y%m%d-%H%M%S)"
cp "$CLI" "$BAK" || { log "FAIL: 备份失败"; exit 1; }
log "已备份 -> $BAK"

CLI="$CLI" node <<'NODE'
const fs = require('fs');
const p = process.env.CLI;
let s = fs.readFileSync(p, 'utf8');
const orig = s;

if (s.includes('toolStallTimeoutMs')) {
  console.log('SKIP: 补丁已存在，无需重复打');
  process.exit(3);
}

const edits = [
  {
    name: 'declare-stall',
    from: `  const hardTimeoutMs = Number(process.env.LARK_BRIDGE_HARD_TIMEOUT_MS || 60 * 60 * 1e3);
  let hardFired = false;`,
    to: `  const hardTimeoutMs = Number(process.env.LARK_BRIDGE_HARD_TIMEOUT_MS || 60 * 60 * 1e3);
  const toolStallTimeoutMs = Number(process.env.LARK_BRIDGE_TOOL_STALL_MS || 40 * 60 * 1e3);
  let hardFired = false;
  let stallFired = false;`
  },
  {
    name: 'graded-idle',
    from: `  const armOrPauseIdle = () => {
    if (!idleTimeoutMs) return;
    if (timer) clearTimeout(timer);
    timer = void 0;
    if (inFlightTools.size > 0) return;
    timer = setTimeout(() => {
      idleFired = true;
      handle2.interrupted = true;
      log.warn("agent", "idle-timeout", { scope, idleTimeoutMs });
      void handle2.run.stop().catch(() => {
      });
    }, idleTimeoutMs);
  };`,
    to: `  const armOrPauseIdle = () => {
    if (!idleTimeoutMs) return;
    if (timer) clearTimeout(timer);
    timer = void 0;
    const busy = inFlightTools.size > 0;
    const waitMs = busy ? toolStallTimeoutMs : idleTimeoutMs;
    if (!waitMs) return;
    timer = setTimeout(() => {
      idleFired = true;
      stallFired = busy;
      handle2.interrupted = true;
      log.warn("agent", busy ? "tool-stall-timeout" : "idle-timeout", { scope, waitMs, inFlight: inFlightTools.size });
      void handle2.run.stop().catch(() => {
      });
    }, waitMs);
  };`
  },
  {
    name: 'timeout-label',
    from: `      state = markIdleTimeout(state, Math.round((hardFired ? hardTimeoutMs : idleTimeoutMs) / 6e4));`,
    to: `      state = markIdleTimeout(state, Math.round((hardFired ? hardTimeoutMs : stallFired ? toolStallTimeoutMs : idleTimeoutMs) / 6e4));`
  }
];

for (const e of edits) {
  const n = s.split(e.from).length - 1;
  if (n !== 1) {
    console.error(`FAIL: 锚点 [${e.name}] 匹配 ${n} 次（应为 1），上游代码可能已变，放弃全部修改`);
    process.exit(1);
  }
  s = s.replace(e.from, e.to);
}

if (s === orig) { console.error('FAIL: 无任何改动'); process.exit(1); }
fs.writeFileSync(p, s);
console.log('OK: 3 处锚点全部替换成功');
NODE

rc=$?
if [ "$rc" = "3" ]; then
  log "补丁已存在，回滚多余备份"; rm -f "$BAK"; exit 0
fi
if [ "$rc" != "0" ]; then
  log "FAIL: 打补丁失败，恢复备份"; cp "$BAK" "$CLI"; exit 1
fi

if node --check "$CLI" 2>>"$LOG"; then
  log "OK: node --check 语法通过"
else
  log "FAIL: 语法检查未通过，已恢复备份"; cp "$BAK" "$CLI"; exit 1
fi

log "完成。重启生效: bash ~/.claude/scripts/lark-bridge-reload.sh"
log "回滚: cp '$BAK' '$CLI' && bash ~/.claude/scripts/lark-bridge-reload.sh"
