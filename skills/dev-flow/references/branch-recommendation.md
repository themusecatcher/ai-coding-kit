# 分支命名推荐：输出模板与命名约束（详细规范）

> **文件定位**：`steps/step-4-decision.md` §4.1「分支名最终推荐」的细节下沉文件，**单一权威源**。
> **加载时机**：步骤 4 · 决策落地（环节 4/4） §4.1.2 推荐流程进入"输出"环节时按需加载；其他位置不直接加载。
> **创建时间**：2026-05-29（v3 patch，从 step-4-decision.md §4.1.3~§4.1.5/§4.1.7 抽离）

## 一、概览

step-4-decision.md §4.1 在正文保留**前置判断 + 推荐流程 + 写入工作上下文**三段骨架；本文件承载：

| 子节 | 内容 | 引用关系 |
| --- | --- | --- |
| §A 输出模板（feature/ 场景） | 含父+孙分支的双层推荐 + 4 选项决策 | step-4-decision.md §4.1.2 步骤 4 |
| §B 输出模板（非 feature/ 场景） | 单一分支推荐 + 3 选项决策 | step-4-decision.md §4.1.2 步骤 4 |
| §C 命名约束强制校验 | AI 自检清单 + 脚本兜底 + 双层校验机制 | step-4-decision.md §4.1.2 步骤 4 + validate-output.sh |
| §D 与步骤 4.5 的衔接 | 父孙等价的环境检查规则 | step-4.5-env-check.md |

> 命名规范的权威源仍是 `references/shared-rules.md` §6。本文件不重复规则，只放 dev-flow 步骤 4 内的实际输出格式与校验流程。

---

## §A 输出模板（feature/ 场景，含父+孙分支）

```markdown
🎯 分支命名推荐（基于已锁定方案）

| 类型 | 分支名 | 用途 |
| --- | --- | --- |
| 开发分支（孙） | `feature_dev/{≤3词}/{username}` | 日常开发、commit、push 的分支 |
| 目标分支（父） | `feature/{≤3词}` | MR 合入 master 的目标，开发完成后从孙分支 MR 到此分支 |

判定依据：

- 改动范围：{N} 个文件，~{M} 行改动
- 方案性质：{新增能力 / 修复 / 重构}
- 命名校验：✅ ≤3 词 + 全小写 + 短横线连接

请确认本次使用的分支组合：

```

| 选项 | 说明 |
| --- | --- |
| ✅ 使用这套分支（默认推荐） | 开发在 `feature_dev/{≤3词}/{username}` 上，完成后 MR 到 `feature/{≤3词}` |
| ✏️ 修改命名 | 调整功能简述部分（追加修改说明） |
| 🔄 换前缀 | feature → bugfix/hotfix（罕见，方案性质判断错误时） |

> **设计原则**：父分支和孙分支是配套使用的，不应让用户二选一。开发分支（孙）用于日常编码，目标分支（父）用于 MR 合入，两者是「开发→合入」的配套关系，不是「二选一」的互斥关系。

> **精简模式行为**：feature/ 场景默认采用孙分支编码（无需弹窗），输出一行摘要：
> `🌿 编码分支：feature_dev/{≤3词}/{username}（目标分支 feature/{≤3词}，默认采用配套分支）`

---

## §B 输出模板（非 feature/ 场景，无孙分支）

```markdown
🎯 分支命名推荐：`bugfix/{≤3词}`（或 `hotfix/` / `i18n/` / `private/`）

判定依据：

- 改动范围：{...}
- 方案性质：{Bug 修复 / 紧急修复 / 国际化 / 私有化}
- 命名校验：✅ 通过

请确认分支命名：

```

| 选项 | 说明 |
| --- | --- |
| ✅ 使用此分支名 | 写入工作上下文，进入步骤 4.5 |
| ✏️ 修改命名 | 调整命名部分 |
| 🔄 换前缀 | 调整为其他前缀 |

