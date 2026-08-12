# 步骤 7：清理与完整性检查 + Commit

> 🔴 **红牌 #16：步骤 7 · H.3+ 文档平台 兜底对账强制读取 closeout-flow.md**
> 进入步骤 7 时，**第一个 read_file 必须是** `references/closeout-flow.md`。
> 禁止凭记忆走 H.1/H.2/H.3 简略路径——H.3+（文档平台 兜底对账）和 H.4（任务平台 状态提醒）等环节
> 仅在该文件中明文定义。
> 自检触发条件：工作上下文 `doc_platform_tech_proposal.docid` 非空 → 必须执行步骤 7 · H.3+ 文档平台 兜底对账。
> 违规后果：`scripts/hooks/post-step.sh` §3.5「文档平台 漂移预检」会拦截，`validate-output.sh` 因缺
> `doc_platform_sync_result` / `last_synced_at` / `title_protected` / `doc_platform_lint_passed` 字段会失败。
> 本文件仅在执行步骤 7 时加载。标准执行下这是最后一步，完整执行下继续步骤 8。

## 目标

清理调试代码、执行 L2 完整审查、生成 Commit Message 和开发日志。
步骤 7 通过调用方标识（`caller=standard-7` / `full-7` / `batch-7` / `micro-fix-7`）共享同一套 commit/devlog/knowledge 子流程规范。

## 执行指令

**加载 commit/devlog/knowledge 子流程**：`read_file("references/closeout-flow.md")`

- **标准执行**（`execution_depth=standard`）：以 `caller=standard-7` 身份执行
- **完整执行**（`execution_depth=full`）：以 `caller=full-7` 身份执行（仅清理+L2审查，commit/devlog/knowledge推迟到步骤10）
- **批次执行**（`batch_mode=true && current_batch < total_batches`）：以 `caller=batch-7` 身份执行（清理+L2审查+精简版Commit+增量devlog，跳过knowledge/反思）
- **微修复执行**（`mode=micro-fix`）：以 `caller=micro-fix-7` 身份执行
  （轻量保留版：主干分支检测 + 5.5a L1 极简 + lint + 7-A Diff stat、
  7-B 限改动行清理 + 7-H.1 commit + 7-H.2 devlog 极简追加、
  7-H.3 knowledge 漂移检测 + 7-J Q1+Q2 经验快检；
  跳过 7-G L2/7-C/7-E/7-I 数据驱动反思）

### 标准执行的环节（`caller=standard-7`）

> 🔴 **红牌 #18：环节清单强制逐项执行** — 以下环节清单是**完整执行清单**，禁止因文档过长而遗漏尾部环节。
> 进入步骤 7 后，**必须将此清单转化为 `todo_write` 逐项推进**，每完成一环标记一项。
> 历史事故：2026-06-05 因 closeout-flow.md 379 行分次读取时遗漏了 L269 的环节 I（度量采集），
> 根因是未对照本清单逐项勾选。

```text
A. Diff 分析        ✅ 执行
B. 清理调试代码      ✅ 执行
C. 可选链检查        ✅ 执行
D. 即时验证          ✅ 执行
E. TODO 检查         ✅ 执行
F. 改动汇总          ✅ 执行（展示给用户确认，非归档文档）
G. L2 审查           ✅ 执行
H. Commit+Devlog+Knowledge ✅ 执行
I. 数据驱动反思      ✅ 执行（必须，Token>50轮时精简为一行摘要）
J. 经验快检          ✅ 执行（静默，3问全否则零开销）
K. dev-logs 完整性自检   ✅ 执行（强制，devlog-integrity-lint --quiet）

```

> ⚠️ **环节清单完成后，必须先调用 `post-step.sh` 或 `validate-output.sh` 进行门控校验**
> （校验 I 的 metrics/flow_report 字段、K 的 devlog_integrity_check 字段均为物理事实兜底，
> 不信 AI 自填值）。禁止直接汇报「步骤 7 完成」。

### 完整执行的环节（`caller=full-7`）

