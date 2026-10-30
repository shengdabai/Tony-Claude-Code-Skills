"""Installer previews must not create directories in the target HOME."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "install.sh"


class InstallDryRunTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.home = self.root / "home"
        self.repo.mkdir()
        self.home.mkdir()
        shutil.copyfile(SCRIPT, self.repo / "install.sh")
        for name in ("my-config/rules", "skills/demo", "opc-methodology/skills/opc-demo"):
            (self.repo / name).mkdir(parents=True)
        (self.repo / "my-config/CLAUDE.md").write_text("Fixture instructions\n")

    def preview(self, *args):
        return subprocess.run(
            ["bash", str(self.repo / "install.sh"), *args],
            env=dict(os.environ, HOME=str(self.home)),
            capture_output=True, text=True, input="",
        )

    def test_dry_run_leaves_new_home_empty_for_each_mode(self):
        for index, args in enumerate((("--dry-run",), ("--link", "--dry-run"), ("--copy", "--dry-run"))):
            with self.subTest(args=args):
                self.home = self.root / f"home-{index}"
                self.home.mkdir()
                result = self.preview(*args)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("[DRY]", result.stdout)
                self.assertEqual(list(self.home.iterdir()), [])

    def test_dry_run_preserves_existing_target(self):
        target = self.home / ".claude"
        target.mkdir()
        (target / "CLAUDE.md").write_text("User instructions\n")
        result = self.preview("--dry-run")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([p.name for p in target.iterdir()], ["CLAUDE.md"])
        self.assertEqual((target / "CLAUDE.md").read_text(), "User instructions\n")

    def test_help_leaves_home_empty(self):
        result = self.preview("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.home.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
