# 门控校验规范（Gate Validator）

> 本文件定义每个步骤的结构化校验规则。步骤路由器在加载下一步骤前，必须按本文件验证完成状态。
> 校验级别与 step-router.md「分级钩子定义」对应。

## 校验协议

```text

1. 验证步骤状态为 completed（非 in_progress/blocked/skipped）
2. 按下方对应级别的校验规则验证 outputs
3. 验证工作上下文和 .flow 文件已同步
4. 验证物理检查点（v2 硬化，所有步骤间强制）：
ls ~/.codebuddy/working-context/.active-flows/{flow-name}.step-{N}.validated
⚠️ 文件名编码规则：{N} 中的 . 会被脚本替换为 _
步骤 4.5 → 实际文件名 .step-4_5.validated
步骤 5.5 → 实际文件名 .step-5_5.validated
其他整数步骤不变（如 .step-5.validated）
文件不存在 → 🔴 红牌 #14（v2）或 #10（v1 兼容），回退到步骤 N 重新调用 validate-output.sh
⚠️ .validated 只能由脚本创建，AI 禁止手动 touch 伪造

5. 全部通过 → 加载下一步骤；任一失败 → 立即补齐

```

## 分级校验规则

### 🟢 轻量级校验（步骤 1、2、4.5、9、10）

仅校验 `status` 和 `next_step` 有效，加上每步 1-2 个核心字段：

| 步骤 | 核心校验 | 失败处理 |
| --- | --- | --- |
| 1 研究 | `related_files_count` > 0 + `sufficiency_check.call_graph_drawn` ∈ {true, not_applicable} | 补充搜索 / 补画调用图 |
| 2 范围 | `user_confirmed` = true + `call_graph_referenced` 与 step-1 对齐 | 等待用户确认 / 补引用调用图 |
| 4.5 环境 | `env_ready` = true | 解决环境问题 |
| 9 反思 | `metrics_report_generated` = true | 补充反思 |
| 10 归档 | `devlog_generated` = true + `knowledge_updated` = true + `commit_message` 非空 | 补齐缺失项 |

### 🟡 中量级校验（步骤 3、5.5、8）

校验关键 outputs 字段，不逐项列出完整清单：

| 步骤 | 核心校验 | 失败处理 |
| --- | --- | --- |
| 3 方案 | `plan_steps_count` > 0 + `boundary_declared` = true | 补充方案 |
| 5.5 后置 | `l1_review_result` 非空 + `lint_pre_check` ∈ {pass, has_issues, skipped_no_changes}（编译级错误必须当场修复，不传递）；最终 lint 裁决在步骤 6.V3 | 修复 L1 问题 / 修复编译级错误 |
| 8 L3审查 | `l3_review_result` 非空 + `critical_issues` = 0 | CRITICAL 回退步骤5 |

### 🔴 重量级校验（步骤 4、5、6、7）

完整逐项校验所有 outputs，含 gate_checks 四项检查：

| 步骤 | 完整校验项 | 特殊规则 |
| --- | --- | --- |
| 4 决策 | `user_decision` ∈ {execute_standard,execute_micro,execute_full,execute_partial,execute_batched,modify,change_plan,pause,cancel} + `execution_depth` ∈ {standard,micro,full} + `outputs.assessment.recommended_depth` ∈ {standard,micro,full} + `plan_locked` = true + `plan_saved_to_context` = true + `plan_saved_to_disk.status` = true + `plan_saved_to_disk.name_lint.*` 四项全部为 true + `doc_platform_tech_proposal.decision_made` = true + `doc_platform_tech_proposal.action` ∈ {create,update,relink,skip,auto_inherited_skip} + **`doc_platform_lint` 7 项全部通过** | ⚠️ user_decision 必须来自用户明确表态，禁止 AI 自动填充；plan.md 须实际写入磁盘；目录命名 lint 四项任一失败即拒绝推进；**文档决策硬性必走**：当 user_decision 为执行类时，doc_platform_tech_proposal.decision_made 必须为 true，禁止 AI 以任何理由省略环节 3（文档决策）；lint 项 7「parent_docid_verified」校验 create 时子类型目录合法（在线模式校验 parent_docid，本地模式校验文件路径目录） |
| 5 编码 | `files_modified` 非空 + `plan_steps_executed` 格式 "N/M" 且 N > 0 + `lint_errors_remaining` = 0 | ⚠️ files_modified 须与步骤3方案对应，偏差须在 unplanned_changes 中说明 |
| 6 验证 | `6a_result` 所有阶段有值 + `6b_result` 非空 + `6c_result` 非空 | ⚠️ 质量关卡，6c 暂存时 status 为 blocked，失败触发回退（详见 flow-graph.md） |
| 7 清理（标准执行） | `l2_review_result` 非空 + `commit_message` 非空 + `debug_code_cleaned` = true + `devlog_generated` = true + `knowledge_updated` = true + `metrics_report_generated` = true + `reflection` 非空 | ⚠️ devlog_generated 和 knowledge_updated 禁止为 false/skipped；全部通过才能结束流程 |
| 7 清理（完整执行） | `l2_review_result` 非空 + `debug_code_cleaned` = true | ⚠️ commit/devlog/knowledge/reflection 推迟到步骤10，此处不校验 |
| 7 清理（批次执行） | `l2_review_result` 非空 + `debug_code_cleaned` = true + `commit_message` 非空 + `devlog_generated` ∈ {true,"batch_partial"} | ⚠️ 非最后一批时 `devlog_generated` 可为 `"batch_partial"`；`knowledge_updated` 不校验（推迟到最后一批）；最后一批按标准执行规则校验 |

### 工作上下文 artifacts 完整性门控（跨步骤，2026-07-13 新增）

