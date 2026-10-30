"""Skill aliases must work from a checkout without a global gstack install."""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class SkillAliasTests(unittest.TestCase):
    def test_gstack_aliases_resolve_inside_the_checkout(self):
        aliases = [
            path for path in (ROOT / "skills").glob("*/*")
            if path.is_symlink() and "gstack" in str(path.readlink())
        ]
        self.assertTrue(aliases, "No gstack aliases found")
        canonical = (ROOT / "skills/gstack").resolve()
        for path in aliases:
            with self.subTest(alias=path.relative_to(ROOT)):
                target = path.readlink()
                self.assertFalse(target.is_absolute())
                self.assertNotIn("$", str(target))
                resolved = path.resolve()
                self.assertTrue(resolved.is_relative_to(canonical))
                self.assertTrue(resolved.exists(), "Alias target is missing")
                if path.name == "SKILL.md":
                    self.assertTrue(resolved.is_file())
                else:
                    self.assertTrue(resolved.is_dir())


if __name__ == "__main__":
    unittest.main()
