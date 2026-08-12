# dev-flow 开发工作流

> 面向 AI 辅助编程的系统化开发工作流。本 README 为**人类阅读导航**，AI 运行时入口为 `SKILL.md`。

## 架构概览

```text
dev-flow 采用 Prompt Chaining 分层架构 + 程序化执行层（v3 重构 2026-05-14）：

L0 入口层    SKILL.md（触发规则 + 全局配置）
              ↓
L1 流程层    flow.md（开发流程路由）
              ↓
L2 步骤层    steps/step-{N}-{name}.md（按需逐步加载，禁止一次性加载多个）
              ↓
L3 参考层    references/（按需加载）

并联：
🆕 L4 配置层  config/{gates.yaml, hooks.json}（门控规则单一权威源）
🆕 L5 执行层  scripts/（lints + precheck + hooks + state-machine）
```

**核心理念**：单一流程 + 智能评估 + 程序化兜底。所有需求走同一条流程（阶段0→步骤1~10），
步骤4基于研究成果智能评估推荐执行深度（标准/完整），用户可覆盖。**门控规则尽量下沉为脚本，
减少对 AI 注意力的依赖**。

## 设计哲学：确定性用代码，模糊性用 LLM

> v3 重构（2026-05-14）的核心架构哲学，已被实战验证（红牌脚本兜底覆盖率 28% → 100%，元门控 13/13 全绿）。
> 同步规则源：`references/core-principles.md` §19 + `~/.codebuddy/rules/AI行为规范.mdc` 「Skill 设计哲学」章节。

**核心思路**：把规则按「机械可枚举」程度做二分，分别用不同手段实现：

| 规则类型 | 特征 | 实现层 | 兜底机制 | 本仓库实例 |
| --- | --- | --- | --- | --- |
| **确定性** | 关键词匹配、JSON Schema、文件存在性、行数、AST 模式、引用计数、状态转移 | `config/` + `scripts/lints/` + `scripts/precheck/` + `scripts/hooks/` | exit code + `.validated` 物理文件 | R1-R5（路径规范）、C1-C8（选项一致性）、name_lint、doc_platform_lint、step5-precheck |
| **模糊性** | 命名是否传神、注释是否清晰、方案是否优雅、根因是否合理、需求是否理解到位 | `flow.md` / `steps/*.md` / `SKILL.md` 提示词 | 用户决策 + 主动确认 | 步骤4方案设计、步骤9经验沉淀的"哪些值得记录"判断 |

**4 项实现哲学**（全部已落地）：

1. **程序化优先**：能进 `config/gates.yaml` / `scripts/lints/` 的规则就不进提示词
2. **单一权威源**：脚本/配置是规则真相，文档只引用不重复（如触发关键词只在 SKILL.md 维护，AI 行为规范引用不复制）
3. **物理事实兜底**：`.validated` / `.done` 文件由脚本原子创建，AI 不可绕过
4. **元门控守护**：用 lints/precheck 脚本守护规则系统本身

**反模式（v3 重构前的真实痛点，已修复）**：

- ❌ "step 5.5 不可跳过" 写成提示词依赖 AI 记忆 → 偶尔遗漏 ✅ 现在由 `scripts/precheck/step5-precheck.sh` 物理拦截
- ❌ "交互式选项必须一致" 写在 N 个文档里 → 双源真相打架 ✅ 现在统一由 `scripts/lints/interactive-options-lint.sh`（C1-C8）校验
- ❌ "commit 格式校验" 留给 AI 肉眼检查 → 格式漂移 ✅ 现在由 commit message lint 兜底

**对其他 Skill 的指导意义**：所有新建/重构 Skill 都应在「决策清单」环节做这次拆分。详见 `~/.codebuddy/rules/AI行为规范.mdc` §「Skill 设计哲学」。

## 程序化执行入口（v3 新增 2026-05-14，v3.1 2026-06-09 新增强化门禁）

