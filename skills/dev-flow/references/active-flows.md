# 活跃流程注册目录（.active-flows/）

> **来源**：从 `references/working-context.md` 拆出（独立文件 2026-05-19）
> **加载触发**：① 跨会话恢复（用户首条消息未命中显式关键词，但 `.active-flows/` 下存在 `.flow` 文件）；② dev-flow 步骤完成钩子刷新 `.flow` 时；③ 用户主动询问"清理流程/活跃需求"。普通对话/创建工作上下文场景**不需要**加载本文件。
> **反向引用**：`references/working-context.md`、`SKILL.md`、`steps/step-router.md`、`references/_index.md`、`references/shared-rules.md`、`references/drift-handling.md`、`references/integration-flow.md`、`references/skill-full.md`、`working-context/README.md`

---

## 用途

解决 dev-flow 在步骤执行过程中（特别是联调/验证阶段），用户后续对话不含触发关键词导致脱离工作流的问题。同时支持多需求并发开发，每个需求独立管理锁文件，互不干扰。

## 目录与文件命名

**目录位置**：`~/.codebuddy/working-context/.active-flows/`

**文件命名**：与对应的工作上下文文件名一致，仅扩展名不同（`.md` → `.flow`）。

```text
working-context/
├── .active-flows/                                    # 活跃流程锁文件目录
│   ├── 20260325_disable-feature_user-project.flow     # 需求 A 的锁
│   └── 20260401_module-settings_user-project.flow      # 需求 B 的锁
├── 20260325_disable-feature_user-project.md           # 需求 A 的工作上下文
└── 20260401_module-settings_user-project.md            # 需求 B 的工作上下文
```

## 单个 .flow 文件格式（v3 schema）

```yaml
# === 核心字段（必填） ===
current_step: 6
mode: full
status: idle                  # active | idle | blocked-by-backend | blocked-by-review | paused | completed | superseded
last_active: 2026-03-31T17:25:00
brief: 封禁长期屏蔽功能

# === v3 新增字段（可选，有则更智能） ===
phase: coding                 # research | coding | integration | iteration | commit-archive
session_id: 20260331_172500_a3f9      # 会话指纹（首次创建时生成：YYYYMMDD_HHMMSS_随机4hex），用于并发抢占检测
last_commit_hash: ""          # 上次步骤完成时的 git HEAD 短 hash，用于 24h+ 跨天恢复时轻量对账
recovery:                     # 3 段式结构化恢复指令（替代散文，新对话首响时直接呈现给用户）
  yesterday: "完成 project-b 4 文件改动，撤销组件级替换，改为数据源拦截方案"
  next_action: "验证数据源拦截方案 → project-a 编码"
  current_plan_summary: "v3：拦截 projectStore.configValue → 替换为新显示名；不动第三方 SDK 内部组件；范围 project-b + project-a"  # 当前最新方案 1 句话摘要（≤80 字，含版本号 vN）。来源 = 工作上下文 ## 需求 §「当前执行方案 v{N}」的「当前要做什么」首句精炼。drift-handling 子流程刷新 v{N} 后必须同步刷新本字段。
  pending:                    # 待确认问题列表，每条 ≤30 字（无则用空数组）
    - "数据源方案是否覆盖所有 displayName 出现位置?"
    - "project-a 是否需要复用 isExternalSdk()?"
match_keywords:               # 用于新对话首条消息的智能匹配（步骤 0/1 由 AI 自动生成 5~10 个，后续可动态扩充）
  - "显示名"
  - "configValue"
  - "rename"
  - "SDK 文本"
last_model: "{model-id}"       # 上次推进时的模型标识（可选，用于跨模型恢复时显式声明）

# === 批次执行时额外字段（可选） ===
# current_batch: 2
# total_batches: 3
```

## 字段语义

| 字段 | 取值/格式 | 说明 |
| ------ | ---------- | ------ |
| `status` | 见下方枚举 | 比 v2 更细粒度的状态机 |
| `phase` | `research`/`coding`/`integration`/`iteration`/`commit-archive` | 阶段语义（与 `current_step` 正交），决定恢复时呈现哪些区块 |
| `session_id` | `YYYYMMDD_HHMMSS_xxxx` | 会话指纹。新对话恢复时若距上次 < 30 分钟且 session_id 不同 → 警告并询问是否抢占 |
| `last_commit_hash` | 7 位 git 短 hash | 仅 `last_active` 距今 > 24h 时使用：跑 `git rev-parse --short HEAD` 对比，若不一致则提示用户「分支可能已变更」 |
| `recovery` | 见上方 4 字段 | 必须在每次步骤完成钩子刷新；缺失时降级为读取工作上下文 `## 进度` 区块 |
| `recovery.current_plan_summary` | string ≤80 字 | 当前最新方案 1 句话摘要（含 `v{N}` 版本号）。**写入时机**：①初始方案确认后（步骤 3 完成）首次写入 v1；②`drift-handling.md` 步骤 3「重写当前执行方案 v{N}」完成后同步刷新；③`iteration-fix.md` 阶段 0 增量理解触发 drift-handling 时同步刷新。**作用**：跨会话恢复时让 AI 直接拿到「当前要做什么」，避免去工作上下文 markdown 各区块自行拼凑而读错。缺失时降级为提示 AI 必读 `## 需求` §「当前执行方案 v{N}」 |
| `match_keywords` | string[] | 由步骤 0/1 完成时自动生成（来源：需求标题、任务平台 标题、关键变量名/文件名）；步骤 5/6 完成时可追加新出现的高频词（去重，上限 15 个） |
| `last_model` | 模型标识字符串 | 跨模型恢复时 AI 主动声明「上次由 X 推进，我是 Y」 |

