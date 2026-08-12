# 共享规则（单一真相源）

> 本文件集中定义在多个文件中重复出现的规则。各文件通过引用本文件消除重复。
> 修改规则时只需修改本文件，所有引用方自动生效。

---

## 1. Commit Message 生成流程

> 📌 单一真相源。SKILL.md、step-7-commit、closeout-flow.md、flow 步骤 10 均引用此处。

### 标准流程

1. **复用检查**：先检查工作上下文 `## 交付` 区块是否已有生成过的 Commit Message

- 已有 → 向用户展示已有内容，弹出选项：✅ 直接使用 / ✏️ 修改 / 🔄 重新生成
- 没有 → 进入步骤 2

1. **调用 Skill**：`use_skill('smart-commit')` 生成 Commit Message
2. **任务平台 信息获取优先级**：对话上下文中已有 → 直接复用 > 用户附带 任务平台 链接 → 解析使用 > git 分支名自动查询关联单据 > 均无 → 生成不含 任务平台 关联的 commit
3. **用户确认**（交互式）：生成后**必须使用 `ask_followup_question` 弹出交互式选项**：

| 选项 | 说明 |
| --- | --- |
| ✅ 确认 | 使用当前 commit message |
| ✏️ 修改 | 告诉我需要调整的内容 |
| 🔄 重新生成 | 重新生成 commit message |
| 📦 确认并提交 | 确认 commit message 并执行 `git add` + `git commit` |

1. **持久化**：用户确认后，将 Commit Message 写入工作上下文 `## 交付` 区块

### 触发点

| 模式 | 触发位置 | 备注 |
| --- | --- | --- |
| 标准执行 | 步骤 7（清理+Commit） | — |
| 标准执行 | 步骤 6C「📝 生成 Commit Message 并暂存」选项 | 暂存场景 |
| 完整执行 | 步骤 10（归档与交付） | 步骤 7 裁剪掉 commit 生成 |

- 仅生成，❌ 禁止自动执行 `git commit`（除非用户选择「📦 确认并提交」）
- Commit 格式：`<type>: <description>`（无 scope，不加括号）

---

## 2. 规范沉淀规则

> 📌 单一真相源：独立 Skill `knowledge-loop`（`~/.codebuddy/skills/knowledge-loop/`）。
> step-7-commit、flow 步骤 10、closeout-flow.md 环节 H 均调用 `use_skill('knowledge-loop')` 沉淀模式。

### 核心要点

- **必须执行**：标准执行步骤7 / 完整执行步骤10 / 收尾环节H，禁止跳过
- **增量更新**：追加新信息，不覆盖已有内容
- **最小沉淀**：简单改动仅追加变更历史一行
- **完整流程**：`use_skill('knowledge-loop')` 沉淀模式

---

## 3. 并行执行策略（环境感知多模式）

> 📌 单一真相源。SKILL.md、step-1、step-5、step-6 均引用此处。

### 设计理念

> **务实分层**：根据运行时环境的实际能力动态适配执行策略
> **向上兼容**：CodeBuddy 中的并行工具调用，可无缝映射为多 Agent 环境中的独立 Agent 实例
> **准确判断**：基于具体可验证的运行时信号检测平台能力，宁可降级也不误判

### 平台能力检测（首次并行调度前必须执行）

**检测规则**：按优先级依次检查以下信号，**首个匹配即确定模式**，未匹配则降级为下一项：

| 优先级 | 检测信号（必须全部满足） | 平台判定 | 执行模式 |
| --- | --- | --- | --- |
| 1 | ① 可调用 `/teams` 命令 ② 环境变量 `CLAUDE_CODE_AGENT_TEAMS=1` | Claude Code (Agent Teams) | 🟢 多 Agent 团队 |
| 2 | ① 可调用 `Task` 工具创建子代理 ② 子代理拥有独立上下文窗口 | Claude Code (Subagents) | 🟡 子代理模式 |
| 3 | ① `team_create` + `send_message` 工具可用 ② `Task` 工具可用且 `agents/` 目录下存在自定义 Agent 定义 | CodeBuddy (Subagents + Teams) | 🟡 子代理模式（Teams 备用） |
| 4 | ① `Task` 工具可用 ② `agents/` 目录下存在自定义 Agent 定义（1号~9号） ③ 无 `team_create` 工具 | CodeBuddy (Subagents only) | 🟡 子代理模式 |
| 5 | ① WorkBuddy Agent Teams API 可用 ② 可创建多个独立 Agent 实例 ③ 成员间支持异步消息通信 | WorkBuddy (Agent Teams) | 🟢 多 Agent 团队 |
| 6 | ① WorkBuddy 子代理 API 可用 ② 可在单会话内创建子代理执行子任务 | WorkBuddy (Subagents) | 🟡 子代理模式 |
| 7 | ① `~/.openclaw/` 目录存在 ② openclaw.json 中配置了 subagents.allowAgents | OpenClaw | 🟡 多 Agent 协作 |
| 8 | 以上均不满足（默认） | 单 Agent IDE | 🔵 并行工具调用 |

