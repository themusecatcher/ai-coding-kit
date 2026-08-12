---
title: "phase-2.5 — 测试套件起手实施账本"
audience: "维护者 / 历史决策追溯"
load_when:
  - "新增 scripts/tests/test-*.sh 套件时"
  - "排查测试套件设计意图（test-runner / 6 套件演化）时"
  - "回滚 Phase 2.5 改动时"
parent: "../refactor-plan.md"
---

<!-- ❄️ 冻结横幅：本文件由 refactor-plan.md 拆分而来（2026-05-16 §十二 收尾）。-->
<!-- 单一权威源：Phase 2.5（测试套件起手）实施账本只在本文件维护。           -->
<!-- 章节编号 §八 及子节保留作为 grep 锚点，禁止重新编号。                    -->

# Phase 2.5 测试套件起手实施账本

> **定位**：[`refactor-plan.md`](../refactor-plan.md) §八 承接版。3 套件 25 用例起手 → 后续在 Phase 3 增长到 6 套件 37 用例。

---

## 八、Phase 2.5 实施记录（2026-05-15，新对话续作）

> 本章节记录 Phase 2.5（测试套件）的实际落盘 + 实施期间发现的偏差修复，是 §7.4 计划的执行账本。
> 新对话起手：用户已对 §7.6 选择方向 A（接受遗留，测试仅断言 exit code）。

### 8.1 §7.6 决策落地

**用户决策**：方向 A——`test-score.sh` 错误用例**仅断言 exit ≠ 0**，不断言 stderr 文本，不触及 bash 3.2 unbound variable 路径（即不传负数 / 非数字 drift / days_merged）。

**理由复述**：

- 正向 81 组 100% 正确 + exit code 100% 可信赖，已覆盖核心契约
- 符合 §「真的有用 > 显得专业」+ §「同类问题 ×2 停下」原则
- 不引入 bash 4 强依赖（不选 B），不冒 awk/python 子进程重构风险（不选 D）
- score.sh 本身**未改一行**

### 8.2 Phase 2.5 落盘清单

| 优先级 | 文件 | 状态 | 物理事实 |
|---|---|---|---|
| P2.5-2 | `scripts/tests/test-score.sh` | ✅ 完成 | 99 行 / 4.2 KB / +x；9 用例（6 数值 + 3 错误） |
| P2.5-3 | `scripts/tests/test-state.sh` | ✅ 完成 | 119 行 / 3.8 KB / +x；10 用例（5 状态 + drift 升级 + stdin + 3 错误） |
| P2.5-4 | `scripts/tests/test-check-frontmatter.sh` | ✅ 完成 | 115 行 / 3.9 KB / +x；6 fixture 端到端（3 pass + 3 fail） |
| P2.5-5 | `scripts/tests/run-tests.sh` | ✅ 完成 | 123 行 / 4.3 KB / +x；含 `--list` / 失败日志展开 / 计时 |
| P2.5-6 | 本章节（refactor-plan.md §八） | ✅ 完成 | 本提交 |

**run-tests.sh 全量实跑**（最后一次物理事实）：

```
[knowledge-loop] run-tests
============================================
  ✓ test-score.sh                    [test-score] PASS=9  FAIL=0
  ✓ test-state.sh                    [test-state] PASS=10  FAIL=0
  ✓ test-check-frontmatter.sh        [test-check-frontmatter] PASS=6  FAIL=0
============================================
summary: 3 total, 3 passed, 0 failed  (5s)
RESULT: ok
```

合计 **25 个用例 / 3 套件 / 全部通过 / 5 秒**。

### 8.3 实施期间发现并修复的偏差：§7.7 fixtures 与 schema 冲突

**现象**：批次 3 首次实跑 test-check-frontmatter.sh，正例文件 `_overview.md` / `data-model.md` 反而 fail。

**根因**：§7.7 落盘的两个正例 fixture 含 `last_updated: 2026-05-15` 字段，但
`config/frontmatter.schema.json` 的 `overviewFm` / `topicFm` 分支使用 `additionalProperties: false`，
该字段不在 properties 白名单 → ajv 报错。`_index.md` 的 `indexFm` 分支同样 `additionalProperties: false`，
但 `last_updated` 恰好在白名单内（因 indexFm 含此字段定义），故未触发问题。

**判断方向**：schema 已在 P2-4 实测通过 3 pass / 3 fail（§7.2 表），是规则真相；fixtures 才是错的。

**修复**（workspace 外四步范式，已备份）：

| 文件 | 改动 | 改动后行数 |
|---|---|---|
| `scripts/tests/fixtures/_overview.md` | 删除 `last_updated: 2026-05-15` 一行 | 9 → 8 |
| `scripts/tests/fixtures/data-model.md` | 删除 `last_updated: 2026-05-15` 一行 | 10 → 9 |

