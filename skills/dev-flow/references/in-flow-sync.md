# 文档同步入口（`dev:sync`）

> 本文件定义 `dev:sync` / `dev:s2` 命令的全量文档同步流程，支持**流程内模式**（`.flow` 存在）和**独立模式**（工作上下文匹配）。
> 复用 `closeout-flow.md §H.0~H.3+` 的现有环节（caller=in-flow-sync），零新增同步逻辑。

## 零、设计哲学（必读）

> ⚠️ **dev:sync 是补救机制，不是 5.5b 的替代品**。详细规则见 `~/.codebuddy/rules/AI行为规范.mdc` §「主动文档同步弹框提醒」。
> 简单记：**5.5b 是日常必做**（freshness-lint 物理硬阻断），**dev:sync 是累计静默 ≥3 次后的兜底**。禁止以"dev:sync 会兜底"为由跳过 5.5b。

## 一、触发条件

### 1.1 用户主动召唤

| 输入 | 行为 |
| --- | --- |
| `dev:sync` / `dev:s2` | 标准触发 |
| "同步文档" / "全量同步" / "检查文档" / "更新文档" | 关键词触发 |

> 高级修饰符 `--docs={list}` 暂不在 MVP 范围，详见附录·未来增强。

### 1.2 AI 主动弹框（必须使用 `ask_followup_question`）

> 🔴 **强制规则**：以下 2 个场景必须主动弹框提醒用户，不得静默推进。

| 触发场景 | 触发条件 | 默认推荐项 |
| --- | --- | --- |
| **场景 A：5.5 静默累计 ≥3 次** | step-5 内部多轮修复 + 迭代修复 5.5 静默执行**累计** ≥3 次（统一计数器，post-step.sh 物理层兜底维护） | ✅ 立即同步 |
| **场景 B：完整模式跨步骤真空期 追加改动** | `caller=full-7` 完成后到步骤 10 之间，步骤 8/9/10 入口 git diff 快照对比发现新增改动 | ✅ 立即同步 |

> ℹ️ 原 v1「每轮迭代修复完成必弹」已删除——迭代修复每轮结束本身会走完整步骤 7（含 H 全套），属于伪盲区。
> ℹ️ 步骤 10 入口仍触发——这是事前同步的最后机会，10.3.5 H.3+ 是事后兜底而非替代。

**统一静默计数器规则（物理层兜底）**：

- 计数器位置：`.flow` 文件 `silent_55_count` 字段（无则视为 0）
- 自增执行者：**`scripts/hooks/post-step.sh`**——AI 层为辅，物理层为主
- 自增判定：post-step.sh 收到 `STEP_ID=5.5` 时，若 `validate-output.sh` 未生成 `.step-5_5.validated.json`
  （说明走的是 iteration-fix §四 / step-5-execute §2.5 静默路径），则 silent_55_count += 1
- 重置时机：① 用户接受 dev:sync 提醒并完成同步 → 归零；② 流程进入步骤 7 H 环节 → 归零；③ 用户点"❌ 永久跳过本流程" → 不归零但不再弹

**弹框模板**（参照 `step-router.md` §「交互式决策强制规则」）：

```text
【dev:sync 提醒】检测到 {触发场景描述}，建议同步以下文档：

📄 技术方案文档 — 兜底对账（{docid} 存在）
📝 工作上下文 — 一致性校验
📋 devlog — 增量追加 Sync-{N} 段
📊 plan.md — 增量追加（CR 非空即触发检查）
📂 artifacts — 路径完整性校验（遍历所有非 null 路径确认文件存在）
🧠 knowledge — 漂移检测

是否立即同步？

```

| 选项 | 说明 |
| --- | --- |
| ✅ 立即同步全部文档 | 执行 `dev:sync` 完整流程 |
| ✏️ 选择性同步 | 用户逐条勾选要同步的文档 |
| ⏭️ 跳过本次，由步骤 7/10 兜底 | 标记已提醒，计数器不归零（下次到 3 仍弹） |
| ❌ 永久跳过本流程 | 工作上下文 YAML 头部写入 `sync_reminder_disabled: true`（仅对当前工作上下文 YAML 生效；迭代修复 N+1 / 批次切换 batch_next 仍属同需求继续生效；新需求自动重置） |

## 二、工具门禁声明

> `caller=in-flow-sync` 期间**复用 `gates.yaml tool_gates.phases.step_5_plus`** 的全工具集，无需新增 phase 配置。
> 实证依据：`gates.yaml` L559~L563
> `step_5_plus: allowed=[read_only, write_code, execute, interact, mcp_read, mcp_write], blocked=[]`，
> 恰好覆盖 dev:sync 所需的 git/read/write/MCP 全部能力。