> **CodeBuddy 子代理模式说明**（优先级 3~4）：
>
> - 通过 `Task` 工具调用 `agents/` 下的自定义 Agent（1号~9号），各 Agent 拥有独立上下文
> - 子 Agent **只做只读操作**（搜索/读取/分析/验证），文件写入由主 Agent 串行执行
> - 可在同一轮对话中并行发起多个 `Task` 调用
> - `team_create` + `send_message` 提供异步团队模式（备用），适合持续协作场景但当前 dev-flow 流程暂不启用
> - Agent 角色映射：按 `agents/` 目录下的 Agent 描述与§3 角色定义自动匹配

**检测结果展示**（必须在首次使用并行调度时向用户输出）：

```text
📡 平台能力检测：
├─ 运行环境：{检测到的平台名称}
├─ 多 Agent 支持：{🟢 完整支持 / 🟡 子代理模式 / ❌ 不支持}
├─ 执行模式：{多 Agent 团队 / 子代理模式 / 并行工具调用}
├─ 角色系统：{完整角色定义 / 轻量角色映射 / 装饰性标注}
└─ 检测依据：{具体匹配的信号描述}

```

**防误判规则**：

- **保守原则**：任何检测信号不确定时，一律降级为「🔵 并行工具调用」模式
- **禁止猜测**：不得仅凭用户声明或环境名称推断能力，必须验证具体信号
- **动态降级**：运行中发现实际能力不符（如子代理创建失败），立即降级并通知用户

### 模式 A：并行工具调用（CodeBuddy / 默认模式）

> 适用于单 Agent 环境，通过并行工具调用实现任务并行

#### 调度策略

| 任务量 | 策略 |
| --- | --- |
| ≤ 2 个子任务 | 顺序执行（减少上下文开销） |
| 3~5 个 | 并行工具调用（同时发起多个搜索/读取） |
| 6~9 个 | 全并行 + task_list 状态跟踪 |

#### 执行约束

- **只读优先**：并行调用仅限只读操作（搜索、分析、读取），文件写入必须顺序执行
- **结果聚合**：并行结果需汇总去重后再决策
- **声明格式**：`🔀 并行调度: [任务1: 描述] | [任务2: 描述] | ...`
- **角色标注（装饰性）**：可在声明中标注角色作为思维引导，但不改变实际执行行为
- 示例：`🔀 并行调度: [🔍研究-1: 搜索组件用法] | [🔍研究-2: 分析依赖链]`

### 模式 B：多 Agent 协作（支持真正多 Agent 的平台）

> 适用于 Claude Code (Subagents/Agent Teams) / WorkBuddy (Subagents/Agent Teams) / OpenClaw 等支持独立 Agent 实例的环境

#### 调度策略（2）

| 任务量 | 策略 |
| --- | --- |
| ≤ 2 个子任务 | 主 Agent 直接执行 |
| 3~5 个 | 调度 3~5 个独立 Agent 并行 |
| 6~9 个 | 调度 6~9 个独立 Agent 全并行 |

#### Agent 角色定义（完整角色系统）

| 步骤 | Agent 角色 | 职责 | 关注点 |
| --- | --- | --- | --- |
| 步骤 1（研究定位） | 🔍 研究员（Researcher） | 代码搜索、依赖分析、规范检索 | 全面性、不遗漏关联文件 |
| 步骤 3（制定方案） | 🏗️ 架构师（Architect） | 方案评估、风险分析、技术选型 | 可行性、副作用、一致性 |
| 步骤 5（执行修改） | 💻 开发者（Developer） | 代码实现、样式编写、类型定义 | 最小入侵、代码质量、边界处理 |
| 步骤 6（质量验证） | 🧪 测试员（Tester） | 功能验证、边界测试、回归检查 | 覆盖率、边界条件、竞态场景 |
| 步骤 7（清理+Commit） | 📋 审查员（Reviewer） | 代码审查、规范沉淀、清理验证 | 代码整洁、规范一致性 |
| 步骤 8（L3 审查） | 🛡️ 安全官（Security Officer） | 安全审查、性能审查、架构审查 | 安全漏洞、性能瓶颈、设计缺陷 |
| 步骤 9（反思学习） | 📊 分析师（Analyst） | 度量分析、经验提炼、规则建议 | 数据驱动、可操作性 |

#### 执行约束（2）

