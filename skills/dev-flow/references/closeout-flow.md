# 步骤 7 收尾子流程规范（commit / devlog / knowledge / 文档平台 对账）

> 本文件定义步骤 7 的收尾子流程规范，被 `step-7-commit.md` 引用。
> 步骤 7 通过「调用方」参数（`caller=standard-7` / `full-7` / `batch-7` / `micro-fix-7`）控制差异行为，复用同一套环节定义。
> 步骤 8-10 完整执行的对账子流程（`caller=full-10`）也共用本文件 §H.3+ 的实现。
>
> 📌 命名历史：
>
> - 一代命名 `wrapup-flow.md`
> - 2026-06-02：移除独立收尾模式，文件被收敛为步骤 7 子流程规范
> - 2026-06-03：重命名为 `closeout-flow.md`，
>   与同目录 `iteration-fix.md` / `flow-retrospective.md` / `tech-proposal-flow.md` 命名风格对齐；
>   `closeout` 在项目管理标准术语中专指「项目收尾闭环」，
>   语义精准对齐本文件实质（commit/devlog/knowledge/文档平台方案 对账闭环）

## 调用方标识

| 调用方 | 标识 | 入口场景 | 差异 |
| --- | --- | --- | --- |
| 标准执行步骤7 | `caller=standard-7` | dev-flow 流程内，步骤6完成后自动进入 | 含可选链检查、TODO检查、即时验证、数据驱动反思 |
| 完整执行步骤7 | `caller=full-7` | dev-flow 完整执行，步骤6完成后进入 | 仅清理+L2审查，commit/devlog/knowledge推迟到步骤10 |
| 批次执行步骤7 | `caller=batch-7` | dev-flow 分批执行，非最后一批的步骤6完成后进入 | 清理+L2审查+精简版Commit+增量devlog，跳过knowledge/反思 |
| 流程内同步入口 | `caller=in-flow-sync` | `dev:sync` / `dev:s2` 流程进行中触发 | 仅 H.0+H.2+H.3+H.3+ 文档同步子集，跳过 commit/L2-L3/度量/K，完成后回到原步骤；详见 `references/in-flow-sync.md` |

## 完整流程（环节 A~I）

以下按执行顺序列出所有环节，各调用方按标记执行对应环节：

### 环节 A：Diff 分析（全部调用方）

> ⚠️ **Diff 基准分两层**：先看「本功能分支相对主干的全量改动」识别整体影响范围，再看「本地未提交/已暂存的改动」识别预期外变更。

```bash
# 第 0 步：自动检测远程主干分支（兼容 master/main/develop）
REMOTE_DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/@@')
if [ -z "$REMOTE_DEFAULT" ]; then
  # fallback：按优先级探测
  for branch in origin/master origin/main origin/develop; do
    git rev-parse --verify "$branch" >/dev/null 2>&1 && REMOTE_DEFAULT="$branch" && break
  done
fi
# 如果仍为空，说明远程信息不完整，跳过第 1 层，仅执行第 2 层

# 第 1 层：功能分支 vs 主干 全量差异（识别整体影响范围）
git diff $(git merge-base $REMOTE_DEFAULT HEAD) HEAD --stat

# 第 2 层：本地未提交 + 已暂存改动（识别预期外变更）
git status
git diff HEAD --stat     # 同时统计 unstaged + staged 改动（自动去重）
```

- 第 1 层用于汇总本次需求的完整改动文件清单（含已 commit 的）
- 第 2 层用于检查是否有预期外的文件被修改（lock 文件、配置文件、不相关模块）
- 远程主干分支检测失败时，跳过第 1 层（降级为仅第 2 层），并在输出中提示用户检查远程配置
- ⚠️ **跨项目场景**：feature 分支可能合入了其他人的 master 改动，必须用 `--author` 过滤后才能确认本人改动范围（详见 `references/cross-project/integration.md` §「Diff / Commit 查看规范」）
- 发现预期外变更 → 列出变更清单，**必须使用 `ask_followup_question` 弹出交互式选项**：

| 选项 | 说明 |
| --- | --- |
| 🧹 全部回退 | 对所有预期外文件执行 `git checkout` |
| ✏️ 部分回退 | 告诉我保留哪几项 |
| ⏭️ 保留全部 | 不回退，继续下一步 |

### 环节 B：清理调试代码（全部调用方）

扫描改动文件中遗留调试代码：

- `console.log` / `console.debug`（业务日志除外）
- `debugger` 语句
- 临时注释（`// TODO: remove`、`// test`、`// hack`）
- 临时样式（`background: red`、`border: 1px solid red`）
- mock 数据 / 硬编码测试值
- `// [ACCEPTANCE-TEST]` 标记的验收调试代码（仅 `caller=standard-7`）

发现遗留 → 列出清单，**必须使用 `ask_followup_question` 弹出交互式选项**：

| 选项 | 说明 |
| --- | --- |
| 🧹 全部清理 | 清理所有遗留项 |
| ✏️ 部分清理 | 告诉我保留哪几项 |
| ⏭️ 跳过 | 不清理，继续下一步 |

