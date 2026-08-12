---
name: dev-flow
description: 面向 AI 辅助编程的系统化开发工作流与代码规范。仅由用户**显式命令**（`dev-flow` / `dev:` / `--micro` / `--fast`）触发或活跃流程相关恢复触发；AI 不基于关键词主观判断自动触发。适用于功能开发、bug 修复、代码优化、样式调整、问题排查等所有代码开发任务。覆盖从需求输入到代码交付的完整生命周期，强制执行最小入侵、根因分析、反模式规避等核心原则。统一流程设计（阶段0+步骤1~10），步骤4由智能评估推荐执行深度（标准/完整/分批）。所有需求均需经过阶段0需求理解+步骤1~3研究分析，确保产出准确性。
keywords: ["开发工作流", "AI辅助编程", "编码规范", "bug修复", "代码优化", "功能开发", "dev-flow"]
---

# 开发工作流

> **分层加载架构**：本文件为精简基线（~130 行），只保留 AI 做触发判断和流程入口所需的最小规则集。
> 详细规范按需加载：遇到复杂场景时 `read_file("references/skill-full.md")` 获取完整版本。

## 触发规则（速查）

> 完整触发规则 → `.compiled/triggers.md`（按需加载）/ `references/skill-full.md`「触发规则」章节
>
> **2026-06-01 改版**：dev-flow 仅支持**显式命令**触发 + **活跃流程相关时恢复**，不再基于关键词主观判断自动触发。

### 触发判定（普通对话 → dev-flow）

| 信号类型 | 关键词/条件 | 行为 |
|---------|-----------|------|
| 显式命令 | `dev-flow` / `dev:` / `/dev-flow` | 进入统一流程 |
| 流程内同步 | `dev:sync` / `dev:s2` | 全量文档同步，支持任意时机调用（按实际文档存在性自动适配；详见 `references/in-flow-sync.md`）|
| 子命令 | `dev:status` / `dev:st` / `dev:kb` / `dev:k` / `dev:metrics` / `dev:m` / `dev:onboard` / `dev:ob` / `dev:flowchart` / `dev:chart` | 对应子命令 |
| 帮助命令 | `dev:help` / `dev:h` / `--help` / `-h` | 加载 `references/help.md`，输出 `<!-- OUTPUT_END -->` 以上的全部内容原文（禁止改写），不进入步骤流程 |
| 帮助一致性检查 | `dev:help --check` | 运行 `scripts/lints/help-consistency.sh`，对比 help.md 与权威源的一致性，不进入步骤流程 |
| 菜单命令 | `dev:ask` / `dev:guide` | 加载 `references/menu.md`，弹出交互式功能菜单。不进入步骤流程，不输出步骤完成标记 JSON |
| 修饰命令 | `--fast` / `--micro`（与基础命令组合） | 修饰层叠加 |
| 活跃流程恢复 | `.active-flows/*.flow` 存在 + 用户消息与 `match_keywords`/`brief` 相关 | v3 智能恢复网关（详见 `flow.md` §「多活跃流程处理」）|
| 开发意图（**不自动触发**） | `修复` / `优化` / `新需求` / `开发 xxx` / 任务平台 / Figma 等 | **AI 在回复中主动建议** `dev-flow` 命令，等待用户决策；不自动调用 `use_skill('dev-flow')` |
| 文档同步关键词 | `同步文档` / `全量同步` / `检查文档` / `更新文档` | 触发 `dev:sync`（.flow 存在→流程内模式，否则→独立模式匹配工作上下文；详见 `references/in-flow-sync.md`）|

**优先级**：用户显式命令 > 活跃流程恢复（相关时） > 普通对话（含开发意图建议）

**强执行规则**：
- 一旦显式命令触发 dev-flow，**严格执行完整流程**，不得以"任务简单"为由跳步
- AI **严禁**基于关键词主观判断自动触发；命中开发意图关键词时，必须在回复中提示 `dev-flow` 命令并等待用户决策
- 用户未用命令但要求改代码（如「直接改」） → 不进入 dev-flow，但仍须遵守 `开发规范-红线.mdc` 的 12 条红线和简化质量检查（详见 `~/.codebuddy/skills/dev-flow/references/no-dev-flow-mode.md`）

