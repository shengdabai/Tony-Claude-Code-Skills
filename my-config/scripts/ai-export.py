#!/usr/bin/env python3
"""ai-export.py — 把 Claude + Codex 会话 jsonl 归一化为带 frontmatter 的 Markdown。

输出: ~/AI-Archive/normalized/{claude,codex}/<YYYY-MM>/<session>.md
特性:
  - secret redaction(sk-/ghp_/github_pat_/AKIA/xox/AIza 等)
  - 增量:已存在且源文件未更新则跳过(--force 强制重导)
  - 单文件 dry-run:--one <path> 只导一个并打印结果

用法:
  ai-export.py                # 全量增量导出
  ai-export.py --force        # 强制重导全部
  ai-export.py --one <jsonl>  # 只导一个文件(dry-run,打印到 stdout)
"""
import argparse
import datetime as dt
import json
import os
import pathlib
import re
import sys

HOME = pathlib.Path.home()
CLAUDE_DIR = HOME / ".claude" / "projects"
CODEX_DIR = HOME / ".codex" / "sessions"
OUT = pathlib.Path(os.environ.get("AI_ARCHIVE_DIR", HOME / "AI-Archive")) / "normalized"

SECRET = re.compile(
    r"(sk-[A-Za-z0-9_\-]{20,}"
    r"|ghp_[A-Za-z0-9_]{20,}"
    r"|github_pat_[A-Za-z0-9_]+"
    r"|AKIA[0-9A-Z]{16}"
    r"|AIza[0-9A-Za-z_\-]{30,}"
    r"|xox[baprs]-[A-Za-z0-9-]+"
    r"|sk-ant-[A-Za-z0-9_\-]{20,})"
)


def redact(text: str) -> str:
    return SECRET.sub("[REDACTED_SECRET]", text)


def block_to_text(content) -> str:
    """把 Claude/Codex 的 content(str 或 block list)拍平成纯文本。"""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return str(content)
    parts = []
    for b in content:
        if not isinstance(b, dict):
            parts.append(str(b))
            continue
        t = b.get("type")
        if t == "text":
            parts.append(b.get("text", ""))
        elif t in ("input_text", "output_text"):
            parts.append(b.get("text", ""))
        elif t == "tool_use":
            parts.append(f"[tool_use: {b.get('name','?')}] {json.dumps(b.get('input',{}), ensure_ascii=False)[:2000]}")
        elif t == "tool_result":
            c = b.get("content", "")
            parts.append(f"[tool_result] {block_to_text(c)[:2000]}")
        else:
            parts.append(f"[{t}]")
    return "\n".join(p for p in parts if p)


def parse_claude(path: pathlib.Path):
    """返回 (meta dict, [(role, text, ts), ...])。"""
    meta = {"tool": "claude", "session_id": path.stem}
    turns = []
    first_ts = None
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                o = json.loads(line)
            except Exception:
                continue
            if o.get("cwd") and "cwd" not in meta:
                meta["cwd"] = o["cwd"]
            if o.get("gitBranch") and "git_branch" not in meta:
                meta["git_branch"] = o["gitBranch"]
            if o.get("version") and "version" not in meta:
                meta["version"] = o["version"]
            ts = o.get("timestamp")
            if ts and not first_ts:
                first_ts = ts
            t = o.get("type")
            if t in ("user", "assistant"):
                m = o.get("message", {})
                role = m.get("role", t)
                txt = block_to_text(m.get("content", ""))
                if txt.strip():
                    turns.append((role, txt, ts))
    meta["started_at"] = first_ts or ""
    return meta, turns


def parse_codex(path: pathlib.Path):
    meta = {"tool": "codex", "session_id": path.stem}
    turns = []
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                o = json.loads(line)
            except Exception:
                continue
            t = o.get("type")
            p = o.get("payload", {})
            ts = o.get("timestamp")
            if t == "session_meta" and isinstance(p, dict):
                meta["cwd"] = p.get("cwd", "")
                meta["started_at"] = p.get("timestamp", ts) or ""
                meta["model_provider"] = p.get("model_provider", "")
            elif t == "turn_context" and isinstance(p, dict):
                if p.get("model"):
                    meta["model"] = p["model"]
            elif t == "response_item" and isinstance(p, dict):
                role = p.get("role")
                if role in ("user", "assistant"):
                    txt = block_to_text(p.get("content", ""))
                    if txt.strip():
                        turns.append((role, txt, ts))
    meta.setdefault("started_at", "")
    return meta, turns


def to_markdown(meta, turns) -> str:
    fm = ["---"]
    for k, v in meta.items():
        fm.append(f"{k}: {json.dumps(str(v), ensure_ascii=False)}")
    fm.append(f"turn_count: {len(turns)}")
    fm.append("---\n")
    body = [f"# {meta['tool']} session {meta['session_id']}\n"]
    for role, txt, ts in turns:
        head = f"## {role}" + (f"  ·  {ts}" if ts else "")
        body.append(head)
        body.append(redact(txt))
        body.append("")
    return "\n".join(fm) + "\n".join(body) + "\n"


def out_path(meta) -> pathlib.Path:
    started = meta.get("started_at", "")
    ym = started[:7] if len(started) >= 7 else "unknown"
    return OUT / meta["tool"] / ym / f"{meta['session_id']}.md"


def export_one(path: pathlib.Path, parser, force=False, dry=False):
    meta, turns = parser(path)
    if not turns:
        return None
    dest = out_path(meta)
    if not dry and not force and dest.exists():
        if dest.stat().st_mtime >= path.stat().st_mtime:
            return "skip"
    md = to_markdown(meta, turns)
    if dry:
        print(md)
        return "dry"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(md, encoding="utf-8")
    os.chmod(dest, 0o600)
    return "write"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--one", type=str, help="只导一个 jsonl(dry-run 打印)")
    args = ap.parse_args()

    if args.one:
        p = pathlib.Path(args.one)
        parser = parse_codex if "/.codex/" in str(p) or "codex" in p.name else parse_claude
        export_one(p, parser, force=True, dry=True)
        return

    stats = {"write": 0, "skip": 0, "none": 0}
    for src, parser in ((CLAUDE_DIR, parse_claude), (CODEX_DIR, parse_codex)):
        if not src.exists():
            continue
        for path in src.rglob("*.jsonl"):
            r = export_one(path, parser, force=args.force)
            if r == "write":
                stats["write"] += 1
            elif r == "skip":
                stats["skip"] += 1
            else:
                stats["none"] += 1
    print(f"导出完成: 新写 {stats['write']}, 跳过 {stats['skip']}, 空会话 {stats['none']}", file=sys.stderr)


if __name__ == "__main__":
    main()
