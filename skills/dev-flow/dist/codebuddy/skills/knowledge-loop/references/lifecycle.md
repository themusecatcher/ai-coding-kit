# 生命周期管理

> 按需加载：管理模式的健康检查 / 过期预警。

## 过期规则

1. 代码漂移检测发现不一致 → `stale`（立即）
2. `stability.last_verified` > 60 天 → 提醒验证
3. `stability.last_verified` > 120 天 → 警告可能过时
4. `release.verified_in_production: true` 的条目：阈值放宽到 90/180 天（有生产验证证据时容错更高）
5. `confidence: deprecated` → 加载时警告
6. `confidence: auto-verified` 且 `today - auto_upgrade.upgraded_at > auto_upgrade.ttl_days`（默认 90） → 衰减为 `archived`（检索中不采纳，仅 `dev:kb audit --archived` 可查阅）。`auto-verified` 被检索命中时重置 `upgraded_at`，推迟衰减。
7. `confidence: auto-stale` → 不自动衰减，保留供 `dev:kb audit` 手动处理

> 💡 方案 A 调整说明：过期阈值不再与 confidence 级别挂钩，而是由 `release.verified_in_production` 独立维度驱动。合并 `production_verified` 为 `verified` 后，"是否经生产验证"的信任加成通过 release 字段表达，保持职责单一。

## git pull 后的生命周期对齐（dev:kb sync）

`dev:kb sync` 是生命周期的核心**主动**事件，每次 `git pull` 后触发，统一处理两类生命周期跳转：

| 跳转类型 | 起点 | 终点 | 触发条件 |
|---------|------|------|---------|
| 自己 pending 升级 | `pending` | `verified` | feature 分支已合入 base（fast-forward / squash / rebase 三重检测命中），自动升级；`stability.days_since_merge` 重置为 0 |
| 他人改动漂移 | `verified` / `auto-verified` | `stale` | 他人 commit 命中本知识 `code_anchors` 或映射模块；`stability.drift_count += 1` |
| 重扫后恢复 | `stale` | 原级别 | 阶段 4 重扫后内容一致 |
| 文件已删除 | 任意 | `deprecated`（待用户确认） | source 文件在仓库中已移除 |

> 详细决策算法见 `modes/manage.md` § dev:kb sync。本文件只描述其在生命周期中的位置。

## 扫描触发的废弃检测

全量扫描（`--all`）时，自动对比扫描识别到的模块列表与知识库已有模块列表：

| 情况 | 处理 |
|------|------|
| 已有模块在代码中无对应目录/路由 | 弹出确认 → 用户确认废弃 → 走下方废弃流程 |
| 已有模块在代码中仍存在但路径变更 | 提示用户确认 → 更新 `_overview.md` 核心文件列表 |

> ❌ 禁止自动标记 `deprecated`，必须用户确认（防止误判：代码可能被重构到新路径而非删除）。

## 废弃流程

1. 将 frontmatter `confidence` 改为 `deprecated`
2. 在文件顶部追加废弃说明
3. 不删除文件（保留历史价值）
4. `_index.md` 模块清单中标注 ⚠️ 已废弃

## auto-verified 衰减为 archived

与「废弃」路径独立但性质相似，供 auto-verified 超过 90 天未被检索命中时使用：

1. `confidence: auto-verified` → `archived`（仅修改 `confidence` 字段，不删除文件不动正文）
2. `_archive/` 目录**不介入**（归档仅针对 design-intent.md 压缩场景，详见 `modes/deposit.md` § 200 行硬上限）
3. 如需恢复 → `dev:kb audit --archived` 查阅 → 手动 `dev:kb verify` 重新走验证 → 验证通过后由用户选择重新为 `verified` 或判定废弃
4. `dev:kb sync` / `dev:kb verify` / `dev:kb health` 内置「衰减检查」环节，会自动调度本路径

> 🔗 完整状态机 + reject/confirm 语义详见 `references/confidence.md` § scanned 自动升级规则 与 `modes/manage.md` § dev:kb audit。

## 跨项目知识提升

当同一个技术模式在 ≥2 个项目中出现时（如灰度控制、接口轮询），提升到 `_global/_patterns/` 全局模式库。

### 触发时机

| 时机 | 触发方式 |
|------|---------|
| 沉淀模式步骤 5.5 | 沉淀时 AI 自动比对：本次沉淀的 `_patterns/` 或 `pitfalls.md` 中的通用模式，是否在其他项目也存在 |
| 检索模式步骤 1 | 检索当前项目知识时，同步扫描 `_global/_patterns/` 推荐全局模式 |
| `dev:kb health --all` | 全局健康检查时，扫描所有项目的 `_patterns/` 和 `pitfalls.md`，识别重复模式 |
| 用户主动 | `dev:kb promote <pattern>` 手动提升指定模式 |

### 识别规则

AI 在沉淀模式的跨模块检查（步骤 5）后，额外执行跨项目检查（步骤 5.5）：

1. 提取本次沉淀中的**通用技术模式**关键词（如"轮询"、"灰度"、"权限继承"、"Token 过期处理"、"双层 data 嵌套"）
2. 在 `~/.codebuddy/knowledge/` 下**其他项目**的 `_patterns/`、`pitfalls.md`、`logic.md` 中搜索相同关键词
3. 发现 ≥2 个项目包含**同类模式**时，输出提升建议

### 提升流程

1. **AI 输出提升建议**：

