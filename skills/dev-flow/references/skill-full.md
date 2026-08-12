---
name: dev-flow
description: 面向 AI 辅助编程的系统化开发工作流与代码规范。仅由用户**显式命令**（`dev-flow` / `dev:` / `--micro` / `--fast`）触发或活跃流程相关恢复触发；AI 不基于关键词主观判断自动触发。适用于功能开发、bug 修复、代码优化、样式调整、问题排查等所有代码开发任务。覆盖从需求输入到代码交付的完整生命周期，强制执行最小入侵、根因分析、反模式规避等核心原则。统一流程设计（阶段0+步骤1~10），步骤4由智能评估推荐执行深度（标准/完整/分批）。所有需求均需经过阶段0需求理解+步骤1~3研究分析，确保产出准确性。
---

# 开发工作流

面向 AI 辅助编程的系统化开发工作流与代码规范。本规范为最高优先级，必须严格遵守。

## 统一流程设计

> **核心理念**：产出准确性是第一优先级。所有需求（无论大小）走同一条流程：阶段0（需求理解）→ 步骤1~3（研究→范围→方案）→ 步骤4（智能评估推荐执行深度）→ 执行。不再区分"快速模式"和"完整模式"，所有入口（`dev-flow` / `dev:`）等价进入统一流程，执行深度完全由步骤4基于研究成果智能评估推荐，用户可覆盖。

### 触发规则

> **2026-06-01 改版**：dev-flow 仅由**显式命令**触发或**活跃流程相关恢复**触发，AI 不再基于关键词主观判断自动触发。
> 单一权威源：`SKILL.md` §「触发规则」 + `.compiled/triggers.md` + `~/.codebuddy/rules/AI行为规范.mdc` §「Skill 触发检查」。

#### 1. 显式触发（命中即 `use_skill('dev-flow')`）

| 用户输入 | 行为 |
| --- | --- |
| `dev-flow` / `dev:` / `/dev-flow` | 进入统一流程，步骤4智能评估推荐执行深度 |
| `dev:kb` / `dev:k` | 知识库管理 → `use_skill('knowledge-loop')` |
| `dev:status` / `dev:st` | 工作上下文进度概览 |
| `dev:metrics` / `dev:m`（含 `--all` / `--trend` / `--report {ID}` / `--dashboard`） | 度量查看 |
| `dev:onboard` / `dev:ob` | 知识库平台 profile 生成/刷新 |
| `dev:flowchart` / `dev:chart` | 生成/更新 dev-flow 流程图（md + html + png） |
| `dev:ask` / `dev:guide` | 交互式功能菜单。加载 `references/menu.md`，弹出分类菜单，不进入步骤流程 |
| `dev:help` / `dev:h` | 显示帮助信息。加载 `references/help.md`，不进入步骤流程 |
| `--fast`（与基础命令组合） | 修饰层：精简交互模式 |
| `--micro`（与基础命令组合） | 基础模式：micro-fix（需满足阈值） |