- **独立上下文**：每个 Agent 拥有独立的上下文窗口，避免信息干扰
- **只读子 Agent**：子 Agent 只做只读操作（搜索、分析），文件写入由主 Agent 执行
- **明确输入输出**：每个 Agent 任务必须有明确的输入和预期输出
- **结果聚合**：Agent 结果需要主 Agent 汇总和去重后再使用
- **主 Agent 决策**：主 Agent 始终是最终决策者
- **Fan-out 声明格式**：`🔀 Fan-out: [🔍研究员-1: 搜索组件用法] | [🔍研究员-2: 分析依赖链]`

### 子代理调度指引（CodeBuddy 环境，检测到优先级 3~4 时生效）

> 以下指引仅在平台检测匹配 CodeBuddy 子代理模式时生效。模式 A（并行工具调用）环境忽略此章节。
> 子 Agent **严格只读**，禁止授予写入权限——多 Agent 写入会引入语义冲突、门控原子性破坏、回退困难等不可控风险。

#### 调度决策矩阵

| 步骤 | 推荐调度 | 子 Agent 角色 | 任务内容 | 触发条件 |
| :---: | :---: | --- | --- | --- |
| 1（研究） | 🟡 条件触发 | 1号（代码搜索）、code-explorer、9号（兜底） | 按模块/目录分配搜索范围 | 涉及 ≥3 个模块或 ≥5 个目录 |
| 5（编码） | 🔵 不使用 | — | 主 Agent 串行写入 | 写入场景不适用子 Agent |
| 6（验证） | 🟢 推荐 | 4号（测试验证）、5号（安全） | 按验证阶段分配独立命令 | ≥3 个验证阶段需执行 |
| 8（L3 审查） | 🟢 强烈推荐 | 2号（审查）、5号（安全）、6号（性能） | 按审查视角独立审查 | 始终（完整执行必经） |

> **不适合子代理调度的步骤**：步骤 2/3/4/4.5/5.5/7/9/10 均为交互决策、方案思考、串行写入或数据驱动分析，拆分到子 Agent 反而增加协调开销、降低产出一致性。

#### 步骤 1：子代理研究调度

**触发条件**：需搜索 ≥3 个独立模块/目录，且对话未进入黄色预警。不满足则主 Agent 并行工具调用即可。

```text
🔀 Fan-out（步骤 1 研究，{N} 子 Agent）：
├─ Task(1号): 搜索 {模块A目录}，定位相关组件/函数/Hook
├─ Task(code-explorer): 搜索 {模块B目录}，追踪依赖链路
└─ Task(9号): 搜索 knowledge/ + .learnings/ 匹配相关知识和经验
⏳ Fan-in → 主 Agent 汇总去重 → 输出相关文件表格

```

**每个 Task prompt 必须包含**：① 搜索的目标目录/关键词 ② 搜索的目的（与当前需求的关系） ③ 期望输出格式（文件路径 + 作用 + 与任务关系的表格）。禁止依赖主 Agent 的隐式上下文。

#### 步骤 5：写入场景说明

步骤 5 的 `🔀 可并行子任务` 指**主 Agent 并行工具调用**：

- 并行 `read_file` 读取多个待改文件（只读操作，可并行）
- 串行 `replace_in_file` / `write_to_file` 逐个写入（写入操作，必须串行）
- 子 Agent **不参与**步骤 5（子 Agent 只读，不能执行写入操作）

#### 步骤 5.5a：子代理 L1 审查调度（审核者分离）

> **🆕 2026-07-08 新增**：审核者分离——编码者与审查者分离，消除"自写自审"盲区。

**触发条件**：步骤 5 产生了任何代码文件改动即触发（标准模式 / 完整模式 / 精简模式 / 迭代修复 / 步骤 5 内部多轮修复 均启用；仅 micro-fix 跳过）。

> **模式差异**：
>
> - **micro-fix**：跳过（单文件 ≤10 行已知位置，子 agent 开销远超改动量，违反轻量设计意图）
> - **迭代修复**：启用（上线前 bugfix / 提测反馈修复，回归风险最高，token 投入合理；🟡 仍自动跳过以减少打断）
> - **步骤 5 内部多轮修复**：启用（🔴 自动修复不增加交互次数，仅 token 成本；🟡 仍自动跳过）
> - 完整规范 → `steps/step-5.5-post-coding.md` §5.5a §「模式差异」

```text
🔀 Fan-out（步骤 5.5a L1 审查，2 子 Agent）：
├─ Task(2号): 代码审查 — 功能正确性、边界条件、可选链、代码风格、
│            React 规范、调试残留 → CRITICAL/HIGH/MEDIUM/LOW 分级
└─ Task(5号): 安全快速扫描 — XSS/注入、硬编码密钥、输入校验
⏳ Fan-in → 主 Agent 汇总去重 → 输出统一 L1 审查报告

```

**Fan-in 后处理**：🔴 立即修复并重审（最多 2 轮）→ 🟡 弹 `ask_followup_question` 让用户决策 → 🟢 仅记录。

