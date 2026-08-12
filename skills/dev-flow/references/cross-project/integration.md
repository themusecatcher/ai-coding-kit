# 跨项目联调 · step-6C 联调 / 验证 / 本地并行

> 父文件 → `references/cross-project-flow.md`。
> 本文件按需加载：B 项目 step-6C 命中跨项目 / A 项目验证回流 / 本地并行协作模式。

## step-6C 扩展：跨项目联调

### 触发条件

step-6C 评估时，工作上下文包含 `cross_project.enabled: true` → 自动触发跨项目联调模式。

### 扩展选项

| 选项 | 说明 |
| --- | --- |
| 🔗 跨项目联调 | 在验证项目中安装新版本并验证（生成回 A 项目的衔接 prompt） |
| ⏭️ 跳过联调 | 不需要跨项目验证，直接进入步骤 7 |
| 📝 生成 Commit 并暂存 | 先提交 B 项目代码，暂存等待跨项目验证 |

### 选择「跨项目联调」后

1. **更新状态**：`cross_project.status` → `fixed_pending_validation`
2. **生成 A 项目验证 prompt**：

```markdown
📋 **验证项目衔接 prompt**（粘贴到 A 项目新对话中）：

> dev-flow，跨项目验证衔接
> **修复项目**：{B 项目名}
> **工作上下文**：`{B 项目工作上下文文件路径}`
> **修复内容**：{一句话修复描述}
> **安装命令**：`npm install {包名}@{新版本}` 或 `npm link {本地路径}`
> **验证步骤**：
> 1. {验证步骤 1}
> 2. {验证步骤 2}

```

1. **交互式选项**：

| 选项 | 说明 |
| --- | --- |
| 📋 复制验证 prompt | 复制后去 A 项目验证，当前流程暂存于步骤 7 |
| 📦 先提交再验证 | 执行 commit 后再去验证 |

## A 项目验证回流

### 识别信号

A 项目新对话中检测到以下任一：

- 包含"跨项目验证衔接"关键词
- 包含来自 B 项目的工作上下文路径

### 验证流程

1. **读取 B 项目工作上下文**：提取修复内容和验证步骤
2. **安装新版本**：提示用户执行安装命令（**不自动执行**）
3. **按验证步骤逐项验证**：可选启动浏览器 MCP 自动化验证 / 用户手动验证后告知结果
4. **更新 B 项目工作上下文**：`cross_project.status` → `validated` 或 `failed`
5. **验证通过**：提示用户回 B 项目完成收尾（commit/devlog）
6. **验证失败**：记录失败原因，提示用户回 B 项目修复

## 知识库平台 消费方契约自动对齐

> A 项目验证回流阶段，B 项目修改的导出符号与 A 项目实际调用之间，可能存在版本/签名/参数不对齐风险。

### 触发条件（2）

A 项目收到「跨项目验证衔接」prompt **且** B 项目修改涉及导出 API（非纯改文案）时自动执行。

### 执行步骤

1. 从 B 项目工作上下文提取本次修改的导出符号（函数名/类名/签名）
2. 在 A 项目本地 `grep_search` 上述符号的实际调用点（导入 + 调用双检）
3. 交叉对比：

- 新签名 vs A 项目调用处的实际传参 → 不匹配 → 🔴 红色告警
- 新签名 vs A 项目 TypeScript 定义 → 不匹配 → 提示运行 `tsc --noEmit`

1. 输出综合结论到验证报告

### 输出模板

```markdown
🔍 契约对齐检测：{B 项目}→{A 项目}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
| 符号 | B 项目新签名 | A 项目调用 | 是否对齐 |
| --- | --- | --- | --- |
| isSameLink(a, b) | 无改动 | [Header/index.tsx#L42] 传参一致 | ✅ |
| 新增 fmtDate(v, opts?) | opts 可选 | 未调用 | ✅ |
| 修改 sign(s, key) → sign(s, { key }) | 对象语义 | [utils.ts#L18] 仍传位置参 | 🔴 不匹配 |

⚠️ 检测到 1 处契约不匹配，请在验证前调整 A 项目调用。

```

## 完整流转示例（isSameLink 修复）

