#!/usr/bin/env python3
"""Build the paginated product design PDF from its editable Markdown source.

Requires reportlab and Pillow. Run with the Codex bundled Python runtime or a
Python environment containing those libraries. Images remain external sources;
the builder embeds unchanged artwork at its original aspect ratio.
"""

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

from PIL import Image as PILImage
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    Flowable,
    Frame,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

BASE = Path(__file__).resolve().parent
DEFAULT_STEM = "squadly-product-design-v1.1-2026-10-27"
INK = colors.HexColor("#1F2329")
MUTED = colors.HexColor("#667085")
ORANGE = colors.HexColor("#C2411A")
BRAND = colors.HexColor("#FC6634")
TINT = colors.HexColor("#FFF1EB")
LINE = colors.HexColor("#E5E7EB")
PAGE_W, PAGE_H = A4
MARGIN = 43
CONTENT_W = PAGE_W - 2 * MARGIN


def inline(text: str) -> str:
    result = html.escape(text)
    result = re.sub(r"`([^`]+)`", r'<font color="#344054">\1</font>', result)
    result = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", result)
    result = re.sub(
        r"\[([^\]]+)\]\((https?://[^)]+)\)",
        r'<link href="\2" color="#C2411A"><u>\1</u></link>',
        result,
    )
    result = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1", result)
    return result


class Artwork(Flowable):
    def __init__(self, path: Path, width: float, height_limit: float = 440):
        super().__init__()
        self.path = path
        with PILImage.open(path) as im:
            self.image = im.convert("RGB")
            iw, ih = im.size
        factor = min(width / iw, height_limit / ih)
        self.width, self.height = iw * factor, ih * factor
        self.box_width = width

    def draw(self):
        self.canv.drawImage(
            ImageReader(self.image),
            (self.box_width - self.width) / 2,
            0,
            width=self.width,
            height=self.height,
        )

    def wrap(self, availWidth, availHeight):
        return self.box_width, self.height


class DesignDoc(BaseDocTemplate):
    def __init__(self, output: Path, expected_pages: int):
        super().__init__(
            str(output),
            pagesize=A4,
            leftMargin=MARGIN,
            rightMargin=MARGIN,
            topMargin=57,
            bottomMargin=47,
            title="Squadly 小分队 - 产品设计 V1.1",
            author="Squadly",
            subject="照片三环、竞品 UI 参考与开发测试交付",
            pageCompression=1,
        )
        self.expected_pages = expected_pages
        self.addPageTemplates(
            PageTemplate(
                id="normal",
                frames=[
                    Frame(
                        MARGIN,
                        47,
                        CONTENT_W,
                        PAGE_H - 104,
                        leftPadding=0,
                        rightPadding=0,
                        topPadding=0,
                        bottomPadding=0,
                    )
                ],
                onPage=self.decorate,
            )
        )
        self.outline_count = 0

    def decorate(self, canvas, doc):
        canvas.saveState()
        if doc.page > 1:
            canvas.setFont("CJK", 7.5)
            canvas.setFillColor(MUTED)
            canvas.drawString(MARGIN, PAGE_H - 30, "SQUADLY / PRODUCT DESIGN")
            canvas.drawRightString(PAGE_W - MARGIN, PAGE_H - 30, "V1.1 · 2026-10-27")
            canvas.setStrokeColor(LINE)
            canvas.line(MARGIN, PAGE_H - 39, PAGE_W - MARGIN, PAGE_H - 39)
        canvas.setStrokeColor(LINE)
        canvas.line(MARGIN, 34, PAGE_W - MARGIN, 34)
        canvas.setFillColor(MUTED)
        canvas.setFont("CJK", 7.2)
        canvas.drawString(MARGIN, 22, "小分队 / 照片三环 / 产品、设计与交付")
        canvas.drawRightString(
            PAGE_W - MARGIN, 22, f"{doc.page:02d} / {self.expected_pages:02d}"
        )
        canvas.restoreState()

    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph) and flowable.style.name in ("Title", "Cover"):
            key = f"section-{self.outline_count}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(flowable.getPlainText(), key, 0, False)
            self.outline_count += 1


def styles():
    base = dict(fontName="CJK", textColor=INK, wordWrap="CJK", allowWidows=0, allowOrphans=0)
    return {
        "body": ParagraphStyle("Body", fontSize=10.2, leading=16.5, spaceAfter=9, **base),
        "title": ParagraphStyle(
            "Title", fontSize=22, leading=30, spaceAfter=15, fontName="CJKB",
            textColor=INK, wordWrap="CJK", keepWithNext=True,
        ),
        "cover": ParagraphStyle(
            "Cover", fontSize=36, leading=46, spaceBefore=24, spaceAfter=12,
            fontName="CJKB", textColor=INK, wordWrap="CJK", keepWithNext=True,
        ),
        "sub": ParagraphStyle(
            "Sub", fontSize=13, leading=20, spaceBefore=11, spaceAfter=8,
            fontName="CJKB", textColor=ORANGE, wordWrap="CJK", keepWithNext=True,
        ),
        "cell": ParagraphStyle("Cell", fontSize=9.0, leading=14, **base),
        "head": ParagraphStyle(
            "Head", fontSize=9.0, leading=14, fontName="CJKB", textColor=colors.white,
            wordWrap="CJK",
        ),
        "caption": ParagraphStyle(
            "Caption", fontSize=8.8, leading=14, alignment=TA_CENTER, **base,
        ),
        "bullet": ParagraphStyle(
            "Bullet", fontSize=10.2, leading=16.5, leftIndent=11, firstLineIndent=-10,
            spaceAfter=7, **base,
        ),
        "source": ParagraphStyle(
            "Source", fontSize=8.6, leading=13.3, spaceAfter=5, **base,
        ),
    }


