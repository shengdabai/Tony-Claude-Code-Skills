#!/bin/bash
# mcp-attach — 把 ~/.claude/mcp-templates/ 的模板合并进当前项目 ./.mcp.json
# 用法: 在项目目录运行  bash ~/.claude/scripts/mcp-attach.sh <template>...
# 例:   bash ~/.claude/scripts/mcp-attach.sh content web-deploy
# 全局只有 6 个核心 MCP(github/context7/firecrawl/gbrain/memory/playwright)随处可用;
# 项目专属的重型 MCP 用本工具按需挂,只在该项目目录的会话才启动,避免全局进程过载。
set -e
TPL_DIR="$HOME/.claude/mcp-templates"
AVAIL=$(ls "$TPL_DIR" 2>/dev/null | sed 's/\.json$//' | tr '\n' ' ')

if [ $# -eq 0 ]; then
  echo "用法: bash ~/.claude/scripts/mcp-attach.sh <template>..."
  echo "可用模板: $AVAIL"
  echo "当前目录 .mcp.json: $([ -f ./.mcp.json ] && jq -r '.mcpServers|keys|join(", ")' ./.mcp.json || echo '(无)')"
  exit 0
fi

FILES=()
for t in "$@"; do
  f="$TPL_DIR/$t.json"
  [ -f "$f" ] || { echo "✗ 模板不存在: $t  (可用: $AVAIL)"; exit 1; }
  FILES+=("$f")
done

# 合并已有 .mcp.json + 所有指定模板的 mcpServers(模板覆盖同名)
EXIST="{}"; [ -f ./.mcp.json ] && EXIST=$(cat ./.mcp.json)
jq -s 'reduce .[] as $x ({}; .mcpServers = ((.mcpServers // {}) + ($x.mcpServers // {})))' \
   <(printf '%s' "$EXIST") "${FILES[@]}" > /tmp/mcp-attach.$$ && mv /tmp/mcp-attach.$$ ./.mcp.json
echo "✓ ./.mcp.json → $(jq -r '.mcpServers|keys|join(", ")' ./.mcp.json)"

# git 仓库:把 .mcp.json 加进 .gitignore(防本地路径/配置进 repo,尤其 public)
if git rev-parse --git-dir >/dev/null 2>&1; then
  grep -qxF '.mcp.json' .gitignore 2>/dev/null || printf '\n# 本地 MCP 配置,勿提交\n.mcp.json\n' >> .gitignore
  echo "✓ .mcp.json 已加入 .gitignore"
fi
echo "⚠️  重开/resume 此目录的会话后生效"
