# 检索模式（Retrieve Mode）

> 由 dev-flow 步骤 1（研究定位）和步骤 5（编码）自动调用。只读操作，不修改 knowledge/ 内容。

## 步骤 1：研究定位时（自动执行）

### 执行流程

1. 从工作上下文 `## 需求 > 项目` 提取项目路径，映射为 knowledge/ 下的目录名
2. `ls ~/.codebuddy/knowledge/{project-name}/ 2>/dev/null` 检查是否存在
3. **存在时**：
   - 读取 `_index.md`（**必读**，获取模块清单、概念索引、接口索引）
   - 按需求关键词匹配相关模块 → **默认加载白名单**：同时读取该模块的 `_overview.md` 和 `design-intent.md`（若存在）
   - 检测到跨模块模式关键词 → 读取 `_patterns/*.md`
   - 在相关文件表格中标注「来源：knowledge/」
4. **不存在时**：跳过，正常执行步骤 1 后续研究
5. **全局模式检索**（自动）：
   - `ls ~/.codebuddy/knowledge/_global/_patterns/ 2>/dev/null` 检查全局模式
   - 存在时，扫描全局模式文件的 `applies_to` frontmatter：
     - 包含当前项目 → 自动加载（与项目知识一起输出）
     - 不包含但关键词匹配需求 → 追加推荐提示（不自动加载）：

       ```
       💡 全局知识推荐：_global/_patterns/{name}.md 可能与当前需求相关（来源项目：{projects}）
       ```

> 📌 **默认加载白名单**：每个模块下 `_overview.md` 与 `design-intent.md` 视为同级入口文件，命中模块即一并加载。`design-intent.md` 由 P3 类远程知识反哺产生（详见 `modes/deposit.md` § design-intent.md 写入规则），用于在步骤 1 多源仲裁中提供「设计意图」视角的参考，**不与代码事实主题（api/logic/data-model/ui/pitfalls）混用**。
> 🔒 **加载阀门**：`design-intent.md` 单文件硬上限 200 行，超限时由沉淀流程自动归档压缩，保证默认加载体积可控。

### 优先展示规则

加载知识时，按新排序策略展示：`verified`（跨分支可信，最高） > `pending`（仅当前分支 == `created_branch` 时参与排序）> `scanned` > `draft`；`stale` 不采纳。同级别内按 `stability.confidence_score` 倒序；`release.verified_in_production: true` 的条目在同分优先展示。
带 `[线上验证]` 标签的 pitfalls 条目始终优先展示（置信度最高的实战经验）。

### 代码漂移快检（检索时自动执行）

读取 `_overview.md` 中的核心文件列表，对每个文件比较 git 最后修改时间 vs `stability.last_verified`：

- 文件修改时间 > stability.last_verified → 标记 ⚠️ 可能漂移（置信度降级 stale + drift_count+1）
- 发现不一致 → 输出提醒（不阻塞流程，仅警告）

> 只做时间戳比较，不做全文 diff，控制性能。
> 完整漂移检测规则 → `read_file("references/confidence.md")`

### sync 滞后检测（检索时自动执行，新需求开工前提示）

> **设计意图**：用户跑 `git pull` 后若忘记 `dev:kb sync`，本地知识库就可能漂移而不自知。本检测在「项目知识检索」时**主动一次性**判定是否值得提醒用户先跑 sync，避免漂移知识被新需求复用。

#### 触发条件（满足任一即提示）

| # | 检测项 | 命令 / 数据来源 | 阈值 |
|---|--------|----------------|------|
| 1 | `last_synced_sha` 与远端 base 已偏离 | `git rev-parse origin/{base_branch}` vs `_index.md.last_synced_sha` | sha 不同 **且** `git rev-list --count ${last_synced_sha}..origin/{base_branch} -- --first-parent` ≥ 1 |
| 2 | `last_synced_sha` 长期未刷新 | `_index.md.last_synced_at` | 距今 ≥ 7 天 |
| 3 | 从未跑过 sync 但已有沉淀 | `_index.md.last_synced_sha == ""` 且存在任意 `confidence: verified` 条目 | 直接命中 |

