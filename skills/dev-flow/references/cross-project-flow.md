# 跨项目联调主流程（索引）

> 本文件由步骤 2（范围确认）和步骤 6C（联调）按需加载。
> 当检测到修复目标不在当前项目，或用户问句涉及他项目代码时触发。
> **结构变更**（2026-05-29 phase2 拆分）：详细规则下沉到 `cross-project/` 子目录的 4 个文件，本主文件仅保留主流程概览 + 字段定义 + 索引。

---

## 一、模式分流（先判定走哪条路径）

| 模式 | 是否要改 B 项目 | 路径文件 |
| --- | :---: | --- |
| **修复型 · 三段式（A→B→A）** | ✅ | [cross-project/trigger.md](./cross-project/trigger.md) → [handoff.md](./cross-project/handoff.md) → [integration.md](./cross-project/integration.md) |
| **修复型 · 两段式（A→B）** | ✅ | trigger.md → handoff.md（B 项目收尾） |
| **修复型 · 多段式（A→B→C→A）** | ✅ | 按三段式递归处理 |
| **本地并行模式**（同一对话多仓库同时改） | ✅ | [integration.md](./cross-project/integration.md) §「本地并行协作模式」 |
| **分析型（只读不改）** | ❌ | [analysis.md](./cross-project/analysis.md) |

> **判定**：先用 `analysis.md` 三步法分析；分析后决定要改 B 项目 → 升级为修复型走 trigger.md；只读不改 → 留在 analysis.md。

---

## 二、工作上下文 `cross_project` 字段（YAML Front Matter）

仅跨项目场景填写，非跨项目不含此字段：

```yaml
cross_project:
enabled: true
origin_project: ""           # A 项目（发现问题/发起修复的项目）
origin_workspace: ""         # A 项目工作区绝对路径
fix_project: ""              # B 项目（需要修复的项目）
fix_workspace: ""            # B 项目工作区绝对路径（已知时填写）
dependency: ""               # A 依赖 B 的包名和版本，如 "@your-org/component-lib: ^1.3.10"
status: "pending_fix"        # pending_fix | fixing | fixed_pending_validation | validated | failed
handoff_prompt: ""           # 生成的 B 项目衔接 prompt（用户可直接复制）
validation_project: ""       # 验证项目（通常等于 origin_project，但也可能是第三方）
validation_workspace: ""     # 验证项目工作区路径
consumers: []                # 知识库平台 信号 4 反查到的消费方项目列表（可选）

```

### `cross_project.status` 状态流转

```text
pending_fix → fixing → fixed_pending_validation → validated
↓                    ↓
failed              failed

```

| 状态 | 含义 | 触发条件 |
| --- | --- | --- |
| `pending_fix` | 已识别需跨项目修复，等待用户切换到 B 项目 | step-2 检测到跨项目 |
| `fixing` | 用户已在 B 项目中开始修复 | B 项目新对话匹配到此工作上下文 |
| `fixed_pending_validation` | B 项目修复完成，等待回 A 项目验证 | B 项目 step-7 完成 |
| `validated` | A 项目验证通过 | A 项目 step-6C 联调通过 |
| `failed` | 修复失败或验证不通过 | 任意阶段失败 |

---

## 三、单 .flow 架构（2026-05-14 重构）

> 跨项目场景下，A 项目和 B 项目**共用同一个工作上下文 `.md` 文件和同一个 `.flow` 锁文件**。
> **设计理由**：`.active-flows/` 是用户级全局目录（`~/.codebuddy/working-context/.active-flows/`），不按 workspace 隔离。
> 双 .flow 会导致同一需求在恢复网关中出现两条匹配记录，增加歧义和维护成本。
> 单 .flow 通过 `phase` 字段区分当前处于 A 项目还是 B 项目阶段。
>
> - **工作上下文 `.md`**：需求的唯一真相源，跨项目场景项目缩写统一使用 **`crossProject`** 专用标识（替代单一项目缩写，因为 A/B 项目交替活跃时无法用一个项目命名）
> - **`.flow` 锁文件**：唯一一个，A→B 切换时更新 `phase`/`recovery` 反映当前阶段

### .flow 字段在跨项目各阶段的值

