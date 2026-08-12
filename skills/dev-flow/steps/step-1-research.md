# 步骤 1：研究与定位

> 本文件仅在执行步骤 1 时加载。执行完毕后输出完成标记 JSON，通过门控后加载步骤 2。

## 目标

搜索项目中已有的相关实现、类似功能、可复用组件/工具函数，追溯完整上下游链路。

## 执行规范

### 0. 项目知识检索（自动执行，按节点信号触达）

步骤 1 开始时，**并行执行本地检索**（0.a/0.b/0.5），**知识库平台 外援默认沉默**，仅在命中「节点信号」时按需触达：

#### 0.a 本地项目知识库（始终执行）

调用 `use_skill('knowledge-loop')` 检索模式，自动检索项目知识库（`~/.codebuddy/knowledge/`）中与当前需求相关的知识（易错点、调试技巧、API 使用习惯）。

> 💡 **附带 sync 滞后检测**：检索模式会自动比对 `_index.md.last_synced_sha` 与远端 `origin/{base_branch}`，
> 若已落后/超 7 天未 sync/从未 sync → 在「📚 项目知识」末尾追加一行轻量提示，建议用户在新需求开工前跑 `dev:kb sync`，
> 避免引用过期 verified 知识。完整规则与触发阈值由 `knowledge-loop/modes/retrieve.md` § sync 滞后检测 单一维护，本步骤仅消费其输出。

#### 0.b L0 profile（仅存在时使用，零 MCP 调用）

1. 检查 `~/.codebuddy/knowledge/{project}/_profile.md` 是否存在（用户主动 `dev:onboard` 后才会存在）
2. **存在且未过期**（<14 天）→ 作为项目全景注入上下文，0 MCP 调用
3. **存在但过期**（14-45 天）→ 使用 + 末尾弱提醒
4. **不存在** → 跳过，**不再自动建议 onboard**（已不是默认推销）
5. 详细生命周期 → [onboard-flow.md](../references/onboard-flow.md)

#### 0.c 知识库平台 节点信号判定（按需触达，默认沉默）

不再做「每次读映射表 + 档位判定」。按 [remote-knowledge.md](../references/remote-knowledge.md) §一 信号表，检查是否命中本步骤可能触发的两个信号：

| 信号 | 触发条件（任一满足即触发） | 调用内容 | Token 预算 |
| --- | --- | --- | --- |
| **信号 1：首次接触陌生模块** | ①本次涉及的模块在 `~/.codebuddy/knowledge/{project}/` 无任何沉淀 **或** ②用户命令 `dev:ref` **或** ③需求描述含「首次接触/不熟悉/陌生模块/理解架构」 | 1 次 `git_doc_platform` 语义检索 | ≤1.5k |
| **信号 4：跨项目联调** | ①`package.json` 含 `@your-org/component-lib` / `@your-org/ui-lib` 且需消费方验证 **或** ②用户声明「跨项目」 **或** ③步骤 2 标记 `cross_project=true` **或** ④用户命令 `--cross-project` | 2~3 次 `git` + `git_doc_platform`（**不传** `search_domain` 做全库检索） | ≤6k |

> ⚠️ **信号 4 触发前置**（2026-05-19 新增）：执行 MCP 调用前，
> **必须先按 [cross-project/analysis.md](../references/cross-project/analysis.md) 三步法处理本地仓库与分支感知**。
> 命中本地且分支正确 → 跳过本次 MCP 调用（节省 ≥4k Token）；未命中或分支不一致 →
> 走该章节的 4 选项主动提醒模板，让用户决策后再决定是否走 知识库平台 MCP。

**判定输出**：

- 命中信号 → 加载 [remote-knowledge.md](../references/remote-knowledge.md) §二 查 `knowledge_uuid` + `search_domain` → 并行子任务表启用对应行
- **未命中任一信号 → 完全沉默**，不读映射表、不加载配置文件、不调 MCP，只走本地流程
- 用户使用 `--no-remote-kb` → 强制沉默，所有信号失效

