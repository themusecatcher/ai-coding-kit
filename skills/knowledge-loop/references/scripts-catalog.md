---
title: "scripts-catalog — 确定性规则的物理事实层（脚本与配置详尽规约）"
audience: "AI 运行时 + 维护者"
load_when:
  - "修改 config/ 或 scripts/ 时"
  - "AI 需要查『哪个脚本输出什么 / 退出码语义』时"
  - "排查脚本输出与 SKILL.md 提示词描述冲突时"
  - "新增 lint/test 套件时"
parent: "../SKILL.md"
---

<!-- ┌──────────────────────────────────────────────────────────────┐ -->
<!-- │  ❄️  冻结横幅 / FROZEN BANNER（Phase 3 抽离，2026-05-16）     │ -->
<!-- ├──────────────────────────────────────────────────────────────┤ -->
<!-- │ 本文件是 SKILL.md §执行链路 的详尽承接版（按需加载）。        │ -->
<!-- │                                                              │ -->
<!-- │ 单一权威源（Single Source of Truth）：                        │ -->
<!-- │   • 前置物 schema       → config/frontmatter.schema.json      │ -->
<!-- │   • 状态机定义           → config/state-machine.yaml          │ -->
<!-- │   • 阈值/健康度          → config/thresholds.yaml             │ -->
<!-- │   • 依赖/lint/校验脚本   → scripts/{precheck,lints,lib,tests}/│ -->
<!-- │                                                              │ -->
<!-- │ 修改规则：                                                    │ -->
<!-- │  1. 任何「确定性规则」改动必须先动 config/scripts，再回引     │ -->
<!-- │     到本文件；禁止只在提示词里描述硬规则。                    │ -->
<!-- │  2. 本文件章节如与 config/scripts 冲突，以 config/scripts 为  │ -->
<!-- │     准；冲突即视为本文件失效，需立即修订。                    │ -->
<!-- │  3. 跨文件协作必须双向引用（参考 AI 行为规范.mdc §跨文件      │ -->
<!-- │     协作设计模式）。SKILL.md ↔ scripts-catalog.md 已建立      │ -->
<!-- │     双向闭环（SKILL.md §执行链路 → 本文件；本文件 frontmatter │ -->
<!-- │     `parent` → SKILL.md）。                                   │ -->
<!-- └──────────────────────────────────────────────────────────────┘ -->

# scripts-catalog — 脚本与配置详尽规约

> **定位**：[`SKILL.md`](../SKILL.md) §执行链路 的详尽承接版。
> SKILL.md 仅保留**入口索引**（脚本路径列表 + 设计哲学一句话），CLI 用法 / 退出码语义 / 调用规约 / 设计哲学回引集中在本文件，按需加载。
>
> **核心一句话（设计哲学）**：**确定性用代码（schema/lint/yaml），模糊性用 LLM**。
> AI 在执行涉及"前置物校验 / 健康度计算 / 状态判定 / 依赖检查"动作时**必须调用脚本而非根据 SKILL.md 提示词推理**——脚本/配置才是规则真相。

---

## 配置层（权威源 · 修改这里即修改规则）

| 文件 | 作用 | 消费方 |
|------|------|--------|
| `config/frontmatter.schema.json` | 三类前置物（index / overview / topic）的 JSON Schema 守卫，使用 `__kind` 判别字段。**spec=draft 2019-09**（适配本机 ajv-cli 6.x） | `scripts/lints/check-frontmatter.sh` |
| `config/state-machine.yaml` | dirty / clean / synced / stale / deprecated 五状态机定义、置信度→状态映射表、漂移阈值 | `scripts/lib/state.sh` |
| `config/thresholds.yaml` | 健康度评分公式（base/penalty/bonus）、生命周期天数、复用率/腐烂阈值 | `scripts/lib/score.sh` · `scripts/lints/check-health.sh` · `scripts/lints/check-staleness.sh` |

---

## 脚本层（可执行真相 · CLI 直接验证）

### lib/（库 + CLI 双形态）

| 文件 | 形态 | CLI 用法 | 退出码语义 |
|------|------|---------|-----------|
| `scripts/lib/yaml-bridge.sh` | 库（可 source / 可独立调用） | `yaml_to_json <yaml>` / `frontmatter_to_json <md>` / `detect_yaml_backend` | 0 ok / 1 输入错 / 2 无 backend / 3 解析失败 |
| `scripts/lib/score.sh` | 库 + CLI | `score.sh --level <lvl> --drift <int> --days_merged <int>` → stdout 整数 0-100 | 0 ok / 1 参数错 / 2 已 fallback |
| `scripts/lib/state.sh` | 库 + CLI（含 stdin） | `state.sh --json '<fm_json>' [--synced-flag <bool>]` → stdout 状态名 | 0 ok / 1 JSON/参数错 / 2 已 fallback |

