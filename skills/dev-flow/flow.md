# dev-flow 开发流程详细指引

> 本文件为 dev-flow 的唯一流程定义文件，不随 SKILL.md 主体一起加载。
> **Prompt Chaining 架构**：本文件为 L0 核心路由层，只包含流程总览和全局规则。
> 每个步骤的详细规范已拆分到 `steps/` 目录下的独立文件中，按需加载。

## 全局输出规范（最高优先级）

> 所有步骤/环节的文本输出中，**文件路径、目录、代码位置引用**必须遵循 `~/.codebuddy/rules/AI行为规范.mdc` 的「文件/代码位置引用」规范（反引号包裹相对路径 `` `相对路径` `` + 空格后缀行号 `L行号`，IDE 自动识别为可点击链接）。
>
> **适用范围**：所有步骤的报告/表格/正文（影响范围、改动汇总、批次规划、交付报告、合并审查、研究结果、问题定位等）。
>
> **例外**：YAML/JSON 结构化字段、代码块内代码、反引号名词性引用。
>
> **强制校验**：由 `references/gate-validator.md` 的「路径可点击性门控」执行正则扫描，违规视为步骤未完成。

## 全局交互式选项规范（最高优先级）

> dev-flow 流程中所有的**用户决策点**和**步骤流转衔接点**，必须同时遵循以下两份规范（单一真相源，本文件不重复定义细节）：
>
> 1. **`~/.codebuddy/rules/AI行为规范.mdc` §「交互式选项一致性规则」**（全局基线）：
>    - 文本选项表格 + `ask_followup_question` **双重展示**，逐条一一对应
>    - 编号一致（以表格为基准），先写表格再写选项
>    - 条件性隐藏时同步移除并顺延编号
>    - 调用前逐条核对：表格行数 === options 数组长度
>
> 2. **`steps/step-router.md` §「交互式决策强制规则」+ §「步骤流转交互规则」**（dev-flow 专属）：
>    - 决策点清单（所有必须调用 `ask_followup_question` 的位置）
>    - 步骤流转推进选项标准模板（A 继续 / B 暂停 / C 回退）
>    - 精简模式豁免范围（哪些步骤流转可静默推进）
>    - 红牌行为定义（违反即立即停止）
>
> **执行要求**：
>
> - ✅ 所有步骤文件/reference 中标注「弹出交互式选项」的位置 → **必须**使用 `ask_followup_question` 工具，禁止用"弹出选项"等模糊措辞
> - ✅ 所有步骤完成后（标准模式）→ **必须**调用 `ask_followup_question` 弹出推进选项
> - ❌ 仅用文本表格不调用 `ask_followup_question` → 违反红牌 #7
> - ❌ 仅调用 `ask_followup_question` 不展示文本表格 → 违反红牌 #7
> - ❌ 步骤完成后只用纯文字"继续进入步骤 X？" → 违反红牌 #13
>
> **强制校验**：由 `references/gate-validator.md` §「交互式选项一致性门控」执行半自动校验，违规视为步骤未完成。

## 核心理念

> **单一流程 + 智能评估**。所有需求走同一条流程，执行深度由步骤4智能评估推荐。
> 所有入口（`dev-flow` / `dev:`）等价，不预设执行深度。
> 在步骤 4（方案确认）时，完全基于步骤 1~3 的研究成果智能评估推荐执行深度：
>
> - **快捷执行**（步骤 5→7 极简版）：仅编码 → 极简审查 → ESLint → 极简 commit。跳过完整 L1/L2 审查、devlog、文档平台
> - **标准执行**（步骤 5→7）：编码 → 验证 → L2审查+commit+devlog+knowledge
> - **完整执行**（步骤 5→10）：编码 → 验证 → 清理 → L3深度审查 → 反思 → 归档
> - **分批执行**（步骤 5→7 循环）：大型需求拆分为多批次，每批独立走 4.5→5→5.5→6→7 循环，最后一批执行完整收尾
>
> 用户在步骤 4 可自由覆盖 AI 推荐。