> 📌 完整信号定义与 CLI 覆盖 → [remote-knowledge.md](../references/remote-knowledge.md) §一 / §四 4.3
> 💰 量化收益与真实案例验证 → [remote-knowledge.md](../references/remote-knowledge.md) §六

### 0.5 历史经验检索（自动执行）

步骤 1 开始时，**与项目规范检索并行**，自动检索历史反思产出：

1. `ls ~/.codebuddy/.learnings/ 2>/dev/null` 检查是否存在经验文件
2. 存在 → 读取 `LEARNINGS.md`（或目录下所有 `.md` 文件）
3. 从中提取与当前需求**相关的经验条目**（按关键词/模块/技术栈匹配）
4. 匹配到的经验 → 作为研究补充上下文，在方案设计时主动规避已知坑点
5. 不存在或无匹配 → 跳过，正常执行后续研究

**匹配策略**（按优先级）：

- 项目名匹配：经验条目中的项目名与当前项目一致
- 模块名匹配：经验条目涉及的模块与当前需求涉及的模块重叠
- 技术栈匹配：经验条目涉及的技术（如 React Hook、CSS 变量）与当前任务相关
- 错误模式匹配：经验条目记录的错误模式可能在当前任务中复现

**Recurrence-Count 差异化处理**（借鉴 MemPalace Agent Diary 模式识别）：
匹配到经验条目后，检查其 `Recurrence-Count` 字段，按频次差异化处理：

| Recurrence-Count | 处理方式 |
| :---: | --- |
| 1 | 正常展示，作为参考 |
| 2 | 标注 ⚠️，在方案设计时重点关注 |
| ≥3 | 标注 🔴 **高频坑点**，步骤 3 方案中**必须包含对应检查项** |

### 1. 先研究再编码

#### 🔀 可并行子任务（多源并行检索）

以下子任务之间无依赖，应尽可能并行执行：

| # | 并行任务 | 工具 | 启用条件（信号驱动） | 说明 |
| --- | --- | --- | --- | --- |
| 1 | 搜索项目已有实现 | `codebase_search` | 总是（所有场景） | 本地代码库语义检索（相关组件/函数/Hook） |
| 2 | 分析文件结构 | `grep_search` | 总是（所有场景） | 追溯 import/export 链路 |
| 3 | 搜索本地 knowledge | `use_skill('knowledge-loop')` | 总是（0.a 启动） | 易错点、API 使用习惯、历史坑 |
| 3.5 | **bug 复现现场采集**（可选） | `use_skill('browser-toolkit')` | 触发信号为`修复/排查/线上问题`且可操作浏览器时 | 抓取截图/console 日志/network 瀑布/performance trace，为根因定位提供一手证据 |
| 4 | 读取 L0 profile | `read_file` `_profile.md` | profile 存在且未过期（0.b） | 零 MCP 调用获取项目全景 |
| 5 | 检索历史经验 | 读取 `.learnings/` | 总是（0.5 启动） | 匹配相关经验教训 |
| 6 | 领域知识查阅 | `web_search` / 在线文档 / 知识库 | 涉及不熟悉领域时 | 外部权威知识 |

> ⏳ 全部完成后汇聚（Fan-in）→ 合并为「相关文件表格」输出

**结果交叉验证**：MCP 命中的文件路径**必须用 `read_file` 验证真实存在**（防 知识库平台 索引延迟），验证失败时在表格中标注 ⚠️ 并降级为
子代理模式下的具体调度方式详见 `shared-rules.md` §3「子代理调度指引 > 步骤 1」。

### 1.5 多源知识仲裁与升级（4 级优先级 + 降级条款）

> 当步骤 1 同时从多个知识源（本地代码、knowledge/、remote-kb/git、remote-kb/wiki/doc_platform、historical .learnings/）
> 获取到信息且**结论冲突**时，按以下 4 级优先级仲裁。本规则同时驱动 knowledge-loop 的「scanned → verified 自动升级」
> （详见 `knowledge-loop/references/confidence.md` § scanned 自动升级规则）。

#### 仲裁优先级（P0 最高）

