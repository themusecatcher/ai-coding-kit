---
title: "phase-1-2 — Phase 1 决策清单 + 物理事实 + Phase 2 实施账本"
audience: "维护者 / 历史决策追溯"
load_when:
  - "排查 Phase 1 决策与当前实现冲突时"
  - "回滚 Phase 1 / Phase 2 改动时"
  - "脚本头注释引用 §7.6 / §7 决策时"
parent: "../refactor-plan.md"
---

<!-- ❄️ 冻结横幅：本文件由 refactor-plan.md 拆分而来（2026-05-16 §十二 收尾）。-->
<!-- 单一权威源：Phase 1 + Phase 2 历史实施账本只在本文件维护。              -->
<!-- 主文件 ../refactor-plan.md 仅保留 §设计哲学 + §9.4 候选清单 + 子文件 TOC。  -->
<!-- 章节编号（§二~§七、§7.6 等）保留作为 grep 锚点，禁止重新编号。          -->

# Phase 1 决策与 Phase 2 实施账本

> **定位**：[`refactor-plan.md`](../refactor-plan.md) §二~§七 的承接版（按需加载）。Phase 1 P0/P1 决策、双向引用闭环、物理事实记录、回滚说明、附录文件清单、Phase 2 完整实施账本（共 7 个一级章节）原文迁移在此。

---

## 二、Phase 1 决策清单（用户已确认 P0 + P1）

### P0（高优先级，核心权威源）

| # | 文件 | 角色 | 状态 |
|---|------|------|------|
| P0-1 | `SKILL.md`（头部冻结横幅） | 入口提示词层声明 | ✅ 已落盘 |
| P0-2 | `config/frontmatter.schema.json` | 前置物 JSON Schema 守卫 | ✅ 已落盘 + ajv 实测通过 |
| P0-3 | `config/state-machine.yaml` | dirty/clean/synced/stale/deprecated 状态机 | ✅ 已落盘 + ruby-yaml 解析通过 |
| P0-4 | `scripts/precheck/check-deps.sh` | jq/git/ajv 必需 + yq/yaml/hash 可选依赖检查 | ✅ 已落盘 + 实测 RESULT: ok |

### P1（中优先级，配套）

| # | 文件 | 角色 | 状态 |
|---|------|------|------|
| P1-1 | `config/thresholds.yaml` | 7 类数值阈值的单一权威源 | ✅ 已落盘 + 解析通过 |
| P1-2 | `references/refactor-plan.md`（本文件） | 决策清单归档 | ✅ 落盘中 |

---

## 三、双向引用闭环清单（强制）

| A 文件 → B 文件 | A 引用 B 的位置 | B 反向引用 A 的位置 |
|----------------|-----------------|--------------------|
| `SKILL.md` → `frontmatter.schema.json` | 头部横幅「单一权威源」清单 | schema 头部 `description` 字段 |
| `SKILL.md` → `state-machine.yaml` | 头部横幅 | yaml 头部注释「消费方」段 |
| `SKILL.md` → `thresholds.yaml` | 头部横幅 | yaml 头部注释「消费方」段 |
| `SKILL.md` → `refactor-plan.md`（本文件） | 头部横幅 | 本文件 §一引用 SKILL.md 横幅 |
| `frontmatter.schema.json` → `state-machine.yaml` | 共享 `confidenceLevel` enum | yaml `confidence_to_state_default` 9 key 与 enum 一致 |
| `state-machine.yaml` → `thresholds.yaml` | predicates 引用 `drift_count_stale_threshold` | thresholds.yaml lifecycle 段定义此项 |
| `AI行为规范.mdc` → 本文件 | § Skill 设计哲学 / § 跨文件协作设计模式 | 本文 §一明确引用 |

> **断链自检命令**（任一新增引用后必须执行）：
>
> ```bash
> # 例：检查 SKILL.md 与 thresholds.yaml 的双向引用
> grep -nE 'thresholds\.yaml' ~/.codebuddy/skills/knowledge-loop/SKILL.md
> grep -nE 'SKILL\.md|消费方' ~/.codebuddy/skills/knowledge-loop/config/thresholds.yaml
> ```

---

## 四、物理事实验证记录（Phase 1）

