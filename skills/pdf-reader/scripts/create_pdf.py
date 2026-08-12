#!/usr/bin/env python3
"""PDF creation toolkit: text, tables, blank pages using reportlab."""

from __future__ import annotations
import argparse
import csv
import json
import os
import sys


def _check_reportlab():
    try:
        import reportlab  # noqa: F401
        return True
    except ImportError:
        print("=== ERROR ===\nreportlab not installed.\nRun: pip3 install reportlab")
        sys.exit(1)


# ---------------------------------------------------------------------------
# Text PDF
# ---------------------------------------------------------------------------


def create_text_pdf(output: str, content: str | None = None, file_path: str | None = None,
                    title: str | None = None, font_size: int = 12, page_size: str = "A4"):
    """Create a PDF from text string or text file."""
    from reportlab.lib.pagesizes import A4, LETTER
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch

    sizes = {"A4": A4, "LETTER": LETTER}
    ps = sizes.get(page_size.upper(), A4)

    doc = SimpleDocTemplate(output, pagesize=ps)
    styles = getSampleStyleSheet()
    body_style = ParagraphStyle(
        "Body", parent=styles["Normal"], fontSize=font_size, leading=font_size * 1.4
    )

    story = []

    if title:
        title_style = ParagraphStyle(
            "Title", parent=styles["Heading1"], fontSize=font_size + 6, spaceAfter=0.3 * inch
        )
        story.append(Paragraph(title, title_style))
        story.append(Spacer(1, 0.2 * inch))

    text = content or ""
    if file_path:
        if not os.path.isfile(file_path):
            print(f"=== ERROR ===\nFile not found: {file_path}")
            sys.exit(1)
        with open(file_path, "r", encoding="utf-8") as f:
            text = f.read()

    # Split by lines and create paragraphs
    for line in text.split("\n"):
        if line.strip():
            # Escape XML special characters for reportlab
            safe = line.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            story.append(Paragraph(safe, body_style))
        else:
            story.append(Spacer(1, 0.15 * inch))

    if not story:
        story.append(Paragraph("(empty document)", body_style))

    doc.build(story)
    print(f"=== Text PDF Created ===\nOutput: {output}")


# ---------------------------------------------------------------------------
# Table PDF
# ---------------------------------------------------------------------------


def create_table_pdf(output: str, csv_path: str | None = None, json_path: str | None = None,
                     title: str | None = None, page_size: str = "A4"):
    """Create a PDF with styled table from CSV or JSON data."""
    from reportlab.lib.pagesizes import A4, LETTER
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.lib import colors
    from reportlab.lib.units import inch

    sizes = {"A4": A4, "LETTER": LETTER}
    ps = sizes.get(page_size.upper(), A4)

    data: list[list] = []

    if csv_path:
        if not os.path.isfile(csv_path):
            print(f"=== ERROR ===\nFile not found: {csv_path}")
            sys.exit(1)
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            data = [row for row in reader]

    elif json_path:
        if not os.path.isfile(json_path):
            print(f"=== ERROR ===\nFile not found: {json_path}")
            sys.exit(1)
        with open(json_path, "r", encoding="utf-8") as f:
            raw = json.load(f)
        if isinstance(raw, list) and len(raw) > 0:
            if isinstance(raw[0], dict):
                headers = list(raw[0].keys())
                data = [headers] + [[str(row.get(h, "")) for h in headers] for row in raw]
            elif isinstance(raw[0], list):
                data = [[str(cell) for cell in row] for row in raw]
            else:
                print("=== ERROR ===\nJSON must be a list of dicts or list of lists.")
                sys.exit(1)
        else:
            print("=== ERROR ===\nJSON must be a non-empty list.")
            sys.exit(1)
    else:
        print("=== ERROR ===\nProvide --csv or --json.")
        sys.exit(1)

    if not data:
        print("=== ERROR ===\nNo data to create table.")
        sys.exit(1)

    doc = SimpleDocTemplate(output, pagesize=ps)
    styles = getSampleStyleSheet()
    story = []

    if title:
        story.append(Paragraph(title, styles["Heading1"]))
        story.append(Spacer(1, 0.3 * inch))

    table = Table(data)
    style = TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#4472C4")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTSIZE", (0, 0), (-1, 0), 11),
        ("FONTSIZE", (0, 1), (-1, -1), 9),
        ("ALIGN", (0, 0), (-1, -1), "LEFT"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#D9E2F3")]),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ])
    table.setStyle(style)
    story.append(table)

    doc.build(story)
    print(f"=== Table PDF Created ===\nOutput: {output}\nRows: {len(data)}")


# ---------------------------------------------------------------------------
# Blank PDF
# ---------------------------------------------------------------------------


def create_blank_pdf(output: str, num_pages: int = 1, page_size: str = "A4"):
    """Create a blank PDF with specified number of pages."""
    from reportlab.lib.pagesizes import A4, LETTER
    from reportlab.pdfgen import canvas

    sizes = {"A4": A4, "LETTER": LETTER}
    ps = sizes.get(page_size.upper(), A4)

    c = canvas.Canvas(output, pagesize=ps)
    for _ in range(num_pages):
        c.showPage()
    c.save()
    print(f"=== Blank PDF Created ===\nOutput: {output}\nPages: {num_pages}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main():
    _check_reportlab()

    parser = argparse.ArgumentParser(description="PDF Creator — text, table, blank")
    sub = parser.add_subparsers(dest="command", required=True)

    # text
    p_text = sub.add_parser("text", help="Create PDF from text")
    p_text.add_argument("-o", "--output", required=True, help="Output PDF path")
    p_text.add_argument("--content", help="Text string content")
    p_text.add_argument("--file", help="Text file path")
    p_text.add_argument("--title", help="Document title")
    p_text.add_argument("--font-size", type=int, default=12)
    p_text.add_argument("--page-size", default="A4", choices=["A4", "LETTER"])

    # table
    p_table = sub.add_parser("table", help="Create PDF from CSV or JSON")
    p_table.add_argument("-o", "--output", required=True, help="Output PDF path")
    p_table.add_argument("--csv", dest="csv_path", help="CSV file")
    p_table.add_argument("--json", dest="json_path", help="JSON file")
    p_table.add_argument("--title", help="Document title")
    p_table.add_argument("--page-size", default="A4", choices=["A4", "LETTER"])

    # blank
    p_blank = sub.add_parser("blank", help="Create blank PDF")
    p_blank.add_argument("-o", "--output", required=True, help="Output PDF path")
    p_blank.add_argument("--pages", type=int, default=1, help="Number of blank pages")
    p_blank.add_argument("--page-size", default="A4", choices=["A4", "LETTER"])

    args = parser.parse_args()

    if args.command == "text":
        create_text_pdf(args.output, content=args.content, file_path=args.file,
                        title=args.title, font_size=args.font_size, page_size=args.page_size)
    elif args.command == "table":
        create_table_pdf(args.output, csv_path=args.csv_path, json_path=args.json_path,
                         title=args.title, page_size=args.page_size)
    elif args.command == "blank":
        create_blank_pdf(args.output, num_pages=args.pages, page_size=args.page_size)


if __name__ == "__main__":
    main()
