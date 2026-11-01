#!/usr/bin/env python3
"""agent-proposal: agents propose edits as reviewable diffs instead of overwriting files.

Protocol (inspired by the proposal mechanism in xiaolai/sonovo, re-implemented from
scratch, stdlib only, runs on python3 3.9+):

* An agent never rewrites a protected document in place. It writes a proposal file
  beside it: ``<dir>/.<name>.proposal.diff``.
* The proposal carries a header (version, document name, SHA-256 of the document bytes
  it was computed against, optional author and summary) followed by a unified diff.
* The human (or a reviewing agent) lists the hunks, accepts some or all of them, and
  the accepted hunks are applied as ordinary edits with a backup copy. The proposal
  file holds no hidden state: it can be read, diffed and deleted by hand.
* A proposal whose base hash no longer matches the document is *stale*. Stale
  proposals are refused unless ``--rebase`` is given, in which case every hunk whose
  context still matches exactly is applied; hunks that no longer match (or pure
  insertions, which have no anchor) are kept in ``.<name>.proposal.conflicts.diff``.

Exit codes: 0 ok, 1 usage / nothing to do, 2 stale base, 3 malformed proposal,
4 document missing / unreadable / unsafe (symlink, changed while applying), 5 hunk
conflict (out of date / overlapping / unresolved conflicts file), 6 another command holds the
document lock.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import difflib
import errno
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
HEADER_RE = re.compile(r"^# agent-proposal v(\d{1,3})$")
HUNK_RE = re.compile(r"^@@ -(\d{1,9})(?:,(\d{1,9}))? \+(\d{1,9})(?:,(\d{1,9}))? @@(.*)$")
NO_NEWLINE = "\\ No newline at end of file"
SKIP_DIRS = {".git", ".git.nosync", "node_modules", ".venv", "__pycache__", ".build", "dist", ".next"}
LOCK_SUFFIX = ".proposal.lock"
CONFLICTS_SUFFIX = ".proposal.conflicts.diff"


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


class Locked(ProposalError):
    code = 6


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
    old_last_has_newline: bool = True  # meaningful only when the hunk reaches the end of the old file
    new_last_has_newline: bool = True  # meaningful only when the hunk reaches the end of the new file

    @property
    def old_index(self) -> int:
        """0-based splice position in the source line array."""
        return self.old_start - 1 if self.old_count else self.old_start

    def _keys(self) -> tuple[list, list]:
        """Lines keyed so that 'same text, no final newline' differs from 'same text with newline'."""
        old = [(line, False) for line in self.old_lines]
        new = [(line, False) for line in self.new_lines]
        if old and not self.old_last_has_newline:
            old[-1] = (old[-1][0], True)
        if new and not self.new_last_has_newline:
            new[-1] = (new[-1][0], True)
        return old, new

    def opcodes(self):
        old, new = self._keys()
        return difflib.SequenceMatcher(a=old, b=new, autojunk=False).get_opcodes()

    def display_lines(self) -> list[tuple[str, str]]:
        """Context edges, removed lines, added lines (a display projection); newline markers inline."""
        out: list[tuple[str, str]] = []
        for tag, i1, i2, j1, j2 in self.opcodes():
            if tag == "equal":
                for k in range(i1, i2):
                    out.append((" ", self.old_lines[k]))
                    if k == len(self.old_lines) - 1 and not self.old_last_has_newline:
                        out.append(("\\", NO_NEWLINE[2:]))
            else:
                for k in range(i1, i2):
                    out.append(("-", self.old_lines[k]))
                    if k == len(self.old_lines) - 1 and not self.old_last_has_newline:
                        out.append(("\\", NO_NEWLINE[2:]))
                for k in range(j1, j2):
                    out.append(("+", self.new_lines[k]))
                    if k == len(self.new_lines) - 1 and not self.new_last_has_newline:
                        out.append(("\\", NO_NEWLINE[2:]))
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


def conflicts_path(document: Path) -> Path:
    return document.parent / f".{document.name}{CONFLICTS_SUFFIX}"


def lock_path(document: Path) -> Path:
    return document.parent / f".{document.name}{LOCK_SUFFIX}"


def check_document(document: Path) -> None:
    if document.is_symlink():
        raise DocumentUnreadable(f"{document} is a symbolic link; proposals only apply to regular files (resolve the link and target the real file)")
    if not document.is_file():
        raise DocumentUnreadable(f"document not found: {document}")


def read_document(document: Path) -> bytes:
    check_document(document)
    try:
        return document.read_bytes()
    except OSError as exc:
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
    old_keys = [(line, False) for line in old_lines]
    new_keys = [(line, False) for line in new_lines]
    if old_keys and not old_nl:
        old_keys[-1] = (old_keys[-1][0], True)
    if new_keys and not new_nl:
        new_keys[-1] = (new_keys[-1][0], True)
    hunks: list[Hunk] = []
    matcher = difflib.SequenceMatcher(a=old_keys, b=new_keys, autojunk=False)
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
        if i2 == len(old_lines) and h.old_count:
            h.old_last_has_newline = old_nl
        if j2 == len(new_lines) and h.new_count:
            h.new_last_has_newline = new_nl
        hunks.append(h)
    return hunks


def render(proposal: Proposal) -> str:
    out = [f"{HEADER_PREFIX} v{proposal.version}", f"# document: {proposal.document_name}", f"# base-sha256: {proposal.base_hash}"]
    if proposal.author:
        out.append(f"# author: {proposal.author}")
    if proposal.summary:
        out.append(f"# summary: {proposal.summary}")
    out.append(f"# created: {proposal.created or _dt.datetime.now(_dt.timezone.utc).isoformat(timespec='seconds')}")  # noqa: UP017 (3.9)
    out.append(f"--- a/{proposal.document_name}")
    out.append(f"+++ b/{proposal.document_name}")
    for h in proposal.hunks:
        old_range = f"{h.old_start}" if h.old_count == 1 else f"{h.old_start},{h.old_count}"
        new_range = f"{h.new_start}" if h.new_count == 1 else f"{h.new_start},{h.new_count}"
        out.append(f"@@ -{old_range} +{new_range} @@{(' ' + h.section) if h.section else ''}")
        for tag, i1, i2, j1, j2 in h.opcodes():
            if tag == "equal":
                for k in range(i1, i2):
                    out.append(" " + h.old_lines[k])
                    if k == len(h.old_lines) - 1 and not h.old_last_has_newline:
                        out.append(NO_NEWLINE)
                continue
            for k in range(i1, i2):
                out.append("-" + h.old_lines[k])
                if k == len(h.old_lines) - 1 and not h.old_last_has_newline:
                    out.append(NO_NEWLINE)
            for k in range(j1, j2):
                out.append("+" + h.new_lines[k])
                if k == len(h.new_lines) - 1 and not h.new_last_has_newline:
                    out.append(NO_NEWLINE)
    return "\n".join(out) + "\n"


# ------------------------------------------------------------------------ parsing


def parse(text: str) -> Proposal:
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if not lines or not lines[0].startswith(HEADER_PREFIX):
        raise Malformed("missing agent-proposal header")
    m = HEADER_RE.match(lines[0])
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
        old_marked = new_marked = False
        last_side = ""
        hunk_no = len(hunks) + 1
        while i < len(lines) and not HUNK_RE.match(lines[i]):
            line = lines[i]
            if line.startswith("\\"):
                if line != NO_NEWLINE:
                    raise Malformed(f"line {i + 1}: unknown marker {line[:40]!r}; only {NO_NEWLINE!r} is allowed")
                if last_side in ("", "\\"):
                    raise Malformed(f"line {i + 1}: newline marker must follow a diff line")
                if last_side in ("-", " "):
                    if old_marked:
                        raise Malformed(f"line {i + 1}: duplicate newline marker on the old side")
                    old_nl, old_marked = False, True
                if last_side in ("+", " "):
                    if new_marked:
                        raise Malformed(f"line {i + 1}: duplicate newline marker on the new side")
                    new_nl, new_marked = False, True
                last_side = "\\"
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
                raise Malformed(f"unexpected line {i + 1} in hunk {hunk_no}")
            if last_side != "\\" and (old_marked and last_side in ("-", " ") or new_marked and last_side in ("+", " ")):
                raise Malformed(f"line {i + 1}: lines after a newline marker on the same side in hunk {hunk_no}")
            i += 1
        if len(old_lines) != old_count or len(new_lines) != new_count:
            raise Malformed(f"hunk {hunk_no} counts do not match its lines")
        if (old_marked and not old_lines) or (new_marked and not new_lines):
            raise Malformed(f"hunk {hunk_no}: newline marker on an empty side")
        hunks.append(Hunk(hunk_no, old_start, old_count, new_start, new_count, section, old_lines, new_lines, old_nl, new_nl))
    return Proposal(version, meta["document"], meta["base-sha256"], hunks, meta.get("author", ""), meta.get("summary", ""), meta.get("created", ""))


def read_bounded(path: Path, limit: int, what: str) -> bytes:
    """Read at most limit+1 bytes from a regular file; refuse anything over the limit without reading it whole."""
    try:
        with open(path, "rb") as fh:
            data = fh.read(limit + 1)
    except OSError as exc:
        raise Malformed(f"cannot read {what} {path}: {exc.strerror}") from exc
    if len(data) > limit:
        raise Malformed(f"{what} exceeds the {limit} byte limit")
    return data


def load(path: Path) -> Proposal:
    if path.is_dir():
        raise Malformed(f"{path} is a directory")
    return parse(decode(read_bounded(path, MAX_PROPOSAL_BYTES, "proposal"), "proposal"))


# ----------------------------------------------------------------------- applying


def hunk_matches(source: list[str], source_nl: bool, h: Hunk, total: int, *, anchored_only: bool = False) -> bool:
    idx = h.old_index
    if anchored_only and h.old_count == 0:
        return False  # a pure insertion has no context to verify against a changed document
    if idx < 0 or idx + h.old_count > total:
        return False
    if source[idx : idx + h.old_count] != h.old_lines:
        return False
    at_end = idx + h.old_count == total and h.old_count
    return not (at_end and h.old_last_has_newline != source_nl)


def apply_hunks(text: str, hunks: Iterable[Hunk], *, strict: bool = True) -> tuple[str, list[int]]:
    """Apply hunks (any order) to text. Returns new text and indexes of hunks skipped.

    strict=True raises HunkConflict on the first hunk whose context no longer matches;
    strict=False (rebase) skips such hunks — and unanchored pure insertions — and reports them.
    """
    source, source_nl = split_lines(text)
    total = len(source)
    chosen = sorted(hunks, key=lambda h: h.old_index)
    for a, b in zip(chosen, chosen[1:]):  # noqa: RUF007 successive pairs (itertools.pairwise needs 3.10+)
        if a.old_index + a.old_count > b.old_index:
            raise HunkConflict(f"hunks {a.index} and {b.index} overlap")
    skipped: list[int] = []
    out: list[str] = []
    cursor = 0
    out_nl = source_nl
    for h in chosen:
        if not hunk_matches(source, source_nl, h, total, anchored_only=not strict):
            if strict:
                raise HunkConflict(f"hunk {h.index} is out of date: the document changed at lines {h.old_start}-{h.old_start + max(h.old_count, 1) - 1}")
            skipped.append(h.index)
            continue
        out.extend(source[cursor : h.old_index])
        out.extend(h.new_lines)
        cursor = h.old_index + h.old_count
        if cursor == total and h.old_count:
            # The hunk reaches the end of the file, so the new side decides the final newline. A pure
            # tail deletion leaves a formerly non-last line as the last one; it always had a newline.
            out_nl = h.new_last_has_newline if h.new_count else True
        elif cursor == total and not h.old_count and h.new_count:
            # appended at the very end of the file: the new lines decide the final newline
            out_nl = h.new_last_has_newline
    out.extend(source[cursor:])
    return join_lines(out, out_nl), skipped


def atomic_write(path: Path, data: bytes, *, preserve_mode: bool, expect: bytes | None = None) -> None:
    """Write data to path through a temp file + rename. With preserve_mode the existing file's
    permission bits are copied first and any failure to read or copy them aborts the replace.
    With expect, the current bytes and inode of path are compared once more right before the
    rename (after the temp file is complete) and a mismatch aborts without touching path."""
    mode = None
    ident = None
    if preserve_mode:
        try:
            st = path.stat()
        except OSError as exc:
            raise DocumentUnreadable(f"cannot read permissions of {path}: {exc.strerror}") from exc
        mode = st.st_mode & 0o7777
        ident = (st.st_ino, st.st_dev)
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        if mode is not None:
            try:
                os.chmod(tmp, mode)
            except OSError as exc:
                raise DocumentUnreadable(f"cannot copy permissions onto the new {path.name}: {exc.strerror}; document left unchanged") from exc
        if expect is not None:
            try:
                with open(path, "rb") as fh:
                    current = fh.read()
                st2 = os.stat(path)
            except OSError as exc:
                raise DocumentUnreadable(f"cannot re-read {path} before replacing it: {exc.strerror}; document left unchanged") from exc
            if current != expect or (ident is not None and (st2.st_ino, st2.st_dev) != ident):
                raise DocumentUnreadable(f"{path.name} changed while the proposal was being applied; nothing written")
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def backup(document: Path, data: bytes, backup_dir: Path) -> Path:
    """Exclusive-create a backup; never overwrites an earlier backup of the same document."""
    stamp = _dt.datetime.now().strftime("%Y%m%dT%H%M%S")
    digest = sha256(str(document.resolve()).encode())[:12]
    backup_dir.mkdir(parents=True, exist_ok=True)
    for n in range(1000):
        target = backup_dir / f"{document.name}.{stamp}.{digest}.{n:03d}.bak"
        try:
            fd = os.open(str(target), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            continue
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        return target
    raise DocumentUnreadable(f"could not create a unique backup in {backup_dir}")


def default_backup_dir() -> Path:
    base = os.environ.get("AGENT_PROPOSAL_BACKUP_DIR")
    if base:
        return Path(base).expanduser()
    xdg = os.environ.get("XDG_CACHE_HOME")
    root = Path(xdg).expanduser() if xdg else Path.home() / ".cache"
    return root / "agent-proposal" / "backups"


class DocumentLock:
    """Exclusive lock file beside the document so propose/apply/reject from this CLI cannot
    interleave. It coordinates only this CLI. An editor that ignores the lock is detected by
    the byte/inode re-check right before the rename, which narrows but cannot close the
    window between that check and the rename."""

    def __init__(self, document: Path):
        self.path = lock_path(document)
        self.fd = None

    def __enter__(self):
        try:
            self.fd = os.open(str(self.path), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            raise Locked(f"another apply holds {self.path}; wait for it or remove the lock if it is stale") from None
        except OSError as exc:
            if exc.errno in (errno.EACCES, errno.EROFS):
                raise DocumentUnreadable(f"cannot create lock {self.path}: {exc.strerror}") from exc
            raise
        os.write(self.fd, f"{os.getpid()}\n".encode())
        return self

    def __exit__(self, *exc_info):
        if self.fd is not None:
            os.close(self.fd)
        try:
            os.unlink(self.path)
        except OSError:
            pass


# -------------------------------------------------------------------------- CLI


def parse_hunk_selection(spec: str, total: int) -> list[int]:
    chosen: set[int] = set()
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        try:
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
        except ValueError:
            raise ProposalError(f"bad hunk selector {part!r}") from None
    if not chosen:
        raise ProposalError("no hunks selected")
    return sorted(chosen)


def cmd_propose(args: argparse.Namespace) -> int:
    document = Path(args.document)
    old_bytes = read_document(document)
    if args.new:
        new_path = Path(args.new)
        if not new_path.is_file():
            raise DocumentUnreadable(f"new content not found: {new_path}")
        new_bytes = new_path.read_bytes()
    else:
        new_bytes = sys.stdin.buffer.read()
    old_text = decode(old_bytes, str(document))
    new_text = decode(new_bytes, "new content")
    target = proposal_path(document)
    with DocumentLock(document):
        if target.exists() and not args.force:
            print(f"proposal already exists: {target} (use --force to replace, or `reject` first)", file=sys.stderr)
            return 1
        hunks = build_hunks(old_text, new_text, args.context)
        if not hunks:
            print("no changes: the new content equals the document", file=sys.stderr)
            return 1
        proposal = Proposal(VERSION, document.name, sha256(old_bytes), hunks, args.author or "", args.summary or "")
        atomic_write(target, render(proposal).encode("utf-8"), preserve_mode=False)
    print(f"wrote {target} ({len(hunks)} hunk{'s' if len(hunks) != 1 else ''})")
    print(f"review: {prog_name()} show {shell_quote(str(document))}")
    return 0


def status_of(proposal: Proposal, data: bytes) -> tuple[str, list[int]]:
    text = decode(data, "document")
    source, source_nl = split_lines(text)
    stale = not proposal.matches(data)
    out_of_date = [h.index for h in proposal.hunks if not hunk_matches(source, source_nl, h, len(source), anchored_only=stale)]
    return ("stale" if stale else "fresh"), out_of_date


def cmd_show(args: argparse.Namespace) -> int:
    document = Path(args.document)
    target = proposal_path(document)
    conflicts = conflicts_path(document)
    if not target.is_file():
        if conflicts.is_file():
            kept = load(conflicts)
            print(f"{document.name}: no open proposal, but {len(kept.hunks)} unresolved hunk{'s' if len(kept.hunks) != 1 else ''} in {conflicts.name} (original base; merge by hand, then `reject --conflicts-only`)")
            for h in kept.hunks:
                print(f"\n--- conflict {h.index}: old lines {h.old_start}-{h.old_start + max(h.old_count, 1) - 1}")
                for kind, text in h.display_lines():
                    print(f"{kind} {text}")
            return 2
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
            "conflicts_file": str(conflicts) if conflicts.is_file() else None,
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
    if conflicts.is_file():
        print(f"note: unresolved hunks from an earlier rebase are kept in {conflicts.name}")
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
        if conflicts_path(document).is_file():
            print(f"conflicts-only {len(load(conflicts_path(document)).hunks)} hunks")
            return 2
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
    check_document(document)
    with DocumentLock(document):
        proposal = load(target)
        data = read_document(document)
        text = decode(data, str(document))
        stale = not proposal.matches(data)
        if stale and not args.rebase:
            raise StaleBase(f"{document.name} changed since the proposal was written; run `show` to inspect, or `apply --rebase` to apply only the hunks whose context still matches")
        if args.all:
            selected = list(proposal.hunks)
        elif args.hunks:
            chosen = parse_hunk_selection(args.hunks, len(proposal.hunks))
            selected = [h for h in proposal.hunks if h.index in chosen]
        else:
            print("choose --all or --hunks N[,M-K]", file=sys.stderr)
            return 1
        source, source_nl = split_lines(text)
        applicable = [h for h in proposal.hunks if hunk_matches(source, source_nl, h, len(source), anchored_only=stale)]
        conflicting = [h for h in proposal.hunks if h not in applicable]
        new_text, skipped = apply_hunks(text, selected, strict=not args.rebase)
        applied = [h.index for h in selected if h.index not in skipped]
        if not applied:
            raise HunkConflict("nothing applied: every selected hunk is out of date")
        if args.dry_run:
            print(f"would apply hunks {','.join(map(str, applied))}" + (f"; skipped {','.join(map(str, skipped))}" if skipped else ""))
            return 0
        notes: list[str] = []
        cpath = conflicts_path(document)
        kept = None
        if conflicting and not args.discard_rest:
            # Cannot be rebased: keep them verbatim (original base hash) in a sidecar so nothing is lost.
            kept = Proposal(VERSION, document.name, proposal.base_hash, [Hunk(n, h.old_start, h.old_count, h.new_start, h.new_count, h.section, h.old_lines, h.new_lines, h.old_last_has_newline, h.new_last_has_newline) for n, h in enumerate(conflicting, start=1)], proposal.author, proposal.summary, proposal.created)
            if cpath.exists():
                if not same_hunks(load(cpath), kept):
                    raise HunkConflict(f"{cpath.name} already holds unresolved hunks from an earlier rebase; merge them by hand and run `reject --conflicts-only`, or pass --discard-rest; nothing written")
                kept = None  # identical sidecar already on disk (retry after an earlier failure)
        backup_path = backup(document, data, Path(args.backup_dir).expanduser() if args.backup_dir else default_backup_dir())
        new_bytes = new_text.encode("utf-8")
        # Order matters for crash safety: (1) conflicts sidecar, a new file nothing depends on; (2) the
        # document, re-checked against the bytes read above right before the rename; (3) the proposal.
        if kept is not None:
            try:
                atomic_write(cpath, render(kept).encode("utf-8"), preserve_mode=False)
            except OSError as exc:
                raise DocumentUnreadable(f"could not save the out-of-date hunks to {cpath.name}: {exc.strerror}; nothing written, proposal kept") from exc
        if conflicting and not args.discard_rest:
            notes.append(f"{len(conflicting)} out-of-date hunk{'s' if len(conflicting) != 1 else ''} kept in {cpath.name} (manual merge; original base)")
        elif conflicting:
            notes.append(f"{len(conflicting)} out-of-date hunk{'s' if len(conflicting) != 1 else ''} discarded (--discard-rest)")
        if read_document(document) != data:
            raise DocumentUnreadable(f"{document.name} changed while the proposal was being applied; nothing written (backup of the version that was read: {backup_path})")
        atomic_write(document, new_bytes, preserve_mode=True, expect=data)
        # Remaining hunks that still apply: the proposal's intent minus what was applied, rebased on the new document.
        remaining_applicable = [h for h in applicable if h.index not in applied]
        try:
            if remaining_applicable and not args.discard_rest:
                full_text, _ = apply_hunks(text, applicable, strict=True)
                remaining = build_hunks(new_text, full_text, args.context)
                if remaining:
                    rest = Proposal(VERSION, document.name, sha256(new_bytes), remaining, proposal.author, proposal.summary)
                    atomic_write(target, render(rest).encode("utf-8"), preserve_mode=False)
                    notes.append(f"{len(remaining)} hunk{'s' if len(remaining) != 1 else ''} remain in {target.name}")
                else:
                    target.unlink()
            else:
                target.unlink()
        except OSError as exc:
            raise DocumentUnreadable(f"document updated (backup {backup_path}) but {target.name} could not be rewritten: {exc.strerror}; run `reject` to clear the now-stale proposal") from exc
    print(f"applied hunks {','.join(map(str, applied))} to {document}" + (f"; skipped out-of-date {','.join(map(str, skipped))}" if skipped else "") + ("; " + "; ".join(notes) if notes else ""))
    print(f"backup: {backup_path}")
    return 0


def same_hunks(a: Proposal, b: Proposal) -> bool:
    def key(h: Hunk):
        return (h.old_start, h.old_count, h.new_start, h.new_count, h.old_lines, h.new_lines, h.old_last_has_newline, h.new_last_has_newline)

    return a.base_hash == b.base_hash and [key(h) for h in a.hunks] == [key(h) for h in b.hunks]


def cmd_reject(args: argparse.Namespace) -> int:
    document = Path(args.document)
    targets = [conflicts_path(document)] if args.conflicts_only else [proposal_path(document), conflicts_path(document)]
    removed = []
    with DocumentLock(document):
        for p in targets:
            if p.is_file():
                p.unlink()
                removed.append(p)
    if not removed:
        print("no proposal to reject" if not args.conflicts_only else "no conflicts file to remove", file=sys.stderr)
        return 1
    for p in removed:
        print(f"removed {p}")
    return 0


def iter_proposals(root: Path) -> Iterable[Path]:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.startswith(".") and name.endswith((".proposal.diff", CONFLICTS_SUFFIX)):
                yield Path(dirpath) / name


def cmd_list(args: argparse.Namespace) -> int:
    root = Path(args.root or ".")
    rows = []
    found: dict[Path, dict[str, Path]] = {}
    for p in iter_proposals(root):
        if p.name.endswith(CONFLICTS_SUFFIX):
            found.setdefault(p.parent / p.name[1 : -len(CONFLICTS_SUFFIX)], {})["conflicts"] = p
        else:
            found.setdefault(p.parent / p.name[1 : -len(".proposal.diff")], {})["proposal"] = p
    for document in sorted(found):
        p = found[document].get("proposal")
        if p is None:
            c = found[document]["conflicts"]
            try:
                n = len(load(c).hunks)
            except ProposalError as exc:
                rows.append({"proposal": str(c), "document": str(document), "state": "malformed", "hunks": 0, "error": str(exc)})
                continue
            rows.append({"proposal": str(c), "document": str(document), "state": "conflicts-only", "hunks": n, "out_of_date": [], "conflicts": True})
            continue
        try:
            proposal = load(p)
        except ProposalError as exc:
            rows.append({"proposal": str(p), "document": str(document), "state": "malformed", "hunks": 0, "error": str(exc)})
            continue
        if document.is_file() and not document.is_symlink():
            state, out_of_date = status_of(proposal, read_document(document))
        else:
            state, out_of_date = "document-missing", []
        rows.append({"proposal": str(p), "document": str(document), "state": state, "hunks": len(proposal.hunks), "out_of_date": out_of_date, "author": proposal.author, "summary": proposal.summary, "created": proposal.created, "conflicts": conflicts_path(document).is_file()})
    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    else:
        if not rows:
            print("no proposals")
        for r in rows:
            extra = f" ({r['error']})" if r.get("error") else (" +conflicts" if r.get("conflicts") else "")
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

    sp = sub.add_parser("check", help="exit 0 fresh, 1 none, 2 stale or conflicts-only, 3 malformed")
    sp.add_argument("document")
    sp.set_defaults(func=cmd_check)

    sp = sub.add_parser("apply", help="apply accepted hunks with a backup; leftovers stay as a rebased proposal")
    sp.add_argument("document")
    sp.add_argument("--hunks", help="e.g. 1,3 or 2-4")
    sp.add_argument("--all", action="store_true")
    sp.add_argument("--rebase", action="store_true", help="stale base: apply hunks whose context still matches; keep the rest in .<doc>.proposal.conflicts.diff")
    sp.add_argument("--dry-run", action="store_true")
    sp.add_argument("--discard-rest", action="store_true", help="delete unapplied and out-of-date hunks instead of keeping them")
    sp.add_argument("--backup-dir", help="default $AGENT_PROPOSAL_BACKUP_DIR or ~/.cache/agent-proposal/backups")
    sp.add_argument("--context", type=int, default=3)
    sp.set_defaults(func=cmd_apply)

    sp = sub.add_parser("reject", help="delete the proposal (and any conflicts sidecar) without touching the document")
    sp.add_argument("document")
    sp.add_argument("--conflicts-only", action="store_true", help="remove only .<doc>.proposal.conflicts.diff (after merging it by hand)")
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
    except (ValueError, OverflowError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"error: {exc.strerror or exc} ({exc.filename})" if exc.filename else f"error: {exc}", file=sys.stderr)
        return 4


if __name__ == "__main__":
    sys.exit(main())
