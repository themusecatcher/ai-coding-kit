# 步骤完成标记 JSON Schema 统一定义

> 本文件是所有步骤完成标记 JSON 的**单一真相源（人类可读版本）**。各步骤文件通过引用本文件获取 JSON 模板，
> 避免在每个步骤文件中重复定义完整的 JSON 结构。
> 📌 步骤 0（需求理解）由 `requirement-intake` Skill 独立管理，其 JSON Schema 定义在 `flow.md` 中，不在本文件维护。
> 🤖 **机器可校验版本**：`references/schemas/all-steps.schema.json`（JSON Schema Draft 2020-12）
> 校验方式：`bash ~/.codebuddy/skills/dev-flow/scripts/validate-output.sh
> <step-id> <json-file> <flow-name>`（v2 硬化 2026-04-30：第三参数必传以触发
> `.validated` 物理检查点）
> 详细协议见 `references/gate-validator.md`「Schema 机器校验」章节。

## 通用结构

所有步骤的完成标记 JSON 共享以下顶层字段：

```json
{
"step": "步骤编号",
"name": "步骤名称",
"status": "completed | partial | blocked | skipped",
"outputs": { /* 各步骤特有 */ },
"gate_passed": true,
"gate_checks": {
"json_complete": true,
"outputs_valid": true,
"context_updated": true,
"flow_file_synced": true
},
"working_context_updated": true,
"next_step": "下一步骤编号"
}

```

> 💡 `gate_passed` 和 `gate_checks` 由步骤路由器在门控验证通过后自动填充，各步骤文件的 JSON 模板中无需定义这两个字段。
> 仅 🔴 重量级步骤（4/5/6/7）会输出完整的 `gate_checks`，其余步骤仅校验 `status` + `next_step`。

## 各步骤 outputs 定义

### 步骤 1（研究与定位）

```json
"outputs": {
"related_files_count": "数字",
"upstream_deps": ["上游依赖文件列表"],
"downstream_deps": ["下游消费方文件列表"],
"reusable_components": ["可复用的组件/工具函数"],
"domain_knowledge_confirmed": "true | false | skipped",
"knowledge_loaded": "已加载的知识文件列表 或 none（项目无 knowledge）",
"learnings_matched": "匹配到的历史经验条数（数字）或 0（无匹配/不存在）",
"remote_kb_signals_hit":
  "本步骤命中的 知识库平台 信号数组（如 [] / ['signal_1'] / ['signal_4']；未命中时为 []，代表完全沉默）",
"remote_kb_calls_made": "本步骤实际发起的 MCP 调用次数（数字，默认沉默时为 0）",
"remote_kb_tokens_used": "本步骤 知识库平台 实际消耗 token（数字，默认沉默时为 0；信号 1≤ 1.5k；信号 4≤ 6k）"
}

```

**充分性校验（硬门控，机器校验）**：

```json
"sufficiency_check": {
"codebase_queries_count":
  "本地 codebase_search/grep_search 次数（整数 ≥1；本地始终是真相源，不管 知识库平台 信号是否命中）",
"mcp_queries_count": "知识库平台 MCP 调用次数（整数 ≥0；默认沉默场景为 0）",
"search_queries_count": "codebase + mcp 合计（整数 ≥2；related_files_count ≤2 时必须 ≥3）",
"keyword_variations_tried": ["尝试过的关键词变体（数组，≥2 项）"],
"cross_verified": true,
"confidence": "high | medium（不得为 low，为 low 时 status=blocked）",
"confidence_reason": "置信度理由（一句话）",
"call_graph_drawn": "true | not_applicable（极简模式可 not_applicable）"
}

```

> 📌 本字段已由 `all-steps.schema.json#step1` 强制机器校验，包含 9 条硬规则
> （详见 `step-1-research.md` 充分性校验章节）。任一不通过 → `status: "blocked"`，
> 回到研究阶段补搜索。
> 📌 `remote_kb_signals_hit`、`remote_kb_calls_made`、`remote_kb_tokens_used`
> 由节点信号触达策略驱动，详见 `references/remote-knowledge.md`（单一权威源）。
> 📌 度量采集从本 JSON 读取这些字段写入 `metrics` 的 `remote_kb_metrics` 字段族，
> 详见 `references/metrics-rules.md`「采集流程 3c」。

