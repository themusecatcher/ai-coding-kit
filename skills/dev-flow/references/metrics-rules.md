# 流程度量机制

> 本文件定义 dev-flow 的流程度量规范，包括数据模型、采集时机、报告生成、统计分析和可视化仪表盘。
> 由 SKILL.md 引用，在 dev-flow 最终步骤自动触发。

## 存储位置

```text
~/.codebuddy/.metrics/
├── reports/                          # 单次需求度量报告（YAML）
│   ├── 20260401_disable-feature_user-project.yaml
│   └── ...
├── summary.yaml                      # 汇总统计（每次新增报告时自动更新）
└── dashboard.html                    # 可视化仪表盘（每次 summary.yaml 更新时自动重新生成）

```

## 数据模型（单次需求）

每次 dev-flow 需求完成时，生成以下结构的 YAML 文件（**扁平 schema，禁止嵌套**）：

> 三层字段语义（必填 / 推荐 / 条件采集）见下方「采集纪律（核心红线）」章节。

```yaml

# === Tier 1 必填（11 个，缺失即 ❌）===
requirement_id: "{工作上下文文件名，不含扩展名}"

# 🔴 红牌 #18：requirement_id 必须严格等于工作上下文文件名（不含 .md），

# 禁止使用 任务平台 ID / 任务平台 短 ID 或任何其他标识符。

# 写入后立即由 validate-metrics-yaml.sh 校验命名一致性。
mode: standard            # standard | full
complexity: medium        # simple | medium | complex（步骤 4 评估，缺失时按文件数/行数推断）

files_changed: 4          # 从功能分支 vs 远程主干分支的 merge-base diff --stat 获取
lines_added: 120
lines_deleted: 30

rollback_count: 0         # 步骤 6→3/5 回退次数
user_corrections: 1       # 工作上下文 🔧 [纠正] 标记计数
first_time_right: true    # rollback_count == 0 && user_corrections <= 1

l2_issues_found: 3        # L2 审查发现问题数
bugs_found_in_verify: 0   # 步骤 6 验证发现的 bug 数

# === Tier 2 推荐（12 个，缺失即 ⚠️）===

# 🆕 2026-07-03: 新增 requirement_type，AI 自动判断，缺失时兜底 feature（兼容历史数据）
requirement_type: feature  # feature | bugfix | refactor | style | other

# AI 根据需求内容自动判断，必须写入字段（不可省略依赖默认值）

# 启发式判断规则（按优先级降序）：

#   ① 任务平台 story → feature / 任务平台 bug → bugfix

#   ② devlog_dir 命名前缀（_feat_ / _fix_ / _refactor_ / _style_）

#   ③ 分支名前缀（feature/ / bugfix/ / refactor/）

#   ④ 以上均无 → feature（兜底），但仍必须写入字段

# feature: 新增功能/页面/组件

# bugfix:  修 Bug（含提测反馈、上线后修复）

# refactor: 纯重构（无功能变更）

# style:   纯样式调整（无逻辑变更）

# other:   依赖升级/配置变更等
title: "需求中文简述"           # 人类可读的需求简述（1-2 句话），用于复盘报告 hero-id 展示；

# 由 AI 根据需求内容生成，格式为简洁中文描述，不含技术实现细节

# 示例："账号恢复功能"、"详情页深色模式适配"
task_id: "1000000000xxxxx"  # 无 任务平台 时省略此 key（不要写空字符串）
task_url: ""  # 🔴 有项目跟踪链接时必填；从工作上下文提取
date: "2026-04-01"          # 简写形式，等价于 complete_date
start_date: "2026-03-25"
complete_date: "2026-04-01"
plan_adherence: full        # REQUIRED | full | minor_deviation | major_deviation | unassessed（确实无法判定时）
iteration: 1                # 迭代轮次（从工作上下文 YAML 头部读取）
knowledge_updated: true     # 是否沉淀了知识（写入 knowledge/）
devlog_generated: true      # 是否生成了 devlog
doc_url: ""  # 🔴 有技术文档时必填；从工作上下文提取
rules_created: 0
lessons_learned: 1

# 🆕 2026-07-30: 跨项目字段（仅跨项目时填写，非跨项目省略）
is_cross_project: true
projects_involved:           # 涉及的项目列表（按 project 缩写）
  - my-project
  - component-lib
primary_project: my-project # 主项目缩写

# === 自动派生字段（脚本 normalize() 计算，AI 通常无需手填）===
l2_issues_fixed: 3        # 等同 l2_issues_found，除非有未修复
issues_per_file: 0.75     # l2_issues_found / files_changed
bugs_per_100_lines: 0     # bugs_found_in_verify / (lines_added / 100)
is_iteration_fix: false   # iteration > 1 时为 true
conversation_rounds: 12   # AI 估算（注释自承不可精确统计）

# === Tier 3 条件采集（仅触发条件命中时**追加**这些 key，未命中时完全省略）===

# 仅当本流程使用了并行调度时追加：

# parallel_mode: subagent          # multi_agent_team | subagent | parallel_tool_call

# parallel_tasks_total: 3

# parallel_steps_used: [1, 5]

# result_conflicts: 0

# 仅当步骤 1/3/9 任一信号命中时追加：

# remote_kb_metrics:

#   signals_hit: ["signal_1"]

#   trigger_at_steps: [1]

#   mcp_calls_total: 2

#   mcp_tokens_estimated: 1500

#   hits_by_source: { git: 5, git_doc_platform: 2, git_commit: 0, git_merge_request: 1 }

#   adopted_count: 5

#   adoption_rate: 0.625

#   fallback_triggered: false

# 仅当为上线后 bugfix 场景时追加：

# requirement_type: bug

# escape_analysis: "提测覆盖不到的边界场景"

# root_cause_category: boundary_miss   # design_flaw | boundary_miss | env_variance | data_variance | config_error

# affected_scope: "海外英文用户"

# time_to_fix: same_day                # same_day | next_day | within_week | over_week

# original_requirement_id: "20260301_xxx"

# 仅当 user_corrections > 0 时追加（🆕 2026-07-03）：

# correction_types:           # AI 在记录纠正时同步分类，增量成本为零

#   logic: 2                  # 业务逻辑理解错误（"不对，应该是..."）

#   boundary: 1               # 遗漏边界条件/空值处理（"没考虑 loading 态"）

#   other: 0                  # 其他（命名/风格/架构调整）

```

## 复杂度推断规则（两级策略）

**优先级 1**：复用步骤 4 的评估结果（标准/完整执行时可用）

