# 完整执行扩展（步骤 8~10）

> 以下步骤仅在用户选择「完整执行」时执行。
> 标准执行在步骤 7 结束，不加载本文件。

## 入口模式

本文件支持两种入口：

| 入口 | 触发条件 | 行为差异 |
| --- | --- | --- |
| **正常入口**（`entry=full-from-step4`） | 步骤 4 用户选择 `execute_full` | 步骤 8/9/10 全量执行；步骤 10 调用 `smart-commit` 生成最终 commit |
| **柔性升级入口**（`entry=full-upgraded-from-standard`） | 步骤 7（标准执行）完成后用户选择「📈 柔性升级：补走完整执行步骤 8–10」 | 跳过 step-7 已生成内容的重做（commit/devlog/knowledge 已生成）；步骤 10.3 仅做差异采集与交付报告，**不重新调用 smart-commit** |

**入口判定规则**：

```yaml

# 加载本文件前 AI 必须读取工作上下文判定入口
if working_context.mode == "full" AND working_context.mode_history 含 {from: standard, to: full}:
entry = "full-upgraded-from-standard"
else:
entry = "full-from-step4"

```

**入口差异详细说明**：

- 步骤 8（L3 审查）：两种入口下规则一致
- 步骤 9（反思）：两种入口下规则一致
- 步骤 10（归档）：
- 正常入口：10.3 调用 `smart-commit` 生成 commit + 10.4 生成 devlog + 10.5 交付报告
- 柔性升级入口：10.3 跳过 commit 生成（commit 在步骤 7 已生成），仅做 commit 差异采集 + 10.4 跳过 devlog 生成（已生成）+ 10.5 生成补充交付报告（包含 L3 + 反思 + 归档增量）

> ⚠️ **柔性升级专属约束**：
>
> 1. 不重复生成 commit / devlog / knowledge（已在步骤 7 生成）
> 2. 物理检查点 `step-7.validated` 必须存在，否则禁止以柔性升级入口加载本文件
> 3. 工作上下文 `mode` 必须为 `full`（已由步骤 7 升级时更新），且 `mode_history` 含完整迁移记录

## 入口前置：完整模式跨步骤真空期 改动检测

> 解决方案：`caller=full-7` 完成后到步骤 10 之间，AI 无从感知用户是否追加了代码改动。
> 实现：在加载本文件 + 进入步骤 8 / 9 / 10 入口处，自动跑一次 git diff 快照对比，差异非空则触发 dev:sync 场景 B 弹框。
> 🔴 **红牌**：本前置检测禁止跳过（违反 = 违反「主动文档同步弹框提醒」reflex）。
> 走出步骤 7 commit 后，AI 不会回头读 step-7-commit.md，故本入口章节是唯一可靠的提醒位置。

### 检测时机

| 时机 | 行为 |
| --- | --- |
| 加载本文件并进入步骤 8 入口 | 跑下方"检测脚本"，差异非空 → 弹框 |
| 步骤 8 完成 → 进入步骤 9 入口 | 同上 |
| 步骤 9 完成 → 进入步骤 10 入口 | 同上（步骤 10 是事前同步的最后机会，10.3.5 是事后兜底而非替代） |
| 进入步骤 10 内部后 | 不再触发（10.3.5 本身就是兜底对账） |

### 检测脚本

```bash
#!/usr/bin/env bash

# 入口前置：完整模式跨步骤真空期 改动检测（2）
set -euo pipefail

DEV_FLOW_ROOT="$HOME/.codebuddy/skills/dev-flow"
source "$DEV_FLOW_ROOT/scripts/lib/common.sh"

FLOW_NAME="${1:?需要 flow-name}"
FLOW_FILE="$(df_active_flows_dir)/${FLOW_NAME}.flow"

if [ ! -f "$FLOW_FILE" ]; then
exit 0   # .flow 不存在，跳过
fi

# 基准 sha：优先取 .flow.last_sync_diff_sha；缺失则降级 HEAD~10 兜底

# 注：原 v3 中间 fallback 已剔除（实测项目 commit message 不含 step-7 关键词，是死代码）
BASE_SHA=$(df_get_flow_field "$FLOW_FILE" "last_sync_diff_sha")
DEGRADED=""
if [ -z "$BASE_SHA" ]; then
BASE_SHA="HEAD~10"
DEGRADED=1
fi

DIFF_FILES=$(git diff "$BASE_SHA" HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')

if [ "$DIFF_FILES" -gt 0 ]; then
echo "FULL_VOID_ADDITIONS_DETECTED files=$DIFF_FILES base=$BASE_SHA${DEGRADED:+ degraded=true}"
exit 1
fi
exit 0

```

