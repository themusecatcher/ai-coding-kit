# 工作上下文规范

> 本文件定义工作上下文的**规则、字段语义、命名/创建/更新流程**。
> **完整文件模板** → `references/templates/working-context.tpl.md`（创建新文件前必须 `read_file` 加载）。
> **设计原则**：模板和规则分离——模板回答"长什么样"，本文件回答"怎么用、怎么改、怎么校验"。

---

## 一、命名规则

```text
~/.codebuddy/working-context/{YYYYMMDD}_{需求简述}_{项目缩写}.md

```

- **格式**：`日期_需求简述_项目缩写`（需求简述使用英文短横线，禁止中文/驼峰/下划线）
- **项目缩写**：按 §六 项目缩写映射表取值，新项目首次使用时 AI 推断并让用户确认后追加映射表
- **跨项目需求**：涉及多项目修复时，项目缩写统一使用 **`crossProject`**（跨项目专用标识，见 `references/cross-project-flow.md` §三），不再使用单一项目的缩写
- **创建位置**：`~/.codebuddy/working-context/`（用户目录），严禁创建在项目目录下
- **唯一性**：同一需求只允许一个文件，覆盖式更新，流程结束后自动清理
- **示例**：`20260305_article-list-filter_myProject.md`（单项目）/ `20260401_fix-login-bug_crossProject.md`（跨项目）

### 1.1 文件名功能段对齐规则（v3，2026-05-18）

工作上下文文件名的「需求简述」段与 YAML `branch` 字段的「功能段」**必须对齐**：

|YAML 字段|提取段|示例|文件名简述|
|---|---|---|---|
|`branch: feature/article-list-filter`|去掉前缀后的最后段|`article-list-filter`|✅ 一致|
|`branch_dev: feature_dev/article-list-filter/{username}`|中间段（不含开发者用户名）|`article-list-filter`|✅ 一致|

**三阶段写入时机**：

|阶段|处理|
|---|---|
|阶段 0 创建（分支未定稿）|临时简述，YAML `branch: ""`|
|步骤 4 §4.1 分支定稿后|与分支功能段不一致时**一次性重命名**（仅此一次）|
|后续所有迭代/跨分支|**禁止重命名**（文件名稳定锚点 > 易变载体分支）|

**重命名脚本**：

```bash

# 步骤 4 §4.1 分支定稿时执行（如名称不匹配）
mv ~/.codebuddy/working-context/$OLD_FILE ~/.codebuddy/working-context/$NEW_FILE
mv ~/.codebuddy/working-context/.active-flows/${OLD_FILE%.md}.flow \
~/.codebuddy/working-context/.active-flows/${NEW_FILE%.md}.flow

```

### 1.2 反查工具

```bash

# 当不确定当前分支对应哪个工作上下文文件时
bash ~/.codebuddy/skills/dev-flow/scripts/find-context-by-branch.sh [分支名]

```

匹配优先级：① YAML `branch`/`branch_dev`/`branch_workspace` 精确匹配 → ② 文件名功能段匹配 → ③ kebab-case 模糊匹配。

---

## 二、YAML Front Matter 字段定义

> 完整 YAML 模板 → `templates/working-context.tpl.md` §「YAML Front Matter」。本节仅列字段语义和必填性。

