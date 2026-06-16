#!/usr/bin/env python3
"""Render a PDF into ONE tall JPG for Feishu image messages.

Feishu's mobile PDF preview crashes on tall single-page PDFs. The image
channel does not — so this rasterizes a PDF (normally the onepage continuous
page) into a single long image. Multi-page sources are stacked vertically.
Refuses if the result would exceed Feishu's image limits so the caller can
fall back to per-page images.
"""

import argparse
import sys
from pathlib import Path

try:
    import pymupdf
except ImportError:
    import fitz as pymupdf

# Feishu image message limits: <=10MB file. Very tall images can also fail to
# render, so cap pixel height and downshift quality before giving up.
MAX_BYTES = 9_500_000
DEFAULT_MAX_HEIGHT_PX = 30000


def render_long_image(pdf_path, out_path, dpi, jpeg_quality, max_height_px):
    doc = pymupdf.open(pdf_path)
    if doc.page_count < 1:
        sys.exit("PDF has no pages")

    zoom = dpi / 72.0
    matrix = pymupdf.Matrix(zoom, zoom)
    pixes = [page.get_pixmap(matrix=matrix, colorspace=pymupdf.csRGB, alpha=False) for page in doc]
    doc.close()

    max_w = max(p.width for p in pixes)
    total_h = sum(p.height for p in pixes)
    if total_h > max_height_px:
        sys.exit(f"long image too tall: {total_h}px > {max_height_px}px; use images mode")

    if len(pixes) == 1:
        combined = pixes[0]
    else:
        combined = pymupdf.Pixmap(pymupdf.csRGB, pymupdf.IRect(0, 0, max_w, total_h))
        combined.clear_with(255)
        y = 0
        for p in pixes:
            tile = pymupdf.Pixmap(p)  # copy so we can re-origin without touching source
            tile.set_origin(0, y)
            combined.copy(tile, tile.irect)
            y += p.height

    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # Re-encode at decreasing quality until under the byte cap.
    quality = jpeg_quality
    while True:
        try:
            data = combined.tobytes("jpeg", jpg_quality=quality)
        except TypeError:
            data = combined.tobytes("png")
            out_path = out_path.with_suffix(".png")
            out_path.write_bytes(data)
            return out_path, max_w, total_h, len(data)
        if len(data) <= MAX_BYTES or quality <= 50:
            out_path.write_bytes(data)
            if len(data) > MAX_BYTES:
                sys.exit(
                    f"long image still {len(data)//1024}KB > {MAX_BYTES//1024}KB at q{quality}; "
                    "use images mode"
                )
            return out_path, max_w, total_h, len(data)
        quality -= 8


def main():
    ap = argparse.ArgumentParser(description="PDF -> single tall JPG for Feishu")
    ap.add_argument("input", help="source PDF (normally onepage continuous page)")
    ap.add_argument("-o", "--output", required=True, help="destination .jpg")
    ap.add_argument("--dpi", type=int, default=132, help="render DPI (default 132)")
    ap.add_argument("--jpeg-quality", type=int, default=82, help="starting JPEG quality")
    ap.add_argument("--max-height-px", type=int, default=DEFAULT_MAX_HEIGHT_PX)
    args = ap.parse_args()

    out, w, h, nbytes = render_long_image(
        args.input, args.output, args.dpi, args.jpeg_quality, args.max_height_px
    )
    print(f"OK long image {w}x{h}px, {nbytes//1024} KB -> {out}")


if __name__ == "__main__":
    main()