### AI 行为

- 脚本退出码 1 → 必须 `ask_followup_question` 弹出场景 B 提醒（按 `references/in-flow-sync.md` §1.2 模板）
- 用户选"✅ 立即同步" → 加载 `references/in-flow-sync.md` 执行
- 用户选"⏭️ 跳过本次，由步骤 10.3.5 兜底" → 记入工作上下文 `## 备注`，继续步骤 8/9/10 入口流程
- 脚本退出码 0 → 静默进入步骤 8/9/10
- 输出含 `degraded=true` → 弹框中追加提示："基准 sha 检测降级到 HEAD~10，对比范围可能不准确"

### 红牌

- 🔴 禁止跳过本前置检测直接进入步骤 8/9/10（违反 = 违反「主动文档同步弹框提醒」reflex）
- 🔴 BASE_SHA 检测降级到 `HEAD~10` 时必须在弹框中提示用户"基准 sha 检测降级"

## 步骤导航

> 本文件包含步骤 8~10 的完整规范。执行时按顺序逐步骤执行，每个步骤完成后必须输出完成标记 JSON。

| 步骤 | 章节标题 | 核心动作 |
| --- | --- | --- |
| 8 | 「步骤 8：代码审查」 | 调用 code-review L3 + 文档同步兜底检查 |
| 9 | 「步骤 9：反思与学习」 | 度量采集(9a) → 经验提炼(9b) → 流程反思(9c) → L1输出(9d) |
| 10 | 「步骤 10：归档与交付」 | 规则归档(10.1) → 规范沉淀(10.2) → Commit(10.3) → **文档平台 归档同步(10.3.5)** → Devlog(10.4) → 交付报告(10.5) → 完成性校验(10.6) |

## 步骤 8：代码审查（L3 多视角深度审查）

> 以下规范独立于 flow.md，完整执行时按此执行。

**执行**：调用 `use_skill('code-review')` 执行 L3 多视角深度审查。

L3 = L2 全部内容 + 注释补充 + 多视角审查（安全审计/性能工程/可维护性）+ 测试点位建议。

### 🔀 可并行子任务（L3 多视角审查）

L3 的三个审查视角（安全审计/性能工程/可维护性）之间**完全独立**，天然适合 Fan-out：

| 并行任务 | 子 Agent 角色 | 审查焦点 |
| --- | --- | --- |
| 代码质量 + 可维护性 | 2号（代码审查） | CRITICAL/HIGH 问题扫描、命名/耦合/可读性 |
| 安全审计 | 5号（安全检查） | XSS/注入/敏感数据/CSRF/硬编码密钥 |
| 性能工程 | 6号（性能分析） | 重渲染/包体积/内存泄漏/兼容性 |

> ⏳ Fan-in → 主 Agent 汇总三份报告 → 去重 + 按严重度排序 → 输出统一 L3 审查报告
> 子代理模式下的具体调度方式详见 `shared-rules.md` §3「子代理调度指引 > 步骤 8」。
> 模式 A 环境下，主 Agent 按视角逐个审查（串行），产出相同。

**文档同步兜底检查**（时机 ③）：调用 `use_skill('tech-doc')` 按 §四 逐项检查。

**严重度处理**：🔴 必须修复回退步骤 5 | 🟡 用户决策 | 🟢 仅提示。

### 步骤推进选项（标准模式必须）

按 `steps/step-router.md` §「步骤流转交互规则」，完成标记 JSON 输出并状态同步后，**必须调用 `ask_followup_question` 弹出推进选项**（先文本表格展示，再调用工具）：

| 选项 | 说明 |
| --- | --- |
| ▶️ 继续步骤 9（反思与学习） | L3 审查通过，进入度量采集+经验提炼 |
| ⏸️ 暂停，我有补充/疑问 | 暂停等待用户输入 |
| 🔁 回退步骤 5 修复问题 | L3 审查发现需要回到编码阶段 |