```text
🅰️ A 项目（发起方）
├── 步骤 0-1：发现问题，定位到 B 项目依赖包
├── 步骤 2：⚡ 检测到跨项目 → 标记 cross_project
│   └── 生成 B 项目衔接 prompt → 用户复制
│   └── .flow: status=paused, phase=integration
└── 暂存

🅱️ B 项目（修复方，新对话）
├── 粘贴衔接 prompt → read_file 共用工作上下文
├── 更新共用 .flow: status=active, phase=coding
├── 步骤 0：增量理解（从工作上下文继承）
├── 步骤 1：跳过（A 已完成研究）
├── 步骤 2~5：确认范围 → 制定方案 → 执行修改
├── 步骤 6C：⚡ 检测到跨项目 → 生成 A 验证 prompt
│   └── .flow: phase=integration, recovery="等 A 验证"
└── 暂存（或先 commit 再暂存）

🅰️ A 项目（验证回流，新对话）
├── 粘贴验证 prompt → read_file 共用工作上下文
├── .flow: status=active, phase=integration
├── 安装新版本 → 逐项验证 → 通过
├── cross_project.status = validated
└── 提示回 B 项目完成收尾

🅱️ B 项目（收尾，新对话）
├── .flow: phase=commit-archive
└── 步骤 7 剩余环节（devlog + knowledge）→ 完成

```

## 边界情况处理

| 边界 | 处置 |
| --- | --- |
| **Monorepo** A/B 同 workspace 不同 package | step-2 检测到文件在不同 package 但同 workspace；提示选「⏭️ 当前项目继续」；不生成衔接 prompt，直接当前对话处理 |
| **B 项目工作区路径未知** | 衔接 prompt 中 `fix_workspace` 留空；B 项目新对话由用户确认 |
| **跨项目验证不通过** | 记录失败原因到 A 项目工作上下文；提示用户回 B 触发迭代修复（`dev-flow 继续 xxx 修复`）；走增量步骤 1~3 |
| **npm link vs npm install** | 验证 prompt 同时提供两种：`npm link {本地路径}`（本地联调，无需发版）/ `npm install {包名}@{版本}`（B 已发版） |

## 本地并行协作模式（同对话多仓库同时改动，2026-05-21 新增）

> **适用**：开发者本地同时有 A/B 两个（或更多）仓库改动，且**同对话**跨仓库执行编码、审查、提交。
> 与「三段式串行模式」并列存在。
> **典型案例**：`business-project` + `component-lib` 同时改 / yalc/npm-link 联调后批量审查提交。

### 触发条件（任一）

1. `git status` 显示改动文件 + 用户明确提到"另一个项目也改了"
2. 工作上下文 `cross_project.enabled: true` 且 `fix_workspace` 指向本地已知路径
3. 当前对话中已对非当前 workspace 的仓库执行过 `read_file`/`replace_in_file` 等编辑
4. 用户在编码阶段让 AI 同时在多个本地仓库执行修改

### 步骤同步规则（强制）

**核心原则**：**步骤 5.5 / 清理 / commit** 对每个有改动的仓库**独立逐一执行**，不可只处理主项目而遗漏协作项目。

| 步骤 | 规则 |
| --- | --- |
| **步骤 5.5（L1 审查）** | 每个仓库独立执行完整 8 项检查；ESLint 按各仓库自身配置跑 |
| **调试日志清理** | 每个仓库独立 `grep -rn -e "console.log" -e "\[DEBUG\]"` 验证；清理后必须再 `grep` 确认零命中 |
| **Commit** | 每个仓库独立生成 commit message；header 保持相同 任务平台 关联，body 注明跨项目配合关系 |
| **Commit 顺序** | 被依赖方（如组件库 B）先 commit，依赖方（业务项目 A）后 commit；保证 git 历史因果关系正确 |
| **package.json 检查** | 主项目 A 提交前检查依赖版本是否已恢复（去掉 yalc/link 调试改动）；本地联调改动（`file:.yalc/xxx`）**禁止**提交 |

### Commit Message 跨项目关联

- **B 项目（组件库）body 末尾**：`[跨项目] 配合 {A 项目名} {需求简述}，需同步升级消费方依赖版本`
- **A 项目（业务项目）body 末尾**：`[跨项目] 依赖 {B 包名}@{版本/分支}，组件库侧改动已同步提交`

### 工作上下文记录

`## 交付` 区块须列出所有仓库提交：

```markdown

## 交付
| 仓库 | 分支 | Commit | 状态 |
| --- | --- | --- | --- |
| component-lib | feature/xxx | feat: 列表支持个人用户展示模式 | ✅ 已提交 |
| business-project | feature/xxx | feat: 个人版分享弹窗支持列表 | ✅ 已提交 |
```

### 与三段式串行的判定边界

| 条件 | 走并行协作 | 走三段式串行 |
| --- | :---: | :---: |
| A/B 都在本地且同一开发者 | ✅ | — |
| B 在本地但需开新对话才能操作 | — | ✅ |
| B 不在本地（需 clone 或只有 知识库平台） | — | ✅ |
| 不同开发者负责 A/B | — | ✅ |
| 同一对话已对 A/B 都做了编辑 | ✅ | — |

### 反模式（违反即拒收）

- ❌ 只对主项目跑 L1 审查，遗漏协作项目调试日志/ESLint
- ❌ 主项目提交时未检查 package.json 是否含本地联调改动（yalc/link）
- ❌ 两仓库 commit 没有体现关联性
- ❌ 步骤 5.5 只跑了一次、对一个仓库的改动文件就宣告完成
- ❌ 依赖方先 commit、被依赖方后 commit（因果倒置）

