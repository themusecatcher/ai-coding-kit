# 管理模式（Manage Mode）

> 由 `dev:kb` 系列命令或用户主动操作触发。提供知识库的查看、扫描、搜索、健康检查、验证和可视化能力。

## 命令速查

| 命令 | 快捷 | 说明 |
|------|------|------|
| `dev:kb` | `dev:k` | 查看当前项目知识库概览 |
| `dev:kb scan [module|--all|--diff]` | — | 扫描代码提取知识（指定模块/全量/增量） |
| `dev:kb sync` | `dev:k sy` | `git pull` 后对齐知识库（双场景：他人改动漂移检测 + 自己 pending 升级 verified） |
| `dev:kb search <query>` | `dev:k s` | 搜索知识库（支持语义扩展） |
| `dev:kb health` | `dev:k h` | 健康度检查（覆盖度 + 充实度 + 新鲜度） |
| `dev:kb verify [module]` | `dev:k v` | 验证知识与代码一致性 |
| `dev:kb audit [--all|--archived|--reject <id>|--confirm <id>]` | `dev:k a` | 审计多源仲裁产生的 auto-verified / auto-stale 条目（默认仅展 auto-stale） |
| `dev:kb dashboard` | `dev:k d` | 生成知识地图 HTML |
| `dev:kb export --format=xxx` | `dev:k e xxx` | 导出知识库（claude-md/cursor-rules/mcp-resources/markdown） |
| `dev:kb promote <pattern>` | — | 手动提升模式为全局知识 |

---

## dev:kb（查看概览）

> **前置检查（所有命令共用）**：先确定项目名称，然后 `ls ~/.codebuddy/knowledge/{project-name}/ 2>/dev/null` 检查是否存在。不存在时：`scan` 命令 → 正常执行（首次扫描会自动创建目录）；其他命令 → 输出「📚 项目知识库尚未创建。使用 `dev:kb scan` 主动扫描代码提取知识，或等首次开发完成自动沉淀。」→ 结束。

### 执行流程

1. 确定当前项目名称（从最近的工作上下文或项目目录推断）
2. `ls ~/.codebuddy/knowledge/{project-name}/` 列出已有知识
3. 展示知识清单（模块名+覆盖主题+置信度+最后验证日期）
4. 弹出交互式选项：

| 选项 | 说明 |
|------|------|
| 📖 查看模块 | 选择一个模块查看详细知识 |
| 🔍 扫描代码 | 主动扫描代码提取知识（→ dev:kb scan） |
| 🏥 检查健康度 | 查看知识健康状况（→ dev:kb health） |
| 🔎 搜索 | 搜索知识库（→ dev:kb search） |
| 🕵️ 审计自动升级 | 查看 auto-verified / auto-stale 条目详情，可 reject / confirm（→ dev:kb audit） |
| ↩️ 返回 | 退出知识库管理 |

---

## dev:kb scan [module|--all]（扫描代码提取知识）

### 扫描模式

| 参数 | 模式 | 说明 |
|------|------|------|
| `dev:kb scan <module>` | 单模块扫描 | 扫描指定模块的核心文件，提取/更新知识 |
| `dev:kb scan --all` | 全量扫描 | 自动识别项目所有模块，逐一扫描 |
| `dev:kb scan --diff` | 增量扫描 | 仅扫描上次扫描后有 git 变更的文件 |

---

### 智能评估（扫描前必做）

扫描开始前，AI 自动评估项目/模块规模，确定最优扫描策略：

#### 评估流程

1. 统计目标范围的文件数和总行数（`find + wc -l`）
2. 按阈值自动选择扫描深度和分段策略：

| 指标 | 轻量级 | 中等规模 | 大型 |
|------|--------|---------|------|
| 模块文件数 | ≤10 | 11~30 | >30 |
| 模块总行数 | ≤2000 | 2001~8000 | >8000 |
| 单文件行数 | ≤500 | 501~2000 | >2000 |

#### 评估结果 → 扫描策略映射

| 评估结果 | 扫描深度 | 分段策略 | 说明 |
|---------|---------|---------|------|
| 轻量级模块 | L2 摘要（默认） | 一次性全文件读取 | 直接读取所有核心文件，一次提取 |
| 中等规模模块 | L2 摘要 | 逐文件处理 | 每个核心文件独立读取+提取，不跨文件累积上下文 |
| 大型模块 | L1 骨架 → L2 摘要 → L3 按需深入 | 分段处理 | 先骨架定结构，再逐主题按需深入 |
| 超大单文件（>2000 行） | 分段深入 | 按函数分批 | 先提取函数签名列表，再按功能分批读取 |

1. 向用户展示评估结果：

```text
📊 模块规模评估：meeting-setting
├── 核心文件：5 个，总计 ~6200 行
├── 最大文件：MeetingSetting/index.tsx（4100 行）
├── 评估结果：大型模块
└── 推荐策略：L1骨架→L2摘要→L3按需深入，超大文件分段处理
```

| 选项 | 说明 |
|------|------|
| ✅ 按推荐策略执行 | 使用 AI 推荐的扫描策略 |
| ⬆️ 提升深度 | 全部用 L3 深度扫描（更完整但更慢） |
| ⬇️ 降低深度 | 仅做 L1 骨架扫描（更快但只有概述） |

---

### 三级扫描深度

#### L1 骨架扫描（秒级）

**读取范围**：仅 `export`/`function`/`class`/`interface`/`type`/`const` 声明行（不读取函数体）

**提取方式**：`grep -n "^export\|^function\|^class\|^interface\|^type\|^const" {file}`

