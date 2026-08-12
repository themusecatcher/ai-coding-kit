# 步骤路由器（L0 核心）

> ⛔ **Prompt Chaining 强制规则**：本文件是 dev-flow 开发流程的唯一步骤路由入口。每个步骤必须按顺序执行，
> 每次只加载一个步骤的详细规范，完成后输出结构化完成标记，通过门控后才能加载下一步。
> 🆕 **程序化执行入口（强烈推荐，2026-05-29 hooks 状态已升级为 implemented）**：避免凭记忆做门控判断，优先用脚本：
| > | 时机 | 推荐脚本 | 替代旧路径 |
| > |------|---------|----------|
| > | 加载下一步骤前 | `scripts/hooks/pre-step.sh <flow-name> <target-step>` | AI 手动 ls .validated |
| > | 步骤完成后 | `scripts/hooks/post-step.sh <step-id> <json-file> <flow-name>` | 直接调 validate-output.sh |
| > | 查询下一步 | `scripts/state-machine.sh --query-next --current=N --mode=M` | 凭记忆查表 |
| > | 步骤 7 子类型 | `scripts/state-machine.sh --query-step7-variant --mode=M` | 凭记忆判断 |
| > | 物理检查点白名单 | `scripts/precheck/physical-checkpoint.sh <flow-name> <target>` | AI 手动 ls |
| > | 编码前置硬卡点 | `scripts/precheck/step5-precheck.sh <flow-name>` | 文字规则记忆 |
> ✅ **使用新入口的优势**：自动跑物理检查点 + Schema 校验 + 关键 lint 三合一，减少 AI 工具调用次数。
> ⚠️ **旧入口（直接调 validate-output.sh）保留向后兼容**，但新流程一律走 `hooks/`。
> Hook 注册表：`config/gates.yaml § hooks`（2026-05-29 status: implemented）；门控规则：`config/gates.yaml`

## 流程总览

| 步骤 | 名称 | 加载文件 | 必须输出 | 门控条件 |
| --- | --- | --- | --- | --- |
| 0 | 需求理解 | `use_skill("requirement-intake")` | 需求确认+分支告知收集（仅 user_specified）+完成标记 JSON | 用户确认 + JSON 完整（分支推荐唯一定稿在步骤 4 §4.1） |
| 1 | 研究与定位 | `steps/step-1-research.md` | 相关文件表格 + 完成标记 JSON | JSON 完整 |
| 2 | 确认范围 | `steps/step-2-scope.md` | 影响范围报告 + 用户确认 + 完成标记 JSON | 用户确认 + JSON 完整 |
| 3 | 制定方案 | `steps/step-3-plan.md` | 执行计划表格 + 完成标记 JSON | JSON 完整 |
| 4 | 方案汇报与用户决策 | `steps/step-4-decision.md` | 评估卡片+执行深度选择+分支名最终推荐（§4.1）+完成标记 JSON | 用户明确决策 + JSON 完整 |
| 4.5 | 环境检查 | `steps/step-4.5-env-check.md` | 环境状态 + 完成标记 JSON | JSON 完整 |
| 5 | 执行修改 | `steps/step-5-execute.md` | 代码改动 + 完成标记 JSON | JSON 完整 |
| 5.5 | 编码后置钩子 | `steps/step-5.5-post-coding.md` | L1审查+文档同步+自检 + 完成标记 JSON | JSON 完整 |
| 6 | 质量验证 | `steps/step-6-verify.md` | 验证报告 + 完成标记 JSON | 全部通过 + JSON 完整 |
| 7 | 清理+Commit | `steps/step-7-commit.md` | L2审查+commit message + 完成标记 JSON | 用户确认 + JSON 完整 |
| 8 | L3 代码审查（仅完整执行） | `steps/step-8-10-full.md` | L3多视角审查报告 + 完成标记 JSON | 审查通过 + JSON 完整 |
| 9 | 反思与学习（仅完整执行） | `steps/step-8-10-full.md` | 度量报告+经验提炼 + 完成标记 JSON | JSON 完整 |
| 10 | 归档与交付（仅完整执行） | `steps/step-8-10-full.md` | commit+devlog+knowledge+交付报告 + 完成标记 JSON | 完成性校验全通过 + JSON 完整 |

## micro-fix 模式专项路由（轻量保留版 v2）

> 当 `mode: micro-fix` 时，使用以下路由，跳过步骤 1~4、轻量执行 5.5a/7-A/7-H.2/7-H.3/7-J。5 个轻量保留环节的执行规范详见 `references/micro-fix-light.md`。

| 步骤 | 名称 | 加载文件 | 必须输出 | 门控条件 |
| --- | --- | --- | --- | --- |
| 0 | 极简需求确认（≤3 行：文件+行号+改动内容） | `steps/step-1-research.md` 不加载，仅在对话内极简确认 | 用户确认 + 阶段 0 完成标记 JSON（含 `mode: micro-fix` 评估） | 用户显式确认 |
| 4.5 | 主干分支兜底检测 | `steps/step-4.5-env-check.md`（仅 §1 主干分支检测部分） | 完成标记 JSON | 非主干分支 或 用户显式同意 |
| 5 | 执行修改 | `steps/step-5-execute.md` | 代码改动 + 完成标记 JSON | JSON 完整 |
| 5.5a | **L1 极简审查**（v2 新增）：仅扫改动行 + 红线 §5/6/7/9 | `steps/step-5.5-post-coding.md`（仅环节 a）+ `references/micro-fix-light.md` §二 | `l1_review_result` 有枚举值 + 完成标记 JSON | 发现 ≥3 个 🔴 → 自动降级 standard |
| 6 | 最小验证（read_lints + 视觉确认） | `steps/step-6-verify.md`（仅 6A 自动化验证最小集） | 完成标记 JSON | read_lints 通过 |
| 7 | commit + 轻量保留环节（H.1+H.2+H.3+J） | `steps/step-7-commit.md`（轻量版 caller=micro-fix-7）+ `references/micro-fix-light.md` §四/五/六 | commit message + 完成标记 JSON（含 `diff_stat_checked`/`devlog_appended`/`knowledge_drift_checked`/`experience_check`） | 用户确认 + JSON 完整 |

**执行约束**：

- 跳过的步骤（1/2/3/4/5.5b 文档同步/8-10）**禁止补做**——若发现需要补做，必须自动降级到 standard 模式重走流程
- 物理检查点机制**仍然适用**（每步 `.validated` 文件必须由 `validate-output.sh` 创建，micro-fix 的白名单详见 `references/gate-validator.md` §「物理检查点白名单」）
- 完整 micro-fix 触发条件、步骤裁剪详情、安全兜底、自动降级机制 → `references/mode-matrix.md` §三bis
- 5 个轻量保留环节的执行边界、成本上限、三道防线 → `references/micro-fix-light.md`

## `dev:sync` 流程内同步路由