|字段|类型|必填|说明|
|---|---|:---:|---|
|`mode`|string|✅|基础模式：`standard` / `full` / `micro-fix` / `iteration-fix` / `batch` / `cross-project`|
|`current_step`|number/string|✅|当前步骤编号（如 `1`、`4.5`、`10`、`done`）|
|`status`|string|✅|`in_progress` / `completed` / `blocked` / `paused` / `batch_in_progress`|
|`iteration`|number|✅|迭代轮次（首轮 1，迭代修复时递增）|
|`interaction_mode`|string|✅|`standard` / `streamlined`|
|`complexity`|string||`simple` / `medium` / `complex`|
|`branch`|string|✅|父分支名（步骤 4 §4.1 定稿后写入；之前为空字符串）|
|`branch_dev`|string|✅|孙分支名（feature/ 场景为 `feature_dev/.../<dev>`；其他与 `branch` 同值）|
|`branch_workspace`|string|✅|实际编码分支（= `branch` 或 `branch_dev`，步骤 4.5 优先读此字段）|
|`has_dev_branch`|boolean||仅 feature/ 场景为 `true`（步骤 4.5 父孙等价检查的开关）|
|`branch_status`|string||`auto_recommended` / `user_modified` / `user_specified` / `iteration_reuse`|
|`task_id`|string||任务平台 ID|
|`project`|string|✅|当前活跃项目路径（跨项目场景取当前编码项目路径，与文件名中的 `crossProject` 标识互补；A↔B 切换时同步更新）|
|`start_time`|string|✅|ISO 8601|
|`steps`|object|✅|各步骤状态映射，key=步骤号，value=`{ status, time }`|
|`signals`|array||条件激活信号（详见 `references/_index.md` §条件激活矩阵）|
|`batch_mode` / `current_batch` / `total_batches` / `batches`|mixed||仅分批执行场景|
|`cross_project`|object||仅跨项目场景，子字段见模板|
|`doc_platform_tech_proposal`|object||步骤 4 · 文档决策（环节 3/4） 决策结果，子字段见模板|
|`validation_log`|array||步骤机器校验摘要（实际产出在 `.validated.json`）|
|`change_requests`|array||轻量 CR 追踪（drift-handling 自动创建，步骤 5.5 联动标记 done）|
|`artifacts`|object|✅|**需求关联产物索引**：统一记录 plan/devlog/knowledge/metrics/tech_proposal/flow_lock 等分散目录文件的路径|
|`artifacts.dir`|string|✅|dev-logs 目录绝对路径（步骤 4 创建时写入）|
|`artifacts.plan`|string|✅|plan.md 绝对路径（步骤 4 落盘时写入）|
|`artifacts.devlog`|string &#124; null|🟡|devlog.md 路径（步骤 7 H.2 后回填；之前为 null）|
|`artifacts.doc_platform.file_path`|string|🟡|技术方案文档文件路径（文档决策后回填）|
|`artifacts.doc_platform.url`|string|🟡|文档链接（如已发布到在线平台）|
|`artifacts.flow_lock`|string|✅|.flow 锁文件绝对路径（阶段 0 创建时写入）|
|`artifacts.knowledge`|array|🟡|关联 knowledge 条目路径（步骤 7 H.3 后回填）|
|`artifacts.metrics`|string &#124; null|🟢|度量报告路径（步骤 7 I / 步骤 9 后回填）|
|`artifacts.flow_report`|string &#124; null|🟢|复盘报告路径（步骤 7 I / 步骤 9 后回填）|
|`sync_history`|array||dev:sync 历史记录（at / from_step / choice）|

### 2.1 `steps.{N}.status` 取值

|值|含义|emoji|
|---|---|:---:|
|`pending`|待执行|⏸️|
|`in_progress`|执行中|🔄|
|`completed`|已完成|✅|
|`partial`|部分完成|⚠️|
|`skipped`|跳过|❌|

### 2.2 头部更新规则（每步骤完成钩子必做）

```yaml

# 步骤 N 完成后：
current_step: N+1
steps:
N: { status: completed, time: "MM-DD HH:mm" }
N+1: { status: in_progress }

```

流程完成时：`status: completed` + `current_step: done`，所有步骤 status ∈ {completed, partial, skipped}。

### 2.3 artifacts 回填规则（每步骤完成钩子，与 §2.2 同步执行）

|步骤/环节|回填字段|写入内容|校验|
|---|---|---|:---:|
|阶段 0|`artifacts.flow_lock`|.flow 锁文件绝对路径|`[ -f ]`|
|步骤 4|`artifacts.dir`|dev-logs 目录绝对路径|`[ -d ]`|
|步骤 4|`artifacts.plan`|plan.md 绝对路径（与 `plan_saved_to_disk` 同步）|`[ -f ]`|
|步骤 4 (文档决策)|`artifacts.doc_platform.file_path` / `artifacts.doc_platform.url`|与 `doc_platform_tech_proposal` 同步|非空检查|
|步骤 7 H.2|`artifacts.devlog`|devlog.md 绝对路径（null → 路径）|`[ -f ]`|
|步骤 7 H.3|`artifacts.knowledge`|关联 knowledge 条目路径数组|数组非空|
|步骤 7 I|`artifacts.metrics`|度量报告 .yaml 路径|`[ -f ]`|
|步骤 7 I|`artifacts.flow_report`|复盘报告 .html 路径|`[ -f ]`|
|dev:sync|全量路径|遍历所有非 null 路径确认存在|失效标注 ⚠️|