> 完整规范 → `steps/step-5.5-post-coding.md` §5.5a。

#### 步骤 6A V7：子代理调用方独立追踪（审核者分离）

> **🆕 2026-07-08 新增**：回归风险评估的调用方追踪由独立子 agent（1号）执行，与 V1-V3 并行发起，不增加串行时间。

**触发条件**：步骤 6A V7 执行时始终触发。

**执行方式**：主 agent 在 V1-V3 并行期间同时发起 `Task(1号)`，分析功能分支全量 diff 的调用方影响。主 agent 在 V7 阶段直接消费 1号的追踪结果。

> 完整规范 → `steps/step-6-verify.md` §V7。

#### 步骤 7-G：子代理 L2 审查调度（审核者分离）

> **🆕 2026-07-08 新增**：L2 审查是 commit 前最后一道质量门，通过 3 个独立子 agent 并行审查（代码质量 + 安全 + 性能），对齐 L3 审查的多视角标准。

**触发条件**：始终（所有调用方：`standard-7` / `full-7` / `batch-7` 均启用）。

```text
🔀 Fan-out（步骤 7-G L2 审查，3 子 Agent，与步骤 8 L3 对齐）：
├─ Task(2号-审查): 代码质量视角 — CRITICAL/HIGH 问题扫描
│            + 可维护性 + 测试点位建议
├─ Task(5号-安全): 安全审计视角 — XSS/注入/敏感数据泄露/
│            CSRF/硬编码密钥
└─ Task(6号-性能): 性能工程视角 — 重渲染/包体积/
内存泄漏/浏览器兼容性
⏳ Fan-in → 主 Agent 汇总三份报告 → 去重 + 按严重度排序 → 输出统一 L2 审查报告

```

**Fan-in 后处理**：🔴 回步骤 5 修复 → 重走 5.5→6A→7-G（最多 1 轮，第 2 轮仍有 🔴 暂停等用户）。

> 完整规范 → `references/closeout-flow.md` §环节 G。

#### 步骤 8：子代理 L3 多视角审查调度

**触发条件**：始终（步骤 8 仅在完整执行时触发，天然适合多视角并行）。

```text
🔀 Fan-out（步骤 8 L3 审查，3 子 Agent）：
├─ Task(2号-审查): 代码质量视角 — CRITICAL/HIGH 问题扫描 + 可维护性 + 测试点位建议
├─ Task(5号-安全): 安全审计视角 — XSS/注入/敏感数据泄露/CSRF/硬编码密钥
└─ Task(6号-性能): 性能工程视角 — 重渲染/包体积/内存泄漏/浏览器兼容性
⏳ Fan-in → 主 Agent 汇总三份报告 → 去重 + 按严重度排序 → 输出统一 L3 审查报告

```

**每个 Task prompt 必须包含**：① 本次改动的文件列表和 diff 摘要 ② 该视角的审查清单 ③ 输出格式（按 CRITICAL/HIGH/MEDIUM/LOW 分级）。

### 跨模式通用约束

- **写入隔离**：无论哪种模式，文件修改必须顺序执行，避免冲突
- **声明格式统一**：模式 A 使用 `🔀 并行调度:`，模式 B 使用 `🔀 Fan-out:`
- **结果聚合**：并行/分布式结果均需主 Agent 汇总去重后再决策（详见下方「结果聚合与冲突检测」）
- **模式切换透明**：切换模式时必须重新输出检测结果，告知用户当前生效的模式

### 成本感知调度

> 并行提升速度但增加 Token 消耗，需根据对话状态动态调整并行度。

| 条件 | 调度调整 | 理由 |
| --- | --- | --- |
| 对话轮次 >15 或 Token 进入黄色预警 | 并行度上限降为 3（原 6~9 降级） | 节省上下文窗口给后续步骤 |
| 对话轮次 >25 或 Token 进入红色预警 | 禁止并行，全部串行 | 保护对话质量，避免上下文溢出 |
| 子 Agent 返回结果 >2000 Token | 主 Agent 汇总时压缩为 ≤500 Token 摘要 | 与 AI 行为规范「上下文精简」对齐 |
| 批次模式后续批次（非首批） | 可降低并行度（首批经验已积累，后续可更精准串行） | 减少不必要的并行开销 |

### 结果聚合与冲突检测

主 Agent 汇总并行结果时，**必须执行以下检查**：

1. **去重**：多个子 Agent 搜索到同一文件/函数 → 合并为一条，保留信息最丰富的版本
2. **矛盾检测**：多个子 Agent 对同一问题得出相反结论（如 A 说该函数安全、B 说存在 XSS 风险）→ 标记矛盾，主 Agent 进一步分析后取结论
3. **搜索范围不重叠**：分配搜索任务时，明确各子 Agent 的搜索范围边界（如按目录分配），避免重复搜索浪费 Token

