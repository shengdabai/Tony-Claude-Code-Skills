#!/usr/bin/env python3
"""agent-proposal: agents propose edits as reviewable diffs instead of overwriting files.

Protocol (inspired by the proposal mechanism in xiaolai/sonovo, re-implemented from
scratch, stdlib only):

* An agent never rewrites a protected document in place. It writes a proposal file
  beside it: ``<dir>/.<name>.proposal.diff``.
* The proposal carries a header (version, document name, SHA-256 of the document bytes
  it was computed against, optional author and summary) followed by a unified diff.
* The human (or a reviewing agent) lists the hunks, accepts some or all of them, and
  the accepted hunks are applied as ordinary edits with a backup copy. The proposal
  file holds no hidden state: it can be read, diffed and deleted by hand.
* A proposal whose base hash no longer matches the document is *stale*. Stale
  proposals are refused unless ``--rebase`` is given, in which case every hunk whose
  context still matches exactly is applied and the rest are reported as out of date.

Exit codes: 0 ok, 1 usage / nothing to do, 2 stale base, 3 malformed proposal,
4 document missing or unreadable, 5 hunk conflict (out of date / overlapping).
"""
from __future__ import annotations

import argparse
import datetime as _dt
import difflib
import hashlib
import json
import os
import re
import sys
import tempfile
from collections.abc import Iterable
from dataclasses import dataclass, field
from pathlib import Path

VERSION = 1
MAX_PROPOSAL_BYTES = 5 * 1024 * 1024
HEADER_PREFIX = "# agent-proposal"
HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")
SKIP_DIRS = {".git", ".git.nosync", "node_modules", ".venv", "__pycache__", ".build", "dist", ".next"}


class ProposalError(Exception):
    code = 3


class StaleBase(ProposalError):
    code = 2


class Malformed(ProposalError):
    code = 3


class DocumentUnreadable(ProposalError):
    code = 4


class HunkConflict(ProposalError):
    code = 5


# --------------------------------------------------------------------------- model


@dataclass
class Hunk:
    index: int  # 1-based position in the proposal
    old_start: int
    old_count: int
    new_start: int
    new_count: int
    section: str
    old_lines: list[str]
    new_lines: list[str]
    old_last_has_newline: bool = True
    new_last_has_newline: bool = True

    @property
    def old_index(self) -> int:
        """0-based splice position in the source line array."""
        return self.old_start - 1 if self.old_count else self.old_start

    def display_lines(self) -> list[tuple[str, str]]:
        """Context edges, then removed lines, then added lines (a display projection)."""
        out: list[tuple[str, str]] = []
        matcher = difflib.SequenceMatcher(a=self.old_lines, b=self.new_lines, autojunk=False)
        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag == "equal":
                out.extend((" ", line) for line in self.old_lines[i1:i2])
            else:
                out.extend(("-", line) for line in self.old_lines[i1:i2])
                out.extend(("+", line) for line in self.new_lines[j1:j2])
        if self.old_lines == self.new_lines and self.old_last_has_newline != self.new_last_has_newline:
            out.append(("\\", "No newline at end of file" + (" (added)" if self.new_last_has_newline else " (removed)")))
        return out


@dataclass
class Proposal:
    version: int
    document_name: str
    base_hash: str
    hunks: list[Hunk]
    author: str = ""
    summary: str = ""
    created: str = ""
    extra: dict = field(default_factory=dict)

    def matches(self, data: bytes) -> bool:
        return sha256(data) == self.base_hash


# ------------------------------------------------------------------------ helpers


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def proposal_path(document: Path) -> Path:
    return document.parent / f".{document.name}.proposal.diff"


def read_document(document: Path) -> bytes:
    try:
        return document.read_bytes()
    except OSError as exc:  # pragma: no cover - exercised via CLI
        raise DocumentUnreadable(f"cannot read {document}: {exc.strerror}") from exc


def split_lines(text: str) -> tuple[list[str], bool]:
    """Split into lines without terminators; report whether the text ended with a newline."""
    if text == "":
        return [], True
    lines = text.split("\n")
    has_newline = text.endswith("\n")
    if has_newline:
        lines.pop()
    return lines, has_newline


def join_lines(lines: list[str], trailing_newline: bool) -> str:
    if not lines:
        return ""
    text = "\n".join(lines)
    return text + "\n" if trailing_newline else text