**产出**：

- `_overview.md`：模块功能描述 + 核心文件列表 + 技术栈推断
- `_index.md`：模块清单更新

**适用**：首次全量扫描的模块识别阶段、快速建立项目结构概览

#### L2 摘要扫描（分钟级，默认）

**读取范围**：函数签名 + 参数类型 + 返回类型 + TypeScript 接口/类型定义 + 常量映射表

**提取方式**：对每个核心文件，使用 code-explorer Agent 提取公共 API 表面

**产出**：

- `api.md`：接口路径 + 参数 + 返回值 + 错误码
- `data-model.md`：TypeScript 接口 + State 结构 + Props 定义 + 常量枚举

**适用**：默认扫描级别，平衡完整性和效率

#### L3 深度扫描（较慢，按需）

**读取范围**：完整函数体 + JSX 渲染逻辑 + 条件分支 + 注释

**产出**：

- `logic.md`：初始化流程 + 分支逻辑 + 函数行为 + 联动规则
- `ui.md`：组件树结构 + 渲染条件 + Props 使用方式
- `pitfalls.md`：代码中的 TODO/FIXME/HACK 注释 + 复杂条件分支 + 隐式依赖

**适用**：指定模块深入扫描、需要完整知识的场景

---

### 大文件分段策略

当单个文件超过阈值时，按语义边界分段处理，避免上下文溢出：

#### 分段规则

| 文件规模 | 策略 | 说明 |
|---------|------|------|
| ≤500 行 | 一次性读取 | 直接全文读取，一次提取知识 |
| 501~2000 行 | 按区块读取 | 将文件按空行/注释分隔的逻辑区块分段，每段 ≤500 行 |
| >2000 行 | 签名优先+分批深入 | 先提取函数/方法签名列表，再按功能分批读取 |

#### 超大文件处理流程（>2000 行）

1. **骨架提取**：读取文件的 class 定义 + 所有方法签名 + state/props 类型（~200 行摘要）
2. **功能分组**：将方法按功能分组（初始化/数据获取/事件处理/渲染/工具函数）
3. **分批读取**：每批 5~8 个相关方法，按行号范围读取（`read_file` 指定 offset+limit）
4. **逐批提取**：每批独立提取知识，**立即追加写入**对应主题文件
5. **关联检查**：所有批次完成后，仅读取摘要做一次跨批次关联性检查（如函数 A 调用了函数 B）

> 分批之间不保留完整上下文（仅保留骨架摘要），大幅降低 token 消耗。
> 每批写入后即持久化，中断不丢失已提取内容。

---

### 单模块扫描完整流程

1. **智能评估**（见上方）→ 确定扫描深度和分段策略
2. **L1 骨架扫描**：提取文件结构 + export 签名 → 写入/更新 `_overview.md`
3. **L2 摘要扫描**：逐文件提取类型定义 + 接口签名 → 写入 `api.md` + `data-model.md`
4. **L3 深度扫描**（仅大型模块或用户要求时）：逐文件/分段提取逻辑 → 写入 `logic.md` + `ui.md` + `pitfalls.md`
5. **增量合并**（见下方合并策略）：新旧知识按置信度规则合并
6. 向用户展示合并结果摘要，用户确认后写入
7. 更新 `_overview.md` 变更历史 + 刷新 `last_scanned`

> 每个主题文件独立产出并写入，不等模块全部扫描完。任何时刻中断，已写入的文件不丢失。

### 全量扫描完整流程（`--all`）

1. **模块自动识别**（按优先级依次尝试）：
   - 路由配置文件（如 `router.ts`/`routes.tsx`）→ 按路由拆分模块
   - `src/views/` 或 `src/pages/` 下的一级子目录 → 每个子目录 = 一个模块
   - `src/components/` 下的大型组件目录（>5 个文件）→ 每个 = 一个模块
   - 用户手动指定模块列表（上述均无法识别时）

2. **全局规模评估**：统计所有模块的文件数和行数，输出全局概览：

   ```text
   📊 项目全局评估：user-project
   ├── 识别到 5 个模块，共 87 个文件，~32000 行
   ├── 大型模块：meeting-setting（6200行）、account-setting（4500行）
   ├── 中等模块：member-manage（2800行）、role-permission（1500行）
   ├── 轻量模块：org-structure（800行）
   └── 预估扫描时间：~8 分钟（L2 摘要级）
   ```

3. **向用户确认**（交互式，必须等待）：

   | 选项 | 说明 |
   |------|------|
   | ✅ 确认开始扫描 | 按评估结果逐模块扫描 |
   | ✏️ 调整模块列表 | 增删/重命名模块 |
   | 🎯 选择部分模块 | 只扫描选中的模块 |
   | ⬆️ 全部深度扫描 | 所有模块用 L3 深度（更慢但更完整） |

4. **逐模块执行**（带进度显示）：

   ```
   📚 全量扫描进度：[██████░░░░] 3/5 模块
   ├── meeting-setting   ✅ L1+L2+L3（6 个文件已写入）
   ├── account-setting   ✅ L1+L2（4 个文件已写入）
   ├── member-manage     ⏳ L2 扫描中（api.md）
   ├── role-permission   ⏸️ 待扫描
   └── org-structure     ⏸️ 待扫描
   ```

   - 每个模块按智能评估推荐的深度执行
   - 每个主题文件完成后即写入（不等全部完成）
   - 中断后可重新执行，已扫描模块自动跳过（对比 `last_scanned`）

5. **废弃检测**：识别到的模块列表 vs 已有知识库模块列表，差集中的模块提示用户确认是否标记 `deprecated`（详见合并策略场景 D）

