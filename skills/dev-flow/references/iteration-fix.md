# 迭代修复机制

> 完整执行/标准执行走完全流程后，后续反馈问题进入「迭代修复」路径。本机制不引入新模式，而是在三模式入口增加一层前置逻辑。
> **场景判定下沉到脚本**：`scripts/precheck/iteration-fix-classify.sh` 输出 JSON，AI 解读后驱动后续流程。

---

## §一 触发条件 + 批次切换分流

### 触发前提（同时满足）

1. 工作上下文创建前匹配到同一需求的已有文件
2. 已有文件 YAML `status` ∈ `{completed, delivered, testing}`

### 批次切换优先分流

匹配到已有工作上下文后，先看 `batch_mode` + `status`：

- `batch_mode: true && status: batch_in_progress` → 走 §六 「批次切换路径」，**不进入迭代修复**
- 否则 → 继续走脚本判定

> ℹ️ 两条路径互斥：`batch_in_progress` 状态天然排除迭代修复触发条件。

### 显式命令触发（推荐）

用户输入 `dev:fix --iteration [描述]` 直接触发：

1. 调用 `iteration-fix-classify.sh --working-context {匹配的 .md} --feedback "{描述}" --explicit-trigger iteration`
2. 脚本输出 scenario=post-test/post-launch JSON 后，按既有 §三 差异处理流程执行
3. 跳过原有"status ∈ {completed, delivered, testing}"前提判定（用户已显式指定）
4. **确保 .flow 存在**：检查 `.active-flows/{name}.flow`
   - 存在 → 按 §六 规则刷新字段
   - 不存在 → 以同名创建，字段来源：工作上下文 YAML（brief / branch / task_id 等）+ 本轮判定 JSON（round_number）

> ⚠️ 若未匹配到任何工作上下文（脚本返回 `scenario: not-iteration`），AI 必须用 `ask_followup_question` 让用户确认：① 提供 任务平台 链接或需求关键词以匹配上下文 ② 改用 `dev-flow` 作为新需求开始 ③ 取消本次操作

---

## §二 场景判定脚本（程序化下沉）

### 调用方式

```bash
~/.codebuddy/skills/dev-flow/scripts/precheck/iteration-fix-classify.sh \
--working-context "{工作上下文 .md 绝对路径}" \
--feedback "{用户本轮反馈描述}" \
[--git-diff-files N] \
[--current-branch BR]

```

### 输出 JSON schema

```json
{
"scenario":           "post-test | post-launch | not-iteration | batch-switch",
"complexity":         "simple | medium | major | n/a",
"fast_track_enabled": true | false,
"recommended_mode":   "standard | full | n/a",
"round_number":       2,
"branch_advice":      "继续当前分支 | 建议切到 bugfix/...",
"estimated_files":    3,
"rationale":          "1 句话判定依据"
}

```

### AI 解读规则

- `scenario == "not-iteration"` → 按正常流程继续，不走迭代修复
- `scenario == "batch-switch"` → 跳到 §六
- `scenario == "post-test" | "post-launch"` → 按 §三 差异处理 + §四 简化规则继续
- `fast_track_enabled == true` → 启用 §三 「简单 bugfix 快车道」
- `branch_advice` 为提醒性质，**不**直接定稿分支名（最终由步骤 4 §4.1 输出）

> 💡 脚本判定基于 YAML `status` / `task_type` + 关键词 + 分支位置，三层信号优先级：任务平台 组合 > 反馈关键词 > 分支位置。AI 收到 JSON 后**禁止**自行重新判定场景，仅可在用户明确指示时切换。

### 用户确认（强制交互，两步）

输出脚本判定 + 评估报告后，必须分两步进行用户确认，**每步都使用 `ask_followup_question` 弹出交互式选项**（违反 = 违反「全局决策交互强制规则」）。

#### 步骤 A：反馈理解确认（新增，阻塞性）

AI 先输出「反馈理解」摘要，然后**必须**调用 `ask_followup_question`：

```markdown
### 🔍 反馈理解确认

**我理解的问题**：
{AI 用自己的话复述对反馈的理解，1~3 句话}

**初步判断**：
- 类型：{post-test / post-launch}
- 复杂度：{simple / medium / major}
- 可能涉及：{文件/模块范围，≤3 个}
- 推荐模式：{standard / full}

请确认以上理解是否正确：
```

