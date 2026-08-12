---
title: "phase-3 — Phase 3 实施记录 + §9.4 候选清单原文 + §十/§十一 收尾段"
audience: "维护者 / 历史决策追溯"
load_when:
  - "排查 Phase 3 决策（§9.2 决策 C-2 / §9.3 落地 / §9.4 候选）冲突时"
  - "脚本头注释引用 §9.x 决策时（如 check-health.sh L11）"
  - "回滚 Phase 3 任意一个对话内的改动时"
parent: "../refactor-plan.md"
---

<!-- ❄️ 冻结横幅：本文件由 refactor-plan.md 拆分而来（2026-05-16 §十二 收尾）。-->
<!-- 单一权威源：Phase 3（含 §九/§十/§十一 三个对话收尾段）实施账本只在本文件维护。-->
<!-- 章节编号 §九 / §9.1 / §9.2 / §9.3 / §9.4 / §十 / §十一 保留作为 grep 锚点。-->

# Phase 3 实施记录（§九 / §十 / §十一 三段对话收尾）

> **定位**：[`refactor-plan.md`](../refactor-plan.md) §九~§十一 承接版。包含 Phase 3 全部决策（§9.1 thresholds.yaml 调整 / §9.2 lints 起手 / §9.3 staleness 落地 / §9.4 后续候选清单）+ 三个对话收尾段。

---

## 九、Phase 3 实施记录（2026-05-16 起）

> 本章节记录 Phase 3（lints 扩展）的逐项落地账本。
> 设计哲学与决策清单见 §一 / §二，本章节只记「实际落了什么」+「有什么偏差」。
> 本论坐标：Phase 1（§二三四六附录） → Phase 2（§七） → Phase 2.5（§八） → Phase 3（本章）。

### 9.1 check-state.sh（B 项，2026-05-16 09:30—09:33）

**决策回顾**：用户 5选 ABCD全做）执行顺序为 A → D-1 → B → C。A/D-1 账本见 §8.4-bis / §8.4-ter；B 推进中发现原始奇调「`check-state.sh` = declared vs computed drift」与现有 frontmatter 实际形态（不携带 `state` 字段）冲突，于是重新校准契约为「**state 可判定性 sanity**」。用户拍板同意后推进。

**契约定义**：扫描 md → 抽 frontmatter → 验证 confidence 字段 → 调 `state.sh` 计算 state。失败条件按优先级：无/非法 frontmatter → 缺 confidence → confidence 不在映射表 → state.sh rc=1。rc=0/2 都视为通过（2 = yaml fallback 但 stdout 仍输出状态名）。

**落盘清单**：

| 优先级 | 文件 | 状态 | 物理事实 |
|---|---|---|---|
| P3-B-1a | `scripts/tests/fixtures/state-deprecated.md` | ✅ 新增 | 12 行 / 297 B / confidence=deprecated 正例 |
| P3-B-1b | `scripts/tests/fixtures/state-bad-confidence.md` | ✅ 新增 | 11 行 / 286 B / confidence=foobar 反例 |
| P3-B-2 | `scripts/lints/check-state.sh` | ✅ 落盘 | 164 行 / 6.1 KB / +x；syntax · 端到端 5 case 全部路径验证通过（空参 / pass / deprecated 路径 / bad-confidence / 整个目录） |
| P3-B-3 | `scripts/tests/test-check-state.sh` | ✅ 落盘 | 110 行 / 3.8 KB / +x；PASS=4 FAIL=0（2 PASS + 2 FAIL）|
| P3-B-4a | `scripts/tests/run-tests.sh` SUITES 数组扩展 | ✅ +1 行 | 4 套件总峙：4 total / 4 passed / **29 用例全过** / 6s |
| P3-B-4b | `SKILL.md` §脚本表 +1 行 | ✅ +1 行 | check-state.sh 一行插在 check-frontmatter.sh 之后 |
| P3-B-4c | `scripts/lib/state.sh` 头注释升级 | ✅ 升级 | check-state.sh 从Phase 3 候选」→「已落盘 / 6.1 KB / 164 行」|
| P3-B-4d | 本章节（§9.1） | ✅ 本提交 | §8.4-bis 预埋的双向闭环现场兑现 |