```text
A. Diff 分析        ✅ 执行
B. 清理调试代码      ✅ 执行
C. 可选链检查        ✅ 执行
D. 即时验证          ✅ 执行
E. TODO 检查         ✅ 执行
F. 改动汇总          ✅ 执行（展示给用户确认，非归档文档）
G. L2 审查           ✅ 执行（到此结束）
H. Commit+Devlog+Knowledge ❌ 推迟到步骤 10
I. 数据驱动反思      ❌ 推迟到步骤 9（深度反思）
J. 经验快检          ❌ 跳过（步骤 9 深度反思已覆盖）
K. dev-logs 完整性自检   ❌ 推迟到步骤 10（与 H/I/J 同节奏）

```

### 批次执行的环节（`caller=batch-7`，非最后一批）

```text
A. Diff 分析        ✅ 执行
B. 清理调试代码      ✅ 执行
C. 可选链检查        ✅ 执行
D. 即时验证          ✅ 执行
E. TODO 检查         ✅ 执行
F. 改动汇总          ✅ 执行（展示给用户确认，非归档文档）
G. L2 审查           ✅ 执行
H. Commit+Devlog+Knowledge ⚡ 精简版（H.1 Commit 含 [batch N/M] + H.2 增量 devlog + H.3 跳过 knowledge）
I. 数据驱动反思      ❌ 跳过（推迟到最后一批）
J. 经验快检          ❌ 跳过（推迟到最后一批）
K. dev-logs 完整性自检   ✅ 执行（强制，每批结束都校验，及早暴露漂移）

```

> 最后一批（`current_batch == total_batches`）自动切换为 `caller=standard-7`（标准执行）或 `caller=full-7`（完整执行），执行完整环节。

### 微修复执行的环节（`caller=micro-fix-7`，**轻量保留版 v2**）

```text
A. Diff 分析        ⚡ 极简版：仅 git diff HEAD --stat + 高风险文件识别（lock/配置文件 → ask_followup_question）
B. 清理调试代码      ⚡ 限本次改动行（全文扫描跳过）
C. 可选链检查        ⚡ 限本次改动行
D. 即时验证          ✅ 执行（`read_lints` 必须通过）
E. TODO 检查         ❌ 跳过
F. 改动汇总          ✅ 执行（展示给用户确认，非归档文档）
G. L2 审查           ❌ 跳过（L1 极简已覆盖，阶段 0 锁边界 + 5.5a L1 极简审查里应外合）
H. Commit+Devlog+Knowledge ⚡ 轻量版：

- H.1 Commit：主干分支兜底校验 + smart-commit + 用户确认
- H.2 Devlog：极简追加 1 行（当前 Round 末尾 或 月度合集，详见 `references/micro-fix-light.md` §四）
- H.3 Knowledge 漂移检测：grep 反查 + 命中模块变更历史追加（详见 `references/micro-fix-light.md` §五）
- 🔴 **H.2/H.3 不可跳过**：无论用户选择提交还是跳过提交，H.2 Devlog 和 H.3 Knowledge 必须在 H.1 决策后继续执行。步骤 7 完成标记 JSON 提交给 `validate-output.sh` 前，`post-step.sh` §3.11 会通过 `doc-sync-lint.sh` 校验 devlog.md 物理修改时间戳 + plan.md CR 完整性。
- 🆕 **plan.md CR 同步**：检查工作上下文 `change_requests` 中状态为 `done` 且未在 plan.md 执行期变更记录中出现的 CR，自动追加一行（格式同 plan.md 表格行）。
- H.3+ 文档平台 / H.4 任务平台 提醒：跳过
I. 数据驱动反思      ❌ 跳过（不采集 metrics，反思缺数据基础）
J. 经验快检          ⚡ **简版**：仅 Q1（用户纠正）+ Q2（踩坑递增），跳 Q3（详见 `references/micro-fix-light.md` §六）
K. dev-logs 完整性自检   ❌ 跳过（不创建/修改 dev-logs，无沉淀价值）

```