| 时机 | 命令 | 说明 |
| --- | --- | --- |
| 步骤完成后 | `scripts/hooks/post-step.sh <step-id> <json> <flow>` | Schema 校验 + 产物归档 + 步骤专属 lint（doc_platform/新鲜度/漂移/YAML/状态/完整性）+ 步骤间质量门禁 |
| 加载下一步前 | `scripts/hooks/pre-step.sh <flow> <target-step>` | 自动跑物理检查点 + step5 前置硬卡点 |
| 路径规范 lint | `scripts/lints/path-lint.sh <md-file>` | R1-R5 校验 |
| 选项一致性 lint | `scripts/lints/interactive-options-lint.sh <snapshot.json>` | C1-C8 校验 |
| dev-logs 完整性 lint | `scripts/lints/devlog-integrity-lint.sh` | 双件（plan+devlog）齐全校验 |
| dev-logs 目录命名 lint | `scripts/lints/devlog-dir-name-lint.sh <dir-name>` | 4 项校验 |
| 文档决策 lint | `scripts/lints/doc-platform-lint.sh <step-4-json>` | 6 项校验 |
| 状态机查询 | `scripts/state-machine.sh --query-next --current=N --mode=M` | 替代记忆查表 |
| 度量仪表盘生成 | `scripts/gen-dashboard.py` | 重算 summary + 生成 dashboard（含 YAML 覆盖率） |
| 流程报告生成 | `scripts/gen-flow-report.py <需求ID>` | 生成单需求 HTML 复盘报告 |

详见 `config/gates.yaml`（门控规则配置）和 `config/hooks.json`（Hook 注册表）。

## 目录结构

```text
dev-flow/
├── README.md                # 本文件：人类阅读导航
├── SKILL.md                 # AI 运行时入口（触发规则 + 全局配置）
├── flow.md                  # 开发流程定义（L0 路由层，阶段0 + 步骤1~10）
├── flowchart/               # 流程图（版本化管理）
│   ├── README.md            #   用户导航（版本信息 + 文件格式说明）
│   ├── SPEC.md   #   AI 更新指南（版本管理 + 生成规范 + 模板）
│   └── versions/            #   版本目录（md/html/svg/png）
├── steps/                   # 步骤详细规范（Prompt Chaining 按需加载）
│   ├── README.md            #   步骤目录说明
│   ├── step-router.md       #   步骤路由器（执行协议 + 门控规则）
│   ├── step-1-research.md   #   步骤1：研究与定位
│   ├── step-2-scope.md      #   步骤2：确认范围
│   ├── step-3-plan.md       #   步骤3：制定方案
│   ├── step-4-decision.md   #   步骤4：方案汇报与用户决策
│   ├── step-4.5-env-check.md#   步骤4.5：环境检查
│   ├── step-5-execute.md    #   步骤5：执行修改
│   ├── step-5.5-post-coding.md# 步骤5.5：编码后置钩子
│   ├── step-6-verify.md     #   步骤6：质量验证
│   └── step-7-commit.md     #   步骤7：清理+Commit
└── references/              # 参考文档（按需加载）
    ├── _index.md            #   参考文件索引（加载时机+加载者）
    └── (44+个参考文件)      #   详见 _index.md
```

## 流程总览

```text
用户消息 → 触发规则匹配 → 加载 SKILL.md
  ↓
阶段0：需求理解（调用 requirement-intake skill）
  ↓
步骤1：研究与定位 → 步骤2：确认范围 → 步骤3：制定方案
  ↓
步骤4：方案汇报与用户决策（智能评估推荐执行深度）
  ↓
步骤4.5：环境检查
  ↓
步骤5：执行编码 → 步骤5.5：编码后置钩子 → 步骤6：质量验证
  ↓
步骤7：清理+Commit
  ↓                                    ↓
标准执行（结束）              完整执行 → 步骤8→9→10（结束）
```