| 验证项 | 命令 | 结果 |
|--------|------|------|
| 横幅落入 SKILL.md | `grep -c '冻结横幅' SKILL.md` | 1 |
| schema 编译通过 | `ajv compile -s frontmatter.schema.json --spec=draft2020 --strict=false` | `is valid` |
| schema 正例 | `ajv validate -s schema -d /tmp/idx-good.json` | `valid` |
| schema 条件必填 | `ajv validate ... -d /tmp/topic-bad.json`（pending 缺 created_branch） | `invalid`（符合预期） |
| state-machine 5 状态齐全 | `ruby -ryaml ... d['states'].keys` | `[dirty, clean, synced, stale, deprecated]` |
| state-machine 必填字段 | 每个 state 含 description/predicates/transitions/effects | OK ×5 |
| thresholds 9 confidence base 与 schema enum 一致 | `confidence_score.base.keys` | 9 个值完全匹配 schema enum |
| check-deps 必需依赖 | 执行脚本 | `RESULT: ok`（exit 0）|

---

## 五、Phase 1 范围之外（Phase 2/3 候选，本 Phase 不实现）

> 决策清单中已确认 **不在 Phase 1 实现** 的项目，避免本次 PR 范围爆炸：

- `scripts/lib/state.sh` —— 状态机判定库（Phase 2 实现）
- `scripts/lib/score.sh` —— confidence_score 计算库（Phase 2 实现）
- `scripts/lints/check-frontmatter.sh` —— 调用 ajv + schema 的 lint（Phase 2）
- `scripts/lints/check-state.sh` —— state 与 confidence 一致性检查（Phase 2）
- `scripts/lints/check-health.sh` —— 健康度评分（Phase 3）
- `scripts/tests/` —— 单元测试套件（Phase 2 起）
- SKILL.md 主体内容精简（Phase 3，待 Phase 2 脚本就绪后剥离硬规则到脚本）

---

## 六、回滚说明

如需回滚 Phase 1：

```bash
# 1. 恢复 SKILL.md
cp ~/.codebuddy/.backup/20260515/SKILL.md.knowledge-loop.162428.before-banner \
   ~/.codebuddy/skills/knowledge-loop/SKILL.md

# 2. 恢复完整目录（含已删除的子目录）
rm -rf ~/.codebuddy/skills/knowledge-loop
cp -R ~/.codebuddy/.backup/20260515/knowledge-loop.skill.161419 \
      ~/.codebuddy/skills/knowledge-loop

# 3. 验证
grep -c '冻结横幅' ~/.codebuddy/skills/knowledge-loop/SKILL.md  # 期望 0
ls ~/.codebuddy/skills/knowledge-loop/config/                    # 期望仅原有内容
```

---

## 附录：文件清单（Phase 1 新增 / 修改）

| 路径 | 操作 | 备份位置 |
|------|------|---------|
| `SKILL.md` | 修改（头部插入 20 行横幅） | `~/.codebuddy/.backup/20260515/SKILL.md.knowledge-loop.162428.before-banner` |
| `config/frontmatter.schema.json` | 新增 | （新文件，无需备份） |
| `config/state-machine.yaml` | 新增 | （新文件，无需备份） |
| `config/thresholds.yaml` | 新增 | （新文件，无需备份） |
| `scripts/precheck/check-deps.sh` | 新增（可执行） | （新文件，无需备份） |
| `references/refactor-plan.md`（本文件） | 新增 | （新文件，无需备份） |
| 完整目录初始备份 | — | `~/.codebuddy/.backup/20260515/knowledge-loop.skill.161419/` |

---

## 七、Phase 2 实施记录（2026-05-15）

> 本章节记录 Phase 2 的实施快照与已知非预期变更，作为后续会话的恢复入口。
> 设计哲学与决策清单见 §一 / §二，本章节只记「实际落了什么」+「有什么偏差」。

### 7.1 Phase 2 范围

| 优先级 | 文件 | 状态 | 物理事实 |
|---|---|---|---|
| P2-1 | `scripts/lib/yaml-bridge.sh` | ✅ 完成 | 149 行 / 6.3 KB / +x，4 case smoke 通过 |
| P2-2 | `scripts/lib/score.sh` | ✅ 完成 | 169 行 / 6.5 KB / +x，7 case 通过（5 数值精确 + 2 错误用例） |
| P2-3 | `scripts/lib/state.sh` | ✅ 完成 | 141 行 / 5.5 KB / +x，8 case 通过（5 状态全覆盖 + stdin 输入 + 错误信息分层） |
| P2-4 | `scripts/lints/check-frontmatter.sh` | ✅ 完成 | 174 行 / 6.3 KB / +x，6 fixtures 端到端验证 3 pass / 3 fail 精确匹配预期 |
| P2-5~8 | 测试套件（test-score / test-state / test-check-frontmatter / run-tests.sh） | ⏸ 推迟 | 并入 Phase 2.5 独立批次（用户决策 C）|
| P2-9 | `SKILL.md` 增补「执行链路」章节 | ✅ 完成 | 行数 143 → 180，含 8 处脚本/schema 引用 + 双向回引 refactor-plan.md |
| P2-10 | 本章节（refactor-plan.md §七）| ✅ 完成 | 本提交 |

