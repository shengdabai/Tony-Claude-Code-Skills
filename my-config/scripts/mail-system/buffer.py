"""日报增量缓冲。

每次 sweep/digest 处理未读邮件时,把元数据(发件人/主题/分类)追加到 jsonl。
每天 8:00 的日报从中读取过去 24h 记录生成总结,再 prune 掉过期记录。

只存邮件元数据(非正文、非凭证)。文件在本地隐藏目录,不入 git。
"""
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

BUFFER = Path(__file__).resolve().parent / "digest_buffer.jsonl"


def append(account: str, records: list[dict]) -> None:
    if not records:
        return
    now = datetime.now(timezone.utc).isoformat()
    with BUFFER.open("a", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps({
                "ts": now,
                "account": account,
                "sender": r.get("sender", ""),
                "subject": r.get("subject", ""),
                "cls": r.get("cls", ""),
            }, ensure_ascii=False) + "\n")


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
    return [rec for rec, _ in _iter_valid(cutoff)]


def prune(hours: int = 48) -> None:
    """只保留最近 hours 小时的记录,防止文件无限增长。"""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    kept = [line for _, line in _iter_valid(cutoff)]
    BUFFER.write_text("\n".join(kept) + ("\n" if kept else ""), encoding="utf-8")
