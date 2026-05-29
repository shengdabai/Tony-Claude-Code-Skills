#!/usr/bin/env python3
"""抓取单篇微信公众号文章为纯文字 markdown。
用法: wechat_grab.py <url> <out_dir>
依赖 web-access CDP proxy 已在 127.0.0.1:3456 运行。
"""
import sys, json, subprocess, re, time, os

PROXY = "http://127.0.0.1:3456"


def curl(args):
    return subprocess.run(["/usr/bin/curl", "-sS", "--noproxy", "*", *args],
                          capture_output=True, text=True, timeout=60).stdout


def new_tab(url):
    out = curl(["-X", "POST", "--data-raw", url, f"{PROXY}/new"])
    try:
        return json.loads(out).get("targetId", "")
    except Exception:
        return ""


def eval_js(tid, js):
    out = curl(["-X", "POST", f"{PROXY}/eval?target={tid}", "-d", js])
    try:
        return json.loads(out).get("value", "")
    except Exception:
        return ""


def close_tab(tid):
    curl([f"{PROXY}/close?target={tid}"])


EXTRACT = (
    'JSON.stringify({'
    'title:(document.querySelector("h1")?.innerText||document.querySelector("#activity-name")?.innerText||"").trim(),'
    'meta:(document.querySelector("#meta_content")?.innerText||document.querySelector("#js_name")?.innerText||"").replace(/\\s+/g," ").trim(),'
    'content:(document.getElementById("js_content")?.innerText||"").trim()'
    '})'
)


def sanitize(name):
    name = re.sub(r'[\\/:*?"<>|\n\r\t]', "_", name)
    name = re.sub(r"\s+", " ", name).strip()
    return name[:80] or "untitled"


def navigate(tid, url):
    curl(["-X", "POST", "--data-raw", url, f"{PROXY}/navigate?target={tid}"])


def grab(url, out_dir):
    tid = new_tab(url)
    if not tid:
        return None, "new_tab_failed"
    time.sleep(2)
    raw = ""
    navigated = False
    # 轮询等待最多 ~20s,内容出现即返回
    for attempt in range(10):
        cur = eval_js(tid, 'location.href')
        if "about:blank" in cur or "mp.weixin.qq.com/s" not in cur:
            if not navigated:
                navigate(tid, url)
                navigated = True
            time.sleep(2.5)
            continue
        raw = eval_js(tid, EXTRACT)
        try:
            if raw and len(json.loads(raw).get("content", "")) >= 50:
                break
        except Exception:
            pass
        time.sleep(2)  # 内容还没渲染完,继续轮询
    close_tab(tid)
    if not raw:
        return None, "eval_empty"
    try:
        o = json.loads(raw)
    except Exception:
        return None, "parse_failed"
    title = o.get("title", "").strip()
    content = o.get("content", "").strip()
    if not content or len(content) < 50:
        return None, f"content_short(len={len(content)})"
    meta = o.get("meta", "").strip()
    md = f"# {title}\n\n> {meta}\n>\n> 原文: {url}\n\n{content}\n"
    fname = sanitize(title) + ".md"
    path = os.path.join(out_dir, fname)
    n = 1
    while os.path.exists(path):
        path = os.path.join(out_dir, sanitize(title) + f"_{n}.md")
        n += 1
    with open(path, "w", encoding="utf-8") as f:
        f.write(md)
    return path, f"ok(len={len(content)})"


if __name__ == "__main__":
    url, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    path, status = grab(url, out_dir)
    print(json.dumps({"url": url, "path": path, "status": status}, ensure_ascii=False))
