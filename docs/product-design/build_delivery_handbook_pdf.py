#!/usr/bin/env python3
"""Render the dated delivery status/spec/manual without changing the V1.1 PDF."""
from __future__ import annotations

import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, Frame, KeepTogether, PageBreak, PageTemplate, Paragraph, Spacer,
)

from build_product_design_pdf import (
    CONTENT_W, INK, LINE, MARGIN, MUTED, PAGE_H, PAGE_W,
    inline, make_table, styles,
)

BASE = Path(__file__).resolve().parent
SOURCES = [BASE / f"{name}-2026-10-31.md" for name in (
    "squadly-feature-status", "squadly-product-spec", "squadly-operation-testing-manual",
)]
OUTPUT = BASE / "squadly-delivery-handbook-2026-10-31.pdf"


class Handbook(BaseDocTemplate):
    def __init__(self, output: Path):
        super().__init__(
            str(output), pagesize=(PAGE_W, PAGE_H), title="Squadly 功能状态、产品规格与操作测试手册",
            author="Squadly", subject="2026-10-31 实现快照与交互验收", pageCompression=1,
            leftMargin=MARGIN, rightMargin=MARGIN, topMargin=57, bottomMargin=47,
        )
        self.section_number = 0
        self.addPageTemplates(PageTemplate(
            id="handbook", frames=[Frame(MARGIN, 47, CONTENT_W, PAGE_H - 104,
                leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)],
            onPage=self.decorate,
        ))

    def decorate(self, canvas, doc):
        canvas.saveState()
        canvas.setFont("CJK", 7.5)
        canvas.setFillColor(MUTED)
        canvas.drawString(MARGIN, PAGE_H - 30, "SQUADLY / 交付与交互手册")
        canvas.drawRightString(PAGE_W - MARGIN, PAGE_H - 30, "2026-10-31 / iOS staging")
        canvas.setStrokeColor(LINE)
        canvas.line(MARGIN, PAGE_H - 39, PAGE_W - MARGIN, PAGE_H - 39)
        canvas.line(MARGIN, 34, PAGE_W - MARGIN, 34)
        canvas.drawString(MARGIN, 22, "实现状态与目标规格分开记录；未验收不计通过")
        canvas.drawRightString(PAGE_W - MARGIN, 22, f"{doc.page:02d}")
        canvas.restoreState()

    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph) and flowable.style.name == "Title":
            key = f"section-{self.section_number}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(flowable.getPlainText(), key, 0, False)
            self.section_number += 1


def render_markdown(source: Path, sheet):
    lines = source.read_text().splitlines()
    story = []
    index = 0
    while index < len(lines):
        line = lines[index].strip()
        index += 1
        if not line:
            continue
        if line.startswith("```"):
            code = []
            while index < len(lines) and not lines[index].strip().startswith("```"):
                code.append(lines[index])
                index += 1
            index += 1
            story.append(Paragraph("<br/>".join(html.escape(value) or " " for value in code), sheet["code"]))
            continue
        if line.startswith("|"):
            table_lines = [line]
            while index < len(lines) and lines[index].strip().startswith("|"):
                table_lines.append(lines[index].strip())
                index += 1
            rows = [[cell.strip() for cell in row.strip("|").split("|")]
                for row in table_lines if not re.fullmatch(r"[|\s:\-]+", row)]
            if len({len(row) for row in rows}) != 1:
                raise ValueError(f"Inconsistent table in {source.name}")
            table = make_table(rows, source, sheet)
            story.extend([KeepTogether([table]) if any("![" in cell for row in rows for cell in row) else table, Spacer(1, 11)])
            continue
        if line.startswith("# "):
            story.append(Paragraph(inline(line[2:]), sheet["title"]))
        elif line.startswith("## "):
            if line.startswith("## 10. 已取得的桌面截图"):
                story.append(PageBreak())
            story.append(Paragraph(inline(line[3:]), sheet["sub"]))
        elif line.startswith("- ") or re.match(r"^\d+\. ", line):
            text = "• " + line[2:] if line.startswith("- ") else line
            story.append(Paragraph(inline(text), sheet["bullet"]))
        else:
            paragraph = [line]
            while index < len(lines) and lines[index].strip() and not re.match(r"^(#|\||-|```|\d+\. )", lines[index]):
                paragraph.append(lines[index].strip())
                index += 1
            story.append(Paragraph(inline(" ".join(paragraph)), sheet["body"]))
    return story


def main():
    pdfmetrics.registerFont(TTFont("CJK", "/System/Library/Fonts/STHeiti Light.ttc", subfontIndex=0))
    pdfmetrics.registerFont(TTFont("CJKB", "/System/Library/Fonts/STHeiti Medium.ttc", subfontIndex=0))
    pdfmetrics.registerFontFamily("CJK", normal="CJK", bold="CJKB", italic="CJK", boldItalic="CJKB")
    sheet = styles()
    sheet["code"] = ParagraphStyle("Code", fontName="CJK", fontSize=8.1, leading=12.8,
        textColor=INK, wordWrap="CJK", backColor=colors.HexColor("#F2F4F7"), borderPadding=7,
        leftIndent=7, rightIndent=7, spaceBefore=4, spaceAfter=13)
    story = []
    for index, source in enumerate(SOURCES):
        if index:
            story.append(PageBreak())
        story.extend(render_markdown(source, sheet))
    Handbook(OUTPUT).build(story)
    print(f"Built {OUTPUT.name} from {len(SOURCES)} Markdown documents.")


if __name__ == "__main__":
    main()