def make_table(rows, source: Path, s, source_page=False):
    cols = len(rows[0])
    image_rows = [r for r in rows[1:] if any("![" in c for c in r)]
    if image_rows:
        widths = [(CONTENT_W - 16) / 2] * 2
        images = []
        for cell in image_rows[0]:
            match = re.search(r"!\[([^\]]*)\]\(([^)]+)\)", cell)
            if not match:
                raise ValueError("Expected a paired image table")
            images.append(Artwork((source.parent / match.group(2)).resolve(), widths[0] - 12))
        table = Table(
            [[Paragraph(inline(c), s["caption"]) for c in rows[0]], images],
            colWidths=widths,
            hAlign="CENTER",
        )
        table.setStyle(TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ]))
        return table

    ratios = {
        2: [0.27, 0.73],
        3: [0.21, 0.41, 0.38],
        4: [0.18, 0.26, 0.31, 0.25],
    }.get(cols, [1 / cols] * cols)
    if rows[0][0] == "ID":
        ratios = [0.09, 0.49, 0.42] if cols == 3 else [0.09] + [0.91 / (cols - 1)] * (cols - 1)
    wrapped = [[Paragraph(inline(c), s["head"] if i == 0 else s["cell"]) for c in r] for i, r in enumerate(rows)]
    table = Table(wrapped, colWidths=[CONTENT_W * x for x in ratios], repeatRows=1, hAlign="LEFT")
    commands = [
        ("BACKGROUND", (0, 0), (-1, 0), INK),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 9),
        ("RIGHTPADDING", (0, 0), (-1, -1), 9),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ("LINEBELOW", (0, 0), (-1, 0), 0.5, INK),
    ]
    for row in range(1, len(rows)):
        commands.append(("BACKGROUND", (0, row), (-1, row), colors.HexColor("#F7F8FA") if row % 2 else colors.white))
        commands.append(("LINEBELOW", (0, row), (-1, row), 0.4, LINE))
    table.setStyle(TableStyle(commands))
    return table


def parse(source: Path, s):
    sections = re.split(r"\n<!-- page -->\s*\n", source.read_text())
    story = []
    for page_index, section in enumerate(sections):
        if page_index:
            story.append(PageBreak())
        else:
            story.append(Paragraph("PRODUCT DESIGN / 2026-10-27", s["sub"]))
        lines = section.strip().splitlines()
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith("<!--"):
                i += 1
                continue
            if line.startswith("# "):
                story.append(Paragraph(inline(line[2:]), s["cover"] if page_index == 0 else s["title"]))
                i += 1
                continue
            if line.startswith("## "):
                story.append(Paragraph(inline(line[3:]), s["sub"]))
                i += 1
                continue
            if line.startswith("|"):
                table_lines = []
                while i < len(lines) and lines[i].strip().startswith("|"):
                    current = lines[i].strip()
                    if not re.fullmatch(r"[|\s:\-]+", current):
                        table_lines.append([c.strip() for c in current.strip("|").split("|")])
                    i += 1
                story.extend([make_table(table_lines, source, s), Spacer(1, 11)])
                continue
            if line.startswith("- "):
                style = s["source"] if page_index == len(sections) - 1 else s["bullet"]
                story.append(Paragraph("• " + inline(line[2:]), style))
                i += 1
                continue
            paragraph = [line]
            i += 1
            while i < len(lines) and lines[i].strip() and not lines[i].startswith(("#", "|", "- ", "<!--")):
                paragraph.append(lines[i].strip())
                i += 1
            style = s["source"] if page_index == len(sections) - 1 else s["body"]
            story.append(Paragraph(inline(" ".join(paragraph)), style))
    return story, len(sections)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=BASE / f"{DEFAULT_STEM}.md")
    parser.add_argument("--output", type=Path, default=BASE / f"{DEFAULT_STEM}.pdf")
    parser.add_argument("--regular-font", default="/System/Library/Fonts/STHeiti Light.ttc")
    parser.add_argument("--bold-font", default="/System/Library/Fonts/STHeiti Medium.ttc")
    args = parser.parse_args()
    pdfmetrics.registerFont(TTFont("CJK", args.regular_font, subfontIndex=0))
    pdfmetrics.registerFont(TTFont("CJKB", args.bold_font, subfontIndex=0))
    pdfmetrics.registerFontFamily("CJK", normal="CJK", bold="CJKB", italic="CJK", boldItalic="CJKB")
    story, expected = parse(args.source.resolve(), styles())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    doc = DesignDoc(args.output, expected)
    doc.build(story)
    if doc.page != expected:
        raise RuntimeError(f"Pagination overflow: expected {expected}, got {doc.page}. Revise source or spacing.")
    print(f"Built {args.output.resolve()} ({doc.page} pages)")


if __name__ == "__main__":
    main()
