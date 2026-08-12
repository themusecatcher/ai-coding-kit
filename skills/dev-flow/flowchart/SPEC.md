# flowchart AI 更新指南

> **AI 更新流程图前必须先读取本文件**，获取版本信息 + 生成规范，确保每次产出风格一致。
>
> **用户命令**：在任意对话中输入 `dev:flowchart` 或 `dev:chart` 即可一键触发完整生成 Pipeline。

---

## 1. 版本管理

### 版本信息获取

读取 `README.md` 中的「当前版本」和「版本历史」，获取当前版本号 `v{N}`、日期和路径。

### 更新流程

1. 读取 `README.md` 获取当前版本信息
2. 向用户展示交互式提示：

```text
📊 流程图更新准备就绪
当前版本：v{N}（{日期}）— {版本说明}

请选择更新方式：
A. 🔄 覆盖当前版本（直接更新 versions/v{N}_{日期}/ 下的文件）
B. 📦 另存新版本（新内容写入 versions/v{N+1}_{今日日期}/）
C. ❌ 取消更新

```

#### 用户选 A（覆盖当前版本）

更新 `versions/v{N}_{日期}/` 下的文件，README.md 无需修改。

#### 用户选 B（另存新版本）

1. 创建 `versions/v{N+1}_{今日日期}/` 目录，生成文件
2. 更新 README.md：

- "当前版本"行 → `**v{N+1}**（{今日日期}）→ \`versions/v{N+1}_{今日日期}/\``
- "版本历史"表新增一行

3. **更新 `index.html` 画廊页（强制，v5 补遗）**：

- 头部"版本数"→ 递增（如 `4 个版本` → `5 个版本`）
- `.section-nav` 新增 `v{N+1}` 导航链接（`class="active"`），移除旧版的 `active`
- `.card-grid` 顶部插入新版本卡片（`class="ver-card current"` + `ver-badge` 当前），移除旧版的 `current` + `ver-badge`

### 版本规则

- 版本号从 v1 递增，不跳号
- 日期格式：YYYY-MM-DD
- 旧版本保留供回溯，不主动清理（用户要求时可删除）

---

## 2. 文件生成规范

每个版本目录下包含 3~4 个文件（svg 为可选），**`flowchart.md` 是唯一源文件**：

```text
versions/v{N}_{日期}/
├── flowchart.md     ← 源文件（AI 直接编写）【必须】
├── flowchart.html   ← 基于 md 生成【必须】
├── flowchart.png    ← 全页截图（Chrome headless）【必须】
└── flowchart.svg    ← 矢量图（mmdc，拆分为独立散图）【可选】

```

> ⚠️ **v3 变更（2026-07-06）**：`flowchart.svg` 改为可选。`mmdc` 会将 md 中每个 mermaid 块渲染为独立 SVG（28+ 个散图），无法合并为单文件。矢量图查看用 html 在浏览器中即可，仅当需要嵌入其他文档时才生成 svg。

### 生成 Pipeline

```text
Step 1: 生成 flowchart.md（必须）← 唯一必须步骤
↓
Step 2: 交互确认（必须）
↓
Step 3: 增强文件生成（用户按需选择）

```

#### Step 1：生成 flowchart.md（必须）

AI 按 §3 模板规范直接编写。这是唯一源文件，也是整个 Pipeline 唯一必须完成的步骤。

#### Step 2：交互确认（必须）

md 生成后，向用户展示确认选项：

```text
flowchart.md 已生成，请确认：
A. ✅ 确认，继续生成 HTML 和 PNG（基于当前 md 派生可视化文件）
B. ✏️ 需要修改 md（请指出修改点）
C. ❌ 取消，仅保留 md

```

- 用户选 A → 进入 Step 3（生成 html + png；svg 可选）
- 用户选 B → 根据反馈修改 md，重新确认
- 用户选 C → Pipeline 结束，仅保留 md

#### Step 3：增强文件生成（html + png 必生成，svg 可选）