> **设计意图**：`artifacts` 是需求所有关联产出物的统一路径索引。本条门控确保各步骤完成后 `artifacts` 对应字段已写入且指向的文件/目录真实存在于磁盘。

| 检查点 | 触发时机 | 校验项 | 失败处理 |
| --- | --- | --- | --- |
| A1 | 步骤 4 完成后 | `artifacts.dir` 非空 + `[ -d $dir ]`；`artifacts.plan` 非空 + `[ -f $plan ]`；`artifacts.flow_lock` 非空 + `[ -f $flow_lock ]` | 🔴 拒绝进入步骤 4.5 |
| A2 | 步骤 4 文档决策后 | 若 `doc_platform_tech_proposal.docid` 非空 → `artifacts.doc_platform.docid` 必须与之相等 | 🟡 自动补齐（从 `doc_platform_tech_proposal` 同步） |
| A3 | dev:sync 执行时 | 遍历 `artifacts` 中所有非 null 路径，`[ -f ]` / `[ -d ]` 确认存在 | ⚠️ 失效路径输出警告，不阻断恢复 |
| A4 | 步骤 7（标准）完成后 | `artifacts.devlog` ≠ null + `[ -f ]`；`artifacts.knowledge` 非空数组；`artifacts.metrics` ≠ null + `[ -f ]`；`artifacts.flow_report` ≠ null + `[ -f ]` | 🔴 拒绝标记流程完成 |
| A5 | 步骤 7（完整）完成后 | 仅 A2（文档平台 docid 自动补齐）；devlog/metrics/flow_report 推迟到步骤 10 由 A6 校验 | 🟡 |
| A6 | 步骤 10（完整）完成后 | 同 A4（devlog ≠ null + metrics ≠ null + flow_report ≠ null + knowledge 非空） | 🔴 拒绝归档 |

**实施**：由步骤完成钩子（动作2 状态同步）在更新工作上下文时同步校验。A1/A4/A6 为硬阻断（拒绝进入下一步骤/标记完成），A2/A3 为自动修复或告警。

## 通用失败处理策略

| 失败类型 | 处理方式 | 最大重试 |
| --- | --- | --- |
| JSON 字段缺失 | 立即补齐 | 1次 |
| outputs 值无效 | 重新执行对应子任务 | 2次 |
| 工作上下文/flow 未同步 | 立即同步 | 1次 |
| 用户确认缺失 | 暂停等待用户响应 | 无限制 |
| 连续3次校验失败 | 输出诊断信息，请求用户介入 | — |

> 📌 本文件是门控校验的唯一权威来源。步骤路由器中的门控清单为精简版，完整校验规则以本文件为准。

## Schema 机器校验（与文字规则并行执行）

> 本章节定义基于 JSON Schema 的机器校验机制，作为文字校验规则的补充。
> Schema 文件真相源：`references/schemas/all-steps.schema.json`

### 校验时机（v2 硬化版 — 2026-04-30）

每个步骤完成标记 JSON 输出**之后**、加载下一步骤文件**之前**，**必须**按以下流程校验（违反即红牌 #14）：

```text

1. AI 将完成标记 JSON 写入临时文件（可用 heredoc）：
/tmp/dev-flow-step-{N}-output.json

2. 调用校验脚本（⚠️ 第三参数 flow-name 是触发物理检查点的关键）：
bash ~/.codebuddy/skills/dev-flow/scripts/validate-output.sh \
{step-id} /tmp/dev-flow-step-{N}-output.json {flow-name}

其中 {flow-name} 从工作上下文文件名推导（去掉 .md 后缀），
例如文件名为 20260430_feat_doc_platform_my-project.md → flow-name=20260430_feat_doc_platform_my-project

3. 根据返回码处理：
- 0 → Schema 通过 + .validated 文件已由脚本自动创建 → 加载下一步骤
- 1 → JSON 格式错误，补齐 JSON 后重新校验
- 2 → Schema 校验失败，.validated **不会**被创建，按错误提示修正 outputs 后重试
- 3 → ajv-cli 缺失，自动降级到 jq-only（仍会创建 .validated，标注 validator_type: jq-only）

4. 连续 3 次 Schema 校验失败 → 按「通用失败处理策略」升级为用户介入

```

**⚠️ 硬性规则**（违反即 🔴 红牌 #14）：

1. 步骤完成标记 JSON 输出后，**必须**立即调用 `validate-output.sh`；缺调用即视为未完成校验
2. 调用时**必须传递**第三参数 `flow-name`（缺失则只校验不生成物理检查点，会导致下一步骤加载时检查点缺失 → 红牌）
3. 禁止 AI 手动 `touch` `.step-{N}.validated` 文件（伪造校验通过）
4. 校验返回码 ≠ 0 时，**禁止**加载下一步骤文件

**加载下一步骤前的强制预检**（`ls` 物理检查点）：

```bash

# 在 read_file("steps/step-{N+1}-xxx.md") 之前必须执行：
ls ~/.codebuddy/working-context/.active-flows/{flow-name}.step-{N}.validated

# → 存在：通过，可加载下一步骤

# → 不存在：🔴 红牌 #14，回退到步骤 N 重新调用 validate-output.sh

```

### 物理检查点白名单（按基础模式分流，硬性规则）

> **设计意图**：不同基础模式跳过的步骤集不同，预检逻辑必须按 `mode` 分流，否则 micro-fix 等精简模式会因不存在的前置 .validated 文件而误触红牌 #14。
> 📌 **单一权威源**：白名单矩阵和预检算法**已下沉到脚本** `scripts/precheck/physical-checkpoint.sh`。
> 白名单配置维护在 `config/gates.yaml` §physical_checkpoints。本节仅保留「调用约定」和「关键规则」。

### 调用约定

