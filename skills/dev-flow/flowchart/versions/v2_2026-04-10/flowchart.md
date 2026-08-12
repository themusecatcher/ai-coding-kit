# dev-flow 完整流程图

> 静态 Mermaid 版本，可在 GitHub / IDE 中直接渲染预览。
> 交互式版本（支持点击跳转到源文件）：[flowchart.html](./flowchart.html)

### v1 → v2 核心变更（2026-04-10）

> **统一流程重构**：v2 移除了 v1 的四模式设计（完整/快速/极速/收尾），改为「单一流程 + 智能评估」架构。
> 核心变更点：
>
> - **入口统一**：所有入口（`dev-flow` / `dev:` / 隐式触发）等价进入统一流程，不再预设执行深度
> - **智能评估**：步骤4 基于步骤1~3 的研究成果（改动范围/复杂度/风险等级）自动推荐执行深度，用户可覆盖
> - **执行深度二分**：标准执行（步骤5→7，步骤7含全部环节A~J）和完整执行（步骤5→10，步骤7裁剪到G）
> - **新增环节J**：经验快检（3问快检机制，借鉴 MemPalace Agent Diary 的模式识别）
> - **Prompt Chaining 架构**：步骤规范拆分到独立文件，按需加载，每次只加载一个步骤，通过门控验证串联
> - **分级钩子**：🔴重量级/🟡中量级/🟢轻量级三级，减少轻量步骤的 Token 开销
> - **原子状态同步**：工作上下文更新和 .flow 文件更新合并为一次操作，减少 IO
> - **状态快照**：关键步骤（3/5/6）自动创建快照，支持回退到特定步骤状态
> - **交互式决策强制规则**：所有决策点必须「文本选项列表 + ask_followup_question」双重展示

---

## 1. 入口触发与模式路由

> **设计理念**：v2 将所有开发类触发统一路由到同一条流程，消除了 v1 中用户需要选择模式的认知负担。
> 收尾模式保留为独立入口（代码已改完，只需汇总+commit），其余所有入口等价。

**命令速查**（`dev:` 前缀，加不加 `/` 均可识别）：

| 命令 | 快捷 | 说明 |
| --- | --- | --- |
| `dev-flow` / `dev:` | — | 进入统一流程 |
| `--fast` | — | 附加精简交互模式（减少交互次数） |
| `dev:wrap` | `dev:w` | 收尾模式（汇总改动+commit） |
| `dev:specs` | `dev:s` | 规范管理（查看/沉淀/搜索项目规范） |
| `dev:status` | `dev:st` | 状态查看（当前工作上下文进度概览） |
| `dev:metrics` | `dev:m` | 度量查看（最近5次/全部/趋势/指定需求） |

```mermaid
flowchart TD
A["🗣️ 用户消息"] --> B{"关键词匹配?"}
B -->|"dev-flow / dev: / 开发流程"| C["🔄 统一流程"]
B -->|"新需求 / 任务平台 / Figma / 开发xxx"| C
B -->|"修复 / 优化 / 调整 / 排查 / 重构"| C
B -->|"dev:wrap / 收尾 / 生成commit"| E["📦 收尾模式"]
B -->|"dev:specs"| F["📐 规范管理"]
B -->|"dev:status"| G["📊 状态查看"]
B -->|"dev:metrics"| GM["📈 度量查看"]
B -->|"未匹配"| H{"检查 .active-flows/"}
H -->|"0个活跃"| I["💬 普通对话"]
H -->|"1个活跃"| J["🔄 自动恢复"]
H -->|"≥2个活跃"| K["📋 展示清单让用户选"]
C --> N{"迭代修复信号?"}
N -->|"是"| O["匹配已有工作上下文"]
O --> Q{"匹配到?"}
N -->|"否"| P["创建/读取工作上下文"]
Q -->|"是"| R["迭代修复评估"]
Q -->|"否"| P
R --> RD{"用户确认"}
RD -->|"按建议执行"| RM{"复杂度?"}
RD -->|"调整范围"| R
RD -->|"取消"| CANCEL["❌ 终止"]
RM -->|"简单/中等"| STD["标准执行（增量）"]
RM -->|"重大"| FULL["完整执行（增量）"]
P --> FLOW["进入统一流程<br/>阶段0 → 步骤1~4"]

classDef unified fill:#1e1b4b,stroke:#4338ca,color:#e0e7ff
classDef wrapup fill:#1c1917,stroke:#78716c,color:#e7e5e4
classDef cmd fill:#0f172a,stroke:#334155,color:#94a3b8
classDef iter fill:#1a2e05,stroke:#4d7c0f,color:#d9f99d
class C,FLOW unified
class E wrapup
class F,G,GM cmd
class R,RD,RM,STD,FULL iter```

> **统一流程设计**：所有需求（无论大小）走同一条流程：阶段0 → 步骤1~3 → 步骤4（智能评估推荐执行深度）→ 执行。
> 不再区分"快速模式"和"完整模式"入口，所有入口等价。
> 优先级：用户显式指定 > 收尾关键词 > 开发流程信号 > 默认进入统一流程
> **活跃流程恢复**：未匹配关键词时，自动检查 `.active-flows/` 目录，1个活跃需求自动恢复，≥2个展示清单让用户选。

---

## 2. 统一流程总览（阶段0 + 步骤1~10）

> **v1→v2 核心重构**：v1 有四条独立流程路径（完整/快速/极速/收尾），v2 合并为一条统一流程。
> 所有需求都走阶段0→步骤1~3的完整研究分析，确保产出准确性。执行深度不在入口决定，而是在步骤4由AI基于研究成果智能评估推荐。