> ⚠️ **html 完全重写规则（强制）**：html 必须**从 flowchart.md 完全重新生成**，禁止复制上一版本的 html 后做局部修改。原因：① 复制修改容易继承旧版本图/文不一致的遗留问题；② 新版本新增的 Mermaid 图和文字描述可能被遗漏；③ 违反 §「md ↔ html 同步规则」的质量底线。

html 和 png 每次必须生成。生成前先确认是否同时生成 svg（每个 Mermaid 图一张独立矢量图，共 N 张）？

```text
html + png 将自动生成。是否也生成 svg（独立散图，每个 Mermaid 块一张）？
A. ✅ 也生成 svg
B. ⏭️ 跳过 svg

```

**各文件生成方式：**

**html 生成**（每次必生成，完全重写）：

- AI 按 §4 模板规范**完全重新编写**，从 md 提取 mermaid 块和文字描述，生成完整 html，禁止复制旧版 html 后做局部修补

**png 生成**（每次必生成）：

- 使用 Chrome headless 全页截图：

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
--headless --disable-gpu \
--screenshot=flowchart.png \
--window-size=1400,12000 \
--virtual-time-budget=12000 \
"file://{绝对路径}/flowchart.html"
```

- 使用 12000px 高度确保完整捕获全页内容

**svg 生成**（选 A 时）：

- 使用 `mmdc -i flowchart.md -o flowchart.svg`，需安装 `@mermaid-js/mermaid-cli`
- ⚠️ mmdc 会生成 N 个独立散图（`flowchart-1.svg` ~ `flowchart-N.svg`），不会合并为单文件
- 生成后整理到 `svg/` 子目录避免散乱
- AI 提示用户执行命令，不自行操作

> **交付标准**：flowchart.md + flowchart.html + flowchart.png 三者必须齐全，flowchart.svg 为可选。

### md ↔ html 同步规则（生成 html 时必须遵守）

- **Mermaid 代码完全相同**：md 中的每个 Mermaid 代码块必须原样出现在 html 对应章节中
- **章节顺序一致**：md 的 `## N.` 编号与 html 的 `<div class="chart-section" id="{锚点}">` 一一对应
- **导航同步**：html 左侧导航的链接数量和顺序必须与章节数量和顺序一致
- **文字内容同步**：md 中的所有文字描述（章节导语、关键设计点说明、核心产出说明、
  参考表格、图表后补充）都必须在 html 中以对应的 HTML 元素呈现
  （`<div class="section-intro">`、`<div class="chart-note">`、`<table>` 等），
  不能只同步 mermaid 代码块而遗漏文字内容

---

## 3. flowchart.md 模板规范

### 文件结构

````markdown

# dev-flow 完整流程图

> 静态 Mermaid 版本，可在 GitHub / IDE 中直接渲染预览。
> 交互式版本（支持点击跳转到源文件）：[flowchart.html](./flowchart.html)

---

## 1. {章节标题}

```
flowchart TD
...

```text

> {补充说明（可选）}

---

## 2. {下一章节}

...

## 13. 源文件索引

| 文件 | 说明 |
| --- | --- |
| ... | ... |

````

### 章节编排规则

| 编号 | 章节 | 内容 |
| --- | --- | --- |
| 1 | 入口触发与模式路由 | 关键词匹配 → 模式分发 → 活跃流程恢复 |
| 2 | 完整模式总览 | 阶段0 + 步骤1~10 全景 |
| 3 | 快速模式总览 | 步骤1~7 精简路径 |
| 4 | 极速模式总览 | 3步极简路径 |
| 5 | 步骤 7 commit/devlog/knowledge 子流程 | 调用方×环节矩阵 |
| 6 | 阶段0：需求理解 | 完整模式独有子流程 |
| 7 | 步骤1~4.5 子流程 | 各步骤详细流程图 |
| 9 | 步骤5~7 子流程 | 执行/后置钩子/验证/Commit |
| 10 | 完整模式独有步骤 | 步骤8~10 |
| 11 | 特殊流程 | 迭代修复/回退/门控钩子 |
| 12 | 交互模式 | 精简交互优化 |
| 13 | 源文件索引 | 所有 dev-flow 文件清单 |

