# 工作上下文文件模板

> **本文件是工作上下文文件的完整模板**（YAML Front Matter + Markdown 正文区块）。
> AI 创建新工作上下文文件时，必须 `read_file` 本文件，按此模板逐字段填充。
> **规则与说明**（命名规则、字段语义、更新规则、阶段感知区块、创建/更新决策流程）→ `references/working-context.md`（单一权威源）。
> 修改本模板需同步更新 `working-context.md` 的字段说明表，避免双权威源漂移。

---

## 文件模板

```markdown
---

# YAML Front Matter（机器可读状态，跨会话恢复时优先解析此区块）
mode: standard                 # standard | full | micro-fix | iteration-fix | batch | cross-project

# mode_history:                  # 柔性升级/降级轨迹（仅发生过模式迁移时存在）

#   - from: standard

#     to: full

#     at: "2026-05-10T11:00:00"

#     reason: "user_choice_post_commit"  # user_choice_post_commit | auto_downgrade_micro_fix
current_step: 1                # 当前步骤编号（0/1/2/3/4/4.5/5/5.5/6/7/8/9/10）
status: in_progress            # in_progress | completed | blocked | paused
iteration: 1                   # 迭代轮次（首轮为 1，迭代修复时递增）
interaction_mode: standard     # standard | streamlined（精简交互模式）
complexity: medium             # simple | medium | complex（需求复杂度）
branch: ""                     # 父分支名（步骤 4 §4.1 定稿后写入，是合入目标分支的唯一真相源）
branch_dev: ""                 # 孙分支名（feature/ 场景且选了孙分支时为 feature_dev/.../<开发者>；其他场景= branch）
branch_workspace: ""           # 用户选定的实际编码分支（= branch 或 branch_dev，步骤 4.5 优先读取此字段做环境检查）
has_dev_branch: false          # 是否推荐了孙分支（仅 feature/ 场景为 true）
branch_status: ""              # auto_recommended | user_modified | user_specified | iteration_reuse【步骤 4 定稿后写入】
task_id: ""                    # 任务平台 ID
project: ""                    # 项目路径（跨项目场景取当前编码项目的路径，与文件名中的 crossProject 标识互补）
start_time: ""                 # 流程开始时间（ISO 8601）
signals: []                    # 条件激活信号数组，如 [figma_url, step_4_5_env_check]，控制 references/ 条件加载

# 批次执行相关（仅分批执行时填写，非批次模式不含以下字段）

# batch_mode: true              # 是否为分批执行

# current_batch: 1              # 当前批次号

# total_batches: 3              # 总批次数

# batches:

#   1:

#     status: completed          # pending | in_progress | completed

#     steps: [1, 2, 3]           # 本批次包含的计划步骤编号

#     goal: "基础类型定义"        # 本批次目标

#     commit_hash: ""            # 本批次 commit hash

#     start_time: ""

#     end_time: ""

#   2:

#     status: in_progress

#     steps: [4, 5, 6]

#     goal: "核心业务逻辑"

#     start_time: ""

# 跨项目联调相关（仅跨项目场景填写，非跨项目不含以下字段）

# cross_project:

#   enabled: true                  # 是否为跨项目场景

#   origin_project: ""             # A 项目（发现问题/发起修复的项目）

#   origin_workspace: ""           # A 项目工作区绝对路径

#   fix_project: ""                # B 项目（需要修复的项目）

#   fix_workspace: ""              # B 项目工作区绝对路径

#   dependency: ""                 # A 依赖 B 的包名和版本

#   status: "pending_fix"          # pending_fix | fixing | fixed_pending_validation | validated | failed

#   handoff_prompt: ""             # 生成的 B 项目衔接 prompt（存储在此，用户可直接复制）

#   validation_project: ""         # 验证项目（通常 = origin_project）

#   validation_workspace: ""       # 验证项目工作区路径

#   projects_detail:               # 跨项目明细（复盘报告「涉及项目」链路图数据源；步骤 7/9a 采集时逐项目回写）
#     - name: ""                   # 项目缩写（与工作区目录名一致，如 my-project）
#       workspace: ""              # 项目工作区绝对路径（可选，缺省从 source_project/fix_project 推断）
#       short: ""                  # 展示短名（报告节点显示，如 MySDK）
#       role: ""                   # main | source | fix | dep-bump | dependency | extra
#       role_label: ""             # 本次需求中的具体职责（如「SDK 底层 · 修复落点」）
#       branch: ""                 # 该项目需求分支（无改动留空）
#       files_changed: 0           # 该项目改动文件数（git diff merge-base..HEAD --stat）
#       lines_added: 0             # 该项目新增行数
#       lines_deleted: 0           # 该项目删除行数
#       mr: ""                     # MR 号（如 "!480"，无则留空）
#       mr_url: ""                 # MR 链接（报告渲染为可点击徽章）
#       mr_status: ""              # merged | created | pushed（已推送待创建 MR）
steps:                         # 各步骤状态（机器可读）
1: { status: pending }
2: { status: pending }
3: { status: pending }
4: { status: pending }
4.5: { status: pending }
5: { status: pending }
5.5: { status: pending }
6: { status: pending }
7: { status: pending }

# 完整执行额外步骤（标准执行不含）：

#  8: { status: pending }

#  9: { status: pending }

#  10: { status: pending }

# 步骤机器校验日志（v2 硬性门控 2026-04-30）

# 由 scripts/validate-output.sh 脚本在每步完成时自动写入辅助文件：

#   ~/.codebuddy/working-context/.active-flows/{flow-name}.step-{N}.validated.json

# 此 YAML 字段为人类可读的摘要版本，跨会话恢复时用于审计"哪些步骤通过了机器校验"
validation_log: []

# 条目格式示例（实际字段以 .validated.json 为准）：

#   - step: 4

#     validated_at: "2026-04-30T21:14:12"

#     validator_type: "ajv"          # ajv | jq-only

#     schema_version: "all-steps.schema.json@2026-04-30"

#   - step: 4.5

#     validated_at: "2026-04-30T21:20:05"

#     validator_type: "ajv"

# 技术方案文档状态（步骤 4 · 文档决策（环节 3/4） 硬性决策产生，迭代修复权威来源）
doc_platform_tech_proposal:
file_path: ""                   # 文档文件路径（本地模式：~/.codebuddy/tech-docs/{子类型}/{文件名}.md）
space_key: "~yourname"          # 文档空间 key（仅在线模式有效）
docid: ""                      # 文档 ID（在线模式唯一标识；本地模式为空，用 file_path）
url: ""                        # 完整 URL（在线为平台链接，本地为 file:// 路径）
locked_title: ""               # 锁定标题（创建/关联后立即记录，后续禁止自动变更）
parent_docid: ""               # 父文件夹 ID（仅在线模式有效；本地模式通过 file_path 的目录结构体现分类）
doc_type: "tech-proposal"      # tech-proposal | tech-sharing | release-doc
status: "not_started"          # not_started | synced | outdated | create_pending | update_pending | skipped | failed
last_synced_at: ""             # 最近一次保存/发布时间
last_compared_at: ""           # 最近一次文档对比时间（用于并发检测）
personnel_check:
passed: false
missing_roles: []

# action_history 是"前面步骤是否处理过文档"的权威证据链

# 每次文档创建/更新成功后必须追加

# 迭代修复场景 AI 必须读取此数组判断首轮决策（见 references/iteration-fix.md §决策继承规则）
action_history: []

# 条目格式示例：

# - action: "created"             # created | updated | relinked | skipped | imported_legacy | failed

#   at: "2026-04-30 20:30"

#   iteration: 1                  # 发生时所在迭代轮次

#   user_choice: "explicit_create" # explicit_create|explicit_update|explicit_relink|explicit_skip|auto_inherited

#   snapshot_sha: "a1b2c3"        # 保存/创建时 body 的 sha256 前 6 位（检测并发覆盖用）

#   title_at_that_time: ""        # 操作时的标题快照

#   note: ""                      # 可选，失败原因或其他备注

# 已有文档检查缓存（步骤 4 · 文档决策（环节 3/4） 决策前写入，生命周期至决策完成；本地模式检查本地目录）
doc_platform_space_probe:
probed_at: ""                  # 最近一次检查时间
probe_layer: ""                # from_local（本地记录） | matched（找到匹配） | no_match | failed
mcp_calls_made: 0              # 在线模式时作 MCP 调用数；本地模式始终为 0
query_used: ""                 # 使用的关键词
matched: false                 # 是否命中任何候选
candidates: []                 # top-3 候选列表

# 条目格式示例：

# - docid: "0"                # 在线模式用 docid 唯一标识

#   file_path: "~/.codebuddy/tech-docs/feat/20260801_title.md"  # 本地模式用文件路径

#   title: "【详情页面】功能重构"

#   url: "https://{doc_platform_url}/p/0"  # 在线模式链接（本地模式可为 file:// 路径）

#   parent_id: "0"

#   parent_folder: "技术方案/feat"

#   match_level: "strong"        # strong | medium | weak

#   last_modified: "2026-04-22"

# 轻量 CR（Change Request）追踪（drift-handling 自动创建，步骤 5.5 自动标记 done）

# 用途：让需求变更可追溯、可回顾，与 drift-handling 互补（drift 负责检测+处理，CR 负责记录+回顾）

# 触发：drift-handling 步骤 3 处理完漂移后自动创建条目

# 消费：gate-6-to-7 P1 检查 / gate-7-to-8 P0 检查 / 步骤 7 commit body 汇总 / 步骤 10 devlog
change_requests: []

# 条目格式示例：

#   - id: "CR-1"

#     description: "产品追加批量导入功能"

#     type: "scope"                # scope | code | ui

#     level: "major"               # minor | major | critical

#     detected_at: "step-5"       # 在哪个步骤检测到

#     detected_time: "2026-05-21T14:30:00+08:00"

#     status: "done"               # in_progress | done | cancelled

#     impact: "新增 2 个文件，修改 API 契约"

#     resolution: "更新 design.md + 新增 import-modal 组件"

# 需求关联产物索引（artifacts）——从工作上下文一步定位所有关联文件

# 设计意图：plan/devlog/knowledge/metrics/tech_proposal 等分散在多个目录，统一记录路径方便索引

# 创建时写入已知项（dir、plan、flow_lock、doc_platform），缺失项用 null 占位，各步骤/环节完成后回填
artifacts:
dir: ""                         # dev-logs 目录（步骤 4 创建时写入）
plan: ""                        # plan.md 路径（步骤 4 落盘时写入）
devlog: null                    # devlog.md 路径（步骤 7 H.2 后回填）
doc_platform:
file_path: ""                   # 文档本地文件路径
docid: ""                      # 文档 ID（在线模式）
url: ""                        # 文档链接（在线为 URL，本地为 file:// 路径）
flow_lock: ""                   # .flow 锁文件路径（阶段 0 创建时写入）
knowledge: []                   # 关联 knowledge 条目路径（步骤 7 H.3 后回填）
metrics: null                   # 度量报告 .yaml 路径（步骤 7 I / 步骤 9 后回填）
flow_report: null               # 复盘报告 .html 路径（步骤 7 I / 步骤 9 后回填）
---

# 工作上下文

> 更新：{YYYY-MM-DD HH:mm} | 步骤：{编号} | 模式：{完整/快速/收尾}

## 需求
- **任务平台**：{story/bug/task} | [{id}]({完整 任务平台 URL})
- **标题**：{需求标题}
- **摘要**：{2-3 句话}
- **分支**：`{开发分支名}`{基准非 master 时追加"（基于 `xxx`）"}
- **项目**：{项目路径}
- **参考**：{文档平台/Figma/PDF 等链接，一行一个}

<!-- 任务平台 字段格式示例：

- **任务平台**：story | [1000000000123456789](https://example.com/tracker/10000000/story/detail/1000000000123456789)
注意：必须包含完整的可点击 任务平台 URL，禁止只填写 ID 而省略链接。
-->

## 项目与分支汇总

<!-- 所有需求必填此表，记录涉及项目的角色、分支和状态。单项目需求只填 1 行。-->

| # | 项目仓库 | 角色 | 开发分支 | workspace 路径 | 改动文件数 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | {项目仓库名} | 主项目 | `{分支名}` | {绝对路径} | {N} | {状态} |

<!-- 字段说明：

- 角色：主项目 / 跨项目-修复方 / 跨项目-验证方 / 跨项目-依赖方
- 开发分支：实际编码分支名（未确定用 {待确认}，直接改 master 标注 master）
- workspace 路径：本机绝对路径（已知时填写，未知留空）
- 改动文件数：编码完成后回填
- 状态：⏸️ 待编码 / 🔄 编码中 / ✅ 编码完成 / ✅ 联调通过 / ⏸️ 等联调

写入时机：

- 阶段 0（需求理解）：创建表格，填写已知项目和角色
- 步骤 2（范围确认）：检测到跨项目时补充 B/C 项目行
- 步骤 4 §4.1（分支定稿）：回填主项目分支名
- 步骤 5（编码完成）：回填改动文件数、更新状态
- 步骤 6C（联调验证）：更新对应项目状态
-->

## 变更动机（可选，复杂需求建议填写）
- **为什么做**：{业务背景和动机，这个需求/修复要解决什么问题}
- **期望效果**：{完成后用户/业务能获得什么价值}
- **不做的后果**：{如果不做这个变更会怎样}

## 约束与决策
- [{HH:mm}] {用户约束或决策记录}

<!-- 决策失效标记规则（借鉴 MemPalace 知识图谱的 invalidate 机制）：
当决策被推翻/变更时，用删除线标记旧决策并关联新决策，确保 AI 跨会话恢复时不会误执行过时方案。
格式示例：

- [14:30] ~~使用 Clerk 做认证~~ → 已废弃，见 [16:00] 条目
- [16:00] 改用 Auth0 做认证（原因：Clerk 不支持 SSO）

用户纠正标记规则（供度量采集统计 user_corrections）：
当用户否定 AI 方案/指出理解错误/要求回退方案时，追加 🔧 [纠正] 标记：

- [2026-06-03 15:00] 🔧 不应使用 any 类型，改用 unknown + 类型守卫
日期格式：`YYYY-MM-DD HH:MM`（跨天需求必须带日期，当天可用 `HH:MM` 简写）
注意：用户在选项中做选择、补充新信息、调整优先级不计为纠正。
-->

## 计划
> 状态：{待确认/已锁定/执行中/已完成}

| # | 操作 | 目标文件 | 改动内容 |
| --- | --- | --- | --- |

不做什么：{边界声明}

## 范围
| 文件 | 操作 | 说明 |
| --- | --- | --- |

影响：上游 {xxx} → 下游 {xxx}

## 批次进度（仅分批执行时存在）

> 总计 {K} 批 | 已完成 {X} 批 | 当前 Batch {N} | 待执行 {Y} 批

| 批次 | 目标 | 计划步骤 | 状态 | Commit | 耗时 |
| --- | --- | --- | :---: | --- | --- |
| Batch 1 | {目标描述} | #{起始}~#{结束} | ✅ | `{hash}` | {时长} |
| Batch 2 | {目标描述} | #{起始}~#{结束} | 🔄 | — | — |
| Batch 3 | {目标描述} | #{起始}~#{结束} | ⏸️ | — | — |

### Batch N 交接信息（每批次完成后更新）
- **前置条件**：{前序批次完成情况和可用产出}
- **本批次范围**：计划步骤 #{起始}~#{结束}，涉及 {文件列表}（按 AI 行为规范「文件/代码位置引用」使用反引号包裹相对路径格式）
- **注意事项**：{从前序批次继承的约束或发现}

## 进度

### 当前状态
{一句话：当前步骤 + 下一步动作}

### 步骤清单

> 状态图例：✅ 已完成 | ⚠️ 部分完成/有瑕疵 | ❌ 跳过 | ⏸️ 待执行 | 🔄 执行中
> 根据实际模式选用对应步骤行（完整执行含阶段0+步骤1~10，标准执行含步骤1~7）

| 步骤 | 状态 | 完成时间 | 关键产出/备注 |
| --- | :---: | --- | --- |
| {步骤名} | {状态} | {MM-DD HH:mm} | {关键产出或问题说明} |

<!-- 完整执行步骤参考：
阶段0 需求理解 → 1 研究定位 → 2 确认范围 → 3 制定方案 → 4 方案汇报 → 4.5 环境检查 → 5 执行修改 → 5.5 编码后置钩子 → 6 质量验证（6A 自动化验证 + 6B 用户验收） → 7 清理+L2审查 → 8 L3审查 → 9 反思学习 → 10 归档交付
标准执行步骤参考：
1 研究定位 → 2 确认范围 → 3 制定方案 → 4 方案汇报 → 4.5 环境检查 → 5 执行修改 → 5.5 编码后置钩子 → 6 质量验证（6A 自动化验证 + 6B 用户验收） → 7 清理+Commit
-->

### 恢复指令（跨会话用，3 段式硬化 v3 schema）

> **设计意图**：与 `.flow` 文件中 `recovery` 字段语义一致，作为跨会话恢复的权威源；.flow 中是机器可读提取，此处是人类可读镜像，两者同步更新。

- **昨天/上次我们做了什么**（yesterday）：{1 句话总结，≤50 字，记录本需求上次推进产出的关键事实}
- **今天/下一步准备做什么**（next_action）：{1 句话描述下一个具体动作，需可执行}
- **待确认**（pending，有则填，无则整项删除）：
- {问题1，≤30 字}
- {问题2}
- **模式文件**：{完整/快速}模式，需加载 {对应文件名}
- **注意事项**（可选）：{需要补齐的步骤或已知瑕疵}

{迭代修复时用【第N轮】标签区分轮次，如：【第二轮】提测反馈修复中}

## 备注

### 参考实现

| 参考对象 | 位置 | 行号 |
| --- | --- | --- |
| {参考功能名}（{用途}） | {文件路径} | L{起始行}-L{结束行} |

### 数据结构

- `{参考变量名}`（{说明}）：`{ 字段1, 字段2, ... }`

### 组件行为

- `{组件名}` {行为描述}

### 关键调用

| 函数/接口 | 签名/路径 | 说明 |
| --- | --- | --- |
| `{函数名}` | `{参数签名或调用链}` | {用途} |
```
