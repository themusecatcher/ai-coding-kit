---
description: dev-flow 帮助命令单一权威源（输出区块 + 参考区块）
loaded_by: --help / -h / dev:help / dev:h
routing: |
  dev:help（无参数）→ 输出 <!-- OUTPUT_END --> 以上的全部内容原文，禁止改写/裁剪/格式化，不进入步骤流程
  dev:help <命令名>  → 在「命令详情」中查找对应 CMD_DETAIL 标记的命令并输出详细说明
  dev:help modes     → 输出「模式速查」表格
last_updated: 2026-07-20
---

# dev-flow 帮助

系统化 AI 辅助编程开发工作流。从需求输入到代码交付，自动走完整流程（研究→方案→编码→验证→commit）。

## 快速上手

| 我想做什么 | 输入 |
| ----------- | ------ |
| 开发新功能 / 修 Bug | `dev-flow <描述你想做的事>` |
| 改个拼写、加个判空 | `--micro <文件路径> L<行号> <改什么>` |
| 同步所有文档 | `dev:sync` |
| 查看当前进度 | `dev:status` |
| 浏览所有功能 | `dev:ask` |

## 流程概览

```
阶段0 · 需求理解
步骤0.5 · 知识库检查（按需）
步骤1 · 研究与定位       →  步骤2 · 确认范围       →  步骤3 · 制定方案
步骤4 · 方案汇报与用户决策  →  步骤4.5 · 环境检查
步骤5 · 执行修改          →  步骤5.5 · 编码后置钩子
步骤6 · 质量验证          →  步骤7 · 清理+Commit
```

标准模式执行到步骤 7 结束，完整模式继续步骤 8·L3审查→9·反思与学习→10·归档与交付。

## 命令大全

### 流程入口
<!-- CMD_TABLE:process_entry -->
| 命令 | 模式 | 说明 |
| ------ | ------ | ------ |
| `dev-flow` | `[标准]` | 进入标准开发流程，步骤 4 智能推荐执行深度 |
| `--micro <描述>` | `[快速]` | 轻量快速修复：≤3 文件 + ≤10 行/文件 + 已知位置 |
| `dev:fix --drift` | `[标准]` | 显式触发需求漂移处理，完成后自动同步文档 |
| `dev:fix --iteration` | `[迭代]` | 显式触发迭代修复，自动匹配已有工作上下文 |

### 管理命令
<!-- CMD_TABLE:management -->
| 命令 | 别名 | 说明 |
| ------ | ------ | ------ |
| `dev:status` | `dev:st` | 当前流程进度概览 |
| `dev:status --trace` | — | 实时观测 Token/红牌/步骤耗时 |
| `dev:sync` | `dev:s2` | 全量文档同步（devlog + knowledge + 文档平台） |
| `dev:kb` | `dev:k` | 知识库管理（查看/扫描/搜索/沉淀/健康度） |
| `dev:metrics` | `dev:m` | 度量查看（--all / --trend / --report / --dashboard） |
| `dev:onboard` | `dev:ob` | 新项目首次接触 / 知识库平台 profile 刷新 |
| `dev:flowchart` | `dev:chart` | 生成/更新 dev-flow 流程图（md + html + png） |
| `dev:ask` | `dev:guide` | 交互式功能菜单，覆盖所有 dev-flow 功能 |

### 流程内信号（仅 dev-flow 激活时生效）

| 场景 | 你可以说 |
| ------ | --------- |
| 迭代修复 | `提测反馈` / `继续上次需求` / `后端接口好了` |
| 需求变更 | `产品说...` / `刚和 XX 对齐了` / `需求变了` / `其实是` |
| 分批继续 | `继续下一批` / `batch 2` |
| 跨项目衔接 | `跨项目修复衔接` / `跨项目验证衔接` |
| 调整交互 | `少问我` / `你决定就好`（精简）/ `每步都问我`（恢复） |

### 修饰
<!-- CMD_TABLE:modifier -->
| 修饰 | 作用 |
| ------ | ------ |
| `--fast` | 精简交互，大幅减少确认次数，不减步骤、不降门控 |

## 模式速查
<!-- MODE_TABLE -->
| 模式 | 适用场景 | 步骤 |
| ------ | --------- | ------ |
| `standard` | 常规开发 | 0→7（全程，含 0.5/4.5/5.5） |
| `full` | 重要需求、需归档 | 0→10（含 8·审查/9·反思/10·归档） |
| `micro-fix` | 拼写/判空/调参数 | 0→4.5→5→5.5→6→7 |
| `iteration-fix` | 提测反馈 | 0→1(增量)→2(增量)→3(增量)→4.5→5→5.5→6→7 |
| `batch` | 大批量改动（>5 文件或 >300 行） | 0→7 循环 |
| `cross-project` | 多仓库 | 0→7（跨 workspace） |

## 常见工作流

