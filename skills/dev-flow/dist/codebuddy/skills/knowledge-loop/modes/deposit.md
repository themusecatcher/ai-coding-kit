# 沉淀模式（Deposit Mode）

> 本文件中 `templates/` 和 `references/` 等相对路径均以 Skill 根目录（`~/.codebuddy/skills/knowledge-loop/`）为基准。

> 由 dev-flow 步骤 7（标准执行）、步骤 10（完整执行）、收尾环节 H.3 调用。
> 读写操作，分析改动 → 逐主题检查 → 用户确认 → 写入 knowledge/。

## 触发条件

每次需求开发完成时，**必须执行**知识沉淀。

- 完整执行：步骤 10（归档与交付）中执行
- 标准执行：步骤 7（清理+Commit）中执行
- 收尾模式：环节 H.3（Commit + devlog + knowledge）中执行

> ❌ 禁止以"改动简单"/"无新知识"/"纯样式调整"等理由跳过知识沉淀。
> ✅ 简单改动执行最小沉淀，复杂改动执行完整沉淀。

---

## 全面沉淀清单（每次沉淀时逐项检查）

> **原则**：**宁多勿少**。
> **判断标准**：如果某个知识点"不知道就会踩坑"或"知道了能省 30 分钟"，就应该沉淀。

| 维度 | 检查问题 | 目标文件 |
|------|---------|---------|
| 接口协议 | 是否接触了新接口或发现已有接口未记录的行为？ | `api.md` |
| 数据结构 | 是否阅读到完整 state/props/interface？已有记录是否完整？ | `data-model.md` |
| 组件 Props | 是否使用了公共组件？Props 接口是否已沉淀？ | `ui.md` |
| 分支逻辑 | 同一功能是否存在不同实现路径？已有记录是否涵盖所有路径？ | `logic.md` |
| 初始化/生命周期 | 组件初始化流程、调用链是否已记录？ | `logic.md` |
| 函数签名与行为 | 核心函数的参数含义、特殊分支、联动逻辑是否已记录？ | `logic.md` |
| 常量/枚举 | 是否使用了重要的常量映射表？命名规则是否已记录？ | `data-model.md` |
| 渲染结构 | 页面区块组成（组件、显示条件、顺序）是否已记录？ | `ui.md` |
| 易错点/踩坑 | 开发过程中是否遇到了容易出错的地方？ | `pitfalls.md` |
| 跨模块依赖 | 是否发现了模块间的隐式依赖？ | `pitfalls.md` 或 `_patterns/` |
| **跨仓库参数链路**（跨项目场景时） | （仅 dev-flow `cross_project.enabled: true` 或改动涉及跨仓库调用的接口/参数时检查）是否有参数/字段/标识符跨越多个仓库的完整传递链路？上下游知识是否已建立双向链接？ | 各仓库 `_index.md` §「跨仓库知识」+ 各仓库对应主题文件（双向引用） |
| **设计意图反哺**（远程 wiki/doc_platform）| 本次研究是否从 知识库平台/wiki / doc_platform / web_search 带回了「设计意图 / 架构背景 / 未来规划」类知识？ | `design-intent.md`（详见下文专章）|

---

## 沉淀执行流程

### 0. 分支检测（前置，全流程共享）

沉淀开始的**第一步**执行分支检测，结果缓存供后续步骤复用（步骤 4.5 流转规则、步骤 6 _index.md 更新等）。

```bash
current_branch=$(git branch --show-current)
# 从 _index.md（若存在）读取 base_branch，缺省 master
base_branch="${base_branch:-master}"
is_base_branch=$([ "$current_branch" = "$base_branch" ] && echo true || echo false)
has_uncommitted=$(git status --porcelain | wc -l)
```

#### 决策矩阵