| 选项 | 说明 |
| --- | --- |
| ✅ 理解正确 | 进入执行方案确认 |
| ✏️ 补充或纠正 | 告诉我理解有误或遗漏的部分 → 重新分析 |
| 🔄 这是新需求 | 反馈涉及的是新需求，不走迭代修复，转为标准 dev-flow |

**交互循环**：

- 用户选 ✏️ → 接收补充信息 → 重新输出理解摘要 → 再次弹确认
- 用户选 🔄 → 退出迭代修复，转为冷启动 `dev-flow`
- 用户选 ✅ → 进入步骤 B

#### 步骤 B：执行方案确认（原有，微调）

步骤 A 确认后，AI 根据纠正信息（如有）重新评估 `recommended_mode` 和影响范围，然后进入执行方案确认：

```markdown
### 📋 执行方案确认

（原有的 scenario + complexity + recommended_mode 评估）

请确认执行方案：
```

| 选项 | 说明 |
| --- | --- |
| ✅ 按建议执行 | 按 AI 建议的模式（含 fast_track）开始修复 |
| 🔄 切换模式 | 使用另一种模式（如 AI 建议 standard，用户改为 full） |
| ✏️ 调整范围 | 补充或修正影响范围后重新评估 |
| ❌ 取消 | 终止本次迭代修复 |

---

## §三 两种场景的差异处理

| 维度 | 提测后迭代修复（post-test） | 上线后 bugfix（post-launch） |
| --- | --- | --- |
| 分支策略 | 继续原开发分支 | 推荐新建 `bugfix/` 分支（步骤 4 §4.1 定稿） |
| 任务平台 关联 | 原 story 单 | 独立 bug 单（工作上下文/devlog 中记录关联） |
| Commit type | `fix`（关联原 story） | `fix`（关联 bug 单） |
| 知识沉淀 | 标准沉淀 | **强化沉淀**（`production_verified` 置信度） |
| 技术方案文档 | 迭代中不评估，由 closeout-flow §H.3+ 兜底 | 同左 |
| 度量维度 | 标准度量 | 追加 bugfix 专属（逃逸分析/根因分类） |
| devlog Round 标题 | `Round N：提测反馈修复` | `Round N：线上 Bug 修复 — {简述}` |
| plan.md | 按需追加变更记录 | 追加「线上 Bug 修复记录」段落 |

### 简单 bugfix 快车道（`fast_track_enabled=true` 时启用）

**触发**：`complexity=simple` + 用户表述代码已实施 + git diff 文件 ≤ 3。

| 环节 | 正常 | 快车道 |
| --- | --- | --- |
| 评估+模式选择 | 分两步 | 合并为一步确认（精简评估 + 默认选项） |
| 6B 用户验收 | 弹决策 | **跳过** |
| 6C 联调决策 | 弹决策 | **跳过**（不涉及新增接口时） |
| 7 A~E 清理检查 | 逐环节 | **合并为一步静默检查**（有问题才暂停） |
| 7 I 度量报告 | 完整 YAML | 精简为一行摘要 |

**快车道不精简**：H.1 Commit / H.2 Devlog / H.2+ Plan.md / H.3 知识沉淀 / H.3+ 文档平台（按统一收敛规则推迟到步骤 7 commit-archive 阶段）。

> 核心原则：**精简流程交互，不精简知识产出**。

### 跨需求 Bug 关联（仅 post-launch）

dev-flow 流程范围内自动处理：(1) 工作上下文 `## 需求` 追加 Bug 单信息；(2) devlog「相关文档」追加 Bug 单链接；(3) impact-index 追加 Bug 信息。

---

## §四 步骤简化规则

### 步骤 5.5 统一 L1 审查（每轮强制）

> 迭代修复是多轮快速循环，但质量检查不能跳过。小改动量下 L1 审查 30~45 秒，与轻量检查几乎一样，**统一每轮走 L1**，不分层。

每轮步骤 5 编码完成后，**汇报"改完了"前**必须执行：

1. **5.5a**：`use_skill('code-review')` 执行 L1 基础审查（含 ESLint 命令行 / 可选链 / 浏览器兼容性 / 异步竞态等 8 项）
2. **5.5b**：更新工作上下文 `## 进度`（迭代修复中仅更新进度，不同步 devlog/文档平台方案）
3. **5.5c**：`read_lints` 确认无新增错误
4. 🔴 问题当场修复 → 重审；🟡 建议项**自动跳过**（不弹交互，减少打断）；🟢 仅提示

