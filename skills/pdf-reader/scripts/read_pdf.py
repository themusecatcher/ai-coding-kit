#!/usr/bin/env python3
"""PDF reading toolkit: text extraction, tables, metadata, pdf-to-images, OCR, embedded images."""

from __future__ import annotations
import argparse
import json
import os
import sys

# ---------------------------------------------------------------------------
# Engine discovery
# ---------------------------------------------------------------------------

_ENGINES: dict = {}


def _discover_engines():
    """Detect available PDF engines at import time."""
    global _ENGINES
    try:
        import fitz  # noqa: F401
        _ENGINES["fitz"] = True
    except ImportError:
        _ENGINES["fitz"] = False

    try:
        import pdfplumber  # noqa: F401
        _ENGINES["pdfplumber"] = True
    except ImportError:
        _ENGINES["pdfplumber"] = False

    try:
        import pypdf  # noqa: F401
        _ENGINES["pypdf"] = True
    except ImportError:
        _ENGINES["pypdf"] = False

    try:
        import PyPDF2  # noqa: F401
        _ENGINES["PyPDF2"] = True
    except ImportError:
        _ENGINES["PyPDF2"] = False

    import shutil
    _ENGINES["pdftotext"] = shutil.which("pdftotext") is not None
    _ENGINES["pdfimages"] = shutil.which("pdfimages") is not None

    # Extra capabilities
    try:
        import pypdfium2  # noqa: F401
        _ENGINES["pypdfium2"] = True
    except ImportError:
        _ENGINES["pypdfium2"] = False

    try:
        import pdf2image  # noqa: F401
        _ENGINES["pdf2image"] = True
    except ImportError:
        _ENGINES["pdf2image"] = False

    try:
        import pytesseract  # noqa: F401
        _ENGINES["pytesseract"] = True
    except ImportError:
        _ENGINES["pytesseract"] = False

    try:
        import reportlab  # noqa: F401
        _ENGINES["reportlab"] = True
    except ImportError:
        _ENGINES["reportlab"] = False


_discover_engines()

# ---------------------------------------------------------------------------
# Page range parser
# ---------------------------------------------------------------------------


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
# Text extraction
# ---------------------------------------------------------------------------


def extract_text_fitz(path: str, pages: list[int] | None = None) -> str:
    import fitz
    doc = fitz.open(path)
    target = pages if pages else range(len(doc))
    parts: list[str] = []
    for i in target:
        page = doc[i]
        parts.append(f"=== Page {i + 1} ===")
        parts.append(page.get_text())
    doc.close()
    return "\n".join(parts)


def extract_text_pdfplumber(path: str, pages: list[int] | None = None) -> str:
    import pdfplumber
    parts: list[str] = []
    with pdfplumber.open(path) as pdf:
        target = pages if pages else range(len(pdf.pages))
        for i in target:
            page = pdf.pages[i]
            parts.append(f"=== Page {i + 1} ===")
            text = page.extract_text() or ""
            parts.append(text)
    return "\n".join(parts)


def extract_text_pypdf(path: str, pages: list[int] | None = None) -> str:
    try:
        from pypdf import PdfReader
    except ImportError:
        from PyPDF2 import PdfReader  # type: ignore[no-redef]
    reader = PdfReader(path)
    target = pages if pages else range(len(reader.pages))
    parts: list[str] = []
    for i in target:
        parts.append(f"=== Page {i + 1} ===")
        parts.append(reader.pages[i].extract_text() or "")
    return "\n".join(parts)


def extract_text_pdftotext(path: str, pages: list[int] | None = None) -> str:
    import subprocess
    parts: list[str] = []
    if pages:
        for i in pages:
            result = subprocess.run(
                ["pdftotext", "-f", str(i + 1), "-l", str(i + 1), path, "-"],
                capture_output=True, text=True,
            )
            parts.append(f"=== Page {i + 1} ===")
            parts.append(result.stdout)
    else:
        result = subprocess.run(
            ["pdftotext", path, "-"], capture_output=True, text=True,
        )
        parts.append(result.stdout)
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Table extraction
# ---------------------------------------------------------------------------


