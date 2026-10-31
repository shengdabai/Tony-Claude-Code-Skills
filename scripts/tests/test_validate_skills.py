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
        self.assertIn(
            "FAIL: demo/SKILL.md symlink -> 'missing.md' dangles", result.stdout)
        self.assertIn("Failed: 1", result.stdout)

    # Issue #17: a symlinked SKILL.md must resolve to a regular file inside
    # the checkout; outside or dangling targets fail and name the entry.
    def link_skill_document(self, target):
        document = self.skill / "SKILL.md"
        content = document.read_text()
        document.unlink()
        document.symlink_to(target)
        return content

    def test_link_outside_repository_fails_even_when_target_exists(self):
        outside = Path(self.temp.name) / "outside.md"
        outside.write_text(self.link_skill_document("../../../outside.md"))
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn(
            "FAIL: demo/SKILL.md symlink -> '../../../outside.md' resolves "
            "outside the repository", result.stdout)
        self.assertIn("Failed: 1", result.stdout)

    def test_absolute_link_outside_repository_fails(self):
        outside = Path(self.temp.name) / "outside.md"
        outside.write_text(self.link_skill_document(outside))
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn("demo/SKILL.md symlink ->", result.stdout)
        self.assertIn("resolves outside the repository", result.stdout)

    def test_dangling_absolute_link_fails(self):
        self.link_skill_document(Path(self.temp.name) / "gone" / "SKILL.md")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn("demo/SKILL.md symlink ->", result.stdout)
        self.assertIn("dangles (target does not exist)", result.stdout)

    def test_link_chain_inside_repository_passes(self):
        content = self.link_skill_document("../shared/alias.md")
        shared = self.root / "skills/shared"
        shared.mkdir()
        (shared / "real.md").write_text(content)
        (shared / "alias.md").symlink_to("real.md")
        (shared / "SKILL.md").write_text(content)
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Failed: 0", result.stdout)

    def test_link_through_repository_alias_path_passes(self):
        (self.root / "shared.md").write_text(
            self.link_skill_document("../../shared.md"))
        alias = Path(self.temp.name) / "alias"
        alias.symlink_to(self.root, target_is_directory=True)
        result = subprocess.run(
            ["bash", str(alias / "tools/validate-skills.sh")],
            cwd=self.temp.name, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Failed: 0", result.stdout)

    def test_link_to_directory_inside_repository_fails(self):
        self.link_skill_document("../../my-config/rules")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn(
            "FAIL: demo/SKILL.md symlink -> '../../my-config/rules' is not a "
            "regular file", result.stdout)

    def test_symlink_loop_fails(self):
        self.link_skill_document("SKILL.md")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn(
            "FAIL: demo/SKILL.md symlink -> 'SKILL.md' is a symlink loop",
            result.stdout)


    # Issue #31: a skill DIRECTORY that is itself a symlink must resolve to a
    # directory inside the checkout. Case A (SKILL.md symlink outside) is
    # test_link_outside_repository_fails_even_when_target_exists above.
    def write_allowlist(self, *names):
        lines = ["# fixture allowlist", ""] + list(names)
        (self.root / "tools/skill-symlink-allowlist.txt").write_text(
            "\n".join(lines) + "\n")

    def test_directory_link_outside_repository_fails(self):  # case B
        outside = Path(self.temp.name) / "outside-skill"
        outside.mkdir()
        (outside / "SKILL.md").write_text("---\nname: x\ndescription: X\n---\n")
        (self.root / "skills/outside").symlink_to(outside, target_is_directory=True)
        result = self.scan()
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("FAIL: outside symlink ->", result.stdout)
        self.assertIn("resolves outside the repository", result.stdout)
        self.assertIn("Failed: 1", result.stdout)

    def test_dangling_directory_link_fails(self):  # case C
        (self.root / "skills/gone").symlink_to(
            "../../.agents/skills/gone", target_is_directory=True)
        result = self.scan()
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn(
            "FAIL: gone symlink -> '../../.agents/skills/gone' dangles",
            result.stdout)
        self.assertIn("Failed: 1", result.stdout)

    def test_allowlisted_directory_link_passes_with_warning(self):  # case D
        self.write_allowlist("gone", "outside")
        (self.root / "skills/gone").symlink_to(
            "../../.agents/skills/gone", target_is_directory=True)
        outside = Path(self.temp.name) / "outside-skill"
        outside.mkdir()
        (self.root / "skills/outside").symlink_to(outside, target_is_directory=True)
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("WARN: gone symlink -> '../../.agents/skills/gone' dangles",
                      result.stdout)
        self.assertIn("WARN: outside symlink ->", result.stdout)
        self.assertIn("allowlisted", result.stdout)
        self.assertIn("Passed: 8", result.stdout)
        self.assertIn("Failed: 0", result.stdout)

    def test_allowlist_does_not_cover_other_names(self):
        self.write_allowlist("other")
        (self.root / "skills/gone").symlink_to(
            "../../.agents/skills/gone", target_is_directory=True)
        result = self.scan()
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("FAIL: gone symlink ->", result.stdout)

    def test_directory_link_inside_repository_is_a_skill(self):
        (self.root / "skills/alias").symlink_to("demo", target_is_directory=True)
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Passed: 9", result.stdout)

    def test_plain_files_in_skills_root_are_ignored(self):
        (self.root / "skills/README.md").write_text("index\n")
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Passed: 8", result.stdout)

    def test_repository_allowlist_points_to_issue_31(self):
        allowlist = SCRIPT.with_name("skill-symlink-allowlist.txt")
        text = allowlist.read_text()
        self.assertIn("#31", text)
        names = [line.strip() for line in text.splitlines()
                 if line.strip() and not line.lstrip().startswith("#")]
        self.assertEqual(len(names), len(set(names)))
        for name in names:
            with self.subTest(name=name):
                self.assertTrue((SCRIPT.parents[1] / "skills" / name).is_symlink())


if __name__ == "__main__":
    unittest.main()