> 迭代修复中 5.5 不输出完成标记 JSON、不弹推进选项——静默执行后直接汇报。commit/收尾前的最终 5.5 仍需输出完成标记并走门控。

**5.5 静默累计 ≥3 必弹 dev:sync 提醒（硬规则）**：

- 计数器 `silent_55_count` 由 `scripts/hooks/post-step.sh` 物理层兜底维护（见 `case 5.5|5_5` 分支），AI 仅消费不维护
- 静默路径判定：post-step.sh 收到 `STEP_ID=5.5` 但 `validate-output.sh` 未生成 `.step-5_5.validated.json` 时，自增 `.flow.silent_55_count`
- AI 在每次响应前必须读取 `.flow.silent_55_count`（用 `df_get_flow_field`）；**累计 ≥3** → 必须 `ask_followup_question` 弹出 `dev:sync` 提醒（场景 A），不得静默推进
- 重置时机：用户接受 dev:sync 完成同步 → 归零；流程进入步骤 7 H 环节 → 归零
- 完整规范 → `references/in-flow-sync.md` §1.2；权威条款 → `~/.codebuddy/rules/AI行为规范.mdc` §「主动文档同步弹框提醒」
- 🔴 dev:sync ≠ 5.5b 替代品：禁止以"反正 dev:sync 会兜底"为由偷工 5.5b

**防跳过 + blocked/paused 恢复强制清单**：从 `blocked-*` / `paused` 恢复后执行编码时，AI 易因"改动小/只是联调配合"跳过 5.5b。此场景必须按序：5.5a → 5.5b
（含 `## 范围`/`## 进度`/`## 迭代修复记录` 更新 + `.flow` 刷新）→ 5.5c。违反 = 与「步骤 5.5 不可跳过」红线同级。

### 标准 / 完整执行模式下的简化对照

| 步骤 | 简化策略 |
| --- | --- |
| 阶段 0 需求理解（仅完整模式） | 增量理解；本轮含需求变更/方案否定时**额外执行** `references/drift-handling.md` §步骤 3 重写「当前执行方案 v{N}」（信号：`## 范围` 增删 / `## 计划` 步骤增删 / `## 需求` 故事调整任一命中） |
| 步骤 1 研究定位 | 增量研究：仅研究反馈涉及的新区域；存在上轮调用链路图时输出**增量调用图**（`call-graph-spec.md` 格式 C） |
| 步骤 2 确认范围 | 增量范围：仅列本轮新增改动 |
| 步骤 3 制定方案 | 增量调整：在原方案上标注「保持不变 / 本轮新增/修改」 |
| 步骤 5.5 | 见上方「统一 L1 审查」 |
| 步骤 4 / 6 / 7 / 8~10 | 无变化 |

### Figma 设计稿处理

- 无新 Figma 输入 → 复用已有
- 有新 Figma 输入 → 按「Figma 设计稿处理流程（三模式通用）」两级策略重新处理，不因"已有信息"跳过

---

## §五 技术方案文档决策继承（硬性）

> 迭代修复期间**不再触发** 文档平台 同步评估；统一由 `closeout-flow.md §H.3+` / `step-8-10-full.md §10.3.5` 基于 `git diff master..HEAD` 三方对账兜底。

读 YAML `doc_platform_tech_proposal.action_history` 判断首轮决策：

| 规则 | 触发条件 | 行为 |
| --- | --- | --- |
| **1 自动继承（首轮 skip）** | `action_history` 全为 `skipped` / 为空 + `docid` 空 + `iteration ≥ 2` | 步骤 4 · 文档决策（环节 3/4） 自动跳过（**不弹 `ask_followup_question`**）；JSON `doc_platform_tech_proposal.action = "auto_inherited_skip"`；`action_history` 追加 `action: skipped, user_choice: auto_inherited`；进度提示「💡 本需求首轮已明确不处理 文档平台，本轮自动继承」 |
| **2 必弹决策（首轮已发布）** | `action_history` 含 `created/updated/relinked/imported_legacy` && `docid` 非空 | 步骤 4 · 文档决策（环节 3/4） **必须用 `ask_followup_question` 弹出**，默认项按场景：post-launch → 🔄 增量更新；post-test → ⏭️ 本轮不更新（交步骤 7 H.3+ 兜底） |
| **3 向后兼容（无字段）** | YAML 无 `doc_platform_tech_proposal` 字段 | 扫描 `## 需求 → 参考` 和 devlog 找文档链接 → 命中则读取文档并初始化，按规则 2；未命中走完整阶段 3 |