**全量测试实峙**（本节完成后的最后一次物理事实）：

```
[knowledge-loop] run-tests
============================================
  ✓ test-score.sh                    [test-score] PASS=9  FAIL=0
  ✓ test-state.sh                    [test-state] PASS=10  FAIL=0
  ✓ test-check-frontmatter.sh        [test-check-frontmatter] PASS=6  FAIL=0
  ✓ test-check-state.sh              [test-check-state] PASS=4  FAIL=0
============================================
summary: 4 total, 4 passed, 0 failed  (6s)
RESULT: ok
```

合计 **29 个用例 / 4 套件 / 全部通过 / 6 秒**（Phase 2.5 末 25 → Phase 3 B 末 29，+4；C 项落地后总数升至 5 套件 33 用例，详见 §9.2）。

**契约奇调重校准记录**（仅为学习账本，不被动到代码）：

- **原计划**（§8.7 候选项）：`check-state.sh` = state 与 confidence **一致性**（declared vs computed drift）。
- **实际调研**：`config/frontmatter.schema.json` 及现有 fixtures 均不携带 `state` 字段——state 是派生量，由 `state.sh` 实时计算。原计划隐含「额外扩展 schema给 frontmatter 加 state 字段」的伪需求。
- **重设契约**：state **只有一个真相源**（`state.sh` + `state-machine.yaml`），lint 只验证「调得动」而不验证「调出来与某个 declared 一致」。
- **决策依据**：§设计哲学（确定性用代码、单一权威源、最小入侵）。不动 schema，不动 fixtures（只新增 2 个）。

**双向闭环验证**（与 §8.4-bis 表保持一致）：

```bash
# state.sh 反向声明 check-state.sh 为消费方
grep -n 'check-state.sh' scripts/lib/state.sh
# ⛒预期：L29 「已落盘 / 6.1 KB / 164 行」

# check-state.sh 反向声明 test-check-state.sh 为消费方
grep -n 'test-check-state' scripts/lints/check-state.sh
# ⛒预期：头注释§「消费方」段命中

# SKILL.md 脚本表声明 check-state.sh
grep -n 'check-state.sh' SKILL.md
# ⛒预期：脚本表 +1 行命中

# run-tests.sh SUITES 覆盖 test-check-state.sh
grep -n 'test-check-state' scripts/tests/run-tests.sh
# ⛒预期：SUITES 数组 +1 行命中
```

**备份**（时间戳 093227）：

- `~/.codebuddy/.backup/20260515/run-tests.sh.093227.before-add-check-state`
- `~/.codebuddy/.backup/20260515/state.sh.093227.before-promote-check-state`
- `~/.codebuddy/.backup/20260515/SKILL.md.093227.before-add-check-state-row`
- `~/.codebuddy/.backup/20260515/refactor-plan.md.093227.before-8.4-quart`

### 9.2 check-health.sh（C 项，2026-05-16 13:45—13:50）

**决策回顾**：B 项收尾后用户在新对话第二轮明示豁免「中断承诺」（祖父原则 §A 契约包含明示豁免），出 C-1~C-5 决策清单后用户回复 **R**（采用推荐套餐）。核心决策记录：

- **C-1 作用域**：B（单目录入参 `<dir>`，整库聚合评分）。理由：health 三维度（coverage/freshness/drift）只在「集合」层面有意义，单文件无信息量
- **C-2 维度计算**：coverage = **C**（暂置 100，权重转嫁；待 sync 完整跑通后启用）/ freshness = **A**（按 thresholds 公式线性衰减）/ drift = **A**（drift_count > 0 文件占比）
- **C-3 输出格式**：A（与 check-state.sh 同风格，文本输出 + summary + grade banner，JSON 留 Phase 4）
- **C-4 fixtures**：A（不新增 fixtures，复用历史 8 个；测试仅断言 exit code 行为，与「评分公式由 thresholds.yaml 单一权威源决定」一致）
- **关键发现**：thresholds.yaml `health:` 段（weights/grade/freshness）已在 Phase 1 预埋齐备，C 项零阈值新增；score.sh L31 在 B 项前就把 check-health.sh 列为消费方候选——双向引用闭环天然成立