> 冲突检测为静默执行，仅在发现矛盾时向用户说明。无矛盾时零开销。

### 并行执行进度格式

使用并行调度时，**向用户展示进度概览**（步骤 1 研究、步骤 5 编码、步骤 6 验证等场景）：

```text
🔀 并行调度（{N} 任务）：
├─ {角色/Agent}: {任务描述} .......... {✅ 完成 / 🔄 进行中 / ❌ 失败}
├─ {角色/Agent}: {任务描述} .......... {状态}
└─ {角色/Agent}: {任务描述} .......... {状态}
⏳ 汇聚中 → {下一步动作}

```

> 此格式为建议性输出，在并行子任务 ≥3 个时展示，<3 个时可省略。

---

## 4. 步骤完成钩子（通用模板）

> 📌 单一真相源。所有步骤文件的「📌 步骤完成钩子」均遵循此模板。

每个步骤完成时，必须按以下顺序执行原子操作：

```text
步骤 N 执行完毕
→ 1. 输出结构化完成标记 JSON（→ 模板详见 references/output-schemas.md）
→ 2. 更新工作上下文（步骤清单状态 + 当前状态 + 恢复指令 3 段式）
→ 3. 更新 .flow 文件（v2 核心字段 + v3 扩展字段，详见下表）
→ 4. 门控校验（→ 详见 references/gate-validator.md）
→ 5. 通过 → 加载下一步骤文件

```

**`.flow` 字段刷新清单**（v3 schema，2026-05-12 升级，向后兼容）：

| 字段 | 类型 | 何时刷新 | 单一真相源 |
| --- | --- | --- | --- |
| `current_step` | v2 必填 | 每个步骤完成 | step-router.md |
| `last_active` | v2 必填 | 每个步骤完成 | step-router.md |
| `status` | v2 必填 | 状态切换时（active/idle/blocked-*/paused/completed/superseded） | active-flows.md `.flow status` 表 |
| `phase` | v3 必填 | 阶段切换时（research/coding/integration/iteration/commit-archive） | step-router.md L480 |
| `recovery.{yesterday, next_action, pending[]}` | v3 必填 | 每个步骤完成（与工作上下文 `### 恢复指令` 同步刷新） | step-router.md L481 |
| `last_commit_hash` | v3 选填 | 步骤 5/5.5/6/7 完成时（步骤 7 记录 commit 后的新 hash） | step-router.md L482-484 |
| `match_keywords` | v3 选填 | 步骤 0/1 首次写入；步骤 5/6 可追加 | step-router.md L487 |
| `session_id` | v3 选填 | 首次创建时；并发抢占时重置 | working-context/README.md「session_id 维护」 |

> ⚠️ **禁止只刷新 `current_step + last_active`**：v3 字段缺失会导致跨对话恢复时 AI 走降级路径（散文恢复指令 + 仅 brief 子串匹配），用户体验明显下降。完整字段写入是步骤完成钩子的硬性要求。

**原子性要求**：步骤 1~4 为不可分割的原子操作，中间不插入其他动作。

---

## 5. Skill 自动发现规则

> 📌 单一真相源。SKILL.md 引用此处。
> 核心理念：哪怕只有 1% 的可能性某个 Skill 能帮助当前任务，也应该主动检查并调用。

| 步骤 | 检查场景 | 可能匹配的 Skill |
| --- | --- | --- |
| 步骤 1（研究定位） | 需要检索历史经验 | `self-improving-agent` |
| 步骤 3（制定方案） | 方案设计阶段 | `design-advisor`、`security-review` |
| 步骤 5（执行修改） | 编码实现阶段 | `coding-standards`、`frontend-patterns`、`i18n`、`dom-animation`、`knowledge-loop`（检索模式）、`browser-toolkit`（UI/性能调试时）、`browser-compat`（涉及 JS API / CSS 属性时，作为生成代码前的参考） |
| 步骤 5.5（TDD 模式） | 测试驱动开发 | `e2e-testing`、`verification-loop` |
| 步骤 6（质量验证） | 验证阶段 | `verification-pipeline`、`code-review`（L1 第 5 条内部代理 `browser-compat`）、`browser-toolkit`（V4 浏览器工具路由） |
| 步骤 9（反思学习） | 经验沉淀 | `self-improving-agent` |

**执行规则**：

1. **静默评估**：不向用户输出"我正在检查可用 Skill"，直接在内部评估
2. **主动建议**：如果发现高度匹配的 Skill，在当前步骤的输出中自然地调用或建议调用
3. **不强制**：Skill 发现是辅助机制，不阻塞主流程
4. **避免重复加载**：已在上下文中的 Skill 不重复加载

---

## 6. Git 分支命名规范