> 当用户输入 `dev:sync` / `dev:s2` 或 AI 检测到主动弹框场景 A/B 时，使用以下路由，**不**操作流程生命周期，仅同步文档子集。
> 完整流程定义 → `references/in-flow-sync.md`。

| 路由 | 触发 | 加载文件 | 说明 |
| --- | --- | --- | --- |
| 流程内同步 | `dev:sync` / `dev:s2` / 关键词「同步文档/全量同步/检查文档/更新文档」 | `references/in-flow-sync.md` → `references/closeout-flow.md` | 以 `caller=in-flow-sync` 执行 H.0+H.2+H.3+H.3+ 文档同步子集 |
| AI 主动弹框（场景 A） | `.flow.silent_55_count ≥ 3` | 同上 | 必须 `ask_followup_question` 弹框；用户接受后走相同路由 |
| AI 主动弹框（场景 B） | `caller=full-7` 完成 + 步骤 8/9/10 入口 git diff vs `last_sync_diff_sha` 非空 | 同上 | 必须 `ask_followup_question` 弹框；用户接受后走相同路由 |

**执行约束**：

- 🔴 必须前置检查 `.flow` 文件存在（不存在 → 提示用户先使用 `dev-flow` 进入流程）
- 🔴 禁止生成 commit / 跑 L2-L3 / 度量采集 / K 环节（这些仍由步骤 7 / 步骤 9 承担）
- ✅ 必须暂存 `current_step` 到 `sync_from_step`，完成后恢复
- ✅ 必须写 `last_sync_diff_sha` 与重置 `silent_55_count`
- ✅ 完成标记 `next_step: "{原步骤号}"`（不是 `done`）
- 🔴 工具门禁：复用 `gates.yaml tool_gates.phases.step_5_plus`（无需新增 phase）

## 步骤执行协议（每个步骤必须严格遵循）

### 交互模式判断（每个步骤开始前检查）

读取工作上下文 YAML 头部的 `interaction_mode` 字段，按 `references/interaction-mode.md` 的风险分级决定交互方式：

- **精简模式**（`streamlined`）：🟢 流程决策点静默完成，🟡 质量决策点智能默认，🔴 关键决策点仍暂停
- **标准模式**（`standard` / 未设置）：所有交互点正常暂停
- 运行中检测到用户说"少问我"/"你决定就好" → 更新 `interaction_mode: streamlined`
- 运行中检测到用户说"每步都问我"/"我要确认" → 更新 `interaction_mode: standard`

### 口语意图消歧规则（处理用户口语化指令时强制执行）

<!-- 防御「精简一下」等口语涉及多维度（mode / interaction_mode / execution_depth）AI 凭推测改错维度。核心原则：宁可多问一次，不可凭推测。 -->

#### 直接命中映射表（命中即静默执行 + 简短反馈）

| 用户口语 | 维度 | 写入字段 / 行为 |
| --- | --- | --- |
| `--fast` / `少问我` / `你决定就好` / `别老问我` | 修饰层 | `interaction_mode: streamlined` |
| `每步都问我` / `我要确认` / `多问我` | 修饰层 | `interaction_mode: standard` |
| `--micro` / `改个错别字` / `这里少个分号` / `把 X 改成 Y` / `{文件}:{行号}` | 基础模式 | 评估是否切到 `mode: micro-fix`（需满足触发条件） |
| `走完整流程` / `要 devlog/反思/归档` / `做正式一点` | 步骤 4 决策 | `execute_full`（步骤 5→10） |
| `走标准流程` / `commit 完就行` / `不需要归档` | 步骤 4 决策 | `execute_standard`（步骤 5→7） |
| `分批做` / `分批执行` / `一批一批来` | 步骤 4 决策 | `execute_batched`（需满足规模阈值） |
| `走极简` / `快捷执行` / `改一行就行` / `轻量流程` | 步骤 4 决策 | `execute_micro`（仅编码+极简审查+ESLint，跳过大审查和 devlog） |
| `提测反馈` / `继续上次需求` + 已有 working-context | 基础模式 | 进入 `iteration-fix` |

#### 模糊口语（必须弹 `ask_followup_question` 让用户选）

| 模糊口语 | 候选维度 |
| --- | --- |
| "精简一下" / "简单点" / "快一点" | ① 修饰层 streamlined ② mode=micro-fix（若满足条件）③ execution_depth=standard |
| "详细一些" / "深入一点" | ① 撤回 streamlined ② execution_depth=full |
| "重头来" / "回到上一步" | ① 步骤回退（rollback）② 换方案（步骤 4 选 `change_plan`）③ 取消重开 |

#### 反绕过规则

- ❌ 不直接命中映射表 → 禁止凭推测"语义解码"，必须弹 `ask_followup_question`
- ❌ 禁止把 streamlined 与 micro-fix 等同（前者修饰层、后者基础模式）
- ❌ 修改工作上下文 YAML 头部前必须先确认维度

### 步骤开始

```text

1. read_file("steps/step-{N}-{name}.md") 加载当前步骤的详细规范
2. 仅按该文件中的指令执行，禁止提前执行后续步骤的内容
3. 禁止在未加载步骤文件的情况下执行该步骤

```

### ⛔ 反加速硬规则（不可绕过，优先级高于一切简化判断）

<!-- 防御 2026-04-21 事故：AI 跳过步骤 6 文件加载、省略步骤 7 的 closeout-flow.md 加载，导致未调用 smart-commit、commit 格式错误。借鉴 ACP「执行路径中无 LLM 判断」+ GSD「程序化 Gate」思想。 -->

1. **单步骤原子性**：每个步骤必须独立执行，禁止在一个回合内连续完成多个步骤。具体：

- 每个步骤必须以 `read_file("steps/step-N-xxx.md")` 开始
- 每个步骤必须以结构化完成标记 JSON 结束
- 两个步骤之间的 JSON 输出不可合并
- ❌ 禁止在输出步骤 N 的 JSON 后，在同一回合内直接输出步骤 N+1 的 JSON

1. **JSON-before-load 强制顺序**：
步骤 N 的完成标记 JSON 必须在 `read_file("steps/step-{N+1}")` **之前**出现在
对话历史中。若 AI 在未输出步骤 N 的 JSON 的情况下调用了 read_file 加载步骤 N+1
的文件，这是红牌行为 #1。

2. **步骤 5.5→6→7 不可合并**：
这三个步骤涉及 L1 审查→质量验证→L2 审查+commit/devlog/knowledge，每个步骤都有独立的质量保障职责。
禁止以"改动简单"为由将它们合并执行。每个步骤必须：

- 独立加载步骤文件（`read_file`）
- 独立输出完成标记 JSON
- 独立更新工作上下文

1. **步骤 7 完整加载强制**：
步骤 7 的执行入口是 `read_file("references/closeout-flow.md")`（非 step-7-commit.md
的部分内容），必须完整读取后按环节 A→J（标准执行）执行。
❌ 禁止只读 step-7-commit.md 的前 N 行就开始执行