| 我想做什么 | 使用命令 |
| ----------- | --------- |
| 开发新功能 / 修 Bug | `dev-flow <描述>`，步骤 4 选择执行深度 |
| 改个拼写/加个判空 | `--micro <文件路径> L<行号> <改动内容>` |
| 提测后修反馈 | 流程内说 `继续上次需求` |
| 产品改需求 | 流程内说 `--drift` 或自然描述变更 |
| 从上次中断处继续 | 自然描述相关话题，自动恢复 |
| 同步所有文档 | `dev:sync` |
| 搜索/沉淀项目代码知识 | `dev:kb` |
| 查看历史效率数据 | `dev:metrics --trend` |
| 不知道用什么功能 | `dev:ask` |

---

使用 `dev:help <命令>` 查看特定命令详情  |  使用 `dev:help modes` 仅查看模式速查  |  `dev:ask` 交互式功能菜单

全文规范：`skills/dev-flow/SKILL.md`
模式矩阵：`skills/dev-flow/references/mode-matrix.md`

<!-- OUTPUT_END -->

<!-- ═══════════════════════════════════════════ -->
<!-- 以下为参考区块：dev:help <命令> 时在此查找对应 CMD_DETAIL 标记 -->
<!-- ═══════════════════════════════════════════ -->

## 进入方式

dev-flow 有多种入口方式，无需死记，自然表达即可：

| 方式 | 说明 | 示例 |
| ------ | ------ | ------ |
| 显式命令 | 主动输入流程命令 | `dev-flow 开发用户中心页` |
| 交互式菜单 | 不知道用什么？输入 `dev:ask` 弹出分类引导菜单 | `dev:ask` → 选中即执行 |
| 活跃流程恢复 | 上次没做完？直接说相关的话，AI 自动续上 | `继续修上次那个登录 bug` |
| 文档同步关键词 | 说 `同步文档` / `全量同步` / `检查文档` / `更新文档` | 自动触发 `dev:sync` |
| AI 主动建议 | 说 `修复 xxx`、发 任务平台/Figma 链接时，AI 会建议你用 dev-flow | 你决定用不用，说「直接改」可跳过流程 |

> `dev-flow` 与 `/dev-flow` 完全等价（加不加 `/` 均可）。使用 `--help` / `-h` / `dev:help` / `dev:h` 随时查看此帮助。

## 快速示例

```text
# 流程入口
dev-flow                                            # 标准开发
dev-flow --fast 修复登录页样式问题                     # 精简交互
--micro 修复 src/utils/format.ts L42 的拼写             # 快速修复

# 流程内使用
继续上次需求                                          # 迭代修复（自动恢复）
少问我                                                # 精简交互模式
继续下一批                                            # 分批执行

# 管理命令
dev:sync                                             # 同步所有文档
dev:status                                           # 查看进度
dev:status --trace                                   # 实时观测
dev:kb                                               # 知识库
dev:metrics --trend                                  # 趋势分析
dev:onboard                                          # 项目接入
dev:flowchart                                        # 生成流程图
dev:ask                                              # 交互式功能菜单
dev:metrics                                          # 查看度量

# 帮助
dev:help                                             # 完整帮助
dev:help modes                                       # 仅看模式速查
dev:help --micro                                     # 仅看 --micro 命令详情
```

## 命令详情

<!-- CMD_DETAIL:dev-flow -->
### dev-flow / dev:

- **类型**: 流程入口
- **别名**: `dev:` / `/dev-flow`
- **模式**: 标准 / 完整 / 分批（步骤 4 决定）
- **说明**: 进入统一开发流程。所有需求走同一入口，执行深度由步骤 4 智能评估推荐
- **组合**: 可与 `--fast` 叠加；流程内可用 `--drift` / `--iteration`
- **相关**: 流程结束时自动在步骤 7 生成 commit message（格式 `<type>: <description>`）
<!-- /CMD_DETAIL:dev-flow -->

<!-- CMD_DETAIL:--micro -->
### --micro <描述>

- **类型**: 流程入口（快速通道）
- **模式**: micro-fix
- **条件**: ≤3 文件 + ≤10 行/文件 + 用户已知修改位置
- **降级**: 实际改动 >15 行 或 >3 文件 或 不对称修改 → 自动降级为标准流程
<!-- /CMD_DETAIL:--micro -->

<!-- CMD_DETAIL:--fast -->
### --fast

- **类型**: 修饰（可叠加任意命令）
- **说明**: 精简交互频率。绿色流程推进 + 黄色质量检查自动决策，红色关键决策（commit/主干/文档方案）仍暂停确认
- **效果**: 大幅减少交互确认次数，不减步骤、不降门控
- **切换**: 流程中随时说 `少问我` 或 `你决定就好` 进入精简模式，`每步都问我` 恢复标准模式
<!-- /CMD_DETAIL:--fast -->

<!-- CMD_DETAIL:dev:fix --drift -->
### dev:fix --drift