> 📌 单一真相源。SKILL.md、flow.md 阶段 0、step-4-decision.md、step-4.5-env-check.md、iteration-fix.md 均引用此处。
> 分支名定稿时机：步骤 4 用户确认执行后、计划保存到磁盘前。步骤 3 不涉及任何分支推荐/校验。

### 命名格式

| 场景 | 格式 | 示例 | 说明 |
| --- | --- | --- | --- |
| 新功能 | `feature/<功能简述>` | `feature/ban-long-block` | 常规开发分支 |
| Bug 修复 | `bugfix/<问题简述>` | `bugfix/fix-date-display` | 提测/线上 bug 修复 |
| 紧急修复 | `hotfix/<问题简述>` | `hotfix/login-crash` | 线上紧急热修 |
| 测试分支 | `test/<测试简述>` | `test/e2e-login` | 测试相关专用分支 |
| 国际化分支 | `i18n/<语言或功能简述>` | `i18n/en-translations` | 多语言翻译专用 |
| 私有化分支 | `private/<简述>` | `private/oem-customer` | 私有化/定制客户分支 |
| 功能孙分支 | `feature_dev/<功能简述>/<开发者>` | `feature_dev/ban-long-block/{username}` | 多人协作孙分支，**一般与同名 `feature/` 父分支同时存在**，末段固定为开发者用户名（开发者用户名） |
| 混合云分支 | `sub-master/<简述>` | `sub-master/hybrid-v1` | 混合云主干分支（前缀含短横线，整体作为一个段） |
| 混合云开发分支 | `dev/<简述>` | `dev/hybrid-feature` | 混合云开发分支 |

### 功能简述命名约束（强制，适用于全部 9 类前缀）

- **最多 3 个单词**：功能简述部分由 1~3 个英文单词组成，超过 3 个必须精简
- **单词优先整词**：每个单词尽量使用完整单词，避免无意义缩写（`btn`→`button`，`msg`→`message`），通用缩写例外（`api`/`ui`/`url`/`id`）
- **短横线连接**：单词之间用短横线 `-` 连接，全部小写
- **禁止驼峰**：禁止 `camelCase`、`PascalCase`、`snake_case`、无分隔连写
- **从需求描述中提取**：从需求核心动作 + 对象中提取关键词，省略冠词/介词

#### 命名示例对照

| 需求描述 | ✅ 正确 | ❌ 错误 |
| --- | --- | --- |
| 禁止长期消息屏蔽 | `feature/ban-long-block` | `feature/ban-long-term-message-block`（>3 词）、`feature/banLongBlock`（驼峰）、`feature/ban_long_block`（下划线） |
| 修复订单日期显示 | `bugfix/fix-date-display` | `bugfix/fix-order-date-display-issue`（>3 词）、`bugfix/fixDateDisplay`（驼峰） |
| 灰度参数配置 | `feature/gray-param-config` | `feature/grayParamConfig`（驼峰）、`feature/gray-parameter-configuration`（单词过长但仍合规，建议精简为左侧） |

### 自动推荐规则（基于事实的前缀判定）

| 需求类型信号 | 推荐前缀 | 判定时机 | AI 自动推荐 |
| --- | --- | --- | :---: |
| 新功能 / feature / 需求开发 / 新增能力 | `feature/` + `feature_dev/.../<开发者>` | 步骤 4 计划锁定后定稿 | ✅ 同时推荐父+孙分支 |
| 修复 / fix / bugfix / 提测反馈 / 线上问题 | `bugfix/` | 步骤 4 计划锁定后定稿 | ✅ |
| 紧急修复 / hotfix / 线上事故 / 紧急回滚 | `hotfix/` | 步骤 4 计划锁定后定稿 | ✅ |
| 国际化 / i18n / 多语言 / 翻译 / 语言包 | `i18n/` | 步骤 4 计划锁定后定稿 | ✅ |
| 私有化 / OEM / 定制客户 / 私有部署 | `private/` | 步骤 4 计划锁定后定稿 | ✅ |
| 多人协作同一功能（显式告知或默认 feature 场景） | `feature_dev/<功能简述>/{username}` | 步骤 4 计划锁定后定稿 | ✅ feature/ 场景默认推荐 |
| 测试相关（e2e/单元测试专用分支） | `test/` | 用户显式指定 | ❌ 仅前缀校验 |
| 混合云主干 | `sub-master/` | 用户显式指定 | ❌ 仅前缀校验 |
| 混合云开发 | `dev/` | 用户显式指定 | ❌ 仅前缀校验 |