### 产出物真实性原则（强制，高于所有步骤模板）

> **产出长度由事实决定，不由模板决定。简单任务的简短产出是合规的、期望的。**
> **但"简短"必须基于充分研究，不得以简化为名行跳步之实。**

1. **忠实反映事实**：每个步骤的产出物是流程的**观测结果**，不是**设计目标**。实际影响 1 个文件就写 1 行，实际影响 10 个文件就写 10 行。
2. **禁止编造填充**：禁止为填满模板而编造内容。具体包括：
   - 禁止"硬凑方案 B/C"——只有 1 个合理方案时，明确写"唯一方案"即可
   - 禁止"硬列不存在的风险"——风险栏如无真实风险，写"无"
   - 禁止"硬写不存在的依赖"——上下游依赖数组可为 `[]`
   - 禁止"硬扩充文件清单"——不相关文件不进表格
3. **证伪式标注**（替代"允许省略"）：若某子区块事实为空，**不得静默省略**，必须显式标注"无"并给出**证伪理由**：
   - ✅ 合规：`### 上下游依赖\n> 无（已 grep "validator" 确认无其他文件 import 该函数）`
   - ❌ 违规：静默省略整节（无法审计 AI 是否真的做过检查）
   - ❌ 违规：仅写"无"而无理由（无法区分"确认为空"与"未检查"）
4. **不跳步，但允许极简**：每个步骤仍须走完（保留门控），但允许**极简形态的产出**——例如步骤 3 的方案可以是 1 句话（"改 validator.ts:45 的正则为 RFC 5322 简化版"）。
5. **极简模式有硬性准入**：步骤 3 极简模式不是 AI 自由选择，须满足**基于步骤 1/2 JSON 产出的机器可校验准入清单**（详见 `steps/step-3-plan.md`）。任一准入条件不满足 → 自动禁用极简模式。
6. **反"伪装简化"原则**：AI 必须警惕"看似简单但实际中等"的任务（如"修复登录失败率高"）。描述简短 ≠ 实际简单。充分性校验不通过时（详见 `steps/step-1-research.md` `sufficiency_check`），**禁止进入下一步**，必须补充搜索。
7. **简短不是偷懒**：AI 对简单任务输出简短产出，是正确行为；输出冗长模板反而违反本原则。**但简短必须是充分研究的结果，不是跳过研究的结果。**

## 架构说明

```text
加载 flow.md（L0 路由，~260 行）
  → 阶段 0：需求理解（调用 requirement-intake）
  → 步骤 N 开始时：read_file("steps/step-N-xxx.md") 加载该步骤详细规范
  → 步骤 N 完成后：输出结构化完成标记 JSON
  → 门控验证 JSON 完整性（Schema 校验 + 文字规则双层）
  → 进入步骤 N+1
  → 步骤 4 选择执行深度：标准（→步骤7结束）或 完整（→步骤10结束）
```

## 阶段 0：需求输入与理解

> **所有需求（无论大小）都必须经过阶段 0**。产出准确性是第一优先级，不理解需求就无法准确执行。

**执行**：调用 `use_skill("requirement-intake")` 加载完整需求理解流程。

### 分支命名（仅当用户主动告知时记录，AI 不预告）

> 分支推荐**仅在步骤 4 §4.1**（计划锁定后、磁盘保存前）唯一定稿。
>
> - 用户在需求描述中**主动告知**分支名 → 写入工作上下文 `branch` + `branch_status: "user_specified"`，跳过步骤 4 §4.1 推荐
> - 用户**未告知** → 置 `branch_status: "pending_step_4"`，本阶段不输出任何分支名
>
> 推荐规则、命名格式、自动推荐规则、孙分支策略详见 `references/shared-rules.md` §6（单一真相源）。❌ 禁止自动执行 `git checkout -b`。

