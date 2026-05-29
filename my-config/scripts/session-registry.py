#!/usr/bin/env python3
"""session-registry.py — Claude Code SessionStart/SessionEnd hook 注册器。

stdin 收 hook JSON(session_id, cwd, hook_event_name),维护
~/.claude/state/sessions-registry.json。退出码永远 0,绝不阻塞 claude。
"""
import json
import os
import sys
import datetime

REG = os.path.expanduser("~/.claude/state/sessions-registry.json")


def main():
    os.makedirs(os.path.dirname(REG), exist_ok=True)
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    if not isinstance(data, dict):
        return

    sid = data.get("session_id") or data.get("sessionId")
    if not sid:
        return
    cwd = data.get("cwd") or os.getcwd()
    event = (data.get("hook_event_name") or data.get("hookEventName") or "").lower()
    tty = os.environ.get("REGISTRY_TTY", "")
    now = datetime.datetime.now().astimezone().isoformat()

    reg = {}
    try:
        with open(REG, encoding="utf-8") as fh:
            reg = json.load(fh)
        if not isinstance(reg, dict):
            reg = {}
    except Exception:
        reg = {}

    entry = reg.get(sid, {})
    entry.setdefault("session_id", sid)
    entry["cwd"] = cwd
    entry["last_seen"] = now
    if tty:
        entry["tty"] = tty
    if "end" in event:
        entry["status"] = "closed"
        entry["ended_at"] = now
    else:
        entry["status"] = "open"
        entry.setdefault("started", now)
    reg[sid] = entry

    tmp = REG + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(reg, fh, ensure_ascii=False, indent=2)
        os.replace(tmp, REG)
        os.chmod(REG, 0o600)
    except Exception:
        pass


if __name__ == "__main__":
    main()
