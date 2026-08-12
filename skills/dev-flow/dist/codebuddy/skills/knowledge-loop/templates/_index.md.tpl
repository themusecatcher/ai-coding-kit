---
project: "{project-name}"
base_branch: "master"           # 项目默认 base 分支（feature 沉淀的 pending 知识合入此分支后会升级为 verified）
created: "YYYY-MM-DD"
last_updated: "YYYY-MM-DD"

# Sync / Scan 增量锚点（由 dev:kb sync / scan --diff 自动维护，首次 scan --all 后写入）
last_scanned_sha: ""            # 上次 scan 完成时的 git HEAD sha（scan --diff 起点）
last_synced_sha: ""             # 上次 sync 完成时的 git HEAD sha（sync 起点，优先于 last_scanned_sha）
last_synced_at: ""              # 上次 sync 时间（ISO 8601）
---

<!-- 占位符说明：{module-name} = 模块显示名（用于描述性字段），{module} = 模块目录名（用于索引引用字段） -->
# {project-name} 项目知识索引

## 模块清单

| 模块 | 说明 | 主题覆盖 | 置信度 | 最后验证 |
|------|------|---------|--------|---------|
| {module-name} | {一句话描述} | api/data-model/logic/ui/pitfalls | verified | YYYY-MM-DD |

## 概念索引

| 概念/术语 | 所在模块 | 说明 |
|---------|---------|------|
| {concept} | {module} | {一句话解释} |

## 跨仓库知识

<!--
  当本项目的参数/字段/标识符跨越多个仓库传递时在此记录完整链路。
  每个条目必须包含双向路径：本方知识库文件 → 对方知识库文件。
  格式：对方知识库路径以 ~/.codebuddy/knowledge/ 开头（绝对路径）。
  参考：~/.codebuddy/skills/knowledge-loop/modes/deposit.md 步骤 5.6
-->
| 参数/链路 | 本方文件 | 对方知识库 | 说明 |
|---------|---------|-----------|------|
| {参数名} {发起方→消费方} 传递 | {本方主题文件路径} §{章节} | `{对方知识库绝对路径}` §{章节} | {链路概要} |

## 接口索引

| 接口路径 | 所在模块 | 用途 |
|---------|---------|------|
| {/api/path} | {module} | {一句话说明} |

## 最近变更

| 日期 | 模块 | 变更类型 | 摘要 |
|------|------|---------|------|
| YYYY-MM-DD | {module} | 新增/更新/漂移修复 | {一句话摘要} |
