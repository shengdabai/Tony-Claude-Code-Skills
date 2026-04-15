# MCP Server Configurations

MCP servers are configured in `~/.claude/settings.json`. Below are the configurations used in this setup.

## Server List

| Server | Type | Command |
|--------|------|---------|
| context7 | stdio | `@upstash/context7-mcp` |
| firecrawl | stdio | `firecrawl-mcp` |
| exa | stdio | `exa-mcp` (via shell script) |
| github | stdio | `github-mcp` (via shell script) |
| playwright | stdio | `@playwright/mcp` |
| getnote | stdio | Custom shell script |
| gbrain | stdio | `gbrain serve` |
| notebooklm | stdio | `notebooklm-mcp` |
| lark | stdio | `lark-mcp` (via shell script) |
| airmcp | stdio | `airmcp` |

## Installation

```bash
# Install npm-based MCP servers globally
npm i -g @upstash/context7-mcp firecrawl-mcp @playwright/mcp notebooklm-mcp airmcp

# Shell-script based servers require additional setup in ~/.config/
# See individual project docs for details
```

## Configuration

Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "context7": {
      "command": "/Users/adam/.nvm/versions/node/v24.14.0/bin/node",
      "args": ["/Users/adam/.nvm/versions/node/v24.14.0/lib/node_modules/@upstash/context7-mcp/dist/index.js"],
      "type": "stdio"
    }
  }
}
```

Note: Use absolute paths for Node.js and npm packages to avoid NVM lazy-loading issues.
