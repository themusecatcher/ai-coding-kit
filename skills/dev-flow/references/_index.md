# references/ 参考文件索引

> 本文件为参考文件的加载索引，明确每个文件的用途、加载时机和加载者。
> 维护规则：新增/删除/重命名参考文件时，必须同步更新本索引。

## 加载索引

| 参考文件 | 用途 | 加载时机 | 加载者 |
| --- | --- | --- | --- |
| `flow-graph.md` | 统一流程图定义，所有模式的流转路径总览 | 需要理解整体流程时 | 人工查阅 / AI 按需 |
| `working-context.md` | 工作上下文规则、字段语义、命名/创建/更新流程、项目缩写映射表 | 创建新工作上下文时（第0步查模板）/ 更新时查规则 | SKILL.md |
| `templates/working-context.tpl.md` | 工作上下文完整文件模板（YAML Front Matter + Markdown 区块），创建新文件时按此模板填充 | 创建新工作上下文文件时第 0 步必加载 | SKILL.md / step-1-research |
| `active-flows.md` | 活跃流程注册目录（`.active-flows/` 锁文件 v3 schema、智能恢复网关、并发抢占等） | 跨会话恢复 / 步骤完成钩子刷新 `.flow` / 用户询问活跃需求清理 | SKILL.md / step-router / AI 行为规范触发检查 |
| `core-principles.md` | 18 条核心原则详细说明（§1~§18） | dev-flow 加载后按需查阅 | SKILL.md 精要引用 |
| `code-safety-rules.md` | 编码安全规则（lint 验证 + 自检清单） | 步骤 5 执行修改 / 步骤 7 清理后验证 | step-5-execute / step-7-commit |
| `iteration-fix.md` | 迭代修复机制（场景分类下沉脚本，文档保留策略：差异处理/快车道/文档方案继承/.flow 字段/轮次管理/批次切换/运行时溯源） | 检测到迭代修复信号时 | step-router / SKILL.md |
| `rollback.md` | 标准执行回退对照表 | 遇到需要回退的场景时 | step-router |
| `token-management.md` | 对话窗口 Token 管理策略 | 对话中后期（>15 轮）按需加载 | SKILL.md |
| `conversation-quality.md` | 对话质量守卫规范（阈值/预警/抑制规则） | 长对话场景按需加载 | SKILL.md |
| `flow-retrospective.md` | 流程反思模板（步骤 9 深度反思） | 完整执行步骤 9 | flow 步骤 9c |
| `figma-flow.md` | Figma 设计稿处理流程（两级策略） | 用户提供 Figma 链接时 | SKILL.md / flow 阶段 0 |
| `doc-sync-rules.md` | 文档同步规则（三模式通用） | 步骤 5.5 / 步骤 7 / 步骤 8 文档同步兜底 | step-5.5 / step-7 / flow |
| `drift-handling.md` | 需求漂移处理子流程（设计意图 / 三步固定动作 / 反模式 / 与既有机制对照表） | doc-sync-rules §路由分流命中「内部需求/方案漂移」分支时 | doc-sync-rules.md / step-router |
| `in-flow-sync.md` | 流程内文档同步入口（`dev:sync` / `dev:s2`），复用 closeout-flow.md §H.0~H.3+ 文档同步子集 | 流程内 `dev:sync` 命令触发 / AI 主动弹框提醒时 | SKILL.md / flow.md |
| `devlog-rules.md` | 开发日志生成规范 | 步骤 7/10 生成 devlog 时 | step-7 / flow |
| `tech-proposal-flow.md` | 技术方案文档生成/更新流程 | 步骤 4 · 文档决策（环节 3/4） `action ∈ {create, update}` 时；步骤 10.3.5 归档同步时 | step-4-decision / step-8-10-full / SKILL.md |
| `branch-recommendation.md` | 分支命名推荐：输出模板 + 命名约束强制校验 + 与步骤 4.5 衔接（step-4 §4.1 细节下沉） | 步骤 4 §4.1.2 推荐流程第 4 步"输出推荐"时 | step-4-decision §4.1.3 |
| `user-acceptance.md` | 用户验收流程（步骤 6B） | 步骤 6 质量验证阶段 | step-6-verify |
| `integration-flow.md` | 联调流程（步骤 6C） | 步骤 6 质量验证阶段 | step-6-verify |
| `cross-project-flow.md` | 跨项目联调主索引（模式分流 + cross_project 字段 + 单 .flow 架构） | 检测到跨项目信号时按需加载 | step-2 / step-6 / SKILL.md |
| `cross-project/trigger.md` | 跨项目触发与检测（适用场景、信号 4、step-2 挂载、知识库平台 反查） | 步骤 2 检测跨项目时 | cross-project-flow.md |
| `cross-project/handoff.md` | B 项目衔接 prompt 生成与识别（含 profile 预检 C3 场景） | A 步骤 2 / B 项目新对话识别时 | cross-project-flow.md |
| `cross-project/integration.md` | step-6C 联调 / A 项目验证回流 / 契约对齐 / 本地并行 / Diff 规范 | 步骤 6C / 验证回流 / 多仓库同改 | cross-project-flow.md / closeout-flow.md |
| `cross-project/analysis.md` | 跨项目分析型流程三步法（只读不改 + 链式追溯 + 来源标注） | 命中分析型信号时（dev-flow / issue-trace / 普通对话） | cross-project-flow.md / step-1-research.md |
| `tdd-mode.md` | TDD 测试驱动开发模式 | 步骤 5 用户选择 TDD 模式时 | step-5-execute |
| `topic-specs.md` | 专题规范查找表（URL编码、组件库等） | 遇到对应专题场景时 | SKILL.md |
| `component-library.md` | 组件库使用规范 | 步骤 5 涉及 UI 组件时 | step-5-execute |
| `react.md` | React 开发专项规范 | 步骤 5 涉及 React 开发时 | step-5-execute |
| `env-tools.md` | 环境与工具信息（含 Git Worktrees） | 步骤 4.5 环境检查时 | step-4.5-env-check |
| `metrics-rules.md` | 流程度量机制（数据模型、采集、报告、统计分析、可视化仪表盘） | 最终步骤完成钩子（步骤7/10） | step-7 / flow |
| `templates/dashboard.tpl.html` | 度量可视化仪表盘 HTML 模板（ECharts v5 + Tabulator v6，`__METRICS_DATA__` + `__HOME_DIR__` 占位符） | 度量采集流程第 8 步 / `dev:metrics --dashboard` | metrics-rules.md |
| `templates/flow-report.tpl.html` | 单需求复盘报告 HTML 模板（5 区块布局，CSS 变量复用 dashboard） | 步骤 7/10 复盘报告生成 | metrics-rules.md |
| `gate-validator.md` | 门控校验规范（每步骤结构化校验规则） | 步骤完成后、加载下一步骤前 | step-router |
| `interaction-mode.md` | 精简交互模式（风险分级、交互点行为定义） | 精简模式触发时 / 步骤开始前检查交互模式 | step-router / SKILL.md |
| `closeout-flow.md` | 步骤 7 收尾子流程规范（commit / devlog / knowledge / 文档平台 对账闭环；`caller=standard-7` / `full-7` / `batch-7` / `micro-fix-7` 共用；§H.3+ 兜底对账子流程同时被 `caller=full-10` 复用）。原名 `wrapup-flow.md`，2026-06-03 重命名 | 步骤 7 加载时 | step-7-commit（`read_file`） |
| `output-schemas.md` | 步骤完成标记 JSON 统一模板定义 | 各步骤输出完成标记时 | 各步骤文件 |
| `shared-rules.md` | 共享规则单一真相源（Commit/沉淀/并行执行策略/角色/钩子/分支） | 涉及共享规则时按需引用 | SKILL.md / 各步骤文件 |
| `call-graph-spec.md` | 代码调用/依赖关系可视化规范（文本树+Mermaid 双格式） | 步骤 1 画调用图时 / 步骤 2/3/6/iteration-fix 引用时 | step-1/2/6 / iteration-fix |
| `remote-knowledge.md` | 知识库平台 节点信号触达单一权威源（5 信号 + 项目映射 + Token 策略 + 噪声过滤 + CLI 覆盖 + 量化收益） | 信号判定 / 信号命中需 MCP 调用 / 项目映射查询时（非每次 dev-flow 加载） | step-1 / step-3 / step-9 |
| `onboard-flow.md` | `dev:onboard` 命令流程与 profile 生命周期（按需生成，不再自动推销） | `dev:onboard` 触发 / 信号 1 判定时验 profile 新鲜度 | SKILL.md / step-1 |
| `mode-matrix.md` | dev-flow 所有执行模式的单一真相源（6 种基础模式 + micro-fix 轻量模式 + streamlined 修饰层 × 11 步骤 × 触发信号 × 加载差异 × 优先级） | AI 不确定当前模式时 / 多模式信号同时触发时 / 模式切换时 | SKILL.md / flow / step-router |
| `no-dev-flow-mode.md` | 无 dev-flow 时直接改代码的简化质量检查规则（从「开发规范-红线」迁出的详细版） | 用户未走 dev-flow 但要求改代码时 | SKILL.md / skill-full.md |
| `micro-fix-light.md` | micro-fix v2 轻量保留版执行规范（轻量保留的 5 个环节执行边界、成本上限、自动降级触发、三道防线） | `caller=micro-fix-7` 执行时 / 查阅 micro-fix 环节执行细节时 | step-7-commit / mode-matrix |
| `skill-full.md` | SKILL.md 完整备份（P0 精简前的原始内容，309 行） | SKILL.md 精简版无法解决的边界情况时 | SKILL.md 按需加载 |
| `dist-sync.md` | dist 目录同步提醒：修改 dev-flow 依赖组件（Skill/规则/Agent）后，提醒用户执行 `bash package.sh` 同步到 `dist/` | 全局生效（修改依赖组件后 AI 自动提醒） | AI 全局规则 |
| `schemas/all-steps.schema.json` | 所有步骤完成标记 JSON 的机器可校验 Schema（JSON Schema Draft 2020-12） | 每个步骤完成标记输出后校验时 | gate-validator.md / validate-output.sh |
| `schemas/README.md` | schemas/ 目录说明（校验器用法、关键规则、维护规则） | 了解 Schema 校验机制时 | 人工查阅 |