### 步骤 2（确认范围）

```json
"outputs": {
"modules_count": "数字",
"files_count": "数字",
"impact_levels": {"core": 0, "linked": 0, "verify_only": 0},
"user_confirmed": true
}

```

> 📌 步骤 2 不承担分支推荐职责。分支名推荐仅在步骤 4 §4.1（唯一定稿点），
> 阶段 0 与步骤 1~3 不输出 AI 推荐。详见 `references/shared-rules.md` §6。

### 步骤 3（制定方案）

```json
"outputs": {
"plan_steps_count": "数字",
"risk_level": "low | medium | high",
"files_to_modify": ["待修改文件列表"],
"files_to_create": ["待新增文件列表"],
"boundary_declared": true,
"output_mode": "minimal | standard | detailed",
"minimal_mode_gate_passed": "true | false | not_applicable",
"estimated_loc_change": "预估改动行数（极简模式必填）",
"batch_suggested": "true | false（可选，仅大需求触发批次规划时输出）",
"batch_count": "批次数（可选，batch_suggested=true 时输出）",
"batch_plan": "批次规划数组（可选，batch_suggested=true 时输出，结构见下方说明）",
"similar_mrs_referenced": "引用的历史类似 MR 数量（数字，0 表示未触发或未命中）",
"similar_mrs_source": "知识库平台 | not_applicable（知识库平台 不可用或未触发时为 not_applicable）",
"remote_kb_signal_2_hit": "true | false（本步骤是否触发了信号 2：方案需要历史参考）"
}

```

> 📌 `remote_kb_signal_2_hit` 仅在需求含扩展类动词且项目已接入 知识库平台 时
> 可能为 true，详见 `steps/step-3-plan.md` §1.5。
> 📌 本步骤不包含 `branch_final` / `branch_source` / `branch_name_lint_passed`
> 字段。分支推荐由步骤 4 §4.1 唯一定稿。

### 步骤 4（方案汇报与用户决策）

<!-- markdownlint-disable MD013 -->
```json
"outputs": {
"user_decision":
  "execute_standard | execute_micro | execute_full | execute_partial | execute_batched | modify | change_plan | pause | cancel",
"execution_depth": "standard | micro | full",
"execution_scope": "all | 部分步骤范围（如 1-3）",
"assessment": {
"files_count": "预估文件数",
"lines_estimate": "预估改动行数",
"complexity": "low | medium | high",
"risk_level": "low | medium | high",
"recommended_depth": "standard | micro | full"
},
"plan_locked": true,
"plan_saved_to_context": true,
"plan_saved_to_disk": {
"status": true,
"dir_name": "dev-logs 目录名（如 20260422_fix_移动端表单提交失败）",
"name_lint": {
"format_matched":
  "true | false（正则 ^\\d{8}_(feat|fix|opt|refactor)_[^\\s/\\\\]+$ 匹配）",
"type_valid": "true | false（类型段 ∈ {feat,fix,opt,refactor}）",
"brief_has_chinese": "true | false（简述段至少含 1 个汉字 [\\u4e00-\\u9fa5]）",
"no_project_suffix":
  "true | false（末尾不含 _myProject/_user-project/_crossProject 等项目缩写）"
}
},
"doc_platform_tech_proposal": {
"decision_made": true,
"action": "create | update | relink | skip | auto_inherited_skip",
"probe_executed": "true | false",
"probe_layer": "layer_0 | layer_1 | layer_1_no_match | probe_failed | not_applicable",
"probe_mcp_calls": 0,
"matched_docid": "探测/关联到的 docid（本地模式对应 file_path；create 时为空，skip 时视情况）",
"locked_title": "标题（update/relink 时从文档获取；create 时按格式规范生成）",
"parent_docid": "create 时必填（在线模式为父文件夹 ID；本地模式对应文件路径的目录）",
"trigger_step": "immediate | none"
},
"branch_recommendation": {
"branch": "父分支名（如 feature/ban-long-block）",
"branch_dev": "孙分支名（feature/ 场景且选孙分支时不同于 branch；其他场景= branch）",
"branch_workspace": "用户选定的实际编码分支（= branch 或 branch_dev）",
"has_dev_branch": "true | false",
"branch_status": "auto_recommended | user_modified | user_specified | iteration_reuse",
"branch_name_lint_passed": "true | false | user_specified_skip_lint"
},
"batch_mode": "true | false（可选，用户选择分批执行时为 true）",
"current_batch": "当前批次号（可选，batch_mode=true 时输出）",
"total_batches": "总批次数（可选，batch_mode=true 时输出）"
}

```
<!-- markdownlint-enable MD013 -->