> ⚠️ 仅当 `git rev-parse --is-inside-work-tree` 为 true 时执行；否则跳过本检测。
> 💡 `base_branch` 取自 `_index.md.base_branch`，缺省为 `master`（与 `manage.md` § sync 阶段 0 保持一致）。
> 🚫 **静默条件**：当前会话已跑过 `dev:kb sync` / 提示过 sync 建议 / 用户在本会话内显式拒绝过 → 本检测沉默，避免重复打扰。

#### 输出格式（不阻塞流程，提示一次即止）

命中触发条件时，在「📚 项目知识」区块末尾追加**一行**轻量提示：

```text
💡 检测到自上次 sync 后远端 {base_branch} 已有 {N} 个 commit 进入（last_synced_sha: abc1234，{M} 天前）。
   建议在新需求开工前跑一次 `dev:kb sync` 对齐知识库（约 5-15s），避免引用过期 verified 知识。
```

或（场景 3，从未 sync）：

```text
💡 当前项目知识库尚未跑过 sync，已有 {K} 条 verified 知识可能与最新 master 存在偏差。
   首次开工建议跑 `dev:kb sync` 建立基线（或 `dev:kb scan --all` 全量重扫）。
```

> 📌 **只提醒不强制**：用户可继续当前需求；漂移快检（上一节）会兜底降级 verified→stale，确保不会引用过期知识。
> 📌 **与 dev-flow 的关系**：dev-flow 步骤 1 §0.a 调用本模块时，本检测的输出会随「📚 项目知识」一同呈现，用户可选择立即跑 sync 或继续。详细交互引用见 `dev-flow/steps/step-1-research.md` §0.a。

### 输出

```
📚 项目知识：已加载 {N} 个知识文件（{列表}）
   ⚠️ {module}/_overview.md 可能存在代码漂移（stability.last_verified: 2026-03-15，代码最后修改: 2026-04-10）
```

或：

```
📚 项目知识：未找到项目知识（首次开发将在沉淀时创建）
```

---

## 步骤 5：编码时（按需加载 — 章节级粒度）

根据当前改动的文件类型动态加载对应主题知识。**优先加载匹配章节而非整个文件**，优化 token 效率：

### 加载策略

| 改动类型 | 自动加载 |
|---------|---------|
| 改动 `*.tsx` / `*.jsx` | `ui.md` + `logic.md` |
| 改动 WebAPI / 接口文件 | `api.md` |
| 改动 constant / types | `data-model.md` |
| 涉及灰度配置 | `_patterns/gray-control.md` |
| 新增配置项 | `_recipes/add-setting-item.md` |
| **跨模块协议 / 架构层改动**（涉及通信协议、组件契约、生命周期编排） | `design-intent.md`（如存在）|
| **设计意图问询场景**（用户问「为什么这么设计」「初始考虑」类问题） | `design-intent.md`（如存在）|

> 📌 步骤 1 默认加载已包含 `design-intent.md`；步骤 5 仅在「跨模块协议改动 / 设计意图问询」时按需追加加载，避免普通编码场景额外消耗 token。

### 章节级精准加载（优化 token）

当主题文件较大（>100 行）时，不加载全文，而是**按章节匹配**：

1. 先读取文件的**标题结构**（仅 `##` 级别标题行），获取章节索引
2. 按当前改动的**函数名/组件名/接口名**匹配相关章节标题
3. 仅加载匹配的章节内容（包含标题行到下一个同级标题行之间的内容）
4. 未匹配到具体章节时，回退为加载全文

**示例**：改动了 `handleMeetingSwitchSetting` 函数

- 读取 `logic.md` 标题结构 → 发现 `### handleMeetingSwitchSetting(name, isOpen, type?)` 章节
- 仅加载该章节（~20 行），而非整个 `logic.md`（~70 行）

> 主题文件 ≤100 行时直接全文加载（章节匹配的开销反而更大）。
> 仅在 `_index.md` 已在上下文中时执行增量加载，避免重复读取。

---

## 项目名称映射

取自项目目录名关键词，与工作上下文的项目缩写保持一致。首次创建时 AI 推断，用户可纠正。
完整映射规则 → `read_file("references/schema.md")`

---

## 执行完毕

检索完毕后，自动返回调用方（dev-flow 步骤 1 / 步骤 5）继续后续流程。
