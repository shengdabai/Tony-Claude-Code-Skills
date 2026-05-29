#!/usr/bin/env python3
"""批量抓取链接清单中的微信文章为 md。
用文件系统 + done-index 作为唯一去重真相源,不解析 ledger。
用法: wechat_batch.py <links_json> <out_dir> <ledger_md> [start] [limit]
"""
import sys, json, os, time
sys.path.insert(0, "/Users/tonysheng/.claude/scripts")
from wechat_grab import grab, sanitize

links_json, out_dir, ledger = sys.argv[1], sys.argv[2], sys.argv[3]
start = int(sys.argv[4]) if len(sys.argv) > 4 else 0
limit = int(sys.argv[5]) if len(sys.argv) > 5 else 99999

os.makedirs(out_dir, exist_ok=True)
items = json.load(open(links_json, encoding="utf-8"))

# done-index: 记录已成功抓取的 url,避免重抓
index_path = os.path.join(out_dir, ".grabbed_urls.json")
done_urls = set()
if os.path.exists(index_path):
    try:
        done_urls = set(json.load(open(index_path, encoding="utf-8")))
    except Exception:
        pass

results = []
count = 0
for i, it in enumerate(items):
    if i < start:
        continue
    if count >= limit:
        break
    link = it.get("link", "")
    title = it.get("title", "")[:50].replace("\n", " ")
    # 去重1:url 已抓过
    if link in done_urls:
        continue
    # 去重2:同名 md 已存在(且非空)
    expected = os.path.join(out_dir, sanitize(it.get("title", "")) + ".md")
    if os.path.exists(expected) and os.path.getsize(expected) > 100:
        done_urls.add(link)
        continue
    if not link.startswith("http"):
        results.append((i, title, "no_link"))
        count += 1
        continue
    path, status = grab(link, out_dir)
    if status.startswith("ok"):
        done_urls.add(link)
        json.dump(sorted(done_urls), open(index_path, "w", encoding="utf-8"),
                  ensure_ascii=False)
    results.append((i, title, status))
    print(json.dumps({"i": i, "title": title, "status": status}, ensure_ascii=False),
          flush=True)
    count += 1
    time.sleep(1.5)

ok = sum(1 for r in results if r[2].startswith("ok"))
bad = len(results) - ok
print(json.dumps({"batch_ok": ok, "batch_failed": bad, "processed": len(results),
                  "total_done": len(done_urls)}, ensure_ascii=False))
