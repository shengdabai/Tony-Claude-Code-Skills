#!/usr/bin/env python3
"""邮件自动化主程序。

模式:
  --mode sweep   未读邮件标已读 + 广告移垃圾箱(高频,每小时)
  --mode digest  sweep + 从 buffer 读过去24h生成总结并发到 QQ(每天 8:00)
  --dry-run      只分析不动手(不标已读/不移动/不发送/不写buffer)

只处理「未读」邮件 —— 即真正打扰你的新邮件;几千封已读旧邮件不重复处理。

用法:
  python3 mail_agent.py --mode digest --dry-run
  python3 mail_agent.py --mode sweep
  python3 mail_agent.py --mode digest
"""
import argparse
import sys
import traceback
from datetime import datetime

import buffer
import config
import rules
from mail_client import MailBox


def process_account(account: dict, dry_run: bool) -> dict:
    """处理单账户未读邮件:分类 → 标已读 + 清广告 → 写 buffer。"""
    result = {
        "name": account["name"], "email": account["email"],
        "unseen": 0, "important": 0, "promo": 0,
        "marked_seen": 0, "moved": 0, "error": None, "records": [],
    }
    try:
        with MailBox(account) as mb:
            mails = mb.fetch_unseen()
            result["unseen"] = len(mails)

            seen_uids, move_uids = [], []
            for m in mails:
                cls = rules.classify(m["subject"], m["sender"], m["has_list_unsub"])
                result["records"].append({
                    "account": account["name"], "sender": m["sender"],
                    "subject": m["subject"], "cls": cls,
                })
                seen_uids.append(m["uid"])
                if cls == "promo":
                    result["promo"] += 1
                    move_uids.append(m["uid"])
                else:
                    result["important"] += 1

            if not dry_run:
                result["marked_seen"] = mb.mark_seen(seen_uids)
                result["moved"] = mb.move_to_trash(move_uids)
                buffer.append(account["name"], result["records"])
            else:
                result["marked_seen"] = len(seen_uids)
                result["moved"] = len(move_uids)
    except Exception as e:
        result["error"] = f"{type(e).__name__}: {e}"
    return result


def _esc(s: str) -> str:
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def build_digest(records: list[dict]) -> tuple[str, str, str]:
    """records: [{account, sender, subject, cls}, ...] → (subject, html, text)。"""
    from summarize import summarize

    today = datetime.now().strftime("%m/%d")
    by_acct: dict[str, list] = {}
    for r in records:
        by_acct.setdefault(r["account"], []).append(r)

    counts = " / ".join(f"{a} {len(v)}封" for a, v in by_acct.items()) or "无新邮件"
    subject = f"📬 邮件日报 {today} — {counts}"

    html = ['<div style="font-family:-apple-system,Helvetica,Arial,sans-serif;'
            'max-width:680px;margin:0 auto;color:#1a1a1a;line-height:1.6;">',
            f'<h2 style="border-bottom:2px solid #4a7;padding-bottom:8px;">'
            f'📬 邮件日报 · {today}</h2>']
    text = [f"邮件日报 {today}", "=" * 30]

    if not records:
        html.append("<p>过去 24 小时没有新邮件。😌</p>")
        text.append("过去 24 小时没有新邮件。")

    for acct, items in by_acct.items():
        important = [i for i in items if i["cls"] == "important"]
        promo = [i for i in items if i["cls"] == "promo"]
        html.append(f'<h3 style="margin-top:24px;">📧 {acct}</h3>')
        stat = f'新邮件 {len(items)} 封 · 重要 {len(important)} · 广告已清理 {len(promo)}'
        html.append(f'<p style="color:#555;">{stat}</p>')
        text.append(f"\n【{acct}】{stat}")

        imp_payload = [{"sender": i["sender"], "subject": i["subject"], "snippet": ""}
                       for i in important]
        summary = summarize(imp_payload)
        if summary:
            html.append('<div style="background:#f6f8f6;border-left:3px solid #4a7;'
                        'padding:10px 14px;white-space:pre-wrap;border-radius:4px;">'
                        + _esc(summary) + '</div>')
            text.append(summary)
        else:
            html.append("<ul>")
            for i in important[:40]:
                html.append(f'<li><b>{_esc(i["subject"])}</b> '
                            f'<span style="color:#888;">— {_esc(i["sender"])}</span></li>')
            html.append("</ul>")
            for i in important[:40]:
                text.append(f"- {i['subject']} — {i['sender']}")

        if promo:
            html.append('<details style="margin-top:10px;"><summary style="color:#999;'
                        f'cursor:pointer;">🗑 已清理广告 {len(promo)} 封'
                        '(垃圾箱,30天可恢复)</summary><ul>')
            for i in promo[:30]:
                html.append(f'<li style="color:#999;font-size:13px;">{_esc(i["subject"])}'
                            f' — {_esc(i["sender"])}</li>')
            if len(promo) > 30:
                html.append(f'<li style="color:#bbb;">…另有 {len(promo) - 30} 封</li>')
            html.append("</ul></details>")

    html.append('<p style="color:#bbb;font-size:12px;margin-top:30px;">'
                '本日报由本地邮件助手自动生成 · Ollama 本地总结</p></div>')
    return subject, "\n".join(html), "\n".join(text)


def main() -> int:
    parser = argparse.ArgumentParser(description="邮件自动化")
    parser.add_argument("--mode", choices=["sweep", "digest"], default="sweep")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--hours", type=int, default=24)
    args = parser.parse_args()

    accounts = config.get_accounts()
    if not accounts:
        print("✗ 没有配置好的账户。请先运行 python3 setup_credentials.py 填凭证。")
        return 1

    tag = "[DRY-RUN] " if args.dry_run else ""
    print(f"{tag}{datetime.now():%Y-%m-%d %H:%M} mode={args.mode} "
          f"accounts={[a['name'] for a in accounts]}", flush=True)

    results = [process_account(a, args.dry_run) for a in accounts]
    for r in results:
        if r["error"]:
            print(f"  ✗ {r['name']}: {r['error']}", flush=True)
        else:
            print(f"  ✓ {r['name']}: 未读 {r['unseen']}, 重要 {r['important']}, "
                  f"标已读 {r['marked_seen']}, 移垃圾箱 {r['moved']}", flush=True)

    if args.mode == "digest":
        smtp = config.get_smtp_config()
        if not smtp:
            print("✗ QQ SMTP 未配置,无法发送总结。")
            return 1
        if args.dry_run:
            records = [rec for r in results for rec in r["records"]]
        else:
            records = buffer.read_since(args.hours)
        subject, html, text = build_digest(records)
        if args.dry_run:
            print("\n===== 总结预览(dry-run 不发送)=====")
            print(f"主题: {subject}\n")
            print(text)
        else:
            from mailer import send
            try:
                via = send(subject, html, text, smtp, config.PHYSICAL_IFACE)
                print(f"✓ 总结已发送到 {smtp['to']}(通道:{via})")
                buffer.prune(48)
            except Exception as e:
                print(f"✗ 总结发送失败:{e}")
                traceback.print_exc()
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
