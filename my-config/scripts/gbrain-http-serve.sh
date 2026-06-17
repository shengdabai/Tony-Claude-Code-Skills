#!/bin/sh
# gbrain HTTP MCP daemon wrapper (launchd-managed, 2026-06-17)
# ----------------------------------------------------------------
# 取代 stdio 模式:一个常驻 HTTP server 独占 PGLite 单写库,所有 Claude 会话
# 当 HTTP 客户端连(http://127.0.0.1:3131/mcp + Bearer token)。彻底消除 stdio
# 多会话下 serve 进程互相 pkill 的 ping-pong(13 会话并发踢死)。
#
# 单写库纪律:本 daemon 是唯一 canonical writer。启动前清掉任何残留 serve
# (stdio 或 http)+ 陈旧锁,确保 daemon 总能拿到锁。launchd KeepAlive 重启时
# 旧实例已退出,pkill 只清孤儿。
#
# NO_PROXY:本机 Clash TUN/ALL_PROXY 环境下,确保 daemon 自身任何 localhost
# 自调用不被代理劫持(Node fetch 默认已忽略 ALL_PROXY,这是双保险)。
#
# 由 ~/Library/LaunchAgents/com.tony.gbrain-http.plist 拉起。

export NO_PROXY="127.0.0.1,localhost,::1"
export no_proxy="127.0.0.1,localhost,::1"

BUN="$HOME/.bun/bin/bun"
CLI="$HOME/.developer-tool-home/gbrain/src/cli.ts"
PGLITE_DIR="$HOME/.gbrain/brain.pglite"

# 兜底:canonical 源不在时退回桌面副本。
if [ ! -f "$CLI" ]; then
  CLI="$HOME/Desktop/01-项目开发/00-Home-Projects/gbrain/src/cli.ts"
fi

# 清掉任何残留 serve(本 wrapper argv 是 "sh .../gbrain-http-serve.sh",
# 不含 "gbrain/src/cli.ts serve",不会自杀)。
pkill -f "gbrain/src/cli.ts serve" 2>/dev/null
sleep 1
pkill -9 -f "gbrain/src/cli.ts serve" 2>/dev/null
rm -rf "$PGLITE_DIR/.gbrain-lock" "$PGLITE_DIR/postmaster.pid" 2>/dev/null

exec "$BUN" run "$CLI" serve --http --port 3131