| 优先级 | 来源 | 信任理由 | AI 行为 |
| :---: | --- | --- | --- |
| **P0** | 本地代码事实（`codebase_search` / `read_file` 命中的源码、类型定义、测试用例） | 真相唯一源，所见即所得 | 直接采纳，作为仲裁基线 |
| **P1** | 本地 knowledge（`~/.codebuddy/knowledge/`，confidence ∈ {verified, pending(本分支)}） | AI 沉淀 + 用户验证 + 与 P0 同源（沉淀时已对齐代码） | 直接采纳；与 P0 一致时给予加权 |
| **P2** | remote-kb/git（远程源码语义检索）、remote-kb/commit（变更历史） | 项目源码索引，与 P0 同源但可能有索引延迟 | 必须用 `read_file` 验证文件真实存在；一致 → 采纳；不一致 → 标 ⚠️ 降级 |
| **P3** | remote-kb/wiki / git_doc_platform（架构文档）、外部 web_search、领域知识 | 设计意图载体；不直接对应代码 | 仅作为「设计意图」参考；不得用于修正 P0 的代码事实判定 |

#### 冲突仲裁规则

1. **P0 vs P1 冲突**（代码与本地知识不一致）→ P0 胜出；将对应 knowledge 主题文件 `confidence` 降为 `stale` + `drift_count += 1`，输出漂移提醒
2. **P0 vs P2 冲突**（代码与 remote-kb/git 不一致）→ P0 胜出；知识库平台 索引可能滞后，结果列表中将该来源标 ⚠️ 但不阻塞流程
3. **P0 vs P3 冲突**（代码与 wiki 设计文档不一致）→ P0 胜出；wiki 视为「过期/未实施」证据，**不污染代码判定**；
   可在 design-intent.md 中标记 stale 并附 diff（详见 `knowledge-loop/modes/deposit.md` § design-intent 写入规则）
4. **P1 vs P2 冲突**（本地 knowledge 与 remote-kb/git 不一致）→ 用 P0 兜底裁决；都不胜出时优先 P1（本地沉淀通常更新）
5. **P2 vs P3 冲突**（知识库平台 源码与 wiki 不一致）→ P2 胜出；wiki 视为过期
6. **多源同向命中**（如 P0 + P1 + P2 一致）→ 在「相关文件表格」中合并标注 `[local]+[remote-kb/git]+[knowledge]`，置信度最高

#### 降级条款（防止 P3 反噬 P0）

- ❌ **禁止**：用 P3（wiki/doc_platform/web_search）的结论修正或推翻 P0（代码事实）的判定，**即使 wiki 看起来更权威**
- ❌ **禁止**：发现 wiki 描述与代码不一致时，自动按 wiki 改代码（应当反向：把 wiki 视为陈旧文档，代码视为现实）
- ✅ **允许**：将 wiki 视为「设计意图档案」，写入 design-intent.md（与代码事实并列，不互相覆盖）
- ✅ **允许**：用 wiki 中的「未来规划/将要支持」类陈述作为需求理解参考，但不得据此声称功能已实现

#### scanned → verified 自动升级（混合策略）

本步骤检索到的远程知识（P2/P3）按以下规则**自动**升级或标记，**无需用户在步骤 1 内确认**（避免打断研究节奏）；用户可异步通过 `dev:kb audit` 审计：

| 远程知识情形 | 自动行为 | 写入位置 |
| --- | --- | --- |
| 找到对应代码符号 + 内容与代码一致 | 升级 `auto-verified`（与人工 verified 区分） | knowledge 主题文件 / design-intent.md |
| 找到对应代码符号 + 内容与代码不一致 | 标记 `auto-stale` + 附 diff 摘要 | 同上 |
| 找不到对应代码符号 | 保留 `scanned`，不升级 | 同上 |
| 涉及「规划/将要/未来/计划」句式 | **强制**保留 `scanned`，不升级（避免把规划误读为已实施） | 同上 |
| 版本标识与代码 changelog 不一致 | 标记 `auto-stale` | 同上 |