### Figma 设计稿处理

用户提供 Figma 设计稿链接时 → `read_file("references/figma-flow.md")` 加载完整处理流程（两级策略）。

### 迭代修复场景的阶段 0 简化

当通过迭代修复机制进入时，阶段 0 执行增量理解而非全量理解。
详见 `references/iteration-fix.md`。

> 📋 **阶段 0 完成钩子**：需求理解确认后，输出结构化完成标记 JSON，更新工作上下文。

```json
{
  "step": 0,
  "name": "需求理解",
  "status": "completed",
  "outputs": {
    "requirement_confirmed": true,
    "branch_user_specified": "用户主动告知的分支名（仅 user_specified 时填，否则为空字符串）",
    "branch_status": "user_specified | pending_step_4",
    "figma_processed": "true | false | not_applicable",
    "remote_kb_available": "unknown（v2：阶段 0.5 不再探测 知识库平台，交由步骤 1 的信号 1/4 判定）"
  },
  "working_context_updated": true,
  "next_step": 0.5
}
```

## 阶段 0.5：项目画像轻量注入

## 阶段 0.5：项目画像轻量注入（默认沉默，仅本地 profile 命中时执行）

> **重要变更**（v2）：本阶段不再默认读映射表、不再调 MCP。默认沉默跳过，仅在本地 `_profile.md` 存在且未过期时将其注入上下文。所有 MCP 调用已迁移到「节点信号」触达（详见 [remote-knowledge.md](./references/remote-knowledge.md)）。
>
> **目的**：如用户已 `dev:onboard` 生成过 profile，在步骤 1 之前将其注入为项目全景上下文；其余场景一律跳过。
> **成本**：0 MCP 调用（0 token）；仅 `read_file` 一次本地 profile。

### 触发条件（严格限定）

仅当 `~/.codebuddy/knowledge/{project}/_profile.md` **存在且未过期**时执行；其余场景沉默跳过，标记 `stage_0_5_status=skipped`。

过期判定按 [onboard-flow.md](./references/onboard-flow.md) §五（soft_ttl=14 天，hard_ttl=45 天）。

### 迭代修复豁免

迭代修复场景自动跳过（上一轮工作上下文已有 project_profile，直接复用）。

### 执行步骤（极轻量）

1. **检查本地 profile**：`ls ~/.codebuddy/knowledge/{project}/_profile.md`
   - 不存在 → `stage_0_5_status=skipped_no_profile`，直接进入步骤 1（**不自动提示 `dev:onboard`**，让用户主动决策）
   - 存在 → 进入第 2 步
2. **读取并校验新鲜度**：`read_file(profile)` → 检查 `last_verified` 时间戳
   - <14 天（fresh）→ 完整注入，`stage_0_5_status=loaded_fresh`
   - 14-45 天（soft_expired）→ 注入 + 末尾弱提醒（"profile 已 {N} 天未验证"），`stage_0_5_status=loaded_stale_soft`
   - >45 天（hard_expired）→ 注入 + 强提醒，推荐用户 `dev:ob -r` 刷新，`stage_0_5_status=loaded_stale_hard`
3. **注入上下文**（仅摘要，不调 MCP）：

```yaml
project_profile:
  source: "local_profile"
  profile_path: "~/.codebuddy/knowledge/{project}/_profile.md"
  tech_stack: "{从 profile frontmatter 提取}"
  core_modules: ["{从 profile 提取，≤5 个}"]
  last_verified: "{ISO 时间戳}"
  freshness: "fresh | soft_expired | hard_expired"
```

### 降级策略

- `read_file` profile 失败 → `stage_0_5_status=skipped_read_error`，不阻塞步骤 1
- Token 预算硬性门控：注入的 `project_profile` 序列化后 ≤ 300 token

### 完成标记