**红线**：❌ 步骤 4 完成时 `artifacts.dir`、`artifacts.plan`、`artifacts.flow_lock` 任一为空或路径不存在 → 拒绝进入步骤 4.5；
❌ 步骤 7 完成时 `artifacts.devlog` 仍为 null（标准执行）→ 拒绝标记流程完成。

---

## 三、Markdown 正文必填区块

|区块|必填|用途|
|---|:---:|---|
|`## 需求`|✅|任务平台（含完整可点击 URL）+ 标题 + 摘要 + 分支 + 项目 + 参考|
|`## 项目与分支汇总`|✅|单/多项目角色、分支、workspace 路径、改动文件数、状态|
|`## 变更动机`||复杂需求建议填（业务背景、期望效果、不做的后果）|
|`## 约束与决策`|✅|时间戳条目，**追加不删**；决策推翻用 `~~删除线~~` + 关联新条目|
|`## 计划`|✅|步骤 4 锁定后不可改，仅更新状态标记|
|`## 范围`|✅|涉及文件清单 + 上下游影响|
|`## 进度`|✅|「当前状态」一句话 + 「步骤清单」表格 + 「恢复指令」3 段式|
|`## 备注`||子章节化（参考实现 / 数据结构 / 组件行为 / 关键调用 / 接口协议 / UI 要点）|

### 3.1 `### 恢复指令` 3 段式硬化 schema（v3）

必含 3 段子项，与 `.flow.recovery` 字段语义同步：

```markdown

### 恢复指令
- **昨天/上次我们做了什么**（yesterday）：{1 句 ≤50 字}
- **今天/下一步准备做什么**（next_action）：{1 句可执行}
- **待确认**（pending，无则整项删除）：{≤30 字 列表}
- **模式文件**：{完整/快速}模式
- **注意事项**（可选）：补齐项 / 已知瑕疵

```

❌ 禁止仅写一句"从步骤 N 继续"的散文。

### 3.2 备注子章节格式（按需选用）

|子章节|格式|
|---|---|
|`### 参考实现`|表格：参考对象 &#124; 位置 &#124; 行号|
|`### 数据结构`|列表：`` `变量名`（说明）：`{ 字段 }` ``|
|`### 组件行为`|列表：`` `组件名` + 行为描述 ``|
|`### 关键调用`|表格：函数/接口 &#124; 签名/路径 &#124; 说明|
|`### 接口协议`|代码块或表格|
|`### UI 要点`|列表|

**红线**：❌ 禁止纯文本流水账；✅ 文件位置必须按 AI 行为规范用反引号包裹相对路径（`` `相对路径` `` L行号）。

---

## 四、阶段感知区块（按 phase 必填，v3，2026-05-12）

> **设计意图**：跨天恢复时，编码 / 联调 / 迭代阶段需要的核心信息完全不同，通用模板的 `## 进度` `## 范围` 不够。
> 进入对应 phase 时**新增**对应区块；切出阶段时区块**保留作历史档案**，不删除。

### 4.1 `## 编码进度细节`（仅 `phase: coding`）

|子项|必填|内容|
|---|:---:|---|
|已改文件 + 状态|✅|表格：文件 &#124; 改动摘要 &#124; 状态（已改/已撤销/已 commit）—— working tree 真实快照|
|未完成 todo|✅|列表，每项 ≤30 字|
|上次 lint/build 状态||"0 lint error / build pass / 测试未跑"|
|当前 commit 基准||7 位 hash + commit message（24h+ 对账用）|

### 4.2 `## 联调暂存`（仅 `phase: integration`）

记录"联调临时改动、结束后必须恢复"的清单（历史上脏代码进 master 的重灾区）：

```markdown
|#|改动位置|改动内容|恢复方式|状态|
|---|---|---|---|:---:|
|1|`src/utils/env.ts` L42|强制开启灰度|改回 `getGray('xxx')`|⏸️|
```

附 `### 联调 Checklist`（接口契约 / 灰度配置 / 错误码 / 跨域 cookie）。

### 4.3 `## 迭代轮次详情`（仅 `phase: iteration`）

每轮迭代追加 `### 第N轮（YYYY-MM-DD ~ YYYY-MM-DD）` 子节，已有轮次保留作档案。每轮含：反馈来源 / 反馈原文（不改写） / 本轮范围 / 已通过用例 / 未通过用例 / 状态。