**流程总览表**（步骤名称以 step-router.md 为准）：

| 步骤 | 名称 | 加载文件 | 核心产出 | 执行深度 |
| --- | --- | --- | --- | --- |
| 0 | 需求理解 | `use_skill("requirement-intake")` | 需求确认 + 分支建议 | 全部 |
| 1 | 研究与定位 | `steps/step-1-research.md` | 相关文件表格 | 全部 |
| 2 | 确认范围 | `steps/step-2-scope.md` | 影响范围报告 + 用户确认 | 全部 |
| 3 | 制定方案 | `steps/step-3-plan.md` | 执行计划表格 | 全部 |
| 4 | 方案汇报与用户决策 | `steps/step-4-decision.md` | 评估卡片+执行深度选择 | 全部 |
| 4.5 | 环境检查 | `steps/step-4.5-env-check.md` | 分支确认 | 全部 |
| 5 | 执行修改 | `steps/step-5-execute.md` | 代码改动 | 全部 |
| 5.5 | 编码后置钩子 | `steps/step-5.5-post-coding.md` | L1审查+文档同步+自检 | 全部 |
| 6 | 质量验证 | `steps/step-6-verify.md` | 验证报告（6A/6B/6C） | 全部 |
| 7 | 清理+Commit | `steps/step-7-commit.md` | L2审查+commit+devlog | 全部 |
| 8 | L3 代码审查 | `steps/step-8-10-full.md` | L3多视角深度审查 | 仅完整执行 |
| 9 | 反思与学习 | `steps/step-8-10-full.md` | 度量报告+经验提炼 | 仅完整执行 |
| 10 | 归档与交付 | `steps/step-8-10-full.md` | commit+devlog+specs+交付报告 | 仅完整执行 |

```
flowchart TD
S0["🎯 阶段0：需求理解"]
S1["🔍 步骤1：研究与定位"]
S2["📐 步骤2：确认范围"]
S3["📝 步骤3：制定方案"]
S4["🤝 步骤4：方案汇报与用户决策"]
S45["🔧 步骤4.5：环境检查"]
S5["⚙️ 步骤5：执行修改"]
S55["🔬 步骤5.5：编码后置钩子"]
S6["✅ 步骤6：质量验证"]
S7["🧹 步骤7：清理+Commit"]
S8["🔎 步骤8：L3代码审查 ★"]
S9["💡 步骤9：反思与学习 ★"]
S10["📦 步骤10：归档与交付 ★"]
DONE["🏁 完成"]

S0 --> S1 --> S2 --> S3 --> S4
S4 -->|"智能评估推荐执行深度"| S45
S45 --> S5 --> S55 --> S6
S6 --> S7
S7 -->|"标准执行：全部环节A~J"| DONE
S7 -->|"完整执行：仅A~G"| S8 --> S9 --> S10 --> DONE

S4 -.->|"换方案"| S3
S6 -.->|"验证失败"| S5
S8 -.->|"🔴 严重问题"| S5

classDef shared fill:#1e1b4b,stroke:#4338ca,color:#e0e7ff
classDef fullOnly fill:#312e81,stroke:#6366f1,color:#c7d2fe
classDef done fill:#064e3b,stroke:#10b981,color:#d1fae5
class S0,S1,S2,S3,S4,S45,S5,S55,S6,S7 shared
class S8,S9,S10 fullOnly
class DONE done```

> ★ = 仅完整执行时执行的步骤。步骤 0~7 为所有需求共享。
> **标准执行**（步骤 5→7）：步骤7 执行全部环节 A~J（清理+L2审查+Commit+Devlog+Specs+反思+经验快检），流程结束。
> **完整执行**（步骤 5→10）：步骤7 仅执行环节 A~G（清理+L2审查），Commit/Devlog/反思推迟到步骤 9~10。
> 执行深度由步骤4基于步骤1~3研究成果智能评估推荐，用户可自由覆盖。

---

## 3. 执行深度分支（步骤4 智能评估）

> **v2 新增设计**：v1 中执行深度由入口关键词决定（dev:full vs dev:quick），v2 改为步骤4基于研究成果智能评估。
> 评估在方案汇报时自动执行，输出评估卡片，用户可自由覆盖AI推荐。

**智能评估维度**：

| 维度 | 评估方式 | 权重 |
| --- | --- | --- |
| 改动范围 | 步骤2确认的文件数、预估改动行数 | 高 |
| 复杂度 | 是否涉及状态管理/异步/多模块联动 | 高 |
| 风险等级 | 是否涉及公共组件/核心逻辑/数据流 | 中 |
| 需求明确度 | 阶段0的需求理解是否有歧义 | 中 |

```mermaid
flowchart TD
S4["🤝 步骤4：方案汇报与用户决策"]
EVAL["📊 智能评估<br/>改动范围/复杂度/风险等级"]
CARD["输出评估卡片<br/>+ 推荐执行深度"]

S4 --> EVAL --> CARD
CARD --> UC{"用户决策"}
UC -->|"✅ 标准执行"| STD["标准执行<br/>步骤 5→6→7（全部环节）→ 完成"]
UC -->|"📋 完整执行"| FULL["完整执行<br/>步骤 5→6→7（裁剪）→8→9→10 → 完成"]
UC -->|"✏️ 修改"| S4
UC -->|"🔄 换方案"| BACK3["回退步骤3"]
UC -->|"⏸️ 暂存"| PAUSE["⏸️ 暂存待执行"]
UC -->|"❌ 取消"| CANCEL["❌ 终止"]

classDef assess fill:#1e1b4b,stroke:#4338ca,color:#e0e7ff
classDef standard fill:#064e3b,stroke:#10b981,color:#d1fae5
classDef full fill:#312e81,stroke:#6366f1,color:#c7d2fe
class S4,EVAL,CARD assess
class STD standard
class FULL full```