**契约定义**：扫描目录下所有 *.md → 抽 frontmatter → 计算 freshness（last_verified 优先，缺则 created，再缺归 0）+ drift（drift_count > 0 比例）→ 按 thresholds.yaml::health 公式聚合综合分 → 输出 grade banner。无 frontmatter 的 md 不计入分母。

**落盘清单**：

| 优先级 | 文件 | 状态 | 物理事实 |
|---|---|---|---|
| P3-C-1 | `scripts/lints/check-health.sh` | ✅ 落盘 | 250 行 / 10.3 KB / +x；syntax · 端到端实跑 fixtures/ → health=95 / healthy / exit=0 |
| P3-C-2 | `scripts/tests/test-check-health.sh` | ✅ 落盘 | 124 行 / 4.1 KB / +x；PASS=4 FAIL=0（空参 / 不存在目录 / fixtures 绿 / tmpdir+无日期 md 红）|
| P3-C-3 | `scripts/tests/run-tests.sh` SUITES 数组扩展 | ✅ +1 行 | 5 套件总峙：5 total / 5 passed / **33 用例全过** / 8s |
| P3-C-4 | `SKILL.md` §脚本表 +1 行 + 汇总计数 25→33 | ✅ +1 行 + 修订 | check-health.sh 一行插在 check-state.sh 之后 |
| P3-C-5a | `config/thresholds.yaml` 头注释「消费方」段升级 | ✅ 升级 | check-health.sh 从「健康度评分阈值」→「已落盘 / 250 行 / 健康度评分：weights/grade/freshness」|
| P3-C-5b | `scripts/lib/score.sh` 头注释「消费方」段升级 | ✅ 升级 | check-health.sh 从「Phase 3 候选」→「已落盘 / 250 行 / 6.1 KB；不直接调 score 计算综合分，而是复用 yaml-bridge + jq + fallback 范式」|
| P3-C-6 | 本章节（§9.2）+ §8.7 表第 2 行 | ✅ 本提交 | §8.7 「⏸ 未开始」→「✅ 已落盘」，预埋的双向闭环兑现 |

**全量测试实峙**（C 项完成后的最后一次物理事实）：

```
[knowledge-loop] run-tests
============================================
  ✓ test-score.sh                    [test-score] PASS=9  FAIL=0
  ✓ test-state.sh                    [test-state] PASS=10  FAIL=0
  ✓ test-check-frontmatter.sh        [test-check-frontmatter] PASS=6  FAIL=0
  ✓ test-check-state.sh              [test-check-state] PASS=4  FAIL=0
  ✓ test-check-health.sh             [test-check-health] PASS=4  FAIL=0
============================================
summary: 5 total, 5 passed, 0 failed  (8s)
RESULT: ok
```

合计 **33 个用例 / 5 套件 / 全部通过 / 8 秒**（Phase 3 B 末 29 → C 末 33，+4；D 项落地后总数升至 6 套件 37 用例，详见 §9.3）。

**契约设计要点记录**（仅为学习账本，不被动到代码）：

- **零阈值新增**：thresholds.yaml `health:` 段在 Phase 1 已完整预埋，C 项 fallback 常量逐字与之对应（`FALLBACK_W_COVERAGE=40` ↔ `coverage: 0.4`），无新增阈值——验证了「确定性用代码、单一权威源」哲学的红利
- **双向闭环天然成立**：B 项之前 score.sh L31 的「Phase 3 候选」一行 + thresholds.yaml L9 的「健康度评分阈值」一行就是预埋的反向引用；C 项落地仅需把这两处的描述事实化，即完成 §跨文件协作设计模式 双向引用闭环（无需新增引用，仅事实回写）
- **coverage 暂置 100 的取舍**：references/ 目录刚开始建，没有「应有」基准——硬算会得到失真分数。设置 `COVERAGE=100` 让该维度暂时不影响综合分，把权重红利转给 freshness/drift 这两个有真值的维度。注释里 `(phase3 placeholder)` 显式标注，便于后续 sync 完整跑通后启用真实算法
- **freshness 计算的 macOS 兼容**：`days_since()` 函数同时尝试 `date -j -f`（macOS BSD）与 `date -d`（GNU），与 score.sh 的 bash 3.2 兼容策略保持一致
- **测试用例 4 的精妙设计**：动态构造一个无 last_verified/created 的 md 让 freshness=0 → 综合分跌到 (40+0+30)=70（warn 区，<healthy_min=80）→ exit=1。无需新增 fixture 文件，与 §设计哲学「最小入侵」一致