2. **commit 生成必须走 smart-commit**：
禁止 AI 自行拼写 commit message。必须调用 `use_skill('smart-commit')`，
该 skill 负责读取用户的 commit 格式规范。
❌ 禁止 AI 凭自身知识直接输出 commit message

### 🔐 物理检查点机制（程序化 Gate，AI 无法绕过文件系统事实）

<!-- 解决「门控执行者 = 被监督者」的根本矛盾，借鉴 ACP「执行路径中无 LLM」+ AgentSpec「Trigger→Predicate→Enforcement」。
v2 升级（2026-04-30）：物理检查点从 .done 升级为 .validated，只能由 validate-output.sh
创建（Schema 机器校验通过 + 物理标记原子绑定，AI 无法 touch 伪装）。 -->

**机制说明**：

每个步骤完成后，必须调用 `scripts/validate-output.sh` 脚本。脚本的"校验通过 + 自动 touch 物理检查点"是原子操作：

```text
~/.codebuddy/working-context/.active-flows/{flow-name}.step-{N}.validated
~/.codebuddy/working-context/.active-flows/{flow-name}.step-{N}.validated.json  ← 审计元信息

```

**📌 文件名编码规则（重要）**：

> `{N}` 中的 `.` 在文件名里会被脚本替换为 `_`（避免 `.` 在 bash glob 中被误解析）。

| 步骤号 | 文档中的 `{N}` 写法 | 实际生成的文件名 |
| --- | --- | --- |
| 1 / 2 / 3 / 4 / 5 / 6 / 7 / 8 / 9 / 10 | `step-5` | `.step-5.validated`（整数，无变化） |
| **4.5** | `step-4.5`（文档记述） | **`.step-4_5.validated`**（实际存储） |
| **5.5** | `step-5.5`（文档记述） | **`.step-5_5.validated`**（实际存储） |

- **AI 执行 `ls` 校验时**：必须使用 `step-4_5.validated`（下划线形式），否则找不到文件会误触红牌 #14
- **脚本输出提示**：`validate-output.sh` 的 stderr 会直接打印实际文件名，以脚本输出为准
- **glob 通配安全**：清理命令 `rm -f {name}.step-*.validated*` 对两种形式均有效

**写入规则**（⚠️ 硬性规则，违反即红牌 #14）：

1. **只能由脚本创建**：`.validated` 文件**只能**由 `validate-output.sh` 通过 `<flow-name>` 参数触发创建

- ❌ AI 不得自行 `touch {name}.step-{N}.validated`（绕过校验）
- ❌ AI 不得通过 `execute_command` 手动创建此文件

1. **调用方式**（每个步骤完成标记 JSON 输出后立即执行）：

```bash

# 1. 将完成标记 JSON 写入临时文件
cat > /tmp/dev-flow-step-{N}-output.json <<'EOF'
{ ...完成标记 JSON... }
EOF

# 2. 调用校验脚本（第三参数 flow-name 是触发物理检查点的关键）
bash ~/.codebuddy/skills/dev-flow/scripts/validate-output.sh \
{step-id} /tmp/dev-flow-step-{N}-output.json {flow-name}
```

1. **返回码语义**：

- 0 → 校验通过 + .validated 已创建 → 可加载下一步骤
- 1 → JSON 格式错误 → 补齐 JSON 后重试
- 2 → Schema 校验失败 → **.validated 不会被创建**，按 gate-validator.md 修正 outputs 后重试
- 3 → ajv-cli 缺失，降级到 jq-only（仍会写 .validated，但标注 `validator_type: jq-only`）

**校验规则**（下一步骤加载前）：

- 步骤 N+1 加载步骤文件**之前**，必须执行：

```bash
ls ~/.codebuddy/working-context/.active-flows/{flow-name}.step-{N}.validated
```

- 文件不存在 → 🔴 **红牌 #14**，回退到步骤 N 重新执行完成钩子 + 调用 validate-output.sh
- 此校验为**程序化 Gate**：`ls` 的结果是确定性的，AI 无法"说服自己跳过"

**适用范围**（v2 扩展至所有关键步骤）：

- 步骤 4 → 4.5 → 5 → 5.5 → 6 → 7 之间**强制执行**物理检查点（门控硬化）
- 步骤 0 → 1 → 2 → 3 → 4 之间**强制执行**（研究分析链路）
- 完整执行步骤 7 → 8 → 9 → 10 之间**强制执行**
- 流程结束时（步骤 7/10 完成），清理所有 `.validated` / `.validated.json` / `.done` 文件：

```bash
rm -f ~/.codebuddy/working-context/.active-flows/{name}.step-*.validated*
rm -f ~/.codebuddy/working-context/.active-flows/{name}.step-*.done
```

**🔀 按基础模式分流的预检白名单**（v2.1 硬化 2026-05-10，micro-fix 等精简模式必读）：

> 不同基础模式跳过的步骤集不同，强制执行物理检查点的范围必须按 `mode` 分流，否则会因不存在的前置 `.validated` 文件而**误触红牌 #14**。

加载下一步骤前的 `ls` 预检逻辑必须先读取工作上下文 `mode` 字段，再按下表确定**需要存在**的检查点：

| 基础模式 | 加载步骤 N+1 前必须存在的 .validated | 例外（不需要存在） |
| --- | --- | --- |
| `standard` | `step-1` `step-2` `step-3` `step-4` `step-4_5` `step-5` `step-5_5` `step-6` `step-7` | — |
| `full` | `standard` 全部 + `step-8` `step-9`（加载 step-10 前） | — |
| `full`（柔性升级） | `step-7` 必须存在；后续 `step-8/9/10` 按完整执行新增 | step-1~step-6 在升级前已通过 standard 校验 |
| `batch` | 首批同 standard；后续批次的 `step-4_5~step-7` | 跨批次的 `step-1~step-3` 不重复检查 |
| `iteration-fix` | `step-4_5` `step-5` `step-5_5` `step-6` `step-7` | `step-1~step-4`（迭代修复跳过研究/范围/方案/决策） |
| **`micro-fix`** | **`step-4_5` `step-5` `step-5_5` `step-6` `step-7`** | **`step-1` `step-2` `step-3` `step-4` `step-8/9/10`** |
| `cross-project` | 同 `standard`（A 项目侧） | B 项目侧不在 dev-flow 主链路 |

**预检算法**：

```text

1. 读取工作上下文 YAML 头部，取 mode 字段（含 mode_history 历史轨迹）
2. 按上表查到该 mode 的「必须存在」清单
3. 对每个需要存在的 .validated，执行 ls 检查
4. 任一缺失 → 🔴 红牌 #14
5. 不在清单内的 .validated（如 micro-fix 下的 step-1.validated）→ 缺失视为正常，不报错

```

