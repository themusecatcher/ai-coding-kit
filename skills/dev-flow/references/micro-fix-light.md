# micro-fix 轻量保留版执行规范（v2）

> 本文件定义 micro-fix 模式下「轻量保留」的 5 个环节执行边界、成本上限与自动降级触发条件。
> 由 `step-7-commit.md` 在 `caller=micro-fix-7` 时按需引用，`mode-matrix.md` §三bis 引用本文件作为执行细则单一真相源。
> 设计哲学：从「极致裁剪」转向「零成本保留 + 极简版执行」——保留所有有价值的环节，但每个环节执行最小集；降级机制不变，确保超出阈值时回到完整流程。

---

## 一、轻量保留的 5 个环节总览

<!-- markdownlint-disable MD013 -->
| # | 环节 | 极简版动作 | 成本上限 | 触发自动降级条件 |
| --- | --- | --- | --- | --- |
| 1 | 5.5a L1 极简审查 | 仅扫改动行 + 红线 §5/6/7/9 共 4 项 | 1 次 use_skill | 发现 ≥3 个 🔴 / 需决策性思考的 🔴 |
| 2 | 7-A Diff 极简分析 | `git diff HEAD --stat` 统计 + 文件类型识别 | 1 次 bash | 改动 >3 文件 / >15 行（单文件）/ 不对称修改 / 涉及 lock 或配置文件 |
| 3 | 7-H.2 devlog 极简追加 | 当前 Round 末尾追加 1 行 | 1 次 read_file + 1 次 replace_in_file | — |
| 4 | 7-H.3 knowledge 漂移检测 | grep 反查 + 命中模块变更历史追加 | 0~1 次 use_skill | knowledge 描述与改动冲突 → 仅追加变更历史，不降级 |
| 5 | 7-J 经验快检（Q1+Q2） | 仅 Q1 用户纠正 + Q2 踩坑递增，跳 Q3 | 静默 ≤15 秒 | — |
<!-- markdownlint-enable MD013 -->

> 跳过的 2 个环节（仍保持当前 micro-fix 设计）：
>
> - **7-C 可选链 + 7-E TODO 检查**：L1 极简审查的红线 §7 已覆盖可选链；TODO 在字面修复中无意义
> - **7-I 数据驱动反思**：micro-fix 不采集 metrics，反思缺数据基础（强行反思反而是噪声）

## 二、5.5a L1 极简审查

> 在 micro-fix 模式下，5.5a 从 ❌ 跳过 → ⚡ 极简版执行。

### 2.1 执行边界

- **调用方式**：`use_skill('code-review')` 执行 **L1 基础审查**
  （code-review skill 仅有 L1/L2/L3 三个实际级别，本环节限定为 L1）
- **扫描范围**：本次 diff 的改动行（不扫全文件，不扫上下文 ±N 行）
- **检查清单裁剪**：只汇报「开发规范-红线」 §5/6/7/9 命中项，其他项静默跳过：
- §5 安全底线（SQL/HTML 拼接、硬编码密钥）
- §6 副作用清理（useEffect cleanup / 卸载后 setState）
- §7 边界条件 + 可选链 `?.`
- §9 错误处理（空 catch / Error Boundary）
- **其余 L1 项静默**：§1/2/3/4/8 不作为本环节的 🔴 拦截项（这些不是 1 行修改能引入的问题）

> 💡 **实现备注**：code-review skill 本身不提供 `mode=micro-fix-light` 入参，
> 本环节通过「调用 L1 + AI 在 prompt 中明示扫描范围与检查清单」实现轻量化。

### 2.2 严重度处理

| 严重度 | 处理 | 是否弹 ask_followup_question |
| --- | --- | --- |
| 🔴 必须修复 | 立即修复并重新 lint | 不弹（修复后静默推进） |
| 🟡 建议项 | 静默跳过 | 不弹（不打扰 micro-fix 节奏） |
| 🟢 提示 | 忽略 | 不弹 |

### 2.3 自动降级触发

满足任一即触发自动降级到 standard：