> **精简模式**：步骤 8→9 无专属豁免，标准模式必须弹出。

### ⛔ 退出自检清单（逐项口播确认后才能输出完成 JSON）

- [ ] L3 多视角审查已完成（3 个子 agent：2号+5号+6号）？
- [ ] 审查报告已汇总并去重？
- [ ] 文档同步兜底检查已完成（时机③）？
- [ ] `l3_review_result` 非空？
- [ ] `critical_issues` = 0（有 CRITICAL 问题必须回退步骤 5）？
- [ ] 🔴 问题已修复并回退步骤 5 → 5.5 → 6 → 7 完整链路？
- [ ] 上述全部完成 → 才可输出完成标记 JSON

```json
{
"step": 8,
"name": "L3 代码审查",
"status": "completed",
"outputs": {
"l3_review_result": "passed | fixed_N_issues",
"critical_issues": 0,
"doc_sync_checked": true
},
"working_context_updated": true,
"next_step": 9
}

```

## 步骤 9：反思与学习（数据驱动）

> 本步骤是三层反思机制（L1/L2/L3）的核心执行点，融合度量数据采集（9a）、经验提炼（9b）、流程深度反思（9c）和 L1 即时反思输出（9d），让反思从"凭感觉"升级为"数据驱动"。L2 阶段报告按条件自动追加，L3 周期总结由用户主动触发。

### 9a. 度量数据采集与报告

**前置操作**：在反思开始前，先执行度量数据采集（详见 `references/metrics-rules.md`「数据采集时机」）：

1. 读取工作上下文，提取步骤耗时、回退次数、用户纠正等数据
2. 按 `closeout-flow.md` 环节 A「第 0 步」检测远程主干分支后，执行
   `git diff $(git merge-base $REMOTE_DEFAULT HEAD) HEAD --stat` 获取**功能分支完整改动规模**；
   检测失败时降级为 `git diff HEAD --stat`；
   **跨项目模式**：逐项目 diff 并回写 `cross_project.projects_detail`（详见 metrics-rules.md §数据采集时机 step 2a）
3. 组装 YAML 数据，写入 `~/.codebuddy/.metrics/reports/{需求ID}.yaml`
4. 更新 `~/.codebuddy/.metrics/summary.yaml` 汇总统计
5. 输出执行报告给用户（按 metrics-rules.md 报告模板，含 ASCII 趋势图）
6. **生成单需求 HTML 复盘报告并自动打开**（必须执行）：

```bash
python3 ~/.codebuddy/skills/dev-flow/scripts/gen-flow-report.py "{需求ID}"
```

- 默认行为：生成 `~/.codebuddy/.metrics/flow-reports/{需求ID}.html` 并自动 `open` 浏览器打开
- 失败容忍：脚本异常仅打印 stderr，不阻断流程；完成标记中 `flow_report_generated: false`
- 详见 `references/metrics-rules.md` §「单需求 HTML 复盘报告」
- 📌 **复盘报告链接追加到 devlog 推迟到步骤 10.4**（完整模式下 devlog 在步骤 10.4 才生成，此时无法回填；不同于标准模式的环节 I 即时回填）
7. **生成全局度量仪表盘并自动打开**（必须执行）：

```bash
python3 ~/.codebuddy/skills/dev-flow/scripts/gen-dashboard.py
```

- 默认行为：扫描全量 `reports/*.yaml`，重算 `summary.yaml`，生成 `~/.codebuddy/.metrics/dashboard.html` 并自动 `open` 浏览器打开
- 失败容忍：脚本异常仅打印 stderr，不阻断流程
- 详见 `references/metrics-rules.md` §「全局度量仪表盘」

### 9b. 代码经验提炼（数据辅助）

从本次开发中提取经验：犯过的错误、耗时环节、教训总结。
**结合度量数据**：重点关注耗时最长的步骤、回退原因、L2 问题的根因模式。
高价值经验直接写入规则文件（`create_rule`）。一切顺利时输出"本次无新增经验"并跳过。

#### 9b.1 历史踩坑根源检索（信号 3 驱动，bugfix 场景专用）

