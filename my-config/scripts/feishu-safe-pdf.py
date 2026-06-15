#!/usr/bin/env python3
"""Render HTML into a Feishu-preview-safe PDF.

The onepage-pdf flow is useful for local archives, but Feishu's mobile PDF
preview can crash on very tall one-page PDFs, unusual page boxes, or complex
Chrome vector PDFs. This script prints the same desktop-width HTML into
fixed-height pages and, by default, flattens those pages into simple A4 image
PDF pages before upload.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

try:
    import pymupdf
except ImportError:
    import fitz as pymupdf

BROWSERS = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
]

PRINT_CSS = """
<style data-feishu-safe-pdf>
  @page {{ size: {width}px {page_height}px; margin: 0; }}
  html, body {{
    width: {width}px !important;
    margin: 0 !important;
  }}
  * {{
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
    animation: none !important;
    transition: none !important;
    background-attachment: scroll !important;
  }}
  [class*="fade"], [class*="reveal"], [class*="animate"], [class*="aos"],
  [data-aos] {{
    opacity: 1 !important;
    transform: none !important;
    visibility: visible !important;
  }}
{extra}
</style>
</head>"""


def find_browser(explicit):
    if explicit:
        if Path(explicit).exists():
            return explicit
        sys.exit(f"browser not found: {explicit}")
    for path in BROWSERS:
        if Path(path).exists():
            return path
    found = shutil.which("chrome") or shutil.which("chromium") or shutil.which("msedge")
    if found:
        return found
    sys.exit("no Chrome/Edge found; pass --chrome PATH")


def align8(value):
    return max(8, int(round(value / 8.0)) * 8)


def normalize_pdf(src, dest, max_page_height_pt):
    doc = pymupdf.open(src)
    if doc.page_count < 1:
        sys.exit("rendered PDF has no pages")

    max_w = max_h = 0
    for i, page in enumerate(doc, start=1):
        rect = page.rect
        max_w = max(max_w, rect.width)
        max_h = max(max_h, rect.height)
        if rect.height > max_page_height_pt:
            sys.exit(
                f"page {i} too tall for Feishu preview: "
                f"{rect.height:.0f}pt > {max_page_height_pt:.0f}pt"
            )

    pages = doc.page_count
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".tmp")
    doc.save(tmp, garbage=4, deflate=True, clean=True)
    doc.close()
    tmp.replace(dest)
    return pages, max_w, max_h


def fit_rect(src_rect, dest_rect):
    scale = min(dest_rect.width / src_rect.width, dest_rect.height / src_rect.height)
    width = src_rect.width * scale
    height = src_rect.height * scale
    x0 = dest_rect.x0 + (dest_rect.width - width) / 2
    y0 = dest_rect.y0 + (dest_rect.height - height) / 2
    return pymupdf.Rect(x0, y0, x0 + width, y0 + height)


def rasterize_pdf(src, dest, dpi, jpeg_quality, max_page_height_pt):
    src_doc = pymupdf.open(src)
    if src_doc.page_count < 1:
        sys.exit("rendered PDF has no pages")

    # ISO A4 in points. The source page ratio (1280x1800) is intentionally close
    # to A4, so this keeps pages readable without unusual dimensions.
    a4_w, a4_h = 595.28, 841.89
    out_doc = pymupdf.open()
    target = pymupdf.Rect(0, 0, a4_w, a4_h)

    max_w = max_h = 0
    for i, page in enumerate(src_doc, start=1):
        rect = page.rect
        max_w = max(max_w, a4_w)
        max_h = max(max_h, a4_h)
        if rect.height > max_page_height_pt:
            sys.exit(
                f"source page {i} too tall for Feishu preview conversion: "
                f"{rect.height:.0f}pt > {max_page_height_pt:.0f}pt"
            )

        zoom = dpi / 72.0
        pix = page.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), colorspace=pymupdf.csRGB, alpha=False)
        try:
            image = pix.tobytes("jpeg", jpg_quality=jpeg_quality)
        except TypeError:
            image = pix.tobytes("png")
        out_page = out_doc.new_page(width=a4_w, height=a4_h)
        out_page.insert_image(fit_rect(rect, target), stream=image)

    pages = out_doc.page_count
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".tmp")
    out_doc.save(tmp, garbage=4, deflate=True, clean=True)
    out_doc.close()
    src_doc.close()
    tmp.replace(dest)
    return pages, max_w, max_h


def export_page_images(pdf_path, images_dir, dpi, jpeg_quality):
    images_dir = Path(images_dir)
    if images_dir.exists():
        for old in images_dir.glob("*"):
            if old.is_file():
                old.unlink()
    images_dir.mkdir(parents=True, exist_ok=True)

    doc = pymupdf.open(pdf_path)
    paths = []
    for i, page in enumerate(doc, start=1):
        zoom = dpi / 72.0
        pix = page.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), colorspace=pymupdf.csRGB, alpha=False)
        out = images_dir / f"page-{i:03d}.jpg"
        try:
            out.write_bytes(pix.tobytes("jpeg", jpg_quality=jpeg_quality))
        except TypeError:
            out = images_dir / f"page-{i:03d}.png"
            out.write_bytes(pix.tobytes("png"))
        paths.append(out)
    doc.close()
    return paths


def main():
    parser = argparse.ArgumentParser(description="HTML -> Feishu-safe paginated PDF")
    parser.add_argument("input", help="source HTML file")
    parser.add_argument("-o", "--output", required=True, help="destination PDF")
    parser.add_argument("--width", type=int, default=1280, help="desktop layout width in CSS px")
    parser.add_argument(
        "--page-height",
        type=int,
        default=1800,
        help="page height in CSS px; 1800px = 1350pt, safe for Feishu mobile preview",
    )
    parser.add_argument("--extra-css", help="CSS appended to injected print styles")
    parser.add_argument("--chrome", help="explicit Chrome/Edge executable")
    parser.add_argument("--virtual-time", type=int, default=10000)
    parser.add_argument("--max-page-height-pt", type=float, default=2000)
    parser.add_argument(
        "--mode",
        choices=["raster", "vector"],
        default="raster",
        help="raster flattens pages into A4 image PDF; vector keeps Chrome PDF structure",
    )
    parser.add_argument("--dpi", type=int, default=144, help="raster mode render DPI")
    parser.add_argument("--jpeg-quality", type=int, default=88, help="raster mode JPEG quality")
    parser.add_argument("--images-dir", help="optional directory for exported page images")
    args = parser.parse_args()

    src = Path(args.input)
    html = src.read_text(encoding="utf-8")
    if "</head>" not in html:
        sys.exit("input HTML has no </head>; cannot inject print CSS")

    width = align8(args.width)
    page_height = align8(args.page_height)
    extra = Path(args.extra_css).read_text(encoding="utf-8") if args.extra_css else ""
    injected = html.replace(
        "</head>",
        PRINT_CSS.format(width=width, page_height=page_height, extra=extra),
        1,
    )

    browser = find_browser(args.chrome)
    workdir = Path(tempfile.gettempdir()) / f"feishu-safe-pdf-{uuid.uuid4().hex[:8]}"
    workdir.mkdir()
    tmp_html = workdir / "in.html"
    tmp_pdf = workdir / "out.pdf"
    try:
        tmp_html.write_text(injected, encoding="utf-8")
        cmd = [
            browser,
            "--headless=new",
            "--disable-gpu",
            "--no-pdf-header-footer",
            "--hide-scrollbars",
            f"--window-size={width},2000",
            f"--virtual-time-budget={args.virtual_time}",
            "--run-all-compositor-stages-before-draw",
            f"--print-to-pdf={tmp_pdf}",
            tmp_html.as_uri(),
        ]
        subprocess.run(cmd, check=True, timeout=180, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if args.mode == "raster":
            _, max_w, max_h = rasterize_pdf(tmp_pdf, args.output, args.dpi, args.jpeg_quality, args.max_page_height_pt)
        else:
            _, max_w, max_h = normalize_pdf(tmp_pdf, args.output, args.max_page_height_pt)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    out = Path(args.output)
    doc = pymupdf.open(out)
    pages = doc.page_count
    doc.close()
    image_count = 0
    if args.images_dir:
        image_count = len(export_page_images(out, args.images_dir, args.dpi, args.jpeg_quality))
    size_kb = out.stat().st_size / 1024
    print(f"OK feishu-safe PDF ({args.mode}), {pages} pages, max {max_w:.0f}x{max_h:.0f}pt, {size_kb:.0f} KB -> {out}")
    if args.images_dir:
        print(f"OK page images, {image_count} files -> {args.images_dir}")


if __name__ == "__main__":
    main()