> **命令规范**：
| > | 命令 | 快捷 | 说明 |
| > |------|------|------|
| > | `--fast` | — | 附加精简交互模式（减少交互次数，可与任意命令组合） |
| > | `dev:kb` | `dev:k` | 知识库管理（查看/沉淀/扫描/搜索项目知识库） |
| > | `dev:status` | `dev:st` | 状态查看（当前工作上下文进度概览） |
| > | `dev:metrics` | `dev:m` | 度量查看（最近5次/全部/趋势/指定需求/仪表盘） |
| > | `dev:onboard` | `dev:ob` | 知识库平台 profile 生成/刷新/校验（L0 缓存）|
| > | `dev:flowchart` | `dev:chart` | 生成/更新 dev-flow 流程图（md + html + png） |
> `dev:` 前缀加不加 `/` 均可识别。`/dev-flow` 和 `dev-flow` 完全等价。
> **命令执行规范**：
>
> #### `dev:kb` / `dev:k`
>
> 1. 确定当前项目名称（从最近的工作上下文或项目目录推断）
> 2. `ls ~/.codebuddy/knowledge/{project-name}/` 列出已有知识
> 3. 展示知识清单（模块名+覆盖主题+置信度+最后验证日期），弹出交互式选项：查看模块 / 扫描代码 / 检查健康度 / 搜索 / 返回
> 4. 详细操作规则 → `use_skill('knowledge-loop')` 管理模式
>
> #### `dev:status` / `dev:st`
>
> 1. `ls ~/.codebuddy/working-context/.active-flows/` 扫描活跃流程
> 2. `ls ~/.codebuddy/working-context/` 扫描工作上下文
> 3. 展示：活跃需求清单（brief+当前步骤+模式+最后活跃时间）
> 4. 展示：暂停需求清单（如有）
> 5. 展示：最近完成的需求（最近3个，按文件修改时间排序）
>
> #### `dev:metrics` / `dev:m`
>
> 按 `references/metrics-rules.md`「用户命令」章节执行。支持 `--all`（全部历史）、`--trend`（趋势）、`--report {需求ID}`（指定需求）、`--dashboard`（生成并打开可视化仪表盘）。
>
> #### `dev:onboard` / `dev:ob`
>
> 1. 识别当前项目（参数 `--project=<name>` > 工作上下文 > `pwd` 推断）
> 2. 读取 `references/remote-knowledge.md` 项目映射表（§二），未命中则提示"项目未接入 知识库平台"并退出
> 3. 解析参数：无参数→智能判断；`--refresh`/`-r`→全量刷新；`--refresh-recent`/`-rr`→增量刷新；`--check`/`-c`→只校验不刷新
> 4. 详细执行规范与 profile 新鲜度机制 → 读取 `references/onboard-flow.md`
>
> #### `dev:flowchart` / `dev:chart`
>
> 1. 读取 `flowchart/SPEC.md` 获取版本信息 + 生成规范 + 模板
> 2. 读取 `flowchart/README.md` 获取当前版本号
> 3. 弹出交互式选项：选择更新方式（覆盖当前版本 / 另存新版本 / 取消）
> 4. 按 SPEC.md §3 模板规范生成 `flowchart.md`（Mermaid 源码）
> 5. 交互确认 flowchart.md 内容无误
> 6. 按 SPEC.md §4 模板规范生成 `flowchart.html`
> 7. Chrome headless 截图生成 `flowchart.png`
> 8. 可选：生成 `flowchart.svg`（需 mmdc）
> 9. 若选「另存新版本」→ 更新 `flowchart/README.md` 版本信息
>
> > 完整生成 Pipeline、Mermaid 规范、HTML 模板、CSS 变量 → `flowchart/SPEC.md`
>
> #### `dev:help` / `dev:h`
>
> 1. `read_file("references/help.md")` 加载帮助内容
> 2. 若带参数（如 `dev:help --micro`），从「命令详情」节定位对应条目输出
> 3. 格式化输出，不创建工作上下文，不进入步骤流程

#### 2. 活跃流程恢复（自动触发，须双条件）

`~/.codebuddy/working-context/.active-flows/{name}.flow` 存在 **且** 用户消息内容与该 `.flow` 的 `match_keywords` / `brief` **相关**
→ `use_skill('dev-flow')` → 走 v3 智能恢复网关（详见 `flow.md` §「启动模式识别」）。

> 不相关时（如纯咨询、元讨论、其他需求）→ **不触发恢复**，普通对话推进。

#### 3. 开发意图关键词（**不自动触发**，AI 主动建议）

检测到以下开发意图关键词时，**AI 不得自动调用 `use_skill('dev-flow')`**：

- 开发：`新需求` / `需求开发` / `开发 xxx` / 任务平台 链接 / Figma 链接 / 含需求单格式内容
- 修复：`修复` / `解决` / `优化` / `调整` / `排查` / `重构` / `帮我改下` / `fix`
- 收尾：`收尾` / `汇总改动` / `生成 commit`