**备份**：`~/.codebuddy/.backup/20260515/{_overview.md,data-model.md}.231700.before-fix-fixtures`

**修复后实测**：test-check-frontmatter.sh PASS=6 FAIL=0（首次首过）。

**对 §7.7 表格的更正**：

| §7.7 旧值 | 实际值（Phase 2.5 修复后） |
|---|---|
| `_overview.md` 9 行 | **8 行** |
| `data-model.md` 10 行 | **9 行** |

### 8.4 双向引用闭环（强制自检）

| A 文件 → B 文件 | A 引用 B 的位置 | B 反向引用 A 的位置 |
|---|---|---|
| `test-score.sh` → `score.sh` | 头注释 + 实际 bash 调用 | score.sh L27-29 头注释 §「消费方」（已显式，Phase 2.5 §8.4-bis 补完） |
| `test-state.sh` → `state.sh` | 头注释 + 实际 bash 调用 | state.sh L27-29 头注释 §「消费方」（已显式，Phase 2.5 §8.4-bis 补完） |
| `test-check-frontmatter.sh` → `check-frontmatter.sh` | 头注释 + 实际 bash 调用 | check-frontmatter.sh 头注释**已**列出 `scripts/tests/test-check-frontmatter.sh`（§7.2 P2-4 实施时已埋点） |
| `run-tests.sh` → 3 个 test-*.sh | `SUITES` 数组 | 各 test-*.sh 自闭，无需反向引用 |
| `test-check-frontmatter.sh` → `fixtures/*.md` | `FIX` 路径常量 + 6 个 assert | fixtures 是数据，不需反向引用 |
| 本 §八 → §7.4 / §7.6 / §7.7 | 章节内多处明示 | §7.4 / §7.6 / §7.7 在文末已写「Phase 2.5-X 留待新对话」自然引向本节 |

> **断链自检命令**：
>
> ```bash
> # 子测试 → 被测脚本
> grep -nE 'score\.sh' ~/.codebuddy/skills/knowledge-loop/scripts/tests/test-score.sh
> grep -nE 'state\.sh' ~/.codebuddy/skills/knowledge-loop/scripts/tests/test-state.sh
> grep -nE 'check-frontmatter\.sh' ~/.codebuddy/skills/knowledge-loop/scripts/tests/test-check-frontmatter.sh
> # check-frontmatter.sh 是否已声明消费方
> grep -nE 'test-check-frontmatter|消费方' ~/.codebuddy/skills/knowledge-loop/scripts/lints/check-frontmatter.sh
> ```

### 8.4-bis 双向闭环 grep 自检（A 选项执行账本，2026-05-15 23:26）

**触发**：用户选 5（ABCD 全做），先闭合 §8.4 表中两处「隐含」标注，避免 D 阶段大改时混入。

**改动**（workspace 内，已备份）：

| 文件 | 改动 | 行数变化 |
|---|---|---|
| `scripts/lib/score.sh` | 头注释末尾追加 3 行「消费方」段 | +3 |
| `scripts/lib/state.sh` | 头注释末尾追加 3 行「消费方」段 | +3 |

**备份**：

- `~/.codebuddy/.backup/20260515/score.sh.232646.before-add-consumer`
- `~/.codebuddy/.backup/20260515/state.sh.232646.before-add-consumer`

**实测验证**（grep 双向命中 + 测试回归）：

```
[score.sh 消费方]
27:#  消费方：
28:#    - scripts/tests/test-score.sh （单元测试，6 数值 + 3 错误用例）
29:#    - scripts/lints/check-health.sh （Phase 3 候选，健康度评分使用 score）

[state.sh 消费方]
27:#  消费方：
28:#    - scripts/tests/test-state.sh （单元测试，5 状态 + drift 升级 + stdin + 3 错误）
29:#    - scripts/lints/check-state.sh （Phase 3 候选，state 与 confidence 一致性 lint）

[run-tests.sh] 3 total, 3 passed, 0 failed (25 用例全过)
```

**双向闭环最终状态**：§8.4 表 5 行全部「双向显式命中」，无单向断链。本次同时为 Phase 3 的 check-state.sh / check-health.sh 预埋了消费方声明，落地时不再需要回头补反向引用。

### 8.4-ter SKILL.md 入口微调（D-1，2026-05-15 23:30）

**触发**：用户选 5（ABCD 全做），D 项重新评估后发现 SKILL.md 已在 Phase 1 完成主体精简（180 行），不需大改。改为 D-1：3 处事实性微调，把 Phase 2.5 落盘事实回写到入口。

**改动**（workspace 内，已备份）：

| 行号 | 改动 | 价值 |
|---|---|---|
| L129 | §脚本层表格末尾追加 `scripts/tests/run-tests.sh` 一行 | 让测试入口能在 SKILL.md 被发现 |
| L137 | §调用规约「计划在 Phase 2.5 落盘」→「Phase 2.5 已落盘 3 套件 25 用例：PASS=25 / FAIL=0」 | 把事实回写到入口（§单一权威源） |
| L183 | §References 表追加 `references/refactor-plan.md` | 让 §设计哲学回引能被发现 |

