# 文档同步规范（三模式通用）

涉及三类文档（工作上下文、开发日志、技术方案文档）的同步规范。

## 主动同步（编码后）

编码过程中按四个时机由轻到重递进执行文档同步：① 编码后（仅更新工作上下文进度）→ ② 验证前（三件套同步）→ ③ Commit/收尾（兜底检查）→ ④ 归档（完整同步）。

## 被动同步（外部文档变更 / 内部需求漂移）

当用户告知外部文档发生变更、或带外沟通后回流澄清结论时触发。**必须在动手改代码之前**完成相应同步流程。

### 触发关键词（指针引用，单一权威源）

> 🔒 **单一权威源原则**：本规范不再独立维护关键词清单。所有触发关键词以 `~/.codebuddy/skills/tech-doc/config/triggers.yaml` 为程序化权威源，本文件仅做语义分类描述与路由说明。增删关键词请直接修改 yaml。

| 类别 | 语义 | 权威源节点 |
| --- | --- | --- |
| **A. 外部文档变更** | 文档平台/Figma/protobuf 等外部文档/协议变更通告 | `triggers.yaml` → `doc_sync.explicit` + `doc_sync.passive_sync` |
| **B. 沟通结果回流** | 与产品/设计/后端 沟通后回流澄清结论 | `triggers.yaml` → `working_context_drift.communication_feedback` |
| **C. 需求/方案否定** | 用户带方向性地推翻既有方案/需求 | `triggers.yaml` → `working_context_drift.requirement_negation` |
| **D. 澄清式调整** | 修正性补充，调整既有理解的细节 | `triggers.yaml` → `working_context_drift.clarification` |

**注**：A 类与 B/C/D 类边界由 `triggers.yaml` `working_context_drift.boundary_with_doc_sync` 定义；同时命中（如「需求变更」+ 文档平台 链接）时按其规则解析。

## 路由分流（v1 新增 2026-05-19）

触发后按变更类型分流，避免不同性质的变更走同一路径导致漏处理：

| 变更类型 | 检测信号 | 路由目的地 |
| --- | --- | --- |
| 外部文档变更（文档平台/Figma/protobuf） | 用户贴出新链接/新结构定义，或命中 A 类关键词 | `use_skill('tech-doc')` 路由到 doc-sync 模块，按 §三「强制执行步骤」逐步执行 |
| **内部需求/方案漂移**（无外部文档变化） | 仅口头澄清/IM 沟通结果，命中 B/C/D 类关键词 | **`references/drift-handling.md`** |
| 两者兼有 | 用户同时贴新链接 + 说明调整 | 先走外部 doc-sync，再走内部漂移子流程 |

## 触发后行为（外部文档变更场景）

调用 `use_skill('tech-doc')`（路由到 doc-sync 模块）加载完整文档同步规范，按 §三「强制执行步骤」逐步执行。

## 触发后行为（内部需求漂移场景）

加载 `references/drift-handling.md`，按其三步固定动作（静默对账 → 输出漂移摘要 + 决策选项 → 执行刷新）执行。**禁止跳过强制交互**，避免 AI 自行揣测漂移程度。

## 反模式（违反即拒收）

- ❌ 命中 B/C/D 类关键词后只更新代码不刷新工作上下文 → 跨会话恢复时 AI 仍读到旧需求
- ❌ 命中 A 类关键词后跳过 doc-sync 模块直接改代码 → 文档平台/Figma 与代码漂移
- ❌ AI 静默判定「这次澄清不重要」而不输出漂移摘要 → 违反「需求理解优先」红线
- ❌ 在本文件复制粘贴关键词清单 → 违反单一权威源原则（应改 `triggers.yaml`）

## 与既有机制的关系

- **与 `~/.codebuddy/skills/tech-doc/config/triggers.yaml` 同步**：本规范是 yaml 中 `doc_sync` + `working_context_drift` 节点的路由消费者，不重复维护关键词；增删关键词只改 yaml
- **与 `references/iteration-fix.md` 互补**：iteration-fix 是「提测/上线后」的修复路径，本规范覆盖「开发中」的澄清回流，二者正交
- **与 `### 恢复指令` 三段式同步**：漂移刷新后必须同步更新 `.flow.recovery.yesterday/next_action/pending`，避免双源不一致
- **与 `## 约束与决策` 删除线规范复用**：本规范不重新定义旧决策的标记格式，统一使用 `~~删除线~~`（详见 `references/working-context.md` § 字段说明 中「约束与决策」行）
