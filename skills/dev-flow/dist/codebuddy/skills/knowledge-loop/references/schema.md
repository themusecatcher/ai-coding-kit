# 知识库目录结构规范（Schema）

> 首次创建项目知识库时加载本文件。定义目录结构、文件格式、项目名称映射规则。

## 目录结构

```
~/.codebuddy/knowledge/
├── _global/                         # 全局说明与模板规范
│   ├── README.md
│   └── schema.md                    # 文件模板（创建文件时参照）
├── {project-name}/                  # L1 项目级
│   ├── _index.md                    # 项目知识索引（必读入口）
│   ├── {module}/                    # L2 模块级（目录化）
│   │   ├── _overview.md             # 模块概述 + 核心文件 + 变更历史
│   │   ├── design-intent.md         # 设计意图反哺（P3 远程 wiki/doc_platform——默认加载白名单，硬上限 200 行）
│   │   ├── data-model.md            # 数据模型（state/props/interface）
│   │   ├── api.md                   # 接口协议（请求/响应/错误码）
│   │   ├── logic.md                 # 业务逻辑（初始化/分支/联动/函数签名）
│   │   ├── ui.md                    # UI 结构（组件树/Props/渲染条件）
│   │   └── pitfalls.md              # 易错点（踩坑记录/跨模块隐式依赖）
│   ├── _patterns/                   # 跨模块设计模式
│   └── _recipes/                    # 操作手册（How-to）
```

## 项目名称映射

取自项目目录名关键词，与工作上下文的项目缩写保持一致。
首次创建时 AI 推断，用户可纠正。

---

## 文件格式规范

### 主题文件 frontmatter

每个主题文件（`data-model.md`/`api.md`/`logic.md`/`ui.md`/`pitfalls.md`）使用以下 YAML frontmatter：

```yaml
---
module: "{module-name}"
topic: "data-model | api | logic | ui | pitfalls"

# 置信度（5 主级别：draft/scanned/pending/verified/stale；废弃用 deprecated 生命周期状态）
# scanned 在步骤 1 多源仲裁中可被自动升级为 auto-verified 或降为 auto-stale（详见 confidence.md § scanned 自动升级规则）
confidence: "verified"           # draft | scanned | pending | verified | stale | auto-verified | auto-stale

# auto-verified 专属字段（仅在 confidence 为 auto-verified / auto-stale 时存在）
auto_upgrade:                     # 可选（人工 verified / pending / draft 不填此字段）
  upgraded_at: "YYYY-MM-DD"      # 本次自动升级时间
  upgraded_by: "step-1-arbitration"  # step-1-arbitration | dev:kb-sync | dev:kb-scan
  code_anchor: "src/x.ts::foo"    # 佐证使用的代码锚点
  source_ref: "remote-kb/wiki/..." # 原始 wiki / doc_platform / mr 引用
  ttl_days: 90                    # 默认 90 天未被检索命中 → 衰减为 archived

# 创建分支追踪（pending 级别必填，其他级别可选）
created_branch: "feature/xxx"   # 知识创建时所在的 git 分支
base_branch: "master"           # 目标合入分支（默认取 _index.md 的 base_branch，缺省 master）

# 代码锚点（供漂移检测使用）
code_anchors:
  - path: "src/xxx/yyy.ts"      # 文件路径
    symbols: ["fooFn", "BarCls"] # 可选：关键符号列表

# 业务验证信息（独立维度，与 confidence 正交）
release:
  released: false               # 是否已上线
  released_at: null             # 上线日期（可选）
  verified_in_production: false # 是否有生产验证证据

# 稳定性指标（自动维护）
stability:
  last_verified: "YYYY-MM-DD"   # 最近一次验证时间
  drift_count: 0                # 漂移次数
  days_since_merge: 0           # 合入 base 分支天数（verified 才有意义）
  confidence_score: 85          # 0-100 综合分

created: "YYYY-MM-DD"
last_scanned: "YYYY-MM-DD"      # 可选，仅扫描模式写入
---
```

