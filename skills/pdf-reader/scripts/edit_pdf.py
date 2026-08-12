#!/usr/bin/env python3
"""PDF editing toolkit: merge, split, rotate, watermark, crop."""

from __future__ import annotations
import argparse
import os
import sys

# ---------------------------------------------------------------------------
# Engine detection — support both pypdf and PyPDF2
# ---------------------------------------------------------------------------

_PDF_LIB: str | None = None  # "pypdf" or "PyPDF2"


def _check_pypdf():
    """Detect which PDF library is available."""
    global _PDF_LIB
    try:
        import pypdf  # noqa: F401
        _PDF_LIB = "pypdf"
        return True
    except ImportError:
        pass
    try:
        import PyPDF2  # noqa: F401
        _PDF_LIB = "PyPDF2"
        return True
    except ImportError:
        pass
    return False


def _import_pdf_classes():
    """Import PdfReader, PdfWriter, PdfMerger from whichever library is available."""
    if _PDF_LIB == "pypdf":
        from pypdf import PdfReader, PdfWriter, PdfMerger
        return PdfReader, PdfWriter, PdfMerger
    elif _PDF_LIB == "PyPDF2":
        from PyPDF2 import PdfReader, PdfWriter, PdfMerger  # type: ignore[no-redef]
        return PdfReader, PdfWriter, PdfMerger
    else:
        print("=== ERROR ===\nNo PDF library found. Install: pip3 install pypdf")
        sys.exit(1)


def _import_rectangle():
    """Import RectangleObject for cropping."""
    if _PDF_LIB == "pypdf":
        from pypdf.generic import RectangleObject
        return RectangleObject
    elif _PDF_LIB == "PyPDF2":
        from PyPDF2.generic import RectangleObject  # type: ignore[no-redef]
        return RectangleObject
    else:
        print("=== ERROR ===\nNo PDF library found.")
        sys.exit(1)


def parse_pages(page_spec: str, total_pages: int) -> list[int]:
    """Parse '1-3,5,8-10' into 0-based page indices."""
    pages: list[int] = []
    for part in page_spec.split(","):
        part = part.strip()
        if "-" in part:
            start, end = part.split("-", 1)
            s = max(int(start) - 1, 0)
            e = min(int(end), total_pages)
            pages.extend(range(s, e))
        else:
            idx = int(part) - 1
            if 0 <= idx < total_pages:
                pages.append(idx)
    return sorted(set(pages))


# ---------------------------------------------------------------------------
# Merge
# ---------------------------------------------------------------------------


def merge_pdfs(files: list[str], output: str):
    _, _, PdfMerger = _import_pdf_classes()
    merger = PdfMerger()
    for f in files:
        if not os.path.isfile(f):
            print(f"=== ERROR ===\nFile not found: {f}")
            sys.exit(1)
        merger.append(f)
    merger.write(output)
    merger.close()
    print(f"=== Merge Complete ===\nOutput: {output}\nMerged {len(files)} files.")


# ---------------------------------------------------------------------------
# Split
# ---------------------------------------------------------------------------


def split_pdf(input_path: str, output_dir: str, pages: list[int] | None = None):
    PdfReader, PdfWriter, _ = _import_pdf_classes()
    os.makedirs(output_dir, exist_ok=True)
    reader = PdfReader(input_path)
    target = pages if pages else range(len(reader.pages))
    saved: list[str] = []
    for i in target:
        writer = PdfWriter()
        writer.add_page(reader.pages[i])
        out = os.path.join(output_dir, f"page_{i + 1}.pdf")
        with open(out, "wb") as f:
            writer.write(f)
        saved.append(out)
    print(f"=== Split Complete ===\nOutput directory: {output_dir}\nPages: {len(saved)}")
    for s in saved:
        print(f"  {s}")


# ---------------------------------------------------------------------------
# Rotate
# ---------------------------------------------------------------------------


def rotate_pdf(input_path: str, output: str, angle: int, pages: list[int] | None = None):
    PdfReader, PdfWriter, _ = _import_pdf_classes()
    if angle not in (90, 180, 270):
        print(f"=== ERROR ===\nAngle must be 90, 180, or 270. Got: {angle}")
        sys.exit(1)
    reader = PdfReader(input_path)
    writer = PdfWriter()
    target = set(pages) if pages else None
    for i, page in enumerate(reader.pages):
        if target is None or i in target:
            page.rotate(angle)
        writer.add_page(page)
    with open(output, "wb") as f:
        writer.write(f)
    rotated = "all" if target is None else str(len(target))
    print(f"=== Rotate Complete ===\nOutput: {output}\nRotated {rotated} pages by {angle}°")


# ---------------------------------------------------------------------------
# Watermark
# ---------------------------------------------------------------------------