def decode(data: bytes, what: str) -> str:
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise DocumentUnreadable(f"{what} is not UTF-8 text: {exc}") from exc


# --------------------------------------------------------------- diff generation


def build_hunks(old_text: str, new_text: str, context: int = 3) -> list[Hunk]:
    old_lines, old_nl = split_lines(old_text)
    new_lines, new_nl = split_lines(new_text)
    hunks: list[Hunk] = []
    matcher = difflib.SequenceMatcher(a=old_lines, b=new_lines, autojunk=False)
    for n, group in enumerate(matcher.get_grouped_opcodes(context), start=1):
        first, last = group[0], group[-1]
        i1, i2, j1, j2 = first[1], last[2], first[3], last[4]
        h = Hunk(
            index=n,
            old_start=i1 + 1 if i2 > i1 else i1,
            old_count=i2 - i1,
            new_start=j1 + 1 if j2 > j1 else j1,
            new_count=j2 - j1,
            section="",
            old_lines=old_lines[i1:i2],
            new_lines=new_lines[j1:j2],
        )
        if i2 == len(old_lines):
            h.old_last_has_newline = old_nl
        if j2 == len(new_lines):
            h.new_last_has_newline = new_nl
        hunks.append(h)
    reaches_end = bool(hunks) and hunks[-1].old_index + hunks[-1].old_count >= len(old_lines)
    if old_nl != new_nl and old_lines and new_lines and not reaches_end:
        # The final newline changed outside every hunk's reach: encode it as a
        # one-line hunk on the last line so the flag travels with the diff.
        hunks.append(Hunk(len(hunks) + 1, len(old_lines), 1, len(new_lines), 1, "", old_lines[-1:], new_lines[-1:], old_nl, new_nl))
    return hunks


def render(proposal: Proposal) -> str:
    out = [f"{HEADER_PREFIX} v{proposal.version}", f"# document: {proposal.document_name}", f"# base-sha256: {proposal.base_hash}"]
    if proposal.author:
        out.append(f"# author: {proposal.author}")
    if proposal.summary:
        out.append(f"# summary: {proposal.summary}")
    out.append(f"# created: {proposal.created or _dt.datetime.now(_dt.timezone.utc).isoformat(timespec='seconds')}")
    out.append(f"--- a/{proposal.document_name}")
    out.append(f"+++ b/{proposal.document_name}")
    for h in proposal.hunks:
        old_range = f"{h.old_start}" if h.old_count == 1 else f"{h.old_start},{h.old_count}"
        new_range = f"{h.new_start}" if h.new_count == 1 else f"{h.new_start},{h.new_count}"
        out.append(f"@@ -{old_range} +{new_range} @@{(' ' + h.section) if h.section else ''}")
        matcher = difflib.SequenceMatcher(a=h.old_lines, b=h.new_lines, autojunk=False)
        nl_changed = h.old_last_has_newline != h.new_last_has_newline
        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag == "equal":
                for k in range(i1, i2):
                    is_last = k == len(h.old_lines) - 1 and j1 + (k - i1) == len(h.new_lines) - 1
                    if is_last and nl_changed:
                        # Same text, different final newline: show it as a replace so the
                        # marker lands on the side that lacks the newline.
                        out.append("-" + h.old_lines[k])
                        if not h.old_last_has_newline:
                            out.append("\\ No newline at end of file")
                        out.append("+" + h.old_lines[k])
                        if not h.new_last_has_newline:
                            out.append("\\ No newline at end of file")
                        continue
                    out.append(" " + h.old_lines[k])
                    if is_last and not h.old_last_has_newline:
                        out.append("\\ No newline at end of file")
                continue
            for k in range(i1, i2):
                out.append("-" + h.old_lines[k])
                if k == len(h.old_lines) - 1 and not h.old_last_has_newline:
                    out.append("\\ No newline at end of file")
            for k in range(j1, j2):
                out.append("+" + h.new_lines[k])
                if k == len(h.new_lines) - 1 and not h.new_last_has_newline:
                    out.append("\\ No newline at end of file")
    return "\n".join(out) + "\n"


# ------------------------------------------------------------------------ parsing


