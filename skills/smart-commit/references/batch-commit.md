# 分批提交（Batch Commit）

> 加载时机：`SKILL.md` 入口路由（S0）判定为**分批候选**，或用户显式要求分批提交。
> 目标：把 N 个不同主题的增量改动，拆成 N 个**自解释、可独立回滚**的 commit。
> message 格式、双版本 body、action 决策规则沿用 `SKILL.md`，本文件不重复。

---

## B0 前置约定

| 约定 | 说明 |
|------|------|
| 独占暂存区 | 进入分批时暂存区应为空；非空则先询问「作为第 1 批内容」还是「先清理」（清理命令由用户执行） |
| 精确暂存 | 全程只用 `scripts/stage-paths.sh`，❌ 禁止 `git add .` / `git add -A`（无路径） |
| 不 push | 分批结束也不执行 `git push` |
| 提交执行权 | 每批交互时由用户当场选择：🤖 AI 执行（`git commit`）或 🙋 用户自行执行（AI 只给命令）。用户选择即视为当次授权 |
| 身份校验 | 首次提交前执行一次 `SKILL.md` 步骤 7 的身份校验，同会话后续批次复用结论；`git config` 变化则重校 |
| 调用方上下文 | 若调用方本身处于「分批开发」（如 dev-flow `caller=batch-7`，message 带 `[batch N/M]`），**默认禁用分批提交**（双层 batch 语义冲突）；用户显式要求时仍可分，但每批 message 保留原 `[batch N/M]` 标识 |
| 调用方交互 | 调用方（如 dev-flow 步骤 7）若已定义固定的 4 项确认交互，**分批方案确认必须在其之前完成**，且每批最终 message 仍按调用方约定回填工作上下文，不得因为分批而跳过调用方的确认环节 |

---

## B1 采集全量清单

```bash
~/.codebuddy/skills/smart-commit/scripts/repo-preflight.sh
```

**这是分批的唯一数据源**。不要用 `git diff --name-only` 代替 —— 它看不到 untracked 文件（新建文件全部漏掉）。

| 字段 | 用途 |
|------|------|
| `blocked` | `merge`/`rebase`/`cherry-pick`/`revert` → 强制单批；`mixed-stage` → 暂停并要求先统一暂存区 |
| `batch_enabled` | `false` → 强制单批（配置总开关，用户显式要求分批时仍可覆盖） |
| `volume_trigger` | 是否达到分批分析阈值（`min_files` / `diff_lines_trigger`） |
| `changed_files` / `untracked` / `deleted` / `renamed` | 全量清单规模 |
| `mixed_files` | 同文件既暂存又改动 → 必须先统一暂存区 |
| `top dirs` | 主题聚类的第一手信号 |
| `sensitive` | 默认排除出所有批次 |
| `generated` | `dist/es/lib/*.lock` 等，提示用户是否入库 |

---

## B2 是否需要分批

**默认不拆**。下表「建议拆」的 3 个条件**同时满足**才拆（`volume_trigger` 本身已包含「文件数 ≥ min_files **或** 总行数 > diff_lines_trigger」）：

| 结论 | 条件 |
|------|------|
| 建议拆 | ① `volume_trigger=true` ② 主题数 ≥ `min_themes`(2) ③ 最大主题文件占比 ≤ `max_theme_file_ratio`(0.7) |
| 不拆 | 主题唯一（哪怕 300 文件，如全仓 prettier 格式化 → ③ 必然不满足） |
| 不拆 | 改动文件 ≤ 3 |
| 不拆 | 存在强绑定关系且无其他主题 |
| 不拆 | `blocked != none` 或 `batch_enabled=false` |
| 不拆 | 用户明确说"不用拆" |

> ③ 的分母是 `changed_files`（含 untracked），分子是主主题的文件数。主题由 LLM 聚类得出，占比由 LLM 自行核算后写入判定理由。

批次数 > `max_batches`(6) 时**不是继续拆**，而是提示「拆得过细，建议合并为 4 批」并重出方案。
拆出结果只有 1 批时（用户显式要求分批，但实际只有一个主题）→ **不启动分批状态机**，直接回单批路径。

判定完成后，对用户说明结论与理由（一句话），不拆则直接走 `SKILL.md` 单批路径。

---

## B3 主题聚类

### 聚类依据（优先级从高到低）

1. **会话上下文**：本轮对话实际讨论了几件事 —— 最强信号
2. **模块归属**：`src/components/x` vs `src/views/y` vs `docs`
3. **变更类型**：新增 / 修复 / 重构 / 格式化
4. **文件命名与 diff 语义**
5. **依赖方向**：被依赖者排在前

### 强绑定组（禁止拆散，脚本清单里出现即自动归并）