```bash

# 加载下一步骤前的强制预检（替换 AI 手动 ls 检查）
bash ~/.codebuddy/skills/dev-flow/scripts/precheck/physical-checkpoint.sh \
<flow-name> <target-step-id>

# 示例：
bash scripts/precheck/physical-checkpoint.sh "20260514_feat_用户登录" 5

# → 自动读取 .flow 中的 mode，按 7 种模式之一的白名单做预检

# → 缺失任一前置 .validated 即返回 1（红牌 #14）

```

**支持的 6 种 mode**：standard / full / micro-fix / iteration-fix / batch / cross-project

完整白名单矩阵见 `config/gates.yaml` §physical_checkpoints（人类可读索引）+ `scripts/precheck/physical-checkpoint.sh::get_required_steps()`（机器执行真相）。

### 关键规则

1. **白名单外的 .validated 缺失不视为红牌**：micro-fix 模式下 `step-1.validated` 不存在是设计预期，不报错
2. **白名单内的 .validated 缺失即红牌 #14**：micro-fix 模式下 `step-5.validated` 不存在 → 必须回退重做
3. **mode 切换时白名单切换**：以**新 mode** 为准，旧白名单立即失效；新 mode 下缺失的 .validated 必须补做
4. **柔性升级 standard→full**：保留 standard 已生成的所有 .validated，新增 step-8/9/10 的检查
5. **AI 不得自行扩展或缩减白名单**：白名单由脚本锁定，禁止根据"任务简单"等理由放宽

### 兼容性（v2 双轨过渡）

- **新流程**：使用 `scripts/precheck/physical-checkpoint.sh` 自动预检
- **旧流程（已激活）**：保留 AI 手动 `ls` 检查作为兜底，确保活跃流程零中断
- **降级**：脚本不可执行时回退到 AI 手动 ls 路径

> 完整规则细节见脚本 + `config/gates.yaml`，禁止在本文件重复维护白名单矩阵。

### step-id 对照表

| 步骤 | step-id 参数 | 典型失败点 |
| --- | --- | --- |
| 1 研究 | `1` | related_files_count=0 / sufficiency_check 缺字段 / confidence=low / search_queries_count<2 / cross_verified!=true |
| 2 范围 | `2` | user_confirmed!=true |
| 3 方案 | `3` | boundary_declared=false / plan_steps_count=0 |
| 4 决策 | `4` | name_lint 四项 / user_decision 越界 / **execute_* 下 branch_recommendation 子字段缺失或 branch 格式不对** |
| 4.5 环境 | `4.5` | env_ready/branch_ok!=true / matched_as=none 且 非 🔴 场景未设为 user_confirmed |
| 5 编码 | `5` | files_modified 空 / lint_errors_remaining>0 |
| 5.5 后置 | `5.5` | lint_pre_check 字段缺失或非合法枚举 / 预检 has_issues 但 pending_lint_issues=0（语义矛盾） |
| 6 验证 | `6` | 6a/6b/6c 任一字段缺失 |
| 7 标准执行 | `7-standard` | 七项产出任一为 false/空 |
| 7 完整执行 | `7-full` | l2_review_result 为空 |
| 7 批次执行 | `7-batch` | batch_info 格式不对 |
| 7 micro-fix | `7-micro-fix` | commit_message 空 / read_lints_passed≠true / branch_safe≠true / diff_stat_checked≠true / l1_review_result 不是 passed_micro_light\| fixed_N_issues_micro_light / devlog_appended 不是 round_appended\| monthly_appended / knowledge_drift_checked 不是 no_hits\| appended_history\| drift_recorded / experience_check 不是 clean\| recorded_N\| alert_pattern_key（v2 轻量保留版新增校验；devlog_generated/knowledge_updated/reflection 按设计仍为 false，不校验为 true） |
| 8 L3审查 | `8` | critical_issues>0 |
| 9 反思 | `9` | metrics_report_generated!=true |
| 10 归档 | `10` | commit/devlog/knowledge 任一缺失 |

### 与文字规则的关系

| 维度 | Schema 校验 | 文字规则（本文件其他章节） |
| --- | --- | --- |
| 校验对象 | JSON 结构、类型、枚举、正则 | 业务语义、跨字段一致性、用户确认 |
| 执行方式 | `validate-output.sh` 自动执行 | AI 自觉遵守、步骤路由器检查 |
| 失败处理 | 返回码 2，硬性拦截 | 按失败类型走「通用失败处理策略」 |
| 优先级 | 结构层校验（先执行） | 语义层校验（后执行） |

**双层校验的价值**：

- Schema 校验能机械拦截 80% 的结构性错误（字段缺失、类型错误、枚举越界、正则不匹配）
- 文字规则仍负责 Schema 无法表达的语义校验（如"用户确认来自用户明确表态，禁止 AI 自动填充"）

### 降级策略

- `ajv-cli` 未安装 → 脚本自动降级到 `jq-only` 模式，仍可校验必需字段和关键枚举
- `jq` 未安装 → 退出码 3，AI 转而使用文字规则校验，不阻塞流程
- 建议全局安装：`npm install -g ajv-cli ajv-formats`（完整 Schema 校验能力）

## 路径可点击性门控（全步骤强制）

> 本门控对应 `~/.codebuddy/rules/AI行为规范.mdc` 的「文件/代码位置引用」规范。
> **统一格式**：反引号包裹相对路径 `` `相对路径` `` + 空格后缀行号 `L行号`。
> 📌 **单一权威源**：扫描规则、正则、豁免范围、严重度分级**已全部下沉到脚本** `scripts/lints/path-lint.sh`，
> 规则配置维护在 `config/gates.yaml` §lints.path-lint。本节仅保留「触发时机」和「调用约定」。

### 触发时机