> 让反思从"AI 回顾本次"升级为"从项目全局历史中辨识是否属于重复踩坑"。
> **只在命中信号 3 时触发**，其余场景静默跳过。

**信号 3：bugfix 需要历史踩坑参考**（任一命中即触发）：

| 触发条件 | 数据来源 | 说明 |
| --- | --- | --- |
| 需求类型 = bugfix | 工作上下文 `## 需求 > 类型` | 需求明确为 bug 修复 |
| 工作上下文含 任务平台/Bug 单链接 | 工作上下文 | 有外部 bug 追溯单据 |
| `branch` 开头为 `bugfix/` | 步骤 4 JSON `branch_recommendation.branch` 或工作上下文 YAML `branch` 字段 | 分支名约定 |
| 用户命令 `dev:pitfalls` | CLI 触发 | 强制查历史踩坑 |

**不触发（静默跳过，不加载配置文件、不调 MCP）**：

- 需求类型 ≠ bugfix（新功能/重构/文案等）
- 项目未接入 知识库平台（映射表未命中）
- 用户明确 `--no-remote-kb`

**执行方式**（命中后发起 1 次 `git_doc_platform` 检索，按 [remote-knowledge.md](../references/remote-knowledge.md) §三：最大 1 次调用，Token 预算 ≤1k，top_k=3）：

```json
{
"serverName": "{knowledge | remote_kb}",
"toolName": "knowledgebase_search",
"arguments": {
"knowledge_uuid": "{从映射表取值}",
"data_type": "git_doc_platform",
"search_domain": "{当前项目的 git_doc_platform 域，限当前项目}",
"query": "常见问题 历史踩坑 排障：{bug 每关键关键词}",
"keyword": "常见问题;历史坑;排障;踩坑;{bug 相关技术关键词}"
}
}

```

**输出与匹配规则**：

1. 取前 3 个结果，仅保留「常见问题/历史坑」或「排障」相关条目，与本次 bug 根因交叉匹配
2. 命中相似踩坑 → 标记 🔴 **重复踩坑**，9b 本节必须写入经验，并评估是否需要 `create_rule`
3. 未命中 → 静默跳过，不影响 9b 正常流程

**输出区块**（仅命中时输出）：

```markdown

#### 历史踩坑比对（信号 3 命中）
| doc_platform 条目 | 类似程度 | 本次 bug 关联 | 可借鉴的修复模式 |
| --- | --- | --- | --- |
| {标题} | 🔴 重复踩坑 / 🟡 相似模式 | {一句话说明} | {从 doc_platform 中提炼的防御/修复模式} |
```

> 命中「重复踩坑」时，9b 的经验摘要必须标注「这是第 N 次同类坏」，该经验优先建议 `create_rule` 固化为规则。

### 9c. 流程自我反思（度量驱动）

**执行**：`read_file("references/flow-retrospective.md")` 加载完整反思模板。

对本次 dev-flow 执行过程进行深度反思，**以度量数据为依据**输出优化建议清单。
反思必须回答以下数据驱动问题：

- 最耗时步骤是什么？为什么？下次如何优化？
- 回退/纠正是否有规律？根因是什么？
- 与同类型需求的历史数据对比，效率如何？

**所有优化建议仅供用户评估，不自动执行**。

### 9d. L1 即时反思输出

按 `references/metrics-rules.md`「L1 即时反思」模板输出度量驱动反思。
改进行动中涉及通用性经验的，自动追加到 `~/.codebuddy/.learnings/LEARNINGS.md`。

**跳过条件**：全程无回退、无卡顿、无用户纠正，且所有指标在历史平均 ±30% 范围内时，精简为：
> 📊 本次执行数据正常，耗时 {X}，改动 {N} 文件，无异常指标。本次流程执行顺畅，无优化建议。

### 9e. 主动 Patch 钩子（Hermes 借鉴）

反思阶段识别出的 rule/skill/step 改进建议，按分级自动触发 `self-improving-agent` 能力四：

| 建议类型 | 触发条件 | 行为 |
| --- | --- | --- |
| 发现规则与实际冲突 | 有明确 diff 目标和原因 | 调用能力四，走用户确认流程 |
| 发现文档类 reference 描述过时 | 低风险改动 | 调用能力四，静默执行（仍记录到 PATCHES.md） |
| 提议新增规则 | 用户纠正 x3 以上累计 | 走 create_rule 主流程，不走 patch |
| 主观改进建议 | 无实际冲突证据 | 仅记录到 .learnings/LEARNINGS.md，不 patch |