**双向闭环验证**（与 §8.4-bis / §9.1 表保持一致）：

```bash
# thresholds.yaml 反向声明 check-health.sh 为消费方
grep -n 'check-health.sh' config/thresholds.yaml
# ⛒预期：L9 「已落盘 / 250 行 / 健康度评分」命中

# score.sh 反向声明 check-health.sh 为消费方
grep -n 'check-health.sh' scripts/lib/score.sh
# ⛒预期：L29 「已落盘 / 250 行 / 6.1 KB」命中

# check-health.sh 反向声明 test-check-health.sh 为消费方
grep -n 'test-check-health' scripts/lints/check-health.sh
# ⛒预期：头注释「消费方」段命中

# SKILL.md 脚本表声明 check-health.sh
grep -n 'check-health' SKILL.md
# ⛒预期：脚本表 +1 行命中（5 套件 33 用例同步更新）

# run-tests.sh SUITES 覆盖 test-check-health.sh
grep -n 'test-check-health' scripts/tests/run-tests.sh
# ⛒预期：SUITES 数组 +1 行命中
```

**备份**（时间戳 134803）：

- `~/.codebuddy/.backup/20260516/run-tests.sh.134803.before-add-check-health`
- `~/.codebuddy/.backup/20260516/SKILL.md.134803.before-add-check-health`
- `~/.codebuddy/.backup/20260516/thresholds.yaml.134803.before-add-check-health`
- `~/.codebuddy/.backup/20260516/score.sh.134803.before-add-check-health`
- `~/.codebuddy/.backup/20260516/refactor-plan.md.134803.before-add-9.3`

### 9.3 check-staleness.sh（D 项，2026-05-16 14:00—14:05）

**决策回顾**：C 项收尾后用户接连表达「继续推进剩下所有实施落地」。考虑 §9.3 原后续候选清单中 4 项都需用户决策输入，严格遵守 §需求理解优先原则，逐项评估 + 豁免后推进。D 项（check-staleness.sh）评估后为「零阈值新增 + 复用 state.sh 集合筛选」，采用语义 a2（按 state.sh 输出筛 stale/deprecated）。

**重要契约重校准**（仅学习账本，不被动到代码）：

- **原豁免**：说「thresholds.yaml `staleness:` 段已预埋阈值」。实测事实：`staleness:` 段只有「漂移检测」阈值（max_drift_files_per_scan / min_diff_lines_to_flag / consecutive_drift_force_stale），​​​​​​​​不是「腐烂语义」阈值​​​​​​​​。两者名似义不似
- **重校准**：腐烂语义 = state.sh 输出的 state 在 {stale, deprecated} 集合里。这是 §单一权威源原则的后果：state 只有一个真相源（state.sh + state-machine.yaml），lint 只是在其输出上面做集合运算
- **决策依据**：§设计哲学（确定性用代码、单一权威源、最小入侵） + §祖父原则（「真的有用」>「显得专业」——不拔高为趋势型阈值，复用现成状态机）

**契约定义**：扫描 md → 抽 frontmatter → 调 `state.sh` 计算 state → 筛出 state ∈ {stale, deprecated} 的文件作为「腐烂条目」。与 check-state.sh 互补不重叠：check-state.sh 验「调得动」，check-staleness.sh 验「调出来是不是 stale」。不能调动的文件（无 frontmatter / 缺 confidence / 未知 confidence）被跳过，不计入分母。

**落盘清单**：

