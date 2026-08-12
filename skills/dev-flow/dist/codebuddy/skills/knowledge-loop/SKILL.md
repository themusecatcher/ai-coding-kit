---
name: knowledge-loop
description: "AI 驱动的本地代码知识沉淀与复用系统（仅本地 ~/.codebuddy/knowledge/，非 MCP 远程知识库）。自动沉淀每次开发中接触到的接口/数据模型/业务逻辑/UI/易错点等代码相关知识，在后续需求中自动检索复用，让 AI 越用越聪明。与 远程知识库 MCP（remote_kb） 远程知识库形成互补：本 skill 是 AI 的『肌肉记忆』（本地、可写、AI 沉淀），知识库平台 是项目的『全景地图』（远程、只读、源码语义检索）。可被 dev-flow 按需调用（步骤1/5/7/10/收尾），也可独立使用。触发关键词：代码知识、代码知识库、本地知识库、本地知识沉淀、知识沉淀、dev:kb、dev:k、dev:kl、项目代码知识、帮我沉淀知识、查看代码知识库、扫描代码知识、搜索代码知识、代码知识库健康度、验证知识、知识地图、导出代码知识、export code knowledge、提升全局模式、git pull 后对齐知识库、知识库同步、dev:kb sync、dev:k sy。"
<!-- ┌──────────────────────────────────────────────────────────────┐ -->
<!-- │  ❄️  冻结横幅 / FROZEN BANNER（Phase 1 重构，2026-05-15）     │ -->
<!-- ├──────────────────────────────────────────────────────────────┤ -->
<!-- │ 本文件是 AI 运行时入口（提示词层），不是规则真相来源。        │ -->
<!-- │                                                              │ -->
<!-- │ 单一权威源（Single Source of Truth）：                        │ -->
<!-- │   • 前置物 schema       → config/frontmatter.schema.json      │ -->
<!-- │   • 状态机定义           → config/state-machine.yaml          │ -->
<!-- │   • 阈值/健康度          → config/thresholds.yaml             │ -->
<!-- │   • 依赖/lint/校验脚本   → scripts/{precheck,lints,lib}/      │ -->
<!-- │   • 设计哲学/重构决策    → references/refactor-plan.md        │ -->
<!-- │                                                              │ -->
<!-- │ 修改规则：                                                    │ -->
<!-- │  1. 任何「确定性规则」改动必须先动 config/scripts，再回引     │ -->
<!-- │     到本文件；禁止只在提示词里描述硬规则。                    │ -->
<!-- │  2. 本文件章节如与 config/scripts 冲突，以 config/scripts 为  │ -->
<!-- │     准；冲突即视为本文件失效，需立即修订。                    │ -->
<!-- │  3. 跨文件协作必须双向引用（参考 AI 行为规范.mdc §跨文件      │ -->
<!-- │     协作设计模式）。                                          │ -->
<!-- └──────────────────────────────────────────────────────────────┘ -->

# knowledge-loop — 本地代码知识沉淀与复用

> **定位**：dev-flow 的唯一**本地代码知识**存储与检索层，让 AI 越用越聪明。
> 与 远程知识库 MCP（remote_kb） 远程知识库互补——本 skill 是 AI 的「肌肉记忆」（本地、可写、AI 沉淀），知识库平台 是项目的「全景地图」（远程、只读、源码语义检索）。
> 可被 `dev-flow` 步骤 1/5/7/10/收尾按需调用，也可独立使用。

## 与 知识库平台 的边界（重要）

| 维度 | 本 skill（knowledge-loop） | 知识库平台 / remote_kb MCP |
|------|--------------------------|---------------------|
| 存储位置 | 本地 `~/.codebuddy/knowledge/{project}/` | 远程 `knowledge_uuid` |
| 可写性 | ✅ 可写（强制沉淀） | ❌ 只读（被动检索） |
| 内容形态 | Markdown + YAML（5 主题文件） | git/git_doc_platform/commit/MR 索引 |
| 数据来源 | AI 沉淀 + 用户验证 | 项目源码 + doc_platform + commit + MR |
| 调用方式 | `use_skill('knowledge-loop')` | `use_mcp_tool(server=remote_kb, tool=knowledgebase_search)` |
| 触发词归属 | 「代码知识」「本地知识库」「沉淀知识」 | 「MCP 知识库」「knowledge_uuid」「remote_kb」「git_doc_platform」 |