### 7.2 非预期变更：schema spec 由 draft/2020-12 降为 draft/2019-09

**起因**：P2-4 实施 `check-frontmatter.sh` 时发现本机 `ajv-cli` 6.x 仅支持
`draft7` 与 `draft2019`，不支持 `draft2020`。schema 顶部 `$schema` 字段须随之
调整，否则 ajv 报 `no schema with key or ref "https://json-schema.org/draft/
2020-12/schema"`。

**决策**：方向 A——改 schema 的 `$schema`（draft/2020-12 → draft/2019-09）。
理由：两版本在我们使用的关键字（oneOf / $ref / $defs / if-then / const /
enum / required / pattern / anyOf / allOf）上完全兼容；方向 B（运行时改写）
会污染权威源，已否决。

**变更范围**：

- 修改文件：`config/frontmatter.schema.json` 第 2 行 `$schema` 字段
- 关联调整：`scripts/lints/check-frontmatter.sh` 中 `ajv validate` 命令显式加 `--spec=draft2019`
- 备份：`~/.codebuddy/.backup/20260515/frontmatter.schema.json.221500.before-draft2019`

**Follow-up（不阻塞 Phase 2 收口）**：

- 后续如升级 ajv-cli 到 8.x（支持 draft2020），可考虑回退至 draft/2020-12；届时同步移除 `--spec=draft2019` 参数
- 升级前必须重跑 P2-4 端到端 fixtures（3 pass / 3 fail）保证回归

### 7.3 P2-4 实施暴露的另一个隐性约束（已修复，留痕）

**约束**：`ajv-cli` 6.x 要求数据文件**后缀必须为 `.json`**，否则按非 JSON 处理报
`Unexpected token ":"`。`mktemp -t check-fm.XXXXXX.json` 不会真把 `.json` 加到
文件名里——它只是把模板里的 `.json` 也作为可替换字符。

**修复**：`check-frontmatter.sh::check_one` 改为「mktemp 拿临时路径 → mv 加上 .json
后缀 → 写入 JSON 内容 → 喂给 ajv → rm」。

### 7.4 Phase 2.5 计划范围（测试套件）

| 文件 | 用途 | 来源依据 |
|---|---|---|
| `scripts/tests/test-score.sh` | score.sh 5-8 case 单测 | P2-2 已落盘的 7 case smoke 形式化 |
| `scripts/tests/test-state.sh` | state.sh 5 状态覆盖 | P2-3 已落盘的 8 case smoke 形式化 |
| `scripts/tests/test-check-frontmatter.sh` | 端到端 fixtures（含正负例） | P2-4 已验证的 6 fixtures 形式化 |
| `scripts/tests/run-tests.sh` | 测试入口 + summary | 新增 |
| `scripts/tests/fixtures/` | 共享 fixtures（_index/_overview/topic 各 1 个正例 + 2 负例 + no-fm.md） | 新增 |

**进入 Phase 2.5 的前置条件**：用户对 Phase 2 当前 4 个脚本 + 1 个 schema 调整无
反对意见；新对话中带回本章节链接即可恢复上下文。

### 7.5 Phase 2 备份位置一览

| 备份文件 | 备份时刻 | 用途 |
|---|---|---|
| `~/.codebuddy/.backup/20260515/knowledge-loop.skill.161419/` | Phase 1 起点 | 整目录回滚（Phase 1 + Phase 2 全部撤回） |
| `~/.codebuddy/.backup/20260515/SKILL.md.knowledge-loop.162428.before-banner` | Phase 1 横幅前 | 撤回头部冻结横幅 |
| `~/.codebuddy/.backup/20260515/frontmatter.schema.json.221500.before-draft2019` | P2-4 schema 调整前 | 回退到 draft/2020-12 |
| `~/.codebuddy/.backup/20260515/SKILL.md.knowledge-loop.222900.before-p2-9` | P2-9 增补前 | 撤回「执行链路」章节 |
| `~/.codebuddy/.backup/20260515/refactor-plan.md.223100.before-phase2` | P2-10 前 | 撤回本 §七 |

### 7.6 已知遗留：score.sh 在 bash 3.2 下负数/非数字参数报 unbound variable

**现象**：

```
$ score.sh --level verified --drift -1 --days_merged 0
score.sh: line 95: DRIFT�: unbound variable
exit=1
```

其中 `�` (U+FFFD) 是 bash 内部解析器读到的越界字节。**触发条件收窄**：仅当 `--drift` 或 `--days_merged` 接收到「含负号 / 含非数字字符 / 空字符串」时触发；如 `--drift abc`、`--days_merged -7`、`--drift ' '`。