| 触发点 | 扫描范围 | 调用约定 |
| --- | --- | --- |
| 步骤 1 研究结果报告 | files_table 表格 | `bash scripts/lints/path-lint.sh <step-1-report.md>` |
| 步骤 2 影响范围报告 | 文件列单元格 | 同上 |
| 步骤 3 批次规划表 | 涉及文件列 | 同上 |
| 步骤 7 合并审查报告 | 改动汇总 + L2 问题定位 | 同上 |
| 步骤 10.5 交付报告 | 全量报告 | 同上 |
| 迭代修复报告 / 验证报告 | 涉及文件清单 | 同上 |

### 退出码处理

- `0` 通过 → 步骤推进
- `1` Block 违规（R1/R4） → 🔴 拒绝推进，最多 2 次自动修复，第 3 次升级用户介入
- `2` Warn 违规（R2/R3/R5） → 🟡 输出告警 + 自动建议修复片段，允许用户确认继续

> 完整规则细节见脚本注释和 `config/gates.yaml` §lints.path-lint，禁止在本文件重复维护。

## 交互式选项一致性门控（全决策点强制）

> 本门控对应 `~/.codebuddy/rules/AI行为规范.mdc` §「交互式选项一致性规则」和 `steps/step-router.md`
> §「交互式决策强制规则」+ §「步骤流转交互规则」。对所有用户决策点和步骤流转衔接点执行半自动校验，违规视为红牌 #7 / #13。
> 📌 **单一权威源**：C1-C8 校验规则、精简模式豁免列表、严重度分级**已下沉到脚本** `scripts/lints/interactive-options-lint.sh`。
> 决策点完整清单维护在 `steps/step-router.md` §「需要使用交互式选项的决策点清单」（单一真相源）。
> 本节仅保留「触发场景」和「调用约定」。

### 触发场景

1. **用户决策点**：知识确认、范围确认、方案决策、环境确认、L1/L2 黄项、熔断、验收、联调、commit 确认、文档平台 方案、迭代评估、跨项目衔接等
2. **步骤流转衔接点**：步骤 N 完成后进入步骤 N+1 的推进选项（精简模式豁免 4 处流转：0.5→1 / 4.5→5 / 5→5.5 / 5.5→6，详见脚本内嵌豁免列表）

### 调用约定（2）

```bash

# AI 在每次输出含 ask_followup_question 的回合，先把当前回合元信息写入 snapshot：
cat > /tmp/df-conversation-snapshot.json <<EOF
{
"text_options_count": 4,
"ask_followup_question_options_count": 4,
"interaction_mode": "standard",
"decision_point": "step-4-execution-depth",
"current_transition": "4->4.5",
"ask_followup_called_in_round": true,
"text_keywords_in_round": [],
"text_has_star": true,
"options_has_star": true
}
EOF

# 然后调用 lint：
bash ~/.codebuddy/skills/dev-flow/scripts/lints/interactive-options-lint.sh \
/tmp/df-conversation-snapshot.json

```

### 退出码处理（2）

- `0` 通过 → 推进
- `1` Block 违规（C1/C2/C3/C5/C6/C7/C8）→ 🔴 红牌 #7/#13，输出"正在回退补齐" → 重新弹出合规的交互式选项；最多 2 次自动修复，第 3 次升级用户介入
- `2` Warn（C4 维护期）→ 仅 PR 审查时报告，运行期不拦截

### 自检清单（AI 调用 `ask_followup_question` 前逐项核对）

1. □ 已输出文本选项表格（`| 选项 | 说明 |` 格式）
2. □ 文本表格行数 === `ask_followup_question` options 数组长度
3. □ 若存在条件性选项，已按触发条件判断是否显示
4. □ 若是步骤完成后的推进选项，已读取 `interaction_mode` 确认非豁免流转
5. □ 若本回合出现「弹出交互式选项」字样，确保已调用 `ask_followup_question` 工具
6. □ 若文本表格有 ⭐ 推荐标识，确保 `ask_followup_question` 对应 option 的 `label` 以 `⭐ [推荐] ` 开头（C8）

> 完整规则细节见脚本 + `config/gates.yaml` §lints.interactive-options-lint，禁止在本文件重复维护。

### 语义层机械兜底（2026-07-01 新增）

> 上述 C1-C8 lint 依赖 AI 主动写 snapshot → 调用脚本，存在「AI 可绕过」的缺口（反复出现只输出文本表格但未调用 `ask_followup_question` 的问题）。

**新增机制**：`scripts/hooks/post-step.sh` 步骤 1.6 会对每个步骤的完成标记 JSON 做 `interactive_progression_shown` 字段的语义兜底校验：

| 模式 | 流转 | 校验行为 |
| --- | --- | --- |
| 标准模式 | 所有流转 | `interactive_progression_shown` 必须为 `true`，缺即 exit 1 |
| 精简模式 | 豁免流转（0.5→1, 4.5→5, 5→5.5, 5.5→6） | 跳过校验 |
| 精简模式 | 非豁免流转 | 同标准模式，必须为 `true` |

**与 C1-C8 lint 的分工**：

- C1-C8 lint：运行时可选校验（AI 主动写 snapshot → 调用），用于实时对话质量检查
- `interactive_progression_shown` 字段校验：post-step hook 机械兜底，无需 AI 配合即可拦截遗漏

> ⚠️ 该字段在 JSON Schema 中为 optional（不影响旧产物），语义强制全在 post-step.sh 中。详细实现见 `steps/step-router.md` §「动作 1：输出结构化完成标记」。

## dev-logs 目录命名门控（步骤 4 专属）

