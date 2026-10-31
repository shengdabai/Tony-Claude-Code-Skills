"""Scripts that PR #12 left pointing at a literal "<external-disk>" path must
read their location from an environment variable and fail clearly without it.

Only the assignment lines are evaluated, so nothing in these scripts runs.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
PLACEHOLDER = "<external-disk>"

CASES = (
    ("skills/youtube-script-sync/scripts/auto_sync_codex.sh",
     "REPORT_DIR", "YT_SYNC_REPORT_DIR"),
    ("my-config/scripts/converge-ai-mem-2t.sh",
     "T2_ROOT", "AI_MEM_T2_ROOT"),
)


def assignment(script, name):
    lines = [line for line in (ROOT / script).read_text().splitlines()
             if re.match(rf"^{name}=", line)]
    if len(lines) != 1:
        raise AssertionError(f"{script}: expected one {name}= line, got {lines}")
    return lines[0]


def evaluate(line, name, env_name, value=None):
    env = {k: v for k, v in os.environ.items() if k != env_name}
    if value is not None:
        env[env_name] = value
    return subprocess.run(
        ["bash", "-c", f'set -u; {line}; printf "%s" "${name}"'],
        env=env, capture_output=True, text=True,
    )


class ExternalPathVariableTests(unittest.TestCase):
    def test_missing_variable_fails_with_its_name(self):
        for script, name, env_name in CASES:
            with self.subTest(script=script):
                result = evaluate(assignment(script, name), name, env_name)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn(env_name, result.stderr)

    def test_variable_value_is_used(self):
        for script, name, env_name in CASES:
            with self.subTest(script=script):
                result = evaluate(assignment(script, name), name, env_name,
                                  "/Volumes/ExampleDisk/data")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "/Volumes/ExampleDisk/data")

    def test_variables_are_documented_and_placeholder_gone(self):
        for script, _name, env_name in CASES:
            with self.subTest(script=script):
                text = (ROOT / script).read_text()
                header = "\n".join(text.splitlines()[:25])
                self.assertIn(env_name, header)
                self.assertNotIn(PLACEHOLDER, text)

    def test_converge_log_check_uses_variable(self):
        text = (ROOT / "my-config/scripts/converge-ai-mem-2t.sh").read_text()
        line = next(l for l in text.splitlines() if "ai-mem-fast.log" in l
                    and "grep" in l)
        self.assertIn('"$T2_ROOT"', line)

    def test_no_placeholder_in_shell_code(self):
        git = shutil.which("git")
        if git is None:
            self.skipTest("git not available")
        listed = subprocess.run([git, "-C", str(ROOT), "ls-files", "-z", "*.sh"],
                                capture_output=True, text=True)
        if listed.returncode != 0:
            self.skipTest("not a git checkout")
        offenders = []
        for name in filter(None, listed.stdout.split("\0")):
            for number, line in enumerate((ROOT / name).read_text(
                    errors="replace").splitlines(), 1):
                if PLACEHOLDER in line and not line.lstrip().startswith("#"):
                    offenders.append(f"{name}:{number}")
        self.assertEqual(offenders, [])


if __name__ == "__main__":
    unittest.main()