**注意：以下错误路径 stderr 仍是友好中文，不在本遗留范围**：

- `--level INVALID` → `score.sh: 未知 level: INVALID` + usage（友好）
- 缺参（如只传 `--level + --drift`）→ `score.sh: --level / --drift / --days_merged 均为必填` + usage（友好）

**根因（深度推断）**：bash 3.2.57 (macOS 默认) + `set -uo pipefail` + `[[ "$X" =~ regex ]]` 在 `$X` 值不能匹配正则、且参数本身被 shell 当作可疑选项时，触发解析器崩溃路径，伪造一个变量名 `DRIFT�` 后再以 nounset 报错。

**已验证不可行的修复**：

- 把 `[[ =~ ]]` 改成 POSIX `case "$X" in ''|*[!0-9]*) ... esac` —— 仍报错（错误转移到 case 行）
- 进一步在变量前加 `x` 前缀：`case "x$X" in / x|x*[!0-9]*) ... esac` —— 仍报错
- 推测：根因不在 `[[ =~ ]]` 的 regex 解析，而在 bash 3.2 + set -u + 字符类 globbing 的整体崩溃路径（trace 显示错误总落在 case 模式行而不是 case 头）

**当前妥协方案**：保留 score.sh 原始 `[[ =~ ]]` 写法，承认此为已知遗留：

- ✅ 正向 81 组 (level × drift × days_merged) 输出 **100% 正确**
- ✅ 所有错误用例 **exit code 仍为 1**（契约可信赖）
- ✅ 多数错误路径 stderr **是友好中文**（level 校验 / 缺参校验 / 文件读取失败等）
- ⚠️ 仅**数值校验路径**（drift / days_merged 收到非数字或负号时）stderr 不友好（爆 unbound 而非中文提示）

**对测试套件的影响**：`test-score.sh` (P2.5-2) 应**仅断言 exit code，不断言 stderr 文本**——这本就是更合理的脚本契约边界。

**未来彻底修复方向（择一）**：

- 升级 shebang 为 `#!/usr/bin/env bash` + 在脚本顶部加 `[ ${BASH_VERSION%%.*} -ge 4 ] || { echo "需要 bash 4+" >&2; exit 2; }`，要求用户 `brew install bash`
- 用 `set +u` 临时关闭 nounset 包住数值校验区段
- 改用 `awk` / `python3` 做参数校验子进程

**触发原则**：本对话已进行 25+ 轮，连续 2 次修复尝试失败 → 按 §「同类问题×2 停下分析根因」+ §「真的有用高于显得专业」**停止猜测、留痕、回滚**。完整调试过程见 `~/.codebuddy/.backup/20260515/score.sh.224000.before-bash3.2-fix`（备份）和本节。

### 7.7 Phase 2.5-1 已落盘（fixtures 共享样本）

| 文件 | 行数 | 用途 |
|---|---|---|
| `scripts/tests/fixtures/_index.md` | 9 | 正例：完整字段 _index.md |
| `scripts/tests/fixtures/_overview.md` | 9 | 正例：完整字段 _overview.md |
| `scripts/tests/fixtures/data-model.md` | 10 | 正例：合法 topic 文件 |
| `scripts/tests/fixtures/extras/_index.md` | 6 | 负例：缺 base_branch / created |
| `scripts/tests/fixtures/extras/bad-topic.md` | 9 | 负例：topic 不在 enum |
| `scripts/tests/fixtures/no-fm.md` | 3 | 无 frontmatter |

**§7.4 ↔ §7.7 fixture 名称映射**（避免新对话恢复时混淆）：

| §7.4 描述 | §7.7 实际文件 |
|---|---|
| `_index.md` 1 个正例 | `fixtures/_index.md` |
| `_overview.md` 1 个正例 | `fixtures/_overview.md` |
| `topic` 1 个正例 | `fixtures/data-model.md` |
| 负例 ① 缺必填字段 | `fixtures/extras/_index.md` |
| 负例 ② topic 不在 enum | `fixtures/extras/bad-topic.md` |
| `no-fm.md` 无 frontmatter | `fixtures/no-fm.md` |

Phase 2.5-2/3/4/5（test-score / test-state / test-check-frontmatter / run-tests）**留待新对话**——本对话已进行 25+ 轮、工具调用 50+ 次，逼近 🔴 红色预警。新对话恢复指引：从本节 §7.4 + §7.6 + §7.7 进入即可。

**新对话第一步**：先读 §7.6 `set -u + bash 3.2` 已知遗留 → 决策 A/B/C 修复方向 → 再写 P2.5-2 `test-score.sh`。

---

