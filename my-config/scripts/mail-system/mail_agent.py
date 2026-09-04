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
import re
import sys
import traceback
from datetime import datetime
from email.utils import parseaddr

import buffer
import config
import rules
from mail_client import MailBox


def process_account(account: dict, dry_run: bool) -> dict:
    """处理单账户未读邮件:分类 → 标已读 + 清广告 → 写 buffer。"""
    result = {
        "name": account["name"], "email": account["email"],
        "unseen": 0, "important": 0, "promo": 0,
        "system": 0, "marked_seen": 0, "moved": 0, "error": None, "records": [],
    }
    try:
        with MailBox(account) as mb:
            mails = mb.fetch_unseen()
            result["unseen"] = len(mails)

            seen_uids, move_uids = [], []
            for m in mails:
                if m.get("is_system_digest"):
                    result["system"] += 1
                    seen_uids.append(m["uid"])
                    continue
                cls = rules.classify(m["subject"], m["sender"], m["has_list_unsub"])
                result["records"].append({
                    "account": account["name"], "sender": m["sender"],
                    "subject": m["subject"], "snippet": m.get("snippet", ""),
                    "message_id": m.get("message_id", ""), "uid": m["uid"],
                    "recipient": m.get("recipient", ""), "cls": cls,
                })
                seen_uids.append(m["uid"])
                if cls == "promo":
                    result["promo"] += 1
                    move_uids.append(m["uid"])
                else:
                    result["important"] += 1

            if not dry_run:
                # Persist first so a disk failure leaves mail unread for retry.
                buffer.append(account["name"], result["records"])
                result["marked_seen"] = mb.mark_seen(seen_uids)
                result["moved"] = mb.move_to_trash(move_uids)
            else:
                result["marked_seen"] = len(seen_uids)
                result["moved"] = len(move_uids)
    except Exception as e:
        result["error"] = f"{type(e).__name__}: {e}"
    return result


def _esc(s: str) -> str:
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def duplicate_move_plan(records: list[dict]) -> dict[str, list[str]]:
    """Move only a verified QQ copy when the Gmail original also exists."""
    groups: dict[tuple[str, str, str], list[dict]] = {}
    for record in records:
        message_id = (record.get("message_id") or "").strip().lower()
        sender = parseaddr(record.get("sender", ""))[1].lower()
        subject = re.sub(r"\s+", " ", (record.get("subject") or "").strip().lower())
        if not (message_id and sender and subject):
            continue
        groups.setdefault((message_id, sender, subject), []).append(record)

    plan: dict[str, list[str]] = {}
    for group in groups.values():
        accounts = {record.get("account") for record in group}
        if not {"Gmail", "QQ"}.issubset(accounts):
            continue
        for record in group:
            if record.get("account") == "QQ" and record.get("uid"):
                plan.setdefault("QQ", []).append(record["uid"])
    return plan


def dedupe_recent_inboxes(accounts: list[dict], hours: int, dry_run: bool) -> dict:
    """Keep one original across QQ/Gmail and move duplicate copies to trash."""
    records = []
    errors = []
    for account in accounts:
        try:
            with MailBox(account) as mailbox:
                for record in mailbox.fetch_recent(hours):
                    record["account"] = account["name"]
                    records.append(record)
        except Exception as exc:
            errors.append(f"{account['name']}: {type(exc).__name__}: {exc}")

    plan = duplicate_move_plan(records)
    found = sum(len(uids) for uids in plan.values())
    moved = 0
    if not dry_run:
        by_name = {account["name"]: account for account in accounts}
        for name, uids in plan.items():
            account = by_name.get(name)
            if not account:
                continue
            try:
                with MailBox(account) as mailbox:
                    moved += mailbox.move_to_trash(uids)
            except Exception as exc:
                errors.append(f"{name}: {type(exc).__name__}: {exc}")
    return {"scanned": len(records), "found": found, "moved": moved, "errors": errors}


