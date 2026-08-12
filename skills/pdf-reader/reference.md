# JS 端 PDF 处理参考

浏览器端和 Node.js 环境下的 PDF 处理方案。

---

## pdf-lib — 创建和修改 PDF

**安装**: `npm install pdf-lib`  
**License**: MIT  
**环境**: Browser + Node.js

### 创建新 PDF

```typescript
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';

async function createPdf() {
  const doc = await PDFDocument.create();
  const page = doc.addPage([595.28, 841.89]); // A4
  const font = await doc.embedFont(StandardFonts.Helvetica);

  page.drawText('Hello World', {
    x: 50, y: 750, size: 24, font, color: rgb(0, 0, 0),
  });

  const bytes = await doc.save();
  // Browser: download
  const blob = new Blob([bytes], { type: 'application/pdf' });
  const url = URL.createObjectURL(blob);
  window.open(url);
}
```

### 修改已有 PDF

```typescript
import { PDFDocument } from 'pdf-lib';

async function modifyPdf(existingPdfBytes: ArrayBuffer) {
  const doc = await PDFDocument.load(existingPdfBytes);
  const pages = doc.getPages();
  const firstPage = pages[0];

  firstPage.drawText('Added by pdf-lib', {
    x: 50, y: 50, size: 12,
  });

  return await doc.save();
}
```

### 合并 PDF

```typescript
import { PDFDocument } from 'pdf-lib';

async function mergePdfs(pdfBytesArray: ArrayBuffer[]) {
  const merged = await PDFDocument.create();

  for (const bytes of pdfBytesArray) {
    const doc = await PDFDocument.load(bytes);
    const copiedPages = await merged.copyPages(doc, doc.getPageIndices());
    copiedPages.forEach((page) => merged.addPage(page));
  }

  return await merged.save();
}
```

### 提取指定页面

```typescript
import { PDFDocument } from 'pdf-lib';

async function extractPages(pdfBytes: ArrayBuffer, pageIndices: number[]) {
  const src = await PDFDocument.load(pdfBytes);
  const dest = await PDFDocument.create();
  const pages = await dest.copyPages(src, pageIndices);
  pages.forEach((page) => dest.addPage(page));
  return await dest.save();
}
```

---

## pdfjs-dist — 渲染和文本提取

**安装**: `npm install pdfjs-dist`  
**License**: Apache-2.0  
**环境**: Browser（主要）+ Node.js

### 渲染 PDF 页面到 Canvas

```typescript
import * as pdfjsLib from 'pdfjs-dist';

// 设置 worker（Webpack/Vite 场景按项目配置调整路径）
pdfjsLib.GlobalWorkerOptions.workerSrc = 'pdfjs-dist/build/pdf.worker.min.js';

async function renderPage(pdfUrl: string, pageNum: number, canvas: HTMLCanvasElement) {
  const pdf = await pdfjsLib.getDocument(pdfUrl).promise;
  const page = await pdf.getPage(pageNum);
  const viewport = page.getViewport({ scale: 1.5 });

  canvas.width = viewport.width;
  canvas.height = viewport.height;

  const ctx = canvas.getContext('2d')!;
  await page.render({ canvasContext: ctx, viewport }).promise;
}
```

### 提取文本

```typescript
import * as pdfjsLib from 'pdfjs-dist';

async function extractText(pdfUrl: string): Promise<string> {
  const pdf = await pdfjsLib.getDocument(pdfUrl).promise;
  const texts: string[] = [];

  for (let i = 1; i <= pdf.numPages; i++) {
    const page = await pdf.getPage(i);
    const content = await page.getTextContent();
    const pageText = content.items
      .map((item: any) => item.str)
      .join(' ');
    texts.push(pageText);
  }

  return texts.join('\n\n');
}
```

### 带坐标的文本提取（高级）

```typescript
interface TextItem {
  text: string;
  x: number;
  y: number;
  width: number;
  height: number;
  pageNum: number;
}

async function extractTextWithPositions(pdfUrl: string): Promise<TextItem[]> {
  const pdf = await pdfjsLib.getDocument(pdfUrl).promise;
  const items: TextItem[] = [];

  for (let i = 1; i <= pdf.numPages; i++) {
    const page = await pdf.getPage(i);
    const content = await page.getTextContent();

    for (const item of content.items as any[]) {
      if (item.str.trim()) {
        items.push({
          text: item.str,
          x: item.transform[4],
          y: item.transform[5],
          width: item.width,
          height: item.height,
          pageNum: i,
        });
      }
    }
  }

  return items;
}
```

---

## 工具选择指南

| 需求 | 推荐工具 | 说明 |
|------|---------|------|
| 创建新 PDF | pdf-lib | 纯 JS，无外部依赖 |
| 修改已有 PDF | pdf-lib | 支持添加文字、图片、表单 |
| 合并 / 提取页面 | pdf-lib | API 简洁 |
| 渲染 PDF 到页面 | pdfjs-dist | Canvas 渲染 |
| 提取纯文本 | pdfjs-dist | 浏览器端首选 |
| 带坐标文本 | pdfjs-dist | 适合搜索高亮 |
| 填写表单 | pdf-lib | 支持 AcroForm |
| 服务端批量处理 | Python 脚本 | 使用本 Skill 的 Python 工具 |
