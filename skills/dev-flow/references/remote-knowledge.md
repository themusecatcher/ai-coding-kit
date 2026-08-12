# 知识库平台 节点信号触达 · 单一权威源

> 按需加载：仅在命中「节点信号」时由对应步骤（step-1 / step-3 / step-9）主动读取，**非每次 dev-flow 加载**。
> 本文件合并自 v1 三文件（remote-kb-config / remote-kb-token-strategy / remote-kb-projects），是 知识库平台 触达机制的**唯一权威源**。修改后无需同步其他文件。

## 定位（一句话）

**知识库平台 不是档位驱动的并列知识源，而是节点级外援**：默认沉默；只有明确的「节点信号」命中时才发起 MCP 调用；每个信号绑定 1 种 `data_type`，不做全类型盲调。三类不可替代价值——**①设计意图（git_doc_platform）②历史排障经验（git_doc_platform）③演进决策轨迹（git_merge_request）**。

---

## §一 节点信号定义（5 个，核心）

> ⚠️ **signal_id 是稳定标识符**，被 `references/output-schemas.md` / `schemas/all-steps.schema.json` / 遥测日志 / dev-flow 步骤完成标记 JSON 引用，**严禁更改**。

| 信号 | signal_id（稳定标识，禁止修改） | 触发节点 | 检测条件（任一满足） | data_type | calls_max | max_tokens |
| --- | --- | --- | --- | --- | :---: | :---: |
| **1** 首次接触陌生模块 | `first_touch_unfamiliar_module` | step-1 | profile 缺失 / `dev:ref` / 关键词「首次接触·不熟悉·陌生模块·理解架构」 | `git_doc_platform` | 1 | 1500 |
| **2** 方案需历史参考 | `plan_needs_history_reference` | step-3 | 复杂度 ∈ {standard, complex_feature} / `dev:mr` / 关键词「新增·对接·集成·重构·升级·接入」 | `git_merge_request` | 1 | 2000 |
| **3** bugfix 历史踩坑 | `bugfix_needs_known_pitfalls` | step-9 | `need_type=bugfix` / 有 任务平台 Bug 单 / `dev:pitfalls` | `git_doc_platform`（query_hint：常见问题;历史坑;排障;踩坑） | 1 | 1000 |
| **4** 跨项目联调（消费方契约） | `cross_project_consumer_verify` | step-1 | `package.json` 含组织内部组件库 / `cross_project.enabled=true` / `--cross-project` | `git` + `git_doc_platform`（**不传 search_domain**，全库检索） | 3 | 6000 |
| **5** commit 风格参考 | `commit_message_style_reference` | step-7 | 仅 `dev:commit-ref` 主动触发 | `git_commit` | 1 | 500 |

> 工作上下文 / output JSON 中以 `signal_1` / `signal_2` / ... / `signal_5` 形式引用（如 `remote_kb_signals_hit: ["signal_4"]`）；signal_id 是配置层定义，两者通过序号关联。

**沉默默认**：未命中任何信号 → `skip_all_mcp`，本地 `codebase_search` / `grep` / `read_file` 即真相源。

---

## §二 项目映射表

> ⚠️ 以下为模板格式。使用前请填入你自己的项目信息。
> 维护：新项目接入 知识库平台 后须在此追加。

### 2.1 项目 ↔ 目录 ↔ search_domain（data_type=git；其他类型同理后缀 `-master-<type>`）

| 项目名 | 目录关键词（路径包含即匹配） | 默认分支 | git 域 |
| --- | --- | :---: | --- |
| <!-- 在此添加你的项目行，格式：| 项目名 | 路径关键词 | master | org@repo-master | --> |

> 其他 data_type 域：在 git 域后追加 `-git_doc_platform` / `-git_commit` / `-git_merge_request`。

### 2.2 本地仓库速查表（跨项目分析 reflex 三步法用）

| 项目 | 包名（package.json `name`） | 本地绝对路径 | 仓库 URL（未 clone 时提醒） |
| --- | --- | --- | --- |
| <!-- 在此添加你的项目行 --> |

#### 包名 → 本地路径速查（用于 import 反查）

| 包名 | 项目 | 本地路径 |
| --- | --- | --- |
| <!-- 在此添加你的包映射 --> |

> 📌 **包名核查方法**：`find {workspace_root}/{repo} -name "package.json" -not -path "*/node_modules/*" | xargs grep '"name"'`
> 实测，禁止凭记忆/推测。
> 📌 **使用规则**（与 cross-project-flow 联动）：
> (1) 优先 `ls {workspace_root}/ | grep -i {kw}` 模糊匹配；
> (2) 命中本地必须做分支感知 `git branch --show-current` 与默认分支对照；
> (3) 未命中本地必须主动提醒用户 clone（4 选项），
> 禁止静默 fallback 到 知识库平台 MCP。

### 2.3 匹配规则

