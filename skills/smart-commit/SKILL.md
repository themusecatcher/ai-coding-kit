---
name: smart-commit
description: "智能 Commit Message 生成器。基于代码 Diff 自动生成符合 Conventional Commits 规范的 commit message，包含标准版与精简版两套 body（标准版在前）。工作区存在多主题大量改动时，先给出分批提交方案并逐批推进（每批精确暂存、独立生成 message、可选自动提交或自行提交）。支持剪贴板复制、可选自动提交。可被 dev-flow 按需调用，也可在任何 Git 仓库中独立使用。触发关键词：commit message、提交信息、生成提交、smart commit、帮我提交、分批提交、拆分 commit、针对当前 diff 生成 commit。"
keywords: ["commit message", "提交信息", "Conventional Commits", "自动生成commit", "smart-commit", "分批提交", "拆分commit"]
---

# Smart Commit

> 智能 Commit Message 生成器 —— 基于 diff 分析自动生成规范的 commit message；多主题大改动时按批次拆分推进。

## 设计哲学

> 遵循「**确定性用代码，模糊性用 LLM**」原则（详见 `~/.codebuddy/skills/dev-flow/references/core-principles.md` §19）。

| 类型 | 实现方式 | 本 Skill 涉及范围 |
|------|---------|------------------|
| 🟢 **确定性规则** | 脚本 | git diff 获取、体量阈值判断（超过 200 行降级为 stat）、全量改动清单（含 untracked/rename/delete）、分批阻塞检测、批次精确暂存与暂存区严格比对、批次状态持久化 |
| 🔴 **模糊性判断** | LLM 提示词 | 是否需要分批、主题聚类与分批方案、基于 diff 生成简短描述、action 决策、分组排序生成 body |

## 用途

基于代码增量 Diff，自动生成符合 Conventional Commits 规范的 commit message。
同时输出**精简版**和**标准版**两套 commit body，由用户选择使用。

工作区改动包含**多个不同主题**且体量较大时，先给出分批提交方案，确认后逐批暂存、逐批生成 message、逐批推进，避免把多件事塞进一个 commit。

## 使用场景

- 用户请求生成 commit message / 提交信息
- 用户说"帮我提交"/"smart commit"/"生成提交"
- 用户说"改动太多，想分批提交"/"拆成几个 commit"
- dev-flow 流程中「Commit Message 生成」步骤调用

## 关键资源

| 资源 | 路径 | 用途 |
|------|------|------|
| 配置 | `config/action-map.yaml` | diff 阈值、合法 action 白名单、分批阈值、敏感文件模式 |
| 脚本 | `scripts/git-diff-summary.sh` | 智能选择 full diff / stat 概览（按阈值自动降级）；`--staged-only` 供分批模式使用 |
| 脚本 | `scripts/repo-preflight.sh` | 仓库体检 + 全量改动清单（untracked/rename/delete + 敏感文件 + 分批阻塞项） |
| 脚本 | `scripts/stage-paths.sh` | 分批精确暂存 + 暂存区严格比对（禁止 `git add .`） |
| 脚本 | `scripts/batch-state.sh` | 分批进度持久化（中断恢复） |
| 文档 | `references/batch-commit.md` | 分批提交完整流程（判定矩阵 / 聚类规则 / 方案模板 / 逐批循环 / 恢复） |
| 测试 | `scripts/tests/test-runner.sh` | 脚本回归测试 |

## Commit Message 格式规范

### Header 格式

```
{action}: {简短描述}
```

**不使用 scope**，header 中不包含 `(scope)` 部分。

| 部分 | 来源 | 示例 |
|------|------|------|
| `{action}` | LLM 基于 diff + 描述决定 | `feat` / `fix` / `chore` |
| `{简短描述}` | LLM 基于 diff 生成 / 用户自定义 | `新增用户头像组件` |

### Action 决策规则（LLM 模糊判断）

LLM 基于 diff 内容 + 用户描述判断 action，参考以下映射：

