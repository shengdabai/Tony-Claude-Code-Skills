#!/usr/bin/env python3
"""Claude Code session history viewer.

Three modes:
  1. /history <keyword>   - Search sessions by keyword (in summary + transcript content)
  2. /history             - Show last 24 hours of sessions
  3. /history all         - Show total count + last 20 sessions, with hint to expand
"""

import json
import re
import sys
import unicodedata
from datetime import datetime, timedelta, timezone
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"
TRANSCRIPTS_DIR = Path.home() / ".claude" / "transcripts"

COL_ID_WIDTH = 10
COL_SUMMARY_WIDTH = 40
COL_EXTRA_WIDTH = 32
GAP = "  "


def char_width(ch: str) -> int:
    ea = unicodedata.east_asian_width(ch)
    return 2 if ea in ("W", "F") else 1


def display_width(text: str) -> int:
    return sum(char_width(ch) for ch in text)


def truncate_to_width(text: str, max_width: int) -> str:
    text = text.replace("\n", " ").replace("\r", "").strip()
    w = 0
    for i, ch in enumerate(text):
        cw = char_width(ch)
        if w + cw > max_width - 1:
            return text[:i] + "…"
        w += cw
    return text


def pad_to_width(text: str, target_width: int) -> str:
    current = display_width(text)
    pad = target_width - current
    return text + " " * max(0, pad)


def format_ts(iso_str: str) -> str:
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        return dt.astimezone().strftime("%m-%d %H:%M")
    except Exception:
        return "—"


def parse_ts(iso_str: str):
    try:
        return datetime.fromisoformat(iso_str.replace("Z", "+00:00")).astimezone(timezone.utc)
    except Exception:
        return None


def short_id(sid: str) -> str:
    return sid.split("-")[0] if sid else "—"


SYSTEM_WRAPPER_PATTERNS = [
    # Generic: any <local-command-*>...</local-command-*> or <command-*>...</command-*>
    re.compile(r"<local-command-[a-z-]+>.*?</local-command-[a-z-]+>", re.DOTALL),
    re.compile(r"<command-[a-z-]+>.*?</command-[a-z-]+>", re.DOTALL),
    re.compile(r"<system-reminder>.*?</system-reminder>", re.DOTALL),
    re.compile(r"<user-prompt-submit-hook>.*?</user-prompt-submit-hook>", re.DOTALL),
    re.compile(r"<task-notification>.*?</task-notification>", re.DOTALL),
    re.compile(r"<task-id>.*?</task-id>", re.DOTALL),
    re.compile(r"Caveat:.*?(?=\n\n|\Z)", re.DOTALL),
]


def clean_user_prompt(text: str) -> str:
    """Strip system wrappers from a user message; return real prompt or empty."""
    if not text:
        return ""
    for pat in SYSTEM_WRAPPER_PATTERNS:
        text = pat.sub("", text)
    return text.strip()


def extract_session_data(path: Path) -> dict:
    """Extract first prompt, timestamps, message count, and full text for search."""
    first_prompt = ""
    created = ""
    modified = ""
    msg_count = 0
    text_blob_parts = []

    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                ts = entry.get("timestamp", "")
                entry_type = entry.get("type", "")

                if entry_type in ("user", "assistant"):
                    msg_count += 1
                    if ts:
                        modified = ts
                    content = ""
                    msg = entry.get("message")
                    if isinstance(msg, dict):
                        c = msg.get("content", "")
                        if isinstance(c, str):
                            content = c
                        elif isinstance(c, list):
                            for part in c:
                                if isinstance(part, dict) and part.get("type") == "text":
                                    content = part.get("text", "")
                                    break
                    if not content:
                        content = entry.get("content", "")

                    if entry_type == "user" and not first_prompt and content:
                        cleaned = clean_user_prompt(content)
                        if cleaned:
                            first_prompt = cleaned
                            created = ts
                    if content:
                        text_blob_parts.append(content[:500])
    except Exception:
        pass

    return {
        "first_prompt": first_prompt,
        "created": created,
        "modified": modified,
        "messages": msg_count,
        "text_blob": "\n".join(text_blob_parts),
        "path": str(path),
    }