**用户逃生通道**：显式说"本轮生成 技术方案文档 / 帮我补个技术方案 / 更新 文档平台 / 同步技术方案"→ 强制触发完整阶段 3，跳过规则 1。

**同步预告**（仅提示，不驱动评估）：满足规则 2 时，评估报告附预告（信号：接口变更 / 方案章节变更 / 改动文件 ≥ 2 / 流程图判断节点变化）「📄 文档平台 同步预告：本轮改动涉及{信号}，预计收尾时生成偏离清单。如需提前同步：说"同步 文档平台"」。

---

## §六 .flow v3 字段写入规则（跨阶段）

> 迭代修复天然属于 `phase=iteration`。必须同步刷新 `.flow` v3 字段，否则下次新对话恢复时智能匹配会回退到 brief 子串匹配，无法识别"第 N 轮迭代"。

| 阶段 | `phase` | `status` | `recovery.yesterday` | `recovery.next_action` | 备注 |
| --- | --- | --- | --- | --- | --- |
| 进入迭代修复 | `iteration` | `active`（从 `completed/delivered/testing` 切回） | 简述上一轮交付 | "评估反馈复杂度后开始 Round {N+1}" | `match_keywords` **追加** `["第N轮", "迭代N", "iteration{N}"]`；`last_active` 刷新；`session_id` 同会话沿用 / 新会话恢复后刷新为新值 |
| 步骤完成钩子 | `iteration` | `active` | `Round {N} 已完成 {步骤}：{推进内容}` | `Round {N} 下一步：{动作}` | 按 `step-router.md §「步骤完成」§动作 2` 执行 .flow 同步；`recovery` 必须标注 `Round {N}` |
| 迭代修复完成 | `commit-archive`（无后续）/ `iteration`（待下一轮） | `completed` / `idle`（等下一轮）/ `paused`（用户暂停） | `Round {N} 已交付：{摘要}` | `等待下一轮反馈` 或 `流程结束` | — |

### 关键约束

- ❌ **禁止**为每一轮迭代新建 `.flow`（改名/改路径），全程复用同一个名称；**若 `.flow` 不存在则以同名重建**（字段来源：工作上下文 YAML + 本轮判定 JSON）
- ✅ 工作上下文 `.md` 的 `iteration_history` 才是轮次历史档案
- ✅ `.flow` 永远只反映"当下这一轮"

**旧 v2 兼容**：读到的 `.flow` 缺 `phase` / `recovery` / `match_keywords` 时，首次步骤完成钩子触发时一次性补齐；`match_keywords` 从 YAML `brief` + `task_id` 派生 ≥3 个；不阻塞主流程。

---

## §七 轮次管理 + devlog 增量

### YAML 头部轮次字段

```yaml
---
iteration: 2                    # 当前轮次（首次开发为 1，每次迭代修复 +1）
iteration_history:              # 历史轮次摘要（机器可读）
1: { mode: standard, status: completed, start_time: "...", end_time: "...", summary: "..." }
2: { mode: standard, status: in_progress, start_time: "...", summary: "..." }
---

```

### 轮次切换原子操作

进入迭代修复时按序：(1) 读 YAML 取 `iteration=N` → (2) 当前轮信息归档到 `iteration_history[N]`（status=completed）
→ (3) `iteration: N+1` → (4) 重置 `current_step: 1`、`status: in_progress`、清空 `steps`
→ (5) **保留**累积信息（`files_changed` / `branch` / `task_id` / `cross_project.projects_detail`，跨项目逐项目明细随迭代累积更新）。

### 工作上下文膨胀控制（`iteration ≥ 3` 自动精简）

| 轮次 | 保留策略 |
| --- | --- |
| 当前（N） | 完整保留所有区块 |
| 上一轮（N-1） | 保留「约束与决策」「范围」，「计划」精简为一句话摘要 |
| ≤ N-2 | 仅在 `iteration_history` 留 summary，正文区块全部移除 |

精简在**步骤 1 开始前**执行，确保研究阶段上下文窗口最大化。

### 工作上下文正文区块更新规则

迭代修复时正文用 **`### 第N轮`** 子标题区分：

- `## 约束与决策`：追加 `### 第N轮` 子标题
- `## 计划`：追加 `### 第N轮计划（迭代修复）`，原计划保留不动
- `## 范围`：追加本轮新增文件，已有文件不删
- `## 进度`：覆盖更新为本轮最新（YAML `steps` 字段同步重置）
- `## 备注`：追加本轮新增