- 迭代修复场景复用已有分支，不新建
- 用户已告知分支名则直接采用，不再推荐
- `test/`、`sub-master/`、`dev/` 三类因语义宽泛/项目特定，AI **不主动推荐**，仅在用户显式指定时做前缀合法性与命名约束校验
- **`feature/` 场景的孙分支默认推荐策略**：
- 推荐父分支 `feature/<≤3词>` 用于功能合入
- **同步**推荐孙分支 `feature_dev/<≤3词>/<开发者用户名>`（开发者用户名）作为**默认实际编码分支**
- 设计意图：实际编码工作绝大多数发生在孙分支上，避免步骤 4.5 误报"分支漂移"
- 用户可在步骤 4 显式选择「直接在父分支编码」覆盖默认（单人开发时）
- 非 `feature/` 前缀（bugfix/hotfix/i18n/private 等）**无孙分支约定**，跳过孙分支推荐

### 推荐时机（单阶段定稿）

> 「**用户告知 OR 步骤 4 推荐**」二元模型，分支推荐**全流程仅一次**，时机为步骤 4 计划锁定后、磁盘保存前。

| 阶段 | 触点 | 行为 |
| --- | --- | --- |
| 阶段 0 | 需求理解结束 | **不输出 AI 预告**；仅当用户在需求描述中**主动告知**分支名时记录 `branch_user_specified` |
| 步骤 1~3 | 研究/范围/方案 | **完全不涉及**分支推荐与校验（聚焦研究与方案制定） |
| **步骤 4** | **计划锁定后、磁盘保存前** | **唯一定稿点**：基于已锁定的最终方案推荐分支名（含 feature/ 场景的父+孙分支），用户确认后写入工作上下文 `branch` / `branch_dev` / `branch_workspace` 字段 |
| 步骤 4.5 | 环境检查 | 校验：读取工作上下文 `branch` + `branch_dev`，对比当前分支，**父孙分支视为等价匹配**，引导切换 |

**关键约束**：

- ❌ 禁止步骤 1~3 涉及任何分支推荐（专注研究/范围/方案）
- ❌ 禁止 AI 自动执行 `git checkout -b`（所有切换必须由用户手动执行）
- ✅ 用户已告知分支名（`branch_status: "user_specified"`） → 跳过步骤 4 §4.1「分支名最终推荐」，直接进入步骤 4.5 校验
- ✅ 迭代修复复用已有分支（`branch_status: "iteration_reuse"`）→ 同上跳过
- ✅ 步骤 4 修改循环改动了方案性质 → 计划锁定时**重新基于最终方案评估前缀**（避免循环结束后分支名与方案不匹配）

---

## 7. Git 分支时序规范（前期调研 vs 开发沉淀）

> 明确 dev-flow 各阶段应在哪个 Git 分支上执行，与 knowledge-loop 的分支感知机制（pending/verified）协同。

### 阶段-分支映射

| 阶段 | 推荐分支 | 原因 |
| --- | --- | --- |
| 阶段 0：需求理解 | 任意分支（通常 master） | 无代码改动，仅分析需求 |
| 步骤 1：研究定位 | master（推荐） | 基于稳定基线分析现状、检索已有知识 |
| 步骤 2：影响范围 | master（推荐） | 扫描现状、估算改动范围，避免 feature 脏代码干扰 |
| 步骤 3：制定方案 | master（推荐） | 技术方案基于稳定基线设计，避免错误锚定 |
| 步骤 4：智能评估 + 分支名最终推荐 | 任意（通常仍在 master） | 计划锁定后、保存前，基于最终方案推荐分支名（含父+孙） |
| **步骤 4.5：环境检查** | **feature（强制切换）** | **进入编码前必须在 feature 子树（父或孙分支均可）** |
| 步骤 5：编码执行 | feature/feature_dev（强制） | 所有代码改动在 feature 子树，避免污染 master |
| 步骤 5.5：编码后检查 | feature/feature_dev | 同步编码分支 |
| 步骤 6：验证修复 | feature/feature_dev | 验证分支上的改动 |
| 步骤 7：清理 Commit | feature/feature_dev | commit 到实际编码分支 |
| 步骤 8-10：标准/完整执行 | feature | 含文档/MR/归档 |
| 收尾环节 H.1~H.3 | feature | 收尾合并前都在 feature |

### 核心约束

- **步骤 1-3 在 master**：研究与方案基于稳定基线，不被开发中的脏代码干扰；此时沉淀的知识（若有）应标记 `verified`
- **步骤 4 为分支名唯一推荐点**（feature/ 场景同时产出父分支与孙分支）
- **步骤 4.5 是分水岭**：强制确认已进入 feature 子树（父或孙）；在 master 上试图进入步骤 5 必须阻断并引导切换
- **步骤 5 之后全部在 feature 子树**：所有编码、验证、沉淀均基于 feature/feature_dev 分支；此时沉淀的知识应标记 `pending`（知识跟随分支）
- **分支切换时机**：步骤 4 定稿 → 4.5 之间，由用户执行 `git checkout -b feature/xxx`（及可选的 `git checkout -b feature_dev/xxx/{username}`），禁止 AI 自动切换