def build_digest(records: list[dict], stats: dict | None = None) -> tuple[str, str, str]:
    """Build one unified, already-deduplicated digest for both inboxes."""
    from summarize import summarize_detailed

    today = datetime.now().strftime("%m/%d")
    stats = stats or {"received": len(records), "duplicates": 0, "promo": 0}
    subject = f"📬 邮件晨报 {today} — 去重后 {len(records)} 封"

    html = ['<div style="font-family:-apple-system,Helvetica,Arial,sans-serif;'
            'max-width:680px;margin:0 auto;color:#1a1a1a;line-height:1.6;">',
            f'<h2 style="border-bottom:2px solid #4a7;padding-bottom:8px;">'
            f'📬 邮件晨报 · {today}</h2>']
    stat_line = (
        f"共收到 {stats.get('received', len(records))} 封 · 去重后 {len(records)} 封 · "
        f"已抑制重复 {stats.get('duplicates', 0)} 封 · 已过滤广告 {stats.get('promo', 0)} 封"
    )
    html.append(f'<p style="color:#555;">{_esc(stat_line)}</p>')
    text = [f"邮件晨报 {today}", "=" * 30, stat_line]

    if not records:
        records = []

    summary, engine = summarize_detailed(records, stats)
    html.append('<div style="background:#f6f8f6;border-left:3px solid #4a7;'
                'padding:14px 16px;white-space:pre-wrap;border-radius:4px;">'
                + _esc(summary) + '</div>')
    text.extend(["", summary])

    html.append('<p style="color:#bbb;font-size:12px;margin-top:30px;">'
                f'摘要引擎：{_esc(engine)} · 有限正文片段在本机最多保留 96 小时</p></div>')
    text.append(f"\n摘要引擎：{engine}")
    return subject, "\n".join(html), "\n".join(text)


def main() -> int:
    parser = argparse.ArgumentParser(description="邮件自动化")
    parser.add_argument("--mode", choices=["sweep", "digest", "dedupe"], default="sweep")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--hours", type=int, default=24)
    args = parser.parse_args()

    if args.mode == "sweep" and datetime.now().hour >= 9 \
            and not buffer.digest_succeeded_today():
        print("↻ 今日晨报尚未成功，当前整点自动补发", flush=True)
        args.mode = "digest"

    accounts = config.get_accounts()
    if not accounts:
        print("✗ 没有配置好的账户。请先运行 python3 setup_credentials.py 填凭证。")
        return 1

    if args.mode == "dedupe":
        result = dedupe_recent_inboxes(accounts, args.hours, args.dry_run)
        tag = "[DRY-RUN] " if args.dry_run else ""
        print(
            f"{tag}近 {args.hours} 小时扫描 {result['scanned']} 封，"
            f"重复 {result['found']} 封，移垃圾箱 {result['moved']} 封"
        )
        for error in result["errors"]:
            print(f"  ✗ {error}")
        return 1 if result["errors"] else 0

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
        cleanup = dedupe_recent_inboxes(accounts, max(args.hours, 30), args.dry_run)
        print(
            f"  ✓ 跨邮箱去重: 扫描 {cleanup['scanned']}, "
            f"重复 {cleanup['found']}, 移垃圾箱 {cleanup['moved']}",
            flush=True,
        )
        for error in cleanup["errors"]:
            print(f"  ✗ 去重: {error}", flush=True)
        smtp = config.get_smtp_config()
        if not smtp:
            print("✗ QQ SMTP 未配置,无法发送总结。")
            return 1
        if args.dry_run:
            records = buffer.read_since(args.hours)
            records.extend(rec for result in results for rec in result["records"])
        else:
            records = buffer.read_pending(args.hours)
        unique, duplicates = buffer.deduplicate(records)
        promo = [record for record in unique if record.get("cls") == "promo"]
        readable = [record for record in unique if record.get("cls") != "promo"]
        stats = {
            "received": len(records),
            "duplicates": len(duplicates),
            "promo": len(promo),
        }
        subject, html, text = build_digest(readable, stats)
        if args.dry_run:
            print("\n===== 总结预览(dry-run 不发送)=====")
            print(f"主题: {subject}\n")
            print(text)
        else:
            from mailer import send
            try:
                via = send(subject, html, text, smtp, config.PHYSICAL_IFACE)
            except Exception as e:
                print(f"✗ 总结发送失败:{e}")
                traceback.print_exc()
                return 1
            print(f"✓ 总结已发送到 {smtp['to']}(通道:{via})")
            try:
                buffer.mark_digest_success()
                buffer.prune(96)
            except Exception as e:
                print(f"⚠ 总结已发送，但本地状态维护失败:{e}")
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