> 完整状态机与子状态字段定义 → `knowledge-loop/references/confidence.md` § scanned 自动升级规则。

### 2. Figma 设计稿处理

如果用户提供了 Figma 设计稿链接 → `read_file("references/figma-flow.md")` 加载完整处理流程（两级策略）。

### 3. 领域知识补充（涉及不熟悉技术领域时必须执行）

1. AI 主动查阅：文档平台、KM、web_search 等
2. 请求用户补充：用户可能有内部文档
3. 知识确认：向用户确认理解是否正确，**必须使用 `ask_followup_question` 弹出交互式选项**：

```text
以上是我对该领域知识的理解，请确认：

```

| 选项 | 说明 |
| --- | --- |
| ✅ 理解正确 | 继续下一步 |
| ✏️ 补充信息 | 告诉我遗漏或理解有误的部分 |
| ⏭️ 跳过，先开始 | 暂不确认，先按当前理解推进 |

### 4. 迭代修复场景

当通过迭代修复路径进入时，步骤 1 简化为增量研究。详见 `references/iteration-fix.md`。

## ⛔ 退出自检清单（逐项口播确认后才能输出完成 JSON）

在输出完成标记 JSON 之前，逐项确认并口播：

- [ ] 0.a 项目知识检索：`knowledge-loop` 已调用？
- [ ] 0.c 知识库平台 信号判定：已执行？`remote_kb_signals_hit` 字段正确？
- [ ] 0.5 历史经验检索：`.learnings/` 已检索？`learnings_matched` 字段正确？
- [ ] 多源并行检索已完成（至少 1 次 codebase_search）？
- [ ] `codebase_queries_count` >= 1？
- [ ] 相关文件表格已输出？`related_files_count` > 0？
- [ ] 调用链路图已按触发矩阵输出（或 `call_graph_drawn: not_applicable`）？
- [ ] 充分性校验硬门控通过：
  - `search_queries_count` >= 2？
  - `keyword_variations_tried.length` >= 2？
  - `cross_verified` = true？
  - `confidence` != "low"？
- [ ] 领域知识确认（如涉及）已完成交互式选项？
- [ ] 上述全部完成 → 才可输出完成标记 JSON

---

## 必须输出

### 相关文件表格

```markdown
| 文件 | 关键位置 | 来源 | 作用 | 与本次任务的关系 |
| --- | --- | --- | --- | --- |
| `{相对路径}` | `{相对路径}` L{起}-L{止} | [local]/[remote-kb/git]/[remote-kb/wiki]/[remote-kb/commit]/[knowledge] | {文件作用} | 核心改动 / 上游依赖 / 下游消费 / 可复用 |
```

**来源标签说明**（详见 `references/remote-knowledge.md` §五 5.2「结果标注规范」）：

- `[local]` — 本地 codebase_search/grep_search 命中（默认）
- `[remote-kb/git]` — 知识库平台 源码语义检索命中
- `[remote-kb/wiki]` — 知识库平台 架构 wiki 命中
- `[remote-kb/commit]` — 知识库平台 变更历史命中
- `[remote-kb/mr]` — 知识库平台 MR 检索命中（通常仅步骤 3 出现）
- `[knowledge]` — 本地 `~/.codebuddy/knowledge/` 命中
- `[local]+[remote-kb/git]` — 多源交叉验证命中（置信度最高）

> 📌 「文件」与「关键位置」两列必须按 `~/.codebuddy/rules/AI行为规范.mdc` 的「文件/代码位置引用」规范
> 使用反引号包裹相对路径（`` `相对路径` `` + 空格后缀行号），IDE 自动识别为可点击链接。
> 此规范由 `references/gate-validator.md` 路径可点击性门控强制校验。
> 📌 MCP 命中的条目必须经过 `read_file` 真实性验证；验证失败的条目在「来源」列后追加 ⚠️。

### 调用链路图（按需输出）

