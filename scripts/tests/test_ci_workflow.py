"""CI must cover shell syntax and the two Node projects, not only Python.

Text checks only (no YAML dependency): each job block must exist and run the
documented commands in a directory that exists in the checkout.
"""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/ci.yml"


def job_block(text, job):
    match = re.search(rf"^  {re.escape(job)}:\n(.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)",
                      text, re.M | re.S)
    if match is None:
        raise AssertionError(f"job {job!r} missing from ci.yml")
    return match.group(1)


class CIWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.text = WORKFLOW.read_text()

    def test_shell_syntax_job_checks_every_tracked_script(self):
        block = job_block(self.text, "shell-syntax")
        self.assertIn("git ls-files -z '*.sh'", block)
        self.assertIn('bash -n "$f"', block)

    def test_getnote_mcp_job(self):
        block = job_block(self.text, "getnote-mcp")
        self.assertIn("working-directory: my-config/mcp-servers/getnote-mcp", block)
        self.assertIn("actions/setup-node@", block)
        self.assertIn("npm ci --ignore-scripts", block)
        self.assertIn("npx tsc --noEmit", block)
        self.assertTrue((ROOT / "my-config/mcp-servers/getnote-mcp/package-lock.json").is_file())

    def test_alias_manager_job(self):
        block = job_block(self.text, "alias-manager")
        project = "skills/d-kimuson-dotfiles/alias-manager"
        self.assertIn(f"working-directory: {project}", block)
        self.assertIn(f"package_json_file: {project}/package.json", block)
        self.assertIn("pnpm/action-setup@", block)
        for command in ("pnpm install --frozen-lockfile", "pnpm vitest run",
                        "pnpm tsc --noEmit"):
            self.assertIn(command, block)
        self.assertTrue((ROOT / project / "pnpm-lock.yaml").is_file())
        # pnpm must be installed before setup-node so later steps find it.
        self.assertLess(block.index("pnpm/action-setup@"),
                        block.index("actions/setup-node@"))

    def test_new_jobs_do_not_keep_checkout_credentials(self):
        for job in ("shell-syntax", "getnote-mcp", "alias-manager"):
            with self.subTest(job=job):
                self.assertIn("persist-credentials: false", job_block(self.text, job))


if __name__ == "__main__":
    unittest.main()