```json
{
  "step": 0.5,
  "name": "项目画像轻量注入",
  "status": "completed | skipped",
  "outputs": {
    "stage_0_5_status": "loaded_fresh | loaded_stale_soft | loaded_stale_hard | skipped_no_profile | skipped_iteration_fix | skipped_read_error",
    "project_profile_loaded": "true | false",
    "mcp_calls_made": 0,
    "remote_kb_available": "unknown（阶段 0.5 不再探测 知识库平台 可用性；交由步骤 1 的信号 1/4 判定）"
  },
  "working_context_updated": true,
  "next_step": 1
}
```

> 本阶段属于极轻量钩子，**不加入入门钩子必选项**；跳过（skipped）不视为流程违规。绝大多数 dev-flow 会命中 `skipped_no_profile`（默认状态）。

## 步骤执行协议

**加载步骤路由器**：`read_file("steps/step-router.md")` 获取完整的步骤执行协议、流程总览表、
门控验证规则和红牌行为定义。路由器是步骤间导航的唯一权威来源。

## 流程总览（阶段 0 + 步骤 1~10）

> 所有需求走同一条流程。步骤 4 选择执行深度后，标准执行在步骤 7 结束，完整执行继续到步骤 10。
> 📌 步骤名称以 step-router.md 为准，本表侧重核心产出概览。修改步骤名称时须同步更新 step-router.md 和 steps/README.md。

| 步骤 | 名称 | 加载文件 | 核心产出 | 执行深度 |
| --- | --- | --- | --- | --- |
| 0 | 需求理解 | `use_skill("requirement-intake")` | 需求确认 + 分支告知收集（仅 user_specified） | 全部 |
| 0.5 | 项目画像轻量注入（默认沉默） | `read_file(_profile.md)` 仅本地，0 MCP | project_profile 或 skipped | 本地 profile 存在且未过期时执行，其余跳过 |
| 1 | 研究与定位 | `steps/step-1-research.md` | 相关文件表格 | 全部 |
| 2 | 确认范围 | `steps/step-2-scope.md` | 影响范围报告 + 用户确认 | 全部 |
| 3 | 制定方案 | `steps/step-3-plan.md` | 执行计划表格 | 全部 |
| 4 | 方案汇报与用户决策 | `steps/step-4-decision.md` | 评估卡片+执行深度选择+分支名最终推荐（§4.1） | 全部 |
| 4.5 | 环境检查 | `steps/step-4.5-env-check.md` | 分支确认（父孙等价） | 全部 |
| 5 | 执行修改 | `steps/step-5-execute.md` | 代码改动 | 全部 |
| 5.5 | 编码后置钩子 | `steps/step-5.5-post-coding.md` | L1审查+文档同步+自检 | 全部 |
| 6 | 质量验证 | `steps/step-6-verify.md` | 验证报告（6A/6B/6C） | 全部 |
| 7 | 清理+Commit | `steps/step-7-commit.md` | L2审查+commit+devlog | 全部 |
| 8 | L3 代码审查 | `steps/step-8-10-full.md` | L3多视角深度审查 | 仅完整执行 |
| 9 | 反思与学习 | `steps/step-8-10-full.md` | 度量报告+经验提炼 | 仅完整执行 |
| 10 | 归档与交付 | `steps/step-8-10-full.md` | commit+devlog+knowledge+交付报告 | 仅完整执行 |

## 执行入口

**阶段 0 开始**：

```text
0. 执行阶段 0：需求理解（调用 requirement-intake）
0.5 执行阶段 0.5：项目画像预注入（仅映射表命中时）
1. 阶段 0 完成后，read_file("steps/step-router.md")  ← 加载步骤路由器
2. read_file("steps/step-1-research.md")  ← 加载步骤 1 详细规范
3. 按步骤 1 规范执行
4. 输出步骤 1 结构化完成标记 JSON
5. 门控验证通过后，read_file("steps/step-2-scope.md") 加载步骤 2
6. 依此类推...
7. 步骤 4 选择执行深度：
   - 标准执行 → 步骤 5~7 → 流程结束
   - 完整执行 → 步骤 5~7(裁剪) → 步骤 8~10 → 流程结束
   - 分批执行 → 步骤 4.5~7 循环（每批） → 最后一批完整收尾 → 流程结束
```