**触发示例**：

- 本轮发现 `references/xxx.md` 引用的命令已废弃 → 能力四 patch
- 本轮因规则描述歧义导致误判 → 能力四 patch
- 本轮用户纠正了 3 次同类行为 → 建议 create_rule（非 patch）

**跳过条件**：9c 流程反思输出 smooth_no_suggestions 时，9e 整体跳过。

### 步骤推进选项（标准模式必须）（2）

按 `steps/step-router.md` §「步骤流转交互规则」，完成标记 JSON 输出并状态同步后，**必须调用 `ask_followup_question` 弹出推进选项**（先文本表格展示，再调用工具）：

| 选项 | 说明 |
| --- | --- |
| ▶️ 继续步骤 10（归档与交付） | 反思完成，进入规则归档+commit+devlog+knowledge+交付报告 |
| ⏸️ 暂停，我有补充/疑问 | 暂停等待用户输入 |
| 🔁 回退步骤 8 重新审查 | 反思中发现 L3 审查有遗漏 |

> **精简模式**：步骤 9→10 无专属豁免，标准模式必须弹出。

### ⛔ 退出自检清单（逐项口播确认后才能输出完成 JSON）

- [ ] 9a. 度量数据采集已完成？`metrics_report_generated` = true？
- [ ] 9a. 单需求 HTML 复盘报告已生成并打开？`flow_report_generated` = true？
- [ ] 9a. 全局度量仪表盘已生成并打开？`dashboard_generated` = true？
- [ ] 9b. 代码经验提炼已完成？`lessons_learned` 已填写（含"none"）？
- [ ] 9b.1 信号 3 判定已执行（如适用）？
- [ ] 9c. 流程自我反思已完成？`flow_reflection` 已填写？
- [ ] 9d. L1 即时反思已输出？
- [ ] 9e. 主动 Patch 钩子已按需触发？
- [ ] 上述全部完成 → 才可输出完成标记 JSON

```json
{
"step": 9,
"name": "反思与学习",
"status": "completed",
"outputs": {
"metrics_report_generated": true,
"metrics_file": "reports/{需求ID}.yaml",
"flow_report_generated": true,
"flow_report_file": "flow-reports/{需求ID}.html",
"flow_report_opened": true,
"dashboard_generated": true,
"dashboard_opened": true,
"lessons_learned": "经验摘要 或 none",
"flow_reflection": "优化建议摘要 或 smooth_no_suggestions",
"l1_reflection": "度量反思结论 或 normal_no_anomaly",
"rules_created": 0,
"auto_patches_count": 0,
"remote_kb_signal_3_hit": "true | false（本步骤是否触发了信号 3：bugfix 历史踩坑检索）",
"recurring_pitfall_detected": "true | false | not_applicable（信号 3 未触发时为 not_applicable）"
},
"working_context_updated": true,
"next_step": 10
}

```

## 步骤 10：归档与交付

按以下编号顺序逐项执行，**禁止跳过或合并**：

### 10.1 规则归档（必须）

步骤 9 提炼的教训融入规则文件。无新增教训时标记"无新增"并继续。

### 10.2 知识沉淀（必须，禁止跳过）

调用 `use_skill('knowledge-loop')` 沉淀模式，执行知识沉淀。

- ❌ 禁止以"改动简单"/"无新知识"/"纯样式调整"等理由跳过
- ❌ 禁止引入"评估是否需要沉淀"的判断环节
- ✅ 即使是简单改动，也至少更新已有模块规范的变更历史，或创建最小模块规范

### 10.3 生成 Commit Message（必须）

按 `references/shared-rules.md` §1「Commit Message 生成」流程执行（含复用检查、生成、用户确认、持久化）。

### 10.3.5 技术方案文档兜底对账（无条件触发：仅要求 docid 非空）

> 完整执行的最终 文档平台 同步点，消除步骤 7~10 之间 文档平台 真空问题。
> 🎯 **设计原则（方案 D 一致性）**：联调/迭代期间不强制同步，把所有累积偏离收敛到完整流程归档节点一次性兜底对账。基于 git diff 的「绝对真相」+ 工作上下文的「决策线索」+ 文档平台 原文的「章节结构」三方对账，无论中间经历多少轮迭代，最终精度恒为 100%。