| 执行深度 | 步骤范围 | 典型场景 |
| --- | --- | --- |
| 标准执行 | 步骤 5→7 | Bug 修复、样式调整、小优化 |
| 完整执行 | 步骤 5→10 | 新功能开发、架构重构、任务平台 需求 |
| 分批执行 | 步骤 5→7 循环 | 大型需求拆分为多批次 |

## 文件职责速查

| 文件 | 职责 | 谁读 | 何时读 |
| --- | --- | --- | --- |
| `SKILL.md` | 触发规则、全局配置、核心原则精要 | AI | 每次触发 dev-flow 时自动加载 |
| `flow.md` | 开发流程定义（阶段0 + 步骤1~10 总览） | AI | 触发开发流程后加载 |
| `steps/step-router.md` | 步骤路由器（执行协议 + 门控 + 红牌行为） | AI | flow.md 加载后立即加载 |
| `steps/step-N-*.md` | 各步骤详细规范 | AI | 按 Prompt Chaining 逐步加载 |
| `references/_index.md` | 参考文件索引（加载时机 + 加载者） | 人/AI | 需要查找参考文档时 |
| `references/*.md` | 各类参考规范（安全、度量、回退等） | AI | 按 _index.md 指示按需加载 |
| `flowchart/*` | 流程图（可视化） | 人 | 需要理解整体流程时 |

## 关联 Skill 调用关系

```text
dev-flow 在不同步骤中调用以下 Skill：

阶段0 ──→ requirement-intake    （需求理解）
步骤3 ──→ design-advisor        （方案设计）
步骤5 ──→ coding-standards      （编码规范）
         frontend-patterns     （前端模式）
         i18n / dom-animation  （按场景）
步骤5.5 ─→ code-review（L1）     （基础审查）
          tech-doc              （文档同步）
步骤6 ──→ verification-pipeline  （7阶段验证）
步骤7 ──→ code-review（L2）     （完整审查）
         smart-commit          （Commit 生成）
         tech-doc              （devlog）
步骤8 ──→ code-review（L3）     （深度审查，仅完整执行）
步骤9 ──→ self-improving-agent   （经验沉淀，仅完整执行）
步骤10 ─→ smart-commit + tech-doc（归档，仅完整执行）
```

## 关联数据目录

| 目录 | 用途 | 由哪个步骤写入 |
| --- | --- | --- |
| `~/.codebuddy/working-context/` | 工作上下文持久化 | 阶段0创建，每步骤更新 |
| `~/.codebuddy/working-context/.active-flows/` | 活跃流程锁文件 | 每步骤同步，最终步骤删除 |
| `~/.codebuddy/dev-logs/` | 开发日志归档（plan.md + devlog.md） | 步骤4生成plan，步骤7追加devlog |
| `~/.codebuddy/.metrics/` | 度量汇总与仪表盘 | 步骤7环节I（YAML报告），`gen-dashboard.py` 重算 |
| `~/.codebuddy/.learnings/` | 经验教训 | 步骤9 |
| `~/.codebuddy/knowledge/` | 项目知识库 | 步骤1/5/7/10 |

## 修改指南

| 想改什么 | 改哪个文件 | 影响范围 |
| --- | --- | --- |
| 触发规则/命令 | `SKILL.md` | 所有入口 |
| 流程步骤顺序/总览 | `flow.md` | 开发流程 |
| 某个步骤的详细规范 | `steps/step-N-*.md` | 仅该步骤 |
| 步骤间的执行协议/门控 | `steps/step-router.md` | 所有步骤切换 |
| 步骤 7 commit/devlog/knowledge 子流程 | `references/closeout-flow.md` | step-7 |
| 核心原则 | `references/core-principles.md` | 全局 |
| 参考文档 | `references/*.md` + 更新 `_index.md` | 按需加载范围 |
| 流程图 | `flowchart/`（版本信息见 README.md，AI 生成规范见 SPEC.md） | 可视化 |

> ⚠️ 修改后需执行 `npm run sync`（在 ai-coding-kit 项目下）同步到源码仓库。
> ⚠️ 修改流程定义文件后建议同步更新 flowchart。
