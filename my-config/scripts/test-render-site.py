#!/usr/bin/env python3
import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("render-site.py")
SPEC = importlib.util.spec_from_file_location("render_site", SCRIPT)
render_site = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(render_site)


class RenderCompletenessTest(unittest.TestCase):
    date = "2026-09-02"

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.src = Path(self.temp.name) / "src"
        self.out = Path(self.temp.name) / "out"
        for kind in ("articles", "ai-news"):
            for lang in ("zh", "en"):
                (self.src / kind / lang).mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        self.temp.cleanup()

    def write(self, kind, lang, title):
        path = self.src / kind / lang / f"{self.date}-{kind}-{lang}.md"
        path.write_text(f"# {title}\n\n> Published: {self.date}\n\n---\n\n{title} summary.\n", encoding="utf-8")

    def test_incomplete_date_never_produces_a_domestic_page(self):
        self.write("articles", "zh", "Reflection")
        self.out.mkdir()
        stale = self.out / f"{self.date}.html"
        stale.write_text("stale one-sided page", encoding="utf-8")

        render_site.build(str(self.src), str(self.out))

        self.assertFalse(stale.exists())
        self.assertNotIn(self.date, (self.out / "index.html").read_text(encoding="utf-8"))

    def test_complete_bilingual_pair_renders_exactly_two_articles_per_page(self):
        for lang in ("zh", "en"):
            self.write("articles", lang, f"Reflection {lang}")
            self.write("ai-news", lang, f"News {lang}")

        render_site.build(str(self.src), str(self.out))

        for suffix in ("", "-en"):
            page = (self.out / f"{self.date}{suffix}.html").read_text(encoding="utf-8")
            self.assertEqual(page.count("<article>"), 2)
        message = render_site.message(str(self.src), self.date, "https://example.test")
        self.assertIn("💭 思考", message)
        self.assertIn("📰 热点", message)
        self.assertIn(f"https://example.test/{self.date}.html", message)

    def test_message_rejects_missing_english_hotspot(self):
        self.write("articles", "zh", "Reflection zh")
        self.write("ai-news", "zh", "News zh")
        self.write("articles", "en", "Reflection en")

        with self.assertRaisesRegex(ValueError, "完整四文件"):
            render_site.message(str(self.src), self.date, "https://example.test")

    def test_active_markdown_link_schemes_are_neutralized(self):
        rendered = render_site.md_to_html("[bad](javascript:alert(1)) [data](data:text/html,boom) [ok](https://example.test?a=1&b=2)")
        self.assertNotIn('href="javascript:', rendered)
        self.assertNotIn('href="data:', rendered)
        self.assertEqual(rendered.count('href="#"'), 2)
        self.assertIn('href="https://example.test?a=1&amp;b=2"', rendered)


if __name__ == "__main__":
    unittest.main()
