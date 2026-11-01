"""Regression tests for proposal.py. Run: python3 -I -m unittest discover -s tests (from the skill dir).
Covers the 2026-11-01 Codex review: final-newline round trips, rebase keeps unapplied hunks, unique backups,
mid-apply edits, bounded reads, symlink refusal, strict newline markers, oversized numbers, unanchored
insertions under --rebase, permission-copy failure."""
from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
import proposal as P

DOC = "# Title\n\nalpha\nbeta\ngamma\n\n## Part two\n\ndelta\nepsilon\nzeta\n"


def run(*argv: str) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = P.main(list(argv))
    return code, out.getvalue(), err.getvalue()


class ProposalTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.doc = self.dir / "note.md"
        self.doc.write_text(DOC, encoding="utf-8")
        self.backups = self.dir / "backups"
        os.environ["AGENT_PROPOSAL_BACKUP_DIR"] = str(self.backups)

    def tearDown(self):
        self.tmp.cleanup()
        os.environ.pop("AGENT_PROPOSAL_BACKUP_DIR", None)

    def propose(self, new_text: str, *extra: str, doc: Path | None = None) -> Path:
        doc = doc or self.doc
        new = self.dir / "new.txt"
        new.write_text(new_text, encoding="utf-8")
        code, _, err = run("propose", str(doc), "--new", str(new), "--author", "test", *extra)
        self.assertEqual(code, 0, err)
        return P.proposal_path(doc)

    def round_trip(self, old: str, new: str, **kw):
        doc = self.dir / "rt.txt"
        doc.write_text(old, encoding="utf-8")
        self.propose(new, doc=doc, **kw)
        code, _, err = run("apply", str(doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertEqual(doc.read_text(encoding="utf-8"), new)
        self.assertFalse(P.proposal_path(doc).exists())

    # ------------------------------------------------------------------ basics

    def test_propose_show_apply_all(self):
        new_text = DOC.replace("beta", "BETA").replace("epsilon", "EPSILON")
        path = self.propose(new_text, "--summary", "capitalise: two words", "--context", "1")
        text = path.read_text(encoding="utf-8")
        self.assertTrue(text.startswith("# agent-proposal v1\n# document: note.md\n# base-sha256: "))
        self.assertIn("# summary: capitalise: two words", text)
        code, out, _ = run("show", str(self.doc))
        self.assertEqual(code, 0)
        self.assertIn("2 hunks, base fresh, by test", out)
        self.assertIn("- beta", out)
        self.assertIn("+ BETA", out)
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), new_text)
        self.assertFalse(path.exists())
        backups = list(self.backups.iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(encoding="utf-8"), DOC)

    def test_partial_apply_leaves_rebased_remainder(self):
        new_text = DOC.replace("alpha", "ALPHA").replace("zeta", "ZETA")
        path = self.propose(new_text)
        code, out, err = run("apply", str(self.doc), "--hunks", "2")
        self.assertEqual(code, 0, err)
        self.assertIn("1 hunk remain", out)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC.replace("zeta", "ZETA"))
        rest = P.load(path)
        self.assertEqual(len(rest.hunks), 1)
        self.assertTrue(rest.matches(self.doc.read_bytes()))
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), new_text)
        self.assertFalse(path.exists())

    def test_no_change_and_existing_proposal_guard(self):
        new = self.dir / "same.txt"
        new.write_text(DOC, encoding="utf-8")
        code, _, err = run("propose", str(self.doc), "--new", str(new))
        self.assertEqual(code, 1)
        self.assertIn("no changes", err)
        self.propose(DOC.replace("beta", "b"))
        code, _, err = run("propose", str(self.doc), "--new", str(new))
        self.assertEqual(code, 1)
        self.assertIn("already exists", err)
        code, _, _ = run("reject", str(self.doc))
        self.assertEqual(code, 0)
        self.assertFalse(P.proposal_path(self.doc).exists())

    def test_hunk_selection_parsing(self):
        self.assertEqual(P.parse_hunk_selection("1,3-4", 5), [1, 3, 4])
        for bad in ("6", "", "x", "2-1"):
            with self.assertRaises(P.ProposalError):
                P.parse_hunk_selection(bad, 5)

    def test_list_reports_state(self):
        sub = self.dir / "sub"
        sub.mkdir()
        (sub / "b.txt").write_text("x\n", encoding="utf-8")
        self.propose(DOC.replace("beta", "b"))
        (sub / ".b.txt.proposal.diff").write_text("nope\n", encoding="utf-8")
        (self.dir / "node_modules").mkdir()
        (self.dir / "node_modules" / ".c.proposal.diff").write_text("nope\n", encoding="utf-8")
        code, out, _ = run("list", str(self.dir), "--json")
        self.assertEqual(code, 0)
        states = {Path(r["document"]).name: r["state"] for r in json.loads(out)}
        self.assertEqual(states, {"note.md": "fresh", "b.txt": "malformed"})

    # ------------------------------------------------------- final newline (P1)

    def test_final_newline_round_trips(self):
        self.round_trip(DOC, DOC.rstrip("\n"))
        self.round_trip(DOC.rstrip("\n"), DOC)
        self.round_trip("a", "a\nb")  # keep the shared line, append after it
        self.round_trip("a", "a\nb\n")
        self.round_trip("a\nb", "a")  # drop the last line, keep the (now unterminated) first
        self.round_trip("a\nb\n", "a")
        self.round_trip("a\nb", "a\nb\nc")
        self.round_trip("x\n", "")
        self.round_trip("", "x")
        self.round_trip("", "x\n")
        self.round_trip("a\nb\n", "b\n")
        self.round_trip("a\nb", "b")

    def test_insert_at_top_and_append_at_end(self):
        self.round_trip(DOC, "preamble\n" + DOC + "tail\n")
        self.round_trip(DOC, "preamble\n" + DOC + "tail")

    # ---------------------------------------------- stale / rebase / conflicts (P1)

    def test_stale_base_is_refused_then_rebase_keeps_everything_unapplied(self):
        new_text = DOC.replace("alpha", "ALPHA").replace("gamma", "GAMMA").replace("zeta", "ZETA")
        self.propose(new_text, "--context", "0")  # three hunks (alpha/gamma are 2 lines apart: context 1 would merge them)
        # a human edits near the first hunk after the proposal was written
        self.doc.write_text(DOC.replace("alpha", "alpha (edited by human)"), encoding="utf-8")
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 2)
        self.assertIn("changed since the proposal", err)
        code, out, _ = run("check", str(self.doc))
        self.assertEqual(code, 2)
        self.assertIn("stale", out)
        self.assertIn("out of date: 1", out)
        # rebase, accepting only hunk 3: hunk 2 (still applicable) must survive, hunk 1 goes to the conflicts sidecar
        code, out, err = run("apply", str(self.doc), "--hunks", "3", "--rebase")
        self.assertEqual(code, 0, err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC.replace("alpha", "alpha (edited by human)").replace("zeta", "ZETA"))
        self.assertIn("1 hunk remain", out)
        self.assertIn("1 out-of-date hunk kept in", out)
        rest = P.load(P.proposal_path(self.doc))
        self.assertEqual([[t for k, t in h.display_lines() if k == "+"] for h in rest.hunks], [["GAMMA"]])  # remainder is re-rendered with context
        self.assertTrue(rest.matches(self.doc.read_bytes()))
        conflicts = P.load(P.conflicts_path(self.doc))
        self.assertEqual([h.new_lines for h in conflicts.hunks], [["ALPHA"]])
        self.assertEqual(conflicts.base_hash, P.sha256(DOC.encode()))
        # second round: apply the remainder; the sidecar stays until rejected
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertIn("GAMMA", self.doc.read_text(encoding="utf-8"))
        self.assertFalse(P.proposal_path(self.doc).exists())
        self.assertTrue(P.conflicts_path(self.doc).exists())
        code, out, _ = run("reject", str(self.doc))
        self.assertEqual(code, 0)
        self.assertFalse(P.conflicts_path(self.doc).exists())

    def test_rebase_with_discard_rest_drops_conflicts(self):
        self.propose(DOC.replace("alpha", "ALPHA").replace("zeta", "ZETA"), "--context", "1")
        self.doc.write_text(DOC.replace("alpha", "alpha!"), encoding="utf-8")
        code, out, err = run("apply", str(self.doc), "--all", "--rebase", "--discard-rest")
        self.assertEqual(code, 0, err)
        self.assertIn("discarded", out)
        self.assertFalse(P.conflicts_path(self.doc).exists())
        self.assertFalse(P.proposal_path(self.doc).exists())

    def test_rebase_skips_unanchored_pure_insertions(self):
        doc = self.dir / "ins.txt"
        doc.write_text("a\nb\n", encoding="utf-8")
        self.propose("a\nX\nb\n", "--context", "0", doc=doc)
        doc.write_text("HEADER\na\nb\n", encoding="utf-8")
        code, _, err = run("apply", str(doc), "--all", "--rebase")
        self.assertEqual(code, 5, err)
        self.assertIn("every selected hunk is out of date", err)
        self.assertEqual(doc.read_text(encoding="utf-8"), "HEADER\na\nb\n")
        # with context the insertion is anchored and rebases correctly
        run("reject", str(doc))
        doc.write_text("a\nb\n", encoding="utf-8")
        self.propose("a\nX\nb\n", doc=doc)
        doc.write_text("HEADER\na\nb\n", encoding="utf-8")
        code, _, err = run("apply", str(doc), "--all", "--rebase")
        self.assertEqual(code, 5, "offset-shifted context is not matched exactly at the old position, so it is a conflict, never a mis-placed insert")
        self.assertEqual(doc.read_text(encoding="utf-8"), "HEADER\na\nb\n")

    def test_hunk_out_of_date_without_rebase_is_a_conflict(self):
        path = self.propose(DOC.replace("gamma", "GAMMA"))
        prop = P.load(path)
        prop.hunks[0].old_lines[0] = "not-in-document"
        path.write_text(P.render(prop), encoding="utf-8")
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 5)
        self.assertIn("out of date", err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC)

    # ------------------------------------------------ backups / locking / safety (P1)

    def test_backups_never_overwrite_each_other(self):
        self.propose(DOC.replace("alpha", "A1"))
        run("apply", str(self.doc), "--all")
        self.propose(self.doc.read_text(encoding="utf-8").replace("beta", "B2"))
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        names = sorted(p.name for p in self.backups.iterdir())
        self.assertEqual(len(names), 2, names)
        contents = sorted(p.read_text(encoding="utf-8") for p in self.backups.iterdir())
        self.assertEqual(contents, sorted([DOC, DOC.replace("alpha", "A1")]))

    def test_edit_between_read_and_write_is_refused(self):
        self.propose(DOC.replace("alpha", "A1"))
        original_backup = P.backup

        def sneaky_backup(document, data, backup_dir):
            path = original_backup(document, data, backup_dir)
            document.write_text(DOC.replace("beta", "edited meanwhile"), encoding="utf-8")
            return path

        with mock.patch.object(P, "backup", sneaky_backup):
            code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 4)
        self.assertIn("changed while the proposal was being applied", err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC.replace("beta", "edited meanwhile"))
        self.assertTrue(P.proposal_path(self.doc).exists(), "proposal kept for a retry")
        self.assertFalse(P.lock_path(self.doc).exists(), "lock released")

    def test_lock_blocks_concurrent_apply(self):
        self.propose(DOC.replace("alpha", "A1"))
        P.lock_path(self.doc).write_text("12345\n")
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 6)
        self.assertIn("another apply holds", err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC)
        P.lock_path(self.doc).unlink()
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)

    def test_permission_copy_failure_leaves_document_unchanged(self):
        self.propose(DOC.replace("alpha", "A1"))
        with mock.patch.object(P.os, "chmod", side_effect=OSError(1, "nope")):
            code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 4)
        self.assertIn("permissions", err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC)
        self.assertEqual([p for p in self.dir.iterdir() if p.suffix == ".tmp"], [], "temp file cleaned up")

    def test_symlink_documents_are_refused(self):
        real = self.dir / "real.md"
        real.write_text(DOC, encoding="utf-8")
        link = self.dir / "link.md"
        link.symlink_to(real)
        new = self.dir / "new.txt"
        new.write_text(DOC.replace("alpha", "A1"), encoding="utf-8")
        code, _, err = run("propose", str(link), "--new", str(new))
        self.assertEqual(code, 4)
        self.assertIn("symbolic link", err)
        self.propose(DOC.replace("alpha", "A1"), doc=real)
        os.rename(P.proposal_path(real), P.proposal_path(link))
        code, _, err = run("apply", str(link), "--all")
        self.assertEqual(code, 4)
        self.assertEqual(real.read_text(encoding="utf-8"), DOC)

    # ------------------------------------------------------- malformed input (P2)

    def test_malformed_and_oversized_proposals_are_rejected(self):
        path = P.proposal_path(self.doc)
        path.write_text("garbage\n", encoding="utf-8")
        code, _, err = run("show", str(self.doc))
        self.assertEqual(code, 3)
        self.assertIn("header", err)
        path.write_text("# agent-proposal v9\n# document: note.md\n# base-sha256: " + "0" * 64 + "\n--- a/x\n+++ b/x\n", encoding="utf-8")
        code, _, err = run("check", str(self.doc))
        self.assertEqual(code, 3)
        self.assertIn("version", err)
        old = P.MAX_PROPOSAL_BYTES
        P.MAX_PROPOSAL_BYTES = 10
        try:
            code, _, err = run("check", str(self.doc))
            self.assertEqual(code, 3)
            self.assertIn("limit", err)
            with mock.patch.object(P, "read_bounded", wraps=P.read_bounded) as rb:
                run("check", str(self.doc))
                rb.assert_called()
        finally:
            P.MAX_PROPOSAL_BYTES = old

    def test_bounded_read_does_not_trust_stat(self):
        path = self.dir / "big.diff"
        path.write_text("x" * 50, encoding="utf-8")
        with self.assertRaises(P.Malformed):
            P.read_bounded(path, 10, "proposal")
        self.assertEqual(P.read_bounded(path, 50, "proposal"), b"x" * 50)

    def test_newline_marker_must_be_exact_and_placed(self):
        head = "# agent-proposal v1\n# document: note.md\n# base-sha256: " + P.sha256(b"a\n") + "\n--- a/a\n+++ b/a\n"
        with self.assertRaises(P.Malformed):
            P.parse(head + "@@ -1 +1 @@\n-a\n+b\n\\ garbage\n")
        with self.assertRaises(P.Malformed):
            P.parse(head + "@@ -1 +1 @@\n\\ No newline at end of file\n-a\n+b\n")
        with self.assertRaises(P.Malformed):
            P.parse(head + "@@ -1,2 +1,2 @@\n-a\n\\ No newline at end of file\n-c\n+b\n+d\n")
        with self.assertRaises(P.Malformed):
            P.parse(head + "@@ -1 +1 @@\n-a\n+b\n\\ No newline at end of file\n\\ No newline at end of file\n")
        ok = P.parse(head + "@@ -1 +1 @@\n-a\n+b\n\\ No newline at end of file\n")
        self.assertFalse(ok.hunks[0].new_last_has_newline)
        self.assertTrue(ok.hunks[0].old_last_has_newline)

    def test_huge_numbers_and_bad_counts_are_malformed(self):
        head = "# agent-proposal v1\n# document: a\n# base-sha256: " + "0" * 64 + "\n--- a/a\n+++ b/a\n"
        with self.assertRaises(P.Malformed):
            P.parse(head + "@@ -" + "9" * 5000 + " +1 @@\n-x\n+y\n")
        with self.assertRaises(P.Malformed):
            P.parse("# agent-proposal v" + "9" * 400 + "\n")
        with self.assertRaises(P.Malformed):
            P.parse(head + "@@ -1,2 +1,1 @@\n-x\n+y\n")
        with self.assertRaises(P.Malformed):
            P.parse("# agent-proposal v1\n# document: a\n# base-sha256: zz\n--- a/a\n+++ b/a\n")
        path = P.proposal_path(self.doc)
        path.write_text(head + "@@ -" + "9" * 5000 + " +1 @@\n-x\n+y\n", encoding="utf-8")
        code, _, _ = run("check", str(self.doc))
        self.assertEqual(code, 3)

    def test_header_with_colons_and_unicode(self):
        path = self.propose(DOC.replace("alpha", "阿尔法"), "--summary", "标题: 改成中文 — 12:30")
        prop = P.load(path)
        self.assertEqual(prop.summary, "标题: 改成中文 — 12:30")
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertIn("阿尔法", self.doc.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
