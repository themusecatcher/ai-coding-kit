---
name: pdf-reader
description: PDF 全能工具包。读取/提取文本和表格、PDF 转图片、OCR 识别、提取嵌入图片、合并/拆分/旋转/水印/裁剪 PDF、创建新 PDF。当用户提到 .pdf 文件或需要处理 PDF 时自动加载。
keywords: ["PDF", "读取PDF", "PDF转图片", "OCR", "合并PDF", "水印", "pdf-reader"]
---

# PDF Toolkit

当用户提到 `.pdf` 文件、要求读取/创建/编辑 PDF，或对话中涉及 PDF 文档时，自动加载此 Skill。

## 触发条件

以下任一条件满足时自动加载：

- 用户消息中包含 `.pdf` 文件路径
- 用户要求"读取/打开/查看/提取/合并/拆分/创建 PDF"
- 用户提供 PDF 文件让 AI 分析
- 任务需要从 PDF 中获取信息（如技术文档、设计方案等）

## 脚本路径

所有脚本位于 `~/.codebuddy/skills/pdf-reader/scripts/`。

---

## 一、读取能力 (read_pdf.py)

### 1. 文本提取

```bash
# 提取全部文本
python3 scripts/read_pdf.py /path/to/document.pdf

# 指定页面范围
python3 scripts/read_pdf.py /path/to/document.pdf --pages 1-5

# 指定单页或混合
python3 scripts/read_pdf.py /path/to/document.pdf --pages 1-3,5,8-10

# 指定引擎
python3 scripts/read_pdf.py /path/to/document.pdf --engine fitz
```

### 2. 表格提取

```bash
python3 scripts/read_pdf.py /path/to/document.pdf --tables
python3 scripts/read_pdf.py /path/to/document.pdf --tables --pages 3-5
```

需要 pdfplumber：`pip3 install pdfplumber`

### 3. 元数据查看

```bash
python3 scripts/read_pdf.py /path/to/document.pdf --metadata
```

### 4. PDF 转图片

```bash
# 将所有页面转为 PNG
python3 scripts/read_pdf.py /path/to/document.pdf --to-images ./output_dir/

# 指定页面和 DPI
python3 scripts/read_pdf.py /path/to/document.pdf --to-images ./output_dir/ --pages 1-5 --dpi 300
```

引擎优先级：pypdfium2 > pdf2image(poppler) > fitz(PyMuPDF)

### 5. OCR 识别（扫描版 PDF）

```bash
# 英文 OCR
python3 scripts/read_pdf.py /path/to/scanned.pdf --ocr

# 中文 OCR
python3 scripts/read_pdf.py /path/to/scanned.pdf --ocr --ocr-lang chi_sim

# 日文 OCR
python3 scripts/read_pdf.py /path/to/scanned.pdf --ocr --ocr-lang jpn

# 指定页面
python3 scripts/read_pdf.py /path/to/scanned.pdf --ocr --pages 1-3
```

需要：`pip3 install pytesseract` + `brew install tesseract`

### 6. 提取嵌入图片

```bash
python3 scripts/read_pdf.py /path/to/document.pdf --images ./output_dir/
python3 scripts/read_pdf.py /path/to/document.pdf --images ./output_dir/ --pages 1-5
```

引擎优先级：fitz(PyMuPDF) > pdfimages(poppler CLI)

### 7. 环境检查

```bash
python3 scripts/read_pdf.py --check
```

### 引擎降级策略

| 优先级 | 引擎 | Python 包 | 特点 |
|--------|------|-----------|------|
| 1 | PyMuPDF | `fitz` | 最快、最准确、支持图片提取 |
| 2 | pdfplumber | `pdfplumber` | 表格提取最强、保留布局 |
| 3 | pypdf | `pypdf` | 轻量、纯 Python |
| 4 | PyPDF2 | `PyPDF2` | 旧版兼容 |
| 5 | pdftotext | poppler CLI | 系统级工具 |

---

## 二、编辑能力 (edit_pdf.py)

需要 pypdf 或 PyPDF2：`pip3 install pypdf`

### 1. 合并 PDF

```bash
python3 scripts/edit_pdf.py merge -o merged.pdf file1.pdf file2.pdf file3.pdf
```

### 2. 拆分 PDF

```bash
# 拆分全部页面
python3 scripts/edit_pdf.py split input.pdf -o output_dir/

# 拆分指定页面
python3 scripts/edit_pdf.py split input.pdf -o output_dir/ --pages 1-5
```