## 流程内同步入口（`dev:sync` / `dev:s2`）

> **设计意图**：dev-flow 流程进行中（任意步骤），用户可主动召唤全量文档同步；AI 在关键节点（5.5 静默累计 ≥3 / 完整模式跨步骤真空期）也会主动弹框提醒。
> 适用于：流程内多轮修复后想统一同步文档、完整模式步骤 7 后到步骤 10 之间追加改动需登记。
> `dev:sync` 复用 `closeout-flow.md §H.0~H.3+` 的文档同步子集（caller=in-flow-sync），跳过 commit/L2-L3/度量/K，零重复逻辑。

### 触发识别

`dev:sync` / `dev:s2` / "同步文档" / "全量同步" / "检查文档" / "更新文档" → 加载 `references/in-flow-sync.md` 获取完整流程。

### 冷启动路由

```text
用户输入 dev:sync / dev:s2
  → read_file("references/in-flow-sync.md")
  → ① 检查 .flow 文件
       ├─ 不存在 → 提示用户先使用 dev-flow 进入流程
       └─ 存在 → 暂存 current_step 到 sync_from_step
  → ② 执行 H.0+H.2+H.3+H.3+ 文档同步子集（跳过 commit/L2-L3/度量/K）
  → ③ 弹出最终用户决策（apply_all / partial / report_only / cancelled）
  → ④ 恢复 .flow（current_step={原步骤号}, status=active, silent_55_count=0）
  → ⑤ 输出完成标记 → 自动回到原步骤继续
```

## 启动模式识别（冷启动 vs 热启动）

> **设计目标**：热启动（活跃流程恢复）跳过已完成步骤的定义文件加载，节省 Token。
>
> **2026-06-01 改版前提**：dev-flow 仅由**显式命令**或**活跃流程相关恢复**触发（详见 SKILL.md §「触发规则」）。本章节描述的是触发后的内部启动逻辑。

### 冷启动（首次进入 dev-flow）

触发条件：用户输入显式命令（`dev-flow` / `dev:` 等），且 `.active-flows/` 下无匹配的 `.flow` 文件，或用户明确开始新需求。

```text
执行完整流程：阶段 0 → 0.5 → 步骤 1 → 2 → ... → 7/10
加载所有必要 reference（按条件激活矩阵）
```

### 热启动（活跃流程恢复）

触发条件（**两个条件须同时满足**）：

1. `.active-flows/{name}.flow` 存在，且 `status` 为 `active`/`idle`/`blocked-*` 之一
2. **用户消息内容与该 .flow 的 `match_keywords` / `brief` 相关**（纯咨询/元讨论/无关消息**不触发恢复**）

```text
1. 读取 .flow 锁文件，获取 current_step + phase + recovery + match_keywords + last_commit_hash + session_id
2. 🆕 运行健康检查（≤3 秒，不阻塞恢复）：
   bash ~/.codebuddy/skills/dev-flow/scripts/harness/health-check.sh <flow-name> --mode hot-start
   - 退出码 2（仅警告）→ 恢复输出末尾追加「⚠️ 发现 N 个状态不一致，建议执行 dev:sync 或检查后再继续」
   - 退出码 1（阻断）→ 恢复输出末尾追加「🔴 发现严重状态不一致，建议先修复再继续」
   - 退出码 0 或 3 → 静默跳过
3. 采用「L1 极速恢复」策略：先不读工作上下文 .md，仅基于 .flow 生成「3 句话回忆杀」输出
4. 用户确认后才读工作上下文文件，按需提取 ## 进度 / ## 编码进度细节 / ## 联调暂存 / ## 迭代轮次详情 区块
5. 跳到 current_step，加载 read_file("steps/step-{current_step}-xxx.md") 继续执行
6. 若 last_active 距今 > 24h：补做轻量 git 对账（见下方「24h+ 跨天对账」）
```