> ⚠️ **AI 不得自行扩展或缩减白名单**：白名单由本表锁定。即使任务"看起来简单"，也禁止以"少检查一项"为由放宽预检。
> ⚠️ **mode 切换时白名单立即切换**：micro-fix 自动降级到 standard 后，**新 mode 白名单**生效；原本不需要的 `step-1/2/3/4.validated` 必须在重新走 standard 流程时按顺序补做。

**完整白名单详细规则**：参见 `references/gate-validator.md` §「物理检查点白名单（按基础模式分流，硬性规则）」。

**向后兼容**：

- 旧的 `.step-{N}.done` 文件（v1 机制）**继续支持**，但**不再推荐创建**
- 新流程统一使用 `.step-{N}.validated`
- 校验逻辑：`.validated` 存在 → 通过；`.validated` 不存在但 `.done` 存在 → 🟡 告警但不阻塞（兼容过渡）

**完整示例**（步骤 5 完成 → 步骤 5.5 加载）：

```bash

# 步骤 5 完成钩子：

# 1. AI 输出完成标记 JSON 到对话

# 2. 将 JSON 写入临时文件
cat > /tmp/dev-flow-step-5-output.json <<'EOF'
{ "step": 5, "name": "执行修改", "status": "completed", ... }
EOF

# 3. 调用脚本（第三参数是 flow-name，触发物理检查点）
bash ~/.codebuddy/skills/dev-flow/scripts/validate-output.sh 5 \
/tmp/dev-flow-step-5-output.json 20260430_feat_xxx

# 期望输出：

#   ✅ [ajv] Schema 校验通过: step=5

#   🔐 物理检查点已写入: .../.active-flows/20260430_feat_xxx.step-5.validated

# 步骤 5.5 加载前校验：
ls ~/.codebuddy/working-context/.active-flows/20260430_feat_xxx.step-5.validated

# → 存在：通过，继续 read_file("steps/step-5.5-post-coding.md")

# → 不存在：🔴 红牌 #14，回退到步骤 5 重新调用脚本

```

### 🔒 编码前置硬卡点（步骤 5 加载前强制校验，不可跳过）

<!-- 防御 AI 以「任务简单」为由跳过步骤 1~4 直接编码。这是唯一一个在步骤开始前（而非完成后）执行的硬性校验。 -->
> 📌 **单一权威源**：4 项校验（含 micro-fix 专项分流）**已下沉到脚本** `scripts/precheck/step5-precheck.sh`。本节仅保留「调用约定」和「关键规则」。

### 调用约定

```bash

# 准备 read_file("steps/step-5-execute.md") 之前必须执行：
bash ~/.codebuddy/skills/dev-flow/scripts/precheck/step5-precheck.sh <flow-name>

# → 自动读取 .flow 中的 mode，按 standard/micro-fix 分流执行 4 项校验

# → 返回 0 通过；返回 1 红牌（禁止加载 step-5）

```

**校验项概览**（详见脚本，禁止在本节重复维护）：

| # | 标准模式校验项 | micro-fix 模式校验项 |
| --- | --- | --- |
| 1 | 工作上下文文件存在 | 同左 |
| 2 | `.flow` 锁文件 current_step ≥ 4.5 | 阶段 0 极简确认 (intake_confirmed=true) |
| 3 | 步骤 4 user_decision 非空 | 4.5 主干分支检测通过 (branch_safe=true) |
| 4 | 步骤 2/4 ask_followup_question 交互记录 | 未命中降级条件 |

### 关键规则

- ⚠️ **此卡点不受精简交互模式影响**——精简模式只影响交互频率，不影响流程完整性
- ❌ **禁止以"任务简单/方案明确/节省时间"等理由绕过**
- ❌ **禁止滥用 micro-fix 标签**：实际改动命中降级条件（>15行/≥2文件/主干分支）必须立即降级到 standard
- 详见 `references/mode-matrix.md` §三bis 的降级条件清单

> 完整规则细节见脚本，禁止在本文件重复维护。

### 交互式决策强制规则

**核心原则**：凡步骤规范中标注了 `ask_followup_question` 或「弹出交互式选项」的决策点，**必须调用 `ask_followup_question` 工具**，禁止用纯文本/Markdown 表格列出选项让用户手动输入。

**需要使用交互式选项的决策点清单**：

| 步骤/阶段 | 决策点 | 所在文件 |
| --- | --- | --- |
| 启动 | 热启动超时处理（继续/放弃/查看） | `flow.md` §热启动超时处理 |
| 启动 | 多活跃流程选择（恢复哪个/开新/取消） | `flow.md` §多活跃流程处理 |
| 1 | 知识确认（理解是否正确） | `step-1-research.md` |
| 2 | 范围确认（用户确认影响范围） | `step-2-scope.md` |
| 2 | 跨项目检测触发（复制衔接 prompt 等） | `cross-project/trigger.md` §触发后行为 |
| 4 | 执行深度选择（环节 2） | `step-4-decision.md` §2 环节 2 |
| 4 | 技术方案文档决策（环节 3，硬性必走） | `step-4-decision.md` §3 环节 3 |
| 4 | 修改循环后的再次确认 | `step-4-decision.md` §4 修改循环 |
| 4.5 | 环境检查确认 | `step-4.5-env-check.md` |
| 5 | 计划无法执行时的用户决策 | `step-5-execute.md` |
| 5.5 | L1 审查 🟡 建议修复项决策 | `step-5.5-post-coding.md` |
| 6A | 3 次失败熔断决策 | `step-6-verify.md` |
| 6B | 用户验收触发决策 + 验收结果决策 | `user-acceptance.md` |
| 6C | 联调方式决策 | `step-6-verify.md` |
| 6C | 跨项目联调方式决策 | `cross-project/integration.md` §step-6C 扩展 |
| 7-A | 预期外变更处理决策 | `closeout-flow.md` |
| 7-B | 调试代码清理决策 | `closeout-flow.md` |
| 7-G | L2 审查 🟡 建议修复项决策 | `closeout-flow.md` |
| 7-H | Commit Message 版本选择 | `shared-rules.md` |
| 7-H.3 | 知识沉淀确认 | `closeout-flow.md`（调用 `use_skill('knowledge-loop')` 沉淀模式） |
| 7-H.3+ | 技术方案文档兜底对账（`doc_platform_tech_proposal.docid` 非空即触发，基于 git diff master..HEAD + 工作上下文 + 文档平台 原文三方对账；完整模式下推迟到步骤 10.3.5） | `closeout-flow.md` §H.3+ / `step-8-10-full.md` §10.3.5 |
| 10.3.5 | 技术方案文档归档同步（完整执行必走，action ≠ skip 时；含 `doc-platform-doc-lint` 物理事实兜底，详见 `gates.yaml`） | `step-8-10-full.md` §10.3.5 |
| 4（技术方案） | 技术方案文档预览确认（新建） | `tech-proposal-flow.md` |
| 4（技术方案） | 技术方案文档更新方式选择（已有） | `tech-proposal-flow.md` |
| 迭代修复 | 迭代修复评估确认 | `iteration-fix.md` |
| 跨项目 | B 项目 profile 预检（onboard/跳过） | `cross-project/handoff.md` §profile 预检 |
| 跨项目 | 跨项目验证衔接（复制/先提交） | `cross-project/integration.md` §step-6C 扩展 |
| 各步骤 | 步骤流转推进选项（A 继续 / B 暂停 / C 回退） | `step-router.md` §步骤流转交互规则（下方） |