> **评估维度**：改动范围（文件数/行数）、复杂度（状态管理/异步/多模块联动）、风险等级（公共组件/核心逻辑）
> **推荐规则**：改动范围小+风险低 → 标准执行；改动范围大+多模块联动 → 完整执行
> 用户可自由覆盖 AI 推荐，不受任何限制。支持部分执行（如"标准执行 1-3"只执行计划中第1~3步）。

---

## 4. 收尾模式（环节制 A→B→F→G→H→I）

> 收尾模式是唯一保留的独立入口，适用于代码已改完、只需汇总改动和生成 commit 的场景。
> 与标准执行步骤7共享统一的收尾流程规范（`wrapup-flow.md`），通过 `caller=wrapup` 标识控制差异行为。

```
flowchart TD
WA["📊 环节A：Diff分析"]
WB["🧹 环节B：清理调试代码"]
WF["📋 环节F：改动汇总"]
WG["🔎 环节G：L2完整审查"]
WH["📝 环节H：Commit+Devlog+Specs"]
WI["💡 环节I：L1即时反思"]
WDONE["🏁 完成"]

WA --> WAD{"预期外变更?"}
WAD -->|"无"| WB
WAD -->|"有"| WAC{"用户选择"}
WAC -->|"🧹 全部回退"| WACR["git checkout"] --> WB
WAC -->|"✏️ 部分回退"| WACP["选择性回退"] --> WB
WAC -->|"⏭️ 保留全部"| WB
WB --> WF --> WG
WG --> WGR{"审查结果"}
WGR -->|"🔴 必须修复"| WGFIX["修复"] --> WG
WGR -->|"🟡 建议修复"| WGD{"用户决策"}
WGD -->|"修复"| WGFIX
WGD -->|"跳过"| WH
WGR -->|"通过"| WH
WH --> WI --> WDONE

classDef wrapup fill:#1c1917,stroke:#78716c,color:#e7e5e4
class WA,WB,WF,WG,WH,WI wrapup```

> 灵活用法：「收尾」=完整流程 | 「不用检查」=跳过环节B | 「汇总改动」=A+F | 「只要commit」=环节H | 「帮我提交」=H+git commit
> 收尾模式跳过环节 C（可选链检查）、D（即时验证）、E（TODO检查），定位为轻量汇总。
> **无 .flow 文件时的处理**：用户直接说"收尾"但之前未走 dev-flow 流程时，收尾模式仍正常执行，但跳过 .flow 文件的同步和删除操作。

---

## 5. 统一收尾流程（wrapup-flow.md）— 调用方×环节矩阵

> **v2 新增设计**：v1 的收尾流程有 9 个环节（A~I），v2 新增环节 J（经验快检），共 10 个环节。
> 三种调用方共享同一套规范，通过 `caller` 参数控制差异行为，消除了代码重复。

**环节 H 子步骤**（Commit+Devlog+Specs，按编号顺序逐项执行，禁止跳过或合并）：
- **H.1** 生成 Commit Message（调用 smart-commit skill，含复用检查+任务平台信息获取+用户确认+持久化）
- **H.2** 生成/追加开发日志（调用 tech-doc skill 路由到 devlog 模块，禁止跳过）
- **H.3** 规范沉淀（加载 project-specs.md 执行沉淀流程，禁止跳过）

```mermaid
flowchart TD
subgraph MATRIX["调用方 × 环节矩阵"]
direction TB
MA["A. Diff分析<br/>standard-7 ✅ | full-7 ✅ | wrapup ✅"]
MB["B. 清理调试代码<br/>standard-7 ✅ | full-7 ✅ | wrapup ✅"]
MC["C. 可选链检查<br/>standard-7 ✅ | full-7 ✅ | wrapup ❌"]
MD["D. 即时验证<br/>standard-7 ✅ | full-7 ✅ | wrapup ❌"]
ME["E. TODO检查<br/>standard-7 ✅ | full-7 ✅ | wrapup ❌"]
MF["F. 改动汇总<br/>standard-7 ❌ | full-7 ❌ | wrapup ✅"]
MG["G. L2审查<br/>standard-7 ✅ | full-7 ✅到此结束 | wrapup ✅"]
MH["H. Commit+Devlog+Specs<br/>standard-7 ✅ | full-7 ❌推迟 | wrapup ✅"]
MI["I. 数据驱动反思<br/>standard-7 ✅必须 | full-7 ❌ | wrapup ✅仅L1"]
MJ["J. 经验快检<br/>standard-7 ✅ | full-7 ❌ | wrapup ❌"]
MA --> MB --> MC --> MD --> ME --> MF --> MG --> MH --> MI --> MJ
end```

> **三种调用方**：
> - `caller=standard-7`：标准执行步骤7，执行全部环节 A~J
> - `caller=full-7`：完整执行步骤7，仅执行 A~G（到 G 结束，H/I/J 推迟到步骤 9~10）
> - `caller=wrapup`：收尾模式，执行 A→B→F→G→H→I（跳过 C/D/E/J）

---

## 6. 阶段0：需求理解