**Token 节省**：L1 极速恢复仅读 1 个 < 1KB 的 .flow，跨会话恢复首响耗费 ≈ 0；后续按需加载最多节省 20k+ tokens。

#### L1 极速恢复输出模板（3 句话回忆杀，高置信需求必用）

```markdown
🔄 已恢复需求：**{brief}**（步骤 {current_step} · {phase}）

**当前方案**：{recovery.current_plan_summary}  ← ⚠️ 编码前必读，作为本会话内方案唯一权威源；若与工作上下文 ## 需求 §「当前执行方案 vN」时间戳不一致以工作上下文为准并提醒用户
**昨天我们做了什么**：{recovery.yesterday}
**今天准备做什么**：{recovery.next_action}
{若 recovery.pending 非空} **待确认**：
- {pending[0]}
- {pending[1]}
```

输出以上模板后，**必须使用 `ask_followup_question` 弹出交互式选项**（禁止用自然语言提问）：

| 选项 | 说明 |
| --- | --- |
| ✅ 按计划继续 | 需求/方案无变化，按 {recovery.next_action} 进入步骤 {N} |
| ✏️ 需求或方案有变化 | 我先补充最新情况 → AI 进入 drift-handling 或重新评估 |
| 📋 先看详细上下文 | 打开工作上下文完整信息，确认后再决定 |
| ❌ 先不继续 | 退出 dev-flow，普通对话 |

若 `last_active` 距今 > 24h，额外追加：

| 选项 | 说明 |
| --- | --- |
| 🔍 检查变更对账 | 对比 git diff / 依赖变化 / 分支状态（加载更多上下文） |

**交互循环**：

- ✅ → 加载 `read_file("steps/step-{current_step}-xxx.md")` 继续
- ✏️ → 用户描述变化 → AI 判断走 drift-handling 还是重新评估范围
- 📋 → 读取完整工作上下文 → 展示摘要 → 再次弹出相同选项
- ❌ → 退出 dev-flow，清理/保留 .flow 取决于用户意愿
- 🔍 → 执行 git diff / 分支对账 → 展示变更 → 再次弹出选项

**特殊处理**：若 `recovery.current_plan_summary` 缺失（旧 v3.1 以前的 .flow），
在恢复输出中追加一行 `⚠️ 当前方案摘要缺失，请打开工作上下文 ## 需求 §「当前执行方案」确认最新方案后再编码` 后仍弹选项，
但将 "✅ 按计划继续" 改为 "✅ 已确认方案（请先确认 ## 需求 §当前执行方案）"。

- 高置信需求 = 以下之一：唯一活跃 .flow / 多 .flow 中用户选择后 / match_keywords 匹配唯一命中
- 出现 `recovery` 字段缺失的旧 .flow，降级为读工作上下文 `## 进度` 中的「恢复指令」散文段落后输出。
- 出现 `phase` 字段缺失的旧 .flow，输出时省略「· {phase}」后缀。
- 跨模型补充：若 `last_model` 与当前模型不同，输出顶部额外追加一句：
  > 上次由 {last_model} 推进，我是 {current_model}。我会严格按工作上下文的明确记录执行，不脑补。

#### 24h+ 跨天轻量 git 对账（仅 last_active > 24h 时触发）

```bash
# 仅一行命令，不做 diff/依赖/分支检查
NOW_HASH=$(git rev-parse --short HEAD 2>/dev/null)
```

- 若 `NOW_HASH` 与 `.flow.last_commit_hash` **一致** → 静默，按正常恢复输出
- 若 不一致 → 在 L1 恢复输出末尾追加一行：
  > ⚠️ 本地 commit 已变化（{last_commit_hash} → {NOW_HASH}），请确认是否仍在同一分支推进。
