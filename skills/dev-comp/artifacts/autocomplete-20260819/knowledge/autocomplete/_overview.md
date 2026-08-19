---
module: "autocomplete"
title: "AutoComplete 自动完成"
category: "数据录入"
confidence: "pending"
created_branch: "feat/auto-complete"
base_branch: "main"
created: "2026-08-18"
last_updated: "2026-08-18"
status: "feature 分支开发中（合入 main 后 dev:kb sync 升级 verified）"
---

# AutoComplete 自动完成

> 一个带提示的输入框，用户可以自由输入，关键词是辅助输入（区别于 Select 的关键词是选择）。

## 参考源

| 参考源 | 版本 | 用途 |
|-------|------|------|
| Ant Design Vue AutoComplete | 4.2.6 | API 对齐（Props/Events/Slots/Methods）+ 交互行为对齐 |
| Naive UI AutoComplete | - | 部分惯例（`to` 挂载容器属性） |

## 核心能力

| 能力 | 说明 |
|------|------|
| 远程搜索 | `search` 事件 + `filterOption: false`（默认不筛选，全量显示，由用户更新 options） |
| 分组数据源 | `{label, options}` 结构识别分组，组内选项 24px 缩进（对齐 antdv `controlPaddingHorizontal*2`） |
| 键盘导航 | ↑↓ 环形循环导航（跳过 disabled）+ `backfill` 回填 + Enter 选中 + Esc 还原 |
| 面板定位 | Teleport 到 `to`（默认 body），垂直翻转（bottom/top）× 水平三态对齐（left/right/viewport-left） |
| 清除按钮 | 有值即显示（computed），与项目 Input 惯例一致 |
| 状态 | `status` error/warning 三态边框同色（antdv 4.2.6 实测值），focus 阴影 `getAlphaColor` 计算值 |

## 与其他组件的区别

| 组件 | 关键词 | 数据源 |
|------|-------|--------|
| AutoComplete | 辅助输入 | 自由输入 + options 提示 |
| Select | 选择 | 仅限 options 内选择 |

## 文件清单

| 文件 | 说明 |
|------|------|
| `components/autocomplete/AutoComplete.vue` | 组件本体（单文件，约 1000 行） |
| `components/autocomplete/index.ts` | 入口与类型导出（Props/Option/GroupOption） |
| `src/views/autoComplete/Index.vue` | 演示页（19 分区，21 本库用例 + 21 antdv 真身对照） |
| `docs/guide/components/autocomplete.md` | 组件文档 |