用户说"不用检查" → 跳过。

### 环节 C：可选链优化检查（仅 `caller=standard-7` / `caller=full-7` / `caller=batch-7`）

按红线 §7 检查本次改动涉及的链式调用，优先优化改动行，同函数内建议一并优化。

### 环节 D：即时验证（仅 `caller=standard-7` / `caller=full-7` / `caller=batch-7`）

按 `references/code-safety-rules.md` 规则执行——`read_lints` 验证 → 通过后回 5.5c 自检。

### 环节 E：TODO 完整性检查（仅 `caller=standard-7` / `caller=full-7` / `caller=batch-7`）

检查是否有遗留的 TODO 项。

### 环节 F：改动汇总（展示用户确认，全部调用方）

基于环节 A 的 Diff 分析结果，向用户展示本轮改动汇总表格：

```markdown
## 📋 本轮改动汇总

| 文件 | 改动 | 说明 |
|------|:---:|------|
| `src/components/xxx.tsx` L42-L45 | 修改 | 修复空值判断逻辑 |
| `src/utils/yyy.ts` L100-L120 | 新增 | 新增导出功能 |

改动文件：N 个  |  新增：+X 行  |  删除：-Y 行
```

- 数据来源：环节 A 的 `git diff --stat` + 步骤 5 的工作上下文编码记录
- 仅展示，不写文件
- 展示后**必须使用 `ask_followup_question` 弹出交互式选项**：

| 选项 | 说明 |
| --- | --- |
| ✅ 确认无误 | 改动范围正确，继续 G. L2 审查 |
| ✏️ 需要调整 | 描述需要调整的内容 → 回退步骤 5 修复 |
| 📋 查看详细 diff | 展示完整 git diff 内容 |

### 环节 G：L2 完整规范审查（全部调用方，必须，审核者分离）

> **设计原则**：L2 审查是 commit 前的最后一道质量门。通过 3 个独立子 agent 并行审查（代码质量 + 安全 + 性能），消除"编码者自审"盲区，对齐 L3 审查的多视角标准。

#### G.1 审查素材准备（主 agent）

1. 获取完整 diff：复用环节 A「第 0 步」检测的 `$REMOTE_DEFAULT`，执行 `git diff $(git merge-base $REMOTE_DEFAULT HEAD) HEAD` 获取功能分支全量改动
2. 生成改动文件清单（`git diff --stat`）
3. 从工作上下文中提取方案摘要和执行计划

#### G.2 Fan-out 并行子 agent 审查

```text
🔀 Fan-out（步骤 7-G L2 审查，3 子 Agent）：
├─ Task(2号-审查): 代码质量视角
│   审查要点：
│   - CRITICAL/HIGH 问题扫描（功能正确性、数据一致性、状态管理）
│   - 可维护性（命名清晰、职责单一、无冗余抽象、if 嵌套不过深）
│   - 边界条件（空值/并发/异常输入是否全覆盖）
│   - 可选链：所有链式属性访问是否使用 ?.
│   - 代码风格一致性（与项目现有代码风格对齐）
│   - 调试代码残留检测
│   - 测试点位建议（指出哪些关键逻辑应优先补测试）
│
├─ Task(5号-安全): 安全审计视角
│   审查要点：
│   - XSS 漏洞（dangerouslySetInnerHTML、innerHTML、document.write）
│   - SQL/命令注入风险
│   - 硬编码密钥/token/敏感凭证
│   - 用户输入未校验/未转义
│   - 敏感数据泄露（日志打印密码/token、响应暴露内部实现）
│   - CSRF 防护缺失
│
└─ Task(6号-性能): 性能工程视角
    审查要点：
    - React 组件不必要的重渲染（缺少 memo/useMemo/useCallback）
    - 新增依赖对包体积的影响
    - 内存泄漏风险（未清理的定时器/事件监听/订阅/useEffect 缺 cleanup）
    - 浏览器兼容性（通过 MDN/Can I Use 查询 API 支持度）
```

> ⚠️ 每个 Task prompt 必须包含：① 功能分支全量 diff ② 方案摘要（从工作上下文提取）③ 期望输出格式（按严重度分级 CRITICAL/HIGH/MEDIUM/LOW，含文件位置+问题描述+修复建议）。

#### G.3 Fan-in 汇总与处理

**主 agent 汇总**：

1. 合并三份报告，去重（同一问题被多个 agent 发现时合并为一条）
2. 标注每条问题的来源（`[2号]` / `[5号]` / `[6号]` / `[2号+5号]` 等）
3. 按严重度排序，输出统一 L2 审查报告

**严重度处理**：

- 🔴 必须修复后才能 commit（无需用户决策）
  - 修复后必须回退步骤 5 修复 → 重走 5.5 L1 → 6A 验证 → 7-G L2 重新审查（最多 1 轮）
  - 第 2 轮仍出现 🔴 → 暂停等待用户介入