- 若 git 命令失败（非 git 仓库）→ 静默跳过，不报错

**故意不做的事**（按用户确认“跨天一般工作目录/分支/依赖保持不变”）：

- 不跑 `git status` 检查文件变动
- 不检查依赖、node_modules、分支名
- 不对「已修改文件清单」做 `git diff --stat`
- 跨项目场景完全不适用本节（走 cross-project-flow.md）

### 热启动超时处理

`.flow` 文件最近活跃时间 ≥ 24h → **必须使用 `ask_followup_question` 弹出交互式选项**：

```text
⚠️ 发现超时活跃流程：{name}（最后活跃：{时间}）
```

| 选项 | 说明 |
| --- | --- |
| ▶️ 继续该流程 | 从步骤 {N} 恢复 |
| 🗑️ 放弃该流程 | 删除 .flow 文件，开始新需求 |
| 📋 查看流程详情 | 读取工作上下文 |

### 多活跃流程处理（v3 智能恢复网关，2026-05-12 升级）

`.active-flows/` 下存在多个 `.flow` 文件时，先走**智能匹配**决策树：

```text
步骤 1：枚举所有 .flow，过滤 paused>7天 / completed / superseded 条目
步骤 2：对每个剩余 .flow 提取 match_keywords + brief，对用户首条消息计算命中数
步骤 3：决策分路：
  - 仅 1 个命中        → 高置信自动恢复（走 L1 极速恢复输出模板，无需 ask_followup_question）
  - 多个命中 / 0 个命中 → ask_followup_question 让用户选择（走下方多需求清单模板）
```

**多需求清单输出格式**（先文本表格罗列所有活跃流程，再调用 `ask_followup_question`）：

```markdown
👋 检测到 {N} 个进行中的需求，按推荐度排序：

| # | 需求简述 | 阶段 | 状态 | 上次活跃 | 命中关键词 |
| --- | --- | --- | --- | --- | --- |
| 1 ⭐ | {brief1} | {phase1} | {status1 emoji} | {time1} | {hits1} |
| 2   | {brief2} | {phase2} | {status2 emoji} | {time2} | — |
| ... | ... | ... | ... | ... | ... |
```

排序规则：① 命中数 desc → ② status 优先级（active > idle > blocked-* > paused）→ ③ last_active desc。
Top1 标注 ⭐ 推荐（仅当唯一 Top1 明显优于其他时才打头，平手不打）。

`status` 到 emoji 的映射：`active`=🟢 `idle`=🔵 `blocked-by-backend`=🟡后端 `blocked-by-review`=🟡评审 `paused`=⏸️。

`ask_followup_question` 选项（与表格逐条对应，按编号顺延 + 末尾附「🆕 开始新需求」和「❌ 取消 / 普通对话」）：

| 选项 | 说明 |
| --- | --- |
| ▶️ 恢复 #1 {brief1} | 从步骤 {N} 继续 |
| ▶️ 恢复 #2 {brief2} | 从步骤 {N} 继续 |
| ... | ... |
| 🆕 开始新需求 | 忽略现有活跃流程，创建新的 |
| ❌ 取消 / 普通对话 | 本轮不进入 dev-flow |

**并发抢占检测**：选中某需求后，若检测到 `last_active` 距今 < 30 分钟 且 `.flow.session_id` 与当前会话不同 → 先额外询问一次是否抢占，抢占后才以新 session_id 写入 .flow。

**降级行为**（旧 .flow 缺失 v3 字段时）：表格「阶段」列填 `—`，「命中关键词」列填 `—`，推荐逆退为仅按 `last_active` 排序。

## 执行深度（由步骤 4 智能评估推荐）