6. **更新 _index.md**：所有模块扫描完成后，更新项目索引

### 增量扫描流程（`--diff`）

#### Git 范围选择策略（按优先级自动选择）

**核心原则**：精确识别「上次扫描/同步到现在」之间的所有变更，不多不少。**与 `dev:kb sync` 阶段 1 共享同一套算法（以 sync 为权威源）**。

| 优先级 | 触发条件 | Git 范围 | 适用场景 |
|--------|---------|---------|---------|
| 1 | `_index.md.last_synced_sha` 存在且仍可达 | `${last_synced_sha}..HEAD` | 之前跑过 sync，最准确 |
| 2 | `_index.md.last_scanned_sha` 存在且仍可达 | `${last_scanned_sha}..HEAD` | 之前跑过 scan，跨多次 pull 也准确 |
| 3 | reflog 中最近一次 pull/merge/rebase 事件的上游 sha | `${reflog_upstream}..HEAD` | 刚 pull 完的可靠信号（替代 ORIG_HEAD） |
| 4 | 在 `base_branch` 上且 `merge-base origin/{base_branch} HEAD` 可用 | `${merge_base}..HEAD` | 后退选项 |
| 5 | 用户显式 `--since=7d` / `--commits=N` | 对应范围 | 手动覆盖 |
| 6（兜底） | 以上均无 | `HEAD~10..HEAD` **+ `--first-parent`** | 首次使用 + 提示「建议先跑 `scan --all` 建立基线」 |

> ⚠️ **重要修正**（与 sync 阶段 1 同步）：
>
> 1. 原 `ORIG_HEAD` 位阶被下调：`git checkout` 后 ORIG_HEAD 会被覆盖为老值，不可作为独立优先级。改用 reflog 最近一次 pull/merge 记录作为优先级 3。
> 2. 所有 `git log` / `git diff` 调用都必须加 `--first-parent`，否则 `HEAD~10..HEAD` 在 merge-heavy 仓库中会返回几百个 commit（实测验证）。

#### 执行步骤

1. 按上表选择 git 范围，运行 `git diff --name-only --first-parent --diff-filter=ACMRD ${range}` 获取变更文件列表
2. 将变更文件路径映射到已有模块（匹配每个模块 `_overview.md` 的核心文件列表 / 路径前缀）
3. 仅对有变更的模块执行单模块扫描（含智能评估 + 增量合并）
4. 新文件不属于任何已知模块 → 提示用户是否创建新模块
5. 扫描完成后将 `git rev-parse HEAD` 的 sha 写入 `_index.md.last_scanned_sha`（以及本次实际扫描的模块 `_overview.md.last_scanned_sha`）

---

### 增量合并策略

> 核心原则：**高置信度知识不被低置信度扫描覆盖**。扫描是辅助手段，人工验证的知识始终优先。

扫描对比分为 4 个场景，每个场景按已有知识的置信度分层处理：

#### 场景 A：内容一致（扫描结果与已有知识无实质差异）

| 已有置信度 | 处理 |
|-----------|------|
| 任何级别 | 仅刷新 `stability.last_verified` 和 `last_scanned` 为当前日期，内容和置信度不变 |

> 判断标准：核心信息点（接口路径、参数名、类型定义、关键逻辑）无差异，措辞不同不算差异。

#### 场景 B：内容变更（扫描发现已有知识与代码不一致）

| 已有置信度 | 处理 | 理由 |
|-----------|------|------|
| `scanned` | **直接更新**内容，保持 `scanned`，刷新日期 | 同为机器产出，新扫描更准确 |
| `draft` | **直接更新**内容，设为 `scanned`，刷新日期 | 草稿级，新扫描更可靠 |
| `stale` | **直接更新**内容，设为 `scanned`，刷新日期 | 已过期知识，用新扫描替代 |
| `verified` | **不覆盖**。输出差异报告，弹出交互式选项让用户决策 | 经人工验证的知识不能被机器覆盖 |
| `pending` | **不覆盖**。若当前分支 == `created_branch` 视同 verified 交互处理；否则跳过该文件（跨分支不扫描） | feature 分支沉淀的本地知识，扫描需尊重分支归属 |

**verified 冲突处理选项**：

```text
⚠️ 扫描发现 {module}/{topic}.md 与代码存在差异（当前置信度: verified）：
```

| 选项 | 说明 | 结果 |
|------|------|------|
| 📥 采纳扫描结果 | 用扫描内容替换，置信度降为 `scanned` | 等待下次需求开发时升级回 `verified` |
| 🔒 保留原知识 | 内容不变，刷新 `stability.last_verified` 标记已审阅 | 视为人工确认 |
| ✏️ 手动合并 | AI 展示新旧 diff，用户编辑 | 合并后保持 `verified` |
| ⏭️ 跳过此文件 | 本次不处理 | 不刷新 `stability.last_verified` |

#### 场景 C：新增内容（扫描发现代码中有新知识，但已有文件未记录）

| 情况 | 处理 |
|------|------|
| 已有主题文件，但缺少新内容 | 在文件末尾**追加**新内容段落，标记 `[scanned]` |
| 主题文件不存在 | 创建新文件，置信度 `scanned` |
| 整个模块不存在 | 创建模块目录 + `_overview.md` + 主题文件，全部 `scanned` |

**追加新内容的标记格式**：

```markdown
## {新增章节标题}

> [scanned YYYY-MM-DD] 以下内容由代码扫描自动提取，建议在下次需求开发时验证。

{扫描提取的内容}
```