| diff 特征 / 描述关键词 | action | 示例 |
|------------------------|--------|------|
| 新增文件/功能、新模块 | `feat` | `feat: 新增暗色模式开关` |
| 修复 bug、异常处理 | `fix` | `fix: 修复支付金额计算错误` |
| 性能优化相关 | `perf` | `perf: 优化首屏加载性能` |
| 代码重构（不改功能） | `refactor` | `refactor: 提取通用表单校验逻辑` |
| 文档/注释更新 | `docs` | `docs: 更新 API 使用说明` |
| 代码格式/缩进（无逻辑变更） | `style` | `style: prettier 格式化` |
| 测试用例 | `test` | `test: 补充用户模块单元测试` |
| 依赖/构建/配置变更 | `chore` | `chore: 更新依赖版本` |
| 回滚 | `revert` | `revert: 回滚到 v1.2` |

> ⚠️ **禁止反模式**：用户未提供描述时，LLM 基于 diff **实际内容**判断 action，不得一律用 `chore`。

### Commit Body 双模式

始终同时生成两套 body，**展示顺序与交互选项顺序统一为「标准版 → 精简版」**（标准版在前）。

#### 标准版 Body

详细说明「改了什么」+「为什么改/改动效果」，格式：`- {动作} {具体文件/模块}，{原因或效果}`

```
- 新增 FeatureToggle 组件，支持按成员维度配置功能权限，包含成员搜索和批量选择功能
- 修改 SettingsPage 页面，在安全设置区块集成功能限制入口，使用条件渲染控制可见性
- 新增 useFeaturePolicy Hook，封装权限策略的 CRUD 操作和本地缓存逻辑
```

#### 精简版 Body

每个改动模块一行概述，格式：`- {动作} {模块/文件简称}`

```
- 新增批量导出限制配置组件
- 修改账户设置页面集成新入口
- 新增权限策略查询 Hook
```

#### Body 生成规则（LLM 模糊判断）

1. 按改动文件/模块分组，每组用 `- ` 开头
2. 按重要性排序（核心逻辑 > 辅助功能 > 配置/样式）
3. 每条控制在一行内
4. body 与 header 之间必须有一个空行

## 入口路由（S0，强制）

**任何调用先跑体检，不要先读 diff 再判断要不要分批**：

```bash
~/.codebuddy/skills/smart-commit/scripts/repo-preflight.sh
```

按 stderr JSON 分流（**按顺序匹配，首个命中即生效**）：

| 条件 | 走向 |
|------|------|
| `changed_files=0` | 见「异常兜底 → 无代码改动时」 |
| `blocked` ∈ `merge` / `rebase` / `cherry-pick` / `revert` | **强制单批**，并提示先完成或中止当前操作 |
| `blocked="mixed-stage"` | **暂停，不进任何提交路径**：同一文件既有暂存改动又有未暂存改动，整文件提交必然带走部分内容。要求用户先 `git add -A` 或 `git restore --staged .` 统一，再重跑体检 |
| `detached=true` | **警告**：处于 detached HEAD，提交后无法被任何分支引用。告知用户并确认后再继续（两种路径都生效） |
| `batch_enabled="false"` | **强制单批**（`config/action-map.yaml` 的 `batch.enabled` 总开关） |
| `volume_trigger=false` | **单批路径**（行为与历史一致，零额外开销） |
| `volume_trigger=true` | **分批候选** → 按 `references/batch-commit.md` 的 B2 判定是否需要拆 |

例外：用户明确说"分批提交 / 拆成几个 commit"时，忽略阈值与 `batch_enabled` 直接进入分批流程（`blocked` 非 none 时仍禁止；方案确认仍不可跳过）。

> 📍 `repo-preflight.sh` / `stage-paths.sh` 会自动切到**仓库根**执行，因此批次路径一律相对仓库根（如 `src/components/table`），不要加 `./` 前缀。

> 判定默认倾向「不拆」：只有确认存在多个独立主题时才拆，不要为了显得专业而分批。
> 分批的第二个收益：单批 diff 超 200 行会被降级为 `--stat`，message 质量显著下降；拆批后每批 diff 回到阈值内。

## 分批路径（多主题大改动）

完整流程见 `references/batch-commit.md`，此处只列骨架：