## Diff / Commit 查看规范（跨项目改动确认）

> **背景**：feature 分支通常含从 master 合入的他人改动。`git diff merge-base..HEAD` 会把这些都算进去导致误判。`git log` 不加 `--author` 也会混入他人 commit。
> **适用**：收尾对账（步骤 7 环节 A）、跨项目验证（step-6C）、需求范围确认（step-2）。

### 强制顺序

1. **确认当前分支**：`git branch --show-current` → 必须与需求分支一致；不一致则**停止操作并提醒用户**（禁止擅自 checkout）
2. **查看 diff 时区分"本人"与"合入他人"**（按场景三选一）：

- **场景 1（默认）· 按作者过滤**：`git --no-pager log --oneline --author="{用户名}" $(git merge-base origin/master HEAD)..HEAD` 列出本人 commit，再逐个 `git --no-pager show <hash> --stat` 查看
- **场景 2 · 多人协作 / squash merge 后追溯 · 按 任务平台 单据过滤**：`git --no-pager log --oneline --grep="--story={task_id}" $(git merge-base origin/master HEAD)..HEAD` 聚合同一需求的所有 commit（覆盖跨开发者、跨分支、squash 后丢失作者信息的场景）；任务平台 bug 用 `--grep="--bug={id}"`，task 用 `--grep="--task={id}"`
- **场景 3 · 长周期需求全量对账（多次迭代修复后）· 双重过滤**：先按 `--author` + `--grep="--story="` 双条件交叉验证 commit 完整性（`git log --author="{用户名}" --grep="--story={task_id}"`），再用 `git --no-pager diff $(git merge-base origin/master HEAD)..HEAD` 看完整累积改动，配合步骤 7 环节 A · §H.3+ 三方对账兜底
- ⚠️ `git diff merge-base..HEAD` 结果**可能含他人改动**，不能直接作为需求范围结论

1. **查看 commit 必须过滤作者或 任务平台 单据**：默认加 `--author="{用户名}"`；多人协作 / squash merge 场景加 `--grep="--story={id}"`；禁止两者都不加就断言"该分支有/没有某改动"

### 反模式（违反即拒收）（2）

- ❌ 不确认分支就执行 `git diff`
- ❌ 用 `git diff merge-base..HEAD --name-only` 直接当作"本需求改动文件清单"
- ❌ 不加 `--author` 看 `git log` 就说"该项目 commit 内容是 XXX"
- ❌ 因 `git diff merge-base..HEAD` 与预期不符就得出"该项目未做改动"（应进一步用 `git show <hash>` 确认本人 commit 实际内容）
- ❌ 多人协作 feature 分支 / squash merge 后追溯场景，仅用 `--author` 过滤就断言需求范围（会漏掉队友为同一 story 提交的代码、漏掉 squash 后丢失作者信息的 commit）；必须叠加 `--grep="--story={id}"` 按 任务平台 单据聚合
- ❌ 长周期需求（多次迭代修复后）只看最近一次 `git diff` 就汇报完成；必须按场景 3 双重过滤交叉验证 + §H.3+ 三方对账兜底

### 统计结果回写（步骤 7 / 9a 度量采集时）

逐项目完成 diff 统计后，必须回写主项目工作上下文 `cross_project.projects_detail`（每项目 `branch` / `files_changed` / `lines_added` / `lines_deleted` / `mr` / `mr_url` / `mr_status`，schema 见 `templates/working-context.tpl.md`）——这是复盘报告「涉及项目」链路图的唯一数据源；未回写则报告节点只显示项目名与角色，无分支/规模/MR 信息。迭代修复轮次中改动有变化时同步更新。

## 历史相似改动反查规范（问题驱动）

> **背景**：dev-flow 步骤 1（研究）/ 步骤 5（编码定位）期间，发现某段代码可疑（如疑似缺可选链、疑似竞态、疑似空 catch），需要回溯**历史需求里有没有相同模式的坑**——以判断本次是孤例还是系统性遗漏，并避免遗漏同类隐患。
> 与上一节「Diff / Commit 查看规范」的边界：上一节是**收尾对账 / 改动确认**（"我改了什么"），本节是**问题驱动反查**（"历史改动里有没有相同模式的坑"），命令栈与意图均不同。
> **适用**：步骤 1 研究阶段验证某代码模式的历史风险面 / 步骤 5 编码时发现可疑模式需举一反三 / issue-trace 中怀疑 bug 由历史需求引入时。

### 命令栈（按优先级）

1. **按字面量回溯（首选 · 准确率最高）** · `git log -S`