| 阶段 | `phase` | `status` | `recovery.yesterday` | `recovery.next_action` |
| --- | --- | --- | --- | --- |
| A 暂停，等 B 修复 | `integration` | `paused` | "已暂停，等待 B 项目修复回流" | "等待 B 发版后安装新版本验证" |
| B 项目接手修复中 | `coding` | `active` | "已接收衔接，正在 B 项目修复 {xxx}" | "完成步骤 {N}，下一步 {xxx}" |
| B 改完，等 A 验证 | `integration` | `active` | "B 项目修复完成，等待回 A 验证" | "安装 {包名}@{新版本} 后启动验证" |
| A 验证中 | `integration` | `active` | "正在 A 项目验证 B 修复" | "逐项验证后回 B 收尾" |
| A 验证通过，回 B 收尾 | `commit-archive` | `active` | "A 验证通过" | "回 B 项目完成 commit/devlog" |

### `match_keywords` 规则

单 .flow 的 `match_keywords` 应同时包含 A/B 两侧关键词，确保任一项目对话都能命中：

```toml
match_keywords = ["A侧关键词", "B侧关键词", "包名", "A项目名", "B项目名"]

```

示例：`["processOrder", "warning_tip", "提交订单", "project-a-component", "project-b-component", "projectA"]`

### 钩子时机

| 时机 | .flow 操作 | 工作上下文操作 |
| --- | --- | --- |
| A step-2 检测到跨项目 | `status=paused`、`phase=integration`、刷新 `recovery` | `cross_project.status = pending_fix`、写入 `handoff_prompt` |
| B 项目衔接 prompt 识别后 | `status=active`、`phase=coding`、刷新 `recovery` | `cross_project.status = fixing` |
| B step-6C/7 完成 | `phase=integration`、刷新 `recovery`（"等 A 验证"） | `cross_project.status = fixed_pending_validation` |
| A 验证回流 | `phase=integration`、刷新 `recovery`（"正在验证"） | — |
| A 验证通过 | `phase=commit-archive`、刷新 `recovery` | `cross_project.status = validated` |

### 降级策略

- 旧 v2 双 .flow 场景 → 恢复网关命中多条时合并为选择列表，用户选择后按单 .flow 逻辑继续
- 旧 `status=paused_for_cross_project` 字符串 → 等价于 `status=paused` + `phase=integration`
- 跨项目场景**禁用**「24h+ 跨天 git 对账」（A/B 不同 workspace，hash 对比无意义）

---

## 四、按场景的入口指引

| 你现在的场景 | 直接打开这个文件 |
| --- | --- |
| step-2 影响范围扫描 / 检测是否跨项目 | [cross-project/trigger.md](./cross-project/trigger.md) §「step-2 挂载：跨项目检测钩子」 |
| 已确认跨项目，要生成 B 项目衔接 prompt | [cross-project/trigger.md](./cross-project/trigger.md) §「触发后行为」 + [handoff.md](./cross-project/handoff.md) |
| B 项目新对话粘贴衔接 prompt 后 | [handoff.md](./cross-project/handoff.md) §「衔接后行为」 + §「profile 预检」 |
| B 项目 step-6C 跨项目联调 | [integration.md](./cross-project/integration.md) §「step-6C 扩展」 |
| A 项目验证回流（粘贴验证 prompt 后） | [integration.md](./cross-project/integration.md) §「A 项目验证回流」+「契约对齐」 |
| 同对话多仓库同时改动 | [integration.md](./cross-project/integration.md) §「本地并行协作模式」 |
| 收尾对账 / 跨项目 commit / Diff 查看 | [integration.md](./cross-project/integration.md) §「Diff / Commit 查看规范」 |
| 纯分析场景（不一定要改 B） | [analysis.md](./cross-project/analysis.md) §「执行三步法」 |

---

## 五、与其他文档的关系

- 项目映射 + search_domain + 本地速查表 → [remote-knowledge.md](./remote-knowledge.md) §二
- profile 生命周期（onboard）→ [onboard-flow.md](./onboard-flow.md)
- step-2 影响范围确认 → [../steps/step-2-scope.md](../steps/step-2-scope.md)
- step-6C 联调评估 → [../steps/step-6-verify.md](../steps/step-6-verify.md)
- issue-trace（纯分析根因 Skill）→ `~/.codebuddy/skills/issue-trace/SKILL.md`

> **维护原则**：本主文件保持「索引 + 字段定义 + 阶段流转」精简骨架；详细 SOP / 模板 / 反模式清单一律下沉到 `cross-project/` 子文件，新增/修改优先在子文件，主文件仅在跨子文件结构变化时同步。
