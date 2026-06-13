#!/bin/sh
# gbrain MCP serve wrapper
# ------------------------
# PGLite 是单写库:同一时刻只允许一个 `gbrain serve` 持锁。
# 多个 Claude 会话退出不干净会留下孤儿 serve + 陈旧锁,导致新会话拿不到锁、
# MCP 连接 30s 超时(2026-06-13 实际故障根因)。
#
# 本 wrapper 在每次 spawn 前:
#   1. 杀掉所有已存在的 gbrain serve(单写库:最新会话胜出)
#   2. 清掉陈旧 .gbrain-lock / postmaster.pid
#   3. exec 一个干净的新实例
#
# MCP 配置(~/.claude.json -> mcpServers.gbrain.command)指向本脚本。

GBRAIN_BIN="$HOME/.bun/bin/gbrain"
PGLITE_DIR="$HOME/.gbrain/brain.pglite"

# 匹配真实进程签名 "bin/gbrain serve";本 wrapper 自身 argv 是
# "sh .../gbrain-serve.sh",不含该串,故不会自杀。
pkill -f "bin/gbrain serve" 2>/dev/null
sleep 1
pkill -9 -f "bin/gbrain serve" 2>/dev/null

# 清陈旧锁(被 kill 的实例不会自己释放)。
rm -rf "$PGLITE_DIR/.gbrain-lock" "$PGLITE_DIR/postmaster.pid" 2>/dev/null

# exec 替换本进程为干净的新 serve(继承 stdio,MCP 正常握手)。
exec "$GBRAIN_BIN" serve