| 组 | 成员 | 拆开的后果 |
|----|------|-----------|
| 依赖组 | `package.json` + `pnpm-lock.yaml` / `yarn.lock` / `package-lock.json` | 中间态无法安装 |
| 类型产物组 | `components.d.ts` / `auto-imports.d.ts` + 触发它的源码 | 中间态类型报错 |
| i18n 组 | 各语言同一 key 的资源文件 | 中间态缺翻译 |
| 组件组 | 组件源码 + 样式 + 类型 + 文档 + demo | 中间态组件不可用 |
| 重命名对 | porcelain `R` 状态（旧路径删除 + 新路径新增） | 只 add 一半会让删除残留在工作区；`git add -A -- <新路径>` 会自动暂存旧路径的删除，所以**批次清单里只写新路径** |
| 源码+产物 | 入库的 `dist/es/lib` 与其源码 | 产物与源码不一致 |

### 同一文件含多个主题

按文件粒度拆不开。三选一，**默认 A**：

| 方案 | 做法 |
|------|------|
| A 合批（默认） | 保持文件完整，并入**主主题**批；message body 追加一行说明顺带改了次要内容 |
| B 用户手拆 | AI 输出该文件的 hunk 清单与逐条 `git add -p` 命令，用户自行执行后告知继续 |
| C 全部归主主题 | 次主题在 body 中省略（不推荐，会丢失信息） |

禁用：AI 自行发明 hunk 级拆分脚本。

### 排序规则

批次顺序按依赖方向排：**依赖/配置 → 类型与源码 → 测试 → 文档与格式化**。

约束：每批应能独立回滚，不依赖后续批次的代码。若发现反向依赖，调整顺序或合批。

---

## B4 方案表输出（必须先确认）

```text
📦 全量改动 14 文件 / +430 −120 行 → 识别 4 个主题 → 建议拆 4 批

| 批 | 主题 | 预期 action | 文件 | ±行 | 依赖/风险 |
|---|---|---|---|---|---|
| 1 | 升级依赖 | chore | package.json, pnpm-lock.yaml | +120/−30 | 无（强绑定已合） |
| 2 | 分组表格组件 | feat | 5 个 src/components/table/* | +210/−40 | 依赖第 1 批 |
| 3 | 修复日期格式 | fix | src/utils/date.ts + 2 个 views | +30/−15 | 无 |
| 4 | 文档与新演示 | docs | 3 个 docs/*, 2 个 views/demo | +70/−35 | 依赖第 2 批 |

⚠️ 同文件多主题：src/views/home/Index.vue 同时含批 2 与批 4 改动 → 已并入批 2
⛔ 排除：packages/.env.local（敏感文件，不进入任何批次）
```

方案表下方的交互（`ask_followup_question`，**强制，不可跳过**）：

| 选项 | 行为 |
|------|------|
| ✅ 按此执行 | 进入 B5 逐批循环 |
| 🔀 调整划分 | 按用户意见重排批次 |
| 🔁 合并为一批 | 退出分批，回到单批路径 |
| 📋 只出方案不执行 | 结束，不暂存不提交 |

文件清单必须来自 `repo-preflight.sh` 的真实输出，❌ 禁止凭记忆或推断列举。
表中「±行」为辅助信息：需要时用 `git diff --numstat` 取（未跟踪文件按 `wc -l` 估算），**不确定就留空，禁止编造数字**。

---

## B5 逐批执行循环

对第 i 批（i = 1..N）依次执行：

### B5.1 预检

```bash
git -c core.quotePath=false status --porcelain -uall
git -c core.quotePath=false diff --cached --name-only
```

校验三点：

1. **暂存区必须为空**（每批提交后都应清空）。非空 → 说明上一批没提交干净或用户手动 add 过，先处置再继续（`stage-paths.sh` 会以 exit 5 兜底拦截）
2. **改动清单应与方案一致**。出现方案外的新改动 → 暂停，询问「并入剩余批次」还是「重新规划」
3. **HEAD 应与上一批记录一致**。不一致说明用户中途提交过 → 重新体检，建议重出方案

### B5.2 精确暂存

```bash
~/.codebuddy/skills/smart-commit/scripts/stage-paths.sh <本批路径...>
```

脚本内部：校验路径属于改动清单 → 比对暂存区是否已含本批外文件 → `git add -A -- <path>` → 与暂存后快照严格比对。
- 入参可为文件或**目录**（目录展开为该目录下全部改动文件）
- 退出码 `5`（暂存区已有本批外文件）/ `3`（add 后冒出计划外文件）/ `4`（路径未生效）→ **立即停止**，不要继续提交
- 想先确认再执行可加 `--dry-run`，它会列出展开后的文件清单而不改动暂存区

### B5.3 取本批 diff

```bash
~/.codebuddy/skills/smart-commit/scripts/git-diff-summary.sh --staged-only
```

