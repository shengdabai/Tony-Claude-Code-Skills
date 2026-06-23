#!/usr/bin/env bash
# skycomputeruse-turn-ended-timeout.sh
# Codex turn 结束通知的 timeout 包装。
# 根因:~/.codex/config.toml 的 notify 直接 spawn SkyComputerUseClient turn-ended,
# 该进程要连 Computer Use app-server 的 IPC;turn 结束后 app-server 不可达 → 永久 hang → 堆积。
# 本包装给它最多 SKY_TURN_ENDED_TIMEOUT_SEC(默认 15)秒,超时 SIGTERM,再 2 秒 SIGKILL。
# 正常情况 Sky 秒退,guard 子 shell 被回收,零残留。
set -euo pipefail

SKY="$HOME/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"

# Sky 二进制不在(已卸载/改版)时,静默成功退出,不阻断 Codex turn
if [[ ! -x "$SKY" ]]; then
  exit 0
fi

"$SKY" turn-ended "$@" &
pid=$!

(
  sleep "${SKY_TURN_ENDED_TIMEOUT_SEC:-15}"
  kill -TERM "$pid" 2>/dev/null || exit 0
  sleep 2
  kill -KILL "$pid" 2>/dev/null || true
) &
guard=$!

set +e
wait "$pid"
rc=$?
set -e

kill "$guard" 2>/dev/null || true
wait "$guard" 2>/dev/null || true

# Timeout means the guard did its job. Do not let a stuck notification mark the
# Codex turn itself as failed.
if [[ "$rc" == "143" || "$rc" == "137" ]]; then
  exit 0
fi

exit "$rc"