### lints/（lint 入口 · 整库或单文件校验）

| 文件 | 用途 | CLI 用法 | 退出码语义 |
|------|------|---------|-----------|
| `scripts/lints/check-frontmatter.sh` | Schema 守卫 | `check-frontmatter.sh <file_or_dir>...`（递归 *.md，注入 `__kind` 后 ajv 校验） | 0 ok / 1 至少一项 fail / 2 依赖缺失 |
| `scripts/lints/check-state.sh` | state 可判定性 | `check-state.sh <file_or_dir>...`（抽 frontmatter → 调 `state.sh` 计算 state） | 0 ok / 1 至少一项 fail / 2 依赖缺失 |
| `scripts/lints/check-health.sh` | 整库健康度评分 | `check-health.sh <dir>`（按 thresholds.yaml::health 公式聚合 freshness/drift） | 0 healthy / 1 warn 或 fail / 2 依赖缺失 |
| `scripts/lints/check-staleness.sh` | 腐烂条目识别 | `check-staleness.sh <file_or_dir>...`（调 `state.sh` → 筛 state ∈ {stale, deprecated}） | 0 无腐烂 / 1 至少一个腐烂 / 2 依赖缺失 |

### precheck/（环境守卫）

| 文件 | 用途 | CLI 用法 | 退出码语义 |
|------|------|---------|-----------|
| `scripts/precheck/check-deps.sh` | 依赖检查（jq/yq/git/python3） | `check-deps.sh`（无参，stdout 报告） | 0 ok / 1 必需缺失 / 2 推荐缺失 |

### tests/（测试套件 · 脚本与 yaml 配置同步性兜底）

| 文件 | 用途 | CLI 用法 | 退出码语义 |
|------|------|---------|-----------|
| `scripts/tests/run-tests.sh` | 测试套件汇总 | `run-tests.sh [--list]` 依次跑 `scripts/tests/test-*.sh`（当前 6 套件 37 用例） | 0 全过 / 1 至少一套件 fail |

> 当前测试覆盖：6 套件 37 用例（PASS=37 / FAIL=0），覆盖 `score.sh` / `state.sh` / `check-frontmatter.sh` / `check-state.sh` / `check-health.sh` / `check-staleness.sh`。

---

## 调用规约

1. **AI 不要复述脚本逻辑**：禁止在 SKILL.md / 其他提示词里复述具体数值（如"verified=80 分"），只调用脚本拿结果。
2. **冲突仲裁**：任何与脚本输出**冲突**的提示词描述视为该提示词失效，需立即修订（与 SKILL.md ❄️ 冻结横幅 §修改规则 第 2 条一致）。
3. **解释路径**：用户/用例若问"为什么打这个分"，让脚本输出解释或读 `config/thresholds.yaml`；本文件不重复维护具体公式数值。
4. **同步性兜底**：脚本与 yaml 配置的同步性由 `scripts/tests/` 测试套件兜底，新增 lint/库时必须同步新增 test-*.sh。

---

## 设计哲学回引

详见 [`refactor-plan.md`](./refactor-plan.md) § 设计哲学（Phase 1 / 2 / 2.5 / 3 实施账本），核心两条：

- **确定性用代码，模糊性用 LLM**：能进 `config/*.yaml` 或 `scripts/lints/` 的就不进提示词。
- **物理事实兜底**：lint/state/score 由脚本原子产出，AI 不可绕过。

---

## 双向引用清单（自检）

| 引用方向 | 命中位置 |
|---------|---------|
| `SKILL.md` → 本文件 | SKILL.md §执行链路 「详尽规约 → `references/scripts-catalog.md`」 |
| 本文件 → `SKILL.md` | frontmatter `parent` + 正文「定位」段 + 调用规约 §2 |
| `SKILL.md` → `refactor-plan.md` | SKILL.md §References 表 |
| `refactor-plan.md` → `SKILL.md` | refactor-plan.md §设计哲学 / §实施账本 多处 |
| 本文件 → `refactor-plan.md` | §设计哲学回引 |

> 自检命令：`grep -l 'scripts-catalog' SKILL.md references/*.md` 应至少命中 SKILL.md（入口）和 refactor-plan.md（主文件 §四 候选清单 + §五 §十二 收尾记录中均有引用）。
>
> **注意**（2026-05-16 §十二 后更新）：refactor-plan.md 已拆分主文件 + `plans/{phase-1-2,phase-2.5,phase-3}.md` 三个子文件。`refactor-plan.md` 主文件仅留 §一~§五 骨架；Phase 1/2/2.5/3 完整实施账本（含历次 §References 表迁移记录 / Phase 2.5 落地 / SKILL.md 精简等）按需加载 `plans/`。
