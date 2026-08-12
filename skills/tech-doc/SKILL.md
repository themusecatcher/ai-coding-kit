---
name: tech-doc
description: "文档处理中心。统一管理开发日志（devlog）、文档同步（doc-sync）和技术方案文档（tech-proposal）三大功能模块。支持独立使用和被 dev-flow 按需调用。根据用户意图自动路由到对应模块，按需加载避免 Token 浪费。技术方案模块同时支持在线发布（需配置 doc_platform_url）和本地模式（默认，输出到 ~/.codebuddy/tech-docs/）。触发关键词：「生成开发日志/记录改动/devlog」→ devlog 模块；「同步文档/文档更新了」→ doc-sync 模块；「技术方案/技术分享/发布文档/精简文档/优化文档」→ tech-proposal 模块。"
keywords: ["开发日志", "devlog", "文档同步", "技术方案", "doc-sync", "tech-proposal", "tech-doc"]
---

# tech-doc — 文档处理中心

> 统一的文档处理入口。支持三大功能模块，根据场景按需加载对应模块。
> 可独立使用（用户触发文档相关操作），也被 dev-flow 按步骤调用。

---

## 功能路由

识别用户意图后，**只加载对应模块**，避免一次性加载全部内容浪费 Token。

> 📌 **触发关键词的单一权威源**：完整的触发关键词清单（含显式/隐式/不触发场景、组合调用、dev-flow 调用映射）维护在 [`config/triggers.yaml`](config/triggers.yaml)。下表仅作为路由速查；当 `config/triggers.yaml` 与本表冲突时以前者为准。

| 模块 | 文件 | 触发关键词（速查） |
|------|------|-----------|
| **开发日志** | `modules/devlog.md`（~15KB） | "生成开发日志"/"记录改动"/"生成 devlog"/"写个开发记录" |
| **文档同步** | `modules/doc-sync.md`（~13KB） | "同步文档"/"更新技术方案"/"文档更新了"/"doc_platform 同步"/"文档改了"/"设计稿更新"/"需求变更"/"接口改了" |
| **技术方案** | `modules/doc-platform-doc.md`（~44KB） | "技术方案"/"技术分享"/"发布文档"/"写/生成+文档类型" | 支持两种输出模式（由 `config/org.yaml` 的 `tech_docs_mode` 控制）：在线（doc_platform_url 已配置 → 发布到文档平台）/ 本地（默认 → 保存到 `~/.codebuddy/tech-docs/`） |

> 📌 本地模式详细说明 → `references/local-doc-mode.md`，类似 devlog 目录的零配置体验

### 技术方案文档支持范围

> 📌 **输出模式**：本模块支持两种输出模式，由 `config/org.yaml` 的 `tech_docs_mode` + `doc_platform_url` 联合控制：
> - **本地模式**（默认，零配置）：文档保存到 `~/.codebuddy/tech-docs/` 目录（类似 devlog）
> - **在线模式**（需配置）：文档通过 MCP 工具发布到配置的文档平台
>
> 两种模式下文档模板、lint 校验、工作流程一致，仅"最终保存位置"不同。
> 详细模式说明 → `references/local-doc-mode.md`

`doc-platform-doc` 模块支持三种文档类型：

| 类型 | 模板状态 | 说明 |
|------|---------|------|
| **tech-proposal**（技术方案） | ✅ 完整模板 | 九章节 + 附录，含完整变量填充规范、流程图判断节点规范等 |
| **tech-sharing**（技术分享） | ✅ 完整模板（B2-D2 改造） | 标准章节：背景/核心要点/实践方案/踩坑总结/总结与展望 |
| **release-doc**（发布文档） | ✅ 完整模板（B2-D3 改造） | 标准章节：版本信息/新增功能/修复问题/已知问题/升级说明 |

> 📌 LLM 在生成对应类型文档时**必须严格加载并使用 `doc-platform-doc.md` 中对应模板**，禁止自由发挥（参见 `~/.codebuddy/rules/AI行为规范.mdc` §「Skill 模板严格遵循规则」）。

### 加载方式

识别意图后，使用 `read_file` 加载对应模块文件（相对于本 Skill 目录）：

```
# 示例：用户说“生成开发日志”
read_file("modules/devlog.md")

# 示例：用户说“同步文档”
read_file("modules/doc-sync.md")

# 示例：用户说“写个技术方案”
read_file("modules/doc-platform-doc.md")
```
### 路由判断规则

1. **优先匹配显式关键词**：用户消息中包含上表关键词 → 直接路由到对应模块
2. **组合场景**：某些操作需要同时加载多个模块（如 doc-sync 执行过程中可能需要更新 devlog），由子模块内部说明依赖关系
3. **不确定时询问**：无法判断用户意图时，展示三个模块选项让用户选择

```
你想执行哪种文档操作？

1. 📝 **开发日志** —— 生成 devlog.md 和 plan.md（本地开发记录）
2. 🔄 **文档同步** —— 同步工作上下文、开发日志和 技术方案文档
3. 📋 **文档平台 文档** —— 生成/更新 技术方案文档、技术分享或发布文档

请选择（1/2/3）或直接描述你的需求。
```

---

## dev-flow 场景路由

