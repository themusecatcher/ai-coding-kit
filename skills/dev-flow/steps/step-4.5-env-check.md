# 步骤 4.5：开发环境就绪检查（首次自动触发）

> 本文件仅在执行步骤 4.5 时加载。当前项目首次进入步骤 5 时自动触发。用户已确认过则跳过。

## 目标

确保在正确的 Git 分支上开发，开发环境就绪。

## 参考加载

环境与工具配置参考 → `read_file("references/env-tools.md")`（含 Git Worktrees 等）

## 执行规范

### 1. Git 分支检查（强制，纯校验，不再推荐分支名；**父孙分支等价**）

> **职责单一化**：本步骤不承担任何分支名推荐/生成职责。
> 分支名由步骤 4 §4.1「分支名最终推荐」唯一产生（写入工作上下文 `branch` / `branch_dev` / `branch_workspace` 字段）。
> 本步骤只做「当前分支 vs 工作上下文期望」的一致性校验，**父分支与孙分支视为等价匹配**（任一命中即过）。

**执行流程**：

1. 读取工作上下文 YAML 头部的分支字段：

- `branch`（父分支名，步骤 4 定稿值）
- `branch_dev`（孙分支名；feature/ 场景且选了孙分支时为 `feature_dev/.../<开发者>`，其他场景= `branch`）
- `branch_workspace`（用户选定的实际编码分支，= `branch` 或 `branch_dev`）
- `has_dev_branch`（布尔值，决定是否启用父孙等价逻辑）

1. 执行 `git branch --show-current` 获取当前分支名
2. **计算合法分支集合**：`accepted_branches = unique({branch, branch_dev})`，其中任一者与当前分支一致即视为 `🟢 正常`
3. 按下方「§2 智能分级处理」判断一致性并决定交互方式

### 2. 智能分级处理（默认静默，异常才打断；**新增父孙兼容**）

> **设计意图**：大多数情况下环境是就绪的，无需让用户每次都点一次确认弹窗。
> 4.5 在 `interaction-mode.md` 中被定义为 🟢 流程决策点（一行摘要，异常时才暂停），本节落实这一定位。
> **底线不降级**：主干分支检测（master/main/develop）这条红线在任何模式下都必须强制交互。
> 🆕 **父孙分支等价**：当 `has_dev_branch=true` 且当前分支 ∈ {`branch`, `branch_dev`} 中任一者 → 视为 🟢 正常，不再误报「分支漂移」。

**分级判断表**（按顺序匹配，命中即执行对应动作）：

| 场景 | 判断条件 | 处理方式 | 交互式选项 |
| --- | --- | --- | --- |
| 🟢 正常（精确匹配） | 当前分支 === `branch_workspace` 且非主干且非公共分支 | 一行摘要后静默推进 | ❌ 无需弹窗 |
| 🟢 正常（父孙等价） | `has_dev_branch=true` 且当前分支 ∈ {`branch`, `branch_dev`} 且非主干且非公共分支 | 一行摘要标注实际使用分支后静默推进 | ❌ 无需弹窗 |
| 🟠 公共分支风险 | 当前分支名匹配 `-common`/`-shared` 后缀或 `references/shared-rules.md` §7.1 定义的公共分支命名模式 | 警告 + 提示「当前在公共分支上，不建议直接在此开发」+ 输出切回个人分支命令 + **必须** `ask_followup_question` 确认 | ✅ 必须弹窗 |
| 🟡 分支漂移 | 当前分支为 feature/feature_dev 但不在 `accepted_branches` 集合中且非公共分支 | 警告 + 输出切换命令 + **必须** `ask_followup_question` 确认 | ✅ 必须弹窗 |
| 🔴 主干分支 | 当前分支为 master/main/develop 且 `branch_workspace` 非空 | 强制阻断 + 输出双分支创建命令 + **必须** `ask_followup_question` 确认 | ✅ 必须弹窗（不可豁免） |
| ⚠️ 字段缺失 | `branch_workspace` 字段为空（未走过步骤 4 §4.1 或历史文件未迁移） | 尝试降级读取 `branch`；`branch` 也为空则到 `references/shared-rules.md` §6 由用户自行命名 + **必须** `ask_followup_question` 确认 | ✅ 必须弹窗 |

**🟢 正常场景一行摘要示例**：

```text
✅ 步骤 4.5 完成：环境就绪（当前分支 feature/block-long-term，与定稿一致）

```

**� 正常（父孙等价）一行摘要示例**：

```text
✅ 步骤 4.5 完成：环境就绪
当前分支：feature_dev/ban-long-block/{username}（孙分支）
定稿父分支：feature/ban-long-block（与当前孙分支等价匹配）

```

**🟠 公共分支风险输出示例**：

```text
⚠️ 步骤 4.5 警告：您当前在公共分支「feature/new-split-speaker-common」上
   该分支为多人共用分支，不建议直接在此开发。
   建议切回个人孙分支：feature_dev/new-split-speaker/{username}

   如已误在此分支做了改动，请参考 shared-rules.md §7.1 四级恢复矩阵处理。
```

**🔴 主干分支场景输出命令示例**（双分支版本）：

```bash

# has_dev_branch=true 场景：推荐依次创建父分支 → 孙分支
git checkout master
git pull
git checkout -b feature/ban-long-block       # 创建父分支
git checkout -b feature_dev/ban-long-block/{username}  # 从父分支创建孙分支

# has_dev_branch=false 场景：仅创建 branch
git checkout master
git pull
git checkout -b bugfix/fix-date-display

```