> ⚠️ 用户说「MCP 知识库」「knowledge_uuid」「remote_kb」「doc_platform」时**不要触发本 skill**——那是 知识库平台 的范畴，应使用 dev-flow 的 知识库平台 MCP 调用机制。

## 路由规则

| 模式 | 触发方式 | 加载文件 |
|------|---------|---------|
| **检索模式** | dev-flow 步骤 1/5 调用 | `read_file("modes/retrieve.md")` |
| **沉淀模式** | dev-flow 步骤 7/10/收尾调用 | `read_file("modes/deposit.md")` |
| **管理模式** | `dev:kb` 命令 / 用户主动操作 | `read_file("modes/manage.md")` |
| **自动捕获** | 非 dev-flow 对话中发现有价值知识 | `read_file("modes/auto-capture.md")` |

> 💡 **检索模式自带「sync 滞后检测」**：dev-flow 步骤 1 触发检索时，自动比对 `_index.md.last_synced_sha` 与 `origin/{base_branch}`，若已偏离/超 7 天/从未 sync 则提示用户先跑 `dev:kb sync`，避免引用过期 verified 知识。完整规则见 `modes/retrieve.md` § sync 滞后检测。

### 加载策略

- **单一模式**：识别到明确模式后只加载对应文件，不加载其余
- **dev-flow 调用时**：dev-flow 步骤说明中会指定模式（如「检索模式」「沉淀模式」），直接加载对应文件
- **自动捕获**：非 dev-flow 对话中，AI 检测到有价值的项目知识时，加载 `auto-capture.md` 执行轻量沉淀
- **不确定时**：默认进入管理模式（展示概览+选项）

---

## dev-flow 集成映射

| dev-flow 步骤 | 模式 | 行为 |
|--------------|------|------|
| 步骤 1（研究定位） | 检索 | 自动检索项目知识，输出匹配结果；**附带 sync 滞后检测**（`last_synced_sha` 落后远端 base / 超 7 天未 sync / 从未 sync） |
| 步骤 5（编码） | 检索 | 按改动文件类型动态加载对应主题知识 |
| 步骤 7（清理+Commit） | 沉淀 | 标准执行/批次最后一批：强制沉淀（禁止跳过） |
| 步骤 10（归档交付） | 沉淀 | 完整执行：强制沉淀（禁止跳过） |
| 收尾环节 H.3 | 沉淀 | 收尾模式：强制沉淀（禁止跳过） |
| `dev:kb` / `dev:k` | 管理 | 查看/扫描/搜索/健康检查/验证/可视化 |

**dev-flow 调用约定**：
- dev-flow 通过 `use_skill('knowledge-loop')` 调用，附带模式标识（如「检索模式」「沉淀模式」）
- 加载后按模块内部规则执行，无需回到本入口文件
- 批次执行非最后一批：跳过沉淀（推迟到最后一批）

---

## 存储位置

`~/.codebuddy/knowledge/{project-name}/` — 三级结构：项目→模块→主题（`_index.md` / `{module}/_overview.md` / `{data-model,api,logic,ui,pitfalls}.md` / `_patterns/` / `_recipes/`）。

> 📌 完整目录树 + 命名规范 + frontmatter schema 详见 `references/schema.md`。

---

## 执行链路（确定性规则的物理事实层）

> **重要**：本 skill 所有「确定性规则」均由 `config/` + `scripts/` 兜底。AI 涉及"前置物校验 / 健康度计算 / 状态判定 / 依赖检查"动作时**必须调用脚本而非根据本文件提示词推理**——脚本/配置才是规则真相。

**配置权威源**（修改这里即修改规则）：
- `config/frontmatter.schema.json` · `config/state-machine.yaml` · `config/thresholds.yaml`

**脚本执行入口**（CLI 直接验证 · 退出码语义见 catalog）：
- 库：`scripts/lib/{yaml-bridge,score,state}.sh`
- Lint：`scripts/lints/check-{frontmatter,state,health,staleness}.sh`
- 守卫：`scripts/precheck/check-deps.sh`
- 测试：`scripts/tests/run-tests.sh`（当前 6 套件 37 用例 · PASS=37 / FAIL=0）

