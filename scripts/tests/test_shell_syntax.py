"""Every tracked shell script must pass `bash -n`.

PR #12 left `df -h / /System<external-disk> <external-disk>` in
mac-optimizer.sh, an unquoted redirection that bash rejects at parse time.
"""
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]


def tracked_shell_scripts():
    git = shutil.which("git")
    if git is None:
        return None
    result = subprocess.run(
        [git, "-C", str(ROOT), "ls-files", "-z", "*.sh"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return None
    return [name for name in result.stdout.split("\0") if name]


class ShellSyntaxTests(unittest.TestCase):
    def test_tracked_shell_scripts_parse(self):
        scripts = tracked_shell_scripts()
        if scripts is None:
            self.skipTest("not a git checkout")
        self.assertTrue(scripts)
        failures = []
        for script in scripts:
            result = subprocess.run(["bash", "-n", script], cwd=ROOT,
                                    capture_output=True, text=True)
            if result.returncode != 0:
                failures.append(result.stderr.strip())
        self.assertEqual(failures, [])

    def test_mac_optimizer_disk_targets(self):
        text = (ROOT / "my-config/scripts/mac-optimizer.sh").read_text()
        self.assertTrue("/System/Volumes/Data" in text, "data volume missing")
        self.assertTrue('"${EXT_DISK:-}"' in text, "EXT_DISK not used")
        self.assertFalse("<external-disk>" in text, "placeholder left")


if __name__ == "__main__":
    unittest.main()