- **类型**: 显式命令（新对话/流程内外均可使用）
- **说明**: 显式触发需求漂移处理。产品改需求或方案对齐后使用，完成后自动调用 dev:sync 同步下游文档
- **对比流程内信号**: 流程内直接说 `--drift` 或描述变更即可，无需输入完整命令
<!-- /CMD_DETAIL:dev:fix --drift -->

<!-- CMD_DETAIL:dev:fix --iteration -->
### dev:fix --iteration

- **类型**: 显式命令（新对话/流程内外均可使用）
- **说明**: 显式触发迭代修复。提测反馈或后端接口就绪后使用，自动匹配已有工作上下文
- **对比流程内信号**: 流程内直接说 `继续上次需求` 即可，无需输入完整命令
<!-- /CMD_DETAIL:dev:fix --iteration -->

<!-- CMD_DETAIL:--drift -->
### --drift（流程内信号）

- **类型**: 流程内信号（仅 dev-flow 激活时生效）
- **说明**: 处理需求漂移。完成后自动调用 dev:sync 同步下游文档
- **触发词**: `产品说` / `刚和 XX 对齐` / `需求变了` / `其实是`
<!-- /CMD_DETAIL:--drift -->

<!-- CMD_DETAIL:--iteration -->
### --iteration（流程内信号）

- **类型**: 流程内信号（仅 dev-flow 激活时生效）
- **说明**: 触发迭代修复。自动匹配已有工作上下文，增量执行
- **触发词**: `提测反馈` / `继续上次需求` / `后端接口好了`
<!-- /CMD_DETAIL:--iteration -->

<!-- CMD_DETAIL:dev:sync -->
### dev:sync / dev:s2

- **类型**: 管理命令（流程内外均可使用）
- **说明**: 全量文档同步（devlog + knowledge + 技术方案文档）
- **流程内模式**（dev-flow 激活时）：同步当前需求的文档，自动识别需同步的范围
- **流程外模式**（独立调用）：自动匹配最近的工作上下文进行同步
- **自动触发节点**：AI 在 5.5 累计 ≥3 次、完整模式追加改动、drift 完成后等节点主动弹框提醒
- **重要**: `dev:sync` 是补救兜底，不是日常 `5.5b 文档同步` 的替代品
<!-- /CMD_DETAIL:dev:sync -->

<!-- CMD_DETAIL:dev:status -->
### dev:status / dev:st

- **类型**: 管理命令
- **说明**: 扫描活跃流程文件和工作上下文，展示当前进度（步骤/模式/交互方式）
- **选项**: `--trace` 实时观测 Token 消耗、红牌次数、步骤耗时
<!-- /CMD_DETAIL:dev:status -->

<!-- CMD_DETAIL:dev:kb -->
### dev:kb / dev:k

- **类型**: 管理命令
- **说明**: 项目代码知识库管理。支持查看/扫描/搜索/沉淀/健康度检查
- **示例**: `dev:kb` 弹出交互式选项（查看模块/扫描代码/检查健康度）
<!-- /CMD_DETAIL:dev:kb -->

<!-- CMD_DETAIL:dev:metrics -->
### dev:metrics / dev:m

- **类型**: 管理命令
- **说明**: 开发流程度量数据查看
- **选项**: `--all` 全部历史 / `--trend` 趋势分析 / `--report <ID>` 指定需求 / `--dashboard` 可视化仪表盘
<!-- /CMD_DETAIL:dev:metrics -->

<!-- CMD_DETAIL:dev:onboard -->
### dev:onboard / dev:ob

- **类型**: 管理命令
- **说明**: 新项目首次接触时生成 知识库平台 profile（L0 缓存），或手动刷新已有 profile
- **选项**: `--refresh`/`-r` 全量刷新 / `--refresh-recent`/`-rr` 增量刷新 / `--check`/`-c` 只校验不刷新
<!-- /CMD_DETAIL:dev:onboard -->

<!-- CMD_DETAIL:dev:ask -->
### dev:ask / dev:guide

- **类型**: 管理命令
- **说明**: dev-flow 全功能交互式入口。弹出分类菜单，逐级引导到具体命令，选中即执行
- **别名**: `dev:guide`
- **特点**: 状态感知（根据当前是否有活跃流程动态显示选项）、场景向导（不确定用什么时帮你判断）
<!-- /CMD_DETAIL:dev:ask -->

<!-- CMD_DETAIL:dev:flowchart -->
### dev:flowchart / dev:chart

- **类型**: 管理命令
- **说明**: 生成/更新 dev-flow 流程图，输出 md + html + png 三种格式。支持覆盖当前版本、另存新版本两种更新方式
<!-- /CMD_DETAIL:dev:flowchart -->

<!-- CMD_DETAIL:dev:help -->
### dev:help / dev:h

- **类型**: 帮助命令
- **说明**: 显示本帮助。支持 `dev:help <命令>` 查看单条命令详情，`dev:help modes` 仅查看模式速查
<!-- /CMD_DETAIL:dev:help -->