- 🟢 仅提示（无需用户决策）
- 🟡 建议修复项需用户决策，**必须使用 `ask_followup_question` 弹出交互式选项**：

| 选项 | 说明 |
| --- | --- |
| 🔧 全部修复 | 修复所有 🟡 建议项后再生成 commit |
| ⏭️ 全部跳过 | 跳过所有 🟡 建议项，直接生成 commit |
| ✏️ 部分修复 | 告诉我要修复哪几项 |

#### G.4 调用方差异

| 调用方 | L2 审查行为 |
| --- | --- |
| `caller=standard-7` | 完整执行 3 agent 审查（如上）→ 完成后进入环节 H |
| `caller=full-7` | 完整执行 3 agent 审查（如上）→ 到此结束，环节 H/I 推迟到步骤 10 |
| `caller=batch-7` | 完整执行 3 agent 审查（如上）→ 完成后进入环节 H（精简版） |

**`caller=full-7` 特殊规则**：完整执行步骤7到此结束，环节 H/I 推迟到步骤 10。

**`caller=batch-7` 特殊规则**：批次执行步骤7到环节 G 后继续环节 H（精简版），跳过环节 I。

**用户说"不用审查"**：仅跳过通用审查，L2 代码规范审查不可跳过。

#### G.5 L2 审查统计（必须）

审查完成后，统计并记录以下数据供度量采集使用：

- `l2_issues_found`：L2 审查发现的问题总数（🔴 + 🟡 + 🟢 所有严重度，三个 agent 去重后合计）
- `l2_issues_fixed`：实际修复的问题数（🔴 必须修复 + 用户选择修复的 🟡 建议项）
- 🟢 仅提示项不计入 fixed（因为不需要修复）
- 将统计结果写入完成标记的 `l2_review_result` 字段，格式：`"found:{N}_fixed:{M}"` 或 `"passed"`（无问题时）

#### G.6 成本

- 子 agent 调用：3 次并行 Task（~6-9k tokens，并行执行无额外串行时间）
- 审查范围：功能分支全量 diff vs 主干（比 L1 的"本轮改动"范围更大）
- 最多 1 轮修复-重审循环（防止无限循环）

### 环节 H：Commit + Devlog + 知识沉淀（`caller=standard-7` / `caller=batch-7`）

按以下编号顺序逐项执行，**禁止跳过或合并**：

#### 环节 H.0：CR 同步与登记（`caller=in-flow-sync` 必须，其他 caller 可选）

> 实施期追加的 CR 自动登记，复用 `drift-handling.md` §三 三步固定动作 + §步骤 3.5 记录 CR 条目 的 CR 创建逻辑。
> 单一权威源：CR 触发关键词在 `tech-doc/config/triggers.yaml` `working_context_drift`。
> 实证依据：`drift-handling.md` L126~L155 已实现 CR 自动登记 + 5.5 联动标记 done 的完整机制，本环节仅在 dev:sync 触发时间点上复用同一套逻辑。

**执行步骤**：

1. 读取工作上下文 YAML 头部 `change_requests` 数组现状
2. 扫描 git diff（相对 `.flow.last_sync_diff_sha` 或 `.flow.sync_base_sha` 之后的改动）
3. 对照 `change_requests` 数组：
   - 已有 `status: in_progress` 条目且 diff 命中其 description 涉及的文件 → 自动标记 `status: done` + 填写 `resolution`（同 drift-handling §步骤 3.5 与 5.5 联动机制）
   - 无对应条目但 diff 非空 → 按 drift-handling §步骤 3.5 模板自动创建新 CR（id 递增，type/level AI 自动判断，detected_at 填当前步骤号）
4. 写入完成标记 `cr_registered` 字段（数字 = 本次新增 CR 数）

**与 drift-handling 的差异**：drift-handling 是用户口头/IM 漂移**主动**触发 CR 登记；
H.0 是用户**已经动手改了代码**但漂移阶段未走 drift-handling 流程的**兜底**登记。
两者复用同一份 CR YAML schema 与 5.5 联动逻辑。

**调用方矩阵**：

| 调用方 | H.0 执行 |
| --- | :---: |
| `caller=in-flow-sync` | ✅ 必须 |
| `caller=standard-7` | 🟢 自动执行（已有 5.5b 联动） |
| `caller=full-7` | 🟢 自动执行 |
| `caller=batch-7` | 🟢 每批结束执行 |
| `caller=micro-fix-7` | ❌ 跳过 |

#### H.1 生成 Commit Message（必须）

按 `references/shared-rules.md` §1「Commit Message 生成」流程执行（含复用检查、任务平台 信息获取、生成、用户确认、持久化）。
仅生成，不自动执行 `git commit`（除非用户选择「📦 确认并提交」）。

#### H.2 生成/追加开发日志（必须，禁止跳过）

调用 `use_skill('tech-doc')` 路由到 devlog 模块，按 `references/devlog-rules.md` 规范生成/追加。