**执行要求**：

- ✅ 标准模式下，以上所有决策点必须使用 `ask_followup_question`
- ✅ 精简模式下，🟢 流程决策点可静默处理，🟡/🔴 仍必须使用 `ask_followup_question`
- ✅ **双重展示**：每个决策点必须**先用文本列出所有选项及说明**，再紧接着调用 `ask_followup_question` 弹出交互式选项。文本列表确保用户选完后回看对话仍能看到完整选项，交互式选项确保操作便捷
- ❌ 禁止只用 `ask_followup_question` 而不展示文本选项列表（选完后无法回看）
- ❌ 禁止只用文本选项列表而不调用 `ask_followup_question`（操作不便捷）
- ❌ 禁止跳过决策点直接替用户做选择

### 推荐项标识传递规范（2026-07-29 新增）

> `ask_followup_question` 工具的 option 对象仅有 `label`/`description` 两字段，无原生"推荐"标记能力。
> 为补全此语义缺失，**文本表格中有 `⭐` 标识的推荐项，必须在 `ask_followup_question` 对应 option 的 `label` 中同样传递**。

**强制标准**：

| 传递位置 | 格式 | 示例 |
|---------|------|------|
| 文本表格 | `⭐ {说明}` | `⭐ 改动小/低风险时默认` |
| `ask_followup_question` options label | `⭐ [推荐] {原 emoji} {选项名}` | `⭐ [推荐] ✅ 标准执行` |

**权威源**：推荐项判定统一来源于各步骤文档定义的推荐字段（如 `outputs.assessment.recommended_depth`），AI 不得自行主观判定。

**门控校验**：`scripts/lints/interactive-options-lint.sh` C8 规则校验文本表格 ⭐ 与 options label ⭐ 必须共存，违规视为红牌 #13。

> 📌 本规范与 `~/.codebuddy/rules/AI行为规范.mdc` §「推荐项一致性」配套构成完整的推荐项传递体系：
> 全局规则定义传递互斥检查原则，本章节定义各决策点的具体格式标准。

### 步骤流转交互规则（每个步骤完成后强制执行）

<!-- 每个步骤完成后，用户应通过可点击的交互式选项确认推进，而非手动输入文字回复。 -->

**规则**：每个步骤输出完成标记 JSON 并完成状态同步后，**必须调用 `ask_followup_question`** 弹出推进选项，让用户一键确认继续。

**标准选项模板**（根据步骤上下文可微调措辞）：

```text
选项 A：继续进入步骤 {N+1}（{步骤名称}）
选项 B：暂停，我有补充/疑问
选项 C：回退到步骤 {N} 重新执行

```

**精简模式豁免**：当 `interaction_mode: streamlined` 时，以下步骤流转可静默自动推进（不弹出选项）：

- 步骤 0.5 → 1（画像注入后自动进入研究）
- 步骤 4.5 → 5（环境检查通过后自动进入编码）
- 步骤 5 → 5.5（编码完成后自动进入后置钩子）
- 步骤 5.5 → 6（后置钩子完成后自动进入验证）

> 📌 **步骤 4.5 特殊补充**（2026-05-06 方案 B 落地）：除「精简模式豁免 4.5→5」这条原有规则外，**标准模式**下 4.5 的推进选项行为由 `steps/step-4.5-env-check.md` §「步骤推进选项」的**交互矩阵**决定：
>
> - 🟢 正常场景（分支一致且非主干）→ 标准模式下**仅**弹出一次推进选项（§2 跳过异常确认弹窗），精简模式下一行摘要静默推进
> - 🟡/🔴/⚠️ 异常场景（漂移/主干/字段缺失）→ 两种模式都必须在 §2 弹出异常处理弹窗（🔴 主干下不允许「跳过检查」选项）
> - 这样「大多数情况环境已就绪」时可避免重复确认弹窗，同时守住「不在主干分支进入步骤 5」的分水岭红线

**除以上 4 处外，其他所有步骤流转在任何模式下都不可豁免**，明确列表如下（防止歧义）：

| 步骤流转 | 标准模式 | 精简模式 | 原因 |
| --- | :---: | :---: | --- |
| 1 → 2 | ✅ 必须弹出 | ✅ 必须弹出 | 🟢流程决策点，范围确认前最后一道关 |
| 2 → 3 | ✅ 必须弹出 | ✅ 必须弹出 | 🔴 §2 用户确认后可合并，但推进必须显式 |
| 3 → 4 | ✅ 必须弹出 | ✅ 必须弹出 | 方案制定完成，用户需知晓进入决策 |
| 4 → 4.5 | ✅ 必须弹出 | ✅ 必须弹出 | 🔴 关键决策点，本身即决策 |
| 6 → 7 | ✅ 必须弹出 | ✅ 必须弹出 | 🟡 质量决策，进入 commit/devlog/knowledge 环节前最后关 |
| 7 → 8 或 → done | ✅ 必须弹出 | ✅ 必须弹出 | 🔴 关键分支点（标准/完整执行差异） |
| 8 → 9 | ✅ 必须弹出 | ✅ 必须弹出 | L3 审查完成，反思前用户确认 |
| 9 → 10 | ✅ 必须弹出 | ✅ 必须弹出 | 反思完成，归档前用户确认 |

**标准模式下不可豁免**：所有步骤流转均需弹出交互式选项，无例外。

> 📌 本表豁免的是「**步骤流转推进选项**」（A/B/C 选项是否弹），与 `references/interaction-mode.md` §🟢 的「**步骤内容展示**」静默是不同维度，互不影响关键决策点（🔴 必须暂停）。

**❌ 禁止**：步骤完成后只用纯文字提问"继续进入步骤 X？"而不调用 `ask_followup_question`

> ⚠️ **机械执行层强制校验**（2026-07-01 新增）：上述规则已由 `post-step.sh` 的步骤 1.6 语义门控机械兜底。
> 每个步骤的完成标记 JSON 中必须包含 `interactive_progression_shown: true`（精简模式豁免流转除外）。
> 字段缺失或非 true → `post-step.sh` 返回 exit 1，拒绝推进到下一步骤。
> 此机制弥补了「规范完备但 AI 可绕过」的执行层缺口。

### 分级钩子定义（Tiered Hooks）

根据步骤的关键程度，使用不同重量的完成钩子，减少轻量级步骤的 Token 开销：