> 本门控对应 `skills/tech-doc/modules/devlog.md` §一「需求简述语言规范」。在步骤 4 创建 `~/.codebuddy/dev-logs/` 目录并保存 plan.md 前/后强制执行。
> 📌 **单一权威源**：name_lint 4 项规则的判定逻辑**已下沉到脚本** `scripts/lints/devlog-dir-name-lint.sh`。
> 规则配置维护在 `config/gates.yaml` §lints.devlog-dir-name-lint。本节仅保留「检查时机」和「调用约定」。

### 检查时机

1. **创建目录前**（强制）：步骤 4 决定保存 plan.md 时，先调用 devlog-dir-name-lint.sh 计算 4 项 boolean，
   写入 step-4 完成标记 JSON 的 `plan_saved_to_disk.name_lint`，任一为 false → 修正目录名后再 `mkdir -p`
2. **创建目录后**（自动）：步骤 4 完成标记 JSON 输出后，`validate-output.sh` 校验 `plan_saved_to_disk.name_lint` 四项，任一为 false → 拒绝进入步骤 4.5

### 调用约定（3）

```bash

# AI 在步骤 4 准备创建 dev-logs 目录前：
DIR_NAME="20260514_feat_用户登录优化"
eval "$(bash ~/.codebuddy/skills/dev-flow/scripts/lints/devlog-dir-name-lint.sh --shell "$DIR_NAME")"

# 这会注入 4 个变量：

#   $name_lint_format_matched

#   $name_lint_type_valid

#   $name_lint_brief_has_chinese

#   $name_lint_no_project_suffix

# 然后写入 step-4 完成标记 JSON 的 plan_saved_to_disk.name_lint 字段

```

### 自动修复建议

- 简述为纯英文短横线 → 禁止机械替换，必须基于 working-context `## 需求` 章节的中文描述或用户输入重新生成中文简述
- 末尾带项目缩写 → 直接 `mv` 去掉后缀即可
- 类型段错误（如 `bug` 应写 `fix`） → 映射：Bug → `fix`、需求 → `feat`、优化 → `opt`、重构 → `refactor`

### 违规处理

- 任一项 false → 🔴 Block，最多 2 次自动修复重试，第 3 次升级用户介入
- 历史案例参考 `.learnings/ERRORS.md`「2026-04-28 · dev-logs 目录命名错误」

### 存量审计（按需）

```bash

# 扫描 ~/.codebuddy/dev-logs/ 下所有目录
for d in ~/.codebuddy/dev-logs/*/; do
bash ~/.codebuddy/skills/dev-flow/scripts/lints/devlog-dir-name-lint.sh --raw "$(basename "$d")" \
&& echo "✅ $(basename "$d")" \
|| echo "❌ $(basename "$d")" |
done

```

> 完整规则细节见脚本 + `config/gates.yaml` §lints.devlog-dir-name-lint，禁止在本文件重复维护。

## dev-logs 物理事实兜底（P0/P1 闭环，步骤 4 + 步骤 7 §K + 步骤 10 三层防线）

> **设计哲学**：「确定性用代码，模糊性用 LLM」（详见 `references/core-principles.md` §19）。
> 本节杜绝 AI「只填 JSON 字段不写磁盘」的反模式——把 `plan_saved_to_disk.status: true` 当成自报值通过，而磁盘上 plan.md 根本没写。
> 背景：早期版本缺乏物理事实兜底时，历史目录容易出现缺 plan.md 的情况，根因即校验只信任 JSON 自报字段而不核对磁盘。

### P0 ── 步骤 4 物理事实兜底（点）

**触发时机**：步骤 4 决策完成、`scripts/validate-output.sh step4` 4 项 `name_lint` 校验通过之后。

**校验逻辑**（实现在 `scripts/validate-output.sh` step4 分支）：

```bash

# 仅执行类 user_decision 强制 plan.md 必须真实落盘
case "$DECISION" in
execute_standard|execute_micro|execute_full|execute_partial|execute_batched)
DIR_NAME=$(jq -r '.outputs.plan_saved_to_disk.dir_name // ""' "$JSON_FILE")
PLAN_FILE="$HOME/.codebuddy/dev-logs/$DIR_NAME/plan.md"
[ ! -f "$PLAN_FILE" ] && exit 2  # 物理文件兜底
[ "$(wc -c < "$PLAN_FILE")" -lt 10 ] && exit 2  # 防空写入
;;
esac

```

**校验范围**：仅当前需求的 plan.md（**点**级校验）。

**反绕过**：

- 仅检查 JSON 字段无法防止 AI 跳过写盘，必须 `[ -f ]` 真去磁盘核对
- 防空写入：plan.md ≥ 10 字节（最起码标题 + 一段内容）
- 模拟决策类（`modify` / `change_plan` / `pause` / `cancel`）豁免（无需写 plan.md）

### P1 ── 步骤 7 §K 批量自检（面）

**触发时机**：步骤 7 §J 经验快检完成后、输出完成标记 JSON 之前（详见 `steps/step-7-commit.md` §K）。

**执行命令**：

```bash
bash ~/.codebuddy/skills/dev-flow/scripts/lints/devlog-integrity-lint.sh --quiet

```

**校验范围**：全量 `~/.codebuddy/dev-logs/` 所有需求目录（**面**级校验）。

**判定规则**：

| 扫描结果 | 完成标记字段 | 处理 |
| --- | --- | --- |
| 全绿 | `devlog_integrity_check: "clean"` | 静默通过 |
| 仅 WARN | `devlog_integrity_check: "warns_N"` | 用户回复末尾追加一行提示，不阻断 |
| 任意 ERROR | `devlog_integrity_check: "blocked_errors_N"` | **拒绝输出完成标记**，向用户报告并要求修复 |

**ERROR vs WARN 分级**（与脚本判定逻辑一致）：