- ❌ 禁止以任何理由跳过
- ❌ 禁止引入"评估是否需要"的判断环节

> 📌 **复盘报告链接由环节 I 回填**：H.2 此时只生成 What/Why/How/Issues/Result/相关文档六段。
> 复盘报告 HTML 由环节 I 第 2 步生成后，
> **立即回填**到 devlog 最末 Round 末尾的 `#### 复盘报告` 段落
> （详见环节 I 第 3.1 步 + `devlog-rules.md` §「复盘报告链接联动」）。

**上线后 bugfix 增强**（迭代修复场景分类为「上线后 bugfix」时）：

1. **Round 标题**：使用 `### Round N：线上 Bug 修复 — {bug简述}（{日期}）` 格式
2. **Round 内容额外包含**：Bug 单号关联 + 线上影响范围描述
3. **plan.md 同步更新**：读取同目录 plan.md → 追加/更新「线上 Bug 修复记录」段落
4. **相关文档表格**：追加 任务平台 Bug 单链接

#### H.3 知识沉淀（必须，禁止跳过）

调用 `use_skill('knowledge-loop')` 沉淀模式，执行知识沉淀。

- ❌ 禁止以"改动简单"/"无新知识"等理由跳过
- 即使是简单改动，也至少更新已有模块 `_overview.md` 的变更历史

**上线后 bugfix 强化沉淀**（迭代修复场景分类为「上线后 bugfix」时）：

上线后 bugfix 的知识置信度极高（经线上环境验证 + bug 根因 100% 确认 + 修复已验证有效），执行强化沉淀：

1. **pitfalls.md 自动追加** + 标注 `[线上验证]` 标签，方便后续检索时优先展示
2. **_overview.md 变更历史**明确标注"线上 bugfix"（区别于普通迭代）
3. **跨模块通用性检查**：主动评估 bug 根因是否具有跨模块通用性（如参数命名混淆可能影响多个模块）→ 有通用性则同步更新 `_patterns/` 或其他模块的 `pitfalls.md`
4. **置信度标记**：沉淀条目标注 `confidence: production_verified`（最高置信度级别）

#### H.3+ 技术方案文档兜底对账（无条件触发：仅要求 docid 非空）

> 🎯 **设计原则**：联调/迭代期间不强制同步 文档平台，把所有累积偏离收敛到收尾节点一次性兜底对账。
> 基于 git diff 的「绝对真相」+ 工作上下文的「决策线索」+ 文档平台 原文的「章节结构」三方对账，
> 无论中间经历多少轮迭代，最终精度恒为 100%。

**触发条件**（仅一条）：工作上下文 `doc_platform_tech_proposal.docid` 非空 → 必须执行兜底对账。

> ⚠️ 与历史规则的差异：不再依赖「上线后 bugfix」「提测后迭代修复命中阈值」「status=outdated」等条件
> ——只要文档存在就对账。`doc_platform_tech_proposal.status == "outdated"` 字段仍然保留
> （用于步骤 4 · 文档决策（环节 3/4） 中标识用户选择「我自己更新」的状态），
> 但**不再作为兜底对账的触发条件**。

**执行细则**：本环节的具体执行流程（数据源采集 / 三方对账 / 偏离清单 / 用户决策 / 更新执行）由 `tech-doc/modules/doc-platform-doc.md` §「兜底对账子流程」承载，本节仅定义触发与产出契约。

**数据源采集**（兜底对账前必须完成）：

| 数据源 | 提供什么 | 命令/方法 |
| --- | --- | --- |
| 📌 git diff（绝对真相） | 最终代码改动 | 复用环节 A「第 0 步」检测的 `$REMOTE_DEFAULT`，执行 `git diff $(git merge-base $REMOTE_DEFAULT HEAD) HEAD` 获取完整 diff |
| 📌 工作上下文（决策线索） | Why + 取舍 | 读取 `working-context/{name}.md` 的决策记录 / `.flow.recovery` / `action_history` |
| 📌 文档原文（章节结构） | 文档当前内容 | 读取文档获取 Markdown 全文，按 `tech-proposal` 模板解析章节 |

**三方对账核心逻辑**：对每个 文档平台 章节，从 diff 提取实际改动 + 从工作上下文提取决策原因 +
与 文档平台 现有内容对比，分类标注偏离类型（字段新增/字段修改/方案变更/数据更新/文档遗漏/范围收窄）。
完整伪代码见 `tech-doc/modules/doc-platform-doc.md` §「兜底对账子流程」。

**输出格式**（A+B 分块格式，每个偏离项独立成块，含可直接复制的纯文本段）：

````markdown
### 技术方案文档兜底对账报告（{需求名}）

📌 原文档：{链接}
📊 代码 diff：{from}...HEAD（共 N 个文件，+X / -Y 行）
📋 工作上下文：working-context/{name}.md（决策记录 M 条，迭代轮次 K 轮）
📄 文档平台 文档：docid={xxx}（最后更新于 {time}）

---
### 偏离 1/3：{文档平台 章节}

