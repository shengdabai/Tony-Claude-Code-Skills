"""Portable structure-validator probes; fixtures never invoke Git or install skills."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "tools/validate-skills.sh"
WORKFLOW = SCRIPT.parents[1] / ".github/workflows/ci.yml"
COLLECTIONS = ("_repos", "_collections", "0", "JamesPrial-github-skills",
               "d-kimuson-dotfiles", "rghamilton3-dotfiles", "rsmdt-the-startup",
               "superpowers", "travisvn-awesome-claude-skills", "wshobson-agents")


class ValidateSkillsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo with spaces"
        (self.root / "tools").mkdir(parents=True)
        shutil.copyfile(SCRIPT, self.root / "tools/validate-skills.sh")
        helper = SCRIPT.with_name("skill-collections.sh")
        if helper.exists():
            shutil.copyfile(helper, self.root / "tools" / helper.name)
        self.skill = self.root / "skills/demo"
        self.skill.mkdir(parents=True)
        (self.skill / "SKILL.md").write_text("---\nname: demo\ndescription: Demo\n---\n")
        (self.root / "install.sh").write_text("#!/bin/bash\nexit 0\n")
        (self.root / "NOTICE.md").write_text("Fixture notice\n")
        for name in ("rules", "hooks", "agents", "commands", "scripts"):
            (self.root / "my-config" / name).mkdir(parents=True)

    def scan(self):
        return subprocess.run(
            ["bash", str(self.root / "tools/validate-skills.sh")],
            cwd=self.temp.name, capture_output=True, text=True,
        )

    def test_resolves_repository_from_script_location(self):
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Passed: 8", result.stdout)
        self.assertIn("Failed: 0", result.stdout)

    def test_missing_skill_document_fails(self):
        (self.skill / "SKILL.md").unlink()
        (self.skill / "README.md").write_text("Not a skill document\n")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn("demo missing SKILL.md", result.stdout)

    def test_collection_containers_are_not_individual_skills(self):
        for name in COLLECTIONS:
            (self.root / "skills" / name).mkdir()
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Passed: 8", result.stdout)

    def run_ci_frontmatter_check(self):
        # Execute only the frontmatter step, never privacy scans or other CI steps.
        step = WORKFLOW.read_text().split("        run: |\n", 1)[1]
        step = step.split("\n      - name:", 1)[0]
        script = "\n".join(line[10:] for line in step.splitlines())
        return subprocess.run(
            ["bash", "-c", script], cwd=self.root,
            capture_output=True, text=True,
        )

    def test_ci_and_local_validator_exempt_the_same_collections(self):
        for name in COLLECTIONS:
            (self.root / "skills" / name).mkdir()
        local = self.scan()
        self.assertEqual(local.returncode, 0, local.stdout + local.stderr)
        self.assertIn("Passed: 8", local.stdout)
        ci = self.run_ci_frontmatter_check()
        self.assertEqual(ci.returncode, 0, ci.stdout + ci.stderr)
        self.assertIn("1/1 skills have complete frontmatter (0 warnings)", ci.stdout)

    def test_ci_still_warns_for_an_unknown_missing_skill(self):
        (self.root / "skills/not-a-collection").mkdir()
        ci = self.run_ci_frontmatter_check()
        self.assertEqual(ci.returncode, 0, ci.stdout + ci.stderr)
        self.assertIn("not-a-collection: missing SKILL.md", ci.stdout)
        self.assertIn("1/2 skills have complete frontmatter (1 warnings)", ci.stdout)

    def test_missing_installer_fails(self):
        (self.root / "install.sh").unlink()
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn("install.sh not found", result.stdout)

    def test_invalid_installer_fails(self):
        (self.root / "install.sh").write_text("if then\n")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn("install.sh has syntax errors", result.stdout)

    def test_link_only_skill_is_not_empty(self):
        document = self.skill / "SKILL.md"
        content = document.read_text()
        document.unlink()
        (self.root / "shared.md").write_text(content)
        document.symlink_to("../../shared.md")
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_empty_skill_document_fails(self):
        (self.skill / "SKILL.md").write_text("")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn("demo has empty SKILL.md", result.stdout)

    def test_broken_skill_document_link_fails(self):
        document = self.skill / "SKILL.md"
        document.unlink()
        document.symlink_to("missing.md")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn("demo missing SKILL.md", result.stdout)


if __name__ == "__main__":
    unittest.main()
