"""Docs damaged by the PR #12 placeholder substitution must be complete again.

The regex replaced a path and the text up to the closing backtick with
"<external-disk>", leaving commands without a target and unbalanced inline
code. The repaired lines use variables such as $AI_MEM_ROOT instead.
"""
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
PLACEHOLDER = "<external-disk>"
DOCS = {
    "my-config/guides/feishu-bot.md": (
        "`$AI_MEM_ROOT/bin/ai-mem-feishu`",
        "`$AI_MEM_ROOT/command-center/docs/commander-playbook.md`",
    ),
    "skills/ebook-download/SKILL.md": (
        "`$EXT_DISK/02-NotebookLM/",
    ),
}


def unbalanced_lines(text):
    bad, fenced = [], False
    for number, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if not fenced and line.count("`") % 2:
            bad.append(number)
    return bad


class DocCommandPathTests(unittest.TestCase):
    def test_repaired_docs_are_complete(self):
        for doc, snippets in DOCS.items():
            text = (ROOT / doc).read_text()
            with self.subTest(doc=doc):
                self.assertFalse(PLACEHOLDER in text, "placeholder left")
                self.assertEqual(unbalanced_lines(text), [])
                for snippet in snippets:
                    self.assertTrue(snippet in text, f"missing {snippet}")

    def test_variables_are_explained(self):
        guide = (ROOT / "my-config/guides/feishu-bot.md").read_text()
        self.assertIn("AI_MEM_ROOT` =", guide)
        skill = (ROOT / "skills/ebook-download/SKILL.md").read_text()
        self.assertIn("EXT_DISK` =", skill)

    def test_no_tracked_markdown_keeps_the_placeholder(self):
        git = shutil.which("git")
        if git is None:
            self.skipTest("git not available")
        result = subprocess.run(
            [git, "-C", str(ROOT), "grep", "-lF", PLACEHOLDER, "--", "*.md"],
            capture_output=True, text=True,
        )
        if result.returncode not in (0, 1):
            self.skipTest("not a git checkout")
        self.assertEqual(result.stdout.split(), [])


if __name__ == "__main__":
    unittest.main()