def extract_tables(path: str, pages: list[int] | None = None) -> str:
    if not _ENGINES.get("pdfplumber"):
        return "=== ERROR ===\npdfplumber not installed. Run: pip3 install pdfplumber"
    import pdfplumber
    parts: list[str] = []
    with pdfplumber.open(path) as pdf:
        target = pages if pages else range(len(pdf.pages))
        for i in target:
            page = pdf.pages[i]
            tables = page.extract_tables()
            if tables:
                parts.append(f"=== Page {i + 1} Tables ===")
                for ti, table in enumerate(tables):
                    parts.append(f"--- Table {ti + 1} ---")
                    parts.append(json.dumps(table, ensure_ascii=False, indent=2))
    if not parts:
        return "=== INFO ===\nNo tables found."
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Metadata
# ---------------------------------------------------------------------------


def extract_metadata(path: str) -> str:
    if _ENGINES.get("fitz"):
        import fitz
        doc = fitz.open(path)
        meta = doc.metadata
        meta["page_count"] = len(doc)
        doc.close()
        return "=== Metadata ===\n" + json.dumps(meta, ensure_ascii=False, indent=2)

    try:
        from pypdf import PdfReader
    except ImportError:
        from PyPDF2 import PdfReader  # type: ignore[no-redef]
    reader = PdfReader(path)
    info = reader.metadata
    meta = {}
    if info:
        for key in info:
            meta[key] = str(info[key])
    meta["page_count"] = len(reader.pages)
    return "=== Metadata ===\n" + json.dumps(meta, ensure_ascii=False, indent=2)


# ---------------------------------------------------------------------------
# PDF to images
# ---------------------------------------------------------------------------


def pdf_to_images(path: str, output_dir: str, pages: list[int] | None = None, dpi: int = 200) -> str:
    """Convert PDF pages to PNG images."""
    os.makedirs(output_dir, exist_ok=True)
    saved: list[str] = []

    # Engine 1: pypdfium2
    if _ENGINES.get("pypdfium2"):
        import pypdfium2 as pdfium
        doc = pdfium.PdfDocument(path)
        target = pages if pages else range(len(doc))
        for i in target:
            page = doc[i]
            bitmap = page.render(scale=dpi / 72)
            img = bitmap.to_pil()
            out = os.path.join(output_dir, f"page_{i + 1}.png")
            img.save(out)
            saved.append(out)
        doc.close()
        return "=== PDF to Images (pypdfium2) ===\n" + "\n".join(saved)

    # Engine 2: pdf2image (poppler)
    if _ENGINES.get("pdf2image"):
        from pdf2image import convert_from_path
        kwargs = {"dpi": dpi}
        if pages:
            kwargs["first_page"] = min(pages) + 1
            kwargs["last_page"] = max(pages) + 1
        images = convert_from_path(path, **kwargs)
        target_set = set(pages) if pages else None
        for idx, img in enumerate(images):
            page_num = (min(pages) + idx) if pages else idx
            if target_set and page_num not in target_set:
                continue
            out = os.path.join(output_dir, f"page_{page_num + 1}.png")
            img.save(out)
            saved.append(out)
        return "=== PDF to Images (pdf2image) ===\n" + "\n".join(saved)

    # Engine 3: fitz (PyMuPDF)
    if _ENGINES.get("fitz"):
        import fitz
        doc = fitz.open(path)
        target = pages if pages else range(len(doc))
        mat = fitz.Matrix(dpi / 72, dpi / 72)
        for i in target:
            pix = doc[i].get_pixmap(matrix=mat)
            out = os.path.join(output_dir, f"page_{i + 1}.png")
            pix.save(out)
            saved.append(out)
        doc.close()
        return "=== PDF to Images (fitz) ===\n" + "\n".join(saved)

    return "=== ERROR ===\nNo PDF-to-image engine available.\nInstall one of: pypdfium2, pdf2image (+ poppler), PyMuPDF"


# ---------------------------------------------------------------------------
# OCR
# ---------------------------------------------------------------------------