> ⚠️ 主干分支兜底（仅 micro-fix）：H.1 生成 commit 前必须检测
> `git branch --show-current`，若为 `master/main/develop/release/*` 主干分支
> → **立即中断**，提示用户切出分支后重试
> （对应隐拦 #4：主干保护。详见 `references/mode-matrix.md` §三bis）。
> ⚠️ 自动降级触发检查（v2 扩展）：若命中以下任一条件，
> 在 `caller=micro-fix-7` 进入前必须自动降级为 `caller=standard-7`
> 并在工作上下文 `mode_history` 追加
> `{from: micro-fix, to: standard, reason: "auto_downgrade_micro_fix"}`，
> 同时补走 step-1/2/3/4 .validated
> （详见 `references/gate-validator.md` §「按基础模式分流的预检白名单」）：
>
> 1. 实际改动 `>15` 行 或 `≥2` 个文件
> 2. 7-A Diff stat 检测到 lock/配置文件且用户拒绝确认
> 3. 5.5a L1 极简审查发现 ≥3 个 🔴 或需决策性思考的 🔴

## ⛔ 退出自检清单（逐项口播确认后才能输出完成 JSON）

> 🔴 此清单与上方环节清单对应，逐项确认后再输出完成标记 JSON。

在输出完成标记 JSON 之前，按 caller 模式逐项确认：

### 标准执行（caller=standard-7）

- [ ] A. Diff 分析：已完成？改动汇总已展示？
- [ ] B. 清理调试代码：已清除？debug_code_cleaned = true？
- [ ] C. 可选链检查：已执行？optional_chain_checked = true？
- [ ] D. 即时验证：已完成？
- [ ] E. TODO 检查：已完成？
- [ ] F. 改动汇总：已展示给用户确认？
- [ ] G. L2 审查：已完成？l2_review_result 非空？
- [ ] H. Commit+Devlog+Knowledge：smart-commit 已调用？devlog_generated = true？knowledge_updated = true？
- [ ] I. 数据驱动反思：已完成？metrics_report_generated = true？YAML 中 `task_url`/`doc_url` 已从工作上下文提取（有则必填，缺则复盘报告链接不可点击）？
- [ ] J. 经验快检：已完成？experience_check 字段已填写？
- [ ] K. dev-logs 完整性自检：devlog-integrity-lint --quiet 已执行？devlog_integrity_check 字段已填写？
- [ ] validate-step7.sh 已调用且通过？
- [ ] 上述全部完成 → 才可输出完成标记 JSON

### 完整执行（caller=full-7）

- [ ] A~G 环节同标准执行
- [ ] H/I/J/K 推迟到步骤 10

### 批次执行（caller=batch-7）

- [ ] A~G 环节同标准执行
- [ ] H. Commit+Devlog：精简版已执行（含 [batch N/M]）？
- [ ] K. dev-logs 完整性自检：已执行？

### 微修复执行（caller=micro-fix-7）

- [ ] A~F 环节轻量版已执行？
- [ ] H.1 Commit：主干分支检测 + smart-commit 已调用？
- [ ] H.2 Devlog：极简追加已完成？
- [ ] H.3 Knowledge：漂移检测已完成？
- [ ] J. 经验快检（简版 Q1+Q2）：已完成？

---

## 必须输出

### 步骤推进选项（标准模式必须，按执行深度分路径）

按 `steps/step-router.md` §「步骤流转交互规则」，完成标记 JSON 输出并状态同步后，**必须调用 `ask_followup_question` 弹出推进选项**（先文本表格展示，再调用工具）。选项内容根据 `caller` 分路径：

**标准执行（`caller=standard-7`）——流程结束或柔性升级**：

| 选项 | 说明 |
| --- | --- |
| ✅ 流程完成 | 标准执行已完成所有环节，可以关闭 |
| � 柔性升级：补走完整执行步骤 8–10 | 本轮提交/devlog 已完成，补做 L3 审查+反思+归档（不重复 commit） |
| �📋 查看交付总结 | 展示本次需求的改动/commit/devlog/knowledge 汇总 |
| ⏸️ 暂停，我有补充/疑问 | 暂停等待用户输入（如想追加优化或重开另一需求） |
| 🔁 回退步骤 6 补充验证 | 发现需要补充验证 |

