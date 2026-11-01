#!/usr/bin/env python3
"""Regression tests for token_ledger.py and import_allowlist.py (python3 -I -m unittest discover -s tests)."""
from __future__ import annotations

import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
import import_allowlist as IA
import token_ledger as TL

CSS = """/* Tokens: primitive -> semantic. Breakpoints: 960px single column. */
:root {
  --c-ink: #0f1c28;
  --c-teal: #0a5f66;
  --space-2: 8px;
  --border-1: 1px;
  --color-text: var(--c-ink);
  --color-accent: var(--c-teal);
  --unused-token: 12px;
  --chip-tint: 14%;
}
body {
  color: var(--color-text);
  margin: 0;
  display: flex;
  width: 100%;
}
.card {
  border: var(--border-1) solid var(--color-accent);
  padding: var(--space-2);
  background: color-mix(in srgb, currentColor var(--chip-tint), transparent);
  /* token-exception: canvas needs a hard pixel edge for the chart grid */
  outline: 1px solid var(--color-accent);
}
.bad {
  color: #ff0000;
  padding: 13px;
  font-weight: 700;
  line-height: 1;
  transition: opacity 160ms ease;
  border-color: var(--nope);
  box-shadow: var(--shadow, 0 1px 2px #000);
}
.scoped {
  --local-token: 4px;
}
@media (max-width: 960px) {
  .card { padding: var(--space-2); }
}
"""