> **轮次号唯一真相源**：YAML 头部 `iteration` 字段；正文 `### 第N轮` 仅作可读性，AI 解析必须读 YAML 头部。

### devlog Round 增量

| 场景 | Round 标题格式 |
| --- | --- |
| post-test | `### Round N：提测反馈修复（{日期}）` |
| post-launch | `### Round N：线上 Bug 修复 — {bug 简述}（{日期}）` |

post-launch Round 内容额外含：Bug 单号关联（任务平台 链接）/ 线上影响范围 / plan.md 同步追加「线上 Bug 修复记录」。
**Round 号必须等于 YAML `iteration`**。

---

## §八 批次切换路径（与迭代修复互斥）

仅在 `batch_mode: true && status: batch_in_progress` 时触发。

### 触发信号

「继续下一批」/「开始 Batch N」/「下一个批次」/「继续上次的需求」（匹配到 `batch_mode=true` 时）/ 新会话自动恢复（活跃 `.flow` + `batch_mode=true`）。

### 简化流程

```text
检测到批次切换信号
→ 读工作上下文 → 确认 batch_mode=true
→ current_batch = N+1
→ batches[N].status=completed、batches[N+1].status=in_progress
→ 提取 Batch N+1 计划步骤 → 输出批次交接信息
→ 直接进入步骤 4.5（环境检查）→ 步骤 5
→ 跳过步骤 1~3（计划已在首轮锁定）

```

### 批次切换 vs 迭代修复对比

| 维度 | 迭代修复 | 批次切换 |
| --- | --- | --- |
| status 前提 | `completed/delivered/testing` | `batch_in_progress` |
| iteration 递增 | ✅ | ❌（同一轮次内） |
| 步骤 1~3 | 增量执行 | ❌ 跳过（计划已锁定） |
| 步骤 4 | 重新评估+用户确认 | 仅确认当前批次范围 |
| devlog | Round N 增量 | Batch N 增量 |

### 交接信息模板

```markdown
📦 批次切换：Batch {N-1} → Batch {N}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Batch {N-1} 已完成：{目标摘要}
Commit: {commit_hash}

🔄 Batch {N} 开始：{目标摘要}
计划步骤：{步骤范围}
涉及文件：{文件列表}
前置条件：{从上一批次继承的约束或发现}

📦 总进度：[✅ Batch 1] ... [🔄 Batch N] ... [⏸️ Batch M]

```

> 「涉及文件」按 AI 行为规范用反引号包裹相对路径（`` `相对路径` `` L起-L止）。

---

## §九 运行时数据溯源排查规范

> **适用**：用户问"XX 数据从哪来 / 为什么没生效 / 显示了错误的值"等**答案依赖运行时状态**的问题。
> **核心原则**：禁止凭静态代码分析直接给结论，必须用调试手段物理验证。

**强制三步法**：(1) **穷举入口**——列出所有可能数据入口（HTTP / WebSocket / JSSDK / 缓存 / props），让用户确认无遗漏；
(2) **一次性全覆盖加调试日志**——所有入口同时加统一格式 `console.log`（如 `[DEBUG-{主题}] {入口名}: {字段}`），不逐个猜测；
(3) **用户验证后给结论**——根据控制台打印一步到位确认，清除日志。

**禁止**：只读代码就给确定性结论 / 逐个推测 → 失败 → 再推测（"猜测链"反模式）/ 等用户主动要求才加调试日志。

**历史教训**：2026-05-25 排查"用户昵称展示"数据来源时 AI 先后给出 3 个错误推测，每次失败才换下一个。实际来源是第 4 个入口，一开始穷举 + 同时加日志一轮即可确认。

---

## §十 相关文档

- 场景判定脚本 → `scripts/precheck/iteration-fix-classify.sh`
- 步骤 5.5 完整规范 → `steps/step-5.5-post-coding.md`
- 步骤 4 §4.1 分支定稿 → `steps/step-4-decision.md`
- 文档平台 收尾兜底对账 → `references/closeout-flow.md` §H.3+ / `steps/step-8-10-full.md` §10.3.5
- 调用图增量格式 C → `references/call-graph-spec.md`
- 漂移处理（方案重写）→ `references/drift-handling.md`
- 共享规则（分支命名约束）→ `references/shared-rules.md` §6