**触发条件**（仅一条）：工作上下文 `doc_platform_tech_proposal.docid` 非空 → **必须执行兜底对账**。

> ⚠️ 与历史规则的差异：本步骤不再依赖「上线后 bugfix」「status=outdated」等条件——只要文档存在就对账。`status` 字段保留为状态标识，但不作为兜底对账的触发条件。

**跳过条件**：

- `action ∈ {skip, auto_inherited_skip}` 且 `docid` 为空 → 静默跳过，`doc_platform_sync_result: skipped_user_opt_out`
- diff 为空（dev 分支无改动） → `doc_platform_sync_result: skipped_no_changes`

**执行细则**：本步骤的具体执行流程（数据源采集 / 三方对账 / 偏离清单 / 用户决策 / 更新执行）由 `tech-doc/modules/doc-platform-doc.md` §「兜底对账子流程」承载（`caller=full-10`），与 `closeout-flow.md §H.3+`（`caller=standard-7`）共用同一套实现，确保标准/完整两类流程的对账精度一致。

**执行步骤**：

1. **加载兜底对账子流程**：调用 `use_skill('tech-doc')` 路由到 doc-platform-doc 模块，按 §「兜底对账子流程」执行 Step 1~Step 4

- Step 1：抓取 `git diff $(git merge-base $REMOTE_DEFAULT HEAD) HEAD`（绝对真相）
- Step 2：加载工作上下文（决策线索）
- Step 3：读取文档获取最新全文（章节结构）
- Step 4：三方对账，分类标注偏离类型（字段新增/字段修改/方案变更/数据更新/文档遗漏/范围收窄）

1. **标题保护校验**：校验文档标题与 `locked_title` 是否一致，不一致则告警并恢复
2. **生成偏离清单**：按子流程 Step 5 输出对账报告（与 H.3+ 同格式）
3. **文档质量 lint 兜底（强制）**：在保存文档前，将更新后的完整 body 落盘为本地草稿，运行：

```bash
bash ~/.codebuddy/skills/tech-doc/scripts/lints/doc-platform-lint.sh \
--doc-type {tech-proposal|tech-sharing|release-doc} <草稿路径>
```

- 退出码 `0` → 通过，继续第 5 步
- 退出码 `1` → 阻断 `doc_platform_sync_result=synced` 标记，按 violations 修复后重跑
- 退出码 `2` → 参数/路径错误

> 📌 **单一权威源**：本 lint 已在 `config/gates.yaml` 注册为 `doc-platform-doc-lint`
> （`triggers: step-8-10-full-doc_platform-publish`），跨 Skill 引用 `tech-doc/scripts/lints/doc-platform-lint.sh`。
> `doc_platform_tech_proposal.action ∈ {skip, auto_inherited_skip, relink}` 时按 `skip_conditions` 自动豁免。

1. **必须使用 `ask_followup_question`** 弹出交互式选项（与 H.3+ 偏离清单逐条对应）：

```text
【步骤 10.3.5】技术方案文档兜底对账 — 对比完毕，偏离清单已汇总。请选择：

```text

| 选项 | 说明 |
| --- | --- |
| 1️⃣ 一键应用所有变更 | AI 直接更新文档（推荐，偏离清单 ≤ 5 条时） |
| 2️⃣ 逐条确认 | 我逐条决定哪些更新、哪些跳过（偏离清单较多时） |
| 3️⃣ 仅生成报告 | AI 输出对账报告，我自己去 文档平台 手动更新 |
| 4️⃣ 跳过本次对账 | 本次不处理（输出原因到 `action_history`） |

1. **回写工作上下文**（关键，无论用户选择哪项都执行）：

- `last_synced_at` / `last_compared_at` 刷新
- `status` 更新为 `synced`（用户选 1️⃣/2️⃣ 实际更新成功时）/ `outdated`（选 3️⃣/4️⃣ 时）
- `action_history` 追加条目（含 `snapshot_sha`、`caller=full-10`、用户选择）

**边界情况**（与 H.3+ 一致）：

