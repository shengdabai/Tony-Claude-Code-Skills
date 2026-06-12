# onepage-pdf

Convert an HTML page into a **single continuous-page PDF** — one tall page, no
pagination breaks, desktop layout preserved, text selectable.

为长滚动式 HTML（提案、报告、落地页）生成不分页的单页 PDF，桌面布局原样保留。

## Why

Chrome's print pipeline cannot tell you the printed height of a page up front:
print media queries evaluate against the default paper width (~741px) instead
of your `@page` size, viewport units drift, web fonts shift line heights, and
the px→inch→pt conversion rounds badly enough to spawn phantom pages
([puppeteer#2278](https://github.com/puppeteer/puppeteer/issues/2278)).

So this tool never predicts the height. It renders onto an oversized "bedrock"
page with headless Chrome, then measures the real content bottom from the PDF
itself (PyMuPDF render-level bbox log) and crops MediaBox + CropBox to fit.
**Height is cropped, not calculated** — the result is exact by construction.

## Requirements

- Python 3.10+ with [`pymupdf`](https://pypi.org/project/PyMuPDF/)
- A local Chrome or Edge (auto-detected, or pass `--chrome`)

## Usage

```bash
python scripts/onepage_pdf.py input.html -o output.pdf --width 1280
```

Try it on the bundled demo (gradient background, 3-column grid, glassmorphism,
scroll-reveal animations, CJK typography):

```bash
python scripts/onepage_pdf.py examples/demo.html -o demo.pdf \
    --extra-css examples/demo-fixes.css
```

### Options

| Flag | Default | Purpose |
|---|---|---|
| `--width` | 1280 | Page width in CSS px (snapped to 8px to dodge MediaBox rounding) |
| `--bedrock` | 18000 | Initial oversized height; auto-doubles on overflow |
| `--padding` | 32 | Whitespace kept below the content, px |
| `--extra-css` | — | CSS appended to the injected print styles (breakpoint locks, glass fallbacks) |
| `--replace` | — | JSON `[["old","new"],...]` applied before rendering (redaction) |
| `--forbid` | — | Word list; abort if any survives in the HTML **or** the final PDF text |
| `--crop` | vector | `vector` (bbox log) or `pixel` (raster row scan) content detection |
| `--virtual-time` | 10000 | Chrome `--virtual-time-budget` ms for JS-driven pages |

### What gets handled for you

- Scroll-reveal animations forced visible (`fade*`/`reveal*`/`animate*`/`aos`)
- Background colors and gradients preserved (`print-color-adjust: exact`)
- `background-attachment: fixed` normalized (Chrome paints it on page 1 only)
- Overflow auto-retry: bedrock doubles until the content fits on one page
- Both MediaBox and CropBox rewritten identically (viewer compatibility)
- Single-page assertion + redaction leak check against the PDF text layer
- Warns when output exceeds the 14400pt Acrobat limit (Chrome/Firefox/WeChat
  render larger pages fine)

### What you still do by hand

Responsive breakpoints ≥741px fire during print and collapse desktop grids —
lock them back with `--extra-css` (see `examples/demo-fixes.css`). Same file is
the place for glassmorphism fallbacks: `backdrop-filter` blur is silently
dropped in PDF output ([crbug 40895818](https://issues.chromium.org/issues/40895818)).

The full rationale — two-viewport media query behavior, the hidden 1.5×
print shrink, PDF size limits, CJK font pitfalls — is documented in
[references/mechanics.md](references/mechanics.md).

## As a Claude Code skill

This repo is also an agent skill: drop it into `~/.claude/skills/onepage-pdf`
and Claude Code will inspect the source HTML, generate the breakpoint locks
itself, run the conversion and eyeball-verify the output. See
[SKILL.md](SKILL.md).

## License

MIT