def collect_sessions(need_text: bool = False) -> list[dict]:
    """Collect all sessions. need_text=True to include searchable content blob."""
    sessions = {}

    # Index files (fast path, no text blob)
    for idx_path in PROJECTS_DIR.rglob("sessions-index.json"):
        try:
            with open(idx_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            for entry in data.get("entries", []):
                sid = entry.get("sessionId", "")
                if not sid:
                    continue
                sessions[sid] = {
                    "id": sid,
                    "summary": clean_user_prompt(entry.get("firstPrompt", "")),
                    "created": entry.get("created", ""),
                    "modified": entry.get("modified", ""),
                    "messages": entry.get("messageCount", 0),
                    "project": entry.get("projectPath", ""),
                    "text_blob": "",
                    "path": "",
                }
        except Exception:
            continue

    # JSONL fallback scan
    jsonl_paths = list(PROJECTS_DIR.rglob("*.jsonl"))
    if TRANSCRIPTS_DIR.exists():
        jsonl_paths += list(TRANSCRIPTS_DIR.glob("*.jsonl"))

    for jsonl_path in jsonl_paths:
        sid = jsonl_path.stem
        existing = sessions.get(sid)
        needs_summary = existing is not None and not existing.get("summary")
        needs_text = need_text and existing is not None and not existing.get("text_blob")
        if existing is not None and not needs_summary and not needs_text:
            continue
        data = extract_session_data(jsonl_path)
        if existing is not None:
            if needs_summary and data["first_prompt"]:
                existing["summary"] = data["first_prompt"]
                if not existing.get("created"):
                    existing["created"] = data["created"]
            existing["text_blob"] = data["text_blob"]
            existing["path"] = data["path"]
            continue
        if not data["first_prompt"] and data["messages"] == 0:
            continue
        sessions[sid] = {
            "id": sid,
            "summary": data["first_prompt"],
            "created": data["created"],
            "modified": data["modified"],
            "messages": data["messages"],
            "project": "",
            "text_blob": data["text_blob"],
            "path": data["path"],
        }

    return list(sessions.values())


def project_name(path: str) -> str:
    if not path:
        return ""
    return Path(path).name or path


def format_table(rows: list[tuple], headers: tuple, widths: tuple) -> str:
    out = []

    def fmt(vals):
        return GAP.join(pad_to_width(v, w) for v, w in zip(vals, widths))

    sep = GAP.join("─" * w for w in widths)
    out.append("  " + fmt(headers))
    out.append("  " + sep)
    for r in rows:
        out.append("  " + fmt(r))
    return "\n".join(out)


def build_row(s: dict) -> tuple:
    sid = truncate_to_width(short_id(s["id"]), COL_ID_WIDTH)
    summary = truncate_to_width(s["summary"] or "—", COL_SUMMARY_WIDTH)
    proj = project_name(s.get("project", ""))
    extra_bits = []
    if proj:
        extra_bits.append(proj)
    extra_bits.append(format_ts(s["modified"]))
    extra_bits.append(f"{s['messages']}msg")
    extra = truncate_to_width(" · ".join(extra_bits), COL_EXTRA_WIDTH)
    return (sid, summary, extra)


def render(rows: list[dict], title: str, footer: str = "") -> None:
    headers = ("ID", "核心概括", "补充信息(项目·时间·消息)")
    widths = (COL_ID_WIDTH, COL_SUMMARY_WIDTH, COL_EXTRA_WIDTH)
    print()
    print(f"  {title}")
    print()
    if not rows:
        print("  (无匹配记录)")
        print()
        return
    table_rows = [build_row(s) for s in rows]
    print(format_table(table_rows, headers, widths))
    print()
    if footer:
        print(f"  {footer}")
        print()


def mode_search(keyword: str, all_sessions: list[dict]) -> None:
    pat = re.compile(re.escape(keyword), re.IGNORECASE)
    matches = []
    for s in all_sessions:
        hay = (s.get("summary", "") or "") + "\n" + (s.get("text_blob", "") or "")
        if pat.search(hay):
            matches.append(s)
    matches.sort(key=lambda s: s.get("modified", "") or "", reverse=True)
    title = f"搜索 “{keyword}” — 命中 {len(matches)} 条"
    footer = "提示:用 `/history <更长关键词>` 收窄结果,或 `claude --resume <ID 前缀>` 直接恢复会话。"
    render(matches[:30], title, footer if matches else "")


def mode_recent_24h(all_sessions: list[dict]) -> None:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    recent = []
    for s in all_sessions:
        ts = parse_ts(s.get("modified", ""))
        if ts and ts >= cutoff:
            recent.append(s)
    recent.sort(key=lambda s: s.get("modified", "") or "", reverse=True)
    title = f"过去 24 小时会话 — 共 {len(recent)} 条"
    footer = "提示:用 `/history <关键词>` 搜索,或 `/history all` 查看全部。"
    render(recent, title, footer)


def mode_all(all_sessions: list[dict]) -> None:
    all_sessions.sort(key=lambda s: s.get("modified", "") or "", reverse=True)
    total = len(all_sessions)
    title = f"全部会话历史 — 共 {total} 条,显示最近 20 条"
    footer = (
        "提示:输入 `/history <关键词>` 直接搜索;`/history all <N>` 显示更多(如 `/history all 100`)。"
    )
    render(all_sessions[:20], title, footer)


def mode_all_n(all_sessions: list[dict], n: int) -> None:
    all_sessions.sort(key=lambda s: s.get("modified", "") or "", reverse=True)
    total = len(all_sessions)
    title = f"全部会话历史 — 共 {total} 条,显示最近 {min(n, total)} 条"
    render(all_sessions[:n], title)


def main():
    args = sys.argv[1:]

    # Parse args
    if not args:
        # Mode 2: last 24h
        sessions = collect_sessions(need_text=False)
        mode_recent_24h(sessions)
        return

    first = args[0].lower()

    if first == "all":
        sessions = collect_sessions(need_text=False)
        if len(args) >= 2:
            try:
                n = int(args[1])
                mode_all_n(sessions, n)
                return
            except ValueError:
                pass
        mode_all(sessions)
        return

    # Numeric-only legacy: /history 50
    if len(args) == 1 and first.isdigit():
        sessions = collect_sessions(need_text=False)
        mode_all_n(sessions, int(first))
        return

    # Mode 1: keyword search (joins all args as one keyword phrase)
    keyword = " ".join(args).strip()
    sessions = collect_sessions(need_text=True)
    mode_search(keyword, sessions)


if __name__ == "__main__":
    main()
