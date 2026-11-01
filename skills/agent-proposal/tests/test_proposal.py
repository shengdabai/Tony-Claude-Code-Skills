#!/usr/bin/env python3
"""Regression tests for proposal.py. Run: python3 -I -m unittest discover -s tests (from the skill dir)."""
from __future__ import annotations

import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
import proposal as P

DOC = "# Title\n\nalpha\nbeta\ngamma\n\n## Part two\n\ndelta\nepsilon\nzeta\n"


def run(*argv: str) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = P.main(list(argv))
    return code, out.getvalue(), err.getvalue()


class ProposalRoundTrip(unittest.TestCase):
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

    def propose(self, new_text: str, *extra: str) -> Path:
        new = self.dir / "new.txt"
        new.write_text(new_text, encoding="utf-8")
        code, _, err = run("propose", str(self.doc), "--new", str(new), "--author", "test", *extra)
        self.assertEqual(code, 0, err)
        return P.proposal_path(self.doc)

    def test_propose_show_apply_all(self):
        new_text = DOC.replace("beta", "BETA").replace("epsilon", "EPSILON")
        # context 1 keeps the two edits (lines 4 and 10) in separate hunks
        path = self.propose(new_text, "--summary", "capitalise two words", "--context", "1")
        self.assertTrue(path.exists())
        text = path.read_text(encoding="utf-8")
        self.assertTrue(text.startswith("# agent-proposal v1\n# document: note.md\n# base-sha256: "))
        self.assertIn("# summary: capitalise two words", text)
        code, out, _ = run("show", str(self.doc))
        self.assertEqual(code, 0)
        self.assertIn("2 hunks, base fresh, by test", out)
        self.assertIn("- beta", out)
        self.assertIn("+ BETA", out)
        code, out, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), new_text)
        self.assertFalse(path.exists(), "proposal must be removed after a full apply")
        self.assertEqual(len(list(self.backups.iterdir())), 1)
        self.assertEqual(next(self.backups.iterdir()).read_text(encoding="utf-8"), DOC)

    def test_partial_apply_leaves_rebased_remainder(self):
        new_text = DOC.replace("alpha", "ALPHA").replace("zeta", "ZETA")
        path = self.propose(new_text)
        code, out, err = run("apply", str(self.doc), "--hunks", "2")
        self.assertEqual(code, 0, err)
        self.assertIn("1 hunk remain", out)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC.replace("zeta", "ZETA"))
        self.assertTrue(path.exists())
        rest = P.load(path)
        self.assertEqual(len(rest.hunks), 1)
        self.assertTrue(rest.matches(self.doc.read_bytes()), "remainder must be rebased on the new document")
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), new_text)
        self.assertFalse(path.exists())

    def test_stale_base_is_refused_then_rebase_applies_matching_hunks(self):
        new_text = DOC.replace("alpha", "ALPHA").replace("zeta", "ZETA")
        self.propose(new_text)
        # Someone edits the document near the first hunk after the proposal was written.
        self.doc.write_text(DOC.replace("alpha", "alpha (edited by human)"), encoding="utf-8")
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 2)
        self.assertIn("changed since the proposal", err)
        code, out, _ = run("check", str(self.doc))
        self.assertEqual(code, 2)
        self.assertIn("stale", out)
        self.assertIn("out of date: 1", out)
        code, out, err = run("apply", str(self.doc), "--all", "--rebase")
        self.assertEqual(code, 0, err)
        self.assertIn("skipped out-of-date 1", out)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC.replace("alpha", "alpha (edited by human)").replace("zeta", "ZETA"))
        self.assertFalse(P.proposal_path(self.doc).exists())

    def test_hunk_out_of_date_without_rebase_is_a_conflict(self):
        new_text = DOC.replace("gamma", "GAMMA")
        path = self.propose(new_text)
        prop = P.load(path)
        prop.hunks[0].old_lines[0] = "not-in-document"
        changed = P.render(prop)
        path.write_text(changed, encoding="utf-8")
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 5)
        self.assertIn("out of date", err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC, "document untouched on conflict")

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
        finally:
            P.MAX_PROPOSAL_BYTES = old

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

    def test_final_newline_only_change_round_trips(self):
        self.propose(DOC.rstrip("\n"))
        code, out, _ = run("show", str(self.doc))
        self.assertEqual(code, 0)
        self.assertIn("No newline at end of file", out)
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC.rstrip("\n"))
        # And back again: adding the newline.
        self.propose(DOC)
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), DOC)

    def test_insert_at_top_and_append_at_end(self):
        new_text = "preamble\n" + DOC + "tail\n"
        self.propose(new_text)
        code, _, err = run("apply", str(self.doc), "--all")
        self.assertEqual(code, 0, err)
        self.assertEqual(self.doc.read_text(encoding="utf-8"), new_text)

    def test_hunk_selection_parsing(self):
        self.assertEqual(P.parse_hunk_selection("1,3-4", 5), [1, 3, 4])
        with self.assertRaises(P.ProposalError):
            P.parse_hunk_selection("6", 5)
        with self.assertRaises(P.ProposalError):
            P.parse_hunk_selection("", 5)

    def test_list_reports_state(self):
        sub = self.dir / "sub"
        sub.mkdir()
        other = sub / "b.txt"
        other.write_text("x\n", encoding="utf-8")
        self.propose(DOC.replace("beta", "b"))
        (sub / ".b.txt.proposal.diff").write_text("nope\n", encoding="utf-8")
        (self.dir / "node_modules").mkdir()
        (self.dir / "node_modules" / ".c.proposal.diff").write_text("nope\n", encoding="utf-8")
        code, out, _ = run("list", str(self.dir), "--json")
        self.assertEqual(code, 0)
        import json

        rows = json.loads(out)
        states = {Path(r["document"]).name: r["state"] for r in rows}
        self.assertEqual(states, {"note.md": "fresh", "b.txt": "malformed"})

    def test_parse_rejects_bad_digest_and_count_mismatch(self):
        with self.assertRaises(P.Malformed):
            P.parse("# agent-proposal v1\n# document: a\n# base-sha256: zz\n--- a/a\n+++ b/a\n")
        bad = "# agent-proposal v1\n# document: a\n# base-sha256: " + "0" * 64 + "\n--- a/a\n+++ b/a\n@@ -1,2 +1,1 @@\n-x\n+y\n"
        with self.assertRaises(P.Malformed):
            P.parse(bad)


if __name__ == "__main__":
    unittest.main()