- 发现 ≥3 个 🔴
- 发现需要决策性思考的 🔴（如架构选择、业务语义重定义）

### 2.4 完成标记

- L1 通过 → 5.5 完成标记 `l1_review_result: "passed_micro_light"`
- L1 修复 N 个 🔴 → `l1_review_result: "fixed_N_issues_micro_light"`

## 三、7-A Diff 极简分析

> 在 micro-fix 模式下，7-A 从 ❌ 跳过 → ⚡ 极简版执行。

### 3.1 执行边界

```bash
git diff HEAD --stat   # 一条命令统计所有本地未提交改动（含 unstaged + staged），自动去重

```

> micro-fix 场景检查的是**当前未提交的本地改动**
> （非功能分支 vs 主干的全量差异）。
> 使用 `git diff HEAD --stat` 而非分开的
> `git diff --stat` + `git diff --cached --stat`，
> 避免同一文件同时存在 unstaged 和 staged 改动时的
> 行数重复计算和文件数歧义。

### 3.2 检测规则（按顺序检查，命中即处理）

<!-- markdownlint-disable MD013 -->
| 检测项 | 处理方式 |
| --- | --- |
| 改动文件数 > 1 | 🔴 自动降级到 standard |
| 改动行数 > 15 | 🔴 自动降级到 standard |
| 出现 lock 文件（`*.lock` / `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml`） | 🔴 必须 ask_followup_question 用户确认 |
| 出现 `package.json` / `tsconfig.json` / `.eslintrc*` / `vite.config.*` / `webpack.config.*` 等配置文件 | 🔴 必须 ask_followup_question 用户确认 |
| 出现非 user_provided_fix_location 中声明的文件 | 🔴 必须 ask_followup_question 用户确认 |
| 改动文件 = 1 且 ≤15 行且非保护文件 | ✅ 静默通过 |
<!-- markdownlint-enable MD013 -->

### 3.3 完成标记

- 通过 → 在步骤 7 完成标记 outputs 中追加 `diff_stat_checked: true`
- 触发降级 → 工作上下文 `mode_history` 追加降级记录

## 四、7-H.2 devlog 极简追加

> 在 micro-fix 模式下，7-H.2 从 ❌ 跳过 → ⚡ 极简版执行。
> 🔴 **不可跳过**：本环节在 H.1 commit 决策后执行，无论用户选择提交还是跳过提交，不可豁免。

### 4.1 执行规则（按优先级判定）

**优先级 1**：找到当前活跃需求的 devlog（`~/.codebuddy/dev-logs/{当前 dir_name}/devlog.md`）

- 在最后 Round 末尾追加 1 行：

```markdown

- [micro-fix] {YYYY-MM-DD HH:mm} {commit_hash[:8]} {一句话描述}（`{改动文件相对路径}` L{行号}）
```

**优先级 2**：无活跃需求 → 写入月度合集

- 路径：`~/.codebuddy/dev-logs/_micro-fixes/{YYYY-MM}.md`
- 文件不存在则创建（首次写入需填写 H1 标题 `# Micro-Fix 月度合集 - {YYYY-MM}`）
- 追加格式同上

### 4.2 禁止行为

- ❌ 禁止主动新建独立 devlog 文件（避免 dev-logs 目录碎片化）
- ❌ 禁止在 micro-fix 月度合集外引入新的章节结构（仅追加单行）
- ❌ 禁止追加超过 1 行的内容（详细描述放到 commit message 中）

### 4.3 完成标记

- 在步骤 7 完成标记 outputs 中：`devlog_appended: "round_appended" | "monthly_appended"`
- ⚠️ 注意：micro-fix 的 `devlog_generated` 字段保持 `false`
  （语义=未生成独立 devlog 文件），
  通过新字段 `devlog_appended` 区分「追加到现有/月度合集」

## 五、7-H.3 knowledge 漂移检测

