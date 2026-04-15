# Auto Browser Skill

智能网页内容获取工具，自动组合 `bb-browser` 和 `gstack browse`。

## 安装

```bash
# 确保依赖已安装
which bb-browser  # bb-browser
ls ~/.claude/skills/gstack/browse/dist/browse  # gstack browse

# skill 已自动安装到 ~/.claude/skills/auto-browser/
```

## 快速使用

```bash
# 方法1: 直接使用 skill
Skill skill="auto-browser" args="https://example.com"

# 方法2: 使用命令行
~/.claude/skills/auto-browser/auto-browser.sh https://example.com

# 方法3: 添加到 PATH
export PATH="$HOME/.claude/skills/auto-browser:$PATH"
auto-browser https://example.com
```

## 使用示例

```bash
# 自动判断最佳方法
auto-browser https://news.ycombinator.com

# 使用特定方法
auto-browser https://example.com --method bb-browser
auto-browser https://example.com --method browse
auto-browser https://example.com --method both

# 获取截图
auto-browser https://example.com --screenshot

# 输出到指定文件
auto-browser https://example.com --output result.md
```

## 智能选择逻辑

1. **检查 bb-browser site adapter**
   - 如果有适配器 → 优先使用 bb-browser
   - 支持: Twitter, GitHub, Bilibili, Reddit 等50+站点

2. **静态内容网站**
   - 使用 gstack browse（更快更稳定）

3. **组合模式 (`--method both`)**
   - 同时使用两种工具
   - 合并结果，提高成功率

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--method` | 获取方法: auto/bb/browse/both | auto |
| `--output` | 输出文件路径 | 自动生成 |
| `--screenshot` | 同时获取截图 | false |
| `--help` | 显示帮助 | - |

## 支持的网站 (bb-browser adapters)

- **社交媒体**: twitter, reddit, m_weibo, bilibili
- **开发者**: github, npm, pypi, arxiv
- **搜索**: google, bing, baidu, duckduckgo
- **新闻**: hackernews, bbc, 36kr
- **其他**: douban, linkedin, producthunt

查看完整列表:
```bash
bb-browser site list
```

## 输出格式

默认输出 Markdown，包含:
- 页面标题和URL
- 主要内容文本
- 获取时间和方法
- 两种工具的结果对比（使用 both 模式时）

## 故障排除

### bb-browser 未找到
```bash
npm install -g bb-browser
```

### gstack browse 未找到
```bash
cd ~/.claude/skills/gstack/browse && ./setup
```

### 网站需要登录
- 先用 bb-browser 登录网站
- 工具会自动使用保存的登录态
