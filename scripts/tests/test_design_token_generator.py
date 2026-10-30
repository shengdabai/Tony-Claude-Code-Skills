"""Exercise the documented CLI formats in both vendored skill copies."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = [
    ROOT / prefix / "alirezarezvani-claude-skills/product-team/ui-design-system/scripts/design_token_generator.py"
    for prefix in ("skills/rsmdt-the-startup", "skills/_collections/rsmdt-the-startup")
]


class DesignTokenGeneratorTests(unittest.TestCase):
    def generate(self, script, style, output_format):
        with tempfile.TemporaryDirectory() as cwd:
            result = subprocess.run(
                [sys.executable, "-B", str(script), "#0066CC", style, output_format],
                cwd=cwd, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(list(Path(cwd).iterdir()), [], "CLI must only write stdout")
            return result.stdout

    def test_json_palette_and_core_sections_for_each_style(self):
        for script in SCRIPTS:
            for style in ("modern", "classic", "playful"):
                with self.subTest(script=str(script.relative_to(ROOT)), style=style):
                    tokens = json.loads(self.generate(script, style, "json"))
                    self.assertEqual(tokens["meta"]["style"], style)
                    self.assertEqual(tokens["colors"]["primary"]["DEFAULT"], "#0066CC")
                    self.assertEqual(tokens["colors"]["semantic"]["warning"]["light"], "#FBBD24")
                    for section in ("typography", "spacing", "shadows", "breakpoints", "z-index"):
                        self.assertTrue(tokens[section])

    def test_css_exports_nested_values_as_custom_properties(self):
        for script in SCRIPTS:
            with self.subTest(script=str(script.relative_to(ROOT))):
                output = self.generate(script, "modern", "css")
                self.assertTrue(output.startswith(":root {\n"))
                self.assertIn("--colors-primary-DEFAULT: #0066CC;", output)
                self.assertIn("--colors-semantic-warning-light: #FBBD24;", output)
                self.assertTrue(output.endswith("}\n"))

    def test_scss_exports_nested_values_as_variables(self):
        for script in SCRIPTS:
            with self.subTest(script=str(script.relative_to(ROOT))):
                output = self.generate(script, "modern", "scss")
                self.assertIn("$colors-primary-DEFAULT: #0066CC;", output)
                self.assertIn("$colors-semantic-warning-light: #FBBD24;", output)
                self.assertNotIn(":root", output)
                self.assertNotIn("{", output)


if __name__ == "__main__":
    unittest.main()