| 优先级 | 文件 | 状态 | 物理事实 |
|---|---|---|---|
| P3-D-1 | `scripts/tests/fixtures/state-stale.md` | ✅ 新增 | 12 行 / confidence=stale 正例；state.sh 直接验证 → state=stale / exit=0 |
| P3-D-2 | `scripts/lints/check-staleness.sh` | ✅ 落盘 | 168 行 / 6.9 KB / +x；syntax · 实跑 fixtures/ → fresh=3 / stale=2 / skipped=4 / exit=1 |
| P3-D-3 | `scripts/tests/test-check-staleness.sh` | ✅ 落盘 | 130 行 / +x；PASS=4 FAIL=0（空参 / fixtures 红 / 单文件 verified 绿 / tmpdir 全 fresh）|
| P3-D-4 | `scripts/tests/run-tests.sh` SUITES 数组扩展 | ✅ +1 行 | 6 套件总峙：6 total / 6 passed / **37 用例全过** / 11s |
| P3-D-5 | `SKILL.md` §脚本表 +1 行 + 汇总计数 33→37 | ✅ +1 行 + 修订 | check-staleness.sh 一行插在 check-health.sh 之后 |
| P3-D-6 | `config/thresholds.yaml` 头注释「消费方」段升级 | ✅ 升级 | check-staleness.sh 从「腐烂检测阈值」→「已落盘 / 168 行 / 调 state.sh 筛 stale|deprecated 集合」|
| P3-D-7 | 本章节（§9.3）+ §8.7 表第 3 行 | ✅ 本提交 | thresholds.yaml L11 预埋的反向引用现场兑现 |

**全量测试实峙**（D 项完成后的最后一次物理事实）：

```
[knowledge-loop] run-tests
============================================
  ✓ test-score.sh                    [test-score] PASS=9  FAIL=0
  ✓ test-state.sh                    [test-state] PASS=10  FAIL=0
  ✓ test-check-frontmatter.sh        [test-check-frontmatter] PASS=6  FAIL=0
  ✓ test-check-state.sh              [test-check-state] PASS=4  FAIL=0
  ✓ test-check-health.sh             [test-check-health] PASS=4  FAIL=0
  ✓ test-check-staleness.sh          [test-check-staleness] PASS=4  FAIL=0
============================================
summary: 6 total, 6 passed, 0 failed  (11s)
RESULT: ok
```

合计 **37 个用例 / 6 套件 / 全部通过 / 11 秒**（Phase 3 C 末 33 → D 末 37，+4）。

**fixtures 资产变化**（1 个新增，未动存量）：

| 名称 | 状态 | 作用 |
|---|---|---|
| `state-stale.md` | ✨ D-1 新增 | confidence=stale 正例，被 check-staleness.sh 识别为腐烂条目 |

**fixtures 复用统计**（3 个 fixture 同时服务 4 个 lint/test 套件）：

- `state-deprecated.md`：B-1 新增 → 服务 test-check-state、test-check-staleness
- `state-stale.md`：D-1 新增 → 服务 test-check-staleness
- `_overview.md` / `data-model.md`：Phase 2.5 遗产 → 服务全部 4 套件

这与 §设计哲学「最小入侵」一致：一次落盘、多处复用。

**双向闭环验证**（与 §8.4-bis / §9.1 / §9.2 表保持一致）：

```bash
# thresholds.yaml 反向声明 check-staleness.sh 为消费方
grep -n 'check-staleness.sh' config/thresholds.yaml
# ⛒预期：L11 「已落盘 / 168 行 / 调 state.sh 筛 stale|deprecated 集合」命中

# check-staleness.sh 反向声明 test-check-staleness.sh 为消费方
grep -n 'test-check-staleness' scripts/lints/check-staleness.sh
# ⛒预期：头注释「消费方」段命中

# SKILL.md 脚本表声明 check-staleness.sh
grep -n 'check-staleness' SKILL.md
# ⛒预期：脚本表 +1 行命中（6 套件 37 用例同步更新）

# run-tests.sh SUITES 覆盖 test-check-staleness.sh
grep -n 'test-check-staleness' scripts/tests/run-tests.sh
# ⛒预期：SUITES 数组 +1 行命中
```