> 在 micro-fix 模式下，7-H.3 从 ❌ 跳过 → ⚡ 极简版执行。
> 这是本轮改造**最关键**的环节，目标是防止 micro-fix 的局部修复污染 knowledge 全局认知。
> 🔴 **不可跳过**：本环节在 H.1 commit 决策后执行，无论用户选择提交还是跳过提交，不可豁免。

### 5.1 执行流程（两步法，零命中即零成本）

#### Step 1：grep 反查

```bash

# 对每个改动文件执行
grep -rl "{改动文件相对路径}" ~/.codebuddy/knowledge/{project}/ 2>/dev/null || true

```

- 0 命中 → 静默退出（成本 0）
- 有命中 → 进入 Step 2

#### Step 2：调用 knowledge-loop skill（检索模式）进行漂移检测

- 调用：`use_skill('knowledge-loop')`，明示「检索模式」并请求运行漂移检测
  （`references/confidence.md` §「代码漂移检测」内置能力，
  根据 `stability.last_verified` / `drift_count` 字段判定）
- 输入：命中的 knowledge 模块路径列表 + 本次改动 diff
- 检测内容：改动是否与 knowledge 描述冲突（字段名/接口签名/常量值/枚举项）

> 💡 **实现备注**：knowledge-loop skill 不提供独立的 `mode=drift-check`，
> 本环节复用 skill 现有「检索模式」中的代码漂移检测能力 +
> 轻量调用「沉淀模式」仅追加变更历史（不走完整沉淀流程）。

### 5.2 漂移处理规则

<!-- markdownlint-disable MD013 -->
| 检测结果 | 处理方式 |
| --- | --- |
| 无冲突 | 仅在命中模块的 `_overview.md` 末尾「变更历史」追加一行：`- {YYYY-MM-DD} [micro-fix] {commit_hash[:8]} {改动摘要}` |
| 有冲突（字段/接口/常量被改动） | 追加变更历史 + 调用 knowledge-loop 「检索模式」递增 `stability.drift_count` + 追加冲突标注：`- {YYYY-MM-DD} [micro-fix] {commit_hash[:8]} {改动摘要}：{字段/接口} 已更新` |
| knowledge 模块过期需要重写 | ⚠️ 仅追加 `⚠️ 本节描述可能与 commit {hash} 后的实际代码不一致，建议下次开发前刷新` 提醒，不在 micro-fix 内重写正文（重写需走 standard 沉淀模式） |
<!-- markdownlint-enable MD013 -->

### 5.3 禁止行为

- ❌ 禁止创建新 knowledge 模块（创建模块属于 standard 范畴）
- ❌ 禁止改写 `_overview.md` 正文（仅追加「变更历史」章节）
- ❌ 禁止跨模块批量更新（micro-fix 改动应为局部）

### 5.4 完成标记

- 0 命中 → `knowledge_drift_checked: "no_hits"`
- 有命中无冲突 → `knowledge_drift_checked: "appended_history"`
- 有冲突 → `knowledge_drift_checked: "drift_recorded"`
- ⚠️ 注意：`knowledge_updated` 字段保持 `false`
  （语义=未沉淀新知识），
  通过新字段 `knowledge_drift_checked` 区分漂移检测结果

## 六、7-J 经验快检（仅 Q1+Q2 简版）

> 在 micro-fix 模式下，7-J 从 ❌ 跳过 → ⚡ 简版执行（仅 Q1+Q2，跳 Q3）。
> 设计依据：micro-fix 改 1 行没纠正没踩坑没新发现时，Q1+Q2 是纯静默退出，零成本；但纠正与踩坑识别能跨任务沉淀 Pattern。

### 6.1 执行时机

环节 H.3 knowledge 漂移检测之后、输出步骤 7 完成标记 JSON 之前。

### 6.2 3 问简版（≤15 秒，静默执行，不输出给用户）

**Q1：本次 micro-fix 中是否有用户纠正？**

- 判定：用户在阶段 0~7 任一节点说了「不对」/「改错了」/「不是这个文件」/「行号错了」
- 命中 → 写入 `~/.codebuddy/.learnings/LEARNINGS.md`（标注 `Source: micro-fix-correction`）
- 未命中 → 跳过