> **核心原则**：产出准确性是第一优先级。所有需求（无论大小）都必须经过阶段0，不理解需求就无法准确执行。
> 阶段0通过 `use_skill("requirement-intake")` 加载完整需求理解流程，支持 任务平台 链接、Figma 设计稿、口头描述、截图等多种输入方式。
> 需求理解确认后，必须根据需求类型自动推荐分支名（feature/xxx 或 bugfix/xxx），输出在需求分析报告末尾。

```
flowchart TD
RI["调用 requirement-intake"] --> RIA{"输入方式?"}
RIA -->|"无信息"| RIQ["交互式提问"]
RIA -->|"带信息"| RID["直接分析"]
RIQ --> RID
RID --> SRC{"需求来源?"}
SRC -->|"任务平台"| 任务平台["MCP查询单据"]
SRC -->|"Figma"| FIG["MCP获取设计稿"]
SRC -->|"口头/截图"| ANA["直接分析"]
任务平台 --> ANA
FIG --> ANA
ANA --> OUT["输出需求分析"]
OUT --> QA{"有疑问?"} -->|"是"| ASK["汇总提问"] --> ANS["用户回答"] --> QA
QA -->|"否"| CONF["输出最终确认"]
CONF --> UC{"用户确认"}
UC -->|"✅ 正确"| BR["分支命名建议 → 步骤1"]
UC -->|"✏️ 纠正"| OUT
UC -->|"❓ 疑问"| ASK```

> 所有需求（无论大小）都必须经过阶段0。产出准确性是第一优先级。
> 迭代修复场景下，阶段0执行增量理解而非全量理解。

---

## 7. 步骤1~4.5 子流程

> 步骤1~3 是所有需求的必经之路，确保在编码前充分理解代码库和需求。
> 步骤4 是编码前的最后一道门控，用户必须明确决策后才能进入步骤5。

### 步骤1：研究与定位

> **核心产出**：相关文件表格。优先检索项目规范（`~/.codebuddy/specs/`），再搜索代码库。
> **Skill 自动发现**：此步骤会检查 `self-improving-agent` skill 检索历史经验。

```mermaid
flowchart TD
S1["步骤1开始"] --> SPEC{"项目规范存在?"}
SPEC -->|"是"| SPECL["加载模块规范"]
SPEC -->|"否"| SEARCH["搜索相关文件+上下游链路"]
SPECL --> SEARCH
SEARCH --> FIGMA{"有Figma?"} -->|"是"| FIGP["处理设计稿"] --> DOMAIN
FIGMA -->|"否"| DOMAIN{"不熟悉领域?"}
DOMAIN -->|"是"| DK["领域知识补充+确认"] --> OUTPUT
DOMAIN -->|"否"| OUTPUT["输出相关文件表格"]```

### 步骤2：确认范围

> **核心产出**：影响范围报告 + 用户确认。锁定范围后不可随意扩展。

```
flowchart TD
S2["步骤2开始"] --> RPT["输出影响范围报告"]
RPT --> UC{"用户确认"}
UC -->|"✅ 确认"| LOCK["锁定范围"]
UC -->|"✏️ 补充"| RPT
UC -->|"🔄 重新分析"| BACK["回退步骤1"]```

### 步骤3：制定方案

> **核心产出**：执行计划表格。调用 `design-advisor` skill 辅助方案设计。

```mermaid
flowchart TD
S3["步骤3开始"] --> DA["调用 design-advisor"]
DA --> PLAN["输出执行计划表格"]```

### 步骤4：方案汇报与用户决策（门控）

> **核心产出**：评估卡片 + 执行深度选择。这是编码前的最后一道门控。
> 计划锁定后保存到 `~/.codebuddy/dev-logs/{需求文件夹名}/plan.md`。

```
flowchart TD
S4["汇报方案 + 评估卡片"] --> UC{"用户决策"}
UC -->|"✅ 标准执行"| LOCK["锁定计划 + 保存plan.md"]
UC -->|"📋 完整执行"| LOCK
UC -->|"✏️ 修改"| S4
UC -->|"🔄 换方案"| BACK3["回退步骤3"]
UC -->|"⏸️ 暂存"| PAUSE["暂存"]
UC -->|"❌ 取消"| CANCEL["终止"]
LOCK --> TECH{"完整执行+文档平台?"}
TECH -->|"是"| TECHD["生成技术方案文档"]
TECH -->|"否"| NEXT["→ 步骤4.5"]
TECHD --> NEXT```

### 步骤4.5：环境检查

> **核心产出**：分支确认。检查当前 Git 分支是否正确，主干分支会警告。

```mermaid
flowchart TD
GIT["git branch --show-current"] --> CHK{"分支检查"}
CHK -->|"主干分支"| WARN["⚠️ 警告+推荐分支"]
CHK -->|"开发分支"| OK["✅ 无需切换"]
CHK -->|"其他分支"| WARN2["⚠️ 可能错误分支"]
WARN --> UC{"确认"} -->|"就绪"| NEXT["→ 步骤5"]
OK --> UC
WARN2 --> UC```

---

## 8. 步骤5~7 子流程

> 步骤5~7 是执行阶段的核心。步骤5 按锁定计划编码，步骤5.5 做 L1 审查和文档同步，
> 步骤6 做 7 阶段自动化验证（Build/TypeCheck/Lint/Browser/Test/Security/Diff Review），
> 步骤7 根据执行深度执行不同环节的收尾流程。

### 步骤5：执行修改

> **核心产出**：代码改动。严格按锁定计划执行，禁止计划外改动（红牌行为）。
> 每个计划步骤完成后执行 `read_lints` 验证，lint 错误立即修复。

```
flowchart TD
S5["步骤5开始"] --> TDD{"TDD评估"}
TDD -->|"适合"| TDDS["建议TDD"]
TDD -->|"不适合"| EXEC["按锁定计划执行"]
TDDS --> EXEC
EXEC --> CODE["编码实现"] --> LINT["read_lints"]
LINT --> ERR{"lint错误?"}
ERR -->|"是"| FIX["修复"] --> LINT
ERR -->|"否"| NEXT{"还有步骤?"}
NEXT -->|"是"| CODE
NEXT -->|"否"| DONE5["→ 步骤5.5"]
EXEC -.->|"无法执行"| BLOCK["回退步骤4"]```

### 步骤5.5：编码后置钩子

> **核心产出**：L1 审查 + 文档同步 + 自检。三个子步骤：5.5a L1基础审查、5.5b 文档同步、5.5c 快速自检。
> **三级审查体系**：L1（步骤5.5，基础审查）→ L2（步骤7，完整规范审查）→ L3（步骤8，多视角深度审查）。

```mermaid
flowchart TD
A["5.5a L1基础审查"] --> SEV{"严重度?"}
SEV -->|"🔴"| RFIX["立即修复"] --> A
SEV -->|"🟡"| YD{"用户决策"} -->|"修复"| YFIX["修复"]
YD -->|"跳过"| B
SEV -->|"🟢"| B["5.5b 文档同步"]
YFIX --> B
B --> C["5.5c 快速自检 read_lints"]
C --> CERR{"有错误?"} -->|"是"| CFIX["修复→回5.5a"]
CERR -->|"否"| PASS["→ 步骤6"]```

### 步骤6：质量验证（6A+6B+6C）

> **核心产出**：验证报告。6A 自动化验证（7阶段管线，含3次失败熔断）、6B 用户验收（可选）、6C 联调（条件触发）。
> **熔断规则**：同一验证项连续失败3次 → 熔断，弹出交互式选项让用户决策（回退/跳过/继续）。

```
flowchart TD
subgraph A6["6A 自动化验证"]
V1["V1 Build"] --> V2["V2 TypeCheck"] --> V3["V3 Lint"]
V3 --> V4["V4 Browser（条件触发）"] --> V5["V5 Test"]
V5 --> V6["V6 Security"] --> V7["V7 Diff Review"]
end
subgraph B6["6B 用户验收（可选）"]
VB{"验收?"} -->|"验收"| VBA["验收流程"]
VB -->|"跳过"| VBP["跳过"]
VBA --> VBR{"结果"} -->|"通过"| VBP
VBR -->|"部分问题"| VBF1["→步骤5"]
VBR -->|"不通过"| VBF2["→步骤3"]
end
subgraph C6["6C 联调（条件触发）"]
VC{"联调?"} -->|"联调"| VCA["联调流程"]
VC -->|"跳过"| VCP["→步骤7"]
VC -->|"暂存"| VCS["暂存等联调"]
VCA --> VCR{"结果"} -->|"通过"| VCP
VCR -->|"前端问题"| VCF["→步骤5"]
VCR -->|"后端问题"| VCW["暂存"]
end
A6 --> FUSE{"3次失败?"} -->|"是"| FUSED["熔断→回退/跳过"]
FUSE -->|"否"| B6 --> C6```

### 步骤7：清理+Commit（统一收尾流程）

> **v2 关键设计**：步骤7 的行为根据执行深度不同而不同。
> 标准执行（`caller=standard-7`）执行全部环节 A~J，是标准执行的最后一步。
> 完整执行（`caller=full-7`）仅执行 A~G，Commit/Devlog/反思推迟到步骤 9~10。

```mermaid
flowchart TD
subgraph STD7["标准执行步骤7（caller=standard-7）"]
direction TB
QA["A.Diff分析"] --> QB["B.清理调试代码"]
QB --> QC["C.可选链检查"] --> QD["D.即时验证"]
QD --> QE["E.TODO检查"] --> QG["G.L2审查"]
QG --> QH["H.Commit+Devlog+Specs"]
QH --> QI["I.数据驱动反思"]
QI --> QJ["J.经验快检"]
end
subgraph FULL7["完整执行步骤7（caller=full-7）"]
direction TB
FA["A.Diff分析"] --> FB["B.清理调试代码"]
FB --> FC["C.可选链检查"] --> FD["D.即时验证"]
FD --> FE["E.TODO检查"] --> FG["G.L2审查"]
FG --> FEND["到此结束→步骤8"]
end```

> 标准执行步骤7执行全部环节（A→B→C→D→E→G→H→I→J），完整执行步骤7仅到G结束，H/I/J推迟到步骤9~10。
> 环节J（经验快检）：3问快检——①本次是否有用户纠正？②是否踩了已知坑？③是否发现新模式？全否则零开销。

---

## 9. 完整执行独有步骤（8~10）

> 以下步骤仅在用户选择「完整执行」时执行。标准执行在步骤7结束。
> 完整执行适用于核心逻辑改动、需求驱动开发、架构重构等高风险场景。

### 步骤8：L3代码审查

> **三级审查体系的最高级**：L3 = L2 全部内容 + 注释补充 + 多视角审查（安全审计/性能工程/可维护性）+ 测试点位建议。
> 调用 `code-review` skill 执行 L3 多视角深度审查，同时执行文档同步兜底检查。

```
flowchart TD
L3["L3多视角深度审查<br/>安全+性能+可维护性+测试点位"]
L3 --> DOC["文档同步兜底"]
DOC --> SEV{"严重度?"}
SEV -->|"🔴"| BACK5["→步骤5修复"]
SEV -->|"🟡"| UD["用户决策"]
SEV -->|"🟢"| NEXT9["→ 步骤9"]
UD --> NEXT9
BACK5 -.-> L3```

### 步骤9：反思与学习（数据驱动，4个子步骤）

> **v2 新增设计**：三层反思机制（L1/L2/L3），融合度量数据采集，让反思从"凭感觉"升级为"数据驱动"。
> 9a 度量数据采集 → 9b 代码经验提炼 → 9c 流程自我反思 → 9d L1即时反思输出。
> 度量数据写入 `~/.codebuddy/.metrics/reports/{需求ID}.yaml`，支持历史对比和趋势分析。

```mermaid
flowchart TD
S9A["9a 度量数据采集与报告<br/>提取步骤耗时/回退次数/git diff统计"]
S9A --> S9B["9b 代码经验提炼（数据辅助）"]
S9B --> EXP{"高价值经验?"}
EXP -->|"是"| RULE["写入规则"]
EXP -->|"否"| S9C
RULE --> S9C["9c 流程自我反思（度量驱动）<br/>最耗时步骤/回退规律/历史对比"]
S9C --> OPT{"有优化建议?"}
OPT -->|"是"| SUGGEST["输出建议清单"]
OPT -->|"否"| SMOOTH["流程顺畅"]
SUGGEST --> S9D["9d L1即时反思输出"]
SMOOTH --> S9D
S9D --> NEXT10["→ 步骤10"]```
> 跳过条件：全程无回退、无卡顿、无用户纠正，且指标在历史平均±30%范围内时精简输出。

### 步骤10：归档与交付（6个子步骤）

> **完成性校验（10.6）**：标记 completed 之前，必须逐项核对 5 项 checklist，全部 ✅ 后才能输出完成标记 JSON。
> 步骤10完成后必须删除 `.flow` 文件（流程结束，释放活跃状态）。

```
flowchart TD
T1["10.1 规则归档"]
T2["10.2 规范沉淀（必须）"]
T3["10.3 生成Commit Message"]
T4["10.4 生成/追加开发日志（必须）"]
T5["10.5 输出交付报告"]
T6["10.6 完成性校验"]
T1 --> T2 --> T3
T3 --> UC{"用户确认"}
UC -->|"✅ 确认"| T4
UC -->|"📦 确认并提交"| GITCMT["git add+commit"] --> T4
UC -->|"✏️ 修改"| T3
T4 --> T5 --> T6
T6 --> CHK{"5项全部✅?"}
CHK -->|"是"| DEL["删除.flow文件 → 🏁 完成"]
CHK -->|"否"| FIX["补齐缺失项"] --> T6```
> 10.6 校验项：①Commit已确认 ②devlog已生成 ③specs已沉淀 ④交付报告已输出 ⑤规则归档已处理

---

## 10. 特殊流程

### 迭代修复机制

> **设计理念**：当完整执行/标准执行走完全流程并提测后，测试/产品反馈问题需要修改时，进入迭代修复路径。
> 不引入新模式，而是在统一流程入口增加一层前置逻辑：匹配已有工作上下文 → 评估复杂度 → 增量执行。
> **轮次管理**：YAML 头部 `iteration` 字段为唯一真相源，`iteration_history` 记录历史轮次摘要。
> **膨胀控制**：`iteration >= 3` 时自动精简早期轮次正文内容，确保研究阶段的上下文窗口最大化。

```mermaid
flowchart TD
TRIG["触发信号：提测反馈/测试bug/继续需求"]
TRIG --> MATCH["匹配已有工作上下文"]
MATCH --> MR{"匹配到?"}
MR -->|"否"| NORMAL["正常统一流程"]
MR -->|"是"| READ["读取上下文"]
READ --> ITER["更新YAML轮次 iteration+1"]
ITER --> EVAL["复杂度评估"]
EVAL --> UC{"用户确认"}
UC -->|"✅ 按建议"| MODE{"复杂度?"}
UC -->|"🔄 切换模式"| EVAL
UC -->|"✏️ 调整范围"| EVAL
UC -->|"❌ 取消"| CANCEL["终止"]
MODE -->|"简单/中等"| STD["标准执行（增量）"]
MODE -->|"重大"| FULL["完整执行（增量）"]
STD --> DEVLOG["devlog追加 Round N"]
FULL --> DEVLOG```
> 步骤简化：步骤1增量研究、步骤2增量范围、步骤3增量调整，步骤4~7/10无变化
> 轮次管理：YAML头部 iteration 字段为唯一真相源，iteration_history 记录历史轮次摘要
> 膨胀控制：iteration≥3 时自动精简早期轮次正文内容

### 回退机制

> 完整回退对照表定义在 `references/rollback.md`（单一真相源）。

| 当前步骤 | 问题 | 回退到 |
| --- | --- | --- |
| 步骤4 | 修改 | 步骤4（更新后重新选择） |
| 步骤4 | 换方案 | 步骤3 |
| 步骤5 | 计划无法执行 | 步骤4 |
| 步骤5.5a | 🔴修复 | 步骤5.5a（重新审查） |
| 步骤5.5c | lint错误 | 步骤5.5a |
| 步骤6A V1-V3 | 编译/类型/lint | 步骤5.5a |
| 步骤6A V4 | Browser失败 | 步骤5 |
| 步骤6A V5 | 测试失败 | 步骤3 |
| 步骤6B | 部分问题 | 步骤5 |
| 步骤6B | 不通过 | 步骤3 |
| 步骤6C | 前端问题 | 步骤5 |
| 步骤6C | 协议不一致 | 步骤3 |
| 步骤7 L2 | 🔴修复后 | 步骤5.5a |
| 步骤8（完整） | CRITICAL | 步骤5 |

### 门控与钩子（分级钩子 Tiered Hooks）

> **v2 新增设计**：根据步骤的关键程度，使用不同重量的完成钩子，减少轻量级步骤的 Token 开销。
> 每个步骤完成后必须按顺序执行 3 个动作：①输出结构化完成标记 JSON → ②原子状态同步 → ③门控验证。
> **原子状态同步**：将工作上下文更新和 .flow 文件更新合并为一次操作，减少文件操作次数。
> **状态快照**：仅关键步骤（3/5/6）创建快照，用于回退时参考历史状态。

```
flowchart TD
STEP["步骤N完毕"] --> TIER{"钩子级别?"}
TIER -->|"🔴 重量级<br/>步骤4/5/6/7"| H1R["动作1：完整outputs+gate_checks"]
TIER -->|"🟡 中量级<br/>步骤3/5.5/8"| H1Y["动作1：精简outputs（仅关键字段）"]
TIER -->|"🟢 轻量级<br/>步骤1/2/4.5/9/10"| H1G["动作1：最小outputs（3-4字段）"]
H1R --> H2["动作2：原子状态同步<br/>（工作上下文+.flow一次写入）"]
H1Y --> H2
H1G --> H2
H2 --> SNAP{"关键步骤?<br/>步骤3/5/6"}
SNAP -->|"是"| H2S["创建状态快照"] --> H3
SNAP -->|"否"| H3["动作3：门控验证"]
H3 --> GATE{"校验通过?"}
GATE -->|"是"| NEXT["加载步骤N+1"]
GATE -->|"否"| FIX["立即补齐"] --> GATE```
> **分级钩子**：🔴重量级（完整校验）| 🟡中量级（关键字段校验）| 🟢轻量级（仅status+next_step）
> **原子操作**：动作2将工作上下文更新和.flow文件更新合并为一次操作，减少IO开销
> **状态快照**：仅步骤3/5/6创建快照，每需求最多5个，超出删除最早的

---

## 11. 交互模式（精简交互优化）

> **设计理念**：减少交互次数，但不跳过任何步骤。按风险等级分级处理交互点，让用户只在关键决策点介入。
> 标准模式（默认，4~7次交互）和精简模式（`--fast`，2~3次交互）。
> **安全保障**：步骤完整性不降级、门控不降级、🔴关键决策点在任何模式下都必须暂停。

### 步骤 2+3+4 合并展示

```mermaid
flowchart TD
subgraph BEFORE["优化前（3次交互）"]
direction TB
B1["步骤2：展示范围"] --> B2{"用户确认范围"}
B2 --> B3["步骤3：展示方案"] --> B4{"用户确认方案"}
B4 --> B5["步骤4：用户决策"]
end
subgraph AFTER["优化后（1次交互）"]
direction TB
A1["步骤2+3：完整执行<br/>（范围分析+方案制定）"]
A1 --> A2["步骤4：一次性展示<br/>范围+方案+评估卡片"]
A2 --> A3{"用户决策"}
A3 -->|"✅ 执行"| A4["→ 步骤4.5"]
A3 -->|"范围有误"| A5["调整范围"] --> A1
A3 -->|"方案需改"| A6["修改方案"] --> A1
end```

> 步骤2和3仍完整执行，只是合并展示和确认点。用户在步骤4一次性确认"范围+方案+执行深度"。

### 步骤 7 合并审查报告

```
flowchart TD
subgraph BEFORE7["优化前（最多3次交互）"]
direction TB
C1["环节A：预期外变更"] --> C2{"交互"}
C2 --> C3["环节B：调试代码"] --> C4{"交互"}
C4 --> C5["环节G：L2审查🟡项"] --> C6{"交互"}
end
subgraph AFTER7["优化后（1次交互）"]
direction TB
D1["环节A+B+C+D+E<br/>静默执行"]
D1 --> D2["环节G：L2审查"]
D2 --> D3["📋 合并输出<br/>清理与审查报告"]
D3 --> D4{"用户选择"}
D4 -->|"🔧 修复🟡项"| D5["修复"]
D4 -->|"⏭️ 跳过"| D6["→ 环节H"]
D4 -->|"✏️ 部分修复"| D7["选择性修复"]
end```

> 精简模式下，若清理全部✅且L2无🟡项，合并为一行摘要直接继续。

### 交互模式风险分级

```mermaid
flowchart TD
MODE{"交互模式?"}
MODE -->|"标准模式"| STD["所有交互点正常暂停<br/>4~7次交互"]
MODE -->|"精简模式"| SIM["按风险分级处理<br/>2~3次交互"]
SIM --> RED["🔴 关键决策点<br/>步骤4决策 / 步骤7 Commit<br/>→ 必须暂停"]
SIM --> YELLOW["🟡 质量决策点<br/>L1/L2审查🟡项 / 验证结果<br/>→ 智能默认，异常才打断"]
SIM --> GREEN["🟢 流程决策点<br/>研究结果 / 环境检查<br/>→ 一行摘要继续"]```
> 精简模式仍输出步骤完成反馈（`✅ 步骤N完成：...`），不完全静默。
> 触发方式：`--fast` / `少问我` / `你自己判断就行` → 精简模式

---

## 12. Prompt Chaining 架构

> **核心作用**：Prompt Chaining 是 v2 的底层执行架构，解决了 v1 中一次性加载所有流程定义导致的 Token 浪费问题。
> **设计理念**：
> - **按需加载**：`flow.md` 为 L0 核心路由层（~340行），只包含流程总览和全局规则。每个步骤的详细规范拆分到 `steps/` 目录下的独立文件中，执行到该步骤时才加载。
> - **门控串联**：每个步骤完成后必须输出结构化完成标记 JSON，通过门控验证后才能加载下一步骤文件。这确保了步骤间的严格顺序和状态一致性。
> - **上下文节约**：完整执行步骤多、上下文消耗大，每完成一个步骤将过程细节卸载，仅保留结论到工作上下文文件。
> **架构层次**：
> - **L0 路由层**：`flow.md`（流程总览）+ `step-router.md`（步骤路由器，唯一导航权威）
> - **L1 步骤层**：`steps/step-N-xxx.md`（各步骤详细规范，按需加载）
> - **L2 参考层**：`references/xxx.md`（参考文件，步骤内按需加载）
> **红牌行为**（检测到任何一条立即停止）：
> 1. 未输出步骤 N 的完成标记 JSON 就开始步骤 N+1
> 2. 未等用户确认就开始编码（步骤4→步骤5）
> 3. 未 `read_file` 加载步骤详细规范就开始执行该步骤
> 4. 一次性加载多个步骤文件

```
flowchart TD
ENTRY["触发 dev-flow"] --> LOAD["加载 flow.md（L0 路由层）"]
LOAD --> ROUTER["加载 step-router.md（步骤路由器）"]
ROUTER --> S0["阶段0：use_skill requirement-intake"]
S0 --> JSON0["输出完成标记 JSON"]
JSON0 --> GATE0["门控验证"]
GATE0 --> STEP["read_file steps/step-N-xxx.md"]
STEP --> EXEC["按步骤规范执行"]
EXEC --> JSONN["输出完成标记 JSON"]
JSONN --> SYNC["原子状态同步<br/>工作上下文+.flow"]
SYNC --> GATEN["门控验证"]
GATEN -->|"通过"| NEXTSTEP{"还有下一步?"}
GATEN -->|"失败"| FIX["补齐"] --> GATEN
NEXTSTEP -->|"是"| STEP
NEXTSTEP -->|"否"| DONE["🏁 流程完成<br/>删除.flow文件"]

classDef chain fill:#1e1b4b,stroke:#4338ca,color:#e0e7ff
class ENTRY,LOAD,ROUTER,STEP,EXEC chain```

> **核心规则**：每次只加载一个步骤文件，完成后输出结构化 JSON，通过门控后才能加载下一步。
> 禁止一次性加载多个步骤文件，禁止未加载步骤文件就执行该步骤。

---

## 13. 源文件索引

| 文件 | 说明 |
| --- | --- |
| `SKILL.md` | 主入口，统一流程设计+全局规则 |
| `flow.md` | 开发流程详细指引（L0路由层） |
| `wrapup.md` | 收尾模式指引（引用统一收尾流程） |
| `steps/step-router.md` | 步骤路由器（Prompt Chaining核心） |
| `steps/README.md` | 步骤规范目录导航 |
| `steps/step-1-research.md` | 步骤1：研究与定位 |
| `steps/step-2-scope.md` | 步骤2：确认范围 |
| `steps/step-3-plan.md` | 步骤3：制定方案 |
| `steps/step-4-decision.md` | 步骤4：方案汇报与用户决策+智能评估 |
| `steps/step-4.5-env-check.md` | 步骤4.5：环境检查 |
| `steps/step-5-execute.md` | 步骤5：执行修改 |
| `steps/step-5.5-post-coding.md` | 步骤5.5：编码后置钩子 |
| `steps/step-6-verify.md` | 步骤6：质量验证 |
| `steps/step-7-commit.md` | 步骤7：清理+Commit（引用统一收尾流程） |
| `steps/step-8-10-full.md` | 步骤8~10：完整执行扩展（L3审查+反思+归档） |
| `references/_index.md` | 参考文件加载索引 |
| `references/wrapup-flow.md` | 统一收尾流程规范（10环节制，含经验快检） |
| `references/iteration-fix.md` | 迭代修复机制（轮次管理+膨胀控制） |
| `references/rollback.md` | 回退对照表 |
| `references/working-context.md` | 工作上下文模板 |
| `references/code-safety-rules.md` | 代码安全规则 |
| `references/integration-flow.md` | 联调流程 |
| `references/user-acceptance.md` | 用户验收流程 |
| `references/project-specs.md` | 项目规范层 |
| `references/flow-retrospective.md` | 流程反思模板 |
| `references/metrics-rules.md` | 度量数据规则 |
| `references/interaction-mode.md` | 交互模式（标准/精简） |
| `references/tech-proposal-flow.md` | 技术方案文档 |
| `references/token-management.md` | Token管理 |
| `references/core-principles.md` | 核心原则（§1~§18） |
| `references/devlog-rules.md` | 开发日志规范 |
| `references/doc-sync-rules.md` | 文档同步规则 |
| `references/figma-flow.md` | Figma设计稿处理流程 |
| `references/topic-specs.md` | 专题规范查找表 |
| `references/tdd-mode.md` | TDD模式规范 |
| `references/output-schemas.md` | 输出Schema定义 |
| `references/shared-rules.md` | 共享规则（Commit/沉淀/并行/分支） |
| `references/gate-validator.md` | 门控验证器 |
| `references/env-tools.md` | 环境工具（含 Git Worktrees） |
| `references/react.md` | React专题规范 |
| `references/component-library.md` | 组件库规范 |
| `references/flow-graph.md` | 流程图定义 |