### 流程内信号（仅 dev-flow 已激活时生效，不属触发规则）

> 以下信号**仅在 dev-flow 已激活的流程内**生效，普通对话中说这些词**不会触发任何行为**。

| 流程内信号 | 关键词 | 作用 |
|-----------|-------|------|
| 迭代修复 | `提测反馈` / `继续上次需求` / `后端接口好了` | 已有 `.flow` 上下文中切到 `iteration-fix` |
| 批次继续 | `继续下一批` / `batch 2` | `batch_mode=true` 上下文中切批次 |
| 跨项目衔接 | `跨项目修复衔接` / `跨项目验证衔接` | 流程内加载 `cross-project-flow.md` |
| 修饰层切换 | `少问我` / `你决定就好` / `每步都问我` | 已激活流程中调整 `interaction_mode` |
| 需求漂移 | `产品说` / `刚和 XX 对齐` / `需求变了` / `其实是` | 已激活流程中加载 `references/drift-handling.md`（micro-fix 模式豁免）|

## 命令速查

> 完整命令说明 → `.compiled/commands.md`（按需加载）

| 命令 | 快捷 | 说明 |
|------|------|------|
| `dev:sync` | `dev:s2` | 全量文档同步，支持任意时机调用（按实际文档存在性自动适配） |
| `--fast` | — | 精简交互模式（可与任意命令组合） |
| `--micro` | — | 显式启动 micro-fix 模式（单文件 + ≤10 行 + 已知位置的快速修复） |
| `dev:fix --drift` | — | 显式触发需求漂移（完成后自动调用 dev:sync 同步下游文档 + 门控校验） |
| `dev:fix --iteration` | — | 显式触发迭代修复（调 iteration-fix-classify.sh --explicit-trigger iteration） |
| `dev:kb` | `dev:k` | 知识库管理 |
| `dev:status` | `dev:st` | 工作上下文进度概览 |
| `dev:status --trace` | — | 实时观测（Token/红牌/步骤耗时）|
| `dev:metrics` | `dev:m` | 度量查看（支持 --all/--trend/--dashboard） |
| `dev:onboard` | `dev:ob` | 知识库平台 profile 生成/刷新（按需，用户主动触发）|
| `dev:flowchart` | `dev:chart` | 生成/更新 dev-flow 流程图（md + html + png） |
| `dev:ask` | `dev:guide` | 交互式功能菜单（覆盖所有 dev-flow 功能） |
| `dev:help` | `dev:h` | 显示帮助信息（命令/模式/工作流）；`--check` 运行一致性检查 |

## 必要节点 AI 主动弹框提醒（dev:sync 触发表）

> 权威表格。AI 在 dev-flow 流程内的以下节点必须主动调用 `ask_followup_question` 弹出 dev:sync 提醒。
> 详细规则 → `references/in-flow-sync.md` §1.2。
> dev:sync ≠ 5.5b 替代品的单一权威源 → `~/.codebuddy/rules/AI行为规范.mdc` §「主动文档同步弹框提醒」