**偏离类型：** {字段新增/字段修改/方案变更/数据更新/文档遗漏/范围收窄}

**变更原因：** {优先引用工作上下文决策记录，其次从 diff 推断}

**当前内容：**

```
{原文片段}
```

**📋 更新内容（点右上角复制按钮一键复制，粘贴到 文档平台）：**

```markdown
{新内容片段}
```

---
### 偏离 2/3：{文档平台 章节}

**偏离类型：** ...

（每个偏离项重复以上结构）
````

> ⚠️ **输出规则**：
>
> - 偏离项按 文档平台 章节顺序排列（一 → 二 → 三...），同章节内按偏离类型分组
> - "当前内容"和"更新内容"各用一个代码块，上下对照；"更新内容"代码块右上角 📋 按钮一键复制
> - "文档遗漏"类偏离："当前内容"代码块写 `（文档中无此内容）`，"更新内容"代码块给出完整新增段落
> - "字段修改/方案变更"类偏离："更新内容"代码块只给替换后的行/片段
> - 偏离总数 ≤ 3 时全部展开输出；> 3 时仅输出首条完整展开、其余折叠为摘要行

**用户决策**（使用 `ask_followup_question`，与偏离清单逐条对应）：

| 选项 | 说明 |
| --- | --- |
| 1️⃣ 一键应用所有变更 | AI 直接更新文档（推荐，偏离清单 ≤ 5 条时） |
| 2️⃣ 逐条确认 | 我逐条决定哪些更新、哪些跳过（偏离清单较多时） |
| 3️⃣ 仅生成报告 | AI 输出对账报告，我自己去 文档平台 手动更新 |
| 4️⃣ 跳过本次对账 | 本次不处理（输出原因到 `action_history`） |

##### 🔴 结构门控：文档平台 文档 vs 模板校验

> ⚠️ **强制执行**：文档平台 内容对账更新后，必须运行结构校验，不得跳过。

**1）读取更新后的 文档平台 文档内容**

```bash
cat << 'EOF' > /tmp/doc_platform_sync_lint.md
{更新后的完整 markdown 内容}
EOF
```

**2）运行结构校验**

```bash
bash ~/.codebuddy/skills/tech-doc/scripts/lints/doc-platform-lint.sh \
  --doc-type tech-proposal \
  /tmp/doc_platform_sync_lint.md
```

**3）处理校验结果**

| 退出码 | 处理 |
|:---:|------|
| `0` | ✅ 通过，继续后续步骤 |
| `1` | ⚠️ 有警告（如选填章节缺失），输出警告但不阻断 |
| `2` | 🔴 有错误（如表格列数不符、必需章节缺失、附录后还有内容） |

🔴 退出码 2 时，必须列出全部错误项并逐一修复后重新校验，直至通过。禁止跳过直接进入下一步骤。

**校验覆盖范围**（`doc-platform-lint.sh` 已实现）：
- 章节完整性（一～九 + 附录）
- 章节编号顺延（选填章删除后编号重新计算）
- 附录为最后一个章节（附录后不得有 H2 级标题）
- 表格列名与模板一致（如「代码归属模块」必须为 5 列：模块|页面名称|文件路径|核心代码|负责人）
- 需求背景表格含 任务平台 链接
- 页面功能表格含设计图列
- 无重复标题
- 无模板段落残留（如 `{测试用例链接}`）

设计原则：**结构性偏离是硬阻断，语义性偏离是警告**——表格列数错误比文案描述不精确影响更大。

**边界情况**：

| 场景 | 处理 |
| --- | --- |
| diff 为空 + 工作上下文无近期漂移 | 跳过对账，输出「无代码改动，文档无需对账」 |
| diff 为空 + 工作上下文有近期漂移 | 降级为工作上下文+文档平台 两方对账（以 ## 约束与决策 / ## 当前执行方案 为源） |
| 工作上下文缺失 | 仅基于 git diff + 文档平台 原文对账，输出「⚠️ 工作上下文缺失，决策原因可能不全」 |
| 文档平台 文档不存在 / 无权限 | 中止对账，输出错误提示，不阻塞收尾流程 |
| 远程主干分支检测失败（环节 A 第 0 步降级） | 跳过对账，输出「⚠️ 无法获取功能分支完整 diff，建议手动检查 文档平台」 |

#### H.4 任务平台 状态更新提醒（仅上线后 bugfix，收尾最后一步）

步骤 7 完成后（所有环节执行完毕、完成标记输出前），输出 任务平台 状态更新提醒：

```text
📋 任务平台 Bug #{bug_id} 当前状态：{current_status}
建议更新为：已解决 / 已修复
```

> 仅做提醒，由用户自行前往 任务平台 更新状态。
> `caller=full-7` 跳过环节 H 全部内容（推迟到步骤 10）。
> `caller=batch-7` 执行环节 H 精简版：
>
> - H.1 生成 Commit Message（必须，scope 包含 `[batch N/M]` 标识）
> - H.2 增量追加 devlog（追加 `### Batch N：{目标}（{日期}）` 段落，仅记录本批次改动摘要）
> - H.3 知识沉淀 → ❌ 跳过（推迟到最后一批统一沉淀）