## 三、执行流程

### 4.1 标准执行（用户输入 `dev:sync`）

````text

1. 读取 .flow 文件 → 取 current_step 暂存到 sync_from_step 字段
├─ .flow 存在 → 继续（流程内模式）
└─ .flow 不存在 → 扫描 working-context 匹配（项目路径+分支名）
     ├─ 匹配到 → 继续（独立模式，跳过暂存/恢复 .flow 操作）
     └─ 未匹配到 → 终止："未找到关联工作上下文，请先创建"

2. 检查 工作上下文 YAML 头部 sync_reminder_disabled:
- true → 仅在用户主动输入 dev:sync 时执行；AI 主动场景 A/B 静默跳过
- false/缺省 → 正常执行

3. 写 .flow 暂存状态（仅 .flow 存在时执行）：
- status: paused_for_sync
- sync_from_step: {原步骤号}
- sync_started_at: {ISO 8601}
- sync_base_sha: $(git rev-parse HEAD)   ← 用于后续增量去重

### 4.0 文档就绪检查

就绪检查（仅依赖文件存在性，不依赖流程状态）：

| 文档 | 检查方式 | 不存在时的处理 |
|------|---------|--------------|
| 工作上下文 | Phase 0 已保证存在 | （不会到这里） |
| 文档平台 | `docid` 或 `file_path` 非空 + 文档可读取 | ⏸️ 跳过，原因："未关联 技术方案文档" |
| devlog | `artifacts.devlog` 路径文件存在 | ⏸️ 跳过，原因："尚未生成（预期步骤 7 创建）" |
| plan.md | `artifacts.plan` 路径文件存在 | ⏸️ 跳过，原因："尚未生成（预期步骤 4 创建）" |
| report.yaml | `artifacts.dir` + `report.yaml` 存在 | ⏸️ 跳过，原因："度量采集尚未执行（预期步骤 7/9）" |

**规则**：
- 未就绪文档标记 `⏸️ 未就绪` + 原因，不报错，不中断
- 已就绪文档正常进入 Phase 2 同步管道
- 就绪检查结果汇总到 Phase 4 报告

4. 加载 closeout-flow.md，以 caller=in-flow-sync 身份执行：

> 🔴 **强制规则 #S1**：步骤 4 的第一个 tool call 必须是 `read_file("references/closeout-flow.md")`。
> AI 必须加载该文件后才能执行 H.3 knowledge 漂移检测和 I 度量采集，
> 禁止凭记忆手动拼装步骤。违反此规则视为 dev:sync 未完成。

✅ H.0 CR 同步与登记
（复用 drift-handling §步骤 3.5 的 CR 创建逻辑：扫描 git diff，
对未登记的改动自动创建 CR-N，状态 in_progress；
对已存在 in_progress 的 CR 检测命中即标记 done + 填 resolution）
✅ H.2 devlog 增量追加（按 sync 触发场景写入"#### Sync-{N}：{触发场景} - {时间}"小节）
✅ H.3 knowledge 漂移检测（grep 反查 + 命中模块变更历史追加）

> 🔴 **强制规则 #S2**：H.3 执行前必须先 `grep -rl "<核心符号>" ~/.codebuddy/knowledge/` 反查命中条目，
> 然后逐条读取、逐条比对、逐条增量更新。禁止跳过 grep 反查直接凭记忆追加。

✅ H.3+ 文档平台 兜底对账（docid 非空时执行三方对账）
✅ plan.md 增量追加（CR 非空即触发检查，与 文档平台 对账逻辑一致；CR 不影响计划内容时输出 unchanged）
✅ artifacts 路径完整性校验（遍历 artifacts 中所有非 null 路径，确认文件存在；
失效路径标注 ⚠️ 并提示手动修复或自动更新）  ← 本环节是预防"猜目录名找不到文件"的物理防线
✅ 工作上下文一致性校验（validate-working-context.sh）

❌ 跳过 H.1 commit（仍由步骤 7 生成）
❌ 跳过 G L2/L3 审查（重审太重）
❌ 跳过 J 经验快检
❌ 跳过 K dev-logs 完整性自检
理由：dev-logs 完整性必须等 commit 完成后才有意义，
dev:sync 不生成 commit（commit 由步骤 7 H.1 生成），故 K 环节无运行前提

🔄 步骤 4a：I 度量采集（按流程状态分情况处理）