```text
🌐 发现跨项目通用模式：
├── 模式：Token 过期处理（error_code 判断 → 触发重新登录）
├── 出现项目：my-sdk-tool（pitfalls.md）、my-project（logic.md）
└── 建议：提升为全局模式 _global/_patterns/token-expiry-handling.md
```

1. **用户确认**（交互式）：

| 选项 | 说明 |
|------|------|
| ✅ 提升为全局模式 | 创建 `_global/_patterns/{name}.md`，原项目中添加引用链接 |
| ✏️ 修改后提升 | 先编辑内容再提升 |
| ⏭️ 跳过 | 不提升，保留在各项目中 |

1. **写入全局模式文件**：

```markdown
---
confidence: verified
stability:
  last_verified: "YYYY-MM-DD"
  drift_count: 0
  confidence_score: 85
release:
  released: false
  verified_in_production: false
created: YYYY-MM-DD
source_projects: [project-a, project-b]
applies_to: [project-a/{module}, project-b/{module}]
---

# {模式名称}

> 全局模式：已在 {N} 个项目中出现。从 {project-a} 和 {project-b} 提取合并。

## 模式描述
{合并两个项目的知识，取并集}

## 各项目实现差异
| 维度 | {project-a} | {project-b} |
|------|------------|------------|
| {差异点} | {实现方式} | {实现方式} |

## 通用注意事项
{从各项目 pitfalls 中提取的通用注意事项}
```

1. **原项目中添加引用**：

在原项目的对应文件（`_patterns/` 或 `pitfalls.md`）中追加：

```markdown
> 📌 此模式已提升为全局模式，详见 [_global/_patterns/{name}.md](../../_global/_patterns/{name}.md)
```

1. **原文不删除**（保留项目级的具体实现细节）

### 全局模式的检索

检索模式步骤 1 中，除了读取当前项目知识外，还应：

1. `ls ~/.codebuddy/knowledge/_global/_patterns/ 2>/dev/null` 检查全局模式是否存在
2. 存在时，扫描全局模式的 `applies_to` 字段，如果包含当前项目 → 自动加载
3. 不包含当前项目但关键词匹配需求 → 作为建议推荐（不自动加载）

## 跨仓库双向链接维护

> 当参数/字段/标识符跨越多个仓库传递时（如 `c_app_version` 从 B 仓库 `my-log-component` 发起，经 A 仓库 `my-record` 的 `request.ts` → `http.js` 两层处理），两个仓库的知识库必须建立双向链接，确保从任意一侧都能完整追溯整个链路。

### 核心原则

1. **双向必达**：如果 A 的知识引用了 B，B 的知识也必须反向引用 A（链路中的每一对相邻仓库都要双向链接）
2. **绝对路径**：跨仓库引用统一使用 `~/.codebuddy/knowledge/{project-name}/{module}/` 绝对路径（IDE 内可直接点击跳转）
3. **参数即入口**：以跨仓库传递的**参数名**作为链接锚点（同参数在不同仓库的描述可串联为完整链路）
4. **链路不可断**：修改链路中任一仓库的知识时，必须检查相邻仓库的引用是否仍然有效

### 维护场景

| 场景 | 触发条件 | 操作 |
|------|---------|------|
| **首次沉淀** | 步骤 5.6 识别到跨仓库参数链路 | 按 deposit.md §5.6 完整流程建立双向链接 |
| **单侧更新** | 修改了链路中某一仓库的知识内容 | 检查对侧仓库的引用是否正确 → 若不正确则同步更新 |
| **仓库重命名** | knowledge 下的项目名变更（如 `my-record` → `my-record-v2`） | 批量替换所有引用该仓库的绝对路径 |
| **链路扩展** | 参数链路新增中间仓库（A→B→C 变为 A→B→C→D） | 为新相邻对（C↔D）建立双向链接；A、B 的链接无需调整 |
| **知识归档** | 某仓库知识标记为 deprecated | 在对侧仓库引用处追加"⚠️ 对方知识已归档"标注，不删除链接 |
| **dev:kb health** | 全局健康检查 | 扫描所有 `_index.md` 的「跨仓库知识」章节，检查引用路径是否可达 |

### 单向调用场景的特殊处理

当只有 A 调用 B（B 被动接收参数，不感知 A 的存在）：

- A 侧：必须引用 B 的消费逻辑（含完整链路图）
- B 侧：可选引用 A 的发起逻辑。若 B 被 ≥2 个仓库调用，建议在 `pitfalls.md` 中记录"被哪些仓库调用"清单而非逐一反向链接

```markdown
<!-- B 侧 pitfalls.md（被多个仓库调用时） -->
### {参数名} 被以下仓库调用
| 调用方 | 用途 |
|--------|------|
| my-log-component | 通过 makePostPromise 传入客户端版本号 |
| （其他调用方） | ... |
```

### 健康度检查规则

`dev:kb health` 全局扫描时，AI 对「跨仓库知识」须执行以下检查（纯 LLM 规则，不依赖脚本）：

| 检查项 | 规则 | 严重度 |
|--------|------|:-----:|
| 双向引用完整性 | 若 A 的 `_index.md` §跨仓库知识 引用了 B，B 的 `_index.md` 也必须引用 A | 🟡 WARN |
| 引用路径可达性 | 所有跨仓库引用路径 `~/.codebuddy/knowledge/{project}/` 指向的目录是否存在（`ls` 验证） | 🔴 ERROR |
| 章节锚点有效性 | 引用路径中 §{章节} 指向的锚点在目标文件中是否存在（`grep` 验证） | 🟡 WARN |