| 场景 | 处理 |
| --- | --- |
| diff 为空（dev 分支无改动） | 跳过对账，`doc_platform_sync_result: skipped_no_changes` |
| 工作上下文缺失 | 降级为「仅基于 diff + 文档平台 原文」两方对账，输出提醒 |
| 文档平台 文档不存在 / 无权限 | 中止对账，输出错误提示，不阻塞步骤 10 后续环节 |
| 远程主干分支检测失败 | 跳过对账，输出「⚠️ 无法获取功能分支完整 diff」 |

**`action=create` 但 `docid` 仍为空的特殊处理**（步骤 4 决策为 create 但后续未真正发布）：

- 本步骤强制触发 doc-platform-doc 模式 A 完整新建流程（含 5b lint 兜底）
- 用户确认后发布/保存，按上述第 6 步回写

### 10.4 生成/追加开发日志（必须，禁止跳过）

调用 `use_skill('tech-doc')` 路由到 devlog 模块。

- ❌ 禁止以任何理由跳过
- ❌ 禁止引入"评估是否需要 devlog"的判断环节

**复盘报告链接追加**（必须，按 `references/devlog-rules.md` §「复盘报告链接联动」规范）：

devlog 写入完成后，在最末 Round 的「相关文档」段后追加：

```markdown

#### 复盘报告
- 📊 [完整复盘报告](file:///{HOME}/.codebuddy/.metrics/flow-reports/{需求ID}.html) - 健康度评分 / KPI 对比 / 数据洞察 / 用户纠正记录 / 沉淀产出
- 📈 [全局度量仪表盘](file:///{HOME}/.codebuddy/.metrics/dashboard.html) - 累计趋势 / 跨需求对比 / 项目分布

```

- ✅ HTML 必须已由步骤 9a 第 6 步生成（不存在则跳过追加，不写死链接）
- ✅ `{HOME}` 用 `echo $HOME` 取值，禁止硬编码或留 `__HOME_DIR__` 占位符
- ✅ 已有 `#### 复盘报告` 段落则更新而非追加（避免重复）
- ✅ 柔性升级入口（commit/devlog 已在步骤 7 生成）→ 此处仅追加复盘报告链接段，不重写其他段落

### 10.5 输出交付报告（必须）

按以下模板生成交付报告。**所有文件/代码位置引用必须使用可点击链接**——遵循 `~/.codebuddy/rules/AI行为规范.mdc` 的「文件/代码位置引用」规范。

#### 交付报告模板

```markdown

## 📦 交付报告

### 需求信息
- **标题**：{需求标题}
- **任务平台**：{story/bug} | [{id}]({完整 任务平台 URL})
- **分支**：`{branch}`

### 改动汇总
| 文件 | 操作 | 关键行 | 改动说明 |
| --- | --- | --- | --- |
| `{相对路径}` | 修改 | L10-L45 | {说明} |
| `{相对路径}` | 新增 | L1-L80 | {说明} |
| `{相对路径}` | 删除 | — | {说明} |

📌 文件列与「关键行」列均为反引号包裹的可点击路径，点击直达 IDE 对应位置。

### 验证结果
- ✅ Lint：通过 / 失败数：{N}
- ✅ TypeCheck：通过
- ✅ 单元测试：{N} 通过 / {M} 失败 — 详见 [{测试相对路径}]({测试绝对路径})
- ✅ 浏览器兼容性：无新增不兼容 API / 详见 [{报告相对路径}]({报告绝对路径})

### 审查结论
- L2 审查：found:{N}_fixed:{M}
- 遗留问题：{无 | 列表（含可点击定位链接）}

### Commit Message

    {type}: {description}

    {body}

    {footer}

### 相关文档

- Devlog：[{devlog 相对路径}]({devlog 绝对路径})
- Knowledge：[{knowledge 相对路径}]({knowledge 绝对路径})
- 复盘报告：[`.metrics/flow-reports/{需求ID}.html`](file:///{用户主目录绝对路径}/.codebuddy/.metrics/flow-reports/{需求ID}.html)（步骤 9a 已自动生成并打开）

```

> 📌 **「相关文档」中的复盘报告链接**：占位符 `{用户主目录绝对路径}` 必须由 AI 在生成 Markdown 时
> 替换为真实主目录（如 `$HOME`），不要把 `__HOME_DIR__` 等模板占位符直接输出到交付报告中。
> 可执行 `echo $HOME` 取值。