0. 先确认调用方不在「分批开发」上下文中（如 dev-flow `caller=batch-7`），否则默认禁用分批提交
1. `repo-preflight.sh` 采集全量清单（**含 untracked** —— `git diff` 看不到新文件，这是最容易漏改动的点）
2. LLM 主题聚类 → 输出**分批方案表** → `ask_followup_question` 等确认（强制，不可跳过）
3. `batch-state.sh init <N>` 记录进度（支撑中断恢复）
4. 逐批**串行**循环：`stage-paths.sh` 精确暂存 → 校验暂存区 → `git-diff-summary.sh --staged-only` 取本批 diff → 生成标准版 + 精简版 message（仅本批）→ 交互 → 提交（或用户自行提交后回执）→ 副作用校验 → `batch-state.sh next`
5. 全批完成后 `repo-preflight.sh` 复查剩余改动，必须为 0

## 分批红线（仅分批模式生效）

1. ❌ 禁止 `git add .` / `git add -A`（无路径）—— 只用 `scripts/stage-paths.sh`
2. ❌ 禁止跳过方案确认直接开始提交
3. ❌ 禁止在 `blocked != none` 时分批
4. ❌ 禁止把敏感文件（`.env*` / `*.pem` / `*.key` 等）纳入任何批次
5. ❌ 禁止同一文件的改动跨批（拆不开就合批，或交由用户手动 `git add -p`）
6. ❌ 禁止 `git push`
7. ❌ 禁止一次性把全部批次的 message 都生成好、再回头逐批暂存 —— 必须走「暂存本批 → 基于本批暂存 diff 生成 message → 交互 → 提交 → 推进下一批」的串行循环。并行预生成会让 message 与实际提交内容脱钩，hook 改写后更是无法对齐

## 单批路径（S1~S7）

> 下文小节标题沿用「步骤 N」表述，`S{N}` 与「步骤 {N}」等价（其他文档引用 S7 即步骤 7）。

### 步骤 1：获取代码改动信息（脚本化）

```bash
~/.codebuddy/skills/smart-commit/scripts/git-diff-summary.sh
```

脚本自动：
- 优先检查 staged，无暂存改动则降级到工作区
- 默认输出 full diff，超过 200 行（阈值在 YAML）自动降级为 `--stat`
- 元信息（mode/line_count/source/untracked_count）写到 stderr 便于 LLM 感知
- 无 diff 但存在未跟踪文件时输出 `mode=untracked-only` 并列出文件

> 阈值需要调整？改 `config/action-map.yaml` 的 `diff_threshold.full_diff_max_lines`。
> ⚠️ `git diff` 看不到 untracked 文件：出现 `untracked_count>0` 时必须提示先 `git add`，否则生成的 message 会漏掉新建文件。

### 步骤 2：生成简短描述（LLM 模糊判断）

**情况 A：用户提供了自定义描述** → 直接使用，跳过 diff 分析
**情况 B：用户未提供描述** → 基于 diff 内容 AI 生成，规则：

| 改动类型 | 描述格式 | 示例 |
|---------|---------|------|
| 新增文件 | `新增 xxx` / `添加 xxx 功能` | `新增用户头像组件` |
| 修改文件 | `优化 xxx` / `更新 xxx` | `优化列表渲染逻辑` |
| 删除文件 | `移除 xxx` / `删除 xxx` | `移除废弃的工具函数` |
| 修复问题 | `修复 xxx` | `修复支付金额计算错误` |

### 步骤 3：LLM 决定 action

基于 diff 内容 + 描述，按「Action 决策规则」中的映射表判断 action。合法 actions 白名单见 `config/action-map.yaml`。

### 步骤 4：LLM 生成双模式 body

基于 diff 内容分别生成标准版和精简版 body，遵循「Commit Body 双模式」规则。

### 步骤 5：二段式展示

生成后按「**标准版 → 精简版**」二段式展示（标准版固定在前）。

> 🔴 **可复制容器（强制）**：每个版本的 commit message 主体**必须用「text 围栏代码块」包裹**（三反引号 + `text`），让 IDE 渲染出复制按钮。
> 标题层（`📝` 汇总 + `📄`/`📋` 子标题）用**加粗**强调，**不带任何分割线**；**仅 commit message 主体入代码块**。