## `status` 枚举详解

| 值 | 含义 | 典型场景 | 恢复欢迎语提示 |
| ---- | ------ | --------- | --------------- |
| `active` | 当前对话正在主动推进 | 步骤切换中 | — |
| `idle` | 步骤已完成，等用户继续 | 大多数「昨天结束时」状态 | "上次到这里，今天继续吗?" |
| `blocked-by-backend` | 等后端联调 | 步骤 5 完成等接口 | "接口好了吗? 还是先看其他需求?" |
| `blocked-by-review` | 等代码评审/产品确认 | 步骤 7 后等合入 | "评审过了吗? 还有要改的地方吗?" |
| `paused` | 用户主动暂停 | 用户说"先停一下" | "要恢复这个需求吗?" |
| `completed` | 流程结束（即将删 .flow） | 步骤 7/10 完成 | — |
| `superseded` | 被另一个会话抢占 | 并发冲突 | "这个需求被另一个会话推进过" |

- `brief`：需求简述，用于多需求时智能匹配和展示
- `context_file` 字段不需要——从文件名即可推导出工作上下文路径（换扩展名 `.flow` → `.md`）
- **向后兼容**：旧 `.flow` 文件（仅含 v2 字段）仍能正常工作，缺失的 v3 字段按默认行为兜底（不做智能匹配，回退到 brief 关键词匹配 + 散文恢复指令）

## 生命周期

| 时机 | 动作 | 执行者 |
| ------ | ------ | -------- |
| dev-flow 触发（任意模式） | 创建/更新对应需求的 `.flow` 文件 | 步骤路由器（`steps/step-router.md`） |
| 每个步骤完成钩子执行时 | 更新对应 `.flow` 文件的 `current_step` 和 `last_active` | 步骤完成钩子 |
| 流程正常结束（步骤 7/10） | 删除对应 `.flow` 文件及全部附属文件（`.validated*`、`.done`、`.breaker/`） | `scripts/hooks/post-step.sh` §7 自动清理 |
| 用户显式退出当前需求 | 删除对应 `.flow` 文件及附属文件（`.validated*`、`.done`、`.breaker/`） | AI 行为规范触发检查 |
| 用户暂停需求 | 更新 `status` → `paused` | AI 行为规范触发检查 |
| 用户恢复需求 | 更新 `status` → `active` | AI 行为规范触发检查 |
| `active` 状态超过 48h 未更新 | 提醒用户：是否继续/暂停/移除 | AI 行为规范触发检查 |
| `paused` 状态超过 7 天未更新 | 提醒用户：是否恢复/移除 | AI 行为规范触发检查 |

## 自动恢复决策逻辑（v3 智能恢复网关）

> 触发时机：用户首条消息未命中 dev-flow 显式触发关键词，但 `.active-flows/` 下存在 ≥1 个 `.flow` 文件。