def parse(text: str) -> Proposal:
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if not lines or not lines[0].startswith(HEADER_PREFIX):
        raise Malformed("missing agent-proposal header")
    m = re.match(rf"^{re.escape(HEADER_PREFIX)} v(\d+)$", lines[0])
    if not m:
        raise Malformed("bad header line")
    version = int(m.group(1))
    if version != VERSION:
        raise Malformed(f"unsupported proposal version {version}")
    meta: dict[str, str] = {}
    i = 1
    while i < len(lines) and lines[i].startswith("# "):
        key, _, value = lines[i][2:].partition(":")
        meta[key.strip()] = value.strip()
        i += 1
    if "document" not in meta or "base-sha256" not in meta:
        raise Malformed("header lacks document or base-sha256")
    if not re.fullmatch(r"[0-9a-f]{64}", meta["base-sha256"]):
        raise Malformed("base-sha256 is not a 64-hex digest")
    if i + 1 >= len(lines) or not lines[i].startswith("--- ") or not lines[i + 1].startswith("+++ "):
        raise Malformed("missing ---/+++ file lines")
    i += 2
    hunks: list[Hunk] = []
    while i < len(lines):
        hm = HUNK_RE.match(lines[i])
        if not hm:
            raise Malformed(f"expected hunk header at line {i + 1}")
        old_start, old_count = int(hm.group(1)), int(hm.group(2)) if hm.group(2) is not None else 1
        new_start, new_count = int(hm.group(3)), int(hm.group(4)) if hm.group(4) is not None else 1
        section = hm.group(5).strip()
        i += 1
        old_lines: list[str] = []
        new_lines: list[str] = []
        old_nl = new_nl = True
        last_side = ""
        while i < len(lines) and not HUNK_RE.match(lines[i]):
            line = lines[i]
            if line.startswith("\\"):
                if last_side in ("-", " "):
                    old_nl = False
                if last_side in ("+", " "):
                    new_nl = False
            elif line.startswith(" "):
                old_lines.append(line[1:])
                new_lines.append(line[1:])
                last_side = " "
            elif line.startswith("-"):
                old_lines.append(line[1:])
                last_side = "-"
            elif line.startswith("+"):
                new_lines.append(line[1:])
                last_side = "+"
            elif line == "":
                # Tolerate a blank context line that lost its leading space.
                old_lines.append("")
                new_lines.append("")
                last_side = " "
            else:
                raise Malformed(f"unexpected line {i + 1} in hunk {len(hunks) + 1}")
            i += 1
        if len(old_lines) != old_count or len(new_lines) != new_count:
            raise Malformed(f"hunk {len(hunks) + 1} counts do not match its lines")
        hunks.append(Hunk(len(hunks) + 1, old_start, old_count, new_start, new_count, section, old_lines, new_lines, old_nl, new_nl))
    return Proposal(version, meta["document"], meta["base-sha256"], hunks, meta.get("author", ""), meta.get("summary", ""), meta.get("created", ""))


def load(path: Path) -> Proposal:
    try:
        size = path.stat().st_size
    except OSError as exc:
        raise Malformed(f"cannot read proposal {path}: {exc.strerror}") from exc
    if size > MAX_PROPOSAL_BYTES:
        raise Malformed(f"proposal is {size} bytes; the limit is {MAX_PROPOSAL_BYTES}")
    return parse(decode(path.read_bytes(), "proposal"))


# ----------------------------------------------------------------------- applying


def hunk_matches(source: list[str], source_nl: bool, h: Hunk, total: int) -> bool:
    idx = h.old_index
    if idx < 0 or idx + h.old_count > total:
        return False
    if source[idx : idx + h.old_count] != h.old_lines:
        return False
    at_end = idx + h.old_count == total and h.old_count
    return not (at_end and h.old_last_has_newline != source_nl)