### Mermaid 图表规范

- 图表类型：统一使用 `flowchart TD`（自上而下）
- 节点格式：`ID["emoji 中文标题"]`，emoji 与标题间有空格
- 判断节点：`ID{"中文问题?"}`
- 连线标签：`-->|"中文标签"|`，标签用双引号包裹
- 子图：`subgraph title["emoji 标题"]` + `end`
- 样式类：用 `classDef` 定义颜色，用 `class` 批量应用
- 每个章节的 Mermaid 代码块独立，不跨章节合并
- 章节间用 `---` 分隔线隔开

### 补充说明规范

- 每个 Mermaid 图表下方可附 `> 补充说明`（blockquote 格式）
- 表格型补充（如回退规则）使用标准 Markdown 表格
- 章节内可包含多个子标题（`###`），每个子标题下一个 Mermaid 图

---

## 4. flowchart.html 模板规范

### 整体架构

```text
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>dev-flow 完整流程图</title>
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<style>/* 见下方样式规范 */</style>
</head>
<body>
<nav><!-- 左侧导航 --></nav>
<main id="main-content">
<div class="hero"><!-- 顶部概览 --></div>
<div class="chart-section" id="{锚点}"><!-- 各章节 --></div>
...
</main>
<button id="backToTop"><!-- 回到顶部 --></button>
<script>/* Mermaid 初始化 + 导航高亮 */</script>
</body>
</html>

```

### 设计系统（CSS 变量）

必须使用以下 CSS 变量，保证所有版本视觉一致：

```css
:root {
/* 背景色 */
--bg-primary: #09090b; --bg-secondary: #0f0f12; --bg-tertiary: #18181b;
--bg-elevated: #1c1c1f; --bg-hover: #27272a;
/* 边框 */
--border-default: #27272a; --border-muted: #1e1e21;
/* 文字 */
--text-primary: #fafafa; --text-secondary: #a1a1aa; --text-tertiary: #71717a;
/* 强调色 */
--accent: #818cf8; --accent-hover: #6366f1;
--accent-bg: rgba(99,102,241,0.06); --accent-bg-hover: rgba(99,102,241,0.12);
/* 语义色 */
--green: #34d399; --green-bg: rgba(52,211,153,0.08);
--red: #f87171; --red-bg: rgba(248,113,113,0.08);
--yellow: #fbbf24; --yellow-bg: rgba(251,191,36,0.06);
--purple: #c084fc; --purple-bg: rgba(192,132,252,0.08);
--orange: #fb923c; --orange-bg: rgba(251,146,60,0.08);
/* 间距 */
--space-1: 4px; --space-2: 8px; --space-3: 12px; --space-4: 16px;
--space-5: 20px; --space-6: 24px; --space-8: 32px; --space-10: 40px; --space-12: 48px;
/* 圆角 */
--radius-sm: 6px; --radius-md: 8px; --radius-lg: 12px; --radius-xl: 16px;
/* 布局 */
--nav-width: 280px;
/* 动画 */
--transition-fast: 150ms cubic-bezier(0.4, 0, 0.2, 1);
--transition-normal: 250ms cubic-bezier(0.4, 0, 0.2, 1);
}

```

### 布局结构

- **左侧导航**（`<nav>`，固定宽度 280px）：
- 导航头：logo emoji `🔀` + 标题 `dev-flow` + 版本描述
- 导航分组（`.nav-group`）：概览 / 完整模式步骤 / 特殊流程
- 每个链接格式：`<a href="#{锚点}"><span class="nav-icon">{emoji}</span>{标题} <span class="badge badge-{类型}">{标签}</span></a>`
- 滚动时自动高亮当前章节（IntersectionObserver）