### 3. 旋转页面

```bash
# 全部页面旋转 90°
python3 scripts/edit_pdf.py rotate input.pdf -o rotated.pdf --angle 90

# 指定页面旋转
python3 scripts/edit_pdf.py rotate input.pdf -o rotated.pdf --angle 180 --pages 1,3,5
```

### 4. 添加水印

```bash
python3 scripts/edit_pdf.py watermark input.pdf watermark.pdf -o output.pdf

# 指定页面
python3 scripts/edit_pdf.py watermark input.pdf watermark.pdf -o output.pdf --pages 1-5
```

### 5. PDF 裁剪

```bash
# box 格式：left,bottom,right,top（单位：points，1inch = 72points）
python3 scripts/edit_pdf.py crop input.pdf -o cropped.pdf --box 50,50,500,700

# 指定页面
python3 scripts/edit_pdf.py crop input.pdf -o cropped.pdf --box 50,50,500,700 --pages 1-3
```

---

## 三、创建能力 (create_pdf.py)

需要 reportlab：`pip3 install reportlab`

### 1. 文本转 PDF

```bash
# 从字符串创建
python3 scripts/create_pdf.py text -o doc.pdf --content "Hello World"

# 从文本文件创建
python3 scripts/create_pdf.py text -o doc.pdf --file input.txt

# 带标题和自定义字体
python3 scripts/create_pdf.py text -o doc.pdf --file input.txt --title "My Document" --font-size 14
```

### 2. 数据表格转 PDF

```bash
# 从 CSV 创建
python3 scripts/create_pdf.py table -o report.pdf --csv data.csv

# 从 JSON 创建
python3 scripts/create_pdf.py table -o report.pdf --json data.json --title "Data Report"
```

JSON 格式支持：
- `[{"col1": "val1", "col2": "val2"}, ...]`（字典列表，自动提取表头）
- `[["header1", "header2"], ["val1", "val2"], ...]`（嵌套列表）

### 3. 空白 PDF

```bash
python3 scripts/create_pdf.py blank -o empty.pdf --pages 5
```

---

## 四、JS 端处理

参见 [reference.md](reference.md)，涵盖：

- **pdf-lib**：浏览器/Node.js 创建和修改 PDF（MIT）
- **pdfjs-dist**：浏览器端渲染和文本提取（Apache-2.0）

---

## 使用流程

### AI 助手调用规范

1. **收到 PDF 相关请求** → 加载本 Skill
2. **确定脚本路径** → `~/.codebuddy/skills/pdf-reader/scripts/`
3. **选择合适的脚本**：
   - 读取/提取 → `read_pdf.py`
   - 编辑（合并/拆分/旋转/水印/裁剪） → `edit_pdf.py`
   - 创建新 PDF → `create_pdf.py`
   - JS 端需求 → 参考 `reference.md`
4. **大文件策略**：超过 50 页的 PDF，先用 `--metadata` 预览，再按需 `--pages` 分段

---

## 依赖安装

```bash
# 核心（推荐全装）
pip3 install PyMuPDF       # fitz - 读取/转图片/提取图片
pip3 install pypdf          # 编辑（合并/拆分/旋转/水印/裁剪）
pip3 install reportlab      # 创建新 PDF

# 增强
pip3 install pdfplumber     # 表格提取
pip3 install pypdfium2      # PDF 转图片（无外部依赖）

# OCR
pip3 install pytesseract    # OCR Python 绑定
brew install tesseract       # OCR 引擎
brew install tesseract-lang  # 额外语言包（中文等）

# 系统工具
brew install poppler        # pdftotext / pdfimages CLI

# JS 端
npm install pdf-lib         # 创建/修改 PDF
npm install pdfjs-dist      # 渲染/提取文本
```

---

## 限制

- **扫描版 PDF**（纯图片）：需要 OCR（`pytesseract` + `tesseract`）
- **加密 PDF**：当前不支持解密，需用 `qpdf --decrypt` 预处理
- **复杂排版**：数学公式、多栏布局可能提取不完整
- **CJK 字体**：reportlab 创建中文 PDF 需额外配置字体

## 输出格式

所有脚本输出遵循以下格式，便于 AI 解析：

```
=== <操作类型> ===
[结构化信息]

=== Page N ===
[内容]
```

错误时输出：
```
=== ERROR ===
[错误描述和修复建议]
```