### 环节 I：度量采集与数据驱动反思（`caller=standard-7` 必须）

> 标准执行的精简版数据驱动反思，与完整执行步骤 9 共享三层反思机制。
> **所有模式都必须执行度量数据采集与 YAML 写入**，确保每次需求完成都生成度量报告。

**执行顺序**（`caller=standard-7`）：

1. **度量数据采集与 YAML 写入**（对标步骤 9a，必须执行）：
   1. 读取工作上下文，提取：需求信息、约束与决策（统计 🔧 [纠正] 标记数）、回退记录、迭代轮次
   2. 按环节 A「第 0 步」检测远程主干分支后，
   执行 `git diff $(git merge-base $REMOTE_DEFAULT HEAD) HEAD --stat`
   获取**功能分支完整改动规模**（文件数、行数），
   确保度量数据反映本次需求的全部代码贡献而非仅最后未 commit 的残留；
   检测失败时降级为 `git diff HEAD --stat`（仅统计本地未提交改动）；
   **跨项目模式追加**：在每个改动项目的工作区逐个执行同一 diff 命令（先分支感知，遵循 `cross-project/integration.md` §Diff/Commit 查看规范），逐项目结果回写主项目工作上下文 `cross_project.projects_detail`（schema 见 `templates/working-context.tpl.md`），metrics yaml 中 `files_changed`/`lines_added`/`lines_deleted` 写所有改动项目的**汇总值**
   3. 从完成标记 JSON 中提取 L2 审查结果
   4. 估算对话轮次（`conversation_rounds`，近似值）
   5. 🔴 **判断 `requirement_type`**（Tier 2 推荐字段，必须写入，不可依赖兜底）：
      启发式判断规则（按优先级降序）：
      - ① 任务平台 类型：story → `feature`，bug → `bugfix`
      - ② `devlog_dir` 命名前缀：`_feat_` → `feature`，`_fix_` → `bugfix`，`_refactor_` → `refactor`，`_style_` → `style`
      - ③ 分支名前缀：`feature/` → `feature`，`bugfix/` → `bugfix`，`refactor/` → `refactor`
      - ④ 以上均无 → `feature`（兜底），但**仍必须写入字段**（不得省略留空依赖 normalize 默认值）
      写入枚举值：`feature` | `bugfix` | `refactor` | `style` | `other`
   5.5. 🔴 **从工作上下文提取 Tier 2 链接字段**（有则必填，不可省略）：
       - `task_id`：从 任务平台 查询结果或工作上下文获取（无 任务平台 时省略整个 key）
       - `task_url`：有 `task_id` 时从 任务平台 链接拼接或工作上下文提取（无则省略）
       - `doc_url`：从工作上下文 `doc_platform_tech_proposal.url` 提取（`docid` 非空时必填，否则省略）
       - `date` / `start_date` / `complete_date`：当天日期（ISO 格式 `YYYY-MM-DD`）
       - `iteration`：从工作上下文 YAML 头部读取（默认 1）
       - `knowledge_updated`：H.3 完成后设为 `true`
       - `devlog_generated`：H.2 devlog 落盘后设为 `true`
       > ⚠️ `task_url` 和 `doc_url` 是复盘报告 hero 链接按钮的数据源，缺失会导致按钮灰色禁用、不可点击。
       > 多次线上事故根因均为 AI 在写 YAML 时遗漏此步。本步骤 5.5 (2026-07-29) 即为堵漏措施。
   6. 计算标准化指标（`issues_per_file`、`bugs_per_100_lines`、`first_time_right`）
   7. 🔴 **红牌 #18：`requirement_id` 必须严格等于工作上下文文件名（不含 .md 扩展名），
      禁止使用 任务平台 ID、任务平台 短 ID 或任何其他标识符。**
      写入 `~/.codebuddy/.metrics/reports/{工作上下文文件名（不含 .md）}.yaml`
   8. 🔴 **写入后立即校验**：`bash ~/.codebuddy/skills/dev-flow/scripts/validate-metrics-yaml.sh <yaml文件>`，
      返回非 0 → 补齐后重试，禁止跳过。校验脚本对 `task_url` / `doc_url` 的缺失只会输出 ⚠️ 警告
      （Tier 2 字段，不阻断），AI **不得**因校验通过而忽略步骤 5.5 的提取要求。
   9. 更新 `~/.codebuddy/.metrics/summary.yaml` 汇总统计
2. **生成单需求 HTML 复盘报告并自动打开**（必须执行）：

    ```bash
    python3 ~/.codebuddy/skills/dev-flow/scripts/gen-flow-report.py "{工作上下文文件名（不含 .md）}"
    ```

    - 默认行为：生成 `~/.codebuddy/.metrics/flow-reports/{工作上下文文件名（不含 .md）}.html` 并自动 `open` 浏览器打开
    - 失败容忍：脚本异常仅打印 stderr，不阻断流程；完成标记中 `flow_report_generated: false` + `flow_report_error: <消息>`
    - 微修复（micro-fix）模式跳过本步骤（不采集度量，无源数据）
    - 详见 `references/metrics-rules.md` §「单需求 HTML 复盘报告」