#### 场景 D：内容废弃（已有知识对应的代码已被删除）

| 检测方式 | 处理 |
|---------|------|
| 全量扫描：已有模块在代码中无对应目录/路由 | 弹出确认 → 用户确认废弃 → 走废弃流程（`lifecycle.md`） |
| 单模块扫描：`_overview.md` 中的核心文件已不存在 | 提示用户确认，选项：标记废弃 / 更新核心文件列表 / 忽略 |
| 增量扫描（`--diff`）：检测到文件删除 | 标记对应主题为疑似废弃，提示用户确认 |

> ❌ 禁止自动标记 `deprecated`，必须用户确认（防止误判：代码可能被重构到新路径而非删除）。

#### 合并后的 frontmatter 更新规则

| 字段 | 更新规则 |
|------|---------|
| `confidence` | 按上述场景表决定 |
| `stability.last_verified` | 除「跳过此文件」外，一律更新为当前日期 |
| `last_scanned` | 每次扫描写入当前日期，用于中断恢复和跳过判断 |

---

### 扫描中断恢复机制

| 机制 | 说明 |
|------|------|
| 判断依据 | 对比每个模块 `_overview.md` 的 `last_scanned` 与本次扫描启动时间 |
| `last_scanned` ≥ 扫描启动时间 | 跳过（本轮已扫描） |
| `last_scanned` < 扫描启动时间 | 需要扫描 |
| 无 `last_scanned` 字段 | 从未扫描过，需要扫描 |

> 扫描提取的知识置信度为 `scanned`（低于 `verified`），加载时会提示"自动提取，建议验证"。
> 后续需求开发中实际接触到这些模块时，沉淀模式会自动将 `scanned` 升级为 `verified`（详见 deposit.md 步骤 4.5 置信度升级机制）。

---

## dev:kb search <query>（搜索知识库）

### 执行流程

1. **查询词扩展**（语义搜索增强）：
   - AI 先将用户的自然语言查询扩展为多组关键词
   - 示例：用户搜索 "如何处理灰度判断" → 扩展为 `["灰度", "gray", "grayCalcOut", "queryAbilityConfig", "enable", "灰度中心", "能力中心"]`
   - 示例：用户搜索 "接口报错处理" → 扩展为 `["error", "catch", "error_code", "错误码", "异常", "try", "dealReconnect"]`

2. **多策略搜索**（并行执行，合并结果）：
   - **关键词搜索**：在 `~/.codebuddy/knowledge/{project-name}/` 下全文 grep 扩展后的关键词
   - **概念索引搜索**：在 `_index.md` 的「概念索引」和「接口索引」表格中匹配
   - **标题结构搜索**：在所有知识文件的 `##` 标题中匹配

3. **结果排序**（按匹配质量）：
   - `verified` 文件中的匹配 > `pending`（仅当前分支） > `scanned`；`release.verified_in_production=true` 同分优先
   - 标题匹配 > 概念索引匹配 > 正文匹配
   - 多个关键词同时命中 > 单关键词命中

4. **输出格式**：

   ```
   🔍 搜索 "灰度判断" → 扩展关键词：灰度, gray, grayCalcOut, queryAbilityConfig
   
   1. user-project/_patterns/gray-control.md (verified) — 标题匹配
      └── 灰度控制机制：能力中心 vs 灰度中心两种灰度平台对比
   2. user-project/meeting-setting/api.md (verified) — 正文匹配
      └── queryAbilityConfig：能力中心灰度查询接口
   3. user-project/meeting-setting/pitfalls.md (verified) — 正文匹配
      └── 两种灰度平台不能混用
   ```

5. **跨项目搜索**（可选）：加 `--all` 参数搜索所有项目

---

## dev:kb sync（git pull 后对齐知识库）

> **定位**：`git pull` 后专用的一键对齐命令。处理两类场景：
>
> - **场景 A**：他人代码已合入 master，我拉下来 → 检测漂移、降级 stale、增量重扫（**最常见**，每次开新需求前都该跑）
> - **场景 B**：我自己的 feature 分支被 MR 合入 master 后拉回来 → 把我之前在 feature 分支沉淀的 `pending` 知识自动升级为 `verified`
>
> 两个场景在一次 sync 调用中**同时处理**，互不冲突。

### 触发场景

| 用户操作时机 | 主导场景 | sync 解决的问题 |
|------------|---------|----------------|
| 开始新需求前在 master 上 `git pull`（每天/每次最常见） | **场景 A**：他人改动漂移 | 我的 `verified` 知识被同事改掉了 → 检测到 → 降 `stale` / 增量重扫 |
| feature MR 合入 master 后切回 master 拉取 | **场景 A + B 并存** | 既要升级自己的 pending，也要处理他人的并发改动 |
| 长时间没拉代码（≥1 周）后再次 pull | **场景 A 大爆发** | 大量 verified 可能被改，必须批量重扫 |
| 切换项目/分支后想确认知识库当前状态 | 漂移检测 | 确认所有 verified 知识仍与代码一致 |

> ❌ **不适用场景**：feature 分支开发过程中（应使用 `dev:kb scan <module>` 局部扫描；feature 分支上的 sync 仅做漂移检测，不升级 pending）。

### 执行流程

#### 阶段 0：前置检查

1. **分支检查**：
   - 在 `base_branch`（默认 master）上 → 全功能运行（场景 A + B）
   - 在 feature 分支上 → 弹出确认，默认仅跑场景 A（漂移检测）并**跳过场景 B**（防止将未合入的 pending 误判为已合入）
   - 在 detached HEAD → 阻断运行（提示先 `git checkout {base_branch}`）
