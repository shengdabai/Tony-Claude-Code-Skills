"""IMAP 客户端封装:抓取近期邮件、标已读、移垃圾箱。

只用标准库 imaplib + email,零第三方依赖,避免安装失败。
所有抓取用 BODY.PEEK 避免意外置 \\Seen,已读状态完全由代码显式控制。
"""
from __future__ import annotations

import email
import email.message
import imaplib
import re
from datetime import datetime, timedelta, timezone
from email.header import decode_header
from email.utils import parsedate_to_datetime


def _decode_mime(value: str | None) -> str:
    """解码 =?utf-8?B?...?= 这类 MIME 编码的头字段。"""
    if not value:
        return ""
    parts = []
    for chunk, enc in decode_header(value):
        if isinstance(chunk, bytes):
            try:
                parts.append(chunk.decode(enc or "utf-8", errors="replace"))
            except (LookupError, ValueError):
                parts.append(chunk.decode("utf-8", errors="replace"))
        else:
            parts.append(chunk)
    return "".join(parts).strip()


def _extract_snippet(msg: email.message.Message, limit: int = 300) -> str:
    """从邮件正文提取纯文本片段(优先 text/plain)。"""
    body = ""
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain" and \
                    "attachment" not in str(part.get("Content-Disposition", "")):
                body = _payload_text(part)
                if body:
                    break
        if not body:
            for part in msg.walk():
                if part.get_content_type() == "text/html":
                    body = re.sub(r"<[^>]+>", " ", _payload_text(part))
                    break
    else:
        body = _payload_text(msg)
    body = re.sub(r"\s+", " ", body).strip()
    return body[:limit]


def _payload_text(part: email.message.Message) -> str:
    try:
        raw = part.get_payload(decode=True)
        if raw is None:
            return ""
        charset = part.get_content_charset() or "utf-8"
        return raw.decode(charset, errors="replace")
    except (LookupError, ValueError, TypeError):
        return ""


class MailBox:
    def __init__(self, account: dict):
        self.account = account
        self.name = account["name"]
        self.conn: imaplib.IMAP4_SSL | None = None
        self.trash_folder: str | None = None

    def __enter__(self):
        self.conn = imaplib.IMAP4_SSL(
            self.account["imap_host"], self.account["imap_port"], timeout=30
        )
        self.conn.login(self.account["email"], self.account["password"])
        # QQ 要求登录后发一条 ID 命令,否则部分操作被拒
        try:
            self.conn._simple_command(
                "ID", '("name" "mail-system" "version" "1.0")'
            )
            self.conn._untagged_response("OK", [], "ID")
        except Exception:
            pass
        return self

    def __exit__(self, *exc):
        if self.conn:
            try:
                self.conn.logout()
            except Exception:
                pass

    def _find_trash(self) -> str | None:
        if self.trash_folder:
            return self.trash_folder
        typ, data = self.conn.list()
        if typ != "OK":
            return None
        folders = []
        for raw in data:
            line = raw.decode("utf-8", errors="replace") if isinstance(raw, bytes) else raw
            # 取最后一个引号内或空格后的文件夹名
            m = re.search(r'"([^"]*)"\s*$', line) or re.search(r'(\S+)\s*$', line)
            if m:
                folders.append(m.group(1))
        for cand in self.account.get("trash_candidates", []):
            if cand in folders:
                self.trash_folder = cand
                return cand
        # 兜底:模糊匹配
        for f in folders:
            if any(k in f.lower() for k in ("trash", "deleted", "垃圾", "已删除")):
                self.trash_folder = f
                return f
        return None

    def fetch_unseen(self) -> list[dict]:
        """抓取 INBOX 全部未读邮件(= 新到、尚未处理的邮件)。

        只处理未读是关键设计:大邮箱里几千封已读旧邮件无需重复处理,
        UNSEEN 精准锁定真正打扰用户的新邮件,既快又省。
        """
        self.conn.select("INBOX")
        typ, data = self.conn.uid("SEARCH", None, "(UNSEEN)")
        if typ != "OK" or not data or not data[0]:
            return []
        uids = data[0].split()

        # 批量抓 header(只取分类必需字段),逐封会在大邮箱上卡死
        fields = "(DATE FROM SUBJECT LIST-UNSUBSCRIBE)"
        spec = f"(UID FLAGS BODY.PEEK[HEADER.FIELDS {fields}])"

        results = []
        for meta, raw in self._batch_fetch(uids, spec):
            msg = email.message_from_bytes(raw)
            try:
                dt = parsedate_to_datetime(msg.get("Date"))
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
            except (TypeError, ValueError):
                dt = datetime.now(timezone.utc)
            m_uid = re.search(rb"UID (\d+)", meta)
            uid = m_uid.group(1).decode() if m_uid else ""
            if not uid:
                continue
            results.append({
                "uid": uid,
                "subject": _decode_mime(msg.get("Subject")),
                "sender": _decode_mime(msg.get("From")),
                "date": dt,
                "has_list_unsub": bool(msg.get("List-Unsubscribe")),
                "is_unread": True,
                "snippet": "",
            })
        return results

    def _batch_fetch(self, uids: list, spec: str, batch_size: int = 400):
        """批量 FETCH,返回 [(meta_bytes, body_bytes), ...]。"""
        out = []
        for i in range(0, len(uids), batch_size):
            chunk = b",".join(uids[i:i + batch_size])
            typ, data = self.conn.uid("FETCH", chunk, spec)
            if typ != "OK" or not data:
                continue
            for item in data:
                if isinstance(item, tuple) and len(item) >= 2:
                    out.append((item[0] or b"", item[1] or b""))
        return out

    def mark_seen(self, uids: list[str], batch_size: int = 400) -> int:
        if not uids:
            return 0
        self.conn.select("INBOX")
        count = 0
        for i in range(0, len(uids), batch_size):
            chunk = ",".join(uids[i:i + batch_size])
            typ, _ = self.conn.uid("STORE", chunk, "+FLAGS", "(\\Seen)")
            if typ == "OK":
                count += len(uids[i:i + batch_size])
        return count

    def move_to_trash(self, uids: list[str], batch_size: int = 400) -> int:
        if not uids:
            return 0
        trash = self._find_trash()
        if not trash:
            return 0
        self.conn.select("INBOX")
        count = 0
        for i in range(0, len(uids), batch_size):
            chunk = ",".join(uids[i:i + batch_size])
            typ, _ = self.conn.uid("COPY", chunk, f'"{trash}"')
            if typ == "OK":
                self.conn.uid("STORE", chunk, "+FLAGS", "(\\Deleted)")
                count += len(uids[i:i + batch_size])
        if count:
            self.conn.expunge()
        return count