所有显式命令入口（`dev-flow` / `dev:` 等）触发后等价进入统一流程，**不预设执行深度**。步骤 4 基于步骤 1~3 的研究成果智能评估推荐：

| 推荐依据 | 推荐执行深度 | 典型场景 |
| --- | --- | --- |
| 改动极小（≤3文件+≤10行/文件）、位置明确 | 快捷执行（步骤 5→7 极简版） | 1 行 CSS 修复、错别字修正 |
| 改动范围小、风险低、单文件/单模块 | 标准执行（步骤 5→7） | Bug 修复、样式调整、小优化 |
| 改动范围大、多模块联动、核心逻辑、需求驱动 | 完整执行（步骤 5→10） | 新功能开发、架构重构、任务平台 需求 |
| 改动文件≥6个、跨模块、可按功能/模块拆分 | 分批执行（步骤 4.5→7 循环） | 大型重构、多模块联动需求、批量文件修改 |

> **关键**：所有需求都走阶段 0 → 步骤 1~4 的完整研究分析。执行深度由步骤 4 智能评估推荐，用户可自由覆盖。

## 步骤 7 的执行深度分支

步骤 7 的行为根据用户在步骤 4 选择的执行深度有所不同（详见 `steps/step-7-commit.md`）：

- **标准执行**（`caller=standard-7`）：执行全部环节 A~J（清理+L2审查+Commit+Devlog+Knowledge+反思+经验快检），流程结束
- **完整执行**（`caller=full-7`）：仅执行环节 A~G（清理+L2审查），Commit/Devlog/反思推迟到步骤 9~10

## 完整执行扩展（步骤 8~10）

> 以下步骤仅在用户选择「完整执行」时执行。标准执行在步骤 7 结束，不加载此文件。

**加载**：`read_file("steps/step-8-10-full.md")` — 包含步骤 8（L3 审查）、9（反思）、10（归档）的完整规范。

## 全局强制规则

### 步骤完成钩子（每个步骤必须执行）

完整的步骤完成协议（结构化 JSON 输出 → 状态同步 → 门控验证）定义在 `steps/step-router.md`「步骤完成」章节（单一真相源）。
每个步骤执行完毕后必须严格按该协议执行，禁止跳过或批量补齐。

### 上下文管理

执行过程中感知到 Token 紧张时 → `read_file("references/token-management.md")`（>15 轮主动压缩，>25 轮强制精简）。
完整执行步骤多、上下文消耗大，每完成一个步骤将过程细节卸载，仅保留结论到工作上下文文件。

### 回退机制

遇到需要回退的场景时 → `read_file("references/rollback.md")` 加载完整回退对照表（单一真相源）。
常见回退速查亦可参考 `steps/README.md`「回退路径速查」。

### 条件加载 reference 文件（Hermes 借鉴）

加载 `references/` 下的参考文件前，必须先查「条件激活矩阵」：

1. 查阅 `references/_index.md` 末尾的「条件激活矩阵」章节。
2. 若目标文件列出了 `requires_signals`：从工作上下文 `signals` 数组检查命中情况。
3. 任一信号命中 → 正常 `read_file` 加载；全部未命中 → 跳过加载（静默，不报错）。
4. 未列入矩阵的 reference → 按主索引的时机正常加载。
5. 用户明确指令「加载 X」 → 强制加载，跳过信号检查。

**信号写入责任**：阶段 0/步骤 1/2 等在其产出物中必须把推断出的信号写入工作上下文 `## 元数据 > signals:` 字段。

### 模式识别与切换（mode-matrix）

当出现以下任一情况时 → `read_file("references/mode-matrix.md")` 加载模式矩阵：

- 多个模式信号同时触发（如活跃 .flow + 迭代信号 + 批次信号）
- 用户询问"当前处于什么模式"
- 步骤 4 进行执行深度决策前（作为 `user_decision` 的决策参考）
- 步骤 2 检测到 workspace 外修改（判断是否进入 cross-project）