**处理方式**：

1. 在回复中**主动建议一句**：「检测到开发意图，建议输入 `dev-flow` 走完整流程，或直接说『直接改』我会按红线规范处理」
2. **等待用户决策**，不自动进入 dev-flow，也不自动开始改代码
3. 用户回复「直接改」 / 「不用走流程」 → 按 `~/.codebuddy/skills/dev-flow/references/no-dev-flow-mode.md` 执行（仍须遵守 `开发规范-红线.mdc` 12 条核心红线 + 前端编码底线）

#### 4. 优先级

```text
用户显式 dev-flow 命令
> 活跃流程恢复（相关时）
> issue-trace
> 普通对话（含开发意图建议）

```

#### 5. 流程内信号（仅 dev-flow 已激活时生效）

> 以下信号**仅在 dev-flow 已经触发后**的流程内部生效，不属于"触发规则"。普通对话（dev-flow 未激活）时说这些词**不会触发任何行为**。

- **迭代修复**：`提测反馈了几个问题` / `测试提了 bug` / `继续上次的需求` / `后端接口好了` → 在已有 `.flow` 上下文中切换到 `iteration-fix` 模式（详见 `references/iteration-fix.md`）
- **批次继续**：`继续下一批` / `执行下一个批次` / `batch 2` → 在 `batch_mode: true && status: batch_in_progress` 上下文中切换批次（详见 `references/iteration-fix.md` §「批次切换」）
- **跨项目衔接**：`跨项目修复衔接` / `跨项目验证衔接` / 含"来源+工作上下文+根因"结构化 prompt → 在 dev-flow 流程内加载 `references/cross-project-flow.md`
- **修饰层切换**：`少问我` / `你决定就好` / `每步都问我` / `我要确认` → 在已激活流程中调整 `interaction_mode`（详见 `references/interaction-mode.md`）
- **micro-fix 辅助描述**：`改个错别字` / `这里少个分号` / `{文件}:{行号}` → 仅作为 `--micro` 命令的位置描述辅助（详见 `references/mode-matrix.md` §三bis）

> ⚠️ **强制规则**：上述自然语言信号**不能单独触发 dev-flow**。用户须先用 `dev-flow` / `dev:` / `--micro` 等显式命令进入 dev-flow，或命中活跃流程恢复，才会进入这些子流程。

#### 6. 反绕过 & 强执行规则

- 一旦显式命令触发 dev-flow，**严格执行完整流程**，不得以"任务简单"为由跳步。复杂度评估是步骤 4 的职责
- 步骤不可跳过：dev-flow 触发后，每个步骤必须按顺序执行
- AI **严禁**基于关键词主观判断自动触发；命中开发意图关键词时必须先建议 `dev-flow` 命令
- 触发判断可观测性：消息含明显开发意图但 AI 未触发 dev-flow 时，必须在回复中**显式提示用户**有 `dev-flow` 命令可用

### 流程加载指令（Prompt Chaining 架构）

**触发 dev-flow 后，统一加载流程定义文件**：

| 流程 | 加载文件 | 架构说明 |
| --- | --- | --- |
| 开发流程 | `read_file("flow.md")` | L0 路由层（~340行），含阶段0+步骤1~10，步骤详细规范按需从 `steps/` 目录逐步加载 |

**Prompt Chaining 执行协议**（开发流程）：

1. 加载 `flow.md` 后，先 `read_file("steps/step-router.md")` 加载步骤路由器
2. 每个步骤开始时：`read_file("steps/step-N-xxx.md")` 加载该步骤的详细规范
3. 每个步骤完成后：输出结构化完成标记 JSON → 更新工作上下文 → 门控验证
4. 门控通过后才能加载下一步骤文件
5. 步骤 4 选择执行深度后，标准执行在步骤 7 结束，完整执行继续到步骤 10
6. ❌ 禁止一次性加载多个步骤文件
7. ❌ 禁止在未加载步骤文件的情况下执行该步骤
8. ❌ 禁止跳过结构化完成标记 JSON 的输出