`--staged-only` 保证读到的是**本批实际要提交的内容**，绝不回退到工作区。

### B5.4 生成 message

按 `SKILL.md`「Commit Message 格式规范」生成**标准版 + 精简版**，展示时标准版在前、精简版在后：
- **只生成本批**：不得提前生成后续批次的 message（上一批未落定，后续批的暂存内容与 diff 都还不存在）
- body 只描述本批文件，不承诺后续批次的内容
- 同一 action 出现在多批时，header 描述必须能相互区分
- 不写「第 1/4 部分」这类内部进度（除非调用方要求 `[batch N/M]`）
- **持久化**：调用方带工作上下文（dev-flow / dev-comp）时，每批确认后追加写入 `## 交付 → ### Commit 批次`，格式 `- [i/N] <header> → <hash>`；禁止只记录最后一批（后续复盘需要完整提交轨迹）

### B5.5 交互

见 B6。

### B5.6 提交（仅当用户选择 AI 执行）

```bash
git config user.name
git config user.email
git log -1 --format='%an | %ae'
git branch --show-current

git commit -m "<header>" -m "<body 第 1 行>" -m "<body 第 2 行>"

git log --oneline -1
git diff --cached --name-only    # 提交后应为空
```

用户自行提交有两条入口，**校验逻辑相同**，区别只在时机：

| 入口 | 时序 | 输出物 |
|------|------|--------|
| 🙋 我已自行提交完成 | 用户先在自己终端提交完，再选此项 | 直接进校验，不再输出命令、不再二次确认 |
| 🙋 只出 message，我稍后提交 | 用户想要命令自己执行 | 输出 message + `git add -A -- <本批路径>` + `git commit` 命令，等用户回「已提交」再校验 |

校验**三点**：

1. `git rev-parse HEAD` 与提交前记录**不同** → 确实新增了 commit
2. `git diff --cached --name-only` 为空 → 暂存区已清
3. `git show --name-only --format='' HEAD` 覆盖本批全部文件；出现本批外文件 → 报告用户，让用户确认是并入本批说明还是保留

| 结果 | 含义 | 处置 |
|------|------|------|
| 三项都满足 | 正常 | 继续下一批 |
| HEAD 未变 | 用户还没提交（多见于误选「我已自行提交完成」） | 提示当前 HEAD 与预期，等待或改用 AI 提交，不推进批次 |
| 暂存区非空 | 用户只 add 未 commit，或 hook 留下残留 | 追问具体状态，禁止直接推进 |
| HEAD 含本批外文件 | 用户把额外改动一并提交了 | 停下报告文件清单，确认后再推进，下批清单需相应剔除 |

### B5.7 副作用校验（易被忽略）

```bash
git -c core.quotePath=false status --porcelain -uall
```

三种结果分别处置：

| 现象 | 含义 | 处置 |
|------|------|------|
| 暂存区为空且工作区无新增 | 正常 | 继续下一批 |
| **本批文件**有新的未暂存改动 | hook 对该批文件做了格式化（lint-staged / prettier） | 重新 `stage-paths.sh` 该批路径，然后 `git commit --amend --no-edit` 把格式化结果并入**同一批**；重试 1 次，再失败则停止 |
| **本批之外**的文件被改写 | hook 越界修改 | 立即停止并报告，禁止把污染带进下一批 |

> ⚠️ 不要用「再提交一个新 commit」处理格式化残留 —— 那会让批次数量与方案不符。

### B5.8 状态推进

```bash
~/.codebuddy/skills/smart-commit/scripts/batch-state.sh next --hash "$(git rev-parse HEAD)" --header "<header>"
```

用户自行提交时同样执行，hash 取用户提交后的 `git rev-parse HEAD`。

### B5.9 阶段汇报

```text
✅ 第 3/4 批已提交（fix: 修复日期格式计算偏差）
剩余改动：5 个文件 → 下一批：文档与新演示
```

---

## B6 每批交互选项

| 选项 | 行为 |
|------|------|
| 🤖 标准版 + 本批提交，继续下一批 | AI 执行 commit 并推进（**固定第一项**） |
| 🤖 精简版 + 本批提交，继续下一批 | AI 执行 commit 并推进（**固定第二项**） |
| 🙋 我已自行提交完成 | 用户已在自己终端提交完本批 → 直接做 B5.6 三点校验并推进，不再二次确认、不再等回执 |
| ✏️ 修改本批 message | 修改后重新展示 |
| 🙋 只出 message，我稍后提交 | 不提交，输出命令后暂停，等用户回「已提交」 |
| 🔀 调整剩余批次划分 | 只重算 i+1 之后，已提交的不动 |
| ⏭️ 剩余全部合并为一批 | 收敛为单批收尾 |
| ⏸️ 暂停（可恢复） | 状态已持久化，提示下次 `smart-commit resume` |
| 🛑 终止分批 | 输出 `git restore --staged .` 回退说明，由用户执行 |