#### 模板输出校验（门控）

生成交付报告后，必须逐项自检（参考 `references/gate-validator.md`「路径可点击性门控」）：

- ✅ 改动汇总表格「文件」列每一行必须匹配 `\[.+\]\(/.+\)`
- ✅ 「关键行」列要么是 `—`，要么匹配 `\[L\d+(-L\d+)?\]\(/.+#L\d+`
- ✅ 验证结果中测试文件、兼容性报告等引用必须是可点击链接
- ✅ 相关文档段 devlog / knowledge 路径必须是可点击链接
- ❌ 任何位置出现裸路径（未包裹在 `[...](...)` 中的 `/Users/...` 或 `src/...`）→ 视为未完成，必须补齐后才能推进 10.6

### 10.6 完成性校验（必须，禁止跳过）

标记 completed **之前**，逐项核对以下 checklist，输出校验表格：

<!-- markdownlint-disable MD060 -->
| # | 校验项 | 必须 | 实际状态 |
| --- | --- | --- | --- |
| 1 | Commit Message 已生成且用户已确认 | ✅ 必须 |  |
| 2 | devlog 已生成/追加（文件实际存在） | ✅ 必须 |  |
| 3 | knowledge 已沉淀（文件实际存在） | ✅ 必须 |  |
| 4 | 交付报告已输出 | ✅ 必须 |  |
| 5 | 规则归档已处理（含"无新增"） | ✅ 必须 |  |
| 6 | 文档平台 同步已完成（`doc_platform_sync_result` ∈ {synced, relinked, created, skipped_no_changes, skipped_user_opt_out}） | ✅ 必须 |  |
<!-- markdownlint-enable MD060 -->

全部 ✅ 后才能输出结构化完成标记 JSON。任何一项未通过 → 立即补齐，禁止以"稍后补"为由跳过。

### ⛔ 退出自检清单（与上方 10.6 完成性校验互补——前者校验内容，本清单校验执行过程）

- [ ] 10.1 规则归档：已处理（含"无新增"）？
- [ ] 10.2 知识沉淀：`knowledge-loop` 已调用？
- [ ] 10.3 Commit：`smart-commit` 已调用？`commit_message` 非空？
- [ ] 10.3.5 文档平台 兜底对账：条件触发时已完成三方对账 + 用户决策？
- [ ] 10.3.5 doc-platform-doc-lint 已执行且通过（如适用）？
- [ ] 10.4 Devlog：已生成/追加？复盘报告链接已追加？
- [ ] 10.5 交付报告：已输出？路径引用格式正确？
- [ ] 10.6 完成性校验 6 项全部 ✅？
- [ ] 流程锁文件 `.flow` 将在完成标记通过后删除？
- [ ] 上述全部完成 → 才可输出完成标记 JSON

```json
{
"step": 10,
"name": "归档与交付",
"status": "completed",
"outputs": {
"commit_message": "生成的 commit message 摘要",
"delivery_report": true,
"devlog_generated": true,
"rules_archived": true,
"knowledge_updated": true,
"doc_platform_sync_result": "synced | relinked | created | skipped_no_changes | skipped_user_opt_out"
},
"working_context_updated": true,
"next_step": "done"
}

```

**完成标记校验规则**：

- `commit_message` 不能为空
- `devlog_generated` 必须为 `true`（禁止为 false/skipped）
- `knowledge_updated` 必须为 `true`（禁止为 false/skipped）
- `delivery_report` 必须为 `true`
- `rules_archived` 必须为 `true`
- **`doc_platform_sync_result` 必须为枚举值之一**；`doc_platform_tech_proposal.action ∈ {skip, auto_inherited_skip}` 时
  必须为 `skipped_user_opt_out`；其他 action 必须为 `synced | relinked | created | skipped_no_changes`
  （详见 `references/gate-validator.md` §「文档平台 归档同步门控」）
- 10.6 完成性校验表格必须已输出且全部通过

> **📌 步骤 10 完成后必须删除活跃流程锁文件**：`rm -f ~/.codebuddy/working-context/.active-flows/<对应需求>.flow`（流程结束，释放活跃状态）。