## 工作上下文持久化

完整模板、字段说明、命名规则、创建/更新决策流程详见 `references/working-context.md`；活跃流程注册目录（`.active-flows/`）已拆出至 `references/active-flows.md`。

### 核心要点

- **文件位置**：`~/.codebuddy/working-context/{YYYYMMDD}_{需求简述}_{项目缩写}.md`
  - 单项目：项目缩写按映射表取值（如 `myProject`）
  - 跨项目：项目缩写统一使用 `crossProject`（见 `references/cross-project-flow.md` §三）
- **创建前检查（强制）**：先 `ls` 扫描目录 → 按关键词/任务 ID/分支名匹配 → 匹配到则更新，未匹配到则创建
- **写入时机**：阶段 0 写需求、用户纠正写约束、步骤 3 写计划、每步骤完成更新进度
- **读取时机**：每个步骤开始前必须先读取。优先级：约束与决策 > 计划 > 范围 > 进度 > 需求
- **创建时**：`read_file("references/working-context.md")` 加载完整模板
- ❌ 禁止不扫描目录就直接创建新文件
- ❌ 禁止同一需求创建多个文件

### 步骤切换门控（硬性规则，不可跳过）

步骤 N 完成后，必须先通过门控检查，才能进入步骤 N+1。门控未通过则阻塞。

**门控检查清单**（每次步骤切换时强制执行）：

1. **结构化完成标记已输出**：当前步骤的完成标记 JSON 已输出
2. **进度已更新**：步骤清单中当前步骤状态已更新
3. **当前状态已刷新**：`## 进度 > 当前状态` 已覆盖更新为下一步骤
4. **恢复指令已刷新**：`## 进度 > 恢复指令` 已覆盖更新

门控为静默执行，仅在失败需要补更新时才产生额外动作。详见 `references/gate-validator.md`。

### 跨会话恢复审计（强制）

新会话中首次读取工作上下文后，必须先审计步骤清单（检查 ⚠️/❌ 标记），按恢复指令确定继续点。

### 跨会话 devlog 同步检查

读取工作上下文后，如发现已完成的轮次但 devlog 缺少对应 Round 记录 → 在收尾阶段补全。静默执行。

## dev-flow 优先级与排除规则

1. **「需求开发」= 写代码**，而非编写技术文档
2. 文档类规则在 dev-flow 执行期间自动失效（除非用户明确要求）
3. 参考文档是参考资料，不是创建指令
4. 冲突时 dev-flow 胜出

## Git 分支命名规范

详见 `references/shared-rules.md` §6。精要：`feature/` 新功能、`bugfix/` 修复、`feature_dev/<功能>/<开发者>` 孙分支；命名 ≤3 单词、小写短横线连接（禁驼峰/禁下划线）。
流程中两个触点：
① 阶段 0 仅当用户主动告知时记录 `branch_user_specified`（AI 不预告）
② **步骤 4 §4.1 唯一定稿**（计划锁定后、磁盘保存前，feature/ 场景同时推荐父+孙分支）
③ 步骤 4.5 **纯校验**（读取工作上下文 `branch` + `branch_dev`，父孙分支视为等价匹配）。

## AI 助手操作红线

见「开发规范-红线」操作红线章节（alwaysApply，每次对话已自动加载）。

## Skill 优先级规则

用户级 skill（`~/.codebuddy/skills/`）优先于项目级同名 skill。

## 核心原则（18 条）

> §1~§12 对应「开发规范-红线」的 12 条核心原则（alwaysApply，每次对话已自动加载）。§13~§18 为 dev-flow 补充原则，在 dev-flow 执行期间与红线等效。

**红线层（§1~§12，alwaysApply）**：需求理解优先 | 最小入侵 | 兼容性优先 | 根因定位与验证闭环 | 安全底线 | 副作用清理 | 边界条件与防御性编码 | 异步与竞态安全 | 错误处理 | 先搜索后编码 | 主动思考更优方案 | 上下文管理