def run(mod, *argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = mod.main(list(argv))
    return code, out.getvalue(), err.getvalue()


class TokenLedgerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        (self.dir / "styles.css").write_text(CSS, encoding="utf-8")
        (self.dir / "index.html").write_text('<style>.x{color:var(--color-text);margin:2px}</style><div style="color: var(--color-accent); gap: 7px">x</div>', encoding="utf-8")
        (self.dir / "app.js").write_text('const t = getComputedStyle(root).getPropertyValue("--c-teal");\n', encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def ledger(self):
        return TL.build_ledger([self.dir / "styles.css", self.dir / "index.html", self.dir / "app.js"], [])

    def test_tokens_uses_and_unused(self):
        ledger = self.ledger()
        names = {t.name for t in ledger.tokens}
        self.assertIn("--color-text", names)
        self.assertEqual(ledger.uses["--c-teal"], 2, "css definition reference + js string reference")
        self.assertIn("--unused-token", ledger.unused)
        self.assertNotIn("--chip-tint", ledger.unused)

    def test_violations_are_classified_with_correct_lines(self):
        ledger = self.ledger()
        by_kind = {}
        for v in ledger.violations:
            by_kind.setdefault(v.kind, []).append(v)
        raw = {(v.property, v.detail.split(" (")[0]) for v in by_kind["raw-literal"] if v.file.endswith("styles.css")}
        self.assertIn(("color", "#ff0000"), raw)
        self.assertIn(("padding", "13px"), raw)
        self.assertIn(("font-weight", "700"), raw)
        self.assertIn(("transition", "160ms"), raw)
        self.assertNotIn(("line-height", "1"), raw, "line-height: 1 is structural")
        self.assertEqual(sorted(v.detail.split(" ")[0] for v in by_kind["undefined-token"]), ["--nope", "--shadow"])
        self.assertEqual(by_kind["raw-fallback"][0].property, "box-shadow")
        self.assertEqual(by_kind["component-token"][0].property, "--local-token")
        # line numbers point at the declaration, not the selector
        color_line = next(v.line for v in by_kind["raw-literal"] if v.property == "color" and "#ff0000" in v.detail)
        self.assertEqual(CSS.split("\n")[color_line - 1].strip(), "color: #ff0000;")
        # inline html: <style> literal and style= literal both reported
        html_props = sorted(v.property for v in ledger.violations if v.file.endswith("index.html"))
        self.assertEqual(html_props, ["gap", "margin"])

    def test_structural_values_and_pure_var_colour_functions_pass(self):
        ledger = self.ledger()
        offending = [v for v in ledger.violations if v.selector.endswith(".card") or v.selector == "body"]
        self.assertEqual(offending, [], [(v.property, v.detail) for v in offending])

    def test_exceptions_and_breakpoints_are_listed_not_counted(self):
        ledger = self.ledger()
        self.assertEqual(len(ledger.exceptions), 1)
        self.assertEqual(ledger.exceptions[0].property, "outline")
        self.assertIn("canvas needs a hard pixel edge", ledger.exceptions[0].detail)
        self.assertEqual([b["value"] for b in ledger.breakpoints], ["960px"])
        status = ledger.to_json()["summary"]["status"]
        self.assertEqual(status, "violations")

    def test_cli_exit_codes_and_status_wording(self):
        code, out, _ = run(TL, str(self.dir / "styles.css"), "--quiet")
        self.assertEqual(code, 1)
        self.assertIn("token-ledger: violations", out)
        clean = self.dir / "clean.css"
        clean.write_text(":root{--a:#fff;--b:var(--a)}\n.x{color:var(--b);display:grid;gap:0}\n", encoding="utf-8")
        code, out, _ = run(TL, str(clean), "--quiet")
        self.assertEqual(code, 0)
        self.assertIn("100% tokenized", out)
        exc = self.dir / "exc.css"
        exc.write_text(":root{--a:#fff}\n.x{color:var(--a); /* token-exception: hairline */ border-top: 1px solid var(--a)}\n", encoding="utf-8")
        code, out, _ = run(TL, str(exc), "--quiet")
        self.assertEqual(code, 0)
        self.assertIn("compliant except for documented exceptions", out)
        code, _, _ = run(TL, str(self.dir / "missing.css"))
        self.assertEqual(code, 2)
        out_file = self.dir / "ledger.json"
        code, _, _ = run(TL, str(clean), "--json", "--out", str(out_file))
        self.assertEqual(json.loads(out_file.read_text())["summary"]["violations"], 0)


class ImportAllowlistTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "src").mkdir()
        (self.root / "tests").mkdir()
        (self.root / "node_modules" / "left-pad").mkdir(parents=True)
        (self.root / "node_modules" / "left-pad" / "index.js").write_text("import fs from 'fs'\n")
        (self.root / "app.js").write_text("import { a } from './src/logic.js';\nimport { d } from './src/data.js';\n")
        (self.root / "src" / "logic.js").write_text("import { d } from './data.js';\nexport const a = d;\n")
        (self.root / "src" / "data.js").write_text("export const d = 1;\n")
        (self.root / "tests" / "t.test.mjs").write_text("import test from 'node:test';\nimport { chromium } from 'playwright';\nimport { a } from '../src/logic.js';\n")
        self.cfg = self.root / "architecture.json"
        self.write_cfg({
            "modules": {"app": ["app.js"], "logic": ["src/logic.js"], "data": ["src/data.js"], "tests": ["tests/*"]},
            "allowed": {"app": ["logic", "data"], "logic": ["data"], "data": [], "tests": ["*"]},
            "external": {"*": [], "tests": ["node:*", "playwright"]},
        })

    def tearDown(self):
        self.tmp.cleanup()

    def write_cfg(self, cfg):
        self.cfg.write_text(json.dumps(cfg), encoding="utf-8")

    def test_clean_layout_passes_and_ignores_node_modules(self):
        code, out, _ = run(IA, str(self.cfg))
        self.assertEqual(code, 0, out)
        self.assertIn("OK", out)

    def test_layer_external_and_unassigned_violations(self):
        (self.root / "src" / "data.js").write_text("import { a } from './logic.js';\nimport lp from 'left-pad';\nexport const d = 1;\n")
        (self.root / "src" / "stray.js").write_text("export const s = 1;\n")
        code, out, _ = run(IA, str(self.cfg), "--json")
        self.assertEqual(code, 1)
        result = json.loads(out)
        kinds = sorted(v["kind"] for v in result["violations"])
        self.assertEqual(kinds, ["external", "layer", "unassigned"])
        layer = next(v for v in result["violations"] if v["kind"] == "layer")
        self.assertEqual(layer["file"], "src/data.js")
        self.assertEqual(layer["line"], 1)
        self.assertIn("'data' may not import module 'logic'", layer["detail"])

    def test_python_imports_resolve_and_stdlib_is_allowed(self):
        (self.root / "pkg").mkdir()
        (self.root / "pkg" / "__init__.py").write_text("")
        (self.root / "pkg" / "core.py").write_text("import json\nfrom pkg import util\n")
        (self.root / "pkg" / "util.py").write_text("import requests\n")
        self.write_cfg({
            "modules": {"core": ["pkg/core.py", "pkg/__init__.py"], "util": ["pkg/util.py"], "js": ["app.js", "src/*", "tests/*"]},
            "allowed": {"core": ["util"], "util": [], "js": ["*"]},
            "external": {"*": ["node:*", "playwright"]},
        })
        code, out, _ = run(IA, str(self.cfg), "--json")
        result = json.loads(out)
        self.assertEqual(code, 1)
        self.assertEqual([(v["file"], v["kind"]) for v in result["violations"]], [("pkg/util.py", "external")])

    def test_bad_config_is_rejected(self):
        self.write_cfg({"modules": {"app": ["app.js"]}, "allowed": {"app": ["ghost"]}})
        with self.assertRaises(SystemExit):
            IA.load_config(self.cfg)
        code, _, err = run(IA, str(self.root / "nope.json"))
        self.assertEqual(code, 2)
        self.assertIn("not found", err)


if __name__ == "__main__":
    unittest.main()