**Q2：本次是否触发了 LEARNINGS 已记录的坑？**

- 判定：grep 改动内容是否匹配 LEARNINGS 中已 active 的 `Pattern-Key`
- 命中 → 递增对应条目的 `Recurrence-Count`，更新 `Last-Seen`
- `Recurrence-Count >= 3 && Status != promoted` → 完成标记追加 `experience_alert: {pattern_key}`
- 未命中 → 跳过

**Q3 跳过**：micro-fix 字面修复几乎不会产出新可复用模式，跳过避免噪声。

### 6.3 完成标记字段（沿用现有 schema）

```json
"experience_check": "clean | recorded_N | alert_pattern_key"

```

- `clean`：Q1 Q2 全否，零开销退出
- `recorded_N`：新增/更新了 N 条 learnings
- `alert_pattern_key`：某条目 Recurrence-Count >= 3，需关注提升为规则

## 七、三道防线（确保「轻量」不变「裸奔」）

> 5 个轻量环节都受这三道防线约束，AI 不得自行扩展或缩减执行边界。

### 防线 1：硬白名单（执行边界写死）

- L1 极简版仅检查红线 §5/6/7/9 共 4 项；禁止 AI 自行扩展到其他红线
- 7-A Diff 极简分析的检测项写死在本文件 §3.2 表格内
- 7-J 经验快检仅 Q1+Q2，禁止补做 Q3

### 防线 2：自动降级触发器

任一极简环节发现「需要更深入处理」→ 立即降级到 standard：

| 环节 | 触发降级条件 |
| --- | --- |
| 5.5a L1 | ≥3 个 🔴 / 需决策性思考的 🔴 |
| 7-A Diff | >3 文件 / >15 行（单文件）/ 不对称修改 / 涉及 lock/配置文件未确认 |
| 7-H.3 knowledge | 仅记录漂移，不降级（漂移处理本身就是 micro-fix 的目标场景） |

### 防线 3：完成标记 schema 校验

步骤 7 完成标记必须包含以下 micro-fix 专属字段（值不能为 `null`，缺字段视为未完成）：

- `diff_stat_checked: true`（来自 7-A）
- `devlog_appended: "round_appended" | "monthly_appended"`（来自 7-H.2）
- `knowledge_drift_checked: "no_hits" | "appended_history" | "drift_recorded"`
  （来自 7-H.3）
- `experience_check: "clean" | "recorded_N" | "alert_pattern_key"`（来自 7-J）

> 校验由 `references/gate-validator.md` §「step-id 对照表」中的 `7-micro-fix` 行执行。

## 八、向后兼容

- 旧 micro-fix 完成标记中 `experience_check` 为 `false`/省略 → 视为 `"clean"`
- 旧 micro-fix 完成标记中 `devlog_generated`/`knowledge_updated` 为 `false` → 不报错（保持原语义）
- 新流程从 v2 落地后的第一次 micro-fix 开始生效，不回溯历史

## 九、与其他 reference 的关系

- `mode-matrix.md` §三bis：声明 micro-fix 触发条件 + 步骤裁剪表（**指向本文件**作为执行细则单一真相源）
- `steps/step-7-commit.md`：环节 A/B/H.2/H.3/J 在 `caller=micro-fix-7` 时引用本文件
- `steps/step-router.md`：micro-fix 路由表 + 物理检查点白名单
- `references/gate-validator.md`：micro-fix 完成标记的 schema 校验规则
- `references/output-schemas.md`：步骤 7 micro-fix 完成标记 JSON 模板

## 维护规则

修改本文件时，必须同步更新：

1. `references/mode-matrix.md` §三bis 步骤裁剪表（保持环节状态一致）
2. `steps/step-7-commit.md` micro-fix 章节（保持环节状态一致）
3. `references/output-schemas.md` 步骤 7 schema（保持字段一致）
4. `references/gate-validator.md` `7-micro-fix` 校验项（保持字段校验一致）
5. `references/_index.md` 加载索引（如新增信号字段）