> 规范详见 references/call-graph-spec.md。按触发矩阵判断是否输出。
> 不画条件（不满足触发矩阵任一画图场景）：极简模式 OR（related_files_count ≤ 2 AND upstream_deps.length === 0）。
> 画条件（满足任一即画，格式按触发矩阵选择）：related_files_count ≥ 3 OR upstream_deps.length ≥ 1 OR 存在分支条件渲染 OR 涉及 ≥ 3 个独立模块。

小型改动用文本树格式；中型/跨模块用 Mermaid graph TD；具体模板见 call-graph-spec.md。

> 本图是 step-2/3/6/7 复用的唯一真相源，后续步骤基于本图标注/增强，禁止重画。

### 历史经验命中（如有匹配）

```markdown
| 经验来源 | 相关内容 | 复现次数 | 对本次任务的启示 |
| --- | --- | :---: | --- |
| LEARNINGS.md#条目X | {经验摘要} | ⚠️ 3次 | **高频坑点，必须重点检查** |
```

### 多源仲裁与升级摘要（如本步骤进行了远程知识检索）

> 当 知识库平台 信号 1/4 命中且发起了 MCP 调用时，本区块**必须输出**；未命中信号（完全沉默）时省略。

```markdown
📊 多源知识仲裁摘要
├── 本次检索远程条目：N 条
├── 自动升级 verified（auto-verified）：X 条
├── 自动标记 stale（auto-stale）：Y 条（详见漂移列表）
├── 保留 scanned 待审计：Z 条（含规划句式 / 找不到代码符号）
└── 与 P0 代码事实冲突：M 条（已按降级条款处理，wiki 视为过期）

💡 异步审计入口：`dev:kb audit` 查看本次自动升级的详细列表，可一键 reject。

```

### 步骤推进选项（标准模式必须）

按 `steps/step-router.md` §「步骤流转交互规则」，完成标记 JSON 输出并状态同步后，**必须调用 `ask_followup_question` 弹出推进选项**（先文本表格展示，再调用工具）：

| 选项 | 说明 |
| --- | --- |
| ▶️ 继续步骤 2（确认范围） | 研究已充分，进入影响范围报告 |
| ⏸️ 暂停，我有补充/疑问 | 暂停等待用户输入（如需要补充研究关键词） |
| 🔁 回退步骤 1 补充研究 | 研究不充分，扩大搜索范围 |

> **精简模式豁免**：步骤 1→2 为🟢流程决策点，精简模式下按 `references/interaction-mode.md` 可静默推进为一行摘要。

### 结构化完成标记（必须输出，缺字段视为未完成）

```json
{
"step": 1,
"name": "研究与定位",
"status": "completed",
"outputs": {
"related_files_count": "发现的相关文件数量（数字）",
"upstream_deps": ["上游依赖文件列表"],
"downstream_deps": ["下游消费方文件列表"],
"reusable_components": ["可复用的组件/工具函数"],
"domain_knowledge_confirmed": "true | false | skipped",
"knowledge_loaded": "已加载的知识文件列表 或 none（项目无 knowledge）",
"learnings_matched": "匹配到的历史经验条数（数字）或 0（无匹配/不存在）",
"remote_kb_signals_hit": "本步骤命中的 知识库平台 信号数组（如 [] / ['signal_1'] / ['signal_4']；未命中时为 []，代表完全沉默）",
"remote_kb_calls_made": "本步骤实际发起的 MCP 调用次数（数字，默认沉默时为 0）",
"remote_kb_tokens_used": "本步骤 知识库平台 实际消耗 token（数字，默认沉默时为 0；信号 1≤ 1.5k；信号 4≤ 6k）",
"arbitration_summary": {
"remote_items_total": "本步骤检索到的远程条目总数（数字，默认 0）",
"auto_verified_count": "自动升级为 auto-verified 的条目数（数字）",
"auto_stale_count": "自动标记为 auto-stale 的条目数（数字）",
"scanned_kept_count": "保留 scanned 待审计的条目数（数字）",
"p0_conflicts_count": "与 P0 代码事实冲突的条目数（数字，已按降级条款处理）"
}
},
"sufficiency_check": {
"codebase_queries_count": "已执行的 codebase_search/grep_search 次数（数字）",
"mcp_queries_count": "已执行的 知识库平台 MCP 调用次数（数字，未启用时为 0）",
"search_queries_count": "codebase_queries_count + mcp_queries_count 总数（数字，向后兼容）",
"keyword_variations_tried": ["尝试过的关键词变体列表，如 ['email validator', 'EMAIL_REG', '邮箱校验']"],
"cross_verified": "true | false（是否使用 ≥2 种关键词交叉验证）",
"confidence": "high | medium | low",
"confidence_reason": "置信度理由（一句话，说明为什么认为研究已充分）",
"call_graph_drawn": "true | not_applicable（极简模式/无需画图）"
},
"working_context_updated": true,
"next_step": 2
}

```