````
📝 Commit Message 已生成：

**📄 【标准版】**

```text
feat: 新增暗色模式开关

- 新增 ThemeToggle 组件，支持一键切换亮色/暗色主题，含过渡动画
- 修改全局 CSS 变量，将硬编码颜色值替换为 CSS 自定义属性以支持主题切换
- 新增 useTheme 自定义 Hook，封装主题状态管理和 localStorage 持久化逻辑
```

**📋 【精简版】**

```text
feat: 新增暗色模式开关

- 新增 ThemeToggle 组件
- 修改全局样式变量
- 新增主题持久化 Hook
```
````

### 步骤 6：用户交互决策

展示后弹出交互选项（使用 `ask_followup_question`）：

| 选项 | 说明 |
|------|------|
| 📦 标准版 + 自动提交 | 使用标准版 commit message 执行 `git add . && git commit`（仅单批模式可用） |
| 📦 精简版 + 自动提交 | 使用精简版 commit message 执行 `git add . && git commit`（仅单批模式可用） |
| ✏️ 修改 | 告诉我需要调整的内容，修改后重新展示 |
| 🔄 重新生成 | 重新分析 diff 生成 |
| ⏭️ 自行提交（继续执行后续环节） | 不执行 git commit，由用户自行提交；调用方继续执行后续环节 |

> 🔁 **分批模式不使用本表**：每批的交互选项见 `references/batch-commit.md` B6（含「AI 提交」与「用户自行提交」两条路径）。
> 📌 选项顺序固定：**第一项标准版提交、第二项精简版提交**，不要按偏好或历史选择调整顺序。
> 🔴 单批模式的 `git add .` **不适用于分批模式**（见「分批红线」），两套上下文不可混用。

### 步骤 7：自动提交（仅当用户选择「自动提交」选项时）

⚠️ **默认不执行任何 git 操作**，仅在用户明确选择「📦 自动提交」选项时执行：

```bash
# 0. 提交前身份检查（强制，禁止跳过）
git config user.name
git config user.email
git log -1 --format='%an | %ae'                                      # 最近一次提交（合并提交不作参照）
git --no-pager log -30 --format='%ae' | sort | uniq -c | sort -rn     # 历史身份分布，取众数为判定基准
git branch --show-current                                             # 确认当前分支

# 1. 暂存所有改动
git add .

# 2. 使用多行 commit（header + body）
git commit -m "header行" -m "body第1行" -m "body第2行" ...

# 3. 提交成功后展示结果
git log --oneline -1
```

**身份一致性校验（红线）**：

1. 采集三组值：`git config user.name` / `user.email`（实测值）、`git log -1 --format='%an | %ae'`（最近一次提交）、`git --no-pager log -30 --format='%ae' | sort | uniq -c | sort -rn`（历史分布）
2. 判定基准取**历史分布众数**（近 30 条里出现次数最多的身份）：实测值与之一致 → 直接通过，不拦截
3. `git log -1` **仅在该提交不是合并提交时作参考**：最近一次是 `Merge pull request` / `Merge branch`（GitHub 侧合并身份）或机器人账号时忽略该值，不得据此拦截
4. 实测值与历史众数不一致、且不是调用方提供的预期身份（如 dev-comp 工作上下文 `git_identity`）→ 🔴 **拦截提交**，弹 `ask_followup_question` 呈现「实测值 vs 历史众数」，选项：修正 local config 后重试 / 确认改用实测值继续 / 取消提交；**未经用户确认不得 `git commit`**
5. 仓库无历史提交时，以调用方提供的预期身份为准，无预期身份则默认采用实测值并明确告知用户

> ❌ 禁止自动执行 `git push`，push 始终由用户自行决定。

> 🔁 **分批模式**：每批提交重复本步骤。提交前暂存区边界已由 `stage-paths.sh` 严格校验（出现计划外文件会以 exit 3 中止），因此**禁止在此再执行任何 `git add`**；身份校验首次通过后同会话复用。

## 异常兜底

### 无代码改动时