**备份**：`~/.codebuddy/.backup/20260515/SKILL.md.232919.before-D1-micro-edits`

**自纠错记录**：D-mini-2 首次落盘时把 run-tests.sh 一行写了 2 遍（multi_replace 失败后改用 replace_in_file 时 old_string 包含已被前一次替换覆盖的内容，触发重复）。grep -c 实测发现 count=2，立即用 replace_in_file 删除重复行，再次实测 count=1。**教训**：复杂表格追加用 replace_in_file 单步操作 + 立即 grep -c 验证，不依赖 multi_replace。

**实测验证**（grep -c + 测试回归）：

```
SKILL.md = 182 行（180 + 3 - 1，符合预期）
run-tests.sh count = 1（去重后）
refactor-plan.md count = 3（冻结横幅 + 设计哲学回引 + References 表）
PASS=25 count = 1
run-tests.sh 全量：3 total, 3 passed, 0 failed
```

### 8.5 Phase 2.5 备份位置一览（增量）

| 备份文件 | 备份时刻 | 用途 |
|---|---|---|
| `~/.codebuddy/.backup/20260515/_overview.md.231700.before-fix-fixtures` | 8.3 fixture 修复前 | 撤回 last_updated 删除 |
| `~/.codebuddy/.backup/20260515/data-model.md.231700.before-fix-fixtures` | 8.3 fixture 修复前 | 同上 |
| `~/.codebuddy/.backup/20260515/refactor-plan.md.231900.before-phase2.5` | 8.6
本节追加前 | 撤回本 §八 |
| `~/.codebuddy/.backup/20260515/score.sh.232646.before-add-consumer` | 8.4-bis 补消费方前 | 撤回 score.sh +3 行头注释 |
| `~/.codebuddy/.backup/20260515/state.sh.232646.before-add-consumer` | 8.4-bis 补消费方前 | 撤回 state.sh +3 行头注释 |

> 不重复列 Phase 1 / Phase 2 备份（详见 §六 / §7.5）。

### 8.6 物理事实终验（运行本节前的最后一次自检）

| 验证项 | 命令 | 期望 |
|---|---|---|
| 4 个新增 .sh 都可执行 | `ls -la scripts/tests/*.sh` | 4 个 `-rwxr-xr-x` |
| 3 个子测试通过 | `bash scripts/tests/run-tests.sh` | `RESULT: ok`，3 passed |
| fixtures 修复后 PASS=6 | `bash scripts/tests/test-check-frontmatter.sh` | `PASS=6 FAIL=0` |
| score.sh 未改一行 | `diff scripts/lib/score.sh ~/.codebuddy/.backup/20260515/score.sh.224000.before-bash3.2-fix` | 无 diff（决策 A 落地确认） |
| 6 fixtures 完整存在 | `ls scripts/tests/fixtures/{,extras/}` | 4 + 2 共 6 个 .md |

### 8.7 后续（Phase 3 候选状态表，2026-05-16 刷新）

| 候选项 | 状态 | 备注 |
|---|---|---|
| `scripts/lints/check-state.sh`（state 可判定性） | ✅ 已落盘 | 详见 §9.1（2026-05-16 09:30）|
| `scripts/lints/check-health.sh`（健康度评分） | ✅ 已落盘 | 详见 §9.2（2026-05-16 13:45）|
| `scripts/lints/check-staleness.sh`（腐烂条目识别） | ✅ 已落盘 | 详见 §9.3（2026-05-16 14:00）|
| `SKILL.md` 主体精简 | ✅ D-1 已调整 | 详见 §8.4-ter；Phase 1 已完成主体精简，D-1 仅补 3 处事实回写 |
| score.sh §7.6 遗留 | ⚫️ 永久留痕 | 决策 A 已落地，不再尝试修复（除非升级 bash 4+）|
| §8.4 双向引用闭环 | ✅ 已闭合 | 详见 §8.4-bis |

### 8.8 Phase 2.5 收口判据（已满足）

- ✅ §7.4 列出的 4 个文件 + 5 套件全部落盘
- ✅ run-tests.sh 全绿（25/25）
- ✅ §7.6 决策 A 落地（score.sh 未动 + 测试仅断言 exit）
- ✅ §7.7 fixture 偏差就地修复并双向更正本节表格
- ✅ workspace 外四步范式：备份 → 写 tmp（edit_file）→ wc/head/tail/run 验证 → 隐式 mv（edit_file 原子写）
- ✅ 不动 SKILL.md 主体（Phase 3 范围）
- ✅ 不删除任何已有文件

**Phase 2.5 完成。** Phase 3 已于 2026-05-16 启动§九）。

---