**🟠/🟡/🔴/⚠️ 异常场景交互式选项**（按需弹出，文本+交互式双重展示）：

| 选项 | 说明 |
| --- | --- |
| ✅ 已切换/已配置完成 | 我已按指引切换分支或解决问题，继续进入步骤 5 |
| 🛠️ 需要更多时间配置 | 暂停，等我处理好后恢复 |
| ⏭️ 跳过检查强制推进 | 我清楚风险，直接进入步骤 5（仅 🟠/🟡/⚠️ 可用；🔴 主干分支禁止跳过） |

> ⚠️ 🔴 主干分支场景下「⏭️ 跳过」选项必须**物理移除**（不展示），这是 `shared-rules.md` L483「步骤 4.5 是分水岭」的强制要求。
> ❌ 禁止 AI 自动执行 `git checkout -b`，切换分支必须由用户手动执行。

### 3. 精简模式行为

当工作上下文 `interaction_mode: streamlined` 时：

- 🟢 正常场景 → 一行摘要，静默完成本步骤并静默推进到步骤 5（符合 `step-router.md` §「精简模式豁免」4.5→5）
- 🟠/🟡/🔴/⚠️ 异常场景 → **自动升级为标准交互**，仍必须 `ask_followup_question`（不可豁免异常处理）

## ⛔ 退出自检清单（逐项口播确认后才能输出完成 JSON）

在输出完成标记 JSON 之前，逐项确认并口播：

- [ ] 当前分支已检查？`git branch --show-current` 已执行？
- [ ] 分支一致性已判定：`matched_as` ∈ {exact, parent_dev_equivalent, none}？
- [ ] 🟢 正常场景 → `interaction_path = silent`？
- [ ] 🟠/🟡/🔴/⚠️ 异常场景 → 已按交互矩阵弹出 `ask_followup_question`？
- [ ] 🔴 主干分支 → 已强制阻断（无跳过选项）？
- [ ] `branch_ok` 字段正确？
- [ ] `env_ready` = true？
- [ ] 上述全部完成 → 才可输出完成标记 JSON

---

## 必须输出

### 步骤推进选项（仅标准模式 + 🟢 正常场景下按需弹出）

> 交互矩阵：
>
> - **精简模式 + 🟢 正常** → 无任何弹窗，输出一行摘要后静默进入步骤 5
> - **精简模式 + 异常** → §2 已弹一次异常处理弹窗，处理完成后静默进入步骤 5
> - **标准模式 + 🟢 正常** → §2 未弹窗，此处**必须**弹一次推进选项（让用户显式确认进入编码）
> - **标准模式 + 异常** → §2 已弹一次异常处理弹窗；用户选「已切换」后此处可合并为简短的推进确认或按「标准模式下不可豁免」规则再弹一次（以 `step-router.md` §「步骤流转交互规则」为准）

| 选项 | 说明 |
| --- | --- |
| ▶️ 继续步骤 5（执行修改） | 环境就绪，开始编码 |
| ⏸️ 暂停，我有补充/疑问 | 暂停等待用户输入 |
| 🔁 回退步骤 4 重新决策 | 想调整执行深度或方案 |

### 结构化完成标记（必须输出，缺字段视为未完成）

```json
{
"step": 4.5,
"name": "开发环境就绪检查",
"status": "completed | skipped",
"outputs": {
"current_branch": "当前分支名",
"branch_expected": "工作上下文 branch_workspace 字段值（步骤 4 §4.1 定稿）",
"branch_parent": "工作上下文 branch 字段值（父分支）",
"branch_dev": "工作上下文 branch_dev 字段值（孙分支或= branch）",
"has_dev_branch": "true | false",
"matched_as": "exact | parent_dev_equivalent | none【exact=与 branch_workspace 精确匹配；parent_dev_equivalent=父孙中任一者匹配；none=不匹配】",
"branch_ok": true,
"env_ready": true,
"interaction_path": "silent | user_confirmed | user_skipped"
},
"working_context_updated": true,
"next_step": 5
}

```

**`interaction_path` 字段语义**（新增，用于审计交互路径）：

- `silent` → 🟢 正常场景静默通过（未弹出 §2 异常处理弹窗；含「父孙等价」场景）
- `user_confirmed` → 🟡/🔴/⚠️ 异常场景下用户选择「✅ 已切换/已配置完成」
- `user_skipped` → 🟡/⚠️ 异常场景下用户选择「⏭️ 跳过检查」（🔴 不允许）

**完成标记校验规则**：

- 用户选择「跳过」时 `status` 为 `skipped`，`interaction_path` 为 `user_skipped`，仍可进入步骤 5
- 用户选择「需要更多时间配置」时 `status` 为 `blocked`，等待用户恢复
- `status` 为 `completed` 或 `skipped` 时才能进入步骤 5
- `branch_ok` 为 `false` 时必须输出切换命令，用户确认已切换后方可进入步骤 5
- `matched_as=parent_dev_equivalent` 时 `branch_ok` 必须为 `true`（父孙等价场景不允许误报为 fail）
- 🟢 正常场景下 `interaction_path` 必须为 `silent`，且对话历史中不应有本步骤的 §2 `ask_followup_question` 记录（此为静默推进的审计依据）
- 字段缺失难题：若工作上下文仅有 `branch` 无 `branch_dev`（历史文件）→ 降级处理为 `branch_dev = branch`，`has_dev_branch=false`，这是向后兼容机制