**详尽规约**（CLI 用法 / 退出码语义 / 调用规约 / 设计哲学回引）：见 `references/scripts-catalog.md`。

> 📌 任何与脚本输出**冲突**的本文件描述视为本文件失效，需立即修订（与 ❄️ 冻结横幅 §修改规则 第 2 条一致）。设计哲学一句话：**确定性用代码（schema/lint/yaml），模糊性用 LLM**。

---

## 核心原则

- **唯一本地来源**：knowledge-loop 是 dev-flow 的唯一**本地代码知识**检索和沉淀目标（远程语义知识用 知识库平台）
- **宁多勿少**：不仅沉淀本次需求改动，还要全面沉淀开发过程中接触到的所有模块知识
- **按需加载**：知识分主题存储在独立文件中，AI 按需加载而非全量加载，优化 token 效率
- **AI 友好**：Markdown 格式，带 YAML frontmatter 元数据，机器可读可写
- **强制沉淀**：每次需求完成都必须沉淀，禁止以任何理由跳过
- **集中存储**：knowledge/ 统一存储在 `~/.codebuddy/knowledge/`，禁止在项目目录中创建

---

## 独立使用

| 用户说 | AI 行为 |
|-------|---------| 
| "帮我沉淀下这个模块的知识" | `read_file("modes/deposit.md")` 进入交互式沉淀 |
| "查看项目知识库" / `dev:kb` | `read_file("modes/manage.md")` 进入管理模式 |
| "搜索知识库 xxx" / `dev:kb search xxx` / `dev:k s xxx` | `read_file("modes/manage.md")` → 搜索 |
| "扫描代码知识" / `dev:kb scan [module|--all|--diff]` | `read_file("modes/manage.md")` → 扫描（支持单模块/全量/增量） |
| "git pull 后对齐知识库" / "拉了最新 master" / `dev:kb sync` / `dev:k sy` | `read_file("modes/manage.md")` → §「dev:kb sync」（双场景：他人改动漂移检测 + 自己 pending 升级 verified） |
| "知识库健康度" / `dev:kb health` / `dev:k h` | `read_file("modes/manage.md")` → 健康检查 |
| "审计自动升级知识" / `dev:kb audit` / `dev:k a` / `dev:kb audit --all` / `dev:kb audit --archived` / `dev:kb audit --reject <id>` / `dev:kb audit --confirm <id>` | `read_file("references/confidence.md")` → §「scanned 自动升级规则」「异步审计与反悔机制」 |
| "验证知识一致性" / `dev:kb verify` / `dev:k v` | `read_file("modes/manage.md")` → 验证 |
| "知识地图" / `dev:kb dashboard` / `dev:k d` | `read_file("modes/manage.md")` → 可视化 |
| "导出知识库" / `dev:kb export --format=xxx` / `dev:k e xxx` | `read_file("references/mcp-export.md")` → 导出 |
| "提升全局模式" / `dev:kb promote <pattern>` | `read_file("references/lifecycle.md")` → 跨项目模式提升 |

---

## References（深度参考，按需加载）

| 文件 | 用途 | 加载时机 |
|------|------|---------| 
| `references/schema.md` | 目录结构规范 + 文件格式 + 项目名称映射 | 首次创建项目知识库时 |
| `references/confidence.md` | 置信度体系 + 代码漂移检测逻辑 | 检索时发现疑似漂移 / 沉淀时更新置信度 |
| `references/lifecycle.md` | 生命周期管理（过期规则/刷新机制/废弃流程/跨项目提升） | 管理模式的健康检查 / 过期预警 / 模式提升 |
| `references/team-sharing.md` | 团队共享方案（Phase 2 扩展） | 用户询问团队共享时 |
| `references/mcp-export.md` | 跨工具导出与 MCP 集成 | 用户要求导出知识库 / 跨工具使用 / MCP 集成 |
| `references/scripts-catalog.md` | §执行链路 详尽规约（脚本 CLI 用法 / 退出码语义 / 调用规约） | 修改 config 或 scripts / 查脚本输出语义 / 排查与提示词冲突 |
| `references/cross-repo-linkage.md` | 跨仓库参数链路联动写入范例（含 B→A 完整示例 + 3 种常见模式 + 自检清单） | deposit.md 步骤 5.6 按需加载 |
