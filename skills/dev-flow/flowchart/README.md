# flowchart 流程图

dev-flow 开发工作流的可视化流程图，支持多种格式查看。

## 查看入口

打开 **[index.html](./index.html)** 查看全部版本的画廊页，一键跳转到任意格式文件。

也可以直接在下方表格中点击具体文件链接。

## 当前版本

**v5**（2026-07-22）→ `versions/v5_2026-07-22/`

> v5 核心更新：交互体验与自检体系完善（新增 dev:ask/dev:guide 交互式菜单、dev:help --check 帮助一致性检查）、
> 源文件索引补全（branch-recommendation.md/cross-project/handoff.md 等遗漏项）、
> 命令数从 10 条扩展至 14 条。

## 版本历史

| 版本 | 日期 | 说明 | 文件 |
| --- | --- | --- | --- |
| v1 | 2026-04-03 | 初始版本（dev-flow 重构后首版） | [html](./versions/v1_2026-04-03/flowchart.html) · [md](./versions/v1_2026-04-03/flowchart.md) · [png](./versions/v1_2026-04-03/flowchart.png) · [svg](./versions/v1_2026-04-03/flowchart.svg) |
| v2 | 2026-04-10 | 统一流程设计（单一流程+智能评估执行深度） | [html](./versions/v2_2026-04-10/flowchart.html) · [md](./versions/v2_2026-04-10/flowchart.md) · [png](./versions/v2_2026-04-10/flowchart.png) |
| v3 | 2026-07-06 | 程序化执行层重构（物理检查点+状态机+6模式+micro-fix+分批+漂移） | [html](./versions/v3_2026-07-06/flowchart.html) · [md](./versions/v3_2026-07-06/flowchart.md) · [png](./versions/v3_2026-07-06/flowchart.png) |
| v5 | 2026-07-22 | 交互体验与自检体系完善（dev:ask菜单+help一致性检查+盲区清单+索引补全） | [html](./versions/v5_2026-07-22/flowchart.html) · [md](./versions/v5_2026-07-22/flowchart.md) · [png](./versions/v5_2026-07-22/flowchart.png) |
| v4 | 2026-07-14 | 交互与执行层持续硬化（口语消歧+文档平台矩阵+6→7修复+micro-fix升级+热启动增强） | [html](./versions/v4_2026-07-14/flowchart.html) · [md](./versions/v4_2026-07-14/flowchart.md) · [png](./versions/v4_2026-07-14/flowchart.png) |

## 目录结构

```text
flowchart/
├── index.html              # 画廊入口：一键查看所有版本
├── README.md               # 本文件：用户导航
├── SPEC.md                 # AI 更新指南（版本管理 + 生成规范 + 模板）
└── versions/               # 版本目录
    └── v{N}_{日期}/        # 各版本（当前最新版见"当前版本"）
        ├── flowchart.md    #    Mermaid 源码（唯一源文件）
        ├── flowchart.html  #    交互式 HTML（必生成）
        ├── flowchart.png   #    全页截图（必生成）
        └── flowchart.svg   #    矢量图（可选，散图）

```

## 文件格式说明

| 文件 | 格式 | 用途 |
| --- | --- | --- |
| `flowchart.md` | Mermaid 源码 | IDE / GitHub 直接渲染预览 |
| `flowchart.html` | 交互式 HTML | 浏览器查看，支持导航跳转和章节高亮 |
| `flowchart.png` | 位图（全页截图） | 快速预览、IM 分享 |
| `flowchart.svg` | 矢量图（散图，可选） | 嵌入其他文档时使用 |

## 快速开始

- **画廊入口**：打开 [index.html](./index.html)，一键跳转任意版本的任意格式
- **浏览器查看**：打开最新版本目录下的 `flowchart.html`
- **IDE 预览**：打开 `flowchart.md`，使用 Markdown 预览功能
- **分享**：使用 `flowchart.png`