2. **工作区清洁度检查**：运行 `git status --porcelain`
   - 完全干净 → 直接继续
   - 有未提交改动 → 弹出警告交互：
     - 选项 1：先 stash 后继续（推荐，避免漂移检测误判为他人改动）
     - 选项 2：忽略未提交改动并继续（漂移检测仅依赖 commit 历史，不读取 working tree）
     - 选项 3：中止
3. **项目知识库检查**：`~/.codebuddy/knowledge/{project}/_index.md` 不存在 → 提示「先跑 `dev:kb scan --all` 建立基线」并终止

#### 阶段 1：确定 sync 范围（精确 Git 范围算法）

按以下优先级自动选择 git 范围（与 `scan --diff` 共享同一套算法，保证一致性）：

| 优先级 | 触发条件 | Git 范围 | 适用性 |
|--------|---------|---------|---------|
| 1 | `_index.md.last_synced_sha` 存在且仍可达 | `${last_synced_sha}..HEAD` | 最佳：跨多次 pull 仍精确 |
| 2 | `_index.md.last_scanned_sha` 存在且仍可达 | `${last_scanned_sha}..HEAD` | 首次 sync 前的备胎 |
| 3 | reflog 中最近一次 `pull` / `merge` / `rebase finished` 事件的上游 sha（在当前分支） | `${reflog_upstream}..HEAD` | **刚 pull 完的最可靠信号**。用于替代 ORIG_HEAD（ORIG_HEAD 在 checkout 后会 == HEAD，不可靠） |
| 4 | 在 `base_branch` 上且 `merge-base origin/{base_branch} HEAD` 可用 | `${merge_base}..HEAD` | 后退选项 |
| 5 | 用户显式 `--since=<value>` / `--commits=N` | 对应范围 | 手动覆盖 |
| 6（兜底） | 以上均无 | `HEAD~10..HEAD` **加 `--first-parent`** + 警告提示 | 仅首次干净仓库使用 |

> ⚠️ **关键纠正 (试运行验证发现)**：
>
> 1. **`ORIG_HEAD` 不可独立作为优先级**：`git checkout` 后 ORIG_HEAD 会被覆盖为老值，可能与 HEAD 相等，本项作为优先级 3 的备选检查之一（与 reflog 双拍）。
> 2. **所有 `git log` / `git diff` 调用都必须加 `--first-parent`**（阶段 2/4 均遵守）——否则在 merge-heavy 仓库中，`HEAD~10..HEAD` 会返回所有合入分支的几百个 commit（实测：HEAD~10 在大型仓库返回 185 个 commit。加 --first-parent 后返回 10 个）。
> 3. **reflog 查找逻辑**：`git reflog --pretty='%H %gs' | awk '/pull|merge|rebase finished/{getline; print $1; exit}'`——取事件后一条记录的 sha（即上游之前的 HEAD）。

输出范围确认：

```text
🔄 dev:kb sync 范围：abc1234..def5678 (--first-parent)
├── 基于：_index.md.last_synced_sha（上次 sync: 2026-05-09）
├── 涉及 commit：23 个（你的5 个 + 他人的 18 个）
├── 涉及文件：47 个（A:12 / M:31 / D:4）
└── 预估命中模块：4 个
```

#### 阶段 2：场景 A —— 他人改动漂移检测（核心）

> 目标：识别他人合入的代码是否让我已有的 `verified` 知识过期。

1. **过滤「我的 commit」**：同时检查 author email 和 committer email（rebase 后 author 不变但 committer 会变，必须两者都不是我才算「他人 commit」）：

   ```bash
   my_email="$(git config user.email)"
   git log --first-parent --pretty=format:'%H|%ae|%ce' ${range} \
     | awk -F'|' -v me="$my_email" '$2 != me && $3 != me {print $1}'
   ```

   > 💡 **验证发现 (P4)**：rebase / amend 场景下仅 author 不变，committer 可能变为我，单查 `%ae` 会误判；反之同理。
2. **变更文件 → 模块映射**（三级 fallback）：`git diff --name-only --first-parent --diff-filter=ACMRD ${range}` 过滤出他人改动的文件后，按优先级尝试映射到已有模块：

   | 优先级 | 映射策略 | 所需字段 | 说明 |
   |--------|---------|---------|------|
   | 1 | `_overview.md.code_anchors[].path` 前缀匹配 | code_anchors 存在 | 最准确。合 schema.md 设计。 |
   | 2 | `_overview.md` 「## 核心文件」表格内路径（取 `「```」` 包裹的项） | 有「## 核心文件」章节 | 兼容旧版 _overview.md。主动提示补充 code_anchors。 |

| 3 | 启发式路径匹配：`src/views/{module}/`、`src/pages/{module}/`、`src/{module}/`，模糊包含模块名 | 仅靠模块名称 | 最后 fallback，可能误包括同名子项。 |
   | 4 | 上述均未命中 | — | 加入「孤儿文件」列表，阶段 5 询问用户是否建新模块。 |

   > ⚠️ **验证发现 (B3-1)**：生产环境中现有 `_overview.md` 多数**不含** `code_anchors`，仅靠优先级 1 会完全失效。需依靠优先级 2/3 补位，同时在完成后交互式建议用户补全 code_anchors。