| 当前分支 | 未提交改动 | 行为 |
|---------|-----------|------|
| base 分支（如 master） | 无 | ✅ 正常沉淀，推荐级别 `verified` |
| base 分支 | 有 | ⚠️ 警告：沉淀将包含未提交改动，建议先 commit 再沉淀（可选择继续，级别仍为 verified） |
| feature/*或 hotfix/* | 任意 | 🟡 推荐级别 `pending`，自动写入 `created_branch=当前分支` |
| detached HEAD | 任意 | 🔴 阻断：不建议沉淀（无分支归属，后续升级路径断裂） |

#### 用户可见输出

```text
🔍 沉淀分支检测
├── 当前分支：feature/vip-light-preload
├── 基准分支：master
├── 未提交改动：2 个文件
└── 推荐级别：pending（开发期知识；MR 合并后下次在 master 上跑 `dev:kb sync` 会自动升级为 verified）
```

> 检测结果作为步骤 4.5 置信度流转的输入，**所有主题文件共享同一分支语境**（不能一文件 verified、另一文件 pending）。

### 1. 确定项目目录

确定项目名称（优先级：活跃 dev-flow 工作上下文 > 当前打开的项目目录名推断 > 询问用户）。

检查 `~/.codebuddy/knowledge/{project-name}/` 是否存在：

- 不存在 → 创建目录 + `_index.md`（参照 `templates/_index.md.tpl`）
- 已存在 → 读取 `_index.md` 获取已有模块清单

### 2. 确定模块名称

优先级：用户明确指定 > 从本次改动的核心文件路径提取 > 询问用户。

当由 dev-flow 调用时，从本次改动的核心文件路径提取模块名。

### 3. 检查模块目录是否已存在

- 已存在 → **按主题增量更新**对应文件
- 不存在 → 创建模块目录 + `_overview.md`（参照 `templates/_overview.md.tpl`）+ 按需创建主题文件（参照 `templates/topic.md.tpl`）

### 4. 逐主题检查

按全面沉淀清单逐项检查，对每个有新知识的主题，追加到对应文件。

### 4.5 置信度流转检查（自动）

对本次沉淀涉及的每个主题文件，**基于当前 git 分支**自动决定级别流转：

```
当前分支 = $(git branch --show-current)
基础分支 = _index.md 的 base_branch（默认 master）
is_base_branch = (当前分支 == 基础分支)
```

#### 流转规则

| 当前 confidence | 当前分支 = base | 升级为 | 说明 |
|----------------|----------------|--------|------|
| `draft` / `scanned` | ✅ 是（如 master） | `verified` | 直接在 base 分支上验证 |
| `draft` / `scanned` | ❌ 否（feature 分支） | `pending` | 本地验证，待合入后升级 |
| `pending` | ✅ 是（合入后首次沉淀） | `verified` | `dev:kb sync` 识别到 feature 合入自动升级（详见 `modes/manage.md` § dev:kb sync 场景 B） |
| `pending` | ❌ 否（同一 feature 分支） | 保持 `pending` | 继续在本地迭代 |
| `verified` | 任意 | 保持 `verified` | 已是稳定级别 |
| `stale` | ✅ 是 | `verified`（重新验证） | 漂移已修复 |
| `stale` | ❌ 否 | `pending`（重新验证） | 在 feature 分支修复 |

#### 分支感知字段维护

- `created_branch`：pending 级别必填，沉淀时自动写入 `git branch --show-current`
- `base_branch`：取 `_index.md` 的 base_branch，缺省 `master`
- `stability.last_verified`：每次沉淀刷新为当日日期
- `stability.drift_count`：从 stale 恢复到非 stale 时清零

#### release 字段维护（独立于级别）

上线后 bugfix 沉淀时，**不升级置信度级别**，而是写入 release 字段：

```yaml
release:
  released: true
  released_at: "YYYY-MM-DD"
  verified_in_production: true
  evidence:
    - type: bugfix
      ref: "commit/MR/任务平台 ID"
      note: "线上 bugfix 验证通过"
```

执行时机：步骤 4 逐主题写入时，在更新 frontmatter 的同时自动检查并流转。无需用户干预。

> 此机制保证「feature 分支沉淀 → pending（仅本地）→ 合入 master 后下次 `git pull` + `dev:kb sync` 升级为 verified」的分支感知闭环；上线验证信息作为独立维度写入 release，不改变 confidence 级别。

### 5. 检查跨模块知识（当前项目内）

是否有可抽取的设计模式 → `_patterns/`；是否有可复用的操作流程 → `_recipes/`

### 5.5 跨项目模式检查（自动）

提取本次沉淀中的**通用技术模式**关键词（如"轮询"、"灰度"、"Token 过期"、"双层嵌套"），在 `~/.codebuddy/knowledge/` 下其他项目中搜索同类模式。发现 ≥2 个项目包含同类模式时，输出提升建议。

完整提升流程 → `read_file("references/lifecycle.md")` 的「跨项目知识提升」章节。

> 此步骤为自动执行，不阻塞流程。仅在发现可提升模式时追加一个建议提示。

### 5.6 跨仓库参数链路联动（自动 + 交互式确认）

**触发条件**（任一满足即执行）：

1. dev-flow 工作上下文 `cross_project.enabled: true` 且 `cross_project.fix_projects` 非空
2. 本次沉淀的主题涉及**跨仓库传递的参数/字段/标识符**（如 `c_app_version`、`app_id`、`query` 参数、jsapi 参数、URL 参数、请求 body 透传字段等）

**识别规则**：

AI 在完成步骤 5.5 后，扫描本次沉淀的主题文件内容，如果识别到以下信号之一：
- "透传"、"传递"、"跨仓库"、"跨项目"、"A→B"、"全链路"
- 函数签名中有 `query` / `params` / `options` 等参数从当前仓库发出到另一仓库消费
- `_overview.md` 或 `pitfalls.md` 中描述了参数在多个仓库间的流转路径

**执行流程**：

1. **识别参数量链路**：
   - 从本次改动中提取跨仓库传递的关键参数名（如 `c_app_version`）
   - 确定发起方仓库（参数构造方）和消费方仓库（参数解析/使用方）
   - 绘制完整传递链路（每层文件 + 作用）

2. **检查两边知识库的双向链接**：
   - 检查发起方知识库是否引用了消费方知识库（`_index.md` + 对应主题文件）
   - 检查消费方知识库是否引用了发起方知识库（反向检查）
   - 任意一侧缺少引用 → 标记为待修复

3. **输出联动建议**（交互式确认）：

```text
🔗 发现跨仓库参数链路：{参数名}

├── 发起方：{project-A}/{module}
│   ├── 当前知识：`_overview.md` §{section} 已描述 {参数名} 的构造逻辑
│   └── ⚠️ 缺少 → 消费方知识库的引用链接

├── 消费方：{project-B}/{module}
│   ├── 当前知识：`_overview.md` §{section} 已描述 {参数名} 的解析逻辑
│   └── ⚠️ 缺少 → 发起方知识库的引用链接

└── 建议：为两侧知识库建立双向链接
```

> 📌 确认弹框选项："✅ 建立双向链接" / "✏️ 仅更新一侧" / "⏭️ 跳过"

4. **执行双向链接写入**（用户确认后）：

   **发起方知识库更新**：
   - 对应主题文件（如 `_overview.md`）中：扩展现有章节为完整跨仓库链路（含发起方+消费方各层描述 + 链接）
   - `_index.md` 概念索引中：新增"跨仓库参数链路"条目，包含双向文件路径

   **消费方知识库更新**：
   - 对应主题文件中：在已有描述末尾追加"B 侧关键文件"段落 + 完整示例 + 反向链接
   - `_index.md` 概念索引中：新增"跨仓库参数链路"条目，包含双向文件路径

**链接格式规范**（双向引用标准格式）：

```markdown
<!-- 在 _index.md 概念索引中 -->
| **跨仓库参数链路：{参数名} {发起方}→{消费方} 完整传递** | {当前模块} ↔ {对方知识库路径} | 发起方 N 层 + 消费方 M 层 |

<!-- 在主题文件 _overview.md 中 -->
**{对方角色}侧**：详见 `{对方知识库绝对路径（以 ~/.codebuddy/knowledge/ 开头）}` §「{章节名}」
```

**边界情况**：

| 场景 | 处理 |
|------|------|
| 发起方知识库不存在 | 先按最小沉淀规则创建，再建立链接 |
| 消费方知识库不在当前机器 | 仅在发起方知识库中标注消费方仓库路径和参数用途，待后续补全 |
| 链路 >2 个仓库 | 逐对建立双向链接（A↔B, B↔C），在中间仓库处形成链式引用 |
| 单向调用（仅 A 调用 B，B 不感知 A） | 发起方必须引用消费方；消费方按需可选引用（在 pitfalls 中记录"被哪些仓库调用"） |

> 📌 完整链路示例 + 双向链接写入范例 → `references/cross-repo-linkage.md`

### 6. 更新 _index.md

模块清单 + 概念索引 + 接口索引 + **跨仓库知识**（步骤 5.6 有产出时必填）+ 最近变更摘要。

### 7. 向用户确认（交互式 / 快速模式）

**快速沉淀模式**（满足以下**全部条件**时自动启用）：

- 本次沉淀仅涉及「变更历史追加一行」+ 刷新 `stability.last_verified`
- 无新增知识点、无修改已有内容、无新建文件
- 无跨项目模式提升建议

快速模式下：展示单行摘要 → **直接执行**（无需交互确认）：

```text
📚 快速沉淀：{module}/_overview.md 变更历史 +1 行，stability.last_verified 已刷新。
```

**标准确认模式**（不满足快速模式条件时）：

展示将要写入的内容摘要，**使用 `ask_followup_question` 弹出交互式选项**：

```text
📚 本次开发涉及以下知识沉淀，请确认：
```

| 选项 | 说明 |
|------|------|
| ✅ 确认沉淀 | 将以上内容写入 knowledge/ |
| ✏️ 修改内容 | 告诉我需要调整的部分 |

> 不提供"跳过"选项，知识沉淀是必须产出物。

---

## 最小沉淀规则

当改动不涉及新模块/新数据结构/新业务逻辑时：

1. 确定涉及的模块 `_overview.md`
2. 在「变更历史」表格末尾追加一行
3. 项目 knowledge/ 目录不存在时，创建 `_index.md` + 最小模块 `_overview.md`

---

## 更新已有知识的规则

- **增量更新，不覆盖**
- **变更历史必须追加**
- **数据结构/接口**：有变更时更新为最新版本
- **关键逻辑/已知约束**：新发现时追加到末尾
- **frontmatter**：更新 `stability.last_verified`、`stability.confidence_score` 和 `confidence`；必要时同步 `stability.drift_count`、`release` 字段

---

## design-intent.md 写入规则（设计意图反哺）

> 针对 P3 类远程知识（知识库平台/wiki / git_doc_platform / doc_platform / web_search）带回的**设计意图、架构背景、未来规划**类知识，沉淀为独立文件 `design-intent.md`，**与代码事实类知识并列不互盖**，避免设计文档与现实代码混为一谈。

### 适用范围

以下内容**应**写入 `{module}/design-intent.md`：

- 架构设计背景与权衡（为什么选 A 不选 B）
- 未来规划 / 路线图（「未来将支持 X」「第二期考虑 Y」）
- 设计原则 / 约束动机（「为避免 Z 问题才这么设计」）
- 跨模块交互协议的设计考量（仅 wiki 描述，未在代码中体现）
- 外部领域知识（如「WebRTC 重连机制的退避收敛原则」）

### 不适用范围

以下内容**不要**写入 design-intent.md，该走对应主题文件：

- 接口请求响应体事实 → `api.md`
- 函数签名与实现逻辑 → `logic.md`
- 组件 Props / state 结构 → `data-model.md` / `ui.md`
- 踩坑记录 → `pitfalls.md`

### Frontmatter 要求

```yaml
---
topic: design-intent
module: {module}
confidence: scanned        # 默认为 scanned；被仲裁升级后可能变为 auto-verified / auto-stale
stability:
  last_verified: YYYY-MM-DD
  drift_count: 0
  confidence_score: 40     # scanned 基线
release:
  released: false           # design-intent 表达设计意图，不参与上线验证体系
---
```

### 写入格式约定

每一条反哺条目**必须**包含以下三要素：

```markdown
## {主题，如「心跳机制设计背景」}

<!-- source: 知识库平台/wiki | doc_platform:xxxxx | mr#1234 -->
<!-- ingested_at: YYYY-MM-DD -->
<!-- arbitration: P3 · scanned · 未与代码交叉验证 -->

{原始表述摘要，控制在 200 字以内}

**设计意图**：{提炼后的意图陈述}
**与代码事实的关系**：{选一：已在 X.tsx 中实现 / 部分实现于 Y / 仅为规划未实施}
```

> 🔑 「**与代码事实的关系**」字段是升级仲裁的关键输入 → 已实现可升级 `auto-verified`；仅为规划必须保留 `scanned`（详见 `references/confidence.md`）。

### 200 行硬上限与摘要压缩

- **硬上限**：`design-intent.md` 身主体行数 > 200 行时，**禁止**继续追加原始全文，必须进入「摘要压缩」流程。
- **压缩流程**：
  1. 在同级创建 `_archive/design-intent-{YYYYMMDD}.md`，将原全文追加到归档文件末尾（并在顶部加入归档时间戳与原因注释）
  2. 对 design-intent.md 中重要要点以**要点清单**方式保留（每条 ≤ 3 行且保留 `<!-- source: -->` 注释）
  3. 在 design-intent.md 顶部加入：`> 📁 历史全文已归档至 _archive/design-intent-{YYYYMMDD}.md`
  4. 压缩后重新检查行数 ≤ 200；如仍超限重复压缩一轮
- **触发时机**：每次向 design-intent.md 追加前检查行数；达阈时先压缩再追加。

### 与仲裁/检索层的关系

- **默认加载**：`design-intent.md` 与 `_overview.md` **同级纳入检索默认加载白名单**（详见 `modes/retrieve.md` § 默认加载白名单）。
- **仲裁结果回写**：步骤 1 仲裁产生的 `auto-verified` / `auto-stale` / `scanned` 状态变化 → 同步更新到对应条目的 `<!-- arbitration: -->` 注释及 frontmatter 的 `confidence` 字段。

## 上线后 bugfix 强化沉淀规则

当 dev-flow 迭代修复场景分类为「上线后 bugfix」时，知识沉淀升级为强化模式：

### 强化沉淀与标准沉淀的差异

| 维度 | 标准沉淀 | 强化沉淀（上线后 bugfix） |
|------|---------|------------------------|
| 置信度标记 | `verified` | `verified` + `release.verified_in_production: true` |
| pitfalls.md | 追加条目 | 追加条目 + **标注 `[线上验证]` 标签** |
| 跨模块检查 | 仅检查当前模块 | **主动评估 bug 根因的跨模块通用性** |
| _overview.md | 追加变更历史 | 追加变更历史 + **明确标注"线上 bugfix"** |
| 用户确认 | 交互确认 | 交互确认（不可跳过） |

### `[线上验证]` 标签

沉淀到 `pitfalls.md` 的条目使用 `[线上验证]` 前缀标注：

```markdown
- [线上验证] **corpId 与 accountCorpId 不等价**：corpInfos 中 corpId 和 accountCorpId 在普通企业场景下相同，但在个人直升企业场景下不同。灰度中心查询时 account_corp_id 参数必须使用 accountCorpId
```

检索模式加载知识时，`[线上验证]` 标签的条目**优先展示**（置信度最高的实战经验）。

### 跨模块通用性评估

强化沉淀时，AI 必须主动检查：

1. bug 根因涉及的概念（如"corpId vs accountCorpId"）是否在其他模块中也被使用
2. 有通用性 → 同步更新 `_patterns/` 或其他相关模块的 `pitfalls.md`
3. 无通用性 → 仅更新当前模块

## 禁止行为

- ❌ 禁止不经用户确认就写入 knowledge/（快速沉淀模式除外——仅追加变更历史+刷新日期时免确认）
- ❌ 禁止覆盖已有内容（只能增量更新）
- ❌ 禁止以任何理由跳过知识沉淀
- ❌ 禁止将临时性调试信息、个人偏好写入
- ❌ 禁止在项目目录中创建 knowledge/

---

## 置信度标记

沉淀时根据分支自动流转置信度（详见步骤 4.5 流转规则表）：

- feature 分支沉淀 → `confidence: pending`（仅本分支可用）
- base 分支沉淀 / 合入后 sync 升级 → `confidence: verified`（跨分支可信；详见 `modes/manage.md` § dev:kb sync）
- 上线后 bugfix 沉淀 → `confidence` 保持不变，`release.verified_in_production: true`（独立维度标记生产验证）

完整置信度体系（5 级：draft/scanned/pending/verified/stale）→ `read_file("references/confidence.md")`

---

## 执行完毕

沉淀写入完毕后，自动返回调用方（dev-flow 步骤 / 收尾环节）继续后续流程。独立使用时直接结束。
