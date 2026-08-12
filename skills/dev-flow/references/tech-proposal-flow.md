# 技术方案文档生成/更新

> 本文件由步骤 4 · 文档决策（环节 3/4） 的 文档平台 硬性决策环节按需加载。**核心原则**：decision 非 `skip` 时加载执行；`skip` 时不加载。

## 触发方式（硬性决策产物）

步骤 4 · 文档决策（环节 3/4） 的 文档决策直接决定本文件是否加载和加载后的执行路径：

| `doc_platform_tech_proposal.action` | 加载本文件？ | 执行路径 |
| --- | --- | --- |
| `create` | ✅ 加载 | 新建流程（doc-platform-doc 模式 A） |
| `update` | ✅ 加载 | 更新流程（doc-platform-doc 模式 A 更新子流程 / 模式 C） |
| `relink` | ❌ 不加载 | 仅读取文档获取 `locked_title` 后回写工作上下文（由 step-4-decision 内联处理） |
| `skip` | ❌ 不加载 | 本轮完全跳过 文档平台 |
| `auto_inherited_skip` | ❌ 不加载 | 迭代修复继承首轮 skip，本轮跳过 |

## 前置检查：文档平台 空间探测结果

步骤 4 · 文档决策（环节 3/4） 已完成探测并将结果写入工作上下文 YAML `doc_platform_space_probe`。本文件直接读取该字段，**不重复探测**。

探测协议详见 `steps/step-4-decision.md` §3.1「文档平台 空间探测协议」。

### 决策与流程的映射

| action | probe_layer | candidates | 对应流程 |
| --- | --- | --- | --- |
| `create` | no_match / failed | 空 | 新建流程：按模板生成并发布 |
| `create` | matched | 非空 | 新建流程（用户拒绝了已有文档，选择重新创建） |
| `update` | from_local | 来自本地记录 | 更新流程：已有文档直接进入 |
| `update` | matched | 强/中匹配 | 更新流程：使用候选文档 |
| `relink` | any | any | 读取文档获取 locked_title → 写入工作上下文（本文件不执行） |

## 新建流程（action=create）

1. 调用 `use_skill('tech-doc')`（路由到 doc-platform-doc 模块，进入模式 A：从工作上下文提取信息）
2. **人员信息完整性校验**：查询 任务平台 后，校验必填人员角色（产品、后台开发、PM、测试、前端开发）是否齐全。缺失时汇总报告给用户补充，**补充完整后才继续生成文档**。详见 doc-platform-doc 模块「关键人员信息校验规范」
3. 按模板生成 Markdown 预览，**必须使用 `ask_followup_question` 弹出交互式选项**让用户确认：

```text
技术方案文档预览完毕，请选择：

```

| 选项 | 说明 |
| --- | --- |
| ✅ 发布 | 确认内容无误，保存文档 |
| ✏️ 修改 | 告诉我需要调整的内容 |
| ⏭️ 跳过 | 本次不生成文档，直接进入步骤 4.5 |

1. 用户选「发布」→ 保存文档到本地或平台
2. **回写工作上下文 YAML**（关键，不可省略）：

- `doc_platform_tech_proposal.file_path` / `locked_title` 填充
- `status: synced`，`last_synced_at` 刷新
- `action_history` 追加 `action: created, user_choice: explicit_create, at: {now}, iteration: {current}` 条目

1. 用户选「修改」→ 接收修改意见 → 更新文档 → 再次弹出选项
2. 用户选「跳过」→ 更新 `doc_platform_tech_proposal.status = "skipped"`，`action_history` 追加 `action: skipped, user_choice: explicit_skip` 条目

## 更新流程（action=update）

已有 技术方案文档时，**不重新生成**，而是基于本轮方案变更进行增量更新：

1. 通过工作上下文中的文档记录获取当前文档全文
2. **读取并校验 `locked_title`**：对比文档标题与 `locked_title`，不一致则告警（可能有人改过标题）
3. **人员信息完整性校验**：检查已有文档中的必填人员角色是否齐全，如有缺失一并纳入变更清单
4. 对比当前文档内容与本轮工作上下文中的方案/计划/范围变更，**汇总整理出需要更新/调整/补充的内容**
5. 按章节逐条列出变更清单，每条包含：

