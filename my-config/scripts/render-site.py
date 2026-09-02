#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tony-Articles 国内静态站渲染器(自包含,零第三方依赖)。

模式:
  render-site.py build [SRC] [OUT]
      把 SRC(默认 ~/.local/share/tony-articles)里的 articles/{zh,en} + ai-news/{zh,en}
      渲染成移动端友好的 HTML 到 OUT(默认 ~/.local/share/tony-articles-site/dist)。
      按日期合并「思考」+「热点」到一个日页 <DATE>.html(中) / <DATE>-en.html(英),
      并生成时间线 index.html。

  render-site.py message <DATE> <BASE_URL>
      输出该日期的微信合并消息文本(双篇摘要 + 国内全文链接),
      已做 surrogate / 控制字符安全过滤,可直接交给 hermes send。
"""
import os, re, sys, html, glob, json
from urllib.parse import urlsplit

HOME = os.path.expanduser("~")
DEFAULT_SRC = os.path.join(HOME, ".local/share/tony-articles")
DEFAULT_OUT = os.path.join(HOME, ".local/share/tony-articles-site/dist")

# ---------------------------------------------------------------- 文本安全
def safe(text: str) -> str:
    """剔除孤立代理字符 + 不可见控制字符,保证 UTF-8 可编码(修历史 surrogate bug)。"""
    if not text:
        return ""
    text = re.sub(r"[\ud800-\udfff]", "", text)                 # 孤立 surrogate
    text = "".join(ch for ch in text if ch == "\n" or ch == "\t" or ord(ch) >= 0x20)
    # 再保险:任何 encode 失败的字符直接丢
    return text.encode("utf-8", "ignore").decode("utf-8")

# ---------------------------------------------------------------- 自包含 markdown
def safe_href(raw_url: str) -> str:
    """Allow web/mail links and local relative paths; neutralize active schemes."""
    decoded = html.unescape(raw_url).strip()
    parsed = urlsplit(decoded)
    if parsed.scheme.lower() in {"http", "https", "mailto"}:
        return html.escape(decoded, quote=True)
    if not parsed.scheme and not decoded.startswith("//"):
        return html.escape(decoded, quote=True)
    return "#"

def _inline(t: str) -> str:
    t = html.escape(t, quote=False)
    # 行内代码
    t = re.sub(r"`([^`]+)`", lambda m: f"<code>{m.group(1)}</code>", t)
    # 链接 [text](url)
    t = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)",
               lambda m: f'<a href="{safe_href(m.group(2))}" target="_blank" rel="noopener noreferrer">{m.group(1)}</a>', t)
    # 粗体先于斜体
    t = re.sub(r"\*\*([^*]+)\*\*", lambda m: f"<strong>{m.group(1)}</strong>", t)
    t = re.sub(r"(?<!\*)\*([^*\n]+)\*(?!\*)", lambda m: f"<em>{m.group(1)}</em>", t)
    return t

def md_to_html(md: str) -> str:
    lines = md.split("\n")
    out, i, n = [], 0, len(md.split("\n"))
    while i < n:
        line = lines[i]
        s = line.strip()
        # 代码围栏
        if s.startswith("```"):
            buf = []; i += 1
            while i < n and not lines[i].strip().startswith("```"):
                buf.append(html.escape(lines[i], quote=False)); i += 1
            i += 1
            out.append("<pre><code>" + "\n".join(buf) + "</code></pre>"); continue
        # 分隔线
        if re.fullmatch(r"(-{3,}|\*{3,}|_{3,})", s):
            out.append("<hr>"); i += 1; continue
        # 标题
        m = re.match(r"(#{1,6})\s+(.*)", s)
        if m:
            lv = len(m.group(1)); out.append(f"<h{lv}>{_inline(m.group(2).strip())}</h{lv}>"); i += 1; continue
        # 引用块
        if s.startswith(">"):
            buf = []
            while i < n and lines[i].strip().startswith(">"):
                buf.append(re.sub(r"^\s*>\s?", "", lines[i])); i += 1
            inner = md_to_html("\n".join(buf))
            out.append(f"<blockquote>{inner}</blockquote>"); continue
        # 列表(有序 / 无序,简单单层)
        if re.match(r"(\s*[-*+]\s+|\s*\d+\.\s+)", line):
            ordered = bool(re.match(r"\s*\d+\.\s+", line))
            tag = "ol" if ordered else "ul"
            items = []
            while i < n and re.match(r"(\s*[-*+]\s+|\s*\d+\.\s+)", lines[i]):
                item = re.sub(r"^\s*(?:[-*+]|\d+\.)\s+", "", lines[i])
                items.append(f"<li>{_inline(item.strip())}</li>"); i += 1
            out.append(f"<{tag}>" + "".join(items) + f"</{tag}>"); continue
        # 空行
        if s == "":
            i += 1; continue
        # 段落(连续非空、非块行)
        buf = []
        while i < n and lines[i].strip() != "" and not re.match(
                r"(#{1,6}\s|>|```|\s*[-*+]\s+|\s*\d+\.\s+)", lines[i]) \
                and not re.fullmatch(r"(-{3,}|\*{3,}|_{3,})", lines[i].strip()):
            buf.append(lines[i].strip()); i += 1
        if buf:
            out.append(f"<p>{_inline(' '.join(buf))}</p>")
    return "\n".join(out)

# ---------------------------------------------------------------- 文章解析
def parse_article(path: str):
    """返回 (title, body_md, plain_summary)。剥掉首部 meta 引用行 + 紧随的 ---。"""
    with open(path, encoding="utf-8", errors="replace") as source:
        raw = safe(source.read())
    lines = raw.split("\n")
    title = ""
    idx = 0
    # 标题 = 第一行 # ...
    while idx < len(lines) and lines[idx].strip() == "":
        idx += 1
    if idx < len(lines) and lines[idx].lstrip().startswith("#"):
        title = re.sub(r"^#+\s*", "", lines[idx].strip()); idx += 1
    # 跳过 meta 引用块(含 发布日期 / Published)
    j = idx
    while j < len(lines) and lines[j].strip() == "":
        j += 1
    if j < len(lines) and lines[j].lstrip().startswith(">") and re.search(r"发布日期|Published", lines[j]):
        while j < len(lines) and lines[j].strip().startswith(">"):
            j += 1
        idx = j
        while idx < len(lines) and lines[idx].strip() == "":
            idx += 1
        # 紧随的一条 ---
        if idx < len(lines) and re.fullmatch(r"-{3,}", lines[idx].strip()):
            idx += 1
    body_md = "\n".join(lines[idx:]).strip()
    # 纯文本摘要:取正文前若干非标题/非引用/非分隔的段落
    plain = []
    for ln in body_md.split("\n"):
        t = ln.strip()
        if not t or t.startswith("#") or t.startswith(">") or re.fullmatch(r"-{3,}", t) \
           or re.match(r"([-*+]\s+|\d+\.\s+)", t):
            if plain:
                break
            continue
        # 去 markdown 行内符号
        t = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", t)
        t = re.sub(r"[*`_]", "", t)
        plain.append(t)
        if sum(len(x) for x in plain) > 160:
            break
    return title, body_md, safe(" ".join(plain))

def find_for_date(src, kind, lang, date):
    """kind: articles|ai-news ; lang: zh|en"""
    hits = sorted(glob.glob(os.path.join(src, kind, lang, f"{date}-*.md")))
    return hits[0] if hits else None

def complete_day(src, date, lang):
    """Return the reflection/news pair only when both files exist."""
    art = find_for_date(src, "articles", lang, date)
    news = find_for_date(src, "ai-news", lang, date)
    return (art, news) if art and news else (None, None)

def all_dates(src):
    dates = set()
    for kind in ("articles", "ai-news"):
        for lang in ("zh", "en"):
            for p in glob.glob(os.path.join(src, kind, lang, "*.md")):
                m = re.match(r"(\d{4}-\d{2}-\d{2})", os.path.basename(p))
                if m:
                    dates.add(m.group(1))
    return sorted(dates, reverse=True)

# ---------------------------------------------------------------- HTML 模板
CSS = """
:root{--bg:#fbfbf9;--fg:#1d1d1f;--muted:#86868b;--line:#e6e6e0;--accent:#0b6efd;--card:#fff}
@media(prefers-color-scheme:dark){:root{--bg:#16161a;--fg:#e8e8ea;--muted:#8a8a92;--line:#2a2a30;--accent:#4ea0ff;--card:#1e1e24}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
 font-family:-apple-system,"PingFang SC","Hiragino Sans GB","Microsoft Yahei",system-ui,sans-serif;
 line-height:1.85;font-size:17px;-webkit-text-size-adjust:100%}
.wrap{max-width:720px;margin:0 auto;padding:28px 20px 80px}
header.top{position:sticky;top:0;background:color-mix(in srgb,var(--bg) 88%,transparent);
 backdrop-filter:saturate(180%) blur(12px);border-bottom:1px solid var(--line);z-index:9}
header.top .wrap{padding:14px 20px;display:flex;align-items:center;justify-content:space-between}
header.top a{color:var(--fg);text-decoration:none;font-weight:600;font-size:16px}
.lang{font-size:13px;color:var(--muted)}
.lang a{color:var(--accent);text-decoration:none}
.date-badge{color:var(--muted);font-size:14px;margin:0 0 6px}
.section-tag{display:inline-block;font-size:13px;font-weight:600;letter-spacing:.04em;
 padding:3px 10px;border-radius:999px;background:var(--accent);color:#fff;margin:42px 0 6px}
.section-tag.news{background:#ff8c1a}
article h1{font-size:27px;line-height:1.35;margin:.2em 0 .5em;letter-spacing:-.01em}
article h2{font-size:21px;margin:1.6em 0 .5em;padding-top:.2em}
article h3{font-size:18px;margin:1.3em 0 .4em}
article p{margin:1em 0}
article a{color:var(--accent);text-decoration:none;border-bottom:1px solid color-mix(in srgb,var(--accent) 35%,transparent)}
article blockquote{margin:1.2em 0;padding:.4em 1em;border-left:3px solid var(--line);color:var(--muted)}
article hr{border:0;border-top:1px solid var(--line);margin:2.4em 0}
article ul,article ol{padding-left:1.4em}
article li{margin:.4em 0}
article code{background:color-mix(in srgb,var(--muted) 20%,transparent);padding:.1em .4em;border-radius:5px;font-size:.92em}
article pre{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px;overflow:auto}
article pre code{background:none;padding:0}
.divider{height:1px;background:var(--line);margin:54px 0}
.idx-item{display:block;text-decoration:none;color:inherit;border:1px solid var(--line);
 background:var(--card);border-radius:14px;padding:16px 18px;margin:14px 0;transition:.15s}
.idx-item:hover{border-color:var(--accent)}
.idx-date{font-size:13px;color:var(--muted);margin-bottom:6px}
.idx-row{font-size:16px;margin:3px 0}
.idx-row b{color:var(--accent);font-weight:600;margin-right:6px}
footer{margin-top:60px;color:var(--muted);font-size:13px;text-align:center}
footer a{color:var(--muted)}
"""

REPO = "https://github.com/shengdabai/Tony-Articles"

def page(title, body, lang_toggle=""):
    return f"""<!doctype html><html lang="zh-CN"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#fbfbf9">
<title>{html.escape(title)}</title>
<style>{CSS}</style></head>
<body>
<header class="top"><div class="wrap">
<a href="/">盛大白 · 每日</a>
<span class="lang">{lang_toggle}</span>
</div></header>
<div class="wrap">{body}
<footer>盛大白每日深度思考 · 思考 + AI 热点<br>
<a href="{REPO}" target="_blank">GitHub 原文备份</a></footer>
</div></body></html>"""

def render_day(src, date, lang):
    other = "en" if lang == "zh" else "zh"
    art, news = complete_day(src, date, lang)
    if not art or not news:
        return None, None
    tag_think = "💭 思考" if lang == "zh" else "💭 Reflection"
    tag_news = "📰 AI 热点" if lang == "zh" else "📰 AI Daily"
    parts = [f'<p class="date-badge">{date}</p>']
    first_title = ""
    if art:
        t, body, _ = parse_article(art)
        first_title = first_title or t
        parts.append(f'<span class="section-tag">{tag_think}</span>')
        parts.append(f"<article><h1>{html.escape(t)}</h1>{md_to_html(body)}</article>")
    if art and news:
        parts.append('<div class="divider"></div>')
    if news:
        t, body, _ = parse_article(news)
        first_title = first_title or t
        parts.append(f'<span class="section-tag news">{tag_news}</span>')
        parts.append(f"<article><h1>{html.escape(t)}</h1>{md_to_html(body)}</article>")
    other_art, other_news = complete_day(src, date, other)
    other_exists = bool(other_art and other_news)
    toggle = ""
    if other_exists:
        href = f"/{date}{'-en' if other=='en' else ''}.html"
        toggle = f'<a href="{href}">{"English" if other=="en" else "中文"}</a>'
    return page(f"{first_title or date} · 盛大白每日", "\n".join(parts), toggle), first_title

def render_index(src, out, dates):
    rows = []
    for d in dates:
        zh_art, zh_news = complete_day(src, d, "zh")
        if not zh_art or not zh_news:
            continue
        line = [f'<a class="idx-item" href="/{d}.html"><div class="idx-date">{d}</div>']
        if zh_art:
            t, _, _ = parse_article(zh_art)
            line.append(f'<div class="idx-row"><b>思考</b>{html.escape(t)}</div>')
        if zh_news:
            t, _, _ = parse_article(zh_news)
            line.append(f'<div class="idx-row"><b>热点</b>{html.escape(t)}</div>')
        line.append("</a>")
        rows.append("".join(line))
    body = '<h1 style="font-size:24px;margin:.2em 0 1em">每日 · 思考 & AI 热点</h1>' + "\n".join(rows)
    return page("盛大白 · 每日", body)

def build(src, out):
    os.makedirs(out, exist_ok=True)
    # An earlier one-sided render must not survive after the completeness gate
    # starts rejecting that date. index.html is overwritten below.
    for stale in glob.glob(os.path.join(out, "20??-??-??.html")) + glob.glob(os.path.join(out, "20??-??-??-en.html")):
        os.unlink(stale)
    dates = all_dates(src)
    n = 0
    for d in dates:
        for lang in ("zh", "en"):
            htmlpage, _ = render_day(src, d, lang)
            if htmlpage:
                fn = f"{d}.html" if lang == "zh" else f"{d}-en.html"
                with open(os.path.join(out, fn), "w", encoding="utf-8") as target:
                    target.write(htmlpage)
                n += 1
    with open(os.path.join(out, "index.html"), "w", encoding="utf-8") as target:
        target.write(render_index(src, out, dates))
    print(f"built {n} pages + index for {len(dates)} dates -> {out}")

def message(src, date, base_url):
    """微信合并消息文本(surrogate-safe)。"""
    art, news = complete_day(src, date, "zh")
    en_art, en_news = complete_day(src, date, "en")
    if not art or not news or not en_art or not en_news:
        raise ValueError(f"{date} 中英文思考/热点未形成完整四文件，拒绝生成国内链接")
    blocks = [f"📅 盛大白每日 · {date}", ""]
    if art:
        t, _, summ = parse_article(art)
        blocks += [f"💭 思考｜《{t}》", (summ[:120] + "…") if summ else "", ""]
    if news:
        t, _, summ = parse_article(news)
        blocks += [f"📰 热点｜{t}", (summ[:110] + "…") if summ else "", ""]
    url = base_url.rstrip("/") + f"/{date}.html"
    blocks += ["🔗 国内秒开 · 双篇全文(中英可切):", url, "", "— 不点链接也能读上面摘要;全文排版更舒服"]
    return safe("\n".join(b for b in blocks))

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(1)
    mode = args[0]
    if mode == "build":
        src = args[1] if len(args) > 1 else DEFAULT_SRC
        out = args[2] if len(args) > 2 else DEFAULT_OUT
        build(src, out)
    elif mode == "message":
        if len(args) < 3:
            print("usage: render-site.py message <DATE> <BASE_URL>", file=sys.stderr); sys.exit(1)
        sys.stdout.write(message(DEFAULT_SRC, args[1], args[2]))
    else:
        print(f"unknown mode: {mode}", file=sys.stderr); sys.exit(1)

if __name__ == "__main__":
    main()