- **ERROR**：v3 阈值（2026-05-12）后创建的目录缺 plan.md，或 plan.md/devlog.md 双件齐缺
- **WARN**：v3 前历史产物缺失，或 v3 后产物有 plan.md 但缺 devlog.md（推断流程进行中）

**模式适用**：

| 执行模式 | §K 适用 | 说明 |
| --- | :---: | --- |
| 标准执行（`caller=standard-7`） | ✅ 强制 | 每次完整流程结束都跑一次 |
| 批次执行（`caller=batch-7`） | ✅ 强制 | 每批结束都校验，及早暴露漂移 |
| 完整执行（`caller=full-7`） | ❌ 推迟到步骤 10 | 与 H/I/J 同节奏 |
| 微修复（`caller=micro-fix-7`） | ❌ 跳过 | 不创建/修改 dev-logs 目录，无沉淀价值 |

### P2 ── 步骤 10 归档前总校验（终）

**触发时机**：步骤 10 完整执行归档前，与 `validate-working-context.sh` 同节奏调用。

**校验范围**：全量 dev-logs/ + working-context/ 引用一致性（**终**级校验）。

**作用**：完整执行模式下，步骤 7 §K 已被推迟，由步骤 10 收口校验，确保归档前无任何漂移。

**实现**（2026-05-29 落地）：

- **ajv 路径**：`scripts/validate-output.sh` 在 `STEP_REF=step10` 分支末尾追加 P2.1
  （`devlog-integrity-lint --quiet` 重算 + 0 ERROR 容忍）+ P2.2
  （`validate-working-context.sh` 检查当前 flow_name 对应的 `.md` 文件命名/结构）
- **jq-only 路径**：作为降级路径不重复实现（用户机器装 ajv-cli 即走 fast path；未装时 jq-only 已有 step10 字段校验，P2 容缺）

### 三层防线协同表

| 层 | 触发时机 | 范围 | 实现 | 兜底强度 |
| --- | --- | --- | --- | --- |
| **P0 步骤 4** | 决策完成 → 写盘后立即校验 | 点（当前需求） | `scripts/validate-output.sh` step4 物理事实兜底 | 🔒 写盘必检 |
| **P1 步骤 7 §K** | 收尾输出 JSON 前 | 面（全量 dev-logs/） | `scripts/lints/devlog-integrity-lint.sh --quiet` | 🛡️ 系统级漂移检测 |
| **P2 步骤 10** | 完整执行归档前 | 终（dev-logs + working-context） | 同 P1 + working-context 引用一致性 | 🏁 归档前总校验 |

### 反模式（违反即拒收）

1. ❌ 把"必须写 plan.md"只写在 SKILL.md 提示词里、只校验 AI 自报的 JSON 字段
2. ❌ 用 `find` / `ls` 查到磁盘上有空 plan.md 就当通过（必须 ≥10 字节防空写入）
3. ❌ 步骤 7 §K 报 ERROR 时，把 `blocked_errors_N` 字段降级为 `warns_N` 自洽通过
4. ❌ 微修复豁免「双件齐全」检查 → 但同时又新增了 dev-logs 目录（自相矛盾）
5. ❌ **「校验脚本双路径不对等」**：物理事实兜底只加在 jq-only 分支，ajv 分支提前 `exit 0` 时直接绕过——
  添加任何 P0/P1/P2 兜底必须 grep 确认 ajv + jq-only 两边都有
6. ❌ **完成标记 JSON 落到临时目录**：用 `/tmp/*` `/var/folders/*` 写步骤完成标记，校验通过后文件被自然清除，破坏审计可追溯性——必须落盘到 `~/.codebuddy/dev-flow-artifacts/<flow-name>/step-<id>.json`
7. ❌ **「path 字段非空但文件不存在 → 静默跳过」**：ajv 路径校验 `path`/`dir_name` 等磁盘路径字段时，必须 `[ ! -f ]` / `[ ! -d ]` 真去 stat，文件不存在 → exit 2，禁止用 `if [ -f ]` 包裹后什么都不做
8. ❌ **flow_name 漂移后改名 .validated 文件掩盖**：同一流程 step-1/2 用 flow_name=A，
   step-3+ 切到 flow_name=B 时不允许手动重命名 .validated 物理文件以"对齐"——
   必须在 `write_validation_checkpoint` 内自检同 prefix 已有 `.validated.json`
   的 `flow_name` 一致性（红牌 #14）

> 详细执行规范见 `steps/step-7-commit.md` §K。脚本是真相，本文件只引用不重复。

## 技术方案文档决策门控（步骤 4 · 环节 3 文档决策专属，硬性必走）

> 本门控对应 `steps/step-4-decision.md` §3 和 `skills/tech-doc/modules/doc-platform-doc.md` 关于 文档平台 硬性决策的要求。
> 📌 **单一权威源**：doc_platform_lint 6 项校验**已下沉到脚本** `scripts/lints/doc-platform-lint.sh`。
> 本节仅保留「硬性原则」「检查时机」「迭代豁免规则」。

### 硬性原则

步骤 4 中，当 `user_decision` 属于执行类（`execute_standard` / `execute_full` /
`execute_partial` / `execute_batched`）时，**文档决策不可跳过**。
AI 必须完成环节 3 的交互，用户必须**显式选择**一个 action（包括"本次不处理"也是显式决策）。

### 调用约定（4）

```bash

# 步骤 4 完成标记 JSON 输出前/后均可校验
bash ~/.codebuddy/skills/dev-flow/scripts/lints/doc-platform-lint.sh <step-4-json-file>

# → 自动按 user_decision 判断是否强制校验

# → 6 项任一失败返回 1（红牌）；非执行类决策直接通过

```

**6 项校验概览**（详见脚本，禁止重复维护）：