- 命令：`git --no-pager log -S"{字面量}" --all --oneline --source`
- 用途：找出**新增或删除**了该字面量的所有 commit（pickaxe 模式）。如查"哪些 commit 引入了 `order_simple_info.order_code` 的裸链式访问"
- 加 `--all` 可跨分支搜索；加 `-p` 看具体 diff；加 `--follow {file}` 跟踪文件改名

1. **按正则模式回溯** · `git log -G`

- 命令：`git --no-pager log -G'{正则}' --all --oneline`（用单引号避免 shell 转义干扰）
- 用途：字面量不固定时按模式搜。**注意 `-G` 只匹配 diff 中"新增/删除行"包含该模式的 commit，不匹配代码当前状态**——所以正则要尽量贴近"曾经被增删过的具体行的关键特征"
- 推荐示例（按由稳到激进排序）：
- `git log -G'catch\s*\(\s*\w+\s*\)\s*\{\s*\}' --all --oneline` 找空 catch 引入历史
- `git log -G'\bvar\s+\w+' --all --oneline -- '*.ts' '*.tsx'` 找 var 残留引入
- `git log -G'==\s*null' --all --oneline` 找弱等判空
- **不推荐**形如 `\?\.\w+\?\.\w+\?\.length` 的多层链式裸正则——历史 commit 同时增删三层链式的概率极低，常出空结果；这种场景改用：先 `grep -rn '?\..*?\..*?\.length' src/` 找当前代码命中位置 → 再对每处 `git blame -L` 回溯（见命令 3）

1. **精确定位问题行修改人** · `git blame -L`

- 命令：`git --no-pager blame -L {起始行},{结束行} -- {文件路径}`
- 用途：确认**当前可疑行**最后由哪个 commit 引入；与 issue-trace 相关模块共用同一规范，但本节关注"该 commit 是哪个需求引入的"
- ⚠️ 必须 `-L` 精确到问题行，禁止用 `git log {file}` 当替代（前者定位行，后者定位文件最后修改）

1. **关联到 任务平台 需求单（用于判定"哪个需求引入了这个坑"）**

- 命令：`git --no-pager log -S"{字面量}" --all --grep="--story=\|--bug=\|--task=" --oneline`
- 或：拿到嫌疑 commit 后 `git --no-pager show {hash} | head -20` 看 commit message 中的 `--story=xxx` / `--bug=xxx`
- 用途：把代码模式 → commit → 任务平台 单据串联，便于在 任务平台 上反查需求背景，决定是否需要顺手举一反三修同类坑

### 命令选用决策

| 场景 | 首选命令 | 备选 |
| --- | --- | --- |
| 知道具体的可疑字符串（变量名/字段名/字面量） | `git log -S` | `git log -G`（带正则边界） |
| 只能用模式描述（"裸链式 length 访问"） | `git log -G` | grep 当前代码 + `git blame -L` 逐个回溯 |
| 怀疑当前某行是历史 bug | `git blame -L` | 拿到 commit 后再 `git log -S` 扩展同类 |
| 想知道"这个反模式还在哪些需求里出现过" | `git log -S` 或 `-G` 后 `--grep` 提取 story 列表 | 结合 `git_merge_request` 知识库平台 查 MR 评审历史 |

### 反模式（违反即拒收）（3）

- ❌ 用 `git log {file}` 替代 `git blame -L {start},{end}`——前者只能定位文件最后修改者，无法精确到问题行的引入 commit
- ❌ 用 `grep -rn` 当前代码后就断言"历史也是这么写的"——当前代码只是切片，必须用 `git log -S/-G` 看历史增删轨迹
- ❌ 找到一个嫌疑 commit 就停手——必须用 `--all` 跨分支、用 `-S/-G` 列全量同模式 commit，避免漏掉合入主干前的 feature 分支历史
- ❌ 不区分"问题驱动反查"与"收尾对账"——前者用 `-S/-G/blame -L`，后者用上一节的 `--author/--grep="--story="`；混用会得出错误结论
- ❌ 反查到历史同类坑后**擅自顺手修复**——按红线 #2 最小入侵：发现范围外同类问题 → 提及但不擅自修改，告知用户后由用户决定是否新开 dev-flow 处理

### 与其他 skill 的协作

| 来源场景 | 入口 | 进入本节的方式 |
| --- | --- | --- |
| dev-flow 步骤 1 研究阶段，需要评估某代码模式的历史风险面 | 步骤 1 研究 | 加载本节命令栈 |
| dev-flow 步骤 5 编码时发现可疑模式，要决定是否扩大修复范围 | 步骤 5 编码 | 反查后回到红线 #2 决策（不擅自扩范围，告知用户） |
| issue-trace 纯分析阶段沿调用链回溯根因 | issue-trace 主流程 | 拿到可疑代码切片后用本节命令栈反查历史改动轨迹 |
