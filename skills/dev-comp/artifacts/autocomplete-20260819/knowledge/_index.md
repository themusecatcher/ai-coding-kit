---
project: "vue-amazing-ui"
base_branch: "main"
created: "2026-08-18"
last_updated: "2026-08-18"

# Sync / Scan 增量锚点（由 dev:kb sync / scan --diff 自动维护，首次 scan --all 后写入）
last_scanned_sha: ""
last_synced_sha: ""
last_synced_at: ""
---

# vue-amazing-ui 项目知识索引

## 模块清单

| 模块 | 说明 | 主题覆盖 | 置信度 | 最后验证 |
|------|------|---------|--------|---------|
| autocomplete | 自动完成组件（输入框自动补全，API 对齐 Ant Design Vue 4.2.6） | ui/logic/pitfalls | pending | 2026-08-18 |

## 概念索引

| 概念/术语 | 所在模块 | 说明 |
|---------|---------|------|
| 面板三态对齐（left/right/viewport-left） | autocomplete | 下拉面板水平定位：左对齐→右对齐→贴视口左，基于实际遮挡检测 |
| backfill 键盘回填 | autocomplete | ↑↓ 环形循环导航时回填高亮项到输入框，Esc 还原 |
| Option/GroupOption 数据源 | autocomplete | options 支持 string/number/Option/GroupOption 四种形态，分组靠 `options` 字段识别 |
| 有值即显示清除按钮 | autocomplete | showClear computed，与项目 Input 组件惯例一致（antdv 为 hover 显示） |

## 跨仓库知识

| 参数/链路 | 本方文件 | 对方知识库 | 说明 |
|---------|---------|-----------|------|
| （无跨仓库链路） | - | - | 独立开源组件库，无跨仓库参数传递 |

## 接口索引

| 接口路径 | 所在模块 | 用途 |
|---------|---------|------|
| （无网络接口） | - | 纯前端组件 |

## 最近变更

| 日期 | 模块 | 变更类型 | 摘要 |
|------|------|---------|------|
| 2026-08-18 | autocomplete | 新增 | 新增 AutoComplete 组件全量能力 + 演示页 + 文档（feat/auto-complete 分支） |