`git-diff-summary.sh` 的 stderr 会输出 `{"mode":"empty",...}`，此时提示用户先进行代码修改，或手动提供描述信息。

### 脚本不可用时（兜底）

如果脚本因任何原因无法执行（权限、路径不存在等），LLM 应：
1. 优先告知用户脚本错误，建议重装/修复 Skill
2. 不得回退到自己心算 diff 内容——应提示用户使用 `git diff --cached` 或 `git diff` 获取

### 仓库处于中间态时

`repo-preflight.sh` 的 `blocked` 字段为 `merge` / `rebase` / `cherry-pick` / `revert` 时：

- ❌ 禁止进入分批流程（连续 commit 会破坏变基/合并状态）
- 提示用户先完成或中止当前操作，再生成 commit message

### 暂存区与工作区混合时（`blocked=mixed-stage`）

同一文件同时存在已暂存与未暂存改动，按文件粒度分批必然切错。处理：

1. 列出 `mixed_files` 清单
2. 提示用户二选一：`git add -A`（统一为已暂存）或 `git restore --staged .`（统一为未暂存）
3. 统一后重跑 `repo-preflight.sh` 再继续

### 分批过程中 commit 被拦截

commit-msg / pre-commit hook 拒绝时：**停止循环**，保留当前批暂存区，输出 hook 原始报错与修复建议。禁止自动改 message 绕过、禁止跳过该批继续下一批。详见 `references/batch-commit.md` B9。

## 完整示例

### 示例 1：用户提供描述

```
用户：帮我生成 commit message，描述：新增暗色模式

AI 执行：
1. 调用 scripts/git-diff-summary.sh → 拿到 file list / stat / diff
2. 使用用户提供的描述："新增暗色模式"
3. LLM 判断 action → feat（新增功能）→ 校验在白名单内
4. LLM 基于 diff 生成标准版/精简版 body
5. 二段式展示 + 用户交互
```

### 示例 2：用户未提供描述

```
用户：帮我生成当前 diff 的 commit message

AI 执行：
1. 调用 scripts/git-diff-summary.sh → 拿到 diff
2. LLM 基于 diff 生成简短描述："修复 marketplace 生成脚本 YAML 多行描述解析失败"
3. LLM 判断 action → fix（修复 bug）
4. LLM 基于 diff 生成标准版/精简版 body
5. 二段式展示 + 用户交互
```

最终输出形态（标题层用加粗强调，**无分割线**；commit message 主体在 ```text 代码块内，IDE 渲染复制按钮）：

````
📝 Commit Message 已生成：

**📄 【标准版】**

```text
fix: 修复 marketplace 生成脚本对 YAML 多行描述解析失败的问题

- 修复 generate-marketplace.js 中的 YAML 多行字段解析逻辑
- 调整 description 字段读取容错，遇到非字符串值时回退到默认描述
```

**📋 【精简版】**

```text
fix: 修复 marketplace 生成脚本对 YAML 多行描述解析失败的问题

- 修复 YAML 多行字段解析逻辑
- 调整 description 字段读取容错
```
````

### 示例 3：多主题大改动（分批）

```
用户：帮我提交，改了一堆不相关的东西

AI 执行：
1. repo-preflight.sh → changed_files=14, volume_trigger=true, blocked=none, untracked=5
2. 主题聚类 → 4 个主题（依赖升级 / 表格组件 / 日期修复 / 文档）
3. 输出分批方案表 → ask_followup_question → 用户选「✅ 按此执行」
4. batch-state.sh init 4
5. 第 1 批（串行，不可预生成后续批次）：stage-paths.sh package.json pnpm-lock.yaml
         → git-diff-summary.sh --staged-only
         → 基于本批暂存 diff 生成标准版 + 精简版 message
         → 用户选「🤖 标准版 + 本批提交」
         → 身份校验 → git commit → 副作用校验 → batch-state.sh next
6. 重复第 2~4 批（每批独立暂存、独立 message、独立校验；上一批未落定不得生成下一批 message）
7. repo-preflight.sh 复查 → changed_files=0（.env.local 为用户确认排除项）
8. batch-state.sh clear → 输出每批 header + hash 总览
```