```text
步骤 1：枚举
  ls ~/.codebuddy/working-context/.active-flows/*.flow

步骤 2：过滤
  - 排除 status=paused 且 last_active 距今 > 7 天的条目
  - 排除 status=completed 的条目（理论上应已被删除，兜底过滤）
  - 排除 status=superseded 的条目

步骤 3：智能匹配（v3 核心）
  对每个剩余 .flow，提取 match_keywords + brief，对用户首条消息做匹配：
    - 命中规则：消息中出现 ≥1 个 match_keywords 元素，或 brief 关键词的子串
    - 计算每个 .flow 的命中数，得到「匹配命中表」

步骤 4：决策
  - 0 个 .flow 通过过滤            → 普通对话模式
  - 1 个 .flow 通过过滤             → 直接走「高置信自动恢复」（即使消息未命中关键词也尝试一次）
  - 多个 .flow，仅 1 个有命中       → 高置信自动恢复该需求
  - 多个 .flow，多个有命中          → 展示「多需求清单」让用户 ask_followup_question 选择，按命中数+last_active 排序，标注推荐 Top1
  - 多个 .flow，0 个命中            → 展示「多需求清单」让用户选择，按 last_active 排序

步骤 5：高置信自动恢复（L1 极速恢复）
  目标：1 次工具调用就让用户感觉「AI 已经接住了」
  执行：
    a. 仅 read_file 一次该 .flow 文件（< 1KB，几乎零成本）
    b. 直接呈现「3 句话回忆杀」格式（见下方），无需读工作上下文 .md
    c. 等待用户确认后，再按需 read_file 工作上下文获取细节（L2/L3 按需扩展）

步骤 6：24h+ 跨天对账（仅 last_active 距今 > 24h 时执行）
  - git rev-parse --short HEAD 拿当前 commit
  - 与 .flow.last_commit_hash 对比；若不一致 → 在恢复输出末尾追加：
    "⚠️ 检测到本地 commit 已变化（昨天: a1b2c3d → 现在: e4f5g6h），请确认是否仍在同一分支推进"
  - **同时检测工作上下文文件 mtime**：`stat -f "%m" working-context/{name}.md` 与 .flow.last_active 比对（容差 60 秒）；若 mtime 更新 → 在恢复输出末尾追加：
    "⚠️ 检测到工作上下文文件 {name}.md 在 .flow 之后被修改（mtime 晚于 last_active {N} 分钟），可能含未同步到 .flow.recovery 的方案变更，请优先以工作上下文 ## 需求 §「当前执行方案 v{N}」为准"
  - 不做 git diff/依赖检查/分支检查，保持轻量
```

### 输出模板：高置信自动恢复（3 句话回忆杀）

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

**特殊处理**：若 `recovery.current_plan_summary` 缺失（旧 v3.1 以前的 .flow），在恢复输出中追加一行
`⚠️ 当前方案摘要缺失，请打开工作上下文 ## 需求 §「当前执行方案」确认最新方案后再编码`
后仍弹选项，但将 "✅ 按计划继续" 改为 "✅ 已确认方案（请先确认 ## 需求 §当前执行方案）"。

### 输出模板：多需求清单（≥2 个候选时）

```markdown
👋 检测到 {N} 个进行中的需求，按推荐度排序：

| # | 需求 | 阶段 | 状态 | 上次活跃 |
|---|------|------|------|---------|
| 1 ⭐ | {brief1} | {phase1} | {status1 emoji} | {time1} |
| 2   | {brief2} | {phase2} | {status2 emoji} | {time2} |
```

排序规则：① 命中数 desc → ② status 优先级（active > idle > blocked-* > paused）→ ③ last_active desc。Top1 标注 ⭐ 推荐。

`ask_followup_question` 选项与表格逐条对应，外加「🆕 开始新需求」「❌ 都不是 / 普通对话」。

## 降级行为（旧 .flow 缺失 v3 字段时）

- 缺 `match_keywords` → 回退到用 `brief` 做子串匹配
- 缺 `recovery` → 回退到读工作上下文 `## 进度` 的「恢复指令」散文段落
- 缺 `recovery.current_plan_summary`（v3.1 前的旧 .flow） → 恢复输出末尾追加一行：`⚠️ 当前方案摘要缺失，请打开工作上下文 ## 需求 §「当前执行方案」确认最新方案后再编码`
- 缺 `phase` → 输出时省略「· {phase}」尾缀
- 缺 `last_commit_hash` → 跳过 24h+ 对账

## 会话指纹与并发抢占

- 新对话恢复时如果检测到 `last_active` 距今 < 30 分钟 且自身 session_id 与 .flow.session_id 不同 → 主动询问：「检测到此需求 {N} 分钟前刚被另一个会话写过，是否抢占？(继续/查看上次进度/取消)」
- 抢占确认后：将旧 .flow 复制为 `{name}.flow.superseded.{HHMMSS}` 备份 → 写入新 session_id → 继续
- 不抢占：当前对话不进入 dev-flow，普通对话模式

## 锁文件维护规则

- 步骤完成钩子中，更新工作上下文后**紧接着**更新对应的 `.flow` 文件
- 流程最终步骤完成后**必须删除**对应的 `.flow` 文件及全部附属文件，包括：
  - `.step-*.validated*`（物理检查点文件，流程结束后无意义）
  - `.step-*.done`（v1 兼容文件，流程结束后无意义）
  - `.breaker/`（熔断计数目录，流程结束后无意义）
  - **实现**：`scripts/hooks/post-step.sh` §7 在 `next_step=done` 时自动执行上述清理
  - **兜底检测**：`scripts/lints/working-context-location-lint.sh` L3 规则会报告漏清理的残留文件
- 用户显式退出时由 AI 行为规范触发检查负责删除对应 `.flow` 文件及附属文件
- 用户说"清理所有流程" → 清空整个 `.active-flows/` 目录