| # | 触发节点 | 触发条件 | 必弹 | 文档引用 |
|---|---------|---------|:----:|---------|
| 1 | 5.5 静默累计 ≥3 次 | `.flow.silent_55_count ≥ 3`（post-step.sh 物理维护）| ✅ | `references/iteration-fix.md` §四 / `steps/step-5-execute.md` §2.5 |
| 2 | 完整模式步骤 7 完成后追加改动 | `caller=full-7` 完成 + 步骤 8/9/**10** 入口 git diff vs `last_sync_diff_sha` 非空 | ✅ | `steps/step-8-10-full.md` 入口钩子 |
| 3 | drift-handling §步骤 3.5 完成后 | CR 登记后 | 🟡 建议（不阻断）| `references/drift-handling.md` §步骤 3.5 |
| 4 | 跨会话恢复时检测到 `.flow.status=paused_for_sync` | 上次 sync 未完成 | ✅ | `references/in-flow-sync.md` §五 |

**`sync_reminder_disabled: true` 时的处理**：仅对 #1 / #2 静默跳过；#4（恢复未完成的 sync）仍必弹（已经是用户主动召唤过的，需要给出收尾交互）；#3 本就是建议级，无影响。

## 流程加载指令（Prompt Chaining 架构）

| 流程 | 加载文件 |
|------|---------|
| 开发流程 | `read_file("flow.md")` → `read_file("steps/step-router.md")` → 按需加载各步骤 |

**Prompt Chaining 硬性规则**：
- ❌ 禁止一次性加载多个步骤文件
- ❌ 禁止未加载步骤文件就执行该步骤
- ❌ 禁止跳过结构化完成标记 JSON 的输出

## 工作上下文持久化（核心要点）

> 完整规则、命名规则、项目缩写映射表 → `references/working-context.md`（规则单一权威源）
> 完整文件模板（YAML + Markdown 区块） → `references/templates/working-context.tpl.md`（创建新文件前必须加载）

- **创建前**：① `read_file("references/templates/working-context.tpl.md")` 加载模板 → ② `read_file("references/working-context.md")` 查规则（命名/项目缩写/校验）→ ③ **跨项目复用预检**（见下方小节，显式命令入口必经，堵"恢复网关不生效"漏洞）→ ④ `ls` 扫描目录匹配已有文件 → ⑤ 匹配到则更新，未匹配到才创建
- **创建/重命名后**：必须调用 `bash scripts/validate-working-context.sh <文件路径>`，返回非 0 → 禁止继续
- ❌ 禁止不扫描就直接创建 / 禁止同一需求创建多个文件 / 禁止未加载模板就凭记忆创建

### 🆕 跨项目复用预检（显式命令入口堵漏，2026-07-02）

> **设计动机**：v3 智能恢复网关（`references/active-flows.md` §「自动恢复决策逻辑」）**只对非显式命令生效**；用户在 B 项目直接输入 `dev-flow` 会绕过网关，导致 A 项目留下的 `cross_project.status=pending_fix` 工作上下文被遗忘、B 项目另开新文件。本预检**仅**在阶段 0 创建工作上下文前执行一次。

**执行 5 步**（AI 必走，约 1 次 `ls` + 1 次 `head` + 0~1 次 `ask_followup_question`）：

1. `ls ~/.codebuddy/working-context/.active-flows/*.flow 2>/dev/null` 拿活跃锁；空 → 跳到步骤 4 普通匹配
2. 对每个 .flow，对应工作上下文 .md 取 YAML 头（`head -n 40 <name>.md` 找 `cross_project` 块）
3. 命中条件：`cross_project.enabled=true && status=pending_fix` 且当前 workspace 与 `fix_workspace` 一致（或 `fix_workspace` 为空时弹选项让用户确认）
4. 命中 → `ask_followup_question` 弹「🔁 复用工作上下文 / 🆕 新建 / 👀 查看详情」三选项；用户选复用 → 跳到已有上下文路径，**不创建**新文件，按 `references/cross-project/handoff.md` §「衔接后行为」执行阶段 0 增量理解（步骤 1 跳过）
5. 未命中 / 用户选新建 → 继续原流程的步骤 ④ 普通匹配

**反模式**：❌ 跳过本预检直接创建（绕开本规约即视为违反强执行规则） / ❌ 预检中无 `cross_project.enabled=true` 时弹选项（无意义打扰）。

## 步骤切换门控（硬性规则）

> 完整门控规范 → `references/gate-validator.md`
> **🆕 程序化执行入口** → `scripts/hooks/`（PreStepLoad / PostStepComplete 钩子）+ `config/gates.yaml` + `config/hooks.json`

每步骤完成后必须：① 输出结构化完成标记 JSON → ② 更新工作上下文 → ③ 调用 validate-output.sh 机器校验（带 flow-name 参数）→ ④ 门控验证通过（`.validated` 已生成）→ ⑤ 才能加载下一步骤

**🆕 推荐：使用统一钩子入口（替代各类零散调用）**：
```bash
# 步骤完成后（替代直接调 validate-output.sh）：自动跑 validate + doc-platform-lint
bash ~/.codebuddy/skills/dev-flow/scripts/hooks/post-step.sh <step-id> <json-file> <flow-name>

# 加载下一步骤前（替代手动 ls 检查）：自动跑物理检查点白名单 + 步骤 5 加上编码前置硬卡点
bash ~/.codebuddy/skills/dev-flow/scripts/hooks/pre-step.sh <flow-name> <target-step-id>
```

**Schema 机器校验**（兼容旧路径，仍可直接调用）：
```
bash ~/.codebuddy/skills/dev-flow/scripts/validate-output.sh <step-id> <json-file> <flow-name>
```
- **必须**传 `<flow-name>`（从工作上下文文件名去 .md 推导），脚本才会自动 touch `.step-{N}.validated` 物理检查点
- 返回码 0 → 加载下一步骤；≠ 0 → 补齐后重试（详见红牌 #14）
- Schema 文件：`references/schemas/all-steps.schema.json`

## 核心原则（精要）

> §1~§12 由 alwaysApply 规则自动加载。§13~§18 为 dev-flow 扩展层。
> 完整说明 → `.compiled/principles.md` / `references/core-principles.md`

**扩展层（§13~§18）**：不确定就先确认 | 向用户解释 | 深度思考 | 不可变性优先 | 文件≤500行/函数≤80行 | 风格一致性

## 模式矩阵（5 种基础模式 + 1 种修饰层）

> 完整矩阵 → `references/mode-matrix.md`

- **基础模式**（mode，互斥单选）：`standard` / `full` / `iteration-fix` / `batch` / `cross-project` + `micro-fix`（轻量快速修复专项模式）
- **修饰层**（interaction_mode，正交叠加）：`streamlined`（启用后仅调节交互频率，不改变基础模式）

遇到模式冲突或不确定时 → `read_file("references/mode-matrix.md")`

## 按需加载索引

> 遇到对应场景时加载，不提前加载

| 场景 | 加载文件 |
|------|---------|
| 触发规则边界情况 | `.compiled/triggers.md` |
| 交互式功能菜单 | `references/menu.md` |
| 帮助/命令查询 | `references/help.md` |
| 帮助一致性检查 | `scripts/lints/help-consistency.sh` |
| 命令详细说明 | `.compiled/commands.md` |
| 核心原则详细说明 | `.compiled/principles.md` / `references/core-principles.md` |
| 模式切换/冲突 | `references/mode-matrix.md` |
| 工作上下文创建 | `references/working-context.md` |
| 迭代修复 | `references/iteration-fix.md` |
| 跨项目联调 | `references/cross-project-flow.md` |
| Figma 设计稿 | `references/figma-flow.md` |
| 技术方案文档 | `references/tech-proposal-flow.md` |
| 精简交互模式 | `references/interaction-mode.md` |
| Token 紧张 | `references/token-management.md` |
| 对话质量守卫（长对话/预警） | `references/conversation-quality.md` |
| 需求漂移（沟通回流/方案否定/澄清调整） | `references/doc-sync-rules.md` → `references/drift-handling.md` |
| 并行执行策略 | `references/shared-rules.md` §3 |
| Git 分支规范 | `references/shared-rules.md` §6 |
| Commit 生成 | `references/shared-rules.md` §1 → `use_skill('smart-commit')` |
| 知识库管理 | `use_skill('knowledge-loop')` |
| 浏览器工具选型/UI 调试/性能分析 | `use_skill('browser-toolkit')` |
| 知识库平台 外援（默认沉默，仅在信号命中时触发）| `references/remote-knowledge.md`（单一权威源：信号定义 + 项目映射 + Token 策略 + 噪声过滤）/ `references/onboard-flow.md`（profile 生命周期）|
| 完整 SKILL 规范 | `references/skill-full.md` |
| 🆕 程序化校验脚本（lints） | `scripts/lints/{path,interactive-options,devlog-dir-name,doc-platform}-lint.sh` |
| 🆕 程序化前置校验（precheck） | `scripts/precheck/{physical-checkpoint,step5-precheck}.sh` |
| 🆕 步骤前后统一钩子 | `scripts/hooks/{pre-step,post-step}.sh` |
| 🆕 状态机查询 | `scripts/state-machine.sh --query-next/--query-step7-variant/--list-steps` |
| 🆕 门控规则单一权威源 | `config/gates.yaml` |
| 🆕 Hook 注册表 | `config/hooks.json` |

## help.md 一致性维护规则

> 权威源文件（SKILL.md / mode-matrix.md / step-router.md）与 `references/help.md` 之间存在手工维护的信息冗余。修改权威源后 help.md 不会自动更新，需主动检查。

### 被动提醒（AI 自动执行）

当对话中**非 dev-flow 流程内**修改了以下文件时，AI 必须在回复末尾主动提醒：
- `SKILL.md`
- `references/mode-matrix.md`
- `steps/step-router.md`

提醒格式：`💡 提醒：help.md 可能与权威源存在不一致，建议运行 \`dev:help --check\` 检查。`

- ❌ 禁止在 dev-flow 流程中触发（与开发无关）
- ❌ 禁止自动执行检查或自动修改 help.md
- ✅ 仅在修改权威源文件后提醒一次

### 已知结构性差异（非错误）

以下差异是 help.md 与权威源之间的设计差异，`help-consistency.sh` 会报告但**不需要修正**：

| 检查项 | 差异 | 原因 |
|--------|------|------|
| cmd_detail | 13 vs 15 | CMD_DETAIL 额外收录了流程内信号命令（--drift, --iteration）和 dev:help 自身 |
| steps | 知识库检查 | 步骤 0.5 仅存在于 mode-matrix.md，step-router.md 流程总览表不包含 |
| steps | L3审查 | help.md 使用简化名"L3审查"，router 使用全名"L3 代码审查" |
| triggers | 刚和 XX 对齐 vs 对齐了 | help.md 添加了口语化"了"字，不影响触发 |

## 其他规则

- **Skill 优先级**：用户级 Skill 优先于项目级同名 Skill
- **dev-flow 优先级**：「需求开发」= 写代码，文档类规则在 dev-flow 执行期间自动失效
- **冲突时**：dev-flow 胜出
- **Skill 自动发现**：步骤×Skill 匹配表 → `references/shared-rules.md` §5

## 关键红线（不可省略）

- ❌ **禁止自动 `git commit`**：commit message 仅生成，除非用户明确选择「📦 确认并提交」才执行
- ❌ **必须调用 `smart-commit`**：禁止 AI 自行拼写 commit message（详见红牌 #12）
- ❌ **dev-logs 目录命名四项 lint**：步骤 4 创建 `~/.codebuddy/dev-logs/` 目录时，`name_lint` 四项（format_matched / type_valid / brief_has_chinese / no_project_suffix）必须全为 true，任一失败即 🔴 Block
- ❌ **先搜索后编码**：新增工具函数/组件/Hook 前必须先 `codebase_search` 确认无已有实现
- ❌ **步骤完成必须经机器校验**（v2 硬化 2026-04-30）：每个步骤完成标记 JSON 输出后，**必须**立即调用 `scripts/validate-output.sh <step-id> <json-file> <flow-name>` 脚本；脚本返回码非 0 或未触发 `.step-{N}.validated` 物理检查点 → 🔴 红牌 #14，禁止加载下一步骤。AI 不得自行 `touch` `.validated` 伪造通过。详见 `steps/step-router.md` §「🔐 物理检查点机制」和 `references/gate-validator.md` §「校验时机（v2 硬化版）」