1. **项目识别**：从 `pwd` 或工作上下文 `## 需求 > 项目` 字段提取
2. **关键词匹配**：对「目录关键词」列**包含匹配**（大小写敏感），匹配第一条即定 `knowledge_uuid`
3. **未匹配**：视为「项目未接入 知识库平台」→ 静默跳过，走本地流程
4. **多匹配**：取**最长关键词**（`MyOrg/my-project` 优先于 `my-project`）

### 2.4 技术栈共性（便于 AI 快速理解）

<!-- 在此描述你的项目技术栈共性 -->
<!-- 例：Next.js 14 + React 18 + TypeScript + Zustand + i18next + antd + 多语言 + 监控 SDK -->

---

## §三 MCP 调用与 Token 预算

### 3.1 MCP server 选择规则（统一约束 step-0.5/1/3/5/9 所有调用）

| 优先级 | 选用规则 | 适用场景 |
| :---: | --- | --- |
| ① 首选 | `description` 中明确列出当前项目的 server | 通常是 `remote_kb`（项目清单内嵌） |
| ② 次选 | 通用 `knowledge` server（通过 `knowledge_uuid` 直接访问） | ① 不可用或当前项目不在 remote_kb 清单 |
| ③ 兜底 | 调用失败时切另一个 server 重试**一次**（非循环） | 单一 server 偶发故障 |

调用模板中 `serverName` 字段以占位符 `{remote_kb | knowledge}` 表示，按当前环境替换。**禁止**凭记忆固定写死。

### 3.2 调用模板（A/B/C/D）

```json
// A. git_doc_platform（架构 wiki，信号 1/3）
{ "serverName":"{remote_kb | knowledge}", "toolName":"knowledgebase_search",
"arguments": { "knowledge_uuid":"{uuid}", "data_type":"git_doc_platform", "query":"{语义化描述}", "keyword":"{kw1;kw2;kw3}" } }

// B. git（源码语义，仅信号 4 跨项目）
{ ..., "data_type":"git", "query":"{业务功能}", "keyword":"{符号名}" }

// C. git_commit（信号 5 / commit 风格）
{ ..., "data_type":"git_commit", "query":"{文件/函数变更}", "keyword":"{文件名;函数名}" }

// D. git_merge_request（信号 2，方案历史参考）
{ ..., "data_type":"git_merge_request", "query":"{需求主题}", "keyword":"{标题关键词}" }

```

**默认参数**：`timeout=10s`、`chunk_top_k=3`（信号 1/2/3）/ `5`（信号 4）；`search_domain` 必传（信号 1/2/3/5）/ 不传（信号 4）。

### 3.3 数据类型价值分级

| 数据类型 | 价值 | 典型场景 | 噪声风险 |
| --- | --- | --- | --- |
| `git_doc_platform` | 🟢 最高 | 设计意图 / 架构决策 / 历史踩坑 | 低（人工沉淀） |
| `git_merge_request` | 🟢 极高 | 类似问题已有解 / bug 根因追溯 | 低 |
| `git_commit` | 🟡 中 | commit 风格参考 | 中 |
| `git` | 🔴 低（本地已有） | 仅跨项目场景有用 | 高（大量低价值函数解释） |

**结论**：`git_doc_platform` + `git_merge_request` 是主力；`git` 仅跨项目用；`git_commit` 仅手动触发。

> 节点 × 信号 × 预算速查见 §一 信号表；阶段 0 / 0.5 / 步骤 2/4/5/6/10 节点 token=0（不触发）。

---

## §四 噪声过滤、关键词扩展与降级

### 4.1 噪声过滤（MCP 返回后必做）

```yaml
noise_filter:
skip_if_title_matches:

- "^use[A-Z]\\w+$"       # 单 Hook 一行代码解释（如 useError → 重复 4 次）
- "^[A-Z_]+$"            # 纯常量名（如 BREAKER_TIPS）
require_min_content_lines: 3

```

**结果摘要压缩**：单条 chunk > 500 token 时，AI 必须内联摘要为 ≤200 token 才写入步骤 1 表格；
原始长片段**不得**原样复制进 working-context；
保留字段：`file_path` + `key_symbol` + `core_logic_sentence`；
需要原文时仅留链接 `{来源:remote-kb/git, href:xxx}`。

### 4.2 关键词扩展（信号触发 MCP 时生效）

触发（任一）：描述 ≤ 20 字 / 首次 MCP 命中 ≤ 1 条 / 关键词单语言。规则：原词 → 中文变体（同义词;全称;缩写）+ 英文变体（直译;camelCase;snake_case;常见 API 名），**≥ 3 个变体才能发起调用**。

### 4.3 降级与 CLI 覆盖

**降级**：项目未在映射表 / MCP 超时 (>10s) / 返回错误 / 信号未命中 / `--no-remote-kb` → 本次跳过，走本地流程；连续 2 次失败 → 本轮降级为「仅本地」，下次对话恢复。**不做持久化熔断**。