def _pdf_pages_to_pil(path: str, pages: list[int] | None = None, dpi: int = 300):
    """Convert PDF pages to PIL Images for OCR."""
    if _ENGINES.get("fitz"):
        import fitz
        from PIL import Image
        import io
        doc = fitz.open(path)
        target = pages if pages else range(len(doc))
        result = []
        mat = fitz.Matrix(dpi / 72, dpi / 72)
        for i in target:
            pix = doc[i].get_pixmap(matrix=mat)
            img = Image.open(io.BytesIO(pix.tobytes("png")))
            result.append((i, img))
        doc.close()
        return result

    if _ENGINES.get("pdf2image"):
        from pdf2image import convert_from_path
        images = convert_from_path(path, dpi=dpi)
        target = pages if pages else range(len(images))
        return [(i, images[i]) for i in target]

    return None


def ocr_pdf(path: str, pages: list[int] | None = None, lang: str = "eng", dpi: int = 300) -> str:
    """OCR a scanned PDF."""
    if not _ENGINES.get("pytesseract"):
        return "=== ERROR ===\npytesseract not installed.\nRun: pip3 install pytesseract && brew install tesseract"

    import pytesseract
    pil_pages = _pdf_pages_to_pil(path, pages, dpi)
    if pil_pages is None:
        return "=== ERROR ===\nNo image engine available for OCR.\nInstall PyMuPDF or pdf2image."

    parts: list[str] = []
    for idx, img in pil_pages:
        parts.append(f"=== Page {idx + 1} (OCR) ===")
        text = pytesseract.image_to_string(img, lang=lang)
        parts.append(text.strip())

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Extract embedded images
# ---------------------------------------------------------------------------


def extract_images(path: str, output_dir: str, pages: list[int] | None = None) -> str:
    """Extract embedded images from PDF."""
    os.makedirs(output_dir, exist_ok=True)
    saved: list[str] = []

    # Engine 1: fitz
    if _ENGINES.get("fitz"):
        import fitz
        doc = fitz.open(path)
        target = pages if pages else range(len(doc))
        img_idx = 0
        for i in target:
            page = doc[i]
            image_list = page.get_images(full=True)
            for img_info in image_list:
                xref = img_info[0]
                base_image = doc.extract_image(xref)
                if base_image:
                    ext = base_image.get("ext", "png")
                    img_bytes = base_image["image"]
                    out = os.path.join(output_dir, f"img_p{i + 1}_{img_idx}.{ext}")
                    with open(out, "wb") as f:
                        f.write(img_bytes)
                    saved.append(out)
                    img_idx += 1
        doc.close()
        if not saved:
            return "=== INFO ===\nNo embedded images found."
        return "=== Extracted Images (fitz) ===\n" + "\n".join(saved)

    # Engine 2: pdfimages CLI
    if _ENGINES.get("pdfimages"):
        import subprocess
        prefix = os.path.join(output_dir, "img")
        cmd = ["pdfimages", "-png", path, prefix]
        subprocess.run(cmd, capture_output=True)
        for f_name in sorted(os.listdir(output_dir)):
            if f_name.startswith("img"):
                saved.append(os.path.join(output_dir, f_name))
        if not saved:
            return "=== INFO ===\nNo embedded images found."
        return "=== Extracted Images (pdfimages) ===\n" + "\n".join(saved)

    return "=== ERROR ===\nNo image extraction engine.\nInstall PyMuPDF or poppler (pdfimages)."


# ---------------------------------------------------------------------------
# Environment check
# ---------------------------------------------------------------------------


def check_environment() -> str:
    lines = ["=== PDF Environment Check ===", ""]

    # Text engines
    lines.append("Text extraction engines:")
    order = [
        ("fitz", "PyMuPDF", "pip3 install PyMuPDF"),
        ("pdfplumber", "pdfplumber", "pip3 install pdfplumber"),
        ("pypdf", "pypdf", "pip3 install pypdf"),
        ("PyPDF2", "PyPDF2", "pip3 install PyPDF2"),
        ("pdftotext", "pdftotext (poppler)", "brew install poppler"),
    ]
    available = []
    for key, name, install in order:
        status = "OK" if _ENGINES.get(key) else "MISSING"
        marker = "  [+]" if _ENGINES.get(key) else "  [-]"
        lines.append(f"{marker} {name} — {status} ({install})")
        if _ENGINES.get(key):
            available.append(name)

    lines.append("")
    lines.append("Extra capabilities:")
    extras = [
        ("pypdfium2", "pypdfium2 (PDF to images)", "pip3 install pypdfium2"),
        ("pdf2image", "pdf2image (PDF to images)", "pip3 install pdf2image"),
        ("pytesseract", "pytesseract (OCR)", "pip3 install pytesseract && brew install tesseract"),
        ("reportlab", "reportlab (create PDF)", "pip3 install reportlab"),
        ("pdfimages", "pdfimages (extract images)", "brew install poppler"),
    ]
    for key, name, install in extras:
        status = "OK" if _ENGINES.get(key) else "MISSING"
        marker = "  [+]" if _ENGINES.get(key) else "  [-]"
        lines.append(f"{marker} {name} — {status} ({install})")

    lines.append("")
    if available:
        lines.append(f"Primary engine: {available[0]}")
    else:
        lines.append("WARNING: No PDF engine found! Install at least one: pip3 install PyMuPDF")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------