3. **生成全局度量仪表盘并自动打开**（必须执行）：

    ```bash
    python3 ~/.codebuddy/skills/dev-flow/scripts/gen-dashboard.py
    ```

    - 默认行为：扫描全量 `reports/*.yaml`，重算 `summary.yaml`，生成 `~/.codebuddy/.metrics/dashboard.html` 并自动 `open` 浏览器打开
    - 失败容忍：脚本异常仅打印 stderr，不阻断流程；终端提示用户可手动执行 `dev:metrics --dashboard`
    - 详见 `references/metrics-rules.md` §「全局度量仪表盘」
    - 设计意图：收尾时主动刷新仪表盘，让用户看到本次需求完成后的全局趋势变化

    **3.1 回填 devlog 复盘报告链接**（HTML 均生成成功后必须执行，按 `devlog-rules.md` §「复盘报告链接联动」规范）：

    - 读取 `~/.codebuddy/dev-logs/{工作上下文文件名（不含 .md）}/devlog.md`
    - 在最末 Round 的「相关文档」段后追加：

      ```markdown
      #### 复盘报告
      - 📊 [完整复盘报告](file:///{HOME}/.codebuddy/.metrics/flow-reports/{工作上下文文件名（不含 .md）}.html) - 健康度评分 / KPI 对比 / 数据洞察 / 用户纠正记录 / 沉淀产出
      - 📈 [全局度量仪表盘](file:///{HOME}/.codebuddy/.metrics/dashboard.html) - 累计趋势 / 跨需求对比 / 项目分布
      ```

    - **强制要求**：
      - ✅ `{HOME}` 用 `echo $HOME` 取值，禁止硬编码 `/Users/xxx`，禁止留 `__HOME_DIR__` 占位符
      - ✅ HTML 文件不存在（脚本失败）→ 跳过追加，不写死链接
      - ✅ batch 中间批次跳过（HTML 仅最后一批生成）
      - ❌ 禁止重复追加（已有 `#### 复盘报告` 段落则更新而非追加）

4. **输出执行报告**：按 `references/metrics-rules.md` 报告模板输出可视化报告（含 HTML 报告路径提示）
5. **L1 即时反思**：按 `references/metrics-rules.md`「L1 即时反思」模板输出
6. **经验提炼**（精简版）：有高价值教训时写入规则/learnings，无则跳过
7. **L2 阶段报告**：满足条件时自动追加（与完整执行共享同一触发逻辑）

> ⚠️ **反思精简 ≠ 数据跳过**：步骤 5~7（执行报告、L1 反思、经验提炼、L2 阶段报告）在对话 Token > 50 轮时可精简为一行摘要（不再因"改动≤2文件"跳过）；步骤 1~3（yaml 落盘 + 复盘报告 + 仪表盘）**始终必须执行**，不受此限制。步骤 1 的产出 `reports/{工作上下文文件名（不含 .md）}.yaml` 若缺失，视为环节 I 未完成。

**与完整执行步骤 9 的差异**：

| 子环节 | 完整执行步骤 9 | 标准执行环节 I |
| --- | --- | --- |
| 度量数据采集 | 9a：独立采集 | ✅ 独立采集（与 9a 流程一致） |
| 单需求 HTML 报告 | 9a 第 6 步生成并打开 | ✅ 第 2 步生成并打开（与 9a 流程一致） |
| 全局度量仪表盘 | 9a 第 7 步生成并打开 | ✅ 第 3 步生成并打开（与 9a 流程一致） |
| 经验提炼 | 9b：深度提炼 | 精简版：仅提炼高价值经验 |
| 流程深度反思 | 9c：加载反思模板，多维度分析 | ❌ 跳过 |
| L1 即时反思 | 9d：完整输出 | ✅ 完整输出（与完整执行一致） |
| L2 阶段报告 | 自动追加 | ✅ 自动追加（共享触发逻辑） |

### 环节 K：dev-logs 完整性自检（`caller=standard-7` / `caller=batch-7` 强制）

> 🔴 **红牌 #17：禁用静默跳过** — 此环节在任何条件下不得以"改动简单""单文件"等理由跳过。
> AI 必须在 H 环节全部完成后、步骤 7 完成标记输出前**显式调用** `devlog-integrity-lint.sh` 并报告结果。

**执行**：

```bash
bash ~/.codebuddy/skills/dev-flow/scripts/lints/devlog-integrity-lint.sh --quiet
```

**退出码语义**：

- 0 → 全部通过 → `devlog_integrity_check: "clean"`
- 2 → 存在 ERROR（如 v3 后缺 plan.md/devlog.md）→ `devlog_integrity_check: "blocked_errors_N"` → 🔴 必须修复后重检
- 1 → 存在 WARN（如 v3 前历史产物缺失）→ `devlog_integrity_check: "warns_N"` → 记录但无需阻断