> 💡 `confidence` 字段除 5 个主级别外，还可填：
>
> - `auto-verified` / `auto-stale`：scanned 在多源仲裁中被自动升级或降级的机器子状态（详见 `confidence.md` § scanned 自动升级规则）
> - `archived`：auto-verified 超过 90 天未被命中衰减后的状态（仅存档，检索中不采纳）
> - `deprecated`：生命周期状态，非置信度，模块废弃时使用（详见 `lifecycle.md`）

### _index.md（项目索引）frontmatter

```yaml
---
project: "{project-name}"
base_branch: "master"           # 项目默认 base 分支
created: "YYYY-MM-DD"
last_updated: "YYYY-MM-DD"

# Sync / Scan 增量锚点（由 dev:kb sync / scan --diff 自动维护）
last_scanned_sha: ""            # 上次 scan 完成时的 git HEAD sha（scan --diff 起点）
last_synced_sha: ""             # 上次 sync 完成时的 git HEAD sha（sync 起点，优先于 last_scanned_sha）
last_synced_at: ""              # 上次 sync 时间（ISO 8601）
---
```

> 💡 `last_scanned_sha` / `last_synced_sha` 是 sync / scan --diff 精确增量的核心依据，代替不精确的 `HEAD~10` 回退策略。首次 `scan --all` 后自动写入。

### _overview.md（模块概述）frontmatter

```yaml
---
module: "{module-name}"
confidence: "verified"

# 创建分支追踪（pending 级别必填，其他级别可选）
created_branch: ""              # 知识创建时所在的 git 分支
base_branch: "master"           # 目标合入分支（默认取 _index.md 的 base_branch）

code_anchors:
  - path: "src/xxx/"            # 模块根目录或核心文件列表
release:
  released: false
  released_at: null
  verified_in_production: false
stability:
  last_verified: "YYYY-MM-DD"
  drift_count: 0
  days_since_merge: 0           # 合入 base 分支天数（verified 才有意义）
  confidence_score: 85          # 0-100 综合分
created: "YYYY-MM-DD"
last_scanned: "YYYY-MM-DD"
last_scanned_sha: ""            # 上次扫描本模块时的 git HEAD sha（用于模块级精确增量）
---
```

---

## 字段填充约束

| 字段 | 必填条件 | 自动化维护 |
|------|---------|-----------|
| `confidence` | 始终必填 | 沉淀/扫描/漂移检测时自动更新；scanned 在步骤 1 多源仲裁中可自动转为 auto-verified / auto-stale |
| `auto_upgrade` | 仅 confidence 为 auto-verified / auto-stale 时填充 | 仲裁升级时自动写入；`dev:kb audit --reject` / `--confirm` 可修改状态 |
| `created_branch` | confidence=pending 时必填 | 沉淀时自动写入 `git branch --show-current` |
| `base_branch` | 建议填写 | 取项目 `_index.md` 的 base_branch，缺省 master |
| `code_anchors` | 强烈建议填写 | 沉淀时 AI 从改动文件列表推断 |
| `release.released` | 可选，默认 false | `dev:kb mark-release` 手动标记；禁止时间推算 |
| `release.verified_in_production` | 可选，默认 false | 仅用户显式标记或 CI 事件写入 |
| `stability.last_verified` | 建议填写 | 沉淀/扫描/验证通过时自动刷新 |
| `stability.drift_count` | 自动维护 | 每次漂移检测命中 +1，stale→非 stale 时清零 |
| `stability.days_since_merge` | 自动维护（verified） | `dev:kb sync` 计算；非 verified 级别为 0 |
| `stability.confidence_score` | 自动计算 | 公式见 `confidence.md` |
| `last_scanned_sha`（_index.md 及_overview.md） | 自动维护 | `dev:kb scan` / `scan --diff` 完成后写入 `git rev-parse HEAD` |
| `last_synced_sha` / `last_synced_at`（_index.md） | 自动维护 | `dev:kb sync` 完成后写入当前 HEAD 和时间 |

---

## 文件内容

- 正文使用 Markdown 格式，按主题组织内容。
- 具体模板 → `templates/` 目录下对应 `.tpl` 文件。