def apply_hunks(text: str, hunks: Iterable[Hunk], *, strict: bool = True) -> tuple[str, list[int]]:
    """Apply hunks (any order) to text. Returns new text and indexes of hunks skipped.

    strict=True raises HunkConflict on the first hunk whose context no longer matches;
    strict=False skips such hunks and reports them.
    """
    source, source_nl = split_lines(text)
    total = len(source)
    chosen = sorted(hunks, key=lambda h: h.old_index)
    for a, b in zip(chosen, chosen[1:]):  # successive pairs; itertools.pairwise needs 3.10+, Apple's python3 is 3.9
        if a.old_index + a.old_count > b.old_index:
            raise HunkConflict(f"hunks {a.index} and {b.index} overlap")
    skipped: list[int] = []
    out: list[str] = []
    cursor = 0
    out_nl = source_nl
    for h in chosen:
        if not hunk_matches(source, source_nl, h, total):
            if strict:
                raise HunkConflict(f"hunk {h.index} is out of date: the document changed at lines {h.old_start}-{h.old_start + max(h.old_count, 1) - 1}")
            skipped.append(h.index)
            continue
        out.extend(source[cursor : h.old_index])
        out.extend(h.new_lines)
        cursor = h.old_index + h.old_count
        if cursor == total:
            out_nl = h.new_last_has_newline
    out.extend(source[cursor:])
    return join_lines(out, out_nl), skipped


def atomic_write(path: Path, data: bytes) -> None:
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        try:
            os.chmod(tmp, path.stat().st_mode & 0o7777)
        except OSError:
            pass
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def backup(document: Path, data: bytes, backup_dir: Path) -> Path:
    stamp = _dt.datetime.now().strftime("%Y%m%dT%H%M%S")
    digest = sha256(str(document.resolve()).encode())[:12]
    target = backup_dir / f"{document.name}.{stamp}.{digest}.bak"
    backup_dir.mkdir(parents=True, exist_ok=True)
    atomic_write(target, data)
    return target


def default_backup_dir() -> Path:
    base = os.environ.get("AGENT_PROPOSAL_BACKUP_DIR")
    if base:
        return Path(base).expanduser()
    xdg = os.environ.get("XDG_CACHE_HOME")
    root = Path(xdg).expanduser() if xdg else Path.home() / ".cache"
    return root / "agent-proposal" / "backups"


# -------------------------------------------------------------------------- CLI


def parse_hunk_selection(spec: str, total: int) -> list[int]:
    chosen: set[int] = set()
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, _, b = part.partition("-")
            lo, hi = int(a), int(b)
            if lo < 1 or hi > total or lo > hi:
                raise ProposalError(f"hunk range {part} is outside 1-{total}")
            chosen.update(range(lo, hi + 1))
        else:
            n = int(part)
            if n < 1 or n > total:
                raise ProposalError(f"hunk {n} is outside 1-{total}")
            chosen.add(n)
    if not chosen:
        raise ProposalError("no hunks selected")
    return sorted(chosen)


def cmd_propose(args: argparse.Namespace) -> int:
    document = Path(args.document)
    if not document.is_file():
        raise DocumentUnreadable(f"document not found: {document}")
    old_bytes = read_document(document)
    if args.new:
        new_bytes = Path(args.new).read_bytes()
    else:
        new_bytes = sys.stdin.buffer.read()
    old_text = decode(old_bytes, str(document))
    new_text = decode(new_bytes, "new content")
    target = proposal_path(document)
    if target.exists() and not args.force:
        print(f"proposal already exists: {target} (use --force to replace, or `reject` first)", file=sys.stderr)
        return 1
    hunks = build_hunks(old_text, new_text, args.context)
    if not hunks:
        print("no changes: the new content equals the document", file=sys.stderr)
        return 1
    proposal = Proposal(VERSION, document.name, sha256(old_bytes), hunks, args.author or "", args.summary or "")
    atomic_write(target, render(proposal).encode("utf-8"))
    print(f"wrote {target} ({len(hunks)} hunk{'s' if len(hunks) != 1 else ''})")
    print(f"review: {prog_name()} show {shell_quote(str(document))}")
    return 0


def status_of(proposal: Proposal, data: bytes) -> tuple[str, list[int]]:
    text = decode(data, "document")
    source, source_nl = split_lines(text)
    stale = not proposal.matches(data)
    out_of_date = [h.index for h in proposal.hunks if not hunk_matches(source, source_nl, h, len(source))]
    return ("stale" if stale else "fresh"), out_of_date


