#!/usr/bin/env python3
"""
PDF 调研报告生成器（通过 HTML 中间格式）
用法：python3 gen_pdf.py --input content.json --output report.pdf

依赖 weasyprint（可选），未安装时降级为生成 HTML。
"""

import argparse
import json
import sys
import os
from datetime import datetime

def markdown_to_html(text: str) -> str:
    """简单的 Markdown → HTML 转换"""
    try:
        import markdown
        return markdown.markdown(text, extensions=["tables", "fenced_code"])
    except ImportError:
        # 简易 fallback
        html = text.replace("\n\n", "</p><p>").replace("\n", "<br>")
        return f"<p>{html}</p>"


def create_html(data: dict) -> str:
    """生成 HTML 报告"""
    title = data.get("title", "调研报告")
    subtitle = data.get("subtitle", "")
    author = data.get("author", "")
    date = data.get("date", datetime.now().strftime("%Y-%m-%d"))
    sections = data.get("sections", [])

    sections_html = []
    for i, sec in enumerate(sections):
        sec_title = sec.get("title", f"章节 {i + 1}")
        sec_type = sec.get("type", "text")
        content = sec.get("content", "")

        if sec_type == "table" and sec.get("data"):
            table_data = sec["data"]
            headers = table_data.get("headers", [])
            rows = table_data.get("rows", [])

            th = "".join(f"<th>{h}</th>" for h in headers)
            tr_list = []
            for row in rows:
                td = "".join(f"<td>{v}</td>" for v in row)
                tr_list.append(f"<tr>{td}</tr>")
            trs = "\n".join(tr_list)

            body = f"""<table>
<thead><tr>{th}</tr></thead>
<tbody>{trs}</tbody>
</table>"""
            if content:
                body += f"<p>{content}</p>"
        else:
            body = markdown_to_html(content)

        sections_html.append(f"""
<div class="section">
    <h2><span class="num">{i + 1:02d}</span> {sec_title}</h2>
    {body}
</div>""")

    meta_parts = []
    if author:
        meta_parts.append(author)
    meta_parts.append(date)
    meta_str = " | ".join(meta_parts)

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>{title}</title>
<style>
@page {{
    size: A4;
    margin: 2cm;
    @bottom-center {{
        content: counter(page) " / " counter(pages);
        font-size: 9pt;
        color: #999;
    }}
}}
body {{
    font-family: "Helvetica Neue", Arial, "PingFang SC", "Microsoft YaHei", sans-serif;
    font-size: 11pt;
    line-height: 1.6;
    color: #333;
    max-width: 800px;
    margin: 0 auto;
}}
.cover {{
    text-align: center;
    padding: 100px 0 60px;
    page-break-after: always;
}}
.cover h1 {{
    font-size: 28pt;
    color: #1A73E8;
    margin-bottom: 12px;
}}
.cover .subtitle {{
    font-size: 14pt;
    color: #666;
    margin-bottom: 30px;
}}
.cover .meta {{
    font-size: 11pt;
    color: #999;
}}
h2 {{
    color: #1A73E8;
    border-bottom: 2px solid #1A73E8;
    padding-bottom: 6px;
    margin-top: 30px;
}}
h2 .num {{
    color: #00C4B4;
    font-size: 0.8em;
    margin-right: 8px;
}}
table {{
    width: 100%;
    border-collapse: collapse;
    margin: 16px 0;
    font-size: 10pt;
}}
th {{
    background: #1A73E8;
    color: #fff;
    padding: 8px 12px;
    text-align: left;
}}
td {{
    padding: 8px 12px;
    border-bottom: 1px solid #e0e0e0;
}}
tr:nth-child(even) td {{
    background: #f7f8fa;
}}
.section {{
    page-break-inside: avoid;
}}
code {{
    background: #f5f5f5;
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 0.9em;
}}
pre {{
    background: #f5f5f5;
    padding: 16px;
    border-radius: 6px;
    overflow-x: auto;
}}
</style>
</head>
<body>

<div class="cover">
    <h1>{title}</h1>
    {"<p class='subtitle'>" + subtitle + "</p>" if subtitle else ""}
    <p class="meta">{meta_str}</p>
</div>

{"".join(sections_html)}

</body>
</html>"""


def main():
    parser = argparse.ArgumentParser(description="PDF 调研报告生成器")
    parser.add_argument("--input", required=True, help="内容 JSON 文件路径")
    parser.add_argument("--output", required=True, help="输出 PDF 文件路径")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)

    output_dir = os.path.dirname(args.output)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    html_content = create_html(data)

    # 尝试使用 weasyprint 生成 PDF
    try:
        from weasyprint import HTML
        HTML(string=html_content).write_pdf(args.output)
        print(f"✅ PDF 已生成：{args.output}")
    except ImportError:
        # 降级：保存为 HTML
        html_path = args.output.replace(".pdf", ".html")
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(html_content)
        print(f"⚠️  weasyprint 未安装，已降级生成 HTML：{html_path}")
        print(f"   安装 weasyprint 后可生成 PDF：pip3 install --user weasyprint")
        print(f"   或使用浏览器打开 HTML 后打印为 PDF")


if __name__ == "__main__":
    main()