## 按步骤的加载清单

| 步骤 | 必须加载 | 按需加载 |
| --- | --- | --- |
| SKILL.md 入口 | — | `working-context.md`（创建时）、`figma-flow.md`（有 Figma 链接时）、`onboard-flow.md`（`dev:onboard` 命令触发时） |
| 阶段 0.5 画像预注入 | — | 默认不加载 知识库平台 相关文件（仅 profile 存在时读本地 `_profile.md`） |
| 步骤 1 研究 | — | `use_skill('knowledge-loop')`（检索模式）、`.learnings/`（检索历史经验）、`call-graph-spec.md`（画调用图时）、`remote-knowledge.md`（仅信号 1首次接触或信号 4跨项目命中时才加载） |
| 步骤 3 方案 | — | `tech-proposal-flow.md`（用户要求技术方案时）、`remote-knowledge.md`（仅信号 2方案需历史参考命中时） |
| 步骤 9 反思 | `flow-retrospective.md` | `remote-knowledge.md`（仅信号 3：bugfix 场景命中时） |
| 步骤 4.5 环境 | — | `env-tools.md`（含 Git Worktrees） |
| 步骤 5 执行 | `code-safety-rules.md` | `tdd-mode.md`、`component-library.md`、`react.md` |
| 步骤 5.5 后置 | — | `doc-sync-rules.md` |
| 步骤 6 验证 | — | `user-acceptance.md`（6B）、`integration-flow.md`（6C） |
| 步骤 7 清理+Commit | `code-safety-rules.md` | `use_skill('knowledge-loop')`、`devlog-rules.md`、`doc-sync-rules.md` |
| 步骤 8 L3 审查 | — | `doc-sync-rules.md` |
| 步骤 9 反思 | `flow-retrospective.md` | — |
| 步骤 10 归档 | `use_skill('knowledge-loop')`、`devlog-rules.md` | — |
| 迭代修复 | `iteration-fix.md` | — |
| 回退场景 | `rollback.md` | — |
| Token 紧张 | `token-management.md` | — |