**与 plan.md 的关系**：如果 lint 报告缺 plan.md → 说明步骤 4 遗漏落盘 → 从工作上下文 `## 计划` 反推重建 plan.md → 重新跑 lint 直到通过。

> `caller=full-7` 跳过此环节（推迟到步骤 10）。

## 调用方 × 环节矩阵

| 环节 | `caller=standard-7` | `caller=full-7` | `caller=batch-7` | `caller=in-flow-sync` |
| --- | :---: | :---: | :---: | :---: |
| A. Diff 分析 | ✅ | ✅ | ✅ | ✅ |
| B. 清理调试代码 | ✅ | ✅ | ✅ | ❌ |
| C. 可选链检查 | ✅ | ✅ | ✅ | ❌ |
| D. 即时验证 | ✅ | ✅ | ✅ | ❌ |
| E. TODO 检查 | ✅ | ✅ | ✅ | ❌ |
| F. 改动汇总 | ✅ | ✅ | ✅ | ❌ |
| G. L2 审查 | ✅ | ✅（到此结束） | ✅ | ❌（重审太重） |
| H.0 CR 同步登记 | 🟢 自动 | 🟢 自动 | 🟢 自动 | ✅ 必须 |
| H. Commit+Devlog+Knowledge | ✅ | ❌（推迟步骤10） | ⚡ 精简版 | ⚡ 仅 H.2 devlog 增量+H.3 knowledge 漂移 |
| H.3+ 文档平台 兜底对账 | 🟢 docid 非空即触发¹ | ↩️ 推迟至 §10.3.5² | ❌ | 🟢 docid 非空即触发 |
| H.4 任务平台 状态提醒 | 🔴 仅上线后 bugfix | ❌ | ❌ | ❌ |
| I. 度量采集+反思 | ✅（必须） | ❌ | ❌ | 🔄 条件化³（仅在步骤 7/9 采集） |
| K. dev-logs 完整性自检 | ✅（强制，不可跳过） | ↩️ 推迟至步骤 10 | ✅ | ❌（不生成 commit，K 无前提） |
| | | | | |
| **流程结束** | 删除 .flow / `done` | 转步骤 8 | 转 batch_next | 恢复 `current_step={原步骤号}` 继续原任务 |

> ¹ **docid 非空即触发** = 工作上下文 `doc_platform_tech_proposal.docid` 非空就执行兜底对账
> （基于 git diff master..HEAD + 工作上下文 + 文档平台 原文三方对账，结果必须通过 §H.3+ 结构校验门控方可继续）。
> 不再区分「上线后 bugfix / 提测后迭代修复 / status=outdated」等场景。
> 详见 §H.3+ 与 `tech-doc/modules/doc-platform-doc.md` §「兜底对账子流程」。
>
> ² **完整执行推迟到步骤 10.3.5** = `caller=full-7` 在步骤 7 跳过 H.3+，
> 由 `steps/step-8-10-full.md §10.3.5「技术方案文档兜底对账」`（`caller=full-10`）承接，
> 与本环节共用同一套兜底对账子流程实现，确保标准/完整两类流程对账精度一致。
> 设计意图：完整模式下 commit/devlog/knowledge 都推迟到步骤 10，
> 文档平台 同步亦保持一致节奏，让最终归档前的代码状态作为唯一对账基准。
> ³ **in-flow-sync I 度量条件化** = `caller=in-flow-sync` 不再无条件跳过度量采集。
> 流程进行中（`.flow` 存在 + `current_step` 非 done）→ ❌ 跳过（后续步骤 7/9 采集）；
> 流程已完成（`status: completed/done`）+ `report.yaml` 存在 + 代码有增量 → ✅ 增量刷新。
> 详细判定表见 `in-flow-sync.md` §步骤 4a。

## 步骤完成钩子（通用）

每个环节完成后，**必须立即**执行状态同步（按 step-router.md 动作2 原子操作）：

- 更新工作上下文步骤清单中对应行的状态/时间/备注
- 更新当前状态和恢复指令
- 同步 `.active-flows/` 目录下对应需求的 `.flow` 文件

**最终环节完成后**（环节 H 或环节 I）：

- `caller=standard-7`：🔴 **产物质检**：确认 `~/.codebuddy/.metrics/reports/{工作上下文文件名（不含 .md）}.yaml` 存在（环节 I 步骤 1 产出）。缺失时阻断，回溯执行环节 I 步骤 1~3（yaml 采集 + 复盘报告 + 仪表盘）。通过后方可删除 `.flow` 文件（流程结束）
- `caller=full-7`：更新 `.flow` 文件步骤号为 8（继续完整执行后续步骤）
- `caller=batch-7`：更新 `.flow` 文件步骤号为 `batch_next`，更新工作上下文 `current_batch` + 批次进度表格（不删除 `.flow` 文件）