**轮次膨胀控制**：当前轮次完整保留；旧轮次新增下一轮时**主动压缩**为 1-2 行摘要。

### 4.4 阶段切换写入规则

|切换|触发|必做|
|---|---|---|
|`research` → `coding`|步骤 5 开始|创建 `## 编码进度细节`，从 `## 范围` 复制初始文件清单|
|`coding` → `integration`|用户说"开始联调" / 6A 进入接口验证|创建 `## 联调暂存`（默认空表）|
|`integration` → `coding`|联调发现需要补改代码|`## 联调暂存` 保留，回 `## 编码进度细节` 继续|
|任意 → `iteration`|检测到迭代信号|创建/追加 `## 迭代轮次详情` 新 `### 第N轮`|
|任意 → `commit-archive`|步骤 7（commit/devlog/knowledge）|不强制新建，但所有阶段区块的"待恢复/未完成"项必须清零|

**`.flow.phase` 同步**：阶段切换时**必须**同步更新 `.flow.phase`，与工作上下文区块保持一致。

---

## 五、创建/更新决策流程（最高优先级）

> **核心原则**：同一需求只允许一个工作上下文文件，必须复用已有文件而非每次新建。

### 5.1 强制执行流程（4 步）

|#|步骤|动作|
|---|---|---|
|0|**加载模板**|创建新文件前必须 `read_file("references/templates/working-context.tpl.md")`，禁止凭记忆填写|
|1|**扫描已有**|`ls /Users/{username}/.codebuddy/working-context/`|
|2|**匹配同一需求**|按需求简述 / 任务平台 ID / 分支名 / 项目路径任一维度命中即视为同一需求|
|3|**决策**|1 个匹配→更新；多个匹配→选最完整 1 个；无匹配→创建新文件|

### 5.2 创建/更新后必校验

```bash
bash ~/.codebuddy/skills/dev-flow/scripts/validate-working-context.sh <文件路径>

# 返回非 0 → 修正后重试

```

校验项（脚本完整实现）：① 文件名格式 ② YAML 头闭合+必填字段 ③ 必填区块（`## 需求` 含 任务平台 URL、`## 进度` 等）④ `.flow` 一致性。

### 5.3 更新已有文件规则

1. **先 `read_file` 读取完整内容**
2. **同步 YAML 头部**：刷新 `current_step` / 对应步骤 `status` `time` / 流程状态变更刷 `status` / 迭代修复递增 `iteration`
3. **Markdown 正文增量更新，不覆盖**：

- `## 约束与决策`：追加不删；决策推翻用 `~~删除线~~` + 关联新条目
- `## 计划`：锁定后不修改
- `## 范围`：新文件追加到表格末尾
- `## 进度`：「当前状态」覆盖更新；「步骤清单」增量更新；「恢复指令」覆盖更新（必含 3 段式）
- `## 备注`：追加，不删除

1. **跨 Skill 操作回写**（如 doc-platform-doc 更新文档后）：必须立即回写工作上下文进度区块和 YAML 头部，**优先级高于"展示结果后结束"**——Skill 流程到最后一步仍必须回写后才算真正完成。

- **文档操作专项**：文档创建成功 → 写 `file_path`/`locked_title`/`status: synced` +
  `action_history` 追加 `created`；文档更新 → 刷 `last_synced_at` +
  追加 `updated`；失败 → `status: failed` + 备注详情。

1. **更新头部时间戳**（不改文件名，文件名日期=创建日期）

### 5.4 迭代修复场景额外规则

- YAML `iteration` 递增
- `## 约束与决策` 和 `## 进度` 用 `【第N轮】` 标签区分轮次
- `## 范围` 表格新增文件标 `【第N轮新增】`
- 上一轮计划状态改为 `已完成`，本轮新增独立计划段
- 文件超 200 行时精简早期轮次为一行摘要

### 5.5 禁止行为

- ❌ 不扫描就直接创建新文件
- ❌ 同一需求创建多个文件（不同日期）
- ❌ 更新时覆盖已有「约束与决策」/「范围」条目
- ❌ 因「找不到」就新建（必须先扫描）
- ❌ 创建时不先读模板
- ❌ 创建/更新后不做校验
- ❌ 更新 Markdown 但不同步 YAML 头部

---