| 条件 | 行为 | 理由 |
|------|:---:|------|
| `.flow` 存在 + `current_step` 非 `done/completed` | ❌ 跳过 | 后续步骤 7/9 会执行完整度量采集 |
| `.flow` 不存在 + 工作上下文 `status: completed/done/testing/delivered` | ✅ 必须执行 | 流程已结束，不会再触发步骤 7/9，度量数据需由本轮 sync 更新 |
| `.flow` 不存在 + `report.yaml` 存在 + 代码有增量变更 | ✅ 增量刷新 | report.yaml 已存在但数据过时（如 complete_date / corrections / changes 字段），仅刷新变更字段，不重建全量 |
| `.flow` 存在但其他条件不明确 | ❌ 跳出决策，不得擅自决定，提示用户确认 |
| `report.yaml` 不存在 | ⏸️ 跳过 | 度量从未生成，通常因流程未走到步骤 7，标记待关注 |

**增量刷新执行清单**（仅刷新变更字段，不重建全量）：
1. 读取现有 `report.yaml`
2. 更新 `complete_date` 为当前日期
3. 用 `git diff master --stat` 刷新 `changes` 字段（files_changed / insertions / deletions）
4. 更新 `iterations.total` 和 `corrections`（从工作上下文 CR 列表统计）
5. 更新 `knowledge.pitfalls_recorded`（`grep -c "^## " knowledge条目.md`）
6. 写入 `report.yaml`（保持文件尾部空行）

> 📌 `report.yaml` 的完整 schema 与标准化采集流程（步骤 7-I 详细清单）→ `closeout-flow.md` §环节 I

5. 弹出最终用户决策（强制 ask_followup_question）：
| 选项 | 说明 |
| --- | --- |
| ✅ 全部应用变更 | AI 通过 MCP 直接更新 文档平台 + 写入所有文档 |
| ✏️ 逐项确认 | 用户逐条决定哪些变更应用 |
| ⏭️ 仅生成报告 | AI 输出对账报告，用户手动同步 |
| 🔁 取消同步 | 不应用任何变更，恢复原步骤 |

### Phase 3：🔐 物理写入校验

> 复用 `scripts/lints/doc-sync-lint.sh`（micro-fix-doc-sync-lint.sh 重构版）。
> 物理事实校验，不依赖 AI 的完成声明。

执行：`bash ~/.codebuddy/skills/dev-flow/scripts/lints/doc-sync-lint.sh <flow-name> --mode sync`

**校验项**（7 项，缺一即 🔴 阻断）：

| # | 校验项 | 检查方式 | 覆盖环节 |
|:---:|---|------|:---:|
| 1 | devlog.md 写入 | 文件存在 + mtime 为今天 | H.2 |
| 2 | plan.md CR 同步 | done 的 CR ID 是否出现在 plan.md 中 | plan.md |
| 3 | CR 登记完整性 | in_progress CR 数 ≤ plan.md 中 CR 行数 | H.0 |
| 4 | knowledge 漂移 | 相关 knowledge 文件 mtime 为今天 | H.3 |
| 5 | 文档平台 同步 | 工作上下文 `last_synced_at` 为今天 | H.3+ |
| 6 | artifacts 路径 | 所有非 null 路径（plan/devlog/report.yaml）存在 | artifacts |
| 7 | 度量采集 | report.yaml `complete_date` 为今天（仅流程已完成时） | I |

失败 → 🔴 阻断，回退到 Phase 2 补执行遗漏项。

### Phase 4：输出同步报告

> 每次 dev:sync 执行完毕后必须输出此报告，禁止省略。

```markdown
## 📋 文档同步报告

> 执行时间：{ISO 8601} | 模式：{流程内 / 独立} | 来源：{from-drift / standalone / ai-reminder}

### 同步结果

| 文档 | 状态 | 说明 |
|------|:---:|------|
| 📄 工作上下文 | {✅/⏸️} | {具体变更摘要，或跳过原因} |
| 🌐 技术方案文档 | {✅/⏸️} | {章节变更摘要，或跳过原因} |
| 📝 devlog | {✅/⏸️} | {追加段落摘要，或跳过原因} |
| 📊 plan.md | {✅/⏸️} | {增量变更，或跳过原因} |
| 📈 report.yaml | {✅/⏸️} | {计数器变更，或跳过原因} |
| 🧠 knowledge | {✅/⏸️} | {漂移检测结果，或跳过原因} |
| 📂 artifacts | {✅/⚠️} | {路径校验结果} |

### 🔐 门控校验

| 检查项 | 结果 |
|--------|:---:|
| devlog.md 已写入 | {✅/🔴} |
| plan.md CR 已同步 | {✅/🔴} |
| CR 已登记 | {✅/🔴} |

### 未就绪文档（如有）

| 文档 | 跳过原因 |
|------|---------|
| {文档} | {原因} |
```