1. **逐文件漂移检测**：对与改动文件关联的主题文件（通过 `code_anchors` 反查），按置信度分层处理：

   | 现有置信度 | 文件是否被他人改动 | 处理 |
   |-----------|------------------|------|
   | `verified` | 是 | 降级为 `stale` + `drift_count += 1` + 加入「待重扫」列表 |
   | `verified` | 否 | 仅刷新 `stability.last_verified` |
   | `pending` | 是 | 警告（我的 pending 知识对应的代码被他人改了） + 加入「手动确认」列表，不自动降级 |
   | `scanned` / `draft` | 是 | 加入「待重扫」列表（后续阶段 4 会重扫） |
   | `stale` | 任意 | 已是 stale，仅刷新 `drift_count` |

2. **文件删除检测**：`--diff-filter=D` 列出的被删文件 → 对应主题标记「疑似废弃」（阶段 5 让用户确认，不自动 `deprecated`）。

#### 阶段 3：场景 B —— 自己 pending 知识升级 verified

> 目标：识别我之前在 feature 分支沉淀的 `pending` 知识，其对应的 feature 分支是否已被合入 base（所以可升级为 verified）。

> ⚠️ 仅在当前分支 == `base_branch`（如 master）时执行；feature 分支上执行时跳过本阶段。

1. **查找所有 pending 知识**：扫描 `~/.codebuddy/knowledge/{project}/` 下所有 frontmatter `confidence: pending` 的主题文件，提取其 `created_branch` 字段。
2. **逐条判定合入状态**（三重检测，防止 squash/rebase 误判）：

   | 检测顺序 | 检测逻辑 | 设计意图 |
   |---------|---------|---------|
   | 检测一：fast-forward 检测 | `git merge-base --is-ancestor ${created_branch_tip} HEAD` | 检测默认 merge（feature 原始 commit 仍存在于 master 历史中） |
   | 检测二：squash merge 检测 | 以 `created_branch` 的 tip commit 的**改动文件集**与 `${range}` 范围内他人 commit 的改动文件集做交集，交集 ≥ 80% 且 commit message 含 feature 分支名 / 任务平台 ID → 高度疑似 squash | squash merge 后 feature commit hash 不再存于 master，is-ancestor 会误判 false |
   | 检测三：rebase merge 检测 | 检查 `${range}` 内是否有 commit 的 commit message 与 `created_branch` tip commit 同文本 | rebase 后原 hash 丢失但 message 常保留 |

   ```bash
   # 检测一语法
   git merge-base --is-ancestor ${created_branch_tip_sha} HEAD

   # 检测一补充语法（计算两边独有 commit 数）
   git rev-list --left-right --count ${created_branch}...HEAD
   # 输出 "X\tY"：X=feature 独有 commit 数，Y=master 独有 commit 数
   ```

3. **升级表**：

   | feature 合入状态 | 处理 |
   |-----------------|------|
   | 完全合入（检测一 = true，X=0） | 升级为 `verified`，设置 `stability.days_since_merge=0`，`created_branch` 保留（历史追溯） |
   | squash/rebase 后误判（检测二或三 = true） | **交互确认后**升级为 `verified`（提示「检测到 squash/rebase 合入迹象」+ 列出依据，默认选中） |
   | 部分合入（检测一=false，X>0） | 保持 `pending`，提示「feature 还有 X 个 commit 未合入」 |
   | 分支已被删除但未合入（三检测均 false） | 保持 `pending` + 警告（可能是 rebase 后原分支被清理，建议手动确认） |
   | 分支不存在 | 保持 `pending` + 警告（可能是本地未 fetch，建议`git fetch origin && 重跑 sync`） |

4. **交互确认**：升级之前逐条列出并询问用户确认（默认全选）：

   ```text
   ✨ 检测到 3 条 pending 知识对应的 feature 分支已合入 master，建议升级为 verified：
   ☑ meeting-setting/api.md       （feature/vip-light-preload）
   ☑ account-setting/data-model.md（feature/account-export）  
   ☑ _patterns/gray-control.md    （feature/gray-refactor）
   ```

#### 阶段 4：增量重扫「待重扫」列表

1. 合并阶段 2 产生的「待重扫」模块列表，去重
2. 对每个模块调用「单模块扫描」逻辑（即 `dev:kb scan {module}` 的路径，**不是** `scan --diff`），走完整智能评估 + 增量合并策略（场景 A/B/C/D）
3. 重扫后，之前被降级为 `stale` 的主题文件会被智能合并策略处理（内容一致则恢复为原级别，不一致则按场景 B 表决策）

> 💡 「单模块扫描」 vs 「scan --diff」区别：sync 阶段 4 已经从阶段 2 拿到具体变更文件集，只需要「对指定模块走智能评估」逻辑，不需重复 git 范围推导。“与其他命令的关系”表中的「共享 git 范围算法」指的是阶段 1。

#### 阶段 5：输出 sync 报告 + 状态写回

1. **输出报告**：

   ```text
   🔄 dev:kb sync 报告（范围 abc1234..def5678，耗时 4.2s）

   ✨ pending 升级 verified（3项）
   ├── meeting-setting/api.md（feature/vip-light-preload）
   ├── account-setting/data-model.md
   └── _patterns/gray-control.md

   ⚠️ verified 降级为 stale（3项）
   ├── member-manage/logic.md — 他人改动于 commit a1b2c3d (@zhangsan)
   ├── role-permission/api.md — 他人改动于 commit e4f5g6h (@lisi)
   └── org-structure/data-model.md — 他人改动于 commit i7j8k9l (@wangwu)

   🔄 增量重扫后恢复（2项）
   ├── member-manage/logic.md → verified（内容一致，调整变量名）
   └── role-permission/api.md → verified（仅注释变动）

   ❓ 需人工决策（1项）
   └── org-structure/data-model.md — 接口参数变更，需手动合并

   ⚠️ 我的 pending 知识对应代码被他人改动（1项，详见下方独立列表）
   └── vip-light/api.md（详见「手动确认列表」）

   🗑️ 疑似废弃（1项）
   └── deprecated-feature/api.md — 源文件已删除，请确认是否标记为 deprecated

   下一步：处理 1 项需人工决策 + 1 项 pending 漂移 + 1 项疑似废弃
   ```