def watermark_pdf(input_path: str, watermark_path: str, output: str, pages: list[int] | None = None):
    PdfReader, PdfWriter, _ = _import_pdf_classes()
    reader = PdfReader(input_path)
    wm_reader = PdfReader(watermark_path)
    wm_page = wm_reader.pages[0]
    writer = PdfWriter()
    target = set(pages) if pages else None
    for i, page in enumerate(reader.pages):
        if target is None or i in target:
            page.merge_page(wm_page)
        writer.add_page(page)
    with open(output, "wb") as f:
        writer.write(f)
    applied = "all" if target is None else str(len(target))
    print(f"=== Watermark Complete ===\nOutput: {output}\nApplied to {applied} pages")


# ---------------------------------------------------------------------------
# Crop
# ---------------------------------------------------------------------------


def crop_pdf(input_path: str, output: str, box: tuple, pages: list[int] | None = None):
    PdfReader, PdfWriter, _ = _import_pdf_classes()
    RectangleObject = _import_rectangle()
    reader = PdfReader(input_path)
    writer = PdfWriter()
    target = set(pages) if pages else None
    left, bottom, right, top = box
    for i, page in enumerate(reader.pages):
        if target is None or i in target:
            page.mediabox = RectangleObject([left, bottom, right, top])
        writer.add_page(page)
    with open(output, "wb") as f:
        writer.write(f)
    cropped = "all" if target is None else str(len(target))
    print(f"=== Crop Complete ===\nOutput: {output}\nCropped {cropped} pages to box ({left},{bottom},{right},{top})")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main():
    if not _check_pypdf():
        print("=== ERROR ===\nNo PDF library found.\nInstall: pip3 install pypdf")
        sys.exit(1)

    parser = argparse.ArgumentParser(description="PDF Editor — merge, split, rotate, watermark, crop")
    sub = parser.add_subparsers(dest="command", required=True)

    # merge
    p_merge = sub.add_parser("merge", help="Merge multiple PDFs")
    p_merge.add_argument("files", nargs="+", help="PDF files to merge")
    p_merge.add_argument("-o", "--output", required=True, help="Output file")

    # split
    p_split = sub.add_parser("split", help="Split PDF into individual pages")
    p_split.add_argument("input", help="Input PDF")
    p_split.add_argument("-o", "--output", required=True, help="Output directory")
    p_split.add_argument("--pages", help="Page range, e.g. '1-3,5'")

    # rotate
    p_rotate = sub.add_parser("rotate", help="Rotate pages")
    p_rotate.add_argument("input", help="Input PDF")
    p_rotate.add_argument("-o", "--output", required=True, help="Output file")
    p_rotate.add_argument("--angle", type=int, required=True, choices=[90, 180, 270])
    p_rotate.add_argument("--pages", help="Page range")

    # watermark
    p_wm = sub.add_parser("watermark", help="Add watermark overlay")
    p_wm.add_argument("input", help="Input PDF")
    p_wm.add_argument("watermark", help="Watermark PDF (first page used)")
    p_wm.add_argument("-o", "--output", required=True, help="Output file")
    p_wm.add_argument("--pages", help="Page range")

    # crop
    p_crop = sub.add_parser("crop", help="Crop pages")
    p_crop.add_argument("input", help="Input PDF")
    p_crop.add_argument("-o", "--output", required=True, help="Output file")
    p_crop.add_argument("--box", required=True, help="Crop box: left,bottom,right,top (points)")
    p_crop.add_argument("--pages", help="Page range")

    args = parser.parse_args()

    if args.command == "merge":
        merge_pdfs(args.files, args.output)

    elif args.command == "split":
        PdfReader, _, _ = _import_pdf_classes()
        pages = None
        if args.pages:
            reader = PdfReader(args.input)
            pages = parse_pages(args.pages, len(reader.pages))
        split_pdf(args.input, args.output, pages)

    elif args.command == "rotate":
        PdfReader, _, _ = _import_pdf_classes()
        pages = None
        if args.pages:
            reader = PdfReader(args.input)
            pages = parse_pages(args.pages, len(reader.pages))
        rotate_pdf(args.input, args.output, args.angle, pages)

    elif args.command == "watermark":
        PdfReader, _, _ = _import_pdf_classes()
        pages = None
        if args.pages:
            reader = PdfReader(args.input)
            pages = parse_pages(args.pages, len(reader.pages))
        watermark_pdf(args.input, args.watermark, args.output, pages)

    elif args.command == "crop":
        PdfReader, _, _ = _import_pdf_classes()
        pages = None
        if args.pages:
            reader = PdfReader(args.input)
            pages = parse_pages(args.pages, len(reader.pages))
        parts = [float(x) for x in args.box.split(",")]
        if len(parts) != 4:
            print("=== ERROR ===\n--box must be 4 comma-separated values: left,bottom,right,top")
            sys.exit(1)
        crop_pdf(args.input, args.output, tuple(parts), pages)


if __name__ == "__main__":
    main()