`ask_followup_question` 单次最多 4 个选项，按以下方式拆分：

| 轮次 | 选项 |
|------|------|
| 第一次（每批必问） | 🤖 标准版+提交 / 🤖 精简版+提交 / 🙋 我已自行提交完成 / ✏️ 修改本批 message |
| 第二次（仅当用户表达"要不要调整/暂停/稍后提交"时） | 🙋 只出 message 稍后提交 / 🔀 调整剩余划分 / ⏸️ 暂停 / 🛑 终止分批 |

> 📌 顺序约束：第一轮第一项必须是**标准版 + 提交**、第二项必须是**精简版 + 提交**，不随用户历史选择调序。
> 📌 「我已自行提交完成」是**用户已执行完**的回执入口，命中后不得再问「要不要我帮你提交」，直接进校验。
> 暂停、终止、调整划分、稍后提交都可由用户随时用自然语言触发，不必强行占用选项位。

---

## B7 收尾闭环（强制）

```bash
~/.codebuddy/skills/smart-commit/scripts/repo-preflight.sh
```

- `changed_files` 必须为 0，或仅剩用户明确排除的文件（敏感文件等）
- 仍有剩余 → 不结束，列出剩余清单 + 询问「追加为新批次」/「保持未提交」
- 全部完成 → `batch-state.sh clear`
- 输出总览：每批 header + hash，便于用户 `git log` 复核

---

## B8 中断与恢复

用户说"继续之前的分批提交"或 `smart-commit resume`：

```bash
~/.codebuddy/skills/smart-commit/scripts/batch-state.sh status
~/.codebuddy/skills/smart-commit/scripts/repo-preflight.sh
```

1. 读出 `current` / `total` / 已提交批次
2. 校验 `base_head` 与当前分支历史是否连续（`git log --oneline -N` 对照已记录 hash）
3. 若用户中途插入过别的 commit → 提示可能错位，建议重新出方案
4. 从 `current` 指定批继续；若剩余改动与方案不符 → 重新出方案确认

状态文件位置：`~/.codebuddy/smart-commit/sessions/<toplevel-hash>.state`（不写入仓库、不修改 `.git` 配置）。

> 中途放弃且未执行 `clear` 会残留状态文件：下次 `init` 会覆盖，也可手动 `batch-state.sh clear`。`status` 与 `resume` 等价。

---

## B9 失败处置

| 现象 | 处置 |
|------|------|
| `stage-paths.sh` exit 2 | 路径不在改动清单：拼写错误 / rename 后传了旧路径 / 被 .gitignore 忽略 → 停止，让用户确认 |
| `stage-paths.sh` exit 3 | add 后冒出计划外文件 → 停止，输出 `git restore --staged <路径>` 建议，不自动执行 |
| `stage-paths.sh` exit 4 | 路径未真正暂存 → 停止，检查忽略规则 |
| `stage-paths.sh` exit 5 | 暂存区已含本批外文件 → 停止，先 `git restore --staged <污染文件>`，或把该文件纳入本批计划 |
| commit-msg / pre-commit 拒绝 | 停止循环，原样输出 hook 报错；禁止改 message 绕过、禁止跳过该批 |
| hook 自动格式化改写了本批外文件 | 停止，报告被改写文件，询问是否并入后续批次 |
| 提交后暂存区非空 | 说明有文件未被 commit，停止并排查 |
| 用户中途新增改动 | 剩余批次重算，重新出方案确认 |
| 用户中途切分支 / 改动 HEAD | 停止，重新体检，建议重新出方案 |

---

## B10 反模式（违反即视为流程失败）

1. ❌ 为"看起来专业"而把单主题改动拆成多批
2. ❌ 用 `git add .` 之后声称"只提交本批"（暂存区已污染，无法保证边界）
3. ❌ 拆批时漏掉 untracked 文件（只用 `git diff` 分析）
4. ❌ 发现漏文件就直接塞进当前批（破坏批次主题纯净度）
5. ❌ 把 `package.json` 与 lock 文件拆到两批
6. ❌ 同一文件跨批（除非用户手工 `git add -p`）
7. ❌ 跳过方案确认直接开始提交
8. ❌ 某批失败后继续下一批
9. ❌ 全批完成后不做剩余改动复查
10. ❌ 把敏感文件（`.env*` / `*.pem`）纳入任何批次
11. ❌ 一次性预生成全部批次的 message 再回头逐批暂存 —— message 与真实暂存内容脱钩，用户无法逐批决策，hook 改写后更无法对齐
12. ❌ 用户已选「我已自行提交完成」后还追问「要不要我帮你提交」—— 该选项本身就是「已执行完」的回执，应直接进三点校验并推进