**dev-flow 扩展层（§13~§18）**：不确定就先确认 | 向用户解释 | 深度思考 | 不可变性优先 | 文件与函数大小约束 | 风格一致性

> 💡 各原则的详细说明与示例 → `read_file("references/core-principles.md")`（按需查阅，日常执行参照上方精要即可）

## 交互模式（精简交互）

支持标准模式（默认）和精简模式（仅关键决策点暂停）。精简模式按风险等级分级处理。详见 `references/interaction-mode.md`。

## 并行执行策略（环境感知多模式）

首次并行调度前执行平台能力检测，根据检测结果自动选择执行模式：

- **模式 A（并行工具调用）**：单 Agent 环境默认模式，通过并行工具调用实现任务并行，角色标注仅作思维引导
- **模式 B（多 Agent 协作）**：Claude Code / WorkBuddy / OpenClaw 等支持独立 Agent 实例的环境，完整角色定义生效
- **CodeBuddy 子代理模式**：通过 `Task` 工具调用 `agents/` 下的自定义 Agent（1号~9号），子 Agent 只读，写入由主 Agent 串行执行

检测规则（含 CodeBuddy 检测项）、调度策略、成本感知、结果冲突检测、角色定义、防误判规则详见 `references/shared-rules.md` §3。

## Skill 自动发现（借鉴 Superpowers）

> 核心理念：哪怕只有 1% 的可能性某个 Skill 能帮助当前任务，也应该主动检查并调用。

完整的步骤×Skill 匹配表详见 `references/shared-rules.md` §5（单一真相源）。

静默评估，主动建议，不阻塞主流程，已在上下文中的 Skill 不重复加载。

## Commit Message 生成

详见 `references/shared-rules.md` §1。精要：

1. 复用检查（工作上下文 `## 交付` 区块）→ 2. 调用 `use_skill('smart-commit')` → 3. 用户确认（✅确认/✏️修改/🔄重新生成/📦确认并提交）→ 4. 持久化到工作上下文

| 模式 | 触发位置 |
| --- | --- |
| 标准执行 | 步骤 7（清理+Commit）/ 步骤 6C 暂存场景 |
| 完整执行 | 步骤 10（归档与交付） |

仅生成，❌ 禁止自动执行 `git commit`（除非用户选择「📦 确认并提交」）。格式：`<type>: <description>`（无 scope）

## 对话窗口 Token 管理

对话中后期按需加载 → `read_file("references/token-management.md")`。核心：>15 轮主动压缩，>25 轮强制精简。

## 开发日志

详见 `references/devlog-rules.md`（按需加载）。

## 项目知识库（Project Knowledge Base）

调用 `use_skill('knowledge-loop')` 管理项目级应用知识库（`~/.codebuddy/knowledge/`）。
支持检索模式（步骤1/5）、沉淀模式（步骤7/10/收尾）、管理模式（`dev:kb` 命令集）。
详见独立 Skill `knowledge-loop`。

## 知识库平台 知识库（MCP，项目级权威）

与本地 `knowledge-loop` 互补：本地是 AI 的"肌肉记忆"（易错点/坑），知识库平台 是项目的"全景地图"（源码/架构 wiki/commit/MR）。

### v2 节点信号触达（替代 v1 CACHE 档位驱动）

知识库平台 定位为**节点级外援**而非默认加载的知识源，遵循"按节点按需触达 + 按数据类型精选"：

- **本地 profile**（零 MCP）：`~/.codebuddy/knowledge/{project}/_profile.md`，`dev:onboard` 生成，阶段 0.5 仅在本地 profile 存在且未过期时注入
- **有域检索**（传 `search_domain`）：信号 1/2/3/5 命中时用于限定当前项目
- **全库检索**（不传 `search_domain`）：信号 4 跨项目联调专用

完整节点触达策略与收益量化 → `references/remote-knowledge.md` §三 / §六

### 配置与触发