> 📌 `plan_saved_to_disk.name_lint` 四项必须全部为 `true` 才能通过门控（详见 `references/gate-validator.md`）。
> 📌 `plan_saved_to_disk` 简写形式 `true` 已废弃——必须输出结构化对象并填 `name_lint`，禁止偷懒用布尔值。
> 📌 命名规范权威来源：`skills/tech-doc/modules/devlog.md` §一「需求简述语言规范」。
> 📌 **`doc_platform_tech_proposal.decision_made` 必须为 `true`（硬性要求）**。
> 当 `user_decision` 属于执行类（`execute_standard` / `execute_full` /
> `execute_partial` / `execute_batched`）时，此字段必须为 `true`，
> AI 禁止省略环节 3（文档平台）决策。`action=auto_inherited_skip` 仅在
> 迭代修复场景下允许（首轮已明确 skip，自动继承）。详见
> `references/gate-validator.md` §「技术方案文档决策门控」。
> 📌 `branch_recommendation`：当 `user_decision ∈ {execute_standard,
> execute_full, execute_partial, execute_batched}` 时为必填对象，
> 上述 6 个子字段全部必填。详见 `steps/step-4-decision.md` §4.1 +
> `references/shared-rules.md` §6。

### 步骤 4.5（开发环境就绪检查）

```json
"outputs": {
"current_branch": "当前分支名（git branch --show-current 实际值）",
"branch_expected": "期望分支名（工作上下文 branch_workspace 字段值，即步骤 4 §4.1 定稿值）",
"branch_parent": "父分支名（工作上下文 branch 字段值）",
"branch_dev": "孙分支名（工作上下文 branch_dev 字段值，可与 branch 同值）",
"has_dev_branch": "true | false",
"matched_as": "exact | parent_dev_equivalent | none",
"branch_ok": true,
"env_ready": true,
"interaction_path": "silent | user_confirmed | user_skipped"
}

```

> 📌 步骤 4.5 不承担分支推荐职责，仅做一致性校验。`branch_expected`
> 来自工作上下文 `branch_workspace` 字段（由步骤 4 §4.1 写入）。
> 📌 「父孙分支等价」逻辑 → `matched_as: parent_dev_equivalent`
> 表示当前分支是父或孙之一且与定稿集合匹配，视为 🟢 正常。底层字段
> `branch_parent` / `branch_dev` / `has_dev_branch` 供审计使用。
> 📌 `interaction_path` 字段语义（2026-05-06 方案 B 新增，用于审计交互路径）：
>
> - `silent` → 🟢 正常场景静默通过（未弹出 §2 异常处理弹窗；含「父孙等价」场景）
> - `user_confirmed` → 🟡/🔴/⚠️ 异常场景下用户选择「✅ 已切换/已配置完成」
> - `user_skipped` → 🟡/⚠️ 异常场景下用户选择「⏭️ 跳过检查」（🔴 主干分支禁止该路径）
>
> 📌 完整交互矩阵（4 种模式×场景组合）以 `steps/step-4.5-env-check.md` §「步骤推进选项」为准。

