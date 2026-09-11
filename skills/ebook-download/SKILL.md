---
name: ebook-download
description: Use when Tony wants to find, download, or obtain an ebook, PDF, EPUB, 电子书, 找书, 搞一本书, 某本书的电子版, 书的资源, or mentions Z-Library / zlibrary / libgen / Anna's Archive / 影子图书馆 / 电子书下载站. Routes the request through author-published, public-domain, open-access, and licensed-library sources in priority order, and produces clean local PDFs. Also use when building a local library for NotebookLM / RAG / 知识库 ingestion.
---

# 电子书获取路由

## 这个 skill 解决什么

Tony 要一本书的电子版时，**默认反射不该是"去哪个盗版站搜"**，而是走一条从合法来源开始的路由。
实测结论：中文思想/技术类作者的自出版率高得惊人 —— 李笑来把 30+ 本著作全部开源在 GitHub，
阮一峰、廖雪峰、崔庆才等同理。**先查作者自己发没发，往往一步到位，而且拿到的是 Markdown 源文件，
转出来的 PDF 比任何扫描件都干净。**

## 边界（硬约束，不绕）

**不做**：通过 Z-Library、Anna's Archive、libgen、鸠摩搜书、各类网盘资源站等影子图书馆，
批量或单本拉取仍在版权保护期内的书。"仅供学习研究"不构成例外 —— 那不是版权豁免。

本机存在 `~/Desktop/01-项目开发/09-工具应用/06-z-library-helper`（多账号轮换下载工具）。
**本 skill 不调用它**。Tony 若坚持自己用，那是他的事，但不要由 Claude 代为发起。

**做**：下面 6 层来源，按顺序往下走，命中即停。

---

## 路由：6 层来源，按顺序试

### L1 · 作者自出版（命中率最高，优先级最高）

大量中文作者把书完整开源。**先搜作者，再搜书名。**

```bash
# 按作者搜 GitHub（注意：作者可能有多个 org）
gh api "search/repositories?q=<作者名>+in:name,description,readme&per_page=30" \
  --jq '.items[] | "\(.full_name)\t⭐\(.stargazers_count)\t\(.description // "")"'

# 列出某作者全部自有仓库（排除 fork）
for p in 1 2 3; do
  gh api "users/<user>/repos?per_page=100&page=$p&sort=full_name" \
    --jq '.[] | select(.fork==false) | [.name,(.stargazers_count|tostring),(.description//"")] | @tsv'
done
```

**关键坑**：
- 作者的书常散落在**多个组织**下，只搜 `users/<name>/repos` 会漏。
  实例：《人人都能用英语》在 `ZuodaoTech/`、《自学是门手艺》在 `selfteaching/`，都不在 `xiaolai/` 下。
  → 务必同时跑一次 `search/repositories` 按书名/作者名全站搜。
- **很多仓库自带作者官方 PDF**，先 `find <repo> -name '*.pdf'` 再考虑自己转档。官方版永远优于自建版。

同时查作者个人站（`sitemap.xml` / `robots.txt` 往往直接列出全部书页）。

### L2 · 公有领域

| 来源 | 覆盖 | 入口 |
|---|---|---|
| Project Gutenberg | 7.5万+ 英文经典 | `gutenberg.org/ebooks/search/?query=` |
| Standard Ebooks | 精校排版版公有领域 | `standardebooks.org` |
| 中国哲学书电子化计划 | 中文古籍全文 | `ctext.org` |
| 维基文库 | 中文公有领域 | `zh.wikisource.org` |

判断是否进入公有领域：作者卒年 + 50 年（中国大陆）/ 70 年（欧盟、美国多数情形）。拿不准就当作**未进入**。

### L3 · 开放获取学术专著

| 来源 | 入口 |
|---|---|
| DOAB（开放获取图书目录） | `doabooks.org` |
| OAPEN | `oapen.org` |
| Springer / MIT Press Open Access | 各社 open access 板块 |
| arXiv / bioRxiv | 论文与部分专著 |

