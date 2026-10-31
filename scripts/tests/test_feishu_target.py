"""The daily digest scripts must take the Feishu chat id from FEISHU_TARGET.

PR #12 replaced the real chat id with a hard-coded `oc_xxxx...` placeholder,
so the digest would send to (and the doctor would read) a chat that does
not exist. Only assignment lines are evaluated; nothing is sent.
"""
import os
from pathlib import Path
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
DIGEST = ROOT / "my-config/scripts/daily-digest.sh"
DOCTOR = ROOT / "my-config/scripts/daily-publish-doctor.sh"
SCRIPTS = (DIGEST, DOCTOR)
CHAT_ID_LITERAL = re.compile(r"oc_[0-9A-Za-z]{8,}")
EXAMPLE_ID = "oc_" + "0" * 32


def lines_starting(script, *prefixes):
    return [line for line in script.read_text().splitlines()
            if line.startswith(prefixes)]


def run_lines(lines, expr, value=None):
    env = {k: v for k, v in os.environ.items() if k != "FEISHU_TARGET"}
    if value is not None:
        env["FEISHU_TARGET"] = value
    body = "; ".join(lines)
    return subprocess.run(["bash", "-c", f'set -u; {body}; printf "%s" "{expr}"'],
                          env=env, capture_output=True, text=True)


class FeishuTargetTests(unittest.TestCase):
    def test_missing_target_fails_clearly(self):
        for script in SCRIPTS:
            with self.subTest(script=script.name):
                lines = lines_starting(script, "FEISHU_TARGET=")
                self.assertEqual(len(lines), 1, lines)
                result = run_lines(lines, "$FEISHU_TARGET")
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("FEISHU_TARGET", result.stderr)

    def test_digest_chat_id_accepts_both_forms(self):
        lines = lines_starting(DIGEST, "FEISHU_TARGET=", "FEISHU_CHAT_ID=")
        self.assertEqual(len(lines), 2, lines)
        for value in (EXAMPLE_ID, "feishu:" + EXAMPLE_ID):
            with self.subTest(value=value):
                result = run_lines(lines, "$FEISHU_CHAT_ID", value)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, EXAMPLE_ID)

    def test_doctor_reads_history_of_the_configured_chat(self):
        text = DOCTOR.read_text()
        self.assertIn('--chat-id "${FEISHU_TARGET#feishu:}"', text)

    def test_no_chat_id_literal_and_variable_documented(self):
        for script in SCRIPTS:
            with self.subTest(script=script.name):
                text = script.read_text()
                self.assertEqual(CHAT_ID_LITERAL.findall(text), [])
                header = "\n".join(text.splitlines()[:15])
                self.assertIn("FEISHU_TARGET", header)


if __name__ == "__main__":
    unittest.main()