### 步骤 5（执行修改）

```json
"outputs": {
"plan_steps_executed": "N/M",
"files_modified": ["实际修改的文件列表"],
"files_created": ["实际新增的文件列表"],
"lint_errors_remaining": 0,
"unplanned_changes": "none | 描述"
}

```

### 步骤 5.5（编码后置钩子）

```json
"outputs": {
"l1_review_result": "passed | fixed_N_issues | skipped_no_changes",
"red_issues_fixed": 0,
"yellow_issues_decision": "all_fixed | all_skipped | partial_fixed | none",
"doc_synced": true,
"lint_pre_check": "pass | has_issues | skipped_no_changes",
"pending_lint_issues": 0
}

```

> 📌 **2026-05-29 字段调整**：原 `lint_clean: true` 已替换为
> `lint_pre_check + pending_lint_issues`，最终 lint 裁决在步骤 6.V3 完成
> （消除 5.5c / 6.V3 重复 lint）。`lint_clean` 字段保留为 deprecated
> 以向后兼容，新流程不再使用。

### 步骤 6（质量验证）

```json
"outputs": {
"6a_result": {
"v1_build": "passed | fixed | skipped",
"v2_typecheck": "passed | fixed | skipped",
"v3_lint": "passed | fixed | skipped",
"v4_browser": "passed | fixed | skipped | not_triggered",
"v5_test": "passed | fixed | skipped",
"v6_security": "passed | fixed | skipped",
"v7_diff": "passed | fixed | skipped"
},
"6b_result": "passed | skipped | partial_issues | failed",
"6c_result": "passed | skipped | not_triggered | paused_waiting"
}

```

### 步骤 7（清理+Commit）

```json
"outputs": {
"debug_code_cleaned": true,
"optional_chain_checked": true,
"unexpected_changes": "none | 描述",
"l2_review_result": "passed | found:{N}_fixed:{M}",
"commit_message": "commit message 摘要",
"devlog_generated": true,
"knowledge_updated": true,
"reflection": "度量驱动反思结论 或 normal_no_anomaly",
"experience_check": "clean | recorded_N | alert_pattern_key",
"metrics_report_generated": true,
"metrics_file": "reports/{需求ID}.yaml",
"flow_report_generated": true,
"flow_report_file": "flow-reports/{需求ID}.html",
"flow_report_opened": true,
"batch_info": "batch N/M（可选，批次模式时输出，如 batch 1/3）",
"batch_next": "下一批次号 或 done（可选，批次模式时输出）"
}

```

> 📦 **批次模式下步骤 7 的字段变化**：
>
> - `devlog_generated`：非最后一批为 `"batch_partial"`（增量 Batch Round），最后一批为 `true`
> - `knowledge_updated`：非最后一批为 `false`（推迟到最后一批），最后一批为 `true`
> - `reflection`：非最后一批不输出，最后一批正常输出
> - `experience_check`：非最后一批不输出，最后一批正常输出
> - `flow_report_generated` / `flow_report_file` / `flow_report_opened`：非最后一批不输出（无度量数据），最后一批输出
> - `batch_info` 和 `batch_next`：仅批次模式时输出
> - `next_step`：非最后一批为 `"batch_next"`，最后一批为 `"done"`（标准执行）或 `8`（完整执行）
>
> 📌 `metrics_report_generated` / `metrics_file` / `flow_report_*` 仅在
> 标准执行（`caller=standard-7`）时填写，完整执行（`caller=full-7`）
> 由步骤 9 负责。

#### 步骤 7 micro-fix v2 轻量保留版专属字段（`caller=micro-fix-7`）

> v2 改造（2026-05-10）：micro-fix 从「全跳」升级为「轻量保留」，5 个轻量环节产出新字段。详细执行规范见 `references/micro-fix-light.md`。