### L4 · Internet Archive

`archive.org` 有两类：**公有领域全文可下**，与**受控数字借阅（可在线借，不可下载）**。
只取前者；后者当作在线阅读资源给 Tony 链接。`openlibrary.org` 用于查书的元数据与借阅可用性。

### L5 · 正版订阅 / 图书馆借阅

微信读书、京东读书、得到、Kindle Unlimited、Libby / OverDrive（公共图书馆）、
O'Reilly Learning。**Tony 已有会员的优先**（见 memory `reference_devices-and-subscriptions`）。

### L6 · 直接买

给购买链接（豆瓣比价 / 京东 / 当当 / Kindle 商店）。这是终点，不是失败。

---

## 拿到源文件后：转 PDF

本机工具链现状（2026-08 实测）：`pandoc` ✅ `xelatex` ✅ `typst` ✅ ｜ `weasyprint` ❌ `calibre` ❌ `mdbook` ❌

### 优先级
1. 仓库自带官方 PDF → **直接复制，不要转档**
2. 有 EPUB → `pandoc book.epub -o book.pdf --pdf-engine=xelatex`
3. 只有 Markdown → 走下面的配方

### Markdown → PDF（CJK 配方）

```bash
pandoc merged.md -o "书名.pdf" \
  --pdf-engine=xelatex \
  -V CJKmainfont="Songti SC" \
  -V geometry:margin=2.5cm \
  -V linkcolor=blue \
  --toc --toc-depth=2
```

**必踩的坑**：
- **xelatex 首跑要建字体缓存，可能超过 2 分钟** → 一律 `run_in_background: true`，别用默认超时跑。
- **章节顺序不能靠文件名排序**。GitBook 结构要读 `SUMMARY.md` 提取顺序；
  `Chapter1.md … Chapter10.md` 用字典序会把 10 排到 2 前面，必须自然排序。
- 图片路径是相对的 → 在仓库根目录执行 pandoc，或加 `--resource-path`。
- **`xargs -I{}` 会把 TSV 的制表符规范化掉**，导致字段串行、URL 畸形。批量处理用纯 bash `while read` + `&`，不要经 xargs。

### 落盘后必验（Gate：不验不算完成）

```bash
python3 - <<'EOF'
import pathlib, hashlib, collections, subprocess
d = pathlib.Path("<输出目录>")
seen = collections.defaultdict(list)
for p in sorted(d.glob("*.pdf")):
    b = p.read_bytes()
    seen[hashlib.md5(b).hexdigest()].append(p.name)
    ok = b.startswith(b"%PDF")
    print(f"{'OK ' if ok and len(b)>10240 else 'BAD'} {len(b)//1024:>7}KB  {p.name}")
dup = {k: v for k, v in seen.items() if len(v) > 1}
print("重复组:", dup or "无")
print("总计:", len(list(d.glob("*.pdf"))))
EOF
```

再抽 2-3 本渲染首页缩略图肉眼确认**中文没变成乱码方块**（UTF-8 / 字体缺失的典型表现）。

---

## 已建成的本地库

**李笑来全集**：`/Volumes/2T/02-NotebookLM/Xiaolai李笑来/所有资料/电子书PDF/`
来源全部为作者本人在 GitHub（`xiaolai` / `selfteaching` / `ZuodaoTech`）与 lixiaolai.com 的公开发布。
同目录 `xiaolai share/` 是既有的音频与课程资料，**不要动**。

再有"补充李笑来的书"这类需求，先 `ls` 该目录去重，只补差集。

---

## 交付给 Tony 的格式

极简。一张表 + 一行结论：

| 书名 | 来源层级 | 拿到了什么 | 落盘路径 |
|---|---|---|---|

**L1-L4 命中的**：直接给文件。
**只能走 L5/L6 的**：给链接，一句话说明为什么不能直接下（版权期内 / 仅限借阅），不展开说教。