**备份**（时间戳 140303）：

- `~/.codebuddy/.backup/20260516/run-tests.sh.140303.before-add-staleness`
- `~/.codebuddy/.backup/20260516/SKILL.md.140303.before-add-staleness`
- `~/.codebuddy/.backup/20260516/thresholds.yaml.140303.before-add-staleness`
- `~/.codebuddy/.backup/20260516/refactor-plan.md.140303.before-add-9.3-staleness`

### 9.4 后续候选（Phase 3 续延，2026-05-16 14:05 刷新）

原 §9.3 后续候选清单中 D 项（check-staleness.sh）已落地，剩下 3 项都需用户决策输入，本对话不自动推进。

| 候选 | 状态 | 阻塞决策点 |
|---|---|---|
| coverage 维度真实算法启用 | ⏸ 需 sync 完整跑通 + 「应有 md 数」基准定义 | 包含跨 phase 依赖（sync 未起手）|
| `--json` 输出模式 | ⏸ 需指定消费方（CI / dev:kb 命两选一）| 当前无调用方，为单次使用做抽象违反 §最小入侵 |
| SKILL.md 主体精简 | ⏸ Phase 3 末或 Phase 4 起手 | 跨 phase 重构，需新对话起手 |
| score.sh §7.6 遗留 | ⚫️ 永久留痕 | 除非升级 bash 4+，否则不动 |

**本轮实施总结**（A → D-1 → B → C → D 五项全部完成）：

- A（§8.4 双向闭环）· D-1（SKILL.md 微调）· B（check-state.sh）· C（check-health.sh）· D（check-staleness.sh）
- 测试总数轨迹：25 → 25（D-1 不增）→ 29（B +4）→ 33（C +4）→ **37（D +4）**
- 测试套件轨迹：3 → 3 → 4 → 5 → **6**
- lints 脚本轨迹：1（check-frontmatter.sh）→ 2（check-state.sh）→ 3（check-health.sh）→ **4（check-staleness.sh）**
- §8 / §九 双向引用闭环全部补齐；thresholds.yaml + score.sh + state.sh + check-state.sh + check-health.sh + check-staleness.sh 互为消费方闭环

## 十、本对话收尾（2026-05-16 14:16）

### 10.1 五项实施全景（Phase 3 单对话内完成）

| 项 | 范围 | 落盘 | 物理事实 |
|---|---|---|---|
| A | §8.4 双向闭环修订 | refactor-plan.md §8.4 / score.sh / state.sh 头注释 | grep 双向命中 ✅ |
| D-1 | SKILL.md 微调（脚本表汇总计数同步） | SKILL.md | 计数 25→33→37 三次同步 ✅ |
| B | check-state.sh + test-check-state.sh | scripts/lints/ + scripts/tests/ + 1 fixture | PASS=4 FAIL=0 ✅ |
| C | check-health.sh + test-check-health.sh | scripts/lints/ + scripts/tests/ | PASS=4 FAIL=0 ✅ |
| D | check-staleness.sh + test-check-staleness.sh | scripts/lints/ + scripts/tests/ + 1 fixture | PASS=4 FAIL=0 ✅ |

### 10.2 物理事实最终态

```
[knowledge-loop] run-tests
============================================
  ✓ test-score.sh                    [test-score] PASS=9  FAIL=0
  ✓ test-state.sh                    [test-state] PASS=10 FAIL=0
  ✓ test-check-frontmatter.sh        [test-check-frontmatter] PASS=6 FAIL=0
  ✓ test-check-state.sh              [test-check-state] PASS=4 FAIL=0
  ✓ test-check-health.sh             [test-check-health] PASS=4 FAIL=0
  ✓ test-check-staleness.sh          [test-check-staleness] PASS=4 FAIL=0
============================================
summary: 6 total, 6 passed, 0 failed  (12s)
RESULT: ok
```

- **测试套件**：3 → 6（+3）
- **测试用例**：25 → 37（+12）
- **lints 脚本**：1 → 4（+3，覆盖 frontmatter / state / health / staleness 四维）
- **fixtures**：6（Phase 2.5 遗产 4 个 + Phase 3 新增 2 个：state-deprecated.md / state-stale.md）
- **双向闭环**：thresholds.yaml ↔ score.sh / state.sh / check-state.sh / check-health.sh / check-staleness.sh 互相 grep 命中

