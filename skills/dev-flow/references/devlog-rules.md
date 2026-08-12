# 开发日志规范

每次需求开发或 Bug 修复完成后，自动生成开发日志。

## 触发规则

| 模式 | 触发点 |
| --- | --- |
| 完整执行 | 步骤 10（归档与交付） |
| 标准执行 | 步骤 7（commit 前） |
| 批次执行（非最后一批） | 步骤 7（`caller=batch-7`，增量追加 Batch Round） |

**统一完整版**：所有模式均生成完整版开发日志（What/Why/How/Issues/Result/相关文档 六段全填），不区分精简版。开发日志最终只有一份，越详细越有价值。

**生成时**：调用 `use_skill('tech-doc')`（路由到 devlog 模块）加载完整模板和规则。

**⚠️ 增量追加规则**：当 devlog.md 已存在时，**禁止跳过生成，禁止覆盖**——
必须在 `## How` 章节末尾追加 `### Round N：{修复描述}（{日期}）` 子段，
并同步更新 `## Issues` 和 `## Result` 清单。详见 devlog 模块「六、增量追加规则」。

## 防跳过声明（硬性规则）

devlog 是每次需求开发/Bug 修复的**必须产出物**，与 Commit Message 同等优先级。

- ❌ 禁止以"改动量小"/"无复杂架构决策"/"标准功能新增"等理由跳过
- ❌ 禁止引入"评估是否需要 devlog"的判断环节——到了触发点就必须生成
- ❌ 禁止将知识沉淀的可选属性泛化到 devlog（knowledge 的沉淀内容可按场景调整，但 devlog 无条件执行）
- ✅ 到了触发点（完整执行步骤 10 / 标准执行步骤 7），devlog 就是必须生成的
- ✅ 完成标记 JSON 中 `devlog_generated` 必须为 `true`（批次执行非最后一批允许为 `"batch_partial"`），否则视为步骤未完成

## 告警排查索引联动

devlog 生成后必须同步追加告警排查索引（`~/.codebuddy/dev-logs/impact-index.md`）。
详细规则见 devlog 模块（`tech-doc/modules/devlog.md`）「七、告警排查索引追加」章节。

- ✅ devlog 生成 = 索引追加，两者绑定执行，禁止跳过
- ✅ 索引字段提取规则见相关索引管理模块

## 度量摘要联动

devlog 的最终 Round 记录末尾自动嵌入度量摘要（由 `metrics-rules.md`「与 devlog 联动」章节定义）：

```markdown

#### 度量摘要
- 模式：{标准/完整/收尾}执行 | 改动：{N} 文件 +{A}/-{D} 行 | 一次做对：{✅/❌}
- 质量：回退 {N} 次 | L2 问题/文件 {N} | 验证 bug {N}

```

- ✅ 度量摘要在度量采集完成后自动追加到 devlog 最后一个 Round 记录末尾
- ✅ 批次模式下仅在最后一批的 Round 记录末尾追加（与告警索引同步）
- ❌ 禁止在度量数据未采集时编造摘要数据

## 复盘报告链接联动（P1，2026-06-02）

度量摘要写入后，立即在**同一 Round 记录末尾**追加「复盘报告」链接区块：

```markdown

#### 复盘报告
- 📊 [完整复盘报告](file:///{HOME 绝对路径}/.codebuddy/.metrics/flow-reports/{需求ID}.html) - 健康度评分 / KPI 对比 / 数据洞察 / 用户纠正记录 / 沉淀产出
- 📈 [全局度量仪表盘](file:///{HOME 绝对路径}/.codebuddy/.metrics/dashboard.html) - 累计趋势 / 跨需求对比 / 项目分布

```

**生成约定**：

- ✅ `{HOME 绝对路径}` 必须由 AI 替换为真实主目录（如 `$HOME`），可执行 `echo $HOME` 取值；禁止把 `__HOME_DIR__` 等占位符直接输出到 devlog
- ✅ `{需求ID}` 使用工作上下文文件名（不含扩展名），与 reports/{需求ID}.yaml 严格一致
- ✅ 仅在 standard / full 模式追加（micro-fix 不生成复盘报告，故跳过此区块）
- ✅ 批次模式仅在最后一批追加（中间批次无独立复盘报告）
- ❌ 禁止编造路径：必须先确认 `~/.codebuddy/.metrics/flow-reports/{需求ID}.html` 真实存在（由 dev-flow 收尾环节 I / 步骤 9a 自动生成）

