#!/usr/bin/env python3
"""枚举某公众号全部历史文章链接(通过公众号平台后台 appmsgpublish 接口)。
用法: wechat_enum.py <target_id> <token> <fakeid> <out_json>
输出 JSON 数组: [{title, link, create_time, idx}]
"""
import sys, json, subprocess, time

PROXY = "http://127.0.0.1:3456"
tid, token, fakeid, out_json = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]


def eval_js(js):
    out = subprocess.run(
        ["/usr/bin/curl", "-sS", "--noproxy", "*", "-X", "POST",
         f"{PROXY}/eval?target={tid}", "-d", js],
        capture_output=True, text=True, timeout=60).stdout
    try:
        return json.loads(out).get("value", "")
    except Exception:
        return ""


def fetch_page(begin):
    js = (
        "fetch('https://mp.weixin.qq.com/cgi-bin/appmsgpublish?sub=list&search_field=null"
        f"&begin={begin}&count=5&query=&fakeid='+encodeURIComponent('{fakeid}')+'"
        f"&type=101_1&free_publish_type=1&sub_action=list_ex&token={token}&lang=zh_CN&f=json&ajax=1'"
        ",{credentials:'include'}).then(r=>r.json()).then(d=>{"
        "if(d.base_resp&&d.base_resp.ret!==0)return JSON.stringify({err:d.base_resp.err_msg});"
        "const p=JSON.parse(d.publish_page);const out=[];"
        "(p.publish_list||[]).forEach(it=>{if(!it.publish_info)return;"
        "const a=JSON.parse(it.publish_info);(a.appmsgex||[]).forEach(m=>{"
        "out.push({title:m.title,link:m.link,create_time:m.create_time||a.sent_info&&a.sent_info.time});});});"
        "return JSON.stringify({total:p.total_count,items:out});"
        "}).catch(e=>JSON.stringify({err:String(e)}))"
    )
    raw = eval_js(js)
    try:
        return json.loads(raw)
    except Exception:
        return {"err": "parse:" + raw[:100]}


all_items = []
seen = set()
begin = 0
total = None
empty_streak = 0
while True:
    page = fetch_page(begin)
    if page.get("err"):
        print(f"[begin={begin}] ERR: {page['err']}", file=sys.stderr)
        if "freq" in page["err"] or "频" in page["err"]:
            time.sleep(20)
            continue
        break
    total = page.get("total", total)
    items = page.get("items", [])
    new = 0
    for it in items:
        link = it.get("link", "")
        if link and link not in seen:
            seen.add(link)
            all_items.append(it)
            new += 1
    print(f"[begin={begin}] got {len(items)} items, {new} new, accum={len(all_items)}, total={total}",
          file=sys.stderr)
    if not items:
        empty_streak += 1
        if empty_streak >= 2:
            break
    else:
        empty_streak = 0
    begin += 5
    if total and begin >= total:
        break
    if begin > 400:
        break
    time.sleep(1.2)

with open(out_json, "w", encoding="utf-8") as f:
    json.dump(all_items, f, ensure_ascii=False, indent=2)
print(f"DONE: {len(all_items)} articles -> {out_json}", file=sys.stderr)
print(json.dumps({"count": len(all_items), "total_records": total}, ensure_ascii=False))
