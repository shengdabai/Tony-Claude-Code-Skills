#!/usr/bin/env python3
"""
Stealth web scraper using curl_cffi (browser impersonation) + html2text.
Extracts clean Markdown from any URL, including WeChat articles.

Usage: python3 scrape.py <url> [max_chars]
"""
import sys
from curl_cffi import requests
import html2text


def extract(url: str, max_chars: int = 30000) -> str:
    # Use curl_cffi with browser impersonation to bypass anti-bot
    resp = requests.get(
        url,
        impersonate="chrome",
        allow_redirects=True,
        timeout=20,
        headers={
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        },
    )
    resp.raise_for_status()
    html_content = resp.text

    # Try to extract main content area via simple heuristics
    from html.parser import HTMLParser
    import re

    # Priority selectors as regex patterns on common content containers
    content_patterns = [
        r'<article[^>]*>(.*?)</article>',
        r'id="js_content"[^>]*>(.*?)</div>',           # WeChat
        r'class="rich_media_content"[^>]*>(.*?)</div>', # WeChat alt
        r'class="article-content[^"]*"[^>]*>(.*?)</div>',
        r'<main[^>]*>(.*?)</main>',
        r'class="post-content[^"]*"[^>]*>(.*?)</div>',
        r'class="markdown-body[^"]*"[^>]*>(.*?)</div>', # GitHub/Juejin
        r'class="article-viewer[^"]*"[^>]*>(.*?)</div>',
    ]

    extracted = None
    for pat in content_patterns:
        m = re.search(pat, html_content, re.DOTALL | re.IGNORECASE)
        if m and len(m.group(1).strip()) > 200:
            extracted = m.group(0)
            break

    if not extracted:
        extracted = html_content

    # Convert to Markdown
    h = html2text.HTML2Text()
    h.ignore_links = False
    h.ignore_images = False
    h.body_width = 0
    h.ignore_emphasis = False
    h.single_line_break = False
    h.protect_links = True
    h.wrap_links = False
    h.unicode_snob = True

    md = h.handle(extracted)

    # Clean up excessive whitespace
    md = re.sub(r'\n{4,}', '\n\n\n', md)

    if len(md) > max_chars:
        md = md[:max_chars] + f"\n\n[... truncated at {max_chars} chars]"

    return md


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scrape.py <url> [max_chars]", file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    max_chars = int(sys.argv[2]) if len(sys.argv) > 2 else 30000

    try:
        result = extract(url, max_chars)
        print(result)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