## 六、项目缩写映射

> 工作上下文文件名格式：`{YYYYMMDD}_{需求简述}_{项目缩写}.md`
>
> 项目缩写由 `config/org.yaml` 的 `project_name` 字段决定。多项目场景下可自定义映射，
> 脚本 `validate-working-context.sh` 从配置中读取白名单。
>
> 默认已知缩写：`my-project`、`my-lib`、`my-components`、`my-app`、`my-service`。

---

## 七、需求漂移处理子流程

> ⚙️ **单一权威源**（2026-05-19 迁移）：完整规则（设计意图 / 触发条件 / 三步固定动作 / 反模式 / 与既有机制对照表）→ `references/drift-handling.md`。
> 📌 本子流程刷新动作复用的「`## 约束与决策` 删除线规范」定义在本文件 §五.3。

---

## 八、活跃流程注册目录（`.active-flows/`）

> **完整规范**（目录结构、`.flow` v3 schema、字段语义、`status` 枚举、生命周期、智能恢复网关、并发抢占、降级行为）→ `references/active-flows.md`（2026-05-19 拆分）。
> **何时加载**：跨会话恢复 / 步骤完成钩子刷新 `.flow` / 用户询问活跃需求清理。

---

## 九、目录结构禁令（2026-06-02 事故反思新增）

> 🔴 **dev-flow 不存在自动归档机制**。`~/.codebuddy/working-context/` 目录结构是 dev-flow 全套 lint
> 与 dashboard 的隐式契约，AI 不得擅自破坏。
> **加载触发**：dev-flow 流程激活（已通过 SKILL.md 加载）；执行 working-context 目录内 `mv` 操作前；用户说"清理/归档/整理"工作上下文时。

### 9.1 禁止动作

- ❌ `mv ~/.codebuddy/working-context/<slug>.md ~/.codebuddy/working-context/archive/...`（误归档 .md）
- ❌ `mv ~/.codebuddy/working-context/.active-flows/<slug>.flow ~/.codebuddy/working-context/archive/...`（应该 `rm` 不是 `mv`）
- ❌ 创建 `~/.codebuddy/working-context/archive/` 子目录（dev-flow 全套规范无该路径定义）
- ❌ 流程结束时只删 `.flow` 不清 `.active-flows/<slug>.step-*.validated*` 残留（违反 `references/active-flows.md` §锁文件维护规则）

### 9.2 设计理由

1. **lint 隐式契约**：`working-context-freshness-lint.sh` / `validate-output.sh §P2`
  / `validate-working-context.sh` / `gen-dashboard.py` 等 4+ 处脚本都用
  `[ -f working-context/<slug>.md ]` 模式定位文件，被 mv 走后会**沉默跳过**而非报错
2. **dev-flow 步骤 10 收尾规范**：`steps/step-8-10-full.md` L474 明确"`.md` 文件保留，仅删 `.flow` 锁文件"
3. **跨会话恢复机制**：智能恢复网关只扫顶层 `working-context/*.md`，归档后失联

### 9.3 Reflex（自动触发）

|触发信号|动作|
|---|---|
|用户说"清理已完成需求 / 归档老需求 / 让 working-context 干净一点"|不得默认走 mv，必须先询问「`rm` 删除 还是 保留」；如要"批量按月归档"，必须先扩展 dev-flow 自动归档规范（无人做过）|
|检测到 `~/.codebuddy/working-context/archive/` 存在且含 `.md` 文件|必须主动报告异常，不视为正常状态|
|即将执行 working-context 内 `mv` 操作|操作前先用 `bash ~/.codebuddy/skills/dev-flow/scripts/lints/working-context-location-lint.sh --all` 体检|

### 9.4 违反后的自动捕获（2026-06-02 已实施）

- `scripts/hooks/post-step.sh` 步骤 7 / 10 完成后自动调用 `working-context-location-lint.sh`，
  4 项检查（L1 位置 / L2 状态一致性 / L3 `.active-flows` 残留 / L4 archive 中 .md 检测）失败即 block
- `scripts/lints/working-context-freshness-lint.sh` 步骤 5.5 / 7 时也兜底检测 `archive/` 路径，发现误归档立即 `exit 1`
- `scripts/validate-output.sh §step10 P2` 同步改造，文件不存在时不再静默跳过
- 单一权威源：`config/gates.yaml §lints.working-context-location-lint`