| 钩子级别 | 适用步骤 | JSON 输出 | 状态同步 | 门控验证 |
| --- | --- | --- | --- | --- |
| 🔴 重量级 | 4（决策）、5（编码）、6（验证）、7（commit） | 完整 outputs + gate_checks | 完整（含快照） | 完整逐项校验 |
| 🟡 中量级 | 3（方案）、5.5（后置）、8（L3） | 精简 outputs（仅关键字段） | 完整（无快照） | 仅校验关键字段 |
| 🟢 轻量级 | 1（研究）、2（范围）、4.5（环境）、9（反思）、10（归档） | 最小 outputs（3-4个字段） | 合并写入 | 仅校验 status + next_step |

### 门控 Subagent 审查（关键步骤过程审计，v4 新增 2026-07-28）

> **设计意图**：现有门控体系（validate-output.sh + Lint 脚本 + 物理检查点）全部校验**产出物**，
> 但无法审计**过程**——无法确认"5.5a 的子 agent 是否真的 spawn 了"、"6A 的 V1~V8 是否每个都执行了"。
> 本机制引入独立的门控 Subagent，对 4 个最关键的步骤执行**过程完整性审查**。

#### 触发范围

仅在以下 4 个步骤的完成标记 JSON 通过 `validate-output.sh` 后、加载下一步骤前调用：

| 步骤 | 为何是它 | 审查清单 |
|------|---------|---------|
| **步骤 4** | 用户决策 + 文档平台 + devlog 命名，错了全流程白费 | 决策枚举 / plan.md 物理存在 / name_lint / doc_platform 决策闭环 / 分支命名 |
| **步骤 5.5** | 最复杂步骤，4 子环节 + 2 子 agent，最常遗漏 | 5.5a 子 agent 是否 spawn / 5.5b 文档同步 / 5.5c read_lints / 5.5d i18n |
| **步骤 6** | V1~V8 八个阶段，AI 经常象征性跑一两个 | 每阶段是否产出对应 artifact / 失败是否有熔断 |
| **步骤 7** | 收尾 A~K 多线并行，commit/devlog/knowledge 缺一不可 | 每环节是否真实完成 / debug_code 清除 / devlog 落盘 |

#### 调用方式

```text
步骤 N 完成 → 输出完成标记 JSON → validate-output.sh 通过
→ 🔀 若 N ∈ {4, 5.5, 6, 7}：Task(step-gate) 审查该步骤
→ 门控 Subagent 返回 pass → 加载下一步骤
→ 门控 Subagent 返回 fail → 输出 blockers 清单 → 补执行遗漏环节 → 重新审查
```

#### 失败处理

| 情况 | 处理 |
|------|------|
| Subagent 返回 fail + blockers 清单 | 立即补执行遗漏的子环节 → 重新走该步骤的退出自检清单 → 重新调用门控 Subagent |
| 连续 2 次 fail | 输出诊断信息 → 请求用户介入 |
| Subagent 调用异常（超时/错误） | 降级为手动对照退出自检清单逐项确认 → 不阻塞流程 |

#### 调用规范

```text
主 Agent 在 validate-output.sh 返回 0 后，调用：

Task(
  subagent_name="step-gate",
  description="审查步骤{N}完整性",
  prompt="请审查步骤 {N}（{步骤名称}）的执行完整性。
          对话摘要：{关键对话片段}
          请按退出自检清单逐项验证，
          在对话历史中搜索 [STEP-{N}-X-COMPLETE] 锚点标记，
          输出 pass/fail 判定 + 逐项证据。"
)
```

> ⚠️ 门控 Subagent **只审查不执行**——发现问题后只报告 blockers 清单，由主 Agent 补执行。
> ⚠️ 非关键步骤（1/2/3/4.5/8/9/10）不触发门控 Subagent，仅依赖退出自检清单的口播确认。
> ⚠️ micro-fix 模式下跳过门控 Subagent（所有步骤），保持轻量快速。

#### 与现有门控体系的关系

```text
┌─────────────────────────────────────────────────────────────┐
│  步骤 N 完成                                                 │
│    ↓                                                        │
│  退出自检清单（口播逐项确认）—— 新增                          │
│    ↓                                                        │
│  完成标记 JSON 输出                                          │
│    ↓                                                        │
│  validate-output.sh（Schema + 物理事实）—— 现有               │
│    ↓                                                        │
│  🔀 若 N ∈ {4, 5.5, 6, 7}：门控 Subagent 过程审计 —— 新增   │
│    ↓                                                        │
│  加载下一步骤                                                │
└─────────────────────────────────────────────────────────────┘
```

> 📌 退出自检清单 vs 门控 Subagent 的分工：清单是"自己检查自己"（prompt 级自律，零成本），
> Subagent 是"第三方检查"（独立审查，关键步骤专用）。两者互补，非替代关系。

### 步骤完成

每个步骤执行完毕后，**必须按顺序执行以下 3 个动作**：

#### 动作 1：输出结构化完成标记

```json
{
"step": "步骤编号（如 1、2、4.5）",
"name": "步骤名称",
"status": "completed | partial | blocked",
"outputs": {
"// 各步骤的必须输出项，详见各步骤文件末尾的「必须输出」定义"
},
"gate_passed": true,
"gate_checks": {
"json_complete": true,
"outputs_valid": true,
"context_updated": true,
"flow_file_synced": true
},
"interactive_progression_shown": true,
"next_step": "下一步骤编号 | batch_next（批次模式下表示切换到下一批次）"
}

```

> ⚠️ **`interactive_progression_shown` 字段说明**（2026-07-01 新增）：
>
> - **必须为 `true`**（标准模式所有步骤流转；精简模式非豁免流转）
> - 豁免场景（精简模式下可不填/可为 false）：`0.5→1` / `4.5→5` / `5→5.5` / `5.5→6`
> - 此字段由 `post-step.sh` 机械校验，缺失时拒绝推进到下一步骤（等价于红牌 #13）
> - 目的：解决「AI 只输出文本表格但未调用 `ask_followup_question`」的反复违规问题

#### 动作 2：状态同步（原子操作）

将工作上下文更新和 .flow 文件更新合并为**一次原子操作**，减少文件操作次数：

