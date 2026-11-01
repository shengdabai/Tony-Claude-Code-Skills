#!/usr/bin/env python3
"""token_ledger: audit CSS (and inline HTML styles) against a design-token contract and emit a ledger.

What it checks (stdlib only, tolerant CSS scanner, no external parser):

* Token definitions: every ``--name: value`` declaration, with the scope it was defined in
  (``:root`` / theme selectors count as the authoritative source; anything else is reported
  as a component-scoped definition).
* Token usage: every ``var(--name)`` reference, so unused tokens and undefined references
  surface. A raw fallback such as ``var(--x, #fff)`` is a violation: fallbacks hide literals.
* Raw design literals outside the token source: colours, lengths, font stacks, numeric
  font weights / line heights / z-index / opacity, durations, shadows. Structural values
  (``0``, ``100%``, ``auto``, ``1fr``, ``none``, ``inherit``, ``currentColor``…) and
  structural properties (``display``, ``position``, ``flex`` …) are not design decisions.
* Media-query thresholds are listed separately: ``var()`` cannot be used there, so they are
  reported as documented literals, never counted as violations.
* Exceptions: a comment ``/* token-exception: <reason> */`` on the same line or on the line
  before a declaration records a deliberate literal. Exceptions are listed, not counted as
  tokenized — so the ledger can say "compliant except for documented exceptions".

Exit codes: 0 no violations, 1 violations found (always, so CI can gate on it), 2 input error.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
from collections import Counter
from dataclasses import asdict, dataclass, field
from pathlib import Path

TOKEN_SCOPES = re.compile(r"^(:root|html|:host|\[data-theme[^\]]*\]|\.theme-[\w-]+|:root\[[^\]]*\]|:root:not\([^)]*\))(\s*,\s*(:root|html|\[data-theme[^\]]*\]|\.theme-[\w-]+))*$")
STRUCTURAL_PROPS = {
    "display", "position", "flex", "flex-direction", "flex-wrap", "flex-grow", "flex-shrink", "flex-basis", "order",
    "grid-template-columns", "grid-template-rows", "grid-template-areas", "grid-column", "grid-row", "grid-area",
    "grid-auto-flow", "grid-auto-rows", "grid-auto-columns", "justify-content", "justify-items", "justify-self",
    "align-items", "align-content", "align-self", "place-items", "place-content", "overflow", "overflow-x", "overflow-y",
    "overflow-wrap", "box-sizing", "white-space", "word-break", "text-overflow", "visibility", "pointer-events",
    "user-select", "cursor", "content", "appearance", "-webkit-appearance", "list-style", "text-decoration", "text-align",
    "vertical-align", "object-fit", "object-position", "resize", "table-layout", "border-collapse", "text-transform",
    "font-variant-numeric", "font-feature-settings", "text-rendering", "-webkit-font-smoothing", "scroll-behavior",
    "overscroll-behavior", "touch-action", "will-change", "contain", "isolation", "mix-blend-mode", "background-repeat",
    "background-size", "background-position", "background-clip", "aspect-ratio", "columns", "column-count", "float",
    "clear", "direction", "unicode-bidi", "writing-mode", "hyphens", "tab-size", "color-scheme", "font-style",
    "text-wrap", "text-size-adjust", "-webkit-text-size-adjust", "transform-origin", "backface-visibility",
}
STRUCTURAL_VALUES = {
    "0", "0px", "0%", "100%", "100vw", "100vh", "100dvh", "100svh", "auto", "none", "inherit", "initial", "unset", "revert",
    "currentcolor", "transparent", "1fr", "1", "-1", "normal", "nowrap", "wrap", "hidden", "visible", "block", "inline",
    "inline-block", "flex", "grid", "contents", "pointer", "default", "both", "row", "column", "center", "start", "end",
    "stretch", "baseline", "space-between", "space-around", "space-evenly", "left", "right", "top", "bottom", "middle",
    "relative", "absolute", "fixed", "sticky", "static", "cover", "contain", "no-repeat", "repeat", "border-box",
    "content-box", "max-content", "min-content", "fit-content", "italic", "bold", "bolder", "lighter", "underline",
    "uppercase", "lowercase", "capitalize", "ellipsis", "clip", "scroll", "collapse", "separate", "solid", "dashed",
    "dotted", "double", "inset", "outset", "ridge", "groove", "break-word", "anywhere", "pre", "pre-wrap", "pre-line",
    "balance", "pretty", "light", "dark", "only", "antialiased", "grayscale", "optimizelegibility", "tabular-nums",
    "sans-serif", "serif", "monospace", "system-ui", "ui-sans-serif", "ui-monospace", "ui-serif", "infinite", "forwards",
    "backwards", "ease", "ease-in", "ease-out", "ease-in-out", "linear", "step-start", "step-end", "alternate",
    "running", "paused", "all", "opacity", "transform", "color", "background-color", "border-color", "box-shadow",
    "ltr", "rtl", "smooth", "manipulation", "isolate", "multiply", "screen", "overlay", "span", "dense", "subgrid",
}
NAMED_COLORS = {
    "white", "black", "red", "green", "blue", "yellow", "orange", "purple", "pink", "gray", "grey", "silver", "maroon",
    "navy", "teal", "olive", "lime", "aqua", "cyan", "magenta", "fuchsia", "brown", "beige", "ivory", "gold", "coral",
    "crimson", "indigo", "violet", "khaki", "lavender", "salmon", "tan", "tomato", "turquoise", "wheat", "whitesmoke",
    "slategray", "slategrey", "lightgray", "lightgrey", "darkgray", "darkgrey", "dimgray", "dimgrey", "gainsboro",
    "royalblue", "steelblue", "skyblue", "dodgerblue", "firebrick", "forestgreen", "seagreen", "goldenrod",
}
COLOR_FN = re.compile(r"\b(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|color|color-mix|light-dark)\(", re.I)
HEX_COLOR = re.compile(r"(?<![\w-])#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b")
LENGTH = re.compile(r"(?<![\w.-])-?\d*\.?\d+(?:px|rem|em|ch|ex|vw|vh|vmin|vmax|dvh|svh|lvh|dvw|svw|lvw|cqw|cqh|cqi|cqb|pt|pc|cm|mm|in|%|ms|s|deg|rad|turn|fr)\b", re.I)
BARE_NUMBER = re.compile(r"(?<![\w.#-])-?\d*\.?\d+(?![\w.%-])")
VAR_REF = re.compile(r"var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*(?:\([^()]*\)[^()]*)*))?\)")
EXCEPTION_RE = re.compile(r"token-exception\s*:\s*([^*]*?)\s*\*/")
NUMERIC_DESIGN_PROPS = {"font-weight", "line-height", "z-index", "opacity", "letter-spacing", "flex-grow", "scale", "zoom", "stroke-width"}
NUMERIC_STRUCTURAL_OK = {"opacity": {"0", "1"}, "z-index": {"0", "1", "-1", "auto"}, "line-height": {"1", "normal"}, "font-weight": {"normal", "bold", "inherit"}, "flex-grow": {"0", "1"}, "scale": {"1", "none"}, "zoom": {"1"}, "stroke-width": set()}
URL_RE = re.compile(r"url\([^)]*\)")
STRING_RE = re.compile(r"\"[^\"]*\"|'[^']*'")


@dataclass
class TokenDef:
    name: str
    value: str
    scope: str
    file: str
    line: int
    authoritative: bool


@dataclass
class Finding:
    kind: str  # raw-literal | raw-fallback | undefined-token | component-token | exception
    file: str
    line: int
    selector: str
    property: str
    value: str
    detail: str = ""


@dataclass
class Ledger:
    files: list[str]
    tokens: list[TokenDef] = field(default_factory=list)
    uses: dict[str, int] = field(default_factory=dict)
    unused: list[str] = field(default_factory=list)
    violations: list[Finding] = field(default_factory=list)
    exceptions: list[Finding] = field(default_factory=list)
    breakpoints: list[dict] = field(default_factory=list)
    inline_styles: int = 0

    def to_json(self) -> dict:
        return {
            "files": self.files,
            "tokens": [asdict(t) for t in self.tokens],
            "uses": self.uses,
            "unused": self.unused,
            "violations": [asdict(f) for f in self.violations],
            "exceptions": [asdict(f) for f in self.exceptions],
            "breakpoints": self.breakpoints,
            "inline_styles": self.inline_styles,
            "summary": {
                "tokens": len(self.tokens),
                "violations": len(self.violations),
                "exceptions": len(self.exceptions),
                "unused": len(self.unused),
                "status": "100% tokenized" if not self.violations and not self.exceptions else ("compliant except for documented exceptions" if not self.violations else "violations"),
            },
        }


# ------------------------------------------------------------------ CSS scanning


def strip_comments(text: str) -> tuple[str, dict[int, str]]:
    """Blank out comments (keeping newlines) and collect token-exception reasons per line."""
    exceptions: dict[int, str] = {}
    out = []
    i = 0
    line = 1
    while i < len(text):
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                end = len(text) - 2
            body = text[i : end + 2]
            m = EXCEPTION_RE.search(body)
            if m:
                exceptions[line] = m.group(1).strip() or "(no reason given)"
            out.append(re.sub(r"[^\n]", " ", body))
            line += body.count("\n")
            i = end + 2
            continue
        ch = text[i]
        if ch == "\n":
            line += 1
        out.append(ch)
        i += 1
    return "".join(out), exceptions


def iter_blocks(css: str):
    """Yield (selector_stack, prop, value, line) for every declaration, descending into at-rules."""
    i = 0
    n = len(css)
    line = 1
    stack: list[str] = []
    buf = []
    buf_line = line
    has_content = False
    while i < n:
        ch = css[i]
        if ch == "\n":
            line += 1
        if ch == "{":
            selector = "".join(buf).strip()
            stack.append(selector)
            buf = []
            buf_line = line
            has_content = False
        elif ch == "}":
            pending = "".join(buf).strip()
            if pending:
                yield from _emit_decl(stack, pending, buf_line)
            buf = []
            buf_line = line
            has_content = False
            if stack:
                stack.pop()
        elif ch == ";":
            decl = "".join(buf).strip()
            if decl:
                yield from _emit_decl(stack, decl, buf_line)
            buf = []
            buf_line = line
            has_content = False
        else:
            if not has_content and not ch.isspace():
                buf_line = line
                has_content = True
            buf.append(ch)
        i += 1


def _emit_decl(stack: list[str], decl: str, line: int):
    if ":" not in decl or not stack:
        return
    prop, _, value = decl.partition(":")
    prop = prop.strip().lower()
    value = value.strip()
    if not prop or decl.startswith("@"):
        return
    yield list(stack), prop, value, line


def is_authoritative(stack: list[str]) -> bool:
    if not stack:
        return False
    selectors = [s for s in stack if not s.startswith("@")]
    at_rules = [s for s in stack if s.startswith("@")]
    if not selectors:
        return False
    if any(not a.startswith(("@media", "@supports", "@layer")) for a in at_rules):
        return False
    return bool(TOKEN_SCOPES.match(selectors[-1].strip()))


def classify_literals(prop: str, value: str, line_lower: str) -> list[str]:
    """Return the raw design literals in a value (after var() calls and urls/strings are removed)."""
    stripped = VAR_REF.sub(" ", value)
    stripped = URL_RE.sub(" ", stripped)
    stripped_no_strings = STRING_RE.sub(" ", stripped)
    found: list[str] = []
    if prop in ("font-family", "font"):
        # font stacks are design decisions: any quoted family or non-generic bare family is a literal
        for s in STRING_RE.findall(stripped):
            found.append(s)
        for word in re.split(r"[,\s]+", stripped_no_strings):
            w = word.strip().lower()
            if w and w not in STRUCTURAL_VALUES and not LENGTH.match(w) and not BARE_NUMBER.fullmatch(w) and w not in {"/", "!important"}:
                found.append(word)
        if prop == "font":
            found.extend(LENGTH.findall(stripped_no_strings))
        return found
    found.extend(HEX_COLOR.findall(stripped_no_strings))
    for m in COLOR_FN.finditer(stripped_no_strings):
        # capture the full function call
        depth = 0
        j = m.start()
        while j < len(stripped_no_strings):
            if stripped_no_strings[j] == "(":
                depth += 1
            elif stripped_no_strings[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        call = stripped_no_strings[m.start() : j + 1]
        # color-mix(in srgb, currentColor var(--tint), transparent) carries no literal; a call with digits or # does.
        inner = VAR_REF.sub(" ", call)
        if re.search(r"[0-9#]", inner):
            found.append(call)
    for word in re.split(r"[\s,/]+", stripped_no_strings):
        w = word.strip().lower()
        if w in NAMED_COLORS:
            found.append(word)
    if prop in STRUCTURAL_PROPS:
        return found  # only colours count on structural properties
    for m in LENGTH.finditer(stripped_no_strings):
        tok = m.group(0)
        if tok.lower() in STRUCTURAL_VALUES:
            continue
        if prop.startswith("grid-template") or prop in ("flex", "flex-basis"):
            continue
        found.append(tok)
    if prop in NUMERIC_DESIGN_PROPS:
        for m in BARE_NUMBER.finditer(stripped_no_strings):
            tok = m.group(0)
            if tok in NUMERIC_STRUCTURAL_OK.get(prop, set()):
                continue
            found.append(tok)
    if prop in ("transition", "animation", "transition-duration", "animation-duration", "transition-timing-function", "animation-timing-function"):
        for fn in re.findall(r"cubic-bezier\([^)]*\)|steps\([^)]*\)", stripped_no_strings):
            found.append(fn)
    if prop in ("box-shadow", "text-shadow", "filter", "backdrop-filter"):
        for fn in re.findall(r"(?:drop-shadow|blur|brightness|contrast|saturate|grayscale|hue-rotate|sepia|invert)\([^)]*\)", stripped_no_strings):
            if LENGTH.search(fn) or BARE_NUMBER.search(fn):
                found.append(fn)
    return found


def scan_css(text: str, file: str, ledger: Ledger, defined: dict[str, TokenDef], uses: Counter, pending: list[tuple]):
    css, exceptions = strip_comments(text)
    for stack, prop, value, line in iter_blocks(css):
        selector = " > ".join(stack)
        reason = exceptions.get(line) or exceptions.get(line - 1)
        if prop.startswith("--"):
            auth = is_authoritative(stack)
            tdef = TokenDef(prop, value, selector, file, line, auth)
            ledger.tokens.append(tdef)
            if prop not in defined or (auth and not defined[prop].authoritative):
                defined[prop] = tdef
            for m in VAR_REF.finditer(value):
                uses[m.group(1)] += 1
                pending.append((m.group(1), file, line, selector, prop, value))
            if not auth:
                ledger.violations.append(Finding("component-token", file, line, selector, prop, value, "token defined outside the authoritative source (:root / theme selector)"))
            continue
        for m in VAR_REF.finditer(value):
            uses[m.group(1)] += 1
            pending.append((m.group(1), file, line, selector, prop, value))
            if m.group(2) is not None and m.group(2).strip():
                fb = m.group(2).strip()
                if not fb.startswith("var("):
                    f = Finding("raw-fallback", file, line, selector, prop, value, f"raw fallback {fb} hides a literal")
                    (ledger.exceptions if reason else ledger.violations).append(f)
        literals = classify_literals(prop, value, "")
        if literals:
            f = Finding("raw-literal", file, line, selector, prop, value, ", ".join(dict.fromkeys(literals)))
            if reason:
                f.detail += f" — exception: {reason}"
                ledger.exceptions.append(f)
            else:
                ledger.violations.append(f)
    for m in re.finditer(r"@media[^{]*\(([^)]*)\)", css):
        cond = m.group(1)
        for lm in LENGTH.finditer(cond):
            ledger.breakpoints.append({"file": file, "line": css.count("\n", 0, m.start()) + 1, "query": cond.strip(), "value": lm.group(0)})


def scan_html(text: str, file: str, ledger: Ledger, defined, uses, pending):
    for m in re.finditer(r"<style[^>]*>(.*?)</style>", text, re.S | re.I):
        offset = text.count("\n", 0, m.start(1))
        sub = Ledger(files=[])
        scan_css(m.group(1), file, sub, defined, uses, pending)
        for coll_name in ("tokens", "violations", "exceptions", "breakpoints"):
            for item in getattr(sub, coll_name):
                if hasattr(item, "line"):
                    item.line += offset
                elif isinstance(item, dict):
                    item["line"] += offset
            getattr(ledger, coll_name).extend(getattr(sub, coll_name))
    for m in re.finditer(r"\sstyle\s*=\s*\"([^\"]*)\"", text, re.I):
        ledger.inline_styles += 1
        line = text.count("\n", 0, m.start()) + 1
        fake = f"inline {{ {m.group(1)} }}"
        css, _ = strip_comments(fake)
        for stack, prop, value, _l in iter_blocks(css):
            for vm in VAR_REF.finditer(value):
                uses[vm.group(1)] += 1
                pending.append((vm.group(1), file, line, "style=", prop, value))
            literals = classify_literals(prop, value, "")
            if literals:
                ledger.violations.append(Finding("raw-literal", file, line, "style=", prop, value, ", ".join(dict.fromkeys(literals)) + " (inline style)"))


def scan_js(text: str, file: str, uses: Counter, pending: list[tuple]):
    """Count --token references in JS (getPropertyValue('--x'), token('--x'), setProperty('--x', ...))."""
    for m in re.finditer(r"[\"'`](--[\w-]+)[\"'`]", text):
        uses[m.group(1)] += 1
        pending.append((m.group(1), file, text.count("\n", 0, m.start()) + 1, "js", "reference", m.group(0)))


# ------------------------------------------------------------------------ driver


def expand(paths: list[str]) -> list[Path]:
    out: list[Path] = []
    for p in paths:
        path = Path(p)
        if path.is_dir():
            for root, dirs, files in os.walk(path):
                dirs[:] = [d for d in dirs if d not in {"node_modules", ".git", ".git.nosync", "dist", "build", ".next", "vendor"}]
                for f in sorted(files):
                    if f.endswith((".css", ".html", ".htm", ".js", ".mjs", ".ts", ".tsx", ".jsx", ".vue", ".svelte")):
                        out.append(Path(root) / f)
        elif any(ch in p for ch in "*?["):
            out.extend(sorted(Path().glob(p)))
        elif path.is_file():
            out.append(path)
        else:
            raise FileNotFoundError(p)
    return out


def build_ledger(paths: list[Path], ignore: list[str]) -> Ledger:
    ledger = Ledger(files=[str(p) for p in paths])
    defined: dict[str, TokenDef] = {}
    uses: Counter = Counter()
    pending: list[tuple] = []
    for path in paths:
        if any(fnmatch.fnmatch(str(path), pat) for pat in ignore):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        suffix = path.suffix.lower()
        if suffix == ".css":
            scan_css(text, str(path), ledger, defined, uses, pending)
        elif suffix in (".html", ".htm", ".vue", ".svelte"):
            scan_html(text, str(path), ledger, defined, uses, pending)
        else:
            scan_js(text, str(path), uses, pending)
    ledger.uses = dict(sorted(uses.items()))
    names = {t.name for t in ledger.tokens}
    for name, file, line, selector, prop, value in pending:
        if name not in names:
            ledger.violations.append(Finding("undefined-token", file, line, selector, prop, value, f"{name} is referenced but never defined"))
    ledger.unused = sorted(n for n in names if uses.get(n, 0) == 0)
    ledger.violations.sort(key=lambda f: (f.file, f.line))
    ledger.exceptions.sort(key=lambda f: (f.file, f.line))
    return ledger


def render_markdown(ledger: Ledger) -> str:
    j = ledger.to_json()
    s = j["summary"]
    out = ["# Design token ledger", "", f"Status: **{s['status']}** — {s['tokens']} tokens, {s['violations']} violations, {s['exceptions']} documented exceptions, {s['unused']} unused tokens.", "", "Scope: " + ", ".join(f"`{f}`" for f in ledger.files), ""]
    out += ["## Tokens", "", "| token | scope | value | uses | defined at |", "|---|---|---|---|---|"]
    for t in ledger.tokens:
        scope = t.scope if t.authoritative else f"⚠ {t.scope}"
        out.append(f"| `{t.name}` | {scope} | `{t.value}` | {ledger.uses.get(t.name, 0)} | {t.file}:{t.line} |")
    if ledger.unused:
        out += ["", "## Unused tokens", ""] + [f"- `{n}`" for n in ledger.unused]
    out += ["", "## Violations", ""]
    if not ledger.violations:
        out.append("None.")
    for f in ledger.violations:
        out.append(f"- **{f.kind}** {f.file}:{f.line} `{f.selector}` → `{f.property}: {f.value}` — {f.detail}")
    out += ["", "## Documented exceptions", ""]
    if not ledger.exceptions:
        out.append("None.")
    for f in ledger.exceptions:
        out.append(f"- {f.file}:{f.line} `{f.selector}` → `{f.property}: {f.value}` — {f.detail}")
    out += ["", "## Media-query thresholds (literal by necessity; keep them documented in the token source)", ""]
    if not ledger.breakpoints:
        out.append("None.")
    for b in ledger.breakpoints:
        out.append(f"- {b['file']}:{b['line']} `{b['query']}`")
    if ledger.inline_styles:
        out += ["", f"Inline `style=` attributes scanned: {ledger.inline_styles}"]
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="token_ledger", description=__doc__.split("\n\n")[0])
    ap.add_argument("paths", nargs="+", help="CSS/HTML/JS files, globs or directories")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of Markdown")
    ap.add_argument("--out", help="write the ledger to this file (Markdown or JSON by --json)")
    ap.add_argument("--ignore", action="append", default=[], help="glob of files to skip (repeatable)")
    ap.add_argument("--quiet", action="store_true", help="only print the one-line summary")
    args = ap.parse_args(argv)
    try:
        paths = expand(args.paths)
    except FileNotFoundError as exc:
        print(f"error: not found: {exc}", file=sys.stderr)
        return 2
    if not paths:
        print("error: no input files", file=sys.stderr)
        return 2
    ledger = build_ledger(paths, args.ignore)
    body = json.dumps(ledger.to_json(), ensure_ascii=False, indent=2) + "\n" if args.json else render_markdown(ledger)
    if args.out:
        Path(args.out).write_text(body, encoding="utf-8")
    s = ledger.to_json()["summary"]
    if args.quiet or args.out:
        print(f"token-ledger: {s['status']} | tokens {s['tokens']} | violations {s['violations']} | exceptions {s['exceptions']} | unused {s['unused']}" + (f" | written {args.out}" if args.out else ""))
        if args.quiet and not args.out and ledger.violations:
            for f in ledger.violations[:20]:
                print(f"  {f.kind} {f.file}:{f.line} {f.property}: {f.value} — {f.detail}")
    else:
        sys.stdout.write(body)
    return 1 if ledger.violations else 0


if __name__ == "__main__":
    sys.exit(main())
