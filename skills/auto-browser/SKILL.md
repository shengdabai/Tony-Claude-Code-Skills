# Auto Browser Skill

自动智能网页内容获取工具，根据URL特征智能选择最佳工具组合。

## 快速开始

```bash
# 自动判断最佳方法
auto-browser https://example.com

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
   - 例如: Twitter, GitHub, Bilibili, Reddit 等

2. **检查网站类型**
   - 静态内容网站 → 使用 gstack browse
   - 需要登录/复杂交互 → 尝试 bb-browser 浏览器模式

3. **组合模式 (--method both)**
   - 同时使用两种工具
   - 合并结果，去重并格式化

## 支持的网站 (bb-browser adapters)

- **社交媒体**: twitter, reddit, m_weibo, bilibili
- **开发者**: github, npm, pypi, arxiv
- **搜索**: google, bing, baidu, duckduckgo
- **新闻**: hackernews, bbc, 36kr
- **其他**: douban, linkedin, producthunt

## 完整选项

```
auto-browser <URL> [OPTIONS]

Options:
  --method <auto|bb-browser|browse|both>  获取方法 (默认: auto)
  --output <path>                         输出文件路径
  --format <text|json|markdown>           输出格式
  --screenshot                            同时获取截图
  --full-content                          获取完整页面内容
  --wait <seconds>                        等待页面加载时间
  --help                                  显示帮助
```

## 使用示例

### 获取技术文章
```bash
auto-browser https://www.anthropic.com/research --method browse --screenshot
```

### 获取Twitter内容
```bash
auto-browser https://x.com/user/status/123 --method bb-browser
```

### 批量获取多个页面
```bash
for url in $(cat urls.txt); do
  auto-browser "$url" --output "output/$(basename $url).md"
done
```

## 输出格式

默认输出 Markdown 格式，包含:
- 页面标题和URL
- 主要内容文本
- 元数据（截图路径、获取时间等）
- 两种工具的结果对比（使用 --method both 时）