**完成标记校验规则**：

- `related_files_count` 必须 > 0（至少找到 1 个相关文件）
- `upstream_deps` 和 `downstream_deps` 可以为空数组，但字段必须存在
- `reusable_components` 可以为空数组（`[]`）——**禁止为了填表而编造不存在的可复用项**
- `status` 为 `completed` 时才能进入步骤 2
- `working_context_updated` 必须为 `true`

**充分性校验硬性门控**（防"伪装简化"，不可跳过）：

- `sufficiency_check.search_queries_count` **必须 ≥ 2**（至少两次不同角度的搜索才算研究过）
- `sufficiency_check.keyword_variations_tried.length` **必须 ≥ 2**（至少尝试 2 种关键词变体）
- `sufficiency_check.cross_verified` 必须为 `true`
- `sufficiency_check.confidence` 不得为 `"low"` —— 为 `"low"` 时 `status` 必须设为 `blocked`，回到研究阶段补充搜索
- **稀疏结果强制校验**：若 `related_files_count ≤ 2`，则 `search_queries_count` **必须 ≥ 3**（防止"搜一次只找到 1 个文件就算研究完"）
- **用户描述简短警戒**：若用户原始需求描述 ≤ 20 字（如"修复登录问题"），必须额外执行 2 次及以上变体搜索，`keyword_variations_tried.length` **必须 ≥ 3**
- **知识库平台 信号驱动门控**（不再按档位强制调用 MCP）：
- `codebase_queries_count` **必须 ≥ 1**（本地仍是真相源，不管信号是否命中）
- **信号一致性校验**：
- `remote_kb_signals_hit === []` → `remote_kb_calls_made` 必须 = 0 且 `remote_kb_tokens_used` 必须 = 0（默认沉默，不得擅自调用）
- `remote_kb_signals_hit` 非空 → `remote_kb_calls_made` 必须 ≥ 1 且与信号定义的 `data_type` 一致（见 [remote-knowledge.md](../references/remote-knowledge.md) §一）
- **Token 预算硬门控**：
- 信号 1 命中 → `remote_kb_tokens_used` ≤ 1500
- 信号 4 命中 → `remote_kb_tokens_used` ≤ 6000
- 超限必须压缩摘要或减少 top_k

> 任一校验不通过 → `status: "blocked"`，输出提示「研究未充分，已补充搜索中」→ 继续搜索后重新输出完成标记，不得强行进入步骤 2。

## 产出物真实性约束（遵循 `flow.md` 核心理念）

- 相关文件表格只列**真实相关**的文件，不为凑数扩充
- 若任务无上下游依赖（如单文件正则修复），`upstream_deps` / `downstream_deps` 直接输出 `[]`
- 若无可复用组件，`reusable_components` 输出 `[]`，不编造
- 「历史经验命中」区块若无匹配，**不得静默省略**，须显式标注"无（.learnings/ 目录下未匹配到相关经验）"
- `sufficiency_check` 字段不得伪造——`search_queries_count` 必须对应实际工具调用次数，`keyword_variations_tried` 必须是实际使用过的关键词
- `call_graph_drawn` 硬门控：满足「不画」触发条件（极简模式、单文件无上下游）时必须填 `not_applicable`；其余情况必须为 `true`——**画不出调用图 = 研究未真正理解链路**，此时须回到研究阶段补充搜索，禁止强行进入步骤 2。