- 所在章节
- 当前内容（原文片段）
- 建议更新为（新内容片段）
- 变更原因

1. **必须使用 `ask_followup_question` 弹出交互式选项**让用户决策更新方式：

```text
已有 技术方案文档文档，以下是本轮需要更新的内容汇总。请选择更新方式：

```

| 选项 | 说明 |
| --- | --- |
| 🤖 AI 直接更新 | 由我直接将变更内容更新到文档 |
| 📋 我自己更新 | 我参考以上汇总内容，自行更新 |
| ✏️ 调整变更内容 | 告诉我需要调整的变更项 |
| ⏭️ 跳过 | 本次不更新文档，直接进入步骤 4.5 |

1. 用户选「AI 直接更新」→ 调用 `use_skill('tech-doc')`（路由到 doc-platform-doc 模块模式 C 方案 A），直接更新文档
2. **回写工作上下文 YAML**（AI 直接更新成功时）：

- `last_synced_at` 刷新
- `action_history` 追加 `action: updated, user_choice: explicit_update, at: {now}, iteration: {current}, snapshot_sha: {sha256前6位}` 条目

1. 用户选「我自己更新」→ 用户自行处理，直接进入步骤 4.5 / 步骤 5（`action_history` 不追加，因为本轮 AI 未执行更新）
2. 用户选「调整变更内容」→ 接收修改意见 → 更新变更清单 → 再次弹出选项
3. 用户选「跳过」→ 更新 `doc_platform_tech_proposal.status = "outdated"`（提醒后续步骤 7/10 兜底处理）

> ⚠️ **注意**：更新流程中，未涉及变更的章节必须保持原文不动，严禁全文重写。
> ⚠️ **标题保护**：更新文档时 title 必须等于 `locked_title`，原样回传，禁止 AI 自行优化标题格式。

## 关联流程（action=relink，本文件不完整加载）

当用户在阶段 3 选择"🔗 关联该文档"/"🔗 关联已有文档"/"🔗 指定其他链接"时：

1. **不加载本文件**，由 `step-4-decision.md` 内联处理
2. 内联步骤：

- 读取文档获取当前 `title`
- 写入工作上下文 YAML `doc_platform_tech_proposal`：
- `file_path` / `locked_title` 填充
- `status: synced`（视为已关联状态）
- `action_history` 追加 `action: relinked, user_choice: explicit_relink, at: {now}` 条目

1. 本轮不执行任何 文档平台 写入操作，只建立关联

## 跳过流程（action=skip / auto_inherited_skip，本文件不加载）

- `action=skip`：用户显式选择"⏭️ 本次不处理"
- `doc_platform_tech_proposal.status = "skipped"`
- `action_history` 追加 `action: skipped, user_choice: explicit_skip` 条目
- `action=auto_inherited_skip`：迭代修复场景自动继承首轮 skip
- `action_history` 追加 `action: skipped, user_choice: auto_inherited` 条目

**后续步骤 5/5.5/6 都不触发 文档平台 同步**；步骤 7 / 步骤 10.3.5 由 closeout-flow §H.3+ / step-8-10-full §10.3.5 兜底对账子流程统一处理
（触发条件仅一条：`doc_platform_tech_proposal.file_path` 非空，与 `status == "outdated"` 解耦）。

## 执行方式

- **新建**（`create`）：调用 `use_skill('tech-doc')`（路由到 doc-platform-doc 模块模式 A），在 dev-flow 上下文中自动填充生成
- **更新**（`update`）：调用 `use_skill('tech-doc')`（路由到 doc-platform-doc 模块模式 C），基于已有文档增量更新

## 排版要求

tech-doc Skill 内置了完整的排版格式规范（空格规则、行内代码、标点符号、Mermaid 图表、专有名词大小写等），生成/更新文档时自动遵守，发布前执行自检清单。