步骤 4 的 `assessment.complexity` 已基于文件数、行数、风险等级做了全面评估，直接使用。

**优先级 2**：自动推断（步骤 4 数据不可用时 fallback；「行数」= `lines_added` 新增行数）

| 条件 | 复杂度 |
| --- | --- |
| 文件 ≤2 且 行数 ≤100 | simple |
| 文件 3~6 或 行数 101~500 | medium |
| 文件 >6 或 行数 >500 | complex |

## 复杂度耗时校准（P3，dashboard 生成时）🆕 2026-07-30

**校准时机**：`gen-dashboard.py` 生成仪表盘时按实际耗时对复杂度做事后修正，**仅影响展示**，不回写 yaml 原始数据。

**耗时计算**：`complete_date - start_date`（天，最小计 1 天）；日期缺失/无效时不校准，保持原值。

| 条件 | 校准动作 |
| --- | --- |
| 耗时 ≤ 1 天且原复杂度 ≠ simple | 降级为 simple |
| 耗时 ≥ 7 天且原复杂度 ≠ complex | 升级为 complex |
| 耗时 2~6 天，或校准前后一致 | 不调整 |

**校准标记**：发生校准时生成派生字段 `complexity_calibration_note`（格式：`simple (原 medium，耗时 1d → 降级)`），dashboard 需求明细表的复杂度列以上标星号标记（如 `复杂 Complex *`），hover 显示校准说明。

**设计意图**：步骤 4 的复杂度评估是事前预估，可能与实际工作量不符（预估 medium 实际 1 天完成 / 预估 simple 实际跨 2 个月）。用真实耗时修正后，复杂度分布、缺陷密度热力图等统计口径更贴近真实工作量。

## 数据采集时机

**触发位置**：在 dev-flow 最终步骤的完成钩子中，**删除 .flow 文件之前**执行：

| 模式 | 触发位置 | 触发时机 |
| --- | --- | --- |
| 标准执行 | 步骤 7 完成钩子 | commit 确认后 |
| 完整执行 | 步骤 9 完成钩子 | 9a 度量数据采集环节 |
| 批次执行（非最后一批） | ❌ 不触发 | 非最终步骤，跳过度量采集 |
| 批次执行（最后一批） | 同标准/完整执行 | 最后一批自动切换 caller，正常触发 |

**采集流程**：