> 💡 **柔性升级说明**：用户在 commit 后才意识到需要 L3 审查/深度反思/完整归档时，可选择此选项补走步骤 8–10。柔性升级后：
>
> 1. 工作上下文 `mode` **从 `standard` 更新为 `full`**（并在 `mode_history` 追加 `{from: standard, to: full, at: "...", reason: "user_choice_post_commit"}`）
> 2. **`signals` 数组同步补全**（v2.1 硬化 2026-05-10）：升级时必须在工作上下文 YAML `signals` 数组中追加 full 模式专属信号，确保步骤 9 反思和步骤 10 归档能正确加载条件 reference：
>    - 追加 `flow_retrospective`（步骤 9 深度反思加载条件）
>    - 追加 `metrics_full_report`（步骤 9 完整度量报告加载条件）
>    - 追加 `l3_review_required`（步骤 8 L3 多视角审查加载条件）
>    - 已存在的信号不重复追加（去重写入）
>    - 写入示例：
>
>      ```yaml
>      signals:
>        - figma_url            # 已有，保留
>        - step_4_5_env_check   # 已有，保留
>        - flow_retrospective   # 柔性升级时追加
>        - metrics_full_report  # 柔性升级时追加
>        - l3_review_required   # 柔性升级时追加
>      ```
>
> >
>
> 1. 状态 `next_step: 8`，步骤 7 完成标记保留不变（commit/devlog/knowledge 已生成，**不重复**）
> 2. 进入步骤 8 后，step-8-10-full.md **检测到从 standard 接入**时跳过 9b/9c 中与 commit 重复的环节，仅补做 L3 审查/深度反思/归档报告
> 3. 步骤 10.3 commit 差异采集仅生成交付报告，**不调用 smart-commit 重新提交**
> ⚠️ 柔性升级仅限 standard → full。batch 不支持柔性升级（需在最后一批的最后一步使用）。
**完整执行（`caller=full-7`）—— 继续步骤 8**：

| 选项 | 说明 |
| --- | --- |
| ▶️ 继续步骤 8（L3 代码审查） | 进入完整执行的深度审查环节 |
| ⏸️ 暂停，我有补充/疑问 | 暂停等待用户输入 |
| 🔁 回退步骤 6 补充验证 | 发现需要补充验证 |

**批次执行（`caller=batch-7`，非最后一批）—— 进入下一批次**：

| 选项 | 说明 |
| --- | --- |
| ▶️ 继续 Batch {N+1} | 本批次完成，进入下一批次的步骤 4.5 |
| ⏸️ 暂停批次，先验证 Batch {N} | 暂存当前进度，等待用户验证本批次 |
| 🔁 回退调整批次规划 | 发现批次划分有问题，回步骤 4 重新规划 |

**微修复执行（`caller=micro-fix-7`）——流程结束**：

| 选项 | 说明 |
| --- | --- |
| ✅ 完成 | micro-fix 轻量快修已完成（commit + devlog 追加 + knowledge 漂移检测 + 经验快检 均已执行），流程结束 |
| 📈 柔性升级：改走 standard 补做完整步骤 7 | 发现改动范围超出预期 / 需补独立 devlog/独立 knowledge 模块 / 需反思 → 自动降级为 standard 重走完整步骤 7（对应 `references/mode-matrix.md` §三bis 「自动降级」） |
| ⏸️ 暂停，我有补充/疑问 | 暂停等待用户输入 |

> 💡 micro-fix 推进说明：micro-fix 不提供柔性升级到 full 的选项（柔性升级仅限 standard→full）。若事后识别为复杂需求，仅能选择「柔性升级至 standard」补做完整步骤 7；standard 完成后可再柔性升级到 full。
> **精简模式**：步骤 7 为🟡质量/🔴关键决策点组合（含 commit 确认），标准模式必须弹出；精简模式下 commit 确认仍必须，推进选项可简化为单选「✅ 完成」。

### 结构化完成标记（必须输出，缺字段视为未完成）

```json
{
"step": 7,
"name": "清理+Commit",
"status": "completed",
"outputs": {
"debug_code_cleaned": true,
"optional_chain_checked": true,
"unexpected_changes": "none | 描述",
"l2_review_result": "passed | found:{N}_fixed:{M}",
"commit_message": "生成的 commit message 摘要",
"devlog_generated": true,
"knowledge_updated": true,
"reflection": "度量驱动反思结论 或 normal_no_anomaly",
"experience_check": "clean | recorded_N | alert_pattern_key",
"devlog_integrity_check": "clean | warns_N | blocked_errors_N",
"metrics_report_generated": true,
"metrics_file": "reports/{工作上下文文件名（不含 .md）}.yaml",
"flow_report_generated": true,
"flow_report_file": "flow-reports/{工作上下文文件名（不含 .md）}.html",
"flow_report_opened": true,
"dashboard_generated": true,
"dashboard_opened": true
},
"working_context_updated": true,
"next_step": "done（标准执行）| 8（完整执行）"
}

```