1. `decision_made` 必须为 true
2. `action` ∈ {create, update, relink, skip, auto_inherited_skip}
3. `probe_executed` 必须为 true（仅 auto_inherited_skip 豁免）
4. update/relink 时 `matched_docid` 或 `file_path` 非空
5. create 时 `parent_docid` 或 `file_path` 非空（本地模式校验文件路径的目录有效性）
6. **create/update 时创建闭环兜底**：`file_path` 或 `docid` 非空 + `status == "synced"` + `trigger_step ∈ {immediate, ""}`
  （防止把保存动作延后；`trigger_step` 字段只接受 `immediate` / `none` 两个值）

### 检查时机（2）

1. **环节 3 弹出前**：AI 调用 `ask_followup_question` 前，`probe_executed` 必须为 true（例外：首轮 skip 的迭代继承场景）
2. **环节 3 决策后**：记录 `action` 和相关字段到工作上下文 YAML `doc_platform_tech_proposal`
3. **步骤 4 完成标记 JSON 输出前**：调用 doc-platform-lint.sh 校验，全部通过才能推进到步骤 4.5

### 迭代修复继承的豁免规则

当工作上下文 `doc_platform_tech_proposal.action_history` 中所有条目的 `action` 均为 `skipped`，且最新 `iteration` 已 ≥ 2 时：

- `decision_made = true`（视为"已决策"，因为首轮已决定不处理）
- `action = auto_inherited_skip`
- `probe_executed` 允许为 `false`（无需重新探测）
- AI **不需要**弹出阶段 3（节省交互）

**用户逃生通道**：用户在当前对话中显式要求"本轮生成 技术方案文档"等相关表述 → 强制触发完整环节 3（`probe_executed` 变回 `true`，action 可变为 create/update/relink）。

### 违规处理（2）

- 🔴 Block：`decision_made=false` + `user_decision` 属于执行类 → 立即回退到阶段 3 补齐决策，最多重试 2 次；第 3 次升级为用户介入
- 🟡 Warn：`probe_layer=probe_failed` → 输出告警但允许推进（MCP 失败不阻塞用户决策流程）

## 文档平台 归档同步门控（步骤 7 standard / 步骤 10 full 双检查）

> 本门控对应：
>
> - `caller=standard-7` → `references/closeout-flow.md` §H.3+「技术方案文档兜底对账」
> - `caller=full-10` → `steps/step-8-10-full.md` §10.3.5「技术方案文档同步」

### 检查项

| 项 | 校验规则 | 失败处理 |
| --- | --- | --- |
| `doc_platform_sync_result` | `doc_platform_tech_proposal.action = skip` → 必须为 `skipped_user_opt_out`；file_path/docid 均为空 → 必须为 `skipped_no_docid`（仅 standard-7 适用）；其他 action → 必须 ∈ {`synced`,`relinked`,`created`,`skipped_no_changes`} | 🔴 Block：补执行 closeout-flow.md §H.3+ 或 §10.3.5 |
| `last_synced_at` | `action ∈ {create, update}` 且 `doc_platform_sync_result=synced/created` 时必须非空 | 🔴 Block：确认文档写入操作是否真实执行 |
| `title_protected` | `action=update` 时，执行后文档标题与 `locked_title` 一致（标题未被误改） | 🔴 Block：立即恢复标题 + 记录到 `.learnings/ERRORS.md` |
| `doc_platform_lint_passed` | §10.3.5 第 5b 步（或 §H.3+ 同步执行后）执行 `doc-platform-lint.sh` 后退出码必须为 `0`（`action ∈ {skip, auto_inherited_skip, relink}` 时按 `skip_conditions` 自动豁免） | 🔴 Block：禁止标记 `doc_platform_sync_result=synced/created`；按 violations 修复后重跑 lint，再触发同步 |

> 📌 **跨 Skill lint 集成**：`doc-platform-doc-lint` 已在 `config/gates.yaml` 注册为独立 lint
> （owner_skill=tech-doc，跨 Skill 引用 `../../tech-doc/scripts/lints/doc-platform-lint.sh`），
> 对应规则详见 `skills/tech-doc/modules/doc-platform-doc.md` §「跨 Skill 集成」段。
> 本门控对其退出码做强制约束，物理事实兜底 `synced` 标记的合法性。

### 检查时机（按 caller 分流）

- `caller=standard-7`（标准模式收尾）：`scripts/hooks/post-step.sh` 在 `STEP_ID=7-standard` 时调用，
  先由 `validate-output.sh` 检查 `step-7-standard.json` 的 outputs 必填 4 字段（schema 兜底），
  再由 hook §3.5「文档平台 兜底对账漂移预检」做业务校验（漂移检测 + doc-platform-doc-lint 触发）
- `caller=full-10`（完整模式收尾）：步骤 10.6 完成性校验表扫描时（第 6 行 文档平台 同步校验）+ 完成标记 JSON 输出前
- `caller=batch-7` / `caller=micro-fix-7`：跳过本门控（batch 推迟到最后一批 / micro 不绑定 doc_platform）

**失败处理**：🔴 Block，要求加载 `references/closeout-flow.md` §H.3+（standard-7）或 §10.3.5（full-10）后重新执行。

> 📌 **P0-1 Schema 增补 + P0-2 Hook 兜底**：自 2026-06-02 起，
> `step7_standard` schema 已强制要求 `doc_platform_sync_result` / `last_synced_at` / `title_protected` /
> `doc_platform_lint_passed` 四字段必填，`scripts/hooks/post-step.sh` 在 `STEP_ID=7-standard` 时
> 自动拦截缺字段产物 + 执行漂移检测，弥补"规范完备但执行层缺失"的盲区。

---

## 步骤内子环节引用规范门控（AI 输出措辞，软门控）