> **精简模式行为**：非 feature/ 场景直接采用推荐值，输出一行摘要后静默推进。

---

## §C 命名约束强制校验（输出前 AI 自检 + 脚本兜底）

> 📌 **程序化兜底**：AI 自检通过后，**必须调用 `branch-name-lint.sh` 脚本做物理事实兜底**，
> 防止 AI 凭记忆判断"通过"但实际违规（如 4 单词错误）。脚本返回 exit 1 → 必须修正分支名后重新推荐。

### §C.1 AI 自检清单（与脚本 4 项对齐）

- ✅ 单词数 ≤ 3（前缀后的功能简述部分）
- ✅ 全小写
- ✅ 单词间用短横线 `-` 连接
- ✅ 每个单词为完整英文单词（禁止缩写、禁止驼峰、禁止数字编号除非必要）
- ✅ 整体匹配正则
  `^(feature|bugfix|hotfix|test|i18n|private|feature_dev|sub-master|dev)(/[a-z0-9][a-z0-9-]*){1,3}$`
- ❌ 违规示例：
  `feature/ban-long-term-block-feature`（4 词）/ `feature/banLongTermBlock`（驼峰）/
  `feature/ban_long_term`（下划线）/ `feat/xxx`（前缀不在枚举内）
- ✅ 合规示例：
  `feature/ban-long-term` + `feature_dev/ban-long-term/{username}` /
  `bugfix/fix-date-display` / `hotfix/login-crash` /
  `i18n/en-translations` / `private/oem-customer`

### §C.2 程序化校验（强制，AI 自检后必须执行）

```bash

# AI 推荐分支名后、输出给用户前，必须调用此脚本验证
bash ~/.codebuddy/skills/dev-flow/scripts/lints/branch-name-lint.sh "<推荐的分支名>"

# exit 0 → 通过，可输出给用户

# exit 1 → 不通过，必须修正分支名后重试（禁止输出不合规的分支名给用户）
#

# user_specified 场景（用户直接告知已有分支）：
bash ~/.codebuddy/skills/dev-flow/scripts/lints/branch-name-lint.sh --skip

# → 直接通过，branch_name_lint_passed 填 "user_specified_skip_lint"

```

### §C.3 与 validate-output.sh 的双层校验

| 层次 | 时机 | 校验者 | 失败后果 |
| --- | --- | --- | --- |
| **第一层**：AI 推荐时实时校验 | §4.1.2 推荐分支名前 | `branch-name-lint.sh` | 修正后重新推荐 |
| **第二层**：步骤 4 完成标记提交时 | `validate-output.sh step4` | 再次调用 `branch-name-lint.sh` | 步骤 4 校验失败，无法进入 4.5 |

> ⚠️ **双层确保**：即使 AI 第一层绕过（如直接填 `branch_name_lint_passed: true`），第二层 `validate-output.sh` 会用脚本重新计算，不匹配即拦截。

---

## §D 与步骤 4.5 的衔接

- 步骤 4.5「环境检查」会读取工作上下文 `branch` + `branch_dev` 双字段，**父分支与孙分支视为等价**（任一匹配即视为 🟢 正常通过），不再误报"分支漂移"
- 详见 `steps/step-4.5-env-check.md` §「智能分级处理（父孙兼容）」

---

## 维护说明

- 本文件由 `step-4-decision.md` §4.1.2 推荐流程第 4 步「输出推荐 + ask_followup_question」时按需加载（用户/AI 可主动 `read_file`）
- §4.1.3「输出与命名约束校验」是正文骨架的引用入口，实际加载触发点是 §4.1.2 第 4 步
- 已登记在 `references/_index.md`，加载时机绑定 step-4 §4.1.2
- 若新增"分支命名推荐场景"（如 chore/、docs/ 等），先更新 `references/shared-rules.md` §6 命名规范权威源，再同步更新本文件 §A/§B 的输出模板