```text

1. 读取工作上下文，提取：需求信息、约束与决策（统计 🔧 [纠正] 标记数）、回退记录
2. 按 `closeout-flow.md` 环节 A「第 0 步」检测远程主干分支后，执行 `git diff $(git merge-base $REMOTE_DEFAULT HEAD) HEAD --stat` 获取**功能分支完整改动规模**（文件数、行数）；检测失败时降级为 `git diff HEAD --stat`
2a. **跨项目模式（`cross_project.enabled: true`）追加采集**：`files_changed`/`lines_added`/`lines_deleted` 写入**所有改动项目的汇总值**；同时在每个改动项目的工作区逐个执行同一 diff 命令（先做分支感知，遵循 `cross-project/integration.md` §Diff/Commit 查看规范），把逐项目结果回写主项目工作上下文 `cross_project.projects_detail`（每项目 `branch` / `files_changed` / `lines_added` / `lines_deleted` / `mr` / `mr_status`，schema 见 `templates/working-context.tpl.md`）——这是复盘报告「涉及项目」链路图的唯一数据源，未回写则节点只显示项目名与角色
3. 从完成标记 JSON 的 `l2_review_result` 字段提取 L2 审查结果：
- `"passed"` → `l2_issues_found=0, l2_issues_fixed=0`
- `"found:{N}_fixed:{M}"` → `l2_issues_found=N, l2_issues_fixed=M`
- 旧格式 `"fixed_N_issues"` → `l2_issues_found=N, l2_issues_fixed=N`（兼容历史数据，视为全部修复）
3a. 从完成标记 JSON 直接提取产出维度字段：`knowledge_updated`、`devlog_generated`
3b. 采集并行执行度量（仅本次使用了并行调度时）：
- `parallel_mode`：从首次并行调度时的平台检测结果获取（multi_agent_team | subagent | parallel_tool_call）
- `parallel_tasks_total`：累计本次流程中所有并行子任务数（从各步骤并行调度声明中统计）
- `parallel_steps_used`：记录使用了并行调度的步骤编号列表
- `result_conflicts`：从结果聚合过程中统计的矛盾/冲突次数
- 未使用并行调度时，以上字段全部留空/置零
3c. 采集 知识库平台 检索质量度量（仅步骤 1/3/9 任一命中信号时）：
- `signals_hit`：汇总步骤 1/3/9 完成标记 JSON 中的信号命中记录
- 步骤 1 JSON 的 `remote_kb_signals_hit` 数组（可含 signal_1 / signal_4）
- 步骤 3 JSON 的 `remote_kb_signal_2_hit === true` → 追加 "signal_2"
- 步骤 9 JSON 的 `remote_kb_signal_3_hit === true` → 追加 "signal_3"
- `trigger_at_steps`：根据 signals_hit 反查对应触发步骤（信号 1/4→[1]，信号 2→[3]，信号 3→[9]，信号 5→[7]）
- `mcp_calls_total`：统计本轮对话内 `use_mcp_tool` + `knowledgebase_search` 的调用次数（AI 内部计数）
- `mcp_tokens_estimated`：从步骤 1 JSON `remote_kb_tokens_used` + 步骤 3/9 估算值累加
- `hits_by_source`：从 MCP 返回中分 data_type 统计 chunk 数
- `adopted_count`：统计步骤 1/3/9 输出表格中标为 `[remote-kb/*]` 来源的条数
- `adoption_rate`：`adopted_count / (hits_by_source 总和)`；分母 0 时为 0
- `profile_status`：从阶段 0.5 完成标记 JSON 的 `stage_0_5_status` 映射（loaded_fresh→fresh，loaded_stale_soft→soft_expired，loaded_stale_hard→hard_expired，skipped_no_profile→skipped_no_profile）
- `profile_hit`：`stage_0_5_status ∈ {loaded_fresh, loaded_stale_soft, loaded_stale_hard}` 时 = true
- `fallback_triggered`：本轮是否因 MCP 失败/超时进入过降级分支
- `cli_override`：用户是否使用了 `--no-remote-kb`/`dev:ref`/`dev:mr`/`dev:pitfalls`/`--cross-project` 等 CLI 覆盖
- `refresh_triggered`：本次 dev-flow 内是否触发过 profile 刷新及其类型
- signals_hit=[] 时：`remote_kb_metrics` 除 signals_hit 和 trigger_at_steps（都为 []）外，其余字段按 YAML 默认值（空字符串/0/false）
4. 计算标准化指标（issues_per_file、bugs_per_100_lines、first_time_right）
5. 写入 `~/.codebuddy/.metrics/reports/{工作上下文文件名（不含 .md）}.yaml`
5a. 🔴 **写入后立即校验**：`bash ~/.codebuddy/skills/dev-flow/scripts/validate-metrics-yaml.sh <yaml文件>`，返回非 0 → 补齐后重试，禁止跳过。
6. 更新 `~/.codebuddy/.metrics/summary.yaml` 汇总统计
7. 输出可视化报告给用户（终端 Markdown + ASCII 趋势图）
8. **生成全局度量仪表盘并自动打开**（必须执行）：

   ```bash
   python3 ~/.codebuddy/skills/dev-flow/scripts/gen-dashboard.py
   ```

   - 默认行为：扫描 `reports/*.yaml` 全量数据，重算 `summary.yaml`，生成 `~/.codebuddy/.metrics/dashboard.html` 并自动 `open` 浏览器打开
   - 失败容忍：脚本异常仅打印 stderr，不阻断流程（终端提示用户可手动执行 `dev:metrics --dashboard`）
   - 与单需求复盘报告的差异：仪表盘是全局视图，包含累计趋势、跨需求对比、项目分布等；复盘报告是本次需求的单次复盘
   - 详见下方「全局度量仪表盘」章节

```

> **dashboard.html 主动生成**：每次 dev-flow 收尾时主动生成并打开全局仪表盘。用户也可随时通过 `dev:metrics --dashboard` 手动触发。

## 执行报告模板（需求完成时输出给用户）

```markdown

## 📊 dev-flow 执行报告

| 项目 | 值 |
| --- | --- |
| 需求 | {需求标题} |
| 模式 | {标准/完整}执行 |
| 改动 | {N} 文件，+{A}/-{D} 行 |
| 复杂度 | {simple/medium/complex} |

### 质量指标
| 指标 | 本次 | 历史均值 | 趋势 |
| --- | --- | --- | --- |
| 一次做对 | {✅/❌} | {rate}% | {📈/📉/➡️} |
| 回退次数 | {N} | {avg} | {📈/📉/➡️} |
| 用户纠正 | {N} | {avg} | {📈/📉/➡️} |
| L2 问题/文件 | {N} | {avg} | {📈/📉/➡️} |
| 验证 bug | {N} | {avg} | {📈/📉/➡️} |

### ASCII 趋势图（≥3 次需求数据时追加）

```

一次做对率趋势（最近 10 次）
100%┤          ●───●
80%┤  ●───●───●     ●───●
60%┤●─●
0%┼──┬──┬──┬──┬──┬──┬──┬──┬──┬──

\# 1 \#2 \#3 \#4 \#5 \#6 \#7 \#8 \#9 \#10

回退分布（按复杂度）
simple  ▓░░░░░░░░░  0.1 次/需求
medium  ▓▓▓░░░░░░░  0.3 次/需求
complex ▓▓▓▓▓▓▓░░░  0.7 次/需求

```text

> **ASCII 趋势图生成规则**：
> - 数据不足 3 次时不输出趋势图
> - 一次做对率用 ● 折线图，Y 轴 0~100%（仅标注 0%/60%/80%/100% 四档），X 轴最近 N 次（≤10）
> - 回退分布用 ▓░ 条形图，按复杂度分组，宽度 10 格，按比例填充（最大值占满 10 格）
> - 趋势图紧跟在质量指标表格之后、执行深度对比表格之前

### 执行深度对比
| 指标 | 本次（{depth}执行） | {depth}执行历史均值 | 全局历史均值 |
| --- | --- | --- | --- |
| 一次做对率 | {✅/❌} | {depth_rate}% | {global_rate}% |
| 回退次数 | {N} | {depth_avg} | {global_avg} |
| L2 问题/文件 | {N} | {depth_avg} | {global_avg} |

### 知识库平台 检索质量（仅信号命中时输出，signals_hit=[] 时整表跳过）
| 指标 | 本次 | 历史均值 | 趋势 |
| --- | --- | --- | --- |
| 命中信号 | {signals_hit} | {most_common_signals} | — |
| MCP 调用次数 | {N} | {avg} | {📈/📉/➡️} |
| 估算 token 消耗 | {N} | {avg} | {📈/📉/➡️} |
| 命中采纳率 | {rate}% | {avg_rate}% | {📈/📉/➡️} |
| profile 命中 | {✅/❌} | {hit_rate}% | — |
| 触发降级 | {✅/❌} | {fallback_rate}% | — |

> 仅当 remote_kb_metrics.signals_hit 非空数组时输出本表格；默认沉默场景（signals_hit=[]）整表跳过

### 洞察
- {仅在有异常指标时输出分析和建议，全部正常时输出：📊 本次执行数据正常，无异常指标。}

```

## 汇总统计文件（summary.yaml）

每次新增度量报告时，自动读取 `reports/` 目录下所有 YAML 文件，重新计算汇总：

```yaml
last_updated: "2026-04-01"
total_requirements: 15

depth_distribution:
standard: 10
full: 5

quality_averages:
rollbacks: 0.3
user_corrections: 1.2
l2_issues_per_file: 0.6
verify_bugs: 0.5
first_time_right_rate: 0.73  # 73% 的需求一次做对

quality_by_depth:
standard:
count: 10
rollbacks: 0.2
user_corrections: 0.8
l2_issues_per_file: 0.5
verify_bugs: 0.3
first_time_right_rate: 0.80
full:
count: 4
rollbacks: 0.5
user_corrections: 2.0
l2_issues_per_file: 0.8
verify_bugs: 0.8
first_time_right_rate: 0.50

iteration_stats:
first_time:                  # 首次开发（iteration == 1）
count: 12
first_time_right_rate: 0.75
iteration_fix:               # 迭代修复（iteration > 1）
count: 3
first_time_right_rate: 0.67

remote_kb_stats:                # 知识库平台 检索汇总（仅统计 remote_kb_metrics.signals_hit 非空的需求）
total_usage: 8               # 触发了任一信号的需求总数
signal_distribution:          # 各信号命中次数分布
signal_1_first_touch: 4    # 首次接触陌生模块
signal_2_plan_reference: 2 # 方案需要历史参考
signal_3_bugfix_pitfalls: 1 # bugfix 需要历史踩坑
signal_4_cross_project: 1  # 跨项目联调
signal_5_commit_ref: 0     # commit 风格参考
mcp_calls_avg: 1.4           # 平均每触发需求 MCP 调用次数
mcp_tokens_avg: 1800         # 平均每触发需求 token 消耗
adoption_rate_avg: 0.68      # 平均命中采纳率
profile_hit_rate: 0.40       # profile 命中率（profile_hit=true / total_usage）
fallback_rate: 0.08          # 降级触发率
top_zero_hit_keywords: []    # 最近 5 条 hits=0 的 keyword，用于检索质量改进（AI 采集时从对应步骤 JSON 提取）

last_l2_report_at: 10          # 上次 L2 阶段报告时的 total_requirements 值

# 🆕 2026-07-03: 需求画像维度
requirement_type_distribution:  # 需求类型分布
feature: 12
bugfix: 5
refactor: 2
style: 1
other: 0

quality_by_type:                # 按需求类型的质量对比
feature:
count: 12
rollbacks: 0.2
user_corrections: 1.0
l2_issues_per_file: 0.5
verify_bugs: 0.3
first_time_right_rate: 0.83
bugfix:
count: 5
first_time_right_rate: 0.60

# ... 同 feature 结构

correction_type_trend:          # 纠正类型按月趋势（仅 user_corrections > 0 时累积数据）
months: ["2026-05", "2026-06"]
logic: [2, 1]                 # 逻辑错误次数
boundary: [1, 0]              # 边界遗漏次数
other: [0, 0]                 # 其他类型次数

monthly_throughput:             # 月度需求完成数
months: ["2026-04", "2026-05", "2026-06"]
counts: [4, 3, 5]

recent:

- id: "20260401_disable-feature_user-project"
mode: standard
rollbacks: 0
files: 4
first_time_right: true

```

## 异常检测

| 异常类型 | 检测条件 | 报告标注 |
| --- | --- | --- |
| 回退异常 | 回退次数 > 历史平均 × 2 且 ≥2 | ⚠️ 回退频繁，建议加强需求理解和方案设计 |
| 质量异常 | L2 问题/文件 > 历史平均 × 2 且 ≥1.5 | ⚠️ 代码质量问题较多，建议编码时加强自检 |
| 规模异常 | 改动文件数 > 10 | ⚠️ 改动范围较大，建议拆分为多个子需求 |
| 知识库平台 成本异常 | mcp_tokens_estimated > 档位上限× 1.2 | ⚠️ 知识库平台 Token 超预算，建议检查压缩策略或调低档位 |
| 知识库平台 质量异常 | adoption_rate < 0.2 且 mcp_calls_total ≥2 | ⚠️ 知识库平台 命中采纳率偏低，建议扩展 keyword 变体或切换档位 |
| 知识库平台 漂移异常 | fallback_triggered 连续 3 次为 true | ⚠️ MCP 连续降级，建议排查网络/MCP server 或运行 `dev:ob -r` 刷新 profile |

## 三层反思机制

### L1 即时反思（每次需求完成时）

**融入位置**：完整执行步骤 9 / 标准执行步骤 7 环节 I 完成标记前。

```markdown

### 📊 度量驱动反思

**本次关键数据**：一次做对 {✅/❌} | 回退 {N} 次 | L2 问题/文件 {N} | 验证 bug {N}
**执行深度对比**：本次（{depth}执行）vs {depth}执行历史均值

**数据洞察**：{质量分析：回退/L2问题是否有规律？根因是什么？}

**改进行动**（仅列出可落地的具体行动）：
- {行动1}

```

**跳过条件**：所有指标均在历史平均 ±30% 范围内，且 first_time_right=true 时，精简为：
> 📊 本次执行数据正常，无异常指标。

### L2 阶段报告（每 3~5 个需求）

`total_requirements - last_l2_report_at >= 5` 时，在 L1 报告末尾追加（`last_l2_report_at` 记录在 summary.yaml 中）：

```markdown

### 📈 阶段性分析（第 {M}~{N} 个需求）
**质量趋势**：一次做对率从 {上一阶段} → {本阶段}
**高频问题模式**：{跨需求重复出现的问题类型，如有}
**建议**：{基于趋势的优化建议}
**执行深度对比**：标准执行一次做对率 {X}% vs 完整执行 {Y}%
**深度洞察**：{如"标准执行回退率偏高，建议复杂任务升级为完整执行"}

```

### L3 周期总结（用户主动触发）

通过 `dev:metrics --all` 或 `dev:metrics --trend` 命令触发，输出全量统计和深度分析。

## 用户命令

| 命令 | 说明 |
| --- | --- |
| `dev:metrics` | 查看最近 5 次需求的度量概览 |
| `dev:metrics --all` | 查看全部历史统计（从 summary.yaml 读取，含轻量一致性校验） |
| `dev:metrics --trend` | 查看质量趋势（一次做对率、回退率随时间变化） |
| `dev:metrics --report {需求ID}` | 生成并打开指定需求的单需求 HTML 复盘报告（调用 `gen-flow-report.py {需求ID}`） |
| `dev:metrics --report {需求ID} --no-open` | 仅生成单需求报告，不打开浏览器 |
| `dev:metrics --dashboard` | 生成/打开全局可视化仪表盘（HTML），自动调用 `open` 命令在浏览器中打开 |

## 单需求 HTML 复盘报告（flow-report）

### 概述

在每次 dev-flow 收尾时（标准执行步骤 7 环节 I / 完整执行步骤 9a），自动生成单条需求的 HTML 复盘报告并打开浏览器，让用户即时查看本次执行的复盘视图。

**与全局仪表盘的边界**：

| 维度 | 全局仪表盘（dashboard.html） | 单需求复盘报告（flow-reports/{需求ID}.html） |
| --- | --- | --- |
| 数据源 | `reports/*.yaml` 全量 | 单条 `reports/{需求ID}.yaml` + summary 历史均值 |
| 触发 | dev-flow 收尾自动 / `dev:metrics --dashboard` 手动补充 | dev-flow 收尾自动 |
| 内容 | 累计趋势/分布/热力图（10+ 图表） | 5 区块：Hero / KPI 对比 / 洞察 / 纠正+沉淀 / 元数据+链接 |
| 受众 | 横向对比、长期回顾 | 本次需求的复盘 |

### 存储位置（2）

```text
~/.codebuddy/.metrics/
├── reports/{需求ID}.yaml             # 单需求度量数据（已有）
├── flow-reports/                      # 单需求 HTML 复盘报告（新）
│   └── {需求ID}.html
├── summary.yaml                       # 全局汇总（已有）
└── dashboard.html                     # 全局仪表盘（已有）

```

### 生成方式

调用常驻脚本 `~/.codebuddy/skills/dev-flow/scripts/gen-flow-report.py`（确定性实现）：

```bash

# dev-flow 收尾自动调用：生成 + 自动打开浏览器
python3 ~/.codebuddy/skills/dev-flow/scripts/gen-flow-report.py "{需求ID}"

# 仅生成不打开（用于批量回填或调试）
python3 ~/.codebuddy/skills/dev-flow/scripts/gen-flow-report.py "{需求ID}" --no-open

```

脚本职责：

1. 读取 `reports/{需求ID}.yaml`（必需，找不到直接退出）
2. 读取全量 reports 计算同模式历史均值（缺失样本时降级到全局均值）
3. 从工作上下文 grep `🔧 [纠正]` 行 + 回退记录
4. 探测关联资源：`dev-logs/{slug}/devlog.md` / `knowledge/{project}/` / `working-context/{slug}.md`
5. 异常检测（复用本文件「异常检测」表）+ 健康度评分（0-100）
6. 读 `references/templates/flow-report.tpl.html` → 替换 `__FLOW_DATA__` / `__HOME_DIR__` / `__GENERATED_AT__` / `__REQUIREMENT_ID__` 占位符
7. 写入 `flow-reports/{需求ID}.html`
8. macOS 调用 `open`、Linux 调用 `xdg-open` 自动打开（`--no-open` 关闭）

### 触发模式适用矩阵

| 模式 | 触发位置 | 是否生成 | 自动打开 |
| --- | --- | :---: | :---: |
| `standard` | 步骤 7 环节 I 第 2 步 | ✅ | ✅ |
| `full` | 步骤 9a 第 6 步 | ✅ | ✅ |
| `batch`（中间批次） | — | ❌（无度量数据） | — |
| `batch`（最后一批） | 自动切到 standard/full，正常触发 | ✅ | ✅ |
| `micro-fix` | — | ❌（不采集度量，无源数据） | — |
| 柔性升级 standard→full | 步骤 7 已生成 → 步骤 9 跳过重复生成 | — | — |

### 失败容忍

- 脚本异常（找不到 yaml / 模板缺失 / 渲染失败）→ stderr 打印错误，**不阻断流程**
- `open` / `xdg-open` 失败（headless / 远程 SSH）→ 降级为打印路径，完成标记 `flow_report_opened: false`
- 完成标记字段：`flow_report_generated` / `flow_report_file` / `flow_report_opened`

### 报告内容（5 区块）

```text
┌─ Hero ──────────────────────────────────────────────────┐
│ 需求 ID + 标签（一次做对/模式/复杂度/规模/迭代）          │
│ 健康度评分环（0-100，绿/黄/红 分级）                       │
│ 元信息（起止日期 / 分支 / 任务平台 ID）                        │
├─ KPI 对比（4×2 = 8 张卡片）─────────────────────────────┤
│ 一次做对 / 回退 / 纠正 / L2 问题/文件                     │
│ 验证 Bug / 改动文件 / 改动行数 / 计划吻合度                 │
│ 每张卡片：本次值 + 同模式历史均值 + ↑↓ 偏离百分比           │
├─ 数据洞察（自动派生，不编造）──────────────────────────┤
│ 来源「异常检测」表：回退异常 / 质量异常 / 规模异常 /          │
│       纠正异常 / 验证 Bug 异常 / 全部正常                  │
├─ 用户纠正 + 沉淀产出（双列）──────────────────────────┤
│ 左：从工作上下文 grep 🔧 [纠正] 行                         │
│ 右：Devlog/Knowledge/Rules/Lessons 状态 + 链接             │
├─ 元数据 + 关联链接 ──────────────────────────────────┤
│ 工作上下文 / Devlog / Knowledge / 任务平台 / 文档平台 / 仪表盘    │
└─────────────────────────────────────────────────────────┘

```

### 设计原则

- **真实性**：所有展示数据均来自 `reports/{需求ID}.yaml` 实测字段、git stat、工作上下文 grep。无步骤耗时图表（无真实数据）、无杜撰的对比维度
- **零依赖**：纯 HTML + 内联 CSS/JS，无外部 CDN（除浏览器原生字体），file:// 直接打开
- **视觉一致**：复用 templates/dashboard.tpl.html 的 CSS 变量（`--bg-primary` / `--accent` 等暗色主题）
- **降级显示**：缺失字段对应区块显示「未采集」/「无」，不报错不阻断

### 禁止行为（1）

- ❌ 禁止手动编辑 `flow-reports/*.html`（由 `gen-flow-report.py` 每次覆盖）
- ❌ 禁止在报告中编造数据（所有数据来自 reports yaml + 工作上下文，找不到则降级显示）
- ❌ 禁止在 micro-fix 模式下强行生成（无度量数据，违反「采集纪律」）
- ✅ `templates/flow-report.tpl.html` 允许手动调整样式和 5 区块布局

### 概述（2）

独立的 HTML 文件，使用 ECharts v5（CDN 引入）渲染交互式图表，Tabulator v6 渲染可排序表格。每次 `summary.yaml` 更新时自动重新生成。
用户也可通过 `dev:metrics --dashboard` 手动触发生成并打开。

### 技术方案

- **图表库**：ECharts v5（`https://cdn.jsdelivr.net/npm/echarts`）+ Tabulator v6（`https://cdn.jsdelivr.net/npm/tabulator-tables`），CDN 引入，零本地依赖
- **数据源**：读取 `~/.codebuddy/.metrics/summary.yaml` + `reports/*.yaml` 全部数据
- **视觉风格**：复用 flowchart.html 的暗色主题（`--bg-primary: #09090b` 系列 CSS 变量）
- **模板位置**：`~/.codebuddy/skills/dev-flow/references/templates/dashboard.tpl.html`
- **生成方式**：调用常驻脚本 `~/.codebuddy/skills/dev-flow/scripts/gen-dashboard.py`（确定性实现，禁止 AI 临场手写解析逻辑）：
- 读取 `reports/*.yaml` 全量（兼容多文档 YAML）→ **schema 归一化**（见下）→ 重算 summary → 读取模板 → 替换 `__METRICS_DATA__`/`__HOME_DIR__` → 写入 `dashboard.html`
- `dev:metrics --dashboard` → `python3 gen-dashboard.py`（脚本默认即生成并自动打开浏览器）
- `dev:metrics --all` → `python3 gen-dashboard.py --no-open`（重算 summary，不打开浏览器，终端再补充全量统计）
- 依赖 PyYAML，缺失时脚本会提示 `python3 -m pip install pyyaml`

#### Schema 校验闸门（脚本内置）

`gen-dashboard.py` 加载每个 report 时执行 `validate_report()` 校验：

| 字段类别 | 缺失行为 | 输出位置 |
| --- | --- | --- |
| Tier 1 必填（11 个） | ❌ stderr 报错 + dashboard 健康度徽章红色 | 终端 + dashboard 头部 |
| Tier 2 推荐（9 个） | ⚠️ stderr 警告 + dashboard 健康度徽章黄色 | 终端 + dashboard 头部 |
| Tier 3 条件采集 | 不校验（按"仅触发条件命中时记录"语义） | — |

校验**不阻塞 dashboard 渲染**，仅作可观测性提示。`reports/*.yaml` 必须使用扁平 schema + Tier 1 标准字段名（详见「采集纪律」红线）。

> 历史嵌套 schema（`requirement.id` / `quality.l2_review` 等多层结构）已于 2026-06-02 一次性扁平化迁移完成，`normalize()` 不再保留嵌套 fallback 链。
> 新生成的报告若使用嵌套或字段别名（如 `rollbacks` / `lines_removed`），校验闸门会立即报告必填缺失。

### 仪表盘布局

```text
┌─────────────────────────────────────────────────────────────┐
│  📊 dev-flow 度量仪表盘                                      │
│  最后更新：{date} | 累计需求：{N} | 一次做对率：{rate}%        │
├─────────────────────────────────────────────────────────────┤
│  ┌─ 概览卡片（3×2 布局，6 KPI）─────────────────────────┐  │
│  │ 累计需求 │ 一次做对率 │ 平均回退                        │  │
│  │ 平均 L2 问题/文件 │ 平均用户纠正 │ 平均验证缺陷         │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌─ ⚠️ 异常检测告警面板（≥3 条数据时激活）───────────────┐  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌─ 折线图：质量趋势 ────────────────────────────────────┐  │
│  │ 多 Y 轴：一次做对率（%）、回退次数、L2 问题/文件       │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌─ 环形图：执行深度分布 ─┐  ┌─ 环形图：复杂度分布 ──────┐  │
│  │ standard / full / wrap │  │ simple / medium / complex  │  │
│  └────────────────────────┘  └────────────────────────────┘  │
│  ┌─ 分组柱状图：质量指标 × 执行深度对比 ─────────────────┐  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌─ 堆叠柱状图：代码规模趋势 ───────────────────────────┐  │
│  │ +added（绿）/ -deleted（红），X 轴按日期排列           │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌─ 🧠 知识全景 Knowledge Panorama ─────────────────────┐  │
│  │ 4 张概览卡片：总条目/本月新增/知识债务/验证滞后          │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌─ 知识增长曲线 ─────────┐  ┌─ 置信度分布 ──────────────┐  │
│  │ 5 层堆叠折线：模块知识  │  │ 环形图：verified/scanned │  │
│  │ /易错点/模式/手册/教训  │  │ /draft/stale/unlabeled   │  │
│  └────────────────────────┘  └────────────────────────────┘  │
│  ┌─ 知识产出率 ───────────┐  ┌─ 项目分布（环形图）──────┐  │
│  │ Knowledge率/Devlog率/Rules │  │ 从 requirement_id 提取   │  │
│  │ /Lessons + 进度条      │  │ 项目名自动分组           │  │
│  └────────────────────────┘  └────────────────────────────┘  │
│  ┌─ 需求耗时分布 ─────────┐  ┌─ 缺陷密度热力图 ─────────┐  │
│  │ 相邻需求日期差（天）    │  │ 3×3 矩阵：复杂度×指标   │  │
│  │ 柱色按执行深度区分      │  │ 颜色从绿→红渐变         │  │
│  └────────────────────────┘  └────────────────────────────┘  │
│  ┌─ 🔔 执行深度建议面板 ────────────────────────────────┐  │
│  │ 5 条智能规则，条件触发，卡片式展示                      │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌─ 需求明细表格（最近 20 条，16 列，可排序）───────────┐  │
│  │ 上下文│项目│日期│耗时│深度│复杂度│类型│FTR│…│产物     │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

```

### 图表详细规格

| 图表 | 类型 | 数据源 | 说明 |
| --- | --- | --- | --- |
| 概览卡片 | 数字卡片（3×2） | summary.yaml | 6 个核心 KPI，含用户纠正和验证缺陷 |
| 异常告警 | 条件卡片 | reports 最新一条 vs 均值 | ≥3 条数据激活，3 条规则（回退/质量/规模） |
| 质量趋势 | 折线图（Line） | reports/*.yaml 按日期排序 | 多 Y 轴：左轴一次做对率（%），右轴回退/L2 |
| 执行深度分布 | 环形图（Doughnut） | summary.depth_distribution | 双色区分 standard/full |
| 复杂度分布 | 环形图（Doughnut） | reports 按 complexity 统计 | 三色区分 simple/medium/complex |
| 深度对比 | 分组柱状图（Bar） | summary.quality_by_depth | 每个指标按深度分组对比 |
| 代码规模趋势 | 堆叠柱状图（Bar） | reports.lines_added/deleted | 正值新增（绿），负值删除（红） |
| **知识概览卡片** | 数字卡片（4 张） | knowledge/ 扫描 → knowledge_panorama.overview | 总条目/本月新增/知识债务率/平均验证滞后 |
| **知识增长曲线** | 5 层折线图（Area） | knowledge/ 扫描 → growth_timeline | 模块知识/易错点/设计模式/操作手册/经验教训累计增长 |
| **置信度分布** | 环形图（Doughnut） | knowledge/ frontmatter → confidence_distribution | verified/scanned/draft/stale/unlabeled 五段分布 |
| 知识产出率 | 数字卡片 + 进度条 | reports 产出维度字段 | knowledge率/devlog率/rules数/lessons数 |
| 项目分布 | 环形图（Doughnut） | reports.requirement_id 后缀 | 自动提取项目名分组统计 |
| 需求耗时分布 | 柱状图（Bar） | reports 相邻日期差 | 柱色按执行深度区分，近似耗时 |
| 缺陷密度热力图 | CSS Grid 热力图 | reports 按复杂度分组 | 3×3 矩阵，颜色从绿→红渐变 |
| 深度建议 | 条件卡片面板 | reports 按模式分组分析 | 5 条智能规则，条件触发 |
| 需求明细 | HTML 表格（16 列） | reports/*.yaml 最近 20 条 | 支持排序，含耗时/类型/用户纠正/代码规模/密度指标等列；复杂度列带 `*` 上标表示耗时校准值 |

### 知识全景数据模型（knowledge_panorama）

> `gen-dashboard.py` 每次运行时扫描 `~/.codebuddy/knowledge/` + `~/.codebuddy/.learnings/` 目录，
> 解析所有 .md 文件的 YAML frontmatter，自动生成以下结构注入到 `__METRICS_DATA__.knowledge_panorama`。

```yaml
knowledge_panorama:
overview:                        # 概览指标
total_entries: 69              # 知识条目总数
new_this_month: 5              # 本月新增条目数
stale_ratio: 0.0               # 过期条目占比（confidence=stale 的条目/总数）
stale_count: 0                 # 过期条目数
avg_verification_lag_days: 72.4  # 平均验证滞后天数
projects_with_knowledge: 10    # 已有知识沉淀的项目数

growth_timeline:                 # 知识增长时间线（按月累计）
months: ["2026-04", "2026-05", "2026-06"]  # 月份列表
series:

- name: "模块知识"           # index/overview/data-model/api/logic/ui
data: [3, 12, 25]          # 累计数

- name: "易错点"             # pitfalls.md
data: [0, 3, 5]

- name: "设计模式"           # _patterns/*.md
data: [0, 1, 2]

- name: "操作手册"           # _recipes/*.md
data: [0, 0, 0]

- name: "经验教训"           # .learnings/*.md
data: [0, 0, 1]

confidence_distribution:         # 置信度分布
verified: 24                   # 已验证
scanned: 0                     # 已扫描（自动提取）
draft: 0                       # 草稿
stale: 0                       # 过期（代码已变更但知识未更新）
unlabeled: 45                  # 未标注（无 frontmatter）

projects_coverage:               # 各项目知识覆盖（用于未来雷达图）
my-project:
modules_documented: 5
with_pitfalls: 3
with_api: 4
with_data_model: 4
patterns: 1
recipes: 0
lessons: 0
user-project:
...

```

**数据采集规则**：

| 字段 | 来源 | fallback 链 |
| --- | --- | --- |
| `created` | frontmatter `created` | git log `--diff-filter=A` 首次提交日期 → 文件 mtime → 当天日期 |
| `confidence` | frontmatter `confidence` | `"unlabeled"`（无 frontmatter 时） |
| `type` | 文件名 + 所在目录 | `_index`/`_patterns`/`_recipes`/`pitfalls` 等 |
| `project` | 文件路径第一级目录名 | `_global` 或 `_unknown` |

### 生成时机

| 触发场景 | 行为 |
| --- | --- |
| dev-flow 收尾（标准执行步骤 7 环节 I / 完整执行步骤 9a） | `python3 scripts/gen-dashboard.py` → 重算 summary + 生成 dashboard.html + **自动打开**浏览器 |
| `dev:metrics --dashboard` | 同收尾自动触发：`python3 scripts/gen-dashboard.py` → 重算 summary + 生成 dashboard.html + **脚本默认自动打开**浏览器（手动补充生成） |
| `dev:metrics --all` | `python3 scripts/gen-dashboard.py --no-open`（重算 summary，含一致性校验）+ 终端输出 + 提示用户可用 `--dashboard` 查看图表 |

> 收尾时主动生成仪表盘，让用户每次需求完成后都能看到全局趋势变化。手动 `dev:metrics --dashboard` 作为补充手段保留。

### 数据注入格式

模板中使用两个占位符，生成时替换：

- `__METRICS_DATA__`：替换为度量数据 JSON
- `__HOME_DIR__`：替换为用户主目录路径（如 `$HOME`），用于需求明细表格中工作上下文文件的链接拼接

```javascript
const METRICS_DATA = __METRICS_DATA__;
// 结构：
// {
//   summary: { ... },           // summary.yaml 完整内容
//   reports: [ ... ],           // reports/*.yaml 按日期排序的数组
//   generated_at: "2026-04-13"  // 生成时间
// }

```

## 与 devlog 联动

度量报告中的关键数据自动嵌入 devlog 的 Round 记录末尾：

```markdown

#### 度量摘要
- 模式：{标准/完整}执行 | 改动：{N} 文件 +{A}/-{D} 行 | 一次做对：{✅/❌}
- 质量：回退 {N} 次 | L2 问题/文件 {N} | 验证 bug {N}

```

## 反思与 .learnings/ 联动

L1 反思中产出的「改进行动」，如涉及通用性经验，自动追加到 `~/.codebuddy/.learnings/LEARNINGS.md`。
同一类改进行动出现 ≥3 次 → 自动提议提升为规则（`create_rule`）。

## 执行深度升级建议机制

在 L2 阶段报告中自动检测并输出执行深度建议：

| 检测条件 | 建议 |
| --- | --- |
| 连续 3 次标准执行的回退率 > 完整执行历史均值 | ⬆️ 近期标准执行质量指标偏低，建议对类似复杂度的需求考虑使用完整执行 |
| 连续 3 次完整执行的所有指标均优于历史均值 | ⬇️ 近期完整执行质量稳定，可考虑对低复杂度需求使用标准执行以提升效率 |

> 建议仅在 L2 阶段报告中输出，不阻塞流程，供用户在步骤 4 智能评估时参考。

## user_corrections 统计规则

### 采集方式：工作上下文锚点

纠正次数**不在最后采集时回溯估算**，而是在流程中**实时标记**到工作上下文「约束与决策」区块：

- 检测到用户纠正行为时，立即在「约束与决策」区块追加 `🔧 [纠正]` 标记
- 度量采集时：`user_corrections = 工作上下文中 🔧 [纠正] 标记的计数`

标记格式：

```text

- [HH:mm] 🔧 [纠正] {纠正内容描述}

```

### 纠正判定规则

以下情况计为 1 次纠正：

- 用户否定了 AI 的方案/判断（如"不对，应该这样做"）
- 用户指出 AI 的理解错误（如"你理解错了，需求是..."）
- 用户要求回退到之前的方案

以下情况**不计为**纠正：

- 用户在多个选项中做出选择（这是正常决策）
- 用户补充了新信息（这是信息增量）
- 用户调整了优先级或范围（这是需求变更）

## plan_adherence 判定规则

| 值 | 含义 | 判定条件 |
| --- | --- | --- |
| `full` | 完全按计划执行 | 所有计划步骤按预期执行，无偏差 |
| `minor_deviation` | 小幅偏差 | 有小幅调整但不影响整体方案（如调整实现细节） |
| `major_deviation` | 重大偏差 | 方案有重大变更（如新增/删除计划步骤、改变技术路线） |

## 一致性校验（dev:metrics --all 自动执行）

`gen-dashboard.py` 每次运行都会**重算 summary**，等价于内置一致性校验：

1. 扫描 `reports/` 目录下所有 YAML 文件（归一化后全量纳入统计）
2. 重新计算 `total_requirements` 及各项汇总，覆盖写入 `summary.yaml`（写入前自动备份为 `summary.yaml.bak`）
3. 因此 summary 与 reports 始终保持一致，无需单独的对比逻辑

> 此机制覆盖最常见的数据不一致场景（如采集失败导致 summary 未更新、report schema 漂移导致漏统计）。

## 采集纪律（核心红线）

> 度量采集是 dev-flow 步骤 7-I / 9-9a 的**必执行环节**，**禁止跳过、禁止留空、禁止编造**。
> 执行时机：标准执行 step-7-I，完整执行 step-9-9a，批次最后一批（非最后一批跳过）。
> 每次 `dev:metrics --dashboard` 运行时会自动跑校验闸门，缺失字段会在 stderr 输出 ❌/⚠️ 并在 dashboard 头部健康度徽章中可见。

### Tier 1 必填字段（11 个，缺失即 ❌）

| 字段 | 类型 | 来源 |
| --- | --- | --- |
| `requirement_id` | string | 工作上下文文件名（不含扩展名）🔴 #18 禁止用 任务平台 ID |
| `mode` | `standard` &#124; `full` | 步骤 4 智能评估结果 |
| `complexity` | `simple` &#124; `medium` &#124; `complex` | 步骤 4 评估，缺失时按文件数/行数推断；dashboard 生成时按实际耗时校准（仅影响展示，见「复杂度耗时校准」） |
| `files_changed` | int | `git diff --stat` 功能分支汇总 |
| `lines_added` | int | 同上 |
| `lines_deleted` | int | 同上 |
| `rollback_count` | int | 工作上下文中"步骤 6→3/5 回退"标记计数 |
| `user_corrections` | int | 工作上下文中 `🔧 [纠正]` 标记计数 |
| `first_time_right` | bool | `rollback_count == 0 && user_corrections <= 1` |
| `l2_issues_found` | int | 完成标记 JSON 的 `l2_review_result` 解析 |
| `bugs_found_in_verify` | int | 步骤 6 验证发现的 bug 数 |

### Tier 2 推荐字段（12 个，缺失即 ⚠️）

| 字段 | 说明 |
| --- | --- |
| `requirement_type` | `feature` / `bugfix` / `refactor` / `style` / `other`，AI 根据启发式规则自动判断并写入（见上方字段注释），禁止省略留空依赖兜底 |
| `knowledge_updated` / `devlog_generated` | 完成标记 JSON 直接提取 |
| `rules_created` / `lessons_learned` | 步骤 9b/10.1 产出统计 |
| `plan_adherence` | 见下文「plan_adherence 判定规则」 |
| `iteration` | 工作上下文 YAML 头部读取 |
| `start_date` / `complete_date` | 工作上下文创建时间 / 采集时刻 |
| `is_cross_project` | 是否为跨项目需求（`true` / `false`），从工作上下文 `cross_project.enabled` 提取 |
| `projects_involved` | 涉及的项目缩写列表（如 `[my-project, component-lib]`），来源：`cross_project.origin_project` + `fix_project` |
| `primary_project` | 主项目缩写（即修复代码所在的项目），来源：工作上下文 `project` 字段或 `cross_project.fix_project` |
| 跨项目规模口径 | 跨项目时 `files_changed` / `lines_added` / `lines_deleted` 为**所有改动项目的汇总值**；逐项目明细回写工作上下文 `cross_project.projects_detail`（见 §数据采集时机 step 2a），复盘报告链路图与 KPI 拆分以此为准 |

> 缺失推荐字段不阻断 dashboard 渲染，但雷达图、热力图、产出统计面板的对应维度会按默认值降级显示，会导致历史趋势失真。

### Tier 3 条件采集字段（仅触发条件命中时记录）

| 字段族 | 触发条件 |
| --- | --- |
| `parallel_mode` / `parallel_tasks_total` 等 | 本流程使用了并行调度（multi_agent_team / subagent / parallel_tool_call） |
| `remote_kb_metrics.*` | 步骤 1/3/9 任一信号命中（见 `remote-knowledge.md`） |
| Bugfix 专属 5 字段（`escape_analysis` 等） | `requirement_type: bug` 且为上线后 bugfix |

> 触发条件未命中时**完全省略字段**（不要写空值占位），dashboard 与校验闸门均不会因省略而告警。

### 数据来源溯源（禁止编造）

每个字段必须有明确来源：工作上下文 / 完成标记 JSON / git stat / 任务平台 / 文档平台。

- 找不到来源时 → 字段**留空**（YAML 中省略该 key），让校验闸门标 ⚠️
- 严禁基于"看起来差不多"或"AI 估算"填值（注释自承"不可精确统计"的字段除外，如 `conversation_rounds`）
- `plan_adherence` 为 **REQUIRED** 字段（2026-07-06 升级），必须从 plan.md vs git diff 判定后填写；确实无法判定时填写 `"unassessed"`（真实值），不要默认 `full`

### 禁止行为（2）

- ❌ 禁止跳过度量报告生成（即使 micro/bugfix 简单任务也要生成）
- ❌ 禁止在度量报告中编造数据（所有数据必须从工作上下文 / 完成标记 JSON / git 中提取）
- ❌ 禁止手动编辑 `dashboard.html`（由 `gen-dashboard.py` 每次覆盖）
- ❌ 禁止手动编辑 `summary.yaml`（由 `gen-dashboard.py` 重算覆写。汇总异常应修复 `reports/*.yaml` 源文件后重跑 `dev:metrics --dashboard`）
- ❌ 禁止使用嵌套 schema（`requirement.id` / `quality.l2_review` 等多层结构）。历史嵌套报告已于 2026-06-02 一次性扁平化迁移
- ❌ 禁止使用字段别名（如 `rollbacks` / `lines_removed` / `files_modified` / `execution_depth` / `iterations`），必须使用 Tier 1 标准字段名
- ✅ `reports/*.yaml` 允许在数据异常或字段补充时手动修正源文件，但必须遵守扁平 schema + Tier 1/2/3 字段语义
- ✅ `templates/dashboard.tpl.html` 允许手动调整样式和布局