**模式适用矩阵**：

| 模式 | 复盘报告链接区块 | 说明 |
| --- | :---: | --- |
| standard | ✅ | 步骤 7 环节 I 生成 HTML 后，devlog 同步追加 |
| full | ✅ | 步骤 9a 生成 HTML 后，步骤 10.4 devlog 写入时追加 |
| batch（中间批次） | ❌ | 无 HTML 报告 |
| batch（最后一批） | ✅ | 自动切换为 standard/full 流程 |
| micro-fix | ❌ | 不采集 metrics，无 HTML 报告 |

## 批次模式下的 devlog 规则

批次模式下，devlog 遵循「增量追加」而非「跳过」，确保不违反防跳过声明：

| 批次 | devlog 行为 | `devlog_generated` 值 |
| --- | --- | --- |
| 非最后一批 | 追加 Batch Round 段落 | `"batch_partial"` |
| 最后一批 | 完整生成/更新六段 | `true` |

### 非最后一批的 devlog 追加格式

在 `## How` 章节末尾追加：

```markdown

### Batch N：{批次目标}（{日期}）

- **范围**：计划步骤 #X~#Y，涉及 {文件列表}
- **改动摘要**：{本批次核心改动的一句话描述}
- **Commit**：`{commit hash 前 7 位}`

```

> 📌 「涉及 {文件列表}」按 AI 行为规范「文件/代码位置引用」渲染为反引号包裹相对路径（`` `相对路径` ``），IDE 自动识别为可点击链接；devlog 归档后在 CodeBuddy/VSCode 内仍可点击跳转。

### 最后一批的 devlog 行为

- 补全 What/Why/How/Issues/Result/相关文档 六段
- How 章节保留之前各批次的 Batch Round 记录，在末尾追加最后一批的 Round
- Issues 和 Result 汇总所有批次的问题和结果

> 这不是「跳过」devlog，而是「分段写入」——每批次写入一段，最后一批汇总完善。
> 告警排查索引仅在最后一批完成时追加（覆盖所有批次的改动）。

---

## dev-logs 目录命名反例（被 step-4-decision.md §4.2 引用）

> 📌 完整命名格式权威源：`skills/tech-doc/modules/devlog.md` §一。本节列出 dev-flow 步骤 4 创建目录时常见的反例，便于 AI 一次性看完踩坑点。

| 反例 | 违反规则 | 正确做法 |
| --- | --- | --- |
| `20260422_fix_form-submit-failed` | 简述纯英文，违反中文规范 | `20260422_fix_表单提交失败` |
| `20260421_fix_comment-sort-feature_my-project` | 纯英文简述 + 项目缩写后缀 | `20260421_fix_评论排序功能_App`（项目缩写若需带，应作为简述的英文术语，而不是 `_xxx` 后缀） |
| `20260401_config-toggle_my-project` | 缺 `_类型_` 段 + 英文简述 + 项目后缀 | `20260401_feat_配置开关优化` |
| `20260422_feat_list batch export` | 简述含空格（不允许） | `20260422_feat_列表批量导出` |
| `20260422_FIX_xxx` / `20260422_新功能_xxx` | 类型段必须是小写英文枚举 `feat/fix/opt/refactor` | `20260422_fix_xxx` / `20260422_feat_xxx` |

**自检要点**（与 `scripts/lints/devlog-dir-name-lint.sh` 4 项对齐）：

1. `format_matched`：整体匹配 `^\d{8}_[a-z]+_.+$`
2. `type_valid`：第二段 ∈ `feat | fix | opt | refactor`
3. `brief_has_chinese`：简述段含中文字符（≥1 个汉字）
4. `no_project_suffix`：简述段末尾不应是 `_项目缩写` 形态（如 `_App`、`_crossProject` 单独作为后缀视为违规，但 `App地区页` 这种"嵌入简述"是允许的）

> ⚠️ 与 working-context 文件名格式严格区分：working-context 用英文短横线 + 项目缩写后缀，dev-logs 目录用中文 + 类型段。两者不可机械替换。