6. 恢复 .flow（仅 .flow 存在时执行）：
- current_step: {原步骤号}（从 sync_from_step 还原）
- status: active
- 写 last_sync_diff_sha: $(git rev-parse HEAD)   ← 供下次增量对比 / 场景 B 检测
- silent_55_count: 0                              ← 重置计数器
- 删除 sync_from_step、sync_started_at、sync_base_sha 字段

7. 更新 sync_history（仅 .flow 存在时写入；独立模式下仅输出到报告）：
- sync_history 追加条目（3 字段精简）：
- at: {ISO 8601}
from_step: {原步骤号}
choice: {apply_all | partial | report_only | cancelled}
注：sync_history 写入工作上下文 YAML 头部（与 iteration_history / change_requests 同级），
不写 .flow（.flow 只承载"当下一轮"临时态）。

8. 输出回归提示：
"✅ 文档同步完成，已回到步骤 {原步骤号}，继续原任务"

````

## 四、结构化完成标记（必须输出）

```json
{
"command": "dev:sync",
"caller": "in-flow-sync",
"status": "completed",
"outputs": {
"sync_trigger": "user_active | ai_reminder_silent_55 | ai_reminder_full_void",
"sync_from_step": "5.5",
"sync_resumed_to_step": "5.5",
"docs_synced": {
"cr_registered": 2,
"devlog_appended": "sync_N_section",
"knowledge_drift_checked": "no_hits | appended_history",
"doc_platform_sync_result": "synced | skipped_no_changes | skipped_user_opt_out | skipped_no_docid",
"plan_md_updated": "true | unchanged（CR 不影响计划内容）",
"artifacts_paths_validated": true,
"working_context_validated": true
},
"user_choice": "apply_all | partial_apply | report_only | cancelled",
"silent_55_count_reset": true,
"last_sync_diff_sha": "{git rev-parse HEAD 后}",
"duration_seconds": 45
},
"next_step": "{原步骤号}（恢复后）"
}

```

**完成标记校验规则**：

- `sync_from_step` 必须有值（证明确实是流程内召唤）
- `sync_resumed_to_step` 必须等于 `sync_from_step`（证明恢复成功）
- `docs_synced` 至少包含 1 个非空字段
- `user_choice` 不能为空
- `last_sync_diff_sha` 必须等于完成时刻的 `git rev-parse HEAD`
- `artifacts_paths_validated` 必须为 `true`（确认所有非 null 路径均已 `[ -f ]` / `[ -d ]` 核验）

## 五、与活跃流程恢复的关系

跨会话恢复时若发现 `.flow.status == paused_for_sync`：

```text
新对话首响：
"⚠️ 检测到上次会话在步骤 {sync_from_step} 召唤了 dev:sync 但未完成。

- 已同步：{docs_synced 摘要}
- 是否继续同步剩余文档？"

| 选项 | 说明 |
| --- | --- |
| ▶️ 继续未完成的同步 | 加载未完成的子环节继续 |
| 🔁 重新开始 dev:sync | 重置 sync 状态从头开始 |
| ⏭️ 取消同步，回原步骤 | 恢复 current_step={sync_from_step} 继续原任务 |
```

## 六、边界情况

| 场景 | 处理 |
| --- | --- |
| `.flow` 不存在 | 扫描 working-context 匹配项目路径+分支名；匹配到则进入独立模式，未匹配到则终止 |
| git diff（相对 sync_base_sha）为空 | 输出"无代码改动，文档已最新，跳过同步" |
| 工作上下文缺失 | 中止，提示用户先恢复工作上下文 |
| 文档平台 docid 为空 | 文档平台 子环节跳过，其他文档照常同步 |
| 同步中用户撤销 | 完整回滚到 `sync_from_step` 状态，不留半成品 |
| 同一会话连续 dev:sync | 第 2 次以 `last_sync_diff_sha` 为起点仅同步增量 |
| `sync_reminder_disabled: true` | 用户主动 `dev:sync` 仍执行；AI 场景 A/B 静默跳过 |
| 迭代修复 N+1 / 批次切换 batch_next | 仍属同需求，`sync_reminder_disabled` 持续生效 |

## 七、相关文档

- 收尾子流程定义 → `references/closeout-flow.md`
- 文档同步规则 → `references/doc-sync-rules.md`
- 需求漂移处理 + CR 自动登记 → `references/drift-handling.md` §三 + §3.5
- 工具门禁权威源 → `config/gates.yaml` §`tool_gates.phases.step_5_plus`
- 工作上下文 freshness 物理守护 → `scripts/lints/working-context-freshness-lint.sh`
- silent_55_count 物理层维护 → `scripts/hooks/post-step.sh`
- AI 主动弹框规则 + dev:sync ≠ 5.5b 替代品 → `~/.codebuddy/rules/AI行为规范.mdc` §「主动文档同步弹框提醒」