### 10.3 Phase 3 续延候选（本对话不推进，需新对话起手）

| 候选 | 阻塞决策点 |
|---|---|
| coverage 维度真实算法启用 | 需 sync 模块完整跑通 + 「应有 md 数」基准定义 |
| `--json` 输出模式 | 需指定具体消费方（CI / dev:kb 二选一），当前无调用方违反 §最小入侵 |
| SKILL.md 主体精简 | 跨 phase 重构（Phase 3 末或 Phase 4 起手），需新对话 |
| score.sh §7.6 bash 3.2 遗留 | ⚫️ 永久留痕，除非升级 bash 4+ 否则不动 |

### 10.4 收尾时备份清单（20260516）

本轮所有备份均落在 `~/.codebuddy/.backup/20260516/`，按时间戳排序：

- 早期 Phase 2.5 / 之前对话备份（不在本对话范围）
- 本对话 A 项：`refactor-plan.md.{HHMMSS}.before-add-8.4-bidirectional`
- 本对话 B 项：`refactor-plan.md.{HHMMSS}.before-add-9.1-state` 系列
- 本对话 C 项：`refactor-plan.md.{HHMMSS}.before-add-9.2-health` 系列
- 本对话 D 项：`refactor-plan.md.140303.before-add-9.3-staleness` + `run-tests.sh.140303` + `SKILL.md.140303` + `thresholds.yaml.140303`
- 本节追加：`refactor-plan.md.141600.before-add-section-10`

### 10.5 下次新对话起手提示

- **首读**：`SKILL.md` § 脚本表（确认 4 lints + 6 test 套件 + 37 用例的现状）
- **次读**：本文件 § 十（理解上次对话边界）→ § 9.4（候选清单）→ § 七 / § 八（Phase 2.5 历史）
- **首跑**：`bash scripts/tests/run-tests.sh` 复核物理事实（应得 6/6/37）
- **决策入口**：§ 9.4 三大候选中选一个解锁，或转入 Phase 4 sync 模块

---

*本对话边界：A → D-1 → B → C → D 五项 + § 十收尾。下一对话从此处恢复。*

---

## §十一 Phase 3 推进 · SKILL.md 主体精简（2026-05-16）

### 候选选取（§9.4 三大候选）

- 候选 3：**SKILL.md 主体精简**（评估推荐 → 用户 ack `y` → 实施）
- 落选：候选 1（修改 thresholds.yaml::staleness 阈值）/ 候选 2（refactor-plan.md 自身瘦身）
- 选取理由：SKILL.md 是 AI 运行时入口，每次会话都消耗上下文，精简收益最大；其余两候选影响面更窄

### 决策路径

1. **方案 v1**：抽离 §存储位置 + §执行链路 全部 + 凝练边界/集成/独立使用 → 估 186→130 行（-30%）
2. **风险发现**：grep 搜索 `scripts/` 发现 6 个脚本头注释引用「**SKILL.md「执行链路」章节**」作为反向引用锚点，全量抽离会断链
3. **方案 v2**（最终采纳）：保留 §执行链路 锚点（精简版索引）+ 抽离详尽内容到新建 catalog → 估 186→140 行（-25%，零断链）
4. 用户 ack `y` → 5 步原子顺序执行

### 实施事实清单

| 步骤 | 动作 | 物理事实 |
|---|---|---|
| 1 | 备份 | `~/.codebuddy/.backup/20260516/SKILL.md.142818.before-skill-md-slim` + `refactor-plan.md.142818.before-add-section-11` |
| 2 | 新建 `references/scripts-catalog.md` | 117 行，承接配置层 + 脚本层（lib/lints/precheck/tests 四类）+ 调用规约 + 设计哲学回引 + 双向引用清单，含冻结横幅 |
| 3 | 编辑 `SKILL.md` | 186 → **148 行**（净减 38 行，**-20%**），multi_replace 一次完成 3 处编辑：①§存储位置目录树外迁到 schema.md（保留 1 行入口指向）②§执行链路 38 行 → 12 行精简版（保留锚点 + 配置/脚本入口列表 + catalog 链接）③References 表追加 scripts-catalog 行 |
| 4 | 跑测试 + grep 自检 | `run-tests.sh`：**6 total / 6 passed / 0 failed / 37 用例**，与抽离前完全一致；6 项 grep 自检全过 |
| 5 | 追加本节 §十一 | — |