```text
一次性完成以下所有更新（禁止拆分为多次独立操作）：

1. 更新工作上下文：
- 步骤清单：当前步骤行的状态/时间/备注
- 当前状态：覆盖为下一步骤信息
- 恢复指令：指向下一步骤
- YAML 头部（如已启用）：current_step / steps.{N}.status / steps.{N}.time

2. 同步 .flow 文件（与工作上下文在同一次操作中完成）：
- 文件名与工作上下文一致（.md → .flow）
- **核心字段**（每次必写）：current_step、mode、status、last_active、brief
- **v3 扩展字段**（2026-05-12 起强制写入，向后兼容）：
- `phase`：从 current_step 推导（1~4=research / 5=coding / 6=integration 或 coding / iteration_count>0=iteration / 7+=commit-archive），或沿用工作上下文 `## 阶段感知区块` 实际状态
- `recovery`：3 段式 `{ yesterday, next_action, pending[] }`，与工作上下文 `### 恢复指令` 区块同步刷新
- `last_commit_hash`：步骤 5/5.5/6/7 完成时刷新（执行 `git rev-parse --short HEAD 2>/dev/null` 获取，失败留空）
- **步骤 5/5.5/6 完成**：记录当前 HEAD（尚未 commit 的工作进展锚点）
- **步骤 7 完成（标准/分批/micro-fix）**：必须在 `git commit` **执行后**再调用 `git rev-parse --short HEAD` 取新 hash 写入；禁止用 commit 前的旧 HEAD（否则 24h+ 跨天对账会误判"分支已变化"）
- **步骤 7 完整模式（caller=full-7，未 commit）**：沿用 commit 前的 HEAD，由步骤 10 完成 commit 后再次刷新
- **步骤 10 完成**：在 `git commit` 执行后取新 hash 写入（与步骤 7 标准一致）
- `match_keywords`：仅步骤 0/1 首次写入（5~10 个，从需求标题/任务平台标题/关键变量名/文件名提取）；步骤 5/6 完成时若发现高频新词可追加（去重，上限 15 个）
- `session_id`：首次创建 .flow 时生成（格式 `YYYYMMDD_HHMMSS_xxxx` 4 位随机 hex），后续步骤不变；并发抢占时换新值
- `last_model`：可选，写入当前会话使用的模型标识（如 `{model-id}`）
- 目录不存在时先 mkdir -p ~/.codebuddy/working-context/.active-flows/
- 最终步骤（标准执行7/完整执行10）→ 删除 .flow 文件而非更新
- **status 状态机**：
- 进入下一步骤前 → `active`
- 步骤完成、等用户输入下一动作 → `idle`（推荐：跨天恢复时这是最常见的状态）
- 步骤 5 完成等接口联调 → `blocked-by-backend`
- 步骤 7 完成等代码评审 → `blocked-by-review`
- 用户主动暂停 → `paused`

3. 写入物理检查点（v2 硬化 — 所有步骤强制，由 validate-output.sh 自动触发）：
- ⚠️ 不要直接 touch：`.step-{N}.validated` 文件**只能**由 `scripts/validate-output.sh` 创建
- 正确做法：将完成标记 JSON 写入 /tmp/dev-flow-step-{N}-output.json 后，调用：
bash ~/.codebuddy/skills/dev-flow/scripts/validate-output.sh {step-id} /tmp/dev-flow-step-{N}-output.json {flow-name}

- 脚本内部会：① Schema 校验 → ② 通过后自动 touch .validated + 写 .validated.json 元信息
- 与 .flow 文件更新在同一原子过程中完成（校验失败则 .flow 不更新 + .validated 不创建）
- 最终步骤完成时清理：`rm -f ~/.codebuddy/working-context/.active-flows/{name}.step-*.validated*`（同时清理 .done 旧兼容文件）

4. 状态快照（仅关键步骤，轻量级）：
- 触发条件：步骤 3（方案确定后）、步骤 5（编码完成后）、步骤 6（验证完成后）
- 快照目录：~/.codebuddy/working-context/.snapshots/{需求名}/
- 快照文件名：step-{N}_{时间戳}.md（cp 工作上下文文件）
- 保留策略：每个需求最多保留 5 个快照，超出时删除最早的
- 用途：回退时可参考历史快照恢复到特定步骤的状态
- ⚠️ 非关键步骤（1/2/4/4.5/5.5/7）跳过快照，避免不必要的 IO

```

> 💡 **优化说明**：原动作2（更新工作上下文）和动作2.5（更新.flow文件）合并为一个原子操作，
> 减少了一次 read_file + 一次终端写入，每个步骤切换节省约 2-3 次工具调用。

#### 动作 3：门控验证（双层校验）

**第一层：Schema 机器校验**（新增，结构层）

```bash

# 1. 将完成标记 JSON 写入临时文件（2）
cat > /tmp/dev-flow-step-{N}.json <<'EOF'
{ ... 完成标记 JSON ... }
EOF

# 2. 调用校验脚本（v2 硬化：必须传 flow-name 以触发物理检查点）
bash ~/.codebuddy/skills/dev-flow/scripts/validate-output.sh {step-id} /tmp/dev-flow-step-{N}.json {flow-name}

# flow-name 从工作上下文文件名推导（去 .md 后缀），例如：

#   工作上下文：~/.codebuddy/working-context/20260430_feat_xxx_my-project.md

#   → flow-name: 20260430_feat_xxx_my-project

# 返回码：0 通过+.validated 已创建 / 1 JSON 格式错误 / 2 Schema 失败（.validated 不创建）/ 3 工具缺失降级