- **主内容区**（`<main>`）：
- Hero 区：标题 + 描述 + 统计数字（模式数/步骤数/收尾环节数/回退规则数）
- 章节区（`.chart-section`）：section-header + chart-card + legend + mermaid
- 章节间分隔线（`.section-divider`）

### 章节卡片模板

```html
<div class="chart-section" id="{锚点}">
<div class="section-header">
<div class="section-icon" style="background:var(--{色系}-bg)">{emoji}</div>
<h2>{章节标题}</h2>
</div>
<div class="chart-card">
<div class="legend"><!-- 可选：图例 --></div>
<div class="mermaid">
{与 flowchart.md 中完全相同的 Mermaid 代码}
</div>
</div>
</div>
<div class="section-divider"></div>

```

### Badge 类型映射

| 类型 | CSS 类 | 用途 |
| --- | --- | --- |
| Full | `badge-full` | 完整模式独有 |
| Quick | `badge-quick` | 快速模式 |
| Ultra | `badge-ultra` | 极速模式 |
| Shared | `badge-shared` | 多模式共享 |
| 1~7 | `badge-shared` | 步骤范围标注 |

### Mermaid 初始化配置

```javascript
mermaid.initialize({
startOnLoad: true,
theme: 'dark',
securityLevel: 'strict',
themeVariables: {
primaryColor: '#1e1b4b', primaryTextColor: '#e0e7ff', primaryBorderColor: '#4338ca',
lineColor: '#6366f1', secondaryColor: '#1c1917', tertiaryColor: '#18181b',
fontFamily: 'Inter, -apple-system, sans-serif', fontSize: '13px',
nodeBorder: '#4338ca', mainBkg: '#1e1b4b',
clusterBkg: 'rgba(99,102,241,0.06)', clusterBorder: '#312e81',
edgeLabelBackground: '#18181b', nodeTextColor: '#e0e7ff'
},
flowchart: {
useMaxWidth: true, htmlLabels: false, curve: 'basis',
padding: 12, nodeSpacing: 30, rankSpacing: 40
}
});

```

### 交互功能

- **导航高亮**：IntersectionObserver 监听章节可见性，自动高亮对应导航链接
- **回到顶部**：滚动超过 400px 时显示按钮
- **响应式**：移动端隐藏左侧导航，主内容区全宽
- **字体**：Google Fonts `Inter`（wght@400;500;600;700）

---

## 5. 质量检查清单

生成/更新后逐项核对：

### flowchart.md（必检）

- [ ] 章节编号连续（1~13）
- [ ] 每个 Mermaid 代码块语法正确（可在 Mermaid Live Editor 验证）
- [ ] 源文件索引（章节13）与 dev-flow 实际文件清单一致

### flowchart.html（必检）

- [ ] 左侧导航链接数 = 章节数
- [ ] html 中 Mermaid 代码与 md 完全一致
- [ ] md 中的文字描述在 html 中均有对应呈现（导语/补充/表格）
- [ ] CSS 变量未硬编码（所有颜色/间距/圆角使用 var()）
- [ ] Hero 区统计数字与实际内容匹配
- [ ] 浏览器打开 html 无渲染错误

### flowchart.png（必检）

- [ ] png 文件存在且清晰度可接受
- [ ] 所有已生成文件版本一致（同一次生成，内容同源）

### index.html 画廊页（必检，v5 补遗）

> 另存新版本时必须更新；覆盖当前版本时无需修改。

- [ ] 头部版本数量已递增（如 `4 个版本` → `5 个版本`）
- [ ] `.section-nav` 已新增 `v{N+1}` 导航链接，旧版 `active` 已移除
- [ ] `.card-grid` 顶部已插入新版本卡片（含 `ver-badge` 当前），旧版 `current` + `ver-badge` 已移除
- [ ] 新版卡片的 HTML/MD/PNG 链接指向正确的版本目录

### flowchart.svg（可选，仅当生成时检查）

- [ ] svg 文件存在且可正常渲染
- [ ] 所有已生成文件版本一致（同一次生成，内容同源）
