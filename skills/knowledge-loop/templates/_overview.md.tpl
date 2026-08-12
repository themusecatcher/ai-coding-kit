---
module: "{module-name}"

# 置信度（5 级：draft/scanned/pending/verified/stale；废弃用 deprecated 生命周期状态）
confidence: "verified"

# 创建分支追踪（pending 级别必填，其他级别可选）
created_branch: ""              # 知识创建时所在的 git 分支（feature/* 时由沉淀自动写入）
base_branch: "master"           # 目标合入分支（默认取 _index.md 的 base_branch）

# 代码锚点（供漂移检测使用；module 级填模块根目录，topic 级填具体文件）
code_anchors:
  - path: "src/{module-path}/"  # 模块根目录或核心文件列表

# 业务验证信息（独立维度，与 confidence 正交）
release:
  released: false               # 是否已上线
  released_at: null             # 上线日期（可选）
  verified_in_production: false # 是否有真实生产环境证据

# 稳定性指标（自动维护）
stability:
  last_verified: "YYYY-MM-DD"   # 最近一次验证通过的时间
  drift_count: 0                # 漂移次数
  days_since_merge: 0           # 合入 base 分支天数（verified 才有意义）
  confidence_score: 85          # 0-100 综合分（公式见 references/confidence.md）

created: "YYYY-MM-DD"
last_scanned: "YYYY-MM-DD"      # 上次扫描日期（可选，仅扫描模式写入）
last_scanned_sha: ""            # 上次扫描本模块时的 git HEAD sha（用于模块级精确增量；dev:kb scan / sync 自动维护）
---

# {module-name} 模块概述

## 功能描述

{该模块的核心功能和在产品中的定位}

## 核心文件

| 文件 | 作用 |
|------|------|
| `{path/to/file}` | {文件职责} |

## 主题知识

| 主题文件 | 状态 | 说明 |
|---------|------|------|
| `_overview.md` | ✅ | 模块概述（本文件）|
| `design-intent.md` | ✅/❌ | 设计意图反哺（P3 远程 wiki/doc_platform）— 默认加载白名单 |
| `data-model.md` | ✅/❌ | {是否已创建} |
| `api.md` | ✅/❌ | {是否已创建} |
| `logic.md` | ✅/❌ | {是否已创建} |
| `ui.md` | ✅/❌ | {是否已创建} |
| `pitfalls.md` | ✅/❌ | {是否已创建} |

## 变更历史

| 日期 | 需求/改动 | 改动说明 |
|------|---------|---------|
| YYYY-MM-DD | {需求简述} | {改了什么} |