```

- 返回码 2 → 立即补齐 outputs 字段后重新校验
- 返回码 3 → 工具缺失，降级到第二层文字规则校验（不阻塞）
- 连续 3 次 Schema 校验失败 → 升级为用户介入

**第二层：文字规则校验**（语义层）

按 `references/gate-validator.md` 中对应步骤的校验规则逐项验证：

- [ ] 完成标记 JSON 已输出且所有必须字段非空
- [ ] `status` 不是 `blocked`（blocked 时必须暂停等待用户指令）
- [ ] 工作上下文步骤清单已更新（上一步状态为 ✅/⚠️/❌，非 🔄/⏸️）
- [ ] .flow 文件已同步（或最终步骤已删除）：核心字段齐全 + v3 扩展字段已刷新
  （`phase`/`recovery.yesterday`/`recovery.next_action` 非空；
  `recovery.pending` 可为空数组；`match_keywords` 仅首次必填）
- [ ] outputs 中所有标注为「必须」的字段值符合预期（→ 详见 gate-validator.md 各步骤校验规则）

> 💡 **双层校验的价值**：Schema 层机械拦截结构性错误（字段缺失/类型错误/枚举越界/正则不匹配），文字规则层校验业务语义（用户确认真实性/跨字段一致性）。两层互补，缺一不可。

**门控失败处理**：

- 任何一项未通过 → 立即补齐，禁止以"稍后补"为由跳过
- 补齐后重新验证，通过后才能 `read_file` 加载下一步骤文件
- 连续 3 次校验失败 → 输出诊断信息，请求用户介入

## 🔴 红牌行为（检测到任何一条立即停止）

> **2026-05-29 重构**：旧 15 条红牌（#1~#15）按主题归并为 **R1~R7（7 条）**，行为定义不变，仅编号合并。
> 旧编号仍可在文档其他位置出现（向后兼容），AI 看到旧编号时按下方映射表定位到新编号即可。

### R1：步骤完整性（合并旧 #1 / #4 / #6 / #9）

每个步骤必须独立完整执行：① 独立输出结构化完成标记 JSON ② 独立更新工作上下文 ③ 一次只能加载一个步骤文件 ④ 一回合内不得连续完成多个步骤。

### R2：步骤文件加载（合并旧 #3 / #11）

执行某步骤前必须先 `read_file` 加载该步骤的详细规范。步骤 7 必须完整加载 `references/closeout-flow.md` 后再执行 commit/devlog/knowledge 收尾环节。

### R3：用户决策与交互式选项（合并旧 #2 / #7 / #13）

涉及用户决策的所有位置必须遵守：
① 步骤 4 → 5 等关键决策点必须等用户明确确认
② 决策点必须**双重展示**（文本选项列表 + `ask_followup_question`，行数与 options 数组长度严格一致）
③ 步骤完成后的推进选项必须用 `ask_followup_question` 而非纯文本提问
（精简模式豁免范围外亦不得放宽，详见 `references/gate-validator.md` §「交互式选项一致性门控」C1~C7）。

### R4：编码边界（合并旧 #5 / #8）

未通过编码前置硬卡点（`scripts/precheck/step5-precheck.sh`）不得执行 `replace_in_file` / `write_to_file` / `delete_file`。步骤 5 中只能执行已锁定计划内的改动，禁止临时扩展范围。

### R5：物理检查点（合并旧 #10 / #14）

步骤完成标记 JSON 输出后**必须**立即调用
`scripts/validate-output.sh <step-id> <json-file> <flow-name>` 执行机器校验。
脚本返回码 ≠ 0 或物理检查点 `.step-{N}.validated` 未由脚本生成时禁止加载下一步骤。
**严禁 AI 自行 `touch` `.validated` 文件伪造通过**（详见本文件 §「🔐 物理检查点机制」）。

### R6：commit 流程（保留旧 #12）

生成 commit message 时**必须**调用 `use_skill('smart-commit')`，禁止 AI 凭自身知识自行拼写 commit message。

### R7：工具门禁（保留旧 #15）

dev-flow 激活期间，当前步骤的禁用工具被调用即视为违规（详见 `config/gates.yaml` §`tool_gates`）—— 立即停止 + 回到当前步骤 + 输出违规报告。

### R8：退出自检清单与门控审查（新增 2026-07-28）

① 每个步骤完成标记 JSON 输出前，**必须**对照退出自检清单逐项口播确认（所有步骤强制）。② 关键步骤（4/5.5/6/7）的 `validate-output.sh` 通过后，**必须**调用门控 Subagent 进行过程审计（详见本文件 §「门控 Subagent 审查」）。③ 门控 Subagent 返回 fail 时，**禁止**加载下一步骤，必须先补执行遗漏环节。④ 禁止以"改动简单/已验证通过"等理由跳过退出自检清单或门控 Subagent 审查。

**检测到红牌后**：

```text
→ 立即停止当前动作
→ 输出 "⚠️ 红牌：{违规描述}，正在回退补齐"
→ 补齐遗漏的步骤/输出/JSON
→ 重新通过门控后继续

```

## 回退机制

遇到需要回退的场景时 → `read_file("references/rollback.md")` 加载完整回退对照表。

## 迭代修复场景

检测到迭代修复信号时 → `read_file("references/iteration-fix.md")` 加载迭代修复流程。
迭代修复场景下，步骤 1~3 可按 iteration-fix.md 中的简化规则执行，但仍须输出完成标记 JSON。

## 流程内修复回归规则（步骤 6→7 之间的修复场景）

<!-- 防御 2026-05-06 事故：步骤 6 静态验证通过后用户发现退出全屏位置偏移问题，AI 执行了迭代修复但跳过了
步骤 7 的 devlog/knowledge/完成标记，直接让用户跳过收尾——即步骤 6 通过/用户验收期间发现新问题后，
AI 跳过 closeout-flow.md 加载 + 结构化 JSON + validate-output.sh 校验。 -->

### 触发场景

步骤 5/5.5/6 已完成，但在以下任一情况下需要额外修改代码：

1. 用户在步骤 6 的实际验收中发现新问题（如本案例）
2. 步骤 6B 用户验收不通过
3. 步骤 6 通过后、步骤 7 加载前，用户追加修复要求

### 强制规则（⛔ 不可绕过）

1. **修复完成后必须重走步骤 5.5→6→7 的完整链路**：

- 修复代码 → `read_file("steps/step-5.5-post-coding.md")` L1 审查
- → `read_file("steps/step-6-verify.md")` 验证
- → `read_file("steps/step-7-commit.md")` + `read_file("references/closeout-flow.md")` 完整收尾
- 每个步骤独立输出完成标记 JSON + 调用 validate-output.sh

1. **禁止以"修复已验证通过"为由跳过步骤 7 的任何环节**：

- ❌ 禁止只做 commit 生成跳过 devlog
- ❌ 禁止只做 devlog 跳过 knowledge 沉淀
- ❌ 禁止不输出步骤 7 完成标记 JSON
- ❌ 禁止不调用 validate-output.sh

1. **步骤 7 的物理检查点是流程结束的唯一合法标志**：

- 只有 `{flow-name}.step-7.validated` 存在，才能标记流程完成并清理 .flow 文件
- AI 不得在缺少 step-7.validated 的情况下删除 .flow 文件或声称流程结束

1. **精简模式不豁免本规则**：即使用户启用了精简交互，步骤 7 的完整执行（A~J 环节）仍然强制。精简模式仅影响交互频率，不影响 commit/devlog/knowledge 环节的执行完整性。

### 回退路径速查

| 修复发生时机 | 回退路径 |
| --- | --- |
| 步骤 6A 验证失败 | 回退步骤 5 修复 → 5.5 → 6A → 6C → 7 |
| 步骤 6B 用户验收不通过 | 回退步骤 5 修复 → 5.5 → 6A → 6B → 7 |
| 步骤 6C 通过后/步骤 7 加载前用户追加修复 | 修复 → 5.5 → 6 → 7（完整链路） |
| 步骤 7 执行中发现问题 | 回退步骤 5 修复 → 5.5 → 6 → 7（重新执行） |
| 5.5 静默累计 ≥3 次 / 用户主动召唤 | 走 `dev:sync`（caller=in-flow-sync）同步文档子集，完成后回原步骤继续，不替代后续步骤 7 收尾 |

## 批次切换场景

检测到 `next_step` 为 `batch_next` 时（批次模式下非最后一批的步骤 7 完成后）：

1. 读取工作上下文 YAML 头部的 `current_batch` 和 `total_batches`
2. 递增 `current_batch`，更新批次进度表格中对应批次状态为 `🔄 进行中`
3. 更新 `.flow` 文件步骤号为 `4.5`（从环境检查开始，跳过步骤 1~4）
4. 加载 `steps/step-4.5-env-check.md` 开始下一批次的执行

> ⚠️ 批次切换**不是**迭代修复。批次切换是同一需求内的计划内分批执行，步骤 1~4 已在首批完成，后续批次从步骤 4.5 开始。
> 迭代修复是需求外的反馈修复，需要重新走增量版步�
