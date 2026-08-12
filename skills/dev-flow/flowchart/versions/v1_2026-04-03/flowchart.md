# dev-flow 完整流程图

> 静态 Mermaid 版本，可在 GitHub / IDE 中直接渲染预览。
> 交互式版本（支持点击跳转到源文件）：[flowchart.html](./flowchart.html)

---

## 1. 入口触发与模式路由

```mermaid
flowchart TD
A["🗣️ 用户消息"] --> B{"关键词匹配?"}
B -->|"dev:full / 任务平台 / Figma / 新需求"| C["📋 完整模式"]
B -->|"dev:quick / 修复 / 优化 / 调整"| D["⚡ 快速模式"]
B -->|"dev:ultra / 直接改就行"| UQ["🚀 极速模式"]
B -->|"dev:wrap / 收尾 / 生成commit"| E["📦 收尾模式"]
B -->|"dev:specs"| F["📐 规范管理"]
B -->|"dev:status"| G["📊 状态查看"]
B -->|"未匹配"| H{"检查 .active-flows/"}
H -->|"0个活跃"| I["💬 普通对话"]
H -->|"1个活跃"| J["🔄 自动恢复"]
H -->|"≥2个活跃"| K["📋 展示清单让用户选"]
C --> N{"迭代修复信号?"}
D --> N
N -->|"是"| O["匹配已有工作上下文"] --> Q{"匹配到?"}
N -->|"否"| P["创建/读取工作上下文"]
Q -->|"是"| R{"复杂度评估"}
Q -->|"否"| P
R -->|"简单/中等"| D2["⚡ 快速模式（增量）"]
R -->|"重大"| C2["📋 完整模式（增量）"]
UQ --> UQ1["U1定位→U2修改→U3收尾"]
UQ1 -.->|"降级"| D

```

> 优先级：用户显式指定 > 收尾关键词 > 完整模式信号 > 快速模式信号 > 极速模式信号 > 默认快速模式

---

## 2. 完整模式总览（阶段0 + 步骤1~10）

```mermaid
flowchart TD
S0["🎯 阶段0：需求理解 ★"]
S1["🔍 步骤1：研究与定位"]
S2["📐 步骤2：确认范围"]
S3["📝 步骤3：制定方案"]
S4["🤝 步骤4：用户决策"]
S45["🔧 步骤4.5：环境检查"]
S5["⚙️ 步骤5：执行修改"]
S55["🔬 步骤5.5：编码后置钩子"]
S6["✅ 步骤6：质量验证"]
S7["🧹 步骤7：清理+L2审查（裁剪版）"]
S8["🔎 步骤8：L3代码审查 ★"]
S9["💡 步骤9：反思与学习 ★"]
S10["📦 步骤10：归档与交付 ★"]
DONE["🏁 完成"]
S0 --> S1 --> S2 --> S3 --> S4
S4 --> S45 --> S5 --> S55 --> S6
S6 --> S7 --> S8 --> S9 --> S10 --> DONE
S4 -.->|"换方案"| S3
S6 -.->|"验证失败"| S5
S8 -.->|"严重问题"| S5

```

> ★ = 完整模式独有步骤。步骤1~7为快速模式共享。步骤7裁剪了commit/devlog/反思，推迟到步骤10。

---

## 3. 快速模式总览（步骤1~7）

```mermaid
flowchart TD
Q1["🔍 步骤1：研究与定位"]
Q2["📐 步骤2：确认范围"]
Q3["📝 步骤3：制定方案"]
Q4["🤝 步骤4：用户决策"]
Q45["🔧 步骤4.5：环境检查"]
Q5["⚙️ 步骤5：执行修改"]
Q55["🔬 步骤5.5：编码后置钩子"]
Q6["✅ 步骤6：质量验证"]
Q7["🧹 步骤7：清理+Commit"]
QDONE["🏁 完成"]
Q1 --> Q2 --> Q3 --> Q4
Q4 -->|"✅ 执行"| Q45 --> Q5 --> Q55 --> Q6 --> Q7 --> QDONE
Q4 -.->|"✏️ 修改"| Q4
Q4 -.->|"🔄 换方案"| Q3
Q4 -.->|"⏸️ 暂存"| QPAUSE["⏸️ 暂存"]
Q4 -.->|"❌ 取消"| QCANCEL["❌ 终止"]
Q6 -.->|"6A失败"| Q5
Q6 -.->|"6B不通过"| Q3

```

---

## 4. 极速模式总览（3步）

```mermaid
flowchart TD
U1["📍 U1：精准定位"]
U2["⚙️ U2：直接修改+即时验证"]
U3["📝 U3：轻量收尾"]
UDONE["🏁 完成"]
U1 --> SAFE{"安全护栏检查"}
SAFE -->|"通过"| U2
SAFE -->|"降级"| DOWNGRADE["⚠️ 降级为快速模式"]
U2 --> UC{"用户确认"}
UC -->|"✅ 确认"| U3 --> UDONE
UC -->|"✏️ 调整"| U2
UC -->|"🔄 撤销"| UNDO["回退修改"]

```

> 触发条件：≤1文件 + ≤20行 + 定位明确 + 无需方案设计（需同时满足≥2个）
> 降级条件：涉及>1文件、>20行、上下游依赖、状态管理/异步/竞态、公共组件、需求歧义

---

## 5. 收尾模式（环节制 A→B→F→G→H）

```mermaid
flowchart TD
WA["📊 环节A：Diff分析"]
WB["🧹 环节B：清理调试代码"]
WF["📋 环节F：改动汇总"]
WG["🔎 环节G：L2完整审查"]
WH["📝 环节H：Commit+Devlog+Specs"]
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
WGR -->|"通过"| WH --> WDONE

```

> 灵活用法：「收尾」=完整流程 | 「不用检查」=跳过环节B | 「汇总改动」=A+F | 「只要commit」=环节H | 「帮我提交」=H+git commit

---

## 6. 统一收尾流程（wrapup-flow.md）— 调用方×环节矩阵

```mermaid
flowchart TD
subgraph MATRIX["调用方 × 环节矩阵"]
direction TB
MA["A. Diff分析<br/>quick-7 ✅ | full-7 ✅ | wrapup ✅"]
MB["B. 清理调试代码<br/>quick-7 ✅ | full-7 ✅ | wrapup ✅"]
MC["C. 可选链检查<br/>quick-7 ✅ | full-7 ✅ | wrapup ❌"]
MD["D. 即时验证<br/>quick-7 ✅ | full-7 ✅ | wrapup ❌"]
ME["E. TODO检查<br/>quick-7 ✅ | full-7 ✅ | wrapup ❌"]
MF["F. 改动汇总<br/>quick-7 ❌ | full-7 ❌ | wrapup ✅"]
MG["G. L2审查<br/>quick-7 ✅ | full-7 ✅到此结束 | wrapup ✅"]
MH["H. Commit+Devlog+Specs<br/>quick-7 ✅ | full-7 ❌推迟 | wrapup ✅"]
MI["I. 轻量反思<br/>quick-7 ✅可选 | full-7 ❌ | wrapup ❌"]
MA --> MB --> MC --> MD --> ME --> MF --> MG --> MH --> MI
end

```

---

## 7. 阶段0：需求理解（完整模式独有）

```mermaid
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
UC -->|"❓ 疑问"| ASK

```

---

## 8. 步骤1~4.5 子流程

### 步骤1：研究与定位

```mermaid
flowchart TD
S1["步骤1开始"] --> SPEC{"项目规范存在?"}
SPEC -->|"是"| SPECL["加载模块规范"]
SPEC -->|"否"| SEARCH["搜索相关文件+上下游链路"]
SPECL --> SEARCH
SEARCH --> FIGMA{"有Figma?"} -->|"是"| FIGP["处理设计稿"] --> DOMAIN
FIGMA -->|"否"| DOMAIN{"不熟悉领域?"}
DOMAIN -->|"是"| DK["领域知识补充+确认"] --> OUTPUT
DOMAIN -->|"否"| OUTPUT["输出相关文件表格"]

```

### 步骤2：确认范围

```mermaid
flowchart TD
S2["步骤2开始"] --> RPT["输出影响范围报告"] --> BRANCH["分支建议"]
BRANCH --> UC{"用户确认"}
UC -->|"✅ 确认"| LOCK["锁定范围"]
UC -->|"✏️ 补充"| RPT
UC -->|"🔄 重新分析"| BACK["回退步骤1"]

```

### 步骤3：制定方案

```mermaid
flowchart TD
S3["步骤3开始"] --> DA["调用 design-advisor"]
DA --> GRADE{"复杂度?"}
GRADE -->|"低"| STD["标准模式计划"]
GRADE -->|"高"| DTL["详细模式计划"]
STD --> PLAN["输出执行计划"]
DTL --> PLAN

```

### 步骤4：用户决策（门控）

```mermaid
flowchart TD
S4["汇报方案"] --> UC{"用户决策"}
UC -->|"✅ 执行"| LOCK["锁定计划"]
UC -->|"✏️ 修改"| S4
UC -->|"🔄 换方案"| BACK3["回退步骤3"]
UC -->|"⏸️ 暂存"| PAUSE["暂存"]
UC -->|"❌ 取消"| CANCEL["终止"]

```

### 步骤4.5：环境检查

```mermaid
flowchart TD
GIT["git branch --show-current"] --> CHK{"分支检查"}
CHK -->|"主干分支"| WARN["⚠️ 警告+推荐分支"]
CHK -->|"开发分支"| OK["✅ 无需切换"]
CHK -->|"其他分支"| WARN2["⚠️ 可能错误分支"]
WARN --> UC{"确认"} -->|"就绪"| NEXT["→ 步骤5"]
OK --> UC
WARN2 --> UC

```

---

## 9. 步骤5~7 子流程

### 步骤5：执行修改

```mermaid
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
EXEC -.->|"无法执行"| BLOCK["回退步骤4"]

```

### 步骤5.5：编码后置钩子

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
CERR -->|"否"| PASS["→ 步骤6"]

```

### 步骤6：质量验证（6A+6B+6C）

```mermaid
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
FUSE -->|"否"| B6 --> C6

```

### 步骤7：清理+Commit（统一收尾流程）

```mermaid
flowchart TD
subgraph Q7["快速模式步骤7（caller=quick-7）"]
direction TB
QA["A.Diff分析"] --> QB["B.清理调试代码"]
QB --> QC["C.可选链检查"] --> QD["D.即时验证"]
QD --> QE["E.TODO检查"] --> QG["G.L2审查"]
QG --> QH["H.Commit+Devlog+Specs"]
QH --> QI["I.轻量反思（可选）"]
end
subgraph F7["完整模式步骤7（caller=full-7）"]
direction TB
FA["A.Diff分析"] --> FB["B.清理调试代码"]
FB --> FC["C.可选链检查"] --> FD["D.即时验证"]
FD --> FE["E.TODO检查"] --> FG["G.L2审查"]
FG --> FEND["到此结束→步骤8"]
end

```

> 快速模式步骤7执行全部环节（A→B→C→D→E→G→H→I），完整模式步骤7仅到G结束，H/I推迟到步骤10。

---

## 10. 完整模式独有步骤（8~10）

### 步骤8：L3代码审查

```mermaid
flowchart TD
L3["L3多视角深度审查<br/>安全+性能+可维护性+测试点位"]
L3 --> DOC["文档同步兜底"]
DOC --> SEV{"严重度?"}
SEV -->|"🔴"| BACK5["→步骤5修复"]
SEV -->|"🟡"| UD["用户决策"]
SEV -->|"🟢"| NEXT9["→ 步骤9"]
UD --> NEXT9
BACK5 -.-> L3

```

### 步骤9：反思与学习（数据驱动，4个子步骤）

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
S9D --> NEXT10["→ 步骤10"]

```

> 跳过条件：全程无回退、无卡顿、无用户纠正，且指标在历史平均±30%范围内时精简输出。

### 步骤10：归档与交付（6个子步骤）

```mermaid
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
CHK -->|"否"| FIX["补齐缺失项"] --> T6

```

> 10.6 校验项：①Commit已确认 ②devlog已生成 ③specs已沉淀 ④交付报告已输出 ⑤规则归档已处理

---

## 11. 特殊流程

### 迭代修复机制

```mermaid
flowchart TD
TRIG["触发信号：提测反馈/测试bug/继续需求"]
TRIG --> MATCH["匹配已有工作上下文"]
MATCH --> MR{"匹配到?"}
MR -->|"否"| NORMAL["正常流程"]
MR -->|"是"| READ["读取上下文"]
READ --> EVAL["复杂度评估"]
EVAL --> UC{"用户确认"}
UC -->|"按建议"| MODE{"复杂度?"}
UC -->|"调整"| EVAL
UC -->|"取消"| CANCEL["终止"]
MODE -->|"简单/中等"| QUICK["快速模式（增量）"]
MODE -->|"重大"| FULL["完整模式（增量）"]
QUICK --> DEVLOG["devlog追加 Round N"]
FULL --> DEVLOG

```

> 步骤简化：步骤1增量研究、步骤2增量范围、步骤3增量调整，步骤4~7/10无变化

### 回退机制

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

```mermaid
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
GATE -->|"否"| FIX["立即补齐"] --> GATE

```

> **分级钩子**：🔴重量级（完整校验）| 🟡中量级（关键字段校验）| 🟢轻量级（仅status+next_step）
> **原子操作**：动作2将工作上下文更新和.flow文件更新合并为一次操作，减少IO开销
> **状态快照**：仅步骤3/5/6创建快照，每需求最多5个，超出删除最早的

---

## 12. 交互模式（精简交互优化）

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
A1 --> A2["步骤4：一次性展示<br/>范围+方案"]
A2 --> A3{"用户决策"}
A3 -->|"✅ 执行"| A4["→ 步骤4.5"]
A3 -->|"范围有误"| A5["调整范围"] --> A1
A3 -->|"方案需改"| A6["修改方案"] --> A1
end

```

> 步骤2和3仍完整执行，只是合并展示和确认点。用户在步骤4一次性确认"范围+方案"。

### 步骤 7 合并审查报告

```mermaid
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
end

```

> 精简模式下，若清理全部✅且L2无🟡项，合并为一行摘要直接继续。

### 交互模式风险分级

```mermaid
flowchart TD
MODE{"交互模式?"}
MODE -->|"标准模式"| STD["所有交互点正常暂停<br/>4~7次交互"]
MODE -->|"精简模式"| SIM["按风险分级处理<br/>2~3次交互"]
SIM --> RED["🔴 关键决策点<br/>步骤4决策 / 步骤7 Commit<br/>→ 必须暂停"]
SIM --> YELLOW["🟡 质量决策点<br/>L1/L2审查🟡项 / 验证结果<br/>→ 智能默认，异常才打断"]
SIM --> GREEN["🟢 流程决策点<br/>研究结果 / 环境检查<br/>→ 一行摘要继续"]

```

> 精简模式仍输出步骤完成反馈（`✅ 步骤N完成：...`），不完全静默。

---

## 13. 源文件索引

| 文件 | 说明 |
| --- | --- |
| `SKILL.md` | 主入口，四模式设计+全局规则 |
| `full-mode.md` | 完整模式指引（阶段0+步骤8/9/10） |
| `quick-mode.md` | 快速模式指引（L0路由层） |
| `ultra-quick-mode.md` | 极速模式指引（3步：定位→修改→收尾） |
| `wrapup-mode.md` | 收尾模式指引（引用统一收尾流程） |
| `steps/step-router.md` | 步骤路由器（Prompt Chaining核心） |
| `steps/step-1-research.md` | 步骤1：研究与定位 |
| `steps/step-2-scope.md` | 步骤2：确认范围 |
| `steps/step-3-plan.md` | 步骤3：制定方案 |
| `steps/step-4-decision.md` | 步骤4：用户决策 |
| `steps/step-4.5-env-check.md` | 步骤4.5：环境检查 |
| `steps/step-5-execute.md` | 步骤5：执行修改 |
| `steps/step-5.5-post-coding.md` | 步骤5.5：编码后置钩子 |
| `steps/step-6-verify.md` | 步骤6：质量验证 |
| `steps/step-7-commit.md` | 步骤7：清理+Commit（引用统一收尾流程） |
| `references/wrapup-flow.md` | 统一收尾流程规范（9环节制） |
| `references/iteration-fix.md` | 迭代修复机制 |
| `references/quick-mode-rollback.md` | 回退对照表 |
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
| `references/shared-rules.md` | 共享规则 |
| `references/gate-validator.md` | 门控验证器 |
| `references/env-tools.md` | 环境工具（含 Git Worktrees） |
| `references/react.md` | React专题规范 |
| `references/component-library.md` | 组件库规范 |
| `references/flow-graph.md` | 流程图定义 |