> 2026-06-01 一期新增（步骤 4 专属）；2026-06-01 二期扩展为全步骤口播规则 + 未来命名守则。配合「阶段 → 环节」命名优化（详见 `steps/step-4-decision.md` 顶部 2026-06-01 变更说明），约束 AI 在面向用户的输出中如何引用任何步骤的内部子节。
> 本门控的**权威源**为 `~/.codebuddy/rules/AI行为规范.mdc` §「dev-flow 步骤内子环节引用规范」。本文件提供 dev-flow 视角的扩展细则与自检模式。

### 命名层级速查

| 层级 | 标准用词 | 例子 |
| --- | --- | --- |
| 顶层流程节点 | **阶段 0 / 0.5** + **步骤 1~10** | 「阶段 0 需求理解」「步骤 4 决策」 |
| 步骤 4 内部子环节 | **环节 N · 语义名** | 「环节 3 · 文档决策」 |
| 其他步骤内部子节 | **既有编号（A/B/C 或 a/b/c 或 V1~V7）** | 6A、5.5a、V4、9b |
| AI 面向用户输出（强制） | **「编号 · 语义名」组合** | 见下方全步骤口播标准 |
| 文档章节锚点（仅文档定位） | **§N.x** | §3.1 空间探测 |

步骤 4 四个语义名定稿：

- 环节 1：任务评估
- 环节 2：执行深度决策
- 环节 3：文档决策
- 环节 4：决策落地

### 全步骤口播标准（AI 输出前自检）

| 步骤 | ✅ 标准说法 | ❌ 反例（裸编号） |
| --- | --- | --- |
| 步骤 4 | 「步骤 4 · 文档决策（环节 3/4）」 | 「步骤 4 阶段 3」「环节 3」 |
| 步骤 5.5 | 「步骤 5.5a · L1 代码审查」「步骤 5.5b · 文档同步」「步骤 5.5c · 快速自检」 | 「5.5a」「5.5b」 |
| 步骤 6 | 「步骤 6A · 自动化验证」「步骤 6A V4 · Browser 验证」「步骤 6B · 用户验收」 | 「6A」「V4」 |
| 步骤 7 | 「步骤 7 · H.3+ 文档平台 兜底对账」「步骤 7 · K dev-logs 完整性自检」 | 「H.3+」「K.3」 |
| 步骤 9 | 「步骤 9a · 度量数据采集」「步骤 9b · 代码经验提炼」 | 「9a」「9b」 |
| 步骤 10 | 「步骤 10.3.5 · 文档平台 兜底对账」「步骤 10.2 · 知识沉淀」 | 「10.3.5」 |

### AI 自检规则（输出前 grep 自检）

AI 在面向用户的输出中**禁止**出现以下旧术语 / 反模式：

| 反模式（grep） | 替换为 |
| --- | --- |
| `步骤[ ]*4[ ]*阶段[ ]*[1-4]` | `步骤 4 · {语义名}（环节 N/4）` |
| 单独出现的「`阶段 [1-4]`」（指代步骤 4 内部，非顶层「阶段 0」） | 「环节 N · {语义名}」 |
| `2B 阶段` / `阶段 3 决策` 等历史残留 | 「环节 3（文档决策）」 |
| 裸字母编号「6A」「5.5b」「9b」「H.3+」「V4」单独面向用户出现（不带语义名） | 「步骤 X{编号} · {语义名}」 |
| 三级以上小数「10.3.5」单独面向用户出现 | 「步骤 10.3.5 · {语义名}」 |

### 未来新增子节点的命名守则（防御）

dev-flow 演进时，新增/重构步骤内部子节点必须**满足以下任一编号体系**：

| ✅ 推荐编号体系 | 适用场景 | 现有例子 |
| --- | --- | --- |
| 大写字母 A/B/C | 强独立性的并列子节 | 步骤 6 的 6A/6B/6C、步骤 7 的 A~K |
| 小写字母 a/b/c | 同一阶段内的细分 | 步骤 5.5 的 a/b/c、步骤 9 的 9a~9e |
| 带语义前缀的编号 | 同类元素列表（前缀字母自带语义） | V1~V7（V=Verify）、caller=xxx |
| 「环节 N · 语义名」 | 多子节决策且需"进度感"的步骤 | 步骤 4 的环节 1~4 |

**禁止使用**：

- 🚫 「阶段 N」指代步骤内部子节点 → 已被顶层「阶段 0/0.5」占用，永久禁用
- 🚫 「步骤 N」指代步骤内部子节点 → 已被顶层步骤占用
- 🚫 纯数字（1/2/3）作为对外引用名 → 必须配语义名或加字母/前缀
- 🚫 三级以上小数（如 10.3.5、4.1.2.3）作为日常对话引用 → 文档锚点可用，但 AI 口播必须用语义名替代

### 例外（合法保留）

- 顶层「阶段 0」「阶段 0.5」**完全保留**，不视为违规
- 散文措辞「研究阶段」「本阶段」「.flow 表格的"阶段"列名」等**与子节点无关**的语境保留
- 各步骤文件的 §章节锚点（§1.1/§2.1/§3.1/§4.1）**保留**——它们仅用于文档内部定位，不要求改名
- 步骤 5.5/6/7/9/10 的现有字母/数字编号体系**保留**——它们天然不与顶层撞车，问题只在 AI 措辞层（口播必须带语义名）

### 检查时机（3）

- AI 在生成涉及任何步骤内部子节的对话回复或决策卡片前，自检输出
- 用户报告"看不懂在哪个环节"时，校对历史输出是否符合本规范
- 未来 dev-flow 演进新增子节点时，必须先核对本节"命名守则"

> 软门控不阻塞流程，但**违规视为话术质量问题**，会被 self-improving-agent 的"用户纠正"链路捕获。

<!-- DIAG_TEST_164422 -->