> 📌 **micro-fix v2 轻量保留版的完成标记**（`caller=micro-fix-7`）：额外包含以下字段，详细说明见 `references/micro-fix-light.md` §七 「三道防线」：
>
> ```json
> "outputs": {
>   "branch_safe": true,
>   "read_lints_passed": true,
>   "diff_stat_checked": true,
>   "l1_review_result": "passed_micro_light | fixed_N_issues_micro_light",
>   "commit_message": "生成的 commit message 摘要",
>   "devlog_appended": "round_appended | monthly_appended",
>   "knowledge_drift_checked": "no_hits | appended_history | drift_recorded",
>   "experience_check": "clean | recorded_N | alert_pattern_key",
>   "devlog_generated": false,
>   "knowledge_updated": false
> }
> ```

**完成标记校验规则**：

> 🔧 **确定性门控（强制）**：写完完成标记 JSON 后，**必须调用脚本校验**，exit≠0 即阻断，禁止 AI 凭记忆对照。
>
> ```bash
> bash ~/.codebuddy/skills/dev-flow/scripts/validate-step7.sh <json文件> <yaml文件>
> ```
>
> 脚本串联校验两阶段：① 完成标记 JSON 6 个必填字段 ② 度量 YAML 10 个 required 字段（仅当 `metrics_report_generated: true`）。
> 设计哲学（`确定性用代码，模糊性用 LLM`）：REQUIRED 字段硬编码在脚本 python dict 中，AI 无需心算。exit 0=pass / 1=fail（输出 violations 清单）。

- `debug_code_cleaned` 必须为 `true`
- `l2_review_result` 不能为空
- `commit_message` 不能为空（标准执行）
- `devlog_generated` 必须为 `true`（标准执行，禁止为 false/skipped）
- `knowledge_updated` 必须为 `true`（标准执行，禁止为 false/skipped）
- `metrics_report_generated` 必须为 `true`（标准执行，度量报告必须生成）
- `flow_report_generated` 必须为 `true`（标准执行，单需求 HTML 复盘报告必须生成；脚本失败可为 `false`，但需在工作上下文记录失败原因）
- `flow_report_opened` 为 `true | false`（macOS 环境下默认 true；headless / 远程 SSH 失败时降级为 false，不阻断流程）
- `dashboard_generated` 必须为 `true`（标准执行，全局度量仪表盘必须生成；脚本失败可为 `false`，但需在工作上下文记录失败原因）
- `dashboard_opened` 为 `true | false`（macOS 环境下默认 true；headless / 远程 SSH 失败时降级为 false，不阻断流程）
- 标准执行：`next_step` 为 `done`，流程结束
- 完整执行：`next_step` 为 `8`，继续步骤 8
- 批次执行（非最后一批）：`next_step` 为 `batch_next`，`devlog_generated` 允许为 `"batch_partial"`，
  `knowledge_updated` 允许为 `false`，`commit_message` 必须包含 `[batch N/M]`
- 批次执行（最后一批）：与标准执行/完整执行规则一致（自动切换 caller）
- **微修复执行**（v2 轻量保留版）：
- 必须为 `true`：`commit_message` 非空、`branch_safe`、`read_lints_passed`、`diff_stat_checked`
- 必须有枚举值：`devlog_appended ∈ {round_appended, monthly_appended}`、
  `knowledge_drift_checked ∈ {no_hits, appended_history, drift_recorded}`、
  `experience_check ∈ {clean, recorded_N, alert_pattern_key}`
- 可选为 `passed_micro_light` 或 `fixed_N_issues_micro_light`：`l1_review_result`（有改动时必填）
- **仍为 `false` 或省略**（保持原语义）：`devlog_generated`（= 未生成独立 devlog 文件）、`knowledge_updated`（= 未沉淀新知识模块）、`reflection`、`metrics_report_generated`

