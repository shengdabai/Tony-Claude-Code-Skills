---
name: wechat-mp-export
description: 导出用户自己拥有的微信公众号"盛大白"全部历史文章为 markdown。使用 Playwright 扫码登录 mp.weixin.qq.com 后台，调用官方 appmsg list_ex 接口翻页拉文章，逐篇拉 js_content 转 md。也支持 fetch_stats.py 补抓阅读量/点赞/分享数据写入 frontmatter。仅当用户要求"导出公众号"/"备份公众号文章"/"批量下载我的公众号"时使用。
---

# WeChat 公众号导出（用户拥有的号）

## 适用场景

用户 Tony（盛大白）有自己的公众号，需要批量导出全部历史文章为 markdown 到 `~/Documents/盛大白公众号/`。

**不适用**：导出别人的公众号（那需要密钥嗅探，参考 wechatDownload）。

## 工具位置

```
/Users/tonysheng/Desktop/02-编程项目/04-工具应用/wechat-mp-exporter/
├── .venv/                       # Python 虚拟环境（Playwright + requests + html2text）
├── export_playwright.py         # 主脚本：扫码 → 翻列表 → 逐篇下载
├── fetch_stats.py               # 补抓阅读量/点赞/分享数据
├── export_manual.py             # 备用：手动 cookie 模式（不用）
└── requirements.txt
```

## 已完成的定制

- 输出路径硬编码为 `~/Documents/盛大白公众号/`
- 保留远程图片链接（不下载）和文章内链接
- 翻页和文章间隔 2 秒（防限频）
- venv 隔离，不污染全局 Python

## 执行流程

### 1. 主导出（首次运行 / 新文章增量）

```bash
cd "/Users/tonysheng/Desktop/02-编程项目/04-工具应用/wechat-mp-exporter"
.venv/bin/python3 export_playwright.py
```

会发生：
1. 弹出 Chromium 窗口打开 `mp.weixin.qq.com`
2. **用户必须扫码登录**（手机微信扫描二维码）
3. 脚本检测到 `slave_sid` cookie 即认为登录成功
4. 自动获取 token，翻页 `appmsg/list_ex`，每页 20 条
5. 逐篇打开文章 URL → 提取 `#js_content` → html2text 转 md
6. 文件名 `YYYY-MM-DD-标题.md`
7. **已存在的文件自动跳过**（增量友好）

预计时间：400 篇 × ~3 秒 = 约 20 分钟

### 2. 补抓统计数据（可选，跑完主导出后）

`fetch_stats.py` 用的是手动 cookie 模式，需要先填 TOKEN/SLAVE_SID/SLAVE_USER。

获取方法：
1. 主导出脚本运行时，在浏览器 F12 → Application → Cookies → mp.weixin.qq.com
2. 复制 `slave_sid` 和 `slave_user` 的值
3. 从浏览器地址栏 URL 复制 `token=` 后的数字

填好后跑：
```bash
.venv/bin/python3 fetch_stats.py
```

会读取 `~/Documents/盛大白公众号/` 下所有 md，按标题匹配，把阅读/点赞/分享/评论/打赏数据注入 YAML frontmatter。

## 常见问题

**登录超时（120 秒）**：扫码动作慢了，重新跑一遍。
**Token 获取失败**：脚本会自动重试 home 页，仍失败则微信后台 UI 改了，需更新选择器。
**文章下载失败 "Timeout"**：单篇网络抖动，重跑会跳过已下载、只补失败的。
**API 返回 ret != 0**：cookie 过期，需重新扫码登录。

## 注意事项

- **仅用于用户自己的公众号**。导出别人的号要换工具（wechatDownload 4.4 + Windows）
- Chromium 弹出窗口必须保持开着，关掉脚本就停
- 不要短时间内重复跑，微信后台会限频（已设 2 秒间隔，正常使用安全）