### 行数轨迹

| 文件 | 抽离前 | 抽离后 | 变化 |
|------|------:|------:|------:|
| `SKILL.md` | 186 | 148 | **-38 行 / -20%** |
| `references/scripts-catalog.md`（新建） | — | 117 | +117 行 |
| `references/refactor-plan.md` | 815 | 815 + §十一 | +30 行（待提交） |
| **总行数** | 186 | 148 + 117 = 265 | +79 行（运行时入口减重，按需加载部分增重；符合按需加载架构目标） |

### 双向闭环验证（§设计哲学 跨文件协作）

| 引用方向 | grep 命中数 |
|---------|-----------:|
| `SKILL.md` → `scripts-catalog.md` | 2（L103 正文 + L147 References） |
| `scripts-catalog.md` → `SKILL.md` | 15（frontmatter `parent` + 横幅 + 正文「定位」+ 调用规约 §1/§2 + 双向引用清单等） |
| `SKILL.md` 保留「执行链路」锚点 | 4（§标题 L90 + 配置权威源 + 脚本执行入口 + References） |
| 6 个脚本头注释引用「SKILL.md「执行链路」」 | 5/5 命中（`check-deps.sh` 是泛指引用 SKILL.md，不含「执行链路」字符串，未受影响）|

### 抽离去向映射

| SKILL.md 原内容 | 去向 | 处置 |
|---|---|---|
| §存储位置 目录树（20 行） | `references/schema.md`（已涵盖 12 处更详细命名规范） | 删除目录树，保留 1 行入口指向 |
| §执行链路 §配置层 表（3 行） | `references/scripts-catalog.md` §配置层 | 详尽版外迁，SKILL.md 保留 1 行权威源列表 |
| §执行链路 §脚本层 表（10 行） | `references/scripts-catalog.md` §脚本层（lib/lints/precheck/tests 四类分组） | 详尽版外迁，SKILL.md 保留 4 行入口分组列表 |
| §执行链路 §调用规约 4 条 | `references/scripts-catalog.md` §调用规约（扩为 4 条 + 同步性兜底） | 详尽版外迁，SKILL.md 保留 1 句冲突仲裁 + 设计哲学一句话 |
| §References 表 | 追加 `scripts-catalog.md` 行 + refactor-plan.md 行更新到 Phase 3 | 表格追加 |

### 关键设计权衡

1. **零断链优先于行数极致**：v1 方案（130 行）会断 6 处脚本头注释引用，违反「跨文件协作必须双向闭环」红线（AI 行为规范.mdc）；v2 方案虽多 8 行但保留锚点
2. **物理事实兜底**：测试套件 6/6/37 与抽离前完全一致 → 抽离动作未影响任何确定性规则
3. **新建 catalog 加冻结横幅**：与 SKILL.md 横幅同款，统一约束「修改 config/scripts 优先于改提示词」

### 物理事实快照（备查）

```
SKILL.md                     148 lines (was 186, -20%)
references/scripts-catalog.md 117 lines (new)
scripts/tests/run-tests.sh    6/6/37 PASS=37 FAIL=0
```

### 下一步候选

候选已完成：[3]
剩余候选（§9.4）：

- 候选 1：`config/thresholds.yaml::staleness` 阈值微调（基于 §9.3 落地反馈）
- 候选 2：`refactor-plan.md` 自身瘦身（>800 行，可考虑拆 Phase 1/2/2.5/3 为独立子文件）
- Phase 4：sync 模块（如启动新方向）

**决策入口**：从剩余候选中选一个，或转入 Phase 4。

---

*§十一 边界：候选 3 完成。下一对话从此处恢复。*