```json
"outputs": {
"branch_safe": true,
"read_lints_passed": true,
"diff_stat_checked": true,
"l1_review_result": "passed_micro_light | fixed_N_issues_micro_light",
"commit_message": "commit message 摘要",
"devlog_appended": "round_appended | monthly_appended",
"knowledge_drift_checked": "no_hits | appended_history | drift_recorded",
"experience_check": "clean | recorded_N | alert_pattern_key",
"devlog_generated": false,
"knowledge_updated": false,
"reflection": "skipped_no_metrics_basis",
"flow_report_generated": false
}

```

> 📌 字段语义说明：
>
> - `devlog_generated`/`knowledge_updated` **保持 `false`**：
>   语义=未生成独立 devlog 文件 / 未沉淀新 knowledge 模块
> - `devlog_appended`/`knowledge_drift_checked` 是 micro-fix v2 新增字段，区分「轻量追加」与「完整生成」
> - `experience_check` 沿用现有 schema 枚举值，`clean` 表示 Q1 Q2 全否的零开销情况
> - `reflection` 固定值 `"skipped_no_metrics_basis"`（micro-fix 不采集 metrics，反思缺数据基础）
> - `flow_report_generated` **必须为 `false`**：micro-fix 不采集 metrics，
>   无源数据，禁止生成单需求 HTML 报告
>
> 📌 向后兼容：旧 micro-fix 完成标记中无以上 v2 字段时，门控容忍但会输出 🟡 告警提示升级。

### 步骤 8（L3 代码审查，完整执行专属）

```json
"outputs": {
"l3_review_result": "passed | found:{N}_fixed:{M}",
"critical_issues": 0,
"doc_sync_checked": true
}

```

### 步骤 9（反思与学习，完整执行专属）

```json
"outputs": {
"metrics_report_generated": true,
"metrics_file": "reports/{需求ID}.yaml",
"flow_report_generated": true,
"flow_report_file": "flow-reports/{需求ID}.html",
"flow_report_opened": true,
"lessons_learned": "经验摘要 或 none",
"flow_reflection": "优化建议摘要 或 smooth_no_suggestions",
"l1_reflection": "度量反思结论 或 normal_no_anomaly",
"rules_created": 0,
"auto_patches_count": 0,
"remote_kb_signal_3_hit": "true | false（本步骤是否触发了信号 3：bugfix 历史踩坑检索）",
"recurring_pitfall_detected": "true | false | not_applicable（信号 3 未触发时为 not_applicable）"
}

```

> 📌 `remote_kb_signal_3_hit` 仅在 need_type=bugfix 且项目已接入 知识库平台 时
> 可能为 true，详见 `steps/step-8-10-full.md` §9b.1。
> 📌 `flow_report_*` 字段语义：
>
> - `flow_report_generated`：必须为 `true`（完整执行步骤 9a 第 6 步必须生成单需求 HTML 报告；脚本失败可为 `false`，需在工作上下文记录失败原因）
> - `flow_report_file`：文件路径相对 `~/.codebuddy/.metrics/` 根目录（如 `flow-reports/{需求ID}.html`）
> - `flow_report_opened`：`true | false`（macOS 默认 true；headless / 远程 SSH 失败时降级为 false，不阻断流程）

### 步骤 10（归档与交付，完整执行专属）

```json
"outputs": {
"commit_message": "commit message 摘要",
"delivery_report": true,
"devlog_generated": true,
"rules_archived": true,
"knowledge_updated": true,
"doc_platform_sync_result": "synced | relinked | created | skipped_no_changes | skipped_user_opt_out"
}

```

> 📌 `doc_platform_sync_result` 必须为上述枚举之一。
> `doc_platform_tech_proposal.action ∈ {skip, auto_inherited_skip}` 时必须为
> `skipped_user_opt_out`；其他 action 必须为
> `synced | relinked | created | skipped_no_changes`。
> 详见 `references/gate-validator.md` §「文档平台 归档同步门控」和
> `steps/step-8-10-full.md` §10.3.5。
> 📌 校验规则详见 `references/gate-validator.md`，本文件仅定义 JSON Schema。