> 🔗 **单一权威源**：dev-flow 调用映射同时也维护在 [`config/triggers.yaml`](config/triggers.yaml) 的 `<模块>.dev_flow_invocation` 节点（`devlog` / `doc_sync` / `doc_platform_doc` 三个模块各自一份）。下表为跨模块综合表格，方便完整查看。增删调用点请同时修改 yaml 与本表。

dev-flow 各步骤调用 `use_skill('tech-doc')` 后，根据以下映射加载对应模块：

| dev-flow 步骤 | 加载模块 | 说明 |
|--------------|---------|------|
| 步骤 4 阶段 3 决策后 | `modules/doc-platform-doc.md` | `action ∈ {create, update}` 时加载。在线模式直接发布；本地模式保存到 `tech-docs/` 目录 |
| 步骤 5.5b 编码后 | `modules/doc-sync.md` | 文档同步时机 ①（最轻量） |
| 步骤 5.5b 接口变更例外 | `modules/doc-sync.md` + `modules/doc-platform-doc.md` | protobuf/接口变更时，时机 ① 提升为时机 ② |
| 步骤 6 前验证前 | `modules/doc-sync.md` | 文档同步时机 ②（主要同步点） |
| 步骤 7 H.3+ | `modules/doc-platform-doc.md` 模式 C | 上线后 bugfix 或提测后迭代修复命中阈值时。在线模式同步到知识库；本地模式对比本地文件 |
| 步骤 7 / 收尾 3.5 | `modules/devlog.md` + `modules/doc-sync.md` | 生成开发日志 + 文档同步兜底 |
| **步骤 10.3.5 归档同步** | `modules/doc-platform-doc.md` 模式 C | **完整执行必走**。在线模式：`doc_platform_tech_proposal.action ∉ {skip, auto_inherited_skip}` 时强制同步到知识库。本地模式：将文档写入 `tech-docs/` 目录归档 |
| 步骤 10 归档三件套 | `modules/devlog.md` + `modules/doc-sync.md` | devlog + 工作上下文完整归档 |
| 被动同步（外部文档变更） | `modules/doc-sync.md` | 用户告知文档变更时 |

**dev-flow 调用约定**：
- dev-flow 各步骤说明中会标注需要加载的具体模块，按标注加载即可
- 同一步骤需要多个模块时，按顺序依次加载
- 模块加载后按其内部规则执行，无需回到本入口文件

---

## 独立使用（用户调用指南）

tech-doc 既可以被 dev-flow 自动调用，也可以**脱离 dev-flow 独立使用**。以下是用户的具体调用方式。

### 调用方式

**统一入口**：对 AI 说任何文档相关的需求即可，AI 会自动触发 `use_skill('tech-doc')` 并路由到对应模块。

**无需记忆模块名**——只需用自然语言描述需求，AI 根据关键词自动匹配。

### 📝 开发日志（devlog 模块）

生成本地开发日志 `devlog.md` 和执行计划 `plan.md`。

**调用示例**：
- "帮我生成开发日志"
- "记录一下这次改动"
- "生成 devlog"
- "写个开发记录"

**输出**：`~/.codebuddy/dev-logs/<项目名>/<分支名>/devlog.md` + `plan.md`

### 🔄 文档同步（doc-sync 模块）

协调管理工作上下文、开发日志和 技术方案文档三类文档的一致性。

**调用示例**：
- "同步一下文档"
- "doc_platform 同步"
- "文档更新了，帮我同步"
- "需求/设计稿/接口改了"

**核心能力**：检查三类文档是否一致，按时机由轻到重递进同步（更新进度 → 三件套同步 → 兜底检查 → 完整同步）。

### 📋 文档平台 文档（doc-platform-doc 模块）

生成/编辑/发布 文档平台 线上技术文档，支持三种文档类型。

**调用示例**：
- "写个技术方案" / "生成技术方案"
- "帮我写个技术分享"
- "生成发布文档" / "写个 release notes"
- "精简这个 doc_platform 文档" + 文档平台 链接
- "优化一下这个文档" + 文档平台 链接
- "把这个方案发到 doc_platform"

**三种工作模式**：
- **模式 A（自动填充）**：从工作上下文/代码自动提取信息生成文档
- **模式 B（手动输入）**：用户提供素材，AI 组织生成文档
- **模式 C（编辑优化）**：对已有 文档平台 文档进行精简/优化/补充。**默认使用方案 B（建议模式）**——输出优化建议供用户自行更新；用户明确要求时切换为方案 A（AI 直接更新 文档平台）

### 组合调用

> 🔗 **单一权威源**：组合调用场景同时维护在 [`config/triggers.yaml`](config/triggers.yaml) 的 `combo_scenarios` 节点。下表仅为高频示例；增删场景请同时修改 yaml 与本表。

某些场景需要多个模块协同：

| 场景 | 说话方式 | 实际加载 |
|------|---------|---------|
| 开发完想一次性搞定 | "帮我生成开发日志，顺便同步文档" | devlog + doc-sync |
| 需求完结全量归档 | "全部文档归档一下" | devlog + doc-sync + doc-platform-doc |
| 写完方案想同步 | "技术方案写好了，帮我同步" | doc-sync |