def extract_text(path: str, pages: list[int] | None = None, engine: str | None = None) -> str:
    """Choose best available engine and extract text."""
    if engine:
        dispatch = {
            "fitz": extract_text_fitz,
            "pdfplumber": extract_text_pdfplumber,
            "pypdf": extract_text_pypdf,
            "PyPDF2": extract_text_pypdf,
            "pdftotext": extract_text_pdftotext,
        }
        fn = dispatch.get(engine)
        if fn:
            return fn(path, pages)
        return f"=== ERROR ===\nUnknown engine: {engine}"

    # Auto-select
    if _ENGINES.get("fitz"):
        return extract_text_fitz(path, pages)
    if _ENGINES.get("pdfplumber"):
        return extract_text_pdfplumber(path, pages)
    if _ENGINES.get("pypdf"):
        return extract_text_pypdf(path, pages)
    if _ENGINES.get("PyPDF2"):
        return extract_text_pypdf(path, pages)
    if _ENGINES.get("pdftotext"):
        return extract_text_pdftotext(path, pages)

    return "=== ERROR ===\nNo PDF engine found.\nInstall: pip3 install PyMuPDF"


def _get_page_count(path: str) -> int:
    if _ENGINES.get("fitz"):
        import fitz
        doc = fitz.open(path)
        n = len(doc)
        doc.close()
        return n
    try:
        from pypdf import PdfReader
    except ImportError:
        from PyPDF2 import PdfReader  # type: ignore[no-redef]
    return len(PdfReader(path).pages)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="PDF Reader — text, tables, metadata, images, OCR")
    parser.add_argument("pdf", nargs="?", help="Path to PDF file")
    parser.add_argument("--pages", help="Page range, e.g. '1-3,5,8-10'")
    parser.add_argument("--tables", action="store_true", help="Extract tables (needs pdfplumber)")
    parser.add_argument("--metadata", action="store_true", help="Show metadata")
    parser.add_argument("--engine", help="Force engine: fitz, pdfplumber, pypdf, PyPDF2, pdftotext")
    parser.add_argument("--check", action="store_true", help="Check environment")
    parser.add_argument("--to-images", metavar="DIR", help="Convert pages to PNG in DIR")
    parser.add_argument("--images", metavar="DIR", help="Extract embedded images to DIR")
    parser.add_argument("--ocr", action="store_true", help="OCR scanned PDF")
    parser.add_argument("--ocr-lang", default="eng", help="Tesseract language code (default: eng)")
    parser.add_argument("--dpi", type=int, default=200, help="DPI for image conversion (default: 200)")

    args = parser.parse_args()

    if args.check:
        print(check_environment())
        return

    if not args.pdf:
        parser.print_help()
        sys.exit(1)

    if not os.path.isfile(args.pdf):
        print(f"=== ERROR ===\nFile not found: {args.pdf}")
        sys.exit(1)

    pages = None
    if args.pages:
        total = _get_page_count(args.pdf)
        pages = parse_pages(args.pages, total)

    if args.metadata:
        print(extract_metadata(args.pdf))
    elif args.tables:
        print(extract_tables(args.pdf, pages))
    elif args.to_images:
        print(pdf_to_images(args.pdf, args.to_images, pages, args.dpi))
    elif args.images:
        print(extract_images(args.pdf, args.images, pages))
    elif args.ocr:
        print(ocr_pdf(args.pdf, pages, args.ocr_lang, args.dpi))
    else:
        print(extract_text(args.pdf, pages, args.engine))


if __name__ == "__main__":
    main()