def cmd_show(args: argparse.Namespace) -> int:
    document = Path(args.document)
    target = proposal_path(document)
    if not target.is_file():
        print(f"no proposal for {document.name} (expected {target})", file=sys.stderr)
        return 1
    proposal = load(target)
    data = read_document(document)
    state, out_of_date = status_of(proposal, data)
    if args.json:
        payload = {
            "document": str(document),
            "proposal": str(target),
            "state": state,
            "author": proposal.author,
            "summary": proposal.summary,
            "created": proposal.created,
            "hunks": [
                {
                    "index": h.index,
                    "old_start": h.old_start,
                    "old_count": h.old_count,
                    "new_start": h.new_start,
                    "new_count": h.new_count,
                    "applicable": h.index not in out_of_date,
                    "lines": [{"kind": k, "text": t} for k, t in h.display_lines()],
                }
                for h in proposal.hunks
            ],
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0 if state == "fresh" else 2
    head = f"{document.name}: {len(proposal.hunks)} hunk{'s' if len(proposal.hunks) != 1 else ''}, base {state}"
    if proposal.author:
        head += f", by {proposal.author}"
    print(head)
    if proposal.summary:
        print(f"summary: {proposal.summary}")
    for h in proposal.hunks:
        flag = "" if h.index not in out_of_date else "  [out of date]"
        print(f"\n--- hunk {h.index}: lines {h.old_start}-{h.old_start + max(h.old_count, 1) - 1} -> {h.new_count} line{'s' if h.new_count != 1 else ''}{flag}")
        for kind, text in h.display_lines():
            print(f"{kind} {text}")
    print(f"\napply: {prog_name()} apply {shell_quote(str(document))} --hunks 1,2  |  --all  |  reject")
    return 0 if state == "fresh" else 2


def cmd_check(args: argparse.Namespace) -> int:
    document = Path(args.document)
    target = proposal_path(document)
    if not target.is_file():
        print("none")
        return 1
    proposal = load(target)
    state, out_of_date = status_of(proposal, read_document(document))
    print(f"{state} {len(proposal.hunks)} hunks" + (f", out of date: {','.join(map(str, out_of_date))}" if out_of_date else ""))
    return 0 if state == "fresh" else 2


def cmd_apply(args: argparse.Namespace) -> int:
    document = Path(args.document)
    target = proposal_path(document)
    if not target.is_file():
        print(f"no proposal for {document.name}", file=sys.stderr)
        return 1
    proposal = load(target)
    data = read_document(document)
    text = decode(data, str(document))
    stale = not proposal.matches(data)
    if stale and not args.rebase:
        raise StaleBase(f"{document.name} changed since the proposal was written; run `show` to inspect, or `apply --rebase` to apply only the hunks whose context still matches")
    if args.all:
        selected = proposal.hunks
    elif args.hunks:
        chosen = parse_hunk_selection(args.hunks, len(proposal.hunks))
        selected = [h for h in proposal.hunks if h.index in chosen]
    else:
        print("choose --all or --hunks N[,M-K]", file=sys.stderr)
        return 1
    new_text, skipped = apply_hunks(text, selected, strict=not args.rebase)
    applied = [h.index for h in selected if h.index not in skipped]
    if not applied:
        raise HunkConflict("nothing applied: every selected hunk is out of date")
    if args.dry_run:
        print(f"would apply hunks {','.join(map(str, applied))}" + (f"; skipped {','.join(map(str, skipped))}" if skipped else ""))
        return 0
    backup_path = backup(document, data, Path(args.backup_dir).expanduser() if args.backup_dir else default_backup_dir())
    new_bytes = new_text.encode("utf-8")
    atomic_write(document, new_bytes)
    # Remaining hunks: the proposal's full intent minus what was just applied, rebased on the new document.
    remaining_text = ""
    try:
        full_text, _ = apply_hunks(text, proposal.hunks, strict=True) if not stale else (None, [])
    except HunkConflict:
        full_text = None
    if full_text is not None:
        remaining = build_hunks(new_text, full_text, args.context)
        if remaining and not args.discard_rest:
            rest = Proposal(VERSION, document.name, sha256(new_bytes), remaining, proposal.author, proposal.summary)
            atomic_write(target, render(rest).encode("utf-8"))
            remaining_text = f"; {len(remaining)} hunk{'s' if len(remaining) != 1 else ''} remain in {target.name}"
        else:
            target.unlink(missing_ok=True)
    else:
        target.unlink(missing_ok=True)
        if stale:
            remaining_text = "; proposal removed (base was stale)"
    print(f"applied hunks {','.join(map(str, applied))} to {document}" + (f"; skipped out-of-date {','.join(map(str, skipped))}" if skipped else "") + remaining_text)
    print(f"backup: {backup_path}")
    return 0


def cmd_reject(args: argparse.Namespace) -> int:
    target = proposal_path(Path(args.document))
    if not target.is_file():
        print("no proposal to reject", file=sys.stderr)
        return 1
    target.unlink()
    print(f"removed {target}")
    return 0


def iter_proposals(root: Path) -> Iterable[Path]:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.startswith(".") and name.endswith(".proposal.diff"):
                yield Path(dirpath) / name


def cmd_list(args: argparse.Namespace) -> int:
    root = Path(args.root or ".")
    rows = []
    for p in sorted(iter_proposals(root)):
        document = p.parent / p.name[1 : -len(".proposal.diff")]
        try:
            proposal = load(p)
        except ProposalError as exc:
            rows.append({"proposal": str(p), "document": str(document), "state": "malformed", "hunks": 0, "error": str(exc)})
            continue
        if document.is_file():
            state, out_of_date = status_of(proposal, read_document(document))
        else:
            state, out_of_date = "document-missing", []
        rows.append({"proposal": str(p), "document": str(document), "state": state, "hunks": len(proposal.hunks), "out_of_date": out_of_date, "author": proposal.author, "summary": proposal.summary, "created": proposal.created})
    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    else:
        if not rows:
            print("no proposals")
        for r in rows:
            extra = f" ({r['error']})" if r.get("error") else ""
            print(f"{r['state']:<16} {r['hunks']:>3} hunks  {r['document']}{extra}")
    return 0


def prog_name() -> str:
    return os.environ.get("AGENT_PROPOSAL_PROG") or (Path(sys.argv[0]).name if sys.argv and sys.argv[0] else "proposal.py")


def shell_quote(s: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_./~+:@%-]+", s):
        return s
    return "'" + s.replace("'", "'\\''") + "'"


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog=prog_name(), description=__doc__.split("\n\n")[0])
    sub = p.add_subparsers(dest="command", required=True)

    sp = sub.add_parser("propose", help="write .<doc>.proposal.diff from new content (file or stdin)")
    sp.add_argument("document")
    sp.add_argument("--new", help="file holding the proposed full content; default: stdin")
    sp.add_argument("--author", help="who proposes (e.g. claude, codex, article-pipeline)")
    sp.add_argument("--summary", help="one-line intent")
    sp.add_argument("--context", type=int, default=3)
    sp.add_argument("--force", action="store_true", help="replace an existing proposal")
    sp.set_defaults(func=cmd_propose)

    sp = sub.add_parser("show", help="print hunks and whether the base is still fresh")
    sp.add_argument("document")
    sp.add_argument("--json", action="store_true")
    sp.set_defaults(func=cmd_show)

    sp = sub.add_parser("check", help="exit 0 fresh, 1 none, 2 stale, 3 malformed")
    sp.add_argument("document")
    sp.set_defaults(func=cmd_check)

    sp = sub.add_parser("apply", help="apply accepted hunks with a backup; leftovers stay as a rebased proposal")
    sp.add_argument("document")
    sp.add_argument("--hunks", help="e.g. 1,3 or 2-4")
    sp.add_argument("--all", action="store_true")
    sp.add_argument("--rebase", action="store_true", help="stale base: apply hunks whose context still matches, skip the rest")
    sp.add_argument("--dry-run", action="store_true")
    sp.add_argument("--discard-rest", action="store_true", help="delete the proposal even if unapplied hunks remain")
    sp.add_argument("--backup-dir", help="default $AGENT_PROPOSAL_BACKUP_DIR or ~/.cache/agent-proposal/backups")
    sp.add_argument("--context", type=int, default=3)
    sp.set_defaults(func=cmd_apply)

    sp = sub.add_parser("reject", help="delete the proposal without touching the document")
    sp.add_argument("document")
    sp.set_defaults(func=cmd_reject)

    sp = sub.add_parser("list", help="find proposals under a directory")
    sp.add_argument("root", nargs="?")
    sp.add_argument("--json", action="store_true")
    sp.set_defaults(func=cmd_list)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except ProposalError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return exc.code
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