2. **状态写回**（详细实现与原子性保证，参考下方「写入原子性设计」）：
   - `_index.md.last_synced_sha = $(git rev-parse HEAD)`
   - `_index.md.last_synced_at = 当前 ISO 8601 时间`
   - `_index.md.last_updated = 当日日期`（与其他修改保持同步）
   - 每个实际扫描的模块 `_overview.md.last_scanned_sha` 同步更新
   - 被降级为 stale 的文件 `stability.drift_count += 1`

   **写入原子性设计**（重要，knowledge/ 不是 git 仓库，不能靠 git 兜底）：

   ```
   sync 开始前:
     → 打包备份: cp -r ~/.codebuddy/knowledge/{project}/ \
               ~/.codebuddy/.backup/sync-{YYYYMMDD-HHMMSS}/
   逐个文件写入时（阶段 4 / 阶段 5）:
     → 先写到 `{file}.tmp` → wc -l 验证非空 → mv -f {file}.tmp {file}
     → 任一步失败 → 从备份目录恢复受影响文件 → 中止 sync
   全部完成后:
     → 备份保留 7 天（供人工回滚）后自动清理
   ```

   > ⚠️ **验证发现 (B5-1)**：`~/.codebuddy/knowledge/` 默认不是 git 仓库，不能依靠 `git stash` / `git checkout` 回滚；必须采用文件级备份 + tmp 原子替换。

3. **手动确认列表**（阶段 2 产生的「pending 知识被他人改动」）：在报告中独立列出以免遗漏：

   ```text
   ⚠️ 我的 pending 知识对应代码被他人改动（1项）
   └── vip-light/api.md (created_branch=feature/vip-light-preload)
         —— 被 @zhangsan 于 commit a1b2c3d 修改了 src/views/vip/api.ts
         推荐动作：切回 feature 分支后重新检查并手动验证知识是否仍适用
   ```

4. **交互选项**（需人工决策项 > 0 时，AI 须调用 `ask_followup_question`，选项与下表逐条对应）：

   | 选项 | 说明 |
   |------|------|
   | 📝 逐项处理 | 进入交互式决策流程（复用增量合并策略场景 B 的 verified 冲突处理选项） |
   | ⏭️ 稍后处理 | 保持当前状态，下次 sync 仍会提醒 |
   | 🔍 查看完整报告 | 输出详细的差异报告供人工阅读 |

   > ⚠️ 交互一致性：表格行数 = `ask_followup_question` options 数组长度，严禁不一致。

5. **只读试运行模式（`--dry-run`）**：支持用户传入 `--dry-run` 参数，全部阶段正常走完但**跳过阶段 4 重扫与阶段 5 状态写回**，仅输出报告。适用于：
   - 首次使用前预览影响面
   - debug 范围选择是否准确

6. **自动重新生成度量仪表盘**：sync 完成后自动执行 `python3 ~/.codebuddy/skills/dev-flow/scripts/gen-dashboard.py --no-open`，刷新 `~/.codebuddy/.metrics/dashboard.html`，无需用户手动操作。仅汇报执行结果。

#### 与其他命令的关系

| 命令 | 关系 |
|------|------|
| `dev:kb scan --diff` | 与 sync 阶段 1 **共享 git 范围算法**（同一优先级表）；sync 阶段 4 调用的是「单模块扫描」而非 `--diff`（阶段 4 已拿到变更集） |
| `dev:kb verify` | sync 是「git pull 专用」，verify 是「批量验证」；sync = verify + scan --diff + pending 升级 |
| `dev:kb health` | sync 后推荐跑 health 查看最新状态分布 |
| dev-flow 步骤 7/10 沉淀 | feature 分支写入 pending；sync 负责合入后升级 verified，二者构成完整闭环 |

---

## dev:kb health（健康度检查）

### 执行流程

1. 遍历项目下所有模块
2. 输出每个模块的**知识覆盖度**（5 个主题文件的填充状态）：

   ```
   模块: my-record
   ├── _overview.md  ✅ verified (2026-04-10)
   ├── data-model.md ✅ verified (2026-04-08)
   ├── api.md        ✅ verified (2026-04-08)
   ├── logic.md      ⚠️ stale   (2026-03-15)
   ├── ui.md         ❌ 缺失
   └── pitfalls.md   ❌ 缺失
   覆盖度: 3/5 (60%)
   ```

3. 输出**置信度分布**（draft/scanned/pending/verified/stale 各多少个；auto-verified / auto-stale / archived 子状态单独统计；`release.released=true` / `verified_in_production=true` 的条目数单独统计）
4. 输出**过期预警**（两级）：
   - ⚠️ stability.last_verified > 60 天：提醒验证
   - 🔴 stability.last_verified > 120 天：警告可能过时
   - 💡 `release.verified_in_production: true` 的条目阈值放宽到 90/180 天（有生产验证证据时容错更高）

5. 输出**深度质量评估**（每个主题文件的内容充实度）：

#### 深度质量评估

对每个主题文件，AI 快速扫描内容并给出**定性评级**：