- **项目映射表**：`references/remote-knowledge.md` §二（必须已注册才能启用，未注册则静默跳过）
- **节点信号与 CLI 覆盖**：`references/remote-knowledge.md` §一 / §四 4.3（v2 信号驱动：信号 1首次接触陌生模块 / 信号 2历史 MR / 信号 3bugfix 踩坑 / 信号 4跨项目 / 信号 5commit 风格，默认沉默）
- **profile 生命周期**：`references/onboard-flow.md`（新鲜度、漂移检测、3 档刷新粒度、10 个兼容场景）

### 挂载点

- **阶段 0.5（项目画像轻量注入）**：v2 默认沉默；仅当本地 `_profile.md` 存在且未过期时读取注入，0 MCP 调用
- **步骤 1（研究定位）**：默认纯本地检索；仅命中信号 1（首次接触陌生模块）或信号 4（跨项目联调）时触发 MCP
- **步骤 3（制定方案）**：仅命中信号 2（需求含扩展类动词且项目接入 知识库平台）时拉取历史类似 MR 作方案参考
- **步骤 9（反思与学习）**：仅命中信号 3（need_type=bugfix）时查 git_doc_platform 常见问题/历史坑

### 降级与来源标注

- **降级策略**：本轮对话内失败即跳过，不做持久化熔断；本地流程是稳定底线
- **来源标注**：步骤 1 表格必须标注 `[local]/[remote-kb/git]/[remote-kb/wiki]/[remote-kb/commit]/[knowledge]` 等来源标签
- **交叉验证**：MCP 命中的文件路径必须用 `read_file` 验证真实存在（防索引延迟）

## 跨项目联调（Cross-Project Flow）

当修复目标不在当前项目时（如组件库 bug 需要在组件库仓库修复，再回消费方项目验证），自动触发跨项目流程。
详见 `references/cross-project-flow.md`（按需加载）。

**挂载点**：

- **步骤 2（范围确认）**：检测到修改目标不在当前 workspace → 标记 `cross_project`，生成 B 项目衔接 prompt
- **步骤 6C（联调）**：检测到 `cross_project` 标记 → 扩展为跨项目联调选项，生成 A 项目验证 prompt
- **B 项目新对话**：识别衔接 prompt → 从 A 项目工作上下文继承根因和方案，跳过重复研究

**不动主干**：不新增步骤编号，通过钩子在已有节点按需触发，非跨项目场景零开销。

## 迭代修复机制

检测到迭代修复信号后 → `read_file("references/iteration-fix.md")` 加载完整流程。
触发条件：匹配到已有工作上下文 + 进度显示上一轮已完成。

## Figma 设计稿处理流程

用户提供 Figma 链接时 → `read_file("references/figma-flow.md")` 加载完整处理流程。

## 文档同步

详见 `references/doc-sync-rules.md`（按需加载）。

## 技术方案文档生成/更新

完整流程详见 `references/tech-proposal-flow.md`。核心：已有则更新，没有才新建。

## 专题规范

遇到对应场景时 → `read_file("references/topic-specs.md")` 加载完整专题规范查找表。

## 模式矩阵（6 种基础模式 + 1 种修饰层）

dev-flow 采用**两个独立维度**描述执行状态：

- **基础模式**（`mode`，互斥单选）：`standard` / `full` / `iteration-fix` / `batch` / `cross-project`；另设专项轻量模式 `micro-fix`（适用于 ≤3 文件对称修改 + ≤10 行/文件 + 已知位置的快速修复）
- **修饰层**（`interaction_mode`，正交叠加在任一基础模式之上）：`streamlined`（仅调节交互频率，不改变步骤覆盖、reference 加载或输出 schema）

当 AI 不确定当前模式、多模式信号冲突、或用户询问模式切换规则时
→ `read_file("references/mode-matrix.md")` 加载单一真相源（含模式分类表 + 决策树 + 步骤覆盖矩阵 + micro-fix 专项说明 §三bis + 修饰层详规 §九 + 优先级规则）。