## 条件激活矩阵（借鉴 Hermes Skills）

> 为减少无意义加载，声明每个 reference 的「触发信号」。
> AI 加载前先检测工作上下文中是否存在对应信号，未命中则跳过加载。
> 信号约定：小写下划线命名，存储于工作上下文 `## 元数据 > signals` 字段。

| 参考文件 | requires_signals（任一命中即加载） | 无信号场景默认 |
| --- | --- | --- |
| figma-flow.md | figma_url, figma_screenshot | 不加载 |
| cross-project-flow.md | cross_project, external_workspace_modification | 不加载 |
| cross-project/trigger.md | cross_project_signal_detected, step_2_cross_project_check | 不加载 |
| cross-project/handoff.md | cross_project_handoff_generated, b_project_handoff_received | 不加载 |
| cross-project/integration.md | step_6c_cross_project, a_project_verify_returning, parallel_repos_modified | 不加载 |
| cross-project/analysis.md | analysis_type_cross_project, import_external_pkg, issue_trace_invoked | 不加载 |
| tdd-mode.md | user_select_tdd, has_jest_config | 不加载 |
| tech-proposal-flow.md | user_request_tech_doc, has_doc_platform_link, step_4_action_in_create_update | 不加载（step_4_action ∈ {skip, auto_inherited_skip, relink} 时） |
| integration-flow.md | step_6c_triggered, need_lian_tiao | 不加载 |
| user-acceptance.md | step_6b_triggered | 不加载 |
| iteration-fix.md | iteration_signal_detected, matched_existing_wc | 不加载 |
| rollback.md | rollback_requested | 不加载 |
| token-management.md | conversation_rounds_gt_15, token_pressure | 不加载 |
| devlog-rules.md | step_7_commit, step_10_archive | 步骤 7/10 默认加载 |
| doc-sync-rules.md | doc_related_change, api_schema_change | 不加载 |
| react.md | changed_files_include_tsx, changed_files_include_react | 不加载 |
| component-library.md | ui_component_change, imports_met_component | 不加载 |
| env-tools.md | step_4_5_env_check, worktree_related | 步骤 4.5 默认加载 |
| call-graph-spec.md | step_1_research, need_call_graph | 不加载 |
| remote-knowledge.md | step_1_research, step_3_plan, step_9_reflection, remote_kb_signal_1_hit, remote_kb_signal_2_hit, remote_kb_signal_3_hit, remote_kb_signal_4_hit, remote_kb_signal_5_hit, cli_override_present | 步骤 1/3/9 时判断是否命中信号才加载（未命中则不加载，默认沉默） |
| `onboard-flow.md` | dev_onboard_cmd, profile_missing, profile_expired, profile_drift_detected, remote_kb_signal_1_hit | 不加载 |
| micro-fix-light.md | mode_micro_fix, caller_micro_fix_7 | 仅在 micro-fix 模式下加载 |
| active-flows.md | cross_session_recovery, flow_lock_refresh, user_query_active_flows | 不加载（创建工作上下文场景不需要） |
| drift-handling.md | drift_signal_detected, doc_sync_route_to_drift, comm_feedback_in, requirement_negation, clarification_adjust | 不加载（仅 doc-sync-rules 路由命中 B/C/D 类关键词时加载） |
| mode-matrix.md | mode_ambiguous, mode_conflict, mode_switch_requested | 不加载 |
| flow-retrospective.md | step_9_retrospective, full_execution | 完整执行步骤 9 默认加载 |
| metrics-rules.md | final_step_hook, dev_metrics_cmd | 最终步骤默认加载 |
| dist-sync.md | skill_modified, rule_modified, agent_modified | 全局生效，不依赖 dev-flow 加载 |
| templates/dashboard.tpl.html | dev_metrics_dashboard | 不加载 |

### 加载决策协议

1. AI 需要加载某个 reference 时，先查本矩阵中的 `requires_signals` 列。
2. 若未列出（默认） → 按「加载索引」主表中的时机加载。
3. 若列出 requires_signals → 从工作上下文 `signals` 数组中检查。
4. 任一信号命中 → 加载；全部未命中 → 跳过加载（静默）。
5. 特殊情况：用户明确指令「加载 X」 → 强制加载，跳过信号检查。

### 信号来源与维护

- **阶段 0 写入**：needs 收集时自动推断 figma_url / has_doc_platform_link 等基础信号
- **步骤 1 写入**：研究阶段确认的 changed_files_include_tsx / cross_module_impact 等结构信号