| 评级 | 含义 | 判断标准 |
|------|------|---------|
| 🟢 充实 | 日常开发可直接依赖 | 有具体代码示例/接口参数/类型定义，信息可直接复用 |
| 🟡 基础 | 有骨架但缺细节 | 有结构框架但缺少参数说明、错误码、边界条件等细节 |
| 🔴 薄弱 | 仅占位或信息极少 | 只有标题/几行描述，无法指导实际开发 |

**输出格式**：

```
📊 知识质量评估：meeting-setting
├── data-model.md  🟢 充实 — 完整接口定义 + 字段说明 + 常量枚举
├── api.md         🟢 充实 — 接口清单 + 参数 + 返回值
├── logic.md       🟡 基础 — 有初始化流程和函数签名，缺分支逻辑细节
├── ui.md          🟡 基础 — 有组件清单，缺 Props 和渲染条件
└── pitfalls.md    🟢 充实 — 7 个条目，均有根因和正确做法
综合：覆盖 5/5，充实 3/5，新鲜度正常
```

> AI 基于文件内容做快速定性判断即可，不需要精确计分。重点是让用户一眼看出"哪些文件该补充"。

---

## dev:kb verify [module]（验证一致性）

### 执行流程

1. 读取模块 `_overview.md` 中的核心文件列表
2. 对每个文件：比较 git 最后修改时间 vs `stability.last_verified`
3. 文件修改时间 > stability.last_verified → 标记为疑似漂移
4. 输出验证报告：一致/漂移/新增未记录
5. 用户确认后：一致的 → 刷新 `stability.last_verified`；漂移的 → 提示更新知识
6. **auto-verified / auto-stale 联动**：扫到 `confidence: auto-verified` 的条目时，重置 `auto_upgrade.upgraded_at` 为今日（推迟 90 天衰减）；扫到 `auto-stale` 的条目时，提示用户查看 `dev:kb audit`，可一键 reject 或人工重写并升级为 `verified`。
7. **自动重新生成度量仪表盘**：验证完成后自动执行 `python3 ~/.codebuddy/skills/dev-flow/scripts/gen-dashboard.py --no-open`，刷新 `~/.codebuddy/.metrics/dashboard.html`，无需用户手动操作。仅汇报执行结果。

---

## dev:kb audit（审计自动升级条目）

> 异步审计入口：步骤 1 多源仲裁产生的 `auto-verified` / `auto-stale` 条目集中查看与处理。详细规则与状态机定义见 `references/confidence.md` § scanned 自动升级规则。

### 子命令与默认行为

| 子命令 | 行为 |
|--------|------|
| `dev:kb audit` | 默认仅展示 `auto-stale` 列表（让用户优先关注异常）|
| `dev:kb audit --all` | 展示 `auto-verified` + `auto-stale` 全量列表 |
| `dev:kb audit --archived` | 展示已被 90 天衰减为 `archived` 的历史条目（只读）|
| `dev:kb audit --reject <id>` | 单条回退：状态由 `auto-verified`/`auto-stale` → `scanned`，写入 `auto_upgrade.rejected_at`，后续不再对同一条目重复升级 |
| `dev:kb audit --confirm <id>` | 单条提升：`auto-verified` → 人工 `verified`（清除 `auto_upgrade` 字段，从此与人工沉淀同等对待）|

### 列表输出格式

```text
🕵️  本项目自动升级审计（共 N 条 auto-stale，X 条 auto-verified）

[auto-stale] (Y 条 — 优先处理)
  #001  {module}/design-intent.md::心跳机制
        source: 知识库平台/wiki/heartbeat-design.md
        code_anchor: src/im/heartbeat.ts::startHeartbeat
        diff: wiki 描述 30s 心跳，代码实现 45s
        actions: [reject] [confirm] [view-diff]

[auto-verified] (X 条 — 默认隐藏，--all 展示)
  #042  {module}/design-intent.md::灰度路由
        upgraded_at: 2026-04-15 (剩余 76 天)
        actions: [reject] [confirm] [view-source]
```

### 衰减与归档

- 调度时机：`dev:kb sync` / `dev:kb verify` / `dev:kb health` 内置「衰减检查」环节
- 判定逻辑：当 `confidence == "auto-verified"` 且 `today - auto_upgrade.upgraded_at > auto_upgrade.ttl_days`（默认 90） → 状态变为 `archived`
- 归档保留原始 frontmatter 与正文，**仅修改 `confidence` 字段**，不删除文件；`dev:kb audit --archived` 可查阅
- 检索层不采纳 `archived` 条目（与 `stale` 同等隔离）

### 与 reject / confirm 的语义差异

| 操作 | 状态变化 | 后续行为 |
|------|---------|---------|
| `reject` | `auto-*` → `scanned` + 写入 `rejected_at` | 同条目再次被仲裁时**跳过自动升级**，永久保持 `scanned`，避免反复打扰 |
| `confirm` | `auto-*` → `verified`（清除 `auto_upgrade`）| 进入人工 verified 排序通道，参与跨分支共享 |
| 不操作 | 保持现状 | 90 天后 auto-verified 衰减为 archived；auto-stale 不衰减（一直保留供下次审计）|

---

## dev:kb dashboard（知识地图可视化）

### 执行流程

1. 遍历 `~/.codebuddy/knowledge/{project-name}/` 全部文件
2. 生成 HTML 知识地图，包含：
   - 模块拓扑图（模块间依赖关系）
   - 覆盖度热力图（每个模块×主题的填充状态）
   - 置信度分布饼图
   - 过期预警列表
3. 写入 `~/.codebuddy/knowledge/{project-name}/_dashboard.html`
4. 自动打开浏览器预览