## J. 经验快检（仅标准执行，静默执行）

> 借鉴 MemPalace Agent Diary 的模式识别机制，在标准执行中增加轻量经验沉淀触点。
> 完整执行由步骤 9 深度反思覆盖，此环节跳过。

**执行时机**：环节 I（数据驱动反思）之后、输出完成标记 JSON 之前。

**3 问快检**（静默执行，≤30 秒，不输出给用户）：

1. **本次开发中是否有用户纠正？**

- 有 → 检查 `~/.codebuddy/.learnings/LEARNINGS.md` 是否已记录
- 未记录 → 按 self-improving-agent 的「写入前去重」流程写入（含 Pattern-Key 匹配和 Recurrence-Count 递增）

1. **本次开发中是否踩了 learnings 中已记录的坑？**

- 有 → 递增对应条目的 `Recurrence-Count`，更新 `Last-Seen`
- `Recurrence-Count >= 3` 且 `Status != promoted` → 在完成标记中标注 `experience_alert`

1. **本次开发中是否发现了新的可复用模式/踩坑经验？**

- 有 → 记录为 `insight` 或 `best_practice` 类型条目

**跳过条件**：3 问全部为"否" → 不写入任何内容，完成标记中 `experience_check` 为 `"clean"`。

**完成标记扩展字段**（追加到 outputs 中）：

```json
"experience_check": "clean | recorded_N | alert_pattern_key"

```

- `clean`：3 问全否，无需记录
- `recorded_N`：新增/更新了 N 条 learnings
- `alert_pattern_key`：某条目 Recurrence-Count >= 3，需关注提升为规则

## K. dev-logs 完整性自检（收尾兜底，物理事实）

> 📌 **设计哲学**：「确定性用代码，模糊性用 LLM」。本章节是 P1 层批量自检（**面**级），
> 与步骤 4 的 P0 物理事实兜底（**点**级）+ 步骤 10 的 P2 归档前总校验（**终**级）
> 形成三层防线。详见 `references/gate-validator.md`
> §「dev-logs 物理事实兜底（P0/P1 闭环）」。

### K.1 触发时机

在 §J 经验快检完成后、输出完成标记 JSON 之前执行。

### K.2 执行命令

```bash
bash ~/.codebuddy/skills/dev-flow/scripts/lints/devlog-integrity-lint.sh --quiet

```

### K.3 判定矩阵（与 gate-validator 一致）

| 扫描结果 | 完成标记 JSON 字段 | 处理 |
| --- | --- | --- |
| 全绿 | `devlog_integrity_check: "clean"` | 静默通过，继续输出完成标记 |
| 仅 WARN | `devlog_integrity_check: "warns_N"` | 用户回复末尾追加一行提示，不阻断流程 |
| 任意 ERROR | `devlog_integrity_check: "blocked_errors_N"` | **拒绝输出完成标记**，向用户报告并要求修复 |

### K.4 ERROR/WARN 分级

- **ERROR（阻断）**：v3 阈值（2026-05-12）后创建的目录缺 plan.md，或 plan.md/devlog.md 双件齐缺
- **WARN（提示）**：v3 前历史产物缺失，或 v3 后产物有 plan.md 但缺 devlog.md（推断流程进行中）

### K.5 模式适用矩阵

| 模式 | §K 适用 | 说明 |
| --- | :---: | --- |
| 标准（standard） | ✅ 强制 | 每次完整流程结束都跑一次 |
| 批次（batched） | ✅ 强制 | 每批结束都校验 |
| 完整（full） | ❌ 推迟到步骤 10 | 与 H/I/J 同节奏 |
| 微修复（micro-fix） | ❌ 跳过 | 不创建/修改 dev-logs，无沉淀价值 |

### K.6 反模式（违反即拒收）

- ❌ 把 ERROR 字段降级为 WARN 自洽通过
- ❌ 微修复模式同时新增了 dev-logs 目录但又豁免本检查（自相矛盾）
- ❌ 不跑 lint 直接填 `devlog_integrity_check: "clean"`

> 脚本是真相，本章节只描述接入约定。完整规则见 `scripts/lints/devlog-integrity-lint.sh` + `references/gate-validator.md` §P1。
