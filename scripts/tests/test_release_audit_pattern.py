"""release_audit_ok must reject internal paths and credential patterns.

The privacy pass in PR #12 dropped a parenthesis from the grep -E pattern in
daily-ai-news.sh / daily-article.sh, so grep errored and nothing was ever
flagged. This test extracts the live pattern from both scripts and runs it
with /usr/bin/grep against synthetic samples. Secret-looking samples are
built at runtime so the test file itself never contains one.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = (
    ROOT / "my-config/scripts/daily-ai-news.sh",
    ROOT / "my-config/scripts/daily-article.sh",
)
GREP = "/usr/bin/grep"
PATTERN_LINE = re.compile(r"""if grep -Eq '([^']+)' "\$source"; then""")

POSITIVE = {
    "users path": "see " + os.path.join("/", "Users", "example", "notes.md"),
    "volumes path": "copied from " + os.path.join("/", "Volumes", "ExampleDisk", "data"),
    "sk key": "key sk-" + "A1b2C3d4" * 4,
    "token assignment": "GITHUB_TOKEN=abc",
    "github token": "token ghp_" + "Z9y8X7w6V5u4" * 3,
}
NEGATIVE = {
    "hyphenated prose": "We follow the risk-management-framework-ai-rmf-10 guide.",
    "plain prose": "The token budget for this model is large; see the docs.",
}


def audit_pattern(script):
    text = script.read_text()
    start = text.index("release_audit_ok() {")
    end = text.index("\n}\n", start)
    matches = PATTERN_LINE.findall(text[start:end])
    if len(matches) != 1:
        raise AssertionError(f"{script.name}: expected one audit grep, got {matches}")
    return matches[0]


class ReleaseAuditPatternTests(unittest.TestCase):
    def setUp(self):
        if not os.access(GREP, os.X_OK):
            self.skipTest(f"{GREP} not available")
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)

    def grep(self, pattern, sample):
        path = Path(self.temp.name) / "sample.md"
        path.write_text(f"# Title\n\n{sample}\n")
        return subprocess.run([GREP, "-Eq", pattern, str(path)],
                              capture_output=True, text=True)

    def test_pattern_is_well_formed(self):
        for script in SCRIPTS:
            with self.subTest(script=script.name):
                pattern = audit_pattern(script)
                self.assertNotIn("<external-disk>", pattern)
                result = self.grep(pattern, "harmless text")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(result.stderr, "")

    def test_positive_samples_are_flagged(self):
        for script in SCRIPTS:
            pattern = audit_pattern(script)
            for name, sample in POSITIVE.items():
                with self.subTest(script=script.name, sample=name):
                    result = self.grep(pattern, sample)
                    self.assertEqual(result.returncode, 0,
                                     f"not flagged: {name} {result.stderr}")

    def test_negative_samples_pass(self):
        for script in SCRIPTS:
            pattern = audit_pattern(script)
            for name, sample in NEGATIVE.items():
                with self.subTest(script=script.name, sample=name):
                    result = self.grep(pattern, sample)
                    self.assertEqual(result.returncode, 1,
                                     f"false positive: {name} {result.stderr}")

    def test_both_scripts_share_one_pattern(self):
        self.assertEqual(audit_pattern(SCRIPTS[0]), audit_pattern(SCRIPTS[1]))


if __name__ == "__main__":
    unittest.main()
