#!/bin/sh
# gbrain MCP serve wrapper (hardened 2026-06-17)
# ----------------------------------------------
# 直接用 bun 跑 canonical 源,**不再依赖** ~/.bun/bin/gbrain 这条
# bun-global-node_modules 符号链。
#
# 2026-06-17 根因:bun 全局 node_modules/gbrain 被清空(疑似 `bun install -g
# gbrain` 拉到 npmmirror 同名假包覆盖,见 memory reference_gbrain-install 故障节),
# 导致 ~/.bun/bin/gbrain 悬空 → MCP "Failed to connect"。本 wrapper 绕开整条
# bin 符号链,即使 ~/.bun/bin/gbrain 再被破坏,MCP 也照常工作。
#
# PGLite 是单写库:同一时刻只允许一个 serve 持锁。孤儿 serve + 陈旧锁会让新
# 会话拿不到锁、MCP 30s 超时(2026-06-13 故障)。每次 spawn 前:
#   1. 杀掉已存在的 gbrain serve(单写库:最新会话胜出)
#   2. 清陈旧 .gbrain-lock / postmaster.pid
#   3. exec 干净新实例
#
# MCP 配置:~/.claude.json -> mcpServers.gbrain.command 指向本脚本。

BUN="$HOME/.bun/bin/bun"
GBRAIN_SRC="$HOME/.developer-tool-home/gbrain/src/cli.ts"
PGLITE_DIR="$HOME/.gbrain/brain.pglite"

# 兜底:canonical 源不在时,退回桌面 git 仓库副本。
if [ ! -f "$GBRAIN_SRC" ]; then
  GBRAIN_SRC="$HOME/Desktop/01-项目开发/00-Home-Projects/gbrain/src/cli.ts"
fi

# 匹配真实 serve 进程签名 "gbrain/src/cli.ts serve"。本 wrapper 自身 argv 是
# "sh .../gbrain-serve.sh",不含该串,不会自杀。
pkill -f "gbrain/src/cli.ts serve" 2>/dev/null
sleep 1
pkill -9 -f "gbrain/src/cli.ts serve" 2>/dev/null

# 清陈旧锁(被 kill 的实例不会自己释放)。
rm -rf "$PGLITE_DIR/.gbrain-lock" "$PGLITE_DIR/postmaster.pid" 2>/dev/null

# exec 替换本进程为干净的 serve(继承 stdio,MCP 正常握手)。
exec "$BUN" run "$GBRAIN_SRC" serve
