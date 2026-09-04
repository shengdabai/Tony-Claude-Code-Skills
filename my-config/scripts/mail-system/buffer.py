"""日报增量缓冲。

每次 sweep/digest 处理未读邮件时,把发件人/主题/分类及有限正文片段追加到 jsonl。
每天 8:00 的日报从中读取过去 24h 记录生成总结,再 prune 掉过期记录。

不存附件或凭证；正文片段最多保留 96 小时并强制 0600 权限。
"""
import hashlib
import fcntl
import json
import os
import re
import tempfile
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from email.utils import parseaddr
from pathlib import Path

BUFFER = Path(__file__).resolve().parent / "digest_buffer.jsonl"
LOCK_FILE = Path(__file__).resolve().parent / ".buffer.lock"
STATE_FILE = Path(__file__).resolve().parent / ".digest_state.json"


@contextmanager
def _locked(exclusive: bool = True):
    LOCK_FILE.touch(mode=0o600, exist_ok=True)
    os.chmod(LOCK_FILE, 0o600)
    with LOCK_FILE.open("r+") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
        yield


def append(account: str, records: list[dict]) -> None:
    if not records:
        return
    now = datetime.now(timezone.utc).isoformat()
    with _locked():
        existing = set()
        if BUFFER.exists():
            for line in BUFFER.read_text(encoding="utf-8").splitlines():
                try:
                    old = json.loads(line)
                    existing.add((old.get("account"), old.get("message_id"), old.get("uid")))
                except json.JSONDecodeError:
                    continue
        BUFFER.touch(mode=0o600, exist_ok=True)
        os.chmod(BUFFER, 0o600)
        with BUFFER.open("a", encoding="utf-8") as f:
            for r in records:
                key = (account, r.get("message_id", ""), r.get("uid", ""))
                if key in existing and any(key[1:]):
                    continue
                record = {
                    "ts": now,
                    "account": account,
                    "sender": r.get("sender", ""),
                    "subject": r.get("subject", ""),
                    "snippet": r.get("snippet", ""),
                    "cls": r.get("cls", ""),
                    "message_id": r.get("message_id", ""),
                    "uid": r.get("uid", ""),
                }
                f.write(json.dumps(record, ensure_ascii=False) + "\n")
                existing.add(key)
            f.flush()
            os.fsync(f.fileno())


def _normalized_subject(subject: str) -> str:
    value = (subject or "").strip().lower()
    value = re.sub(r"^(?:(?:re|fw|fwd)\s*:|回复\s*:|转发\s*:)+\s*", "", value)
    return re.sub(r"\s+", " ", value)


def _normalized_snippet(snippet: str) -> str:
    value = (snippet or "").strip().lower()
    value = re.sub(r"\b(user|uid|token|id)=[\w.-]+", r"\1=", value)
    value = re.sub(r"https?://\S+", "<url>", value)
    return re.sub(r"\s+", " ", value)[:1600]


def content_fingerprint(record: dict) -> str:
    sender = parseaddr(record.get("sender", ""))[1].lower()
    parts = [
        sender,
        _normalized_subject(record.get("subject", "")),
        _normalized_snippet(record.get("snippet", "")),
    ]
    return hashlib.sha256("\n".join(parts).encode("utf-8")).hexdigest()


def deduplicate(records: list[dict]) -> tuple[list[dict], list[dict]]:
    """Keep one original copy; prefer Gmail over its QQ-forwarded copy."""
    ranked = sorted(
        enumerate(records),
        key=lambda pair: (
            0 if pair[1].get("account") == "Gmail" else 1,
            -len(pair[1].get("snippet", "")),
            pair[0],
        ),
    )
    exact_seen: set[str] = set()
    content_seen: set[str] = set()
    unique: list[dict] = []
    duplicates: list[dict] = []
    for _, record in ranked:
        message_id = (record.get("message_id") or "").strip().lower()
        normalized_snippet = _normalized_snippet(record.get("snippet", ""))
        allow_content = (
            record.get("cls") not in {"urgent", "action"}
            and len(normalized_snippet) >= 80
        )
        content_key = content_fingerprint(record) if allow_content else ""
        if (message_id and message_id in exact_seen) or (
            allow_content and content_key in content_seen
        ):
            duplicates.append(record)
            continue
        if message_id:
            exact_seen.add(message_id)
        if allow_content:
            content_seen.add(content_key)
        unique.append(record)
    return unique, duplicates


def _iter_valid(cutoff: datetime):
    if not BUFFER.exists():
        return
    for line in BUFFER.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
            ts = datetime.fromisoformat(rec["ts"])
        except (ValueError, KeyError, json.JSONDecodeError):
            continue
        if ts >= cutoff:
            yield rec, line


def read_since(hours: int = 24) -> list[dict]:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    with _locked(exclusive=False):
        return [rec for rec, _ in _iter_valid(cutoff)]


def _last_success_unlocked() -> datetime | None:
    if not STATE_FILE.exists():
        return None
    try:
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        return datetime.fromisoformat(data["last_success_at"])
    except (OSError, ValueError, KeyError, json.JSONDecodeError):
        return None


def read_pending(default_hours: int = 24, max_hours: int = 96) -> list[dict]:
    """Read everything received since the last successful digest, bounded."""
    now = datetime.now(timezone.utc)
    with _locked(exclusive=False):
        last = _last_success_unlocked()
        cutoff = last if last else now - timedelta(hours=default_hours)
        cutoff = max(cutoff, now - timedelta(hours=max_hours))
        return [rec for rec, _ in _iter_valid(cutoff)]


def digest_succeeded_today() -> bool:
    with _locked(exclusive=False):
        last = _last_success_unlocked()
    return bool(last and last.astimezone().date() == datetime.now().astimezone().date())


def mark_digest_success(now: datetime | None = None) -> None:
    now = now or datetime.now(timezone.utc)
    with _locked():
        with tempfile.NamedTemporaryFile(
            "w", encoding="utf-8", dir=STATE_FILE.parent, delete=False
        ) as tmp:
            json.dump({"last_success_at": now.isoformat()}, tmp)
            tmp.flush()
            os.fsync(tmp.fileno())
            temp_path = Path(tmp.name)
        os.chmod(temp_path, 0o600)
        os.replace(temp_path, STATE_FILE)


def prune(hours: int = 48) -> None:
    """只保留最近 hours 小时的记录,防止文件无限增长。"""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    with _locked():
        kept = [line for _, line in _iter_valid(cutoff)]
        with tempfile.NamedTemporaryFile(
            "w", encoding="utf-8", dir=BUFFER.parent, delete=False
        ) as tmp:
            tmp.write("\n".join(kept) + ("\n" if kept else ""))
            tmp.flush()
            os.fsync(tmp.fileno())
            temp_path = Path(tmp.name)
        os.chmod(temp_path, 0o600)
        os.replace(temp_path, BUFFER)