**CLI 覆盖**：`--no-remote-kb`（全轮沉默）/ `dev:ref`（强制信号 1）/ `dev:mr`（信号 2）/
`dev:pitfalls`（信号 3）/ `--cross-project`（信号 4 全库检索）/
`dev:commit-ref`（信号 5）/ `--budget=<N>`（覆盖 max_tokens）。

---

## §五 自检清单与结果标注

### 5.1 信号触发前 AI 必过自检

- [ ] 是否命中任一信号？未命中 → 立即沉默退出
- [ ] `data_type` 与信号表定义一致（不盲调全类型）
- [ ] 信号 1/2/3/5 传 `search_domain` / 信号 4 不传
- [ ] `chunk_top_k` 按信号上限取值
- [ ] 关键词变体 ≥ 3（描述 ≤ 20 字时）
- [ ] Token 预算未超 `max_tokens` 上限
- [ ] 返回 chunk > 500 token 压缩为 ≤200 token 摘要
- [ ] 命中 `noise_filter` 的 chunk 必须丢弃
- [ ] 遥测记录到 `~/.codebuddy/.learnings/remote-kb-metrics.jsonl`

### 5.2 结果标注规范（步骤 1「相关文件表格」必须前缀）

- `[remote-kb/git]` 源码语义命中 / `[remote-kb/wiki]` 架构 wiki / `[remote-kb/commit]` 变更历史 / `[remote-kb/mr]` MR
- `[local]` 本地 codebase_search/grep（默认可省略）/ `[knowledge]` 本地 `~/.codebuddy/knowledge/` 命中

**交叉验证**：MCP 命中的文件路径**必须用 `read_file` 验证真实存在**（防索引延迟）；验证失败标注 ⚠️。

### 5.3 profile 层（仅用户主动 onboard 后生效）

- 路径：`~/.codebuddy/knowledge/{project}/_profile.md`
- 软 TTL 14 天 / 硬 TTL 45 天 / 不再每次 dev-flow 漂移检测
- 全量刷新 ≤ 3 次 MCP / 增量刷新 1 次 / 轻验证 1 次
- 详细生命周期 → `references/onboard-flow.md`

### 5.4 遥测

- 日志：`~/.codebuddy/.learnings/remote-kb-metrics.jsonl`
- 字段：`signal, trigger_at, data_type, calls, tokens_used, hits, adopted, timestamp`
- 仅命中信号时记录（避免大量空记录）

---

## §六 量化收益与真实案例

| 场景 | 命中信号 | 调用次数 | Token | 节省 vs v1 档位驱动 |
| --- | --- | :---: | :---: | :---: |
| 🟢 小 bug 修复（正则/文案） | 无 → 沉默 | 0 | 0 | **100%** |
| 🟡 项目内常规功能（熟悉模块） | 无 | 0 | 0 | **100%** |
| 🟢 项目内新功能（首次碰陌生模块） | 1 | 1 | ≤1.5k | 72% |
| 🩹 bugfix（带 任务平台 Bug 单） | 3 | 1 | ≤1k | 83% |
| 🣠 复杂新功能（关键词匹配） | 2 | 1 | ≤2k | — |
| 🣠 复杂新功能 + 首次接触模块 | 1+2 | 2 | ≤3.5k | 71% |
| 🔴 跨项目联调（my-component → 消费方） | 4 | ≤3 | ≤6k | 50% |
| 📝 用户 `dev:commit-ref` | 5 | 1 | ≤0.5k | — |

**加权平均**（按真实频率 70%/15%/8%/5%/2%）：v1 档位驱动 ~8.2k token / 次 → v2 节点信号 ~0.9k token / 次，**整体节省 89%**。

### 真实案例回归（working-context/ 抽样）

- email-regex-fix（小修复）/ pageheader-i18n（熟悉模块）→ 无信号 → 0 调用 ✅
- article-filter（首次接触 + 新增）→ 信号 1+2 → 2 次 ≤3.5k ✅
- lang-switch（跨项目）→ 信号 4 → ≤3 次 ≤6k ✅ 核对消费方
- dark-theme（bugfix）→ 信号 3 → 1 次 ≤1k ✅ 拿到历史踩坑

---

## 附：与其他文档的关系

- profile 按需生命周期 → `references/onboard-flow.md`
- 跨项目衔接流程 → `references/cross-project-flow.md`（信号 4 命中后的项目间流转）
- 步骤 1 研究集成 → `steps/step-1-research.md`
- 步骤 3 方案集成 → `steps/step-3-plan.md`
- 步骤 9 反思集成 → `steps/step-9-reflection.md`

> **维护原则**：本文件是 知识库平台 触达机制的**单一权威源**。新增信号 / 修改 token 预算 / 调整噪声规则 / 追加项目映射，**只改本文件**。