### 与 knowledge-loop 的协同

| dev-flow 阶段 | knowledge-loop 行为 |
| --- | --- |
| 步骤 1 检索知识（master 上） | 加载 `verified` + 当前分支匹配的 `pending`（若已在 feature） |
| 步骤 5 加载主题知识（feature 上） | 同上，优先展示 `verified`，`pending` 仅本分支可见 |
| 步骤 7/10 沉淀（feature 上） | 自动标记 `pending` + `created_branch=当前分支` |
| 开始新需求前在 master 上 `git pull`（**最常见，每次都该跑**） | `dev:kb sync` 双场景闭环：①他人改动漂移检测（已有 `verified` 被改 → 降 `stale` + 增量重扫）②自己 pending 升级 verified（feature 已合入则升级）。详见 `knowledge-loop/modes/manage.md` § dev:kb sync |
| feature MR 合入后切回 master 拉取 | 同上（场景 A + B 并存） |

### 特殊场景

- **纯咨询/讨论**：不触发 dev-flow，无分支约束
- **研究性 spike**（仅步骤 1-3，不写代码）：可全程在 master，沉淀的调研知识标记 `verified`
- **hotfix 紧急修复**：从 master 拉 hotfix 分支，遵循同样的"研究在 master / 修复在 hotfix"原则，沉淀先 `pending`，合入后升级 `verified`
- **已提测迭代修复**：在已有 feature 分支上继续，不切回 master

### §7.1 误在错误分支开发后的恢复 SOP

> 📌 单一真相源。解决"改了代码才发现不在自己的分支上"的各类场景，按 Git 状态流水线分四级处理。
> 核心红线：**❌ 禁止用 `git merge` 将公共分支的内容搬入个人分支**——线性关系时 Git 走 fast-forward，会将公共分支上**其他人的 commit** 一起带入个人分支历史。

#### 公共分支定义

含 `-common`/`-shared` 后缀或多开发者共用的 feature 分支（如 `feature/new-split-speaker-common`）。个人开发应在孙分支（`feature_dev/.../<developer>`）上进行。

#### 四级恢复矩阵

| 场景 | Git 状态 | 判别方式 | 恢复步骤 |
|------|---------|---------|---------|
| ① 工作区有改动 | 修改了文件，未 `git add` | `git status` 显示红色 `modified` | `git stash` → 切正确分支 → `git stash pop` |
| ② 暂存区有改动 | 已 `git add`，未 commit | `git status` 显示绿色 `staged` | `git stash` → 切正确分支 → `git stash pop`（stash 默认包含暂存区改动） |
| ③ 已 commit 未 push | commit 在本地，远程无记录 | `git log` 有记录，未推送到远程 | `git cherry-pick <hash>` 到正确分支 → 切回错误分支 `git reset --hard HEAD~N` |
| ④ 已 commit 已 push | commit 已推送到远程 | 远程已有记录 | `git cherry-pick <hash>` 到正确分支 → 切回错误分支 `git revert <hash>` |

#### 场景 ③④ 详细命令

```bash
# ===== 场景 ③：已 commit 未 push =====
# 1. 查看需要搬移的 commit
git log --oneline <错误分支> --not <正确分支>

# 2. 切到正确分支，cherry-pick（按时间从早到晚）
git checkout <正确分支>
git cherry-pick <hash1> <hash2> ...

# 3. 切回错误分支，本地 reset（未 push，安全）
git checkout <错误分支>
git reset --hard HEAD~N   # N = 搬走的 commit 数量

# ===== 场景 ④：已 commit 已 push =====
# 1-2 同上（cherry-pick 到正确分支并 push）
git checkout <正确分支>
git cherry-pick <hash1> <hash2> ...
git push origin <正确分支>

# 3. 切回错误分支，用 revert 还原（安全推荐，保留历史）
git checkout <错误分支>
git revert <hash2> <hash1>   # 按时间从晚到早还原
git push origin <错误分支>
```

#### 合并前检查（防 fast-forward 陷阱）

合并任何非个人分支前，**必须先检查**目标分支上有哪些不属于自己的 commit：

```bash
# 查看目标分支相对于 base 的 commit 列表（按作者标注）
git log --oneline <目标分支> --format="%h %an %s"

# 或对比差异
git log --oneline <目标分支> --not <base分支>
```

> ⚠️ 确认所有 commit 都属于同批上线需求后，才执行 merge 操作。

#### AI 行为指令

- 发现用户在错误分支上开发时，主动提示并按上表推荐恢复方法，**禁止建议 `git merge` 作为搬移方案**
- 提示包含：当前分支 + Git 状态判别 + 推荐命令（完整可复制执行）
