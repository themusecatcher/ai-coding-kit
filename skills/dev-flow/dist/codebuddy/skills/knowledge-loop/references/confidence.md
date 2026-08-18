# 置信度体系与代码漂移检测

> 按需加载：检索时发现疑似漂移 / 沉淀时更新置信度 / 健康检查时。

## 核心设计原则

- **职责单一**：`confidence` 只表达"代码位置对不对"；业务验证信息（是否上线、是否经生产验证）用独立维度 `release` 表达；漂移与稳定性指标用独立维度 `stability` 表达。
- **AI 决策优先**：级别的差异必须映射到不同的 AI 行为，否则不设级别。
- **分支感知**：沉淀级别区分"本地 feature 分支"与"已合入 base 分支"。

---

## 置信度级别（5 级）

每个主题文件在 frontmatter 中标记置信度：

| 级别 | 含义 | 来源 | AI 行为 |
|------|------|------|---------|
| `draft` ⚫ | 草稿/初次记录 | 手动临时补充 | 仅作参考，加载时提示二次确认 |
| `scanned` ⚪ | 自动扫描提取 | `dev:kb scan` / 远程知识反哺（知识库平台/wiki / doc_platform / web_search） | 低置信度，加载时提示“自动提取，建议验证”；**在步骤 1 多源仲裁中可被自动升级为 `auto-verified` 或降为 `auto-stale`**（详见下文§scanned 自动升级规则） |
| `pending` 🟡 | 本地 feature 分支沉淀 | dev-flow 步骤 7/10 在 feature 分支上沉淀 | **仅本分支生效**；跨分支不采纳；`git pull` 后合入 base 分支自动升级为 `verified` |
| `verified` 🔵 | 已合入 base 分支，跨分支可信 | `dev:kb sync` 识别到 feature 合入 / 用户确认 / base 分支上沉淀 | 直接采纳，排序优先 |
| `stale` 🔴 | 漂移状态，代码已变更但知识未更新 | 漂移检测 / **`dev:kb sync` 检测到他人改动** | **不采纳**，加载时警告并提示重新验证 |

> `deprecated` 不是置信度级别，而是生命周期状态（模块废弃时使用），详见 `lifecycle.md`。

### 为什么没有 `production_verified`

"是否上线验证"不属于 `confidence` 的职责——confidence 回答"代码位置对不对"，"上线验证"回答"这条知识在生产环境稳不稳"，两者是正交维度，应独立表达（见下方 `release` 字段）。

---

## 独立维度：release（业务验证信息）

表达"这条知识对应的代码是否已上线/经过生产验证"，与 `confidence` 正交。

```yaml
release:
  released: true              # 是否已上线（默认 false）
  released_at: "2026-04-20"   # 上线日期（可选）
  verified_in_production: true # 是否有真实生产环境证据（默认 false）
  evidence:                   # 生产验证证据（可选数组）
    - type: bugfix            # bugfix/feature_release/user_confirmed
      ref: "bugfix/xxxxx"     # commit / MR / 任务平台 ID
      note: "线上 bugfix 验证通过"
```

### 字段填充规则

- `released` 默认 `false`，只有以下情况设为 `true`：
  - 用户显式执行 `dev:kb mark-release`
  - 沉淀时用户在交互中确认"本次改动已上线"（沉淀模式会询问）
  - 未来接入 CI/CD 事件时自动标记
- ❌ **禁止**仅凭"合入 master N 天无变更"就自动标记 `released=true`（时间推算不等于上线验证）

---

## 独立维度：stability（稳定性与漂移指标）

自动维护，用于排序加权与健康检查。

```yaml
stability:
  last_verified: "2026-04-18" # 最近一次验证通过的时间
  drift_count: 0              # 历史漂移累计次数（被检测到漂移的次数）
  days_since_merge: 30        # 合入 base 分支后经过的天数（verified 级别才有意义）
  confidence_score: 95        # 0-100 综合分数（由 AI/脚本根据级别+漂移+时间综合计算）
```

### confidence_score 计算约定（参考）

```
base = {draft: 20, scanned: 40, pending: 70, verified: 85, stale: 0}[confidence]
# auto-verified 仅次于人工 verified，调低 -5；auto-stale 与 stale 同为 0
base += (confidence == "auto-verified" ? 80 - 85 : 0)   # 仅作说明，实际可以 base = 80
bonus = (release.released ? +5 : 0)
      + (release.verified_in_production ? +10 : 0)
      + (drift_count == 0 ? +5 : -5 * drift_count)
      + (days_since_merge >= 30 ? +3 : 0)
confidence_score = clamp(base + bonus, 0, 100)
```

> 该分数供 AI 在同级别内做细粒度排序使用，非级别替代品。

---

## AI 检索时的排序策略

检索模式下，按以下优先级综合排序：

```
1) confidence 级别：verified > auto-verified > pending(仅本分支) > scanned > draft；stale / auto-stale 不采纳
2) 同级别内按 confidence_score 倒序
3) release.verified_in_production 为 true 的条目在同分数下优先
4) 跨分支场景：pending 条目只有在"当前分支 == 该知识创建分支"时才参与排序，否则完全不展示
5) auto-verified 被检索命中时会重置存活时间（推迟 90 天衰减）
```

---

## scanned 自动升级规则（混合策略）

> 针对 P3 类远程知识（知识库平台/wiki / doc_platform / web_search）反哺产生的 `scanned` 条目，在**步骤 1 多源仲裁阶段**并调用本规则 → **默认 AI 自动升级不打断用户** + **异步审计补足信任**。整体走「严格条件自动 + 异步审计 + 90 天衰减」三重防护。

### 升级决策矩阵

| 远程条目情形 | 自动行为 | confidence 变化 |
|------------|---------|-----------------|
| 找到对应代码符号（`codebase_search` 能定位到函数/类/常量） + 内容与代码**一致** | 自动升级 | `scanned` → `auto-verified` |
| 找到对应代码符号 + 内容与代码**不一致** | 自动标记 + 附 diff 摘要 | `scanned` → `auto-stale` |
| 找不到对应代码符号（仅 wiki 提及，代码未实现） | 不升级 | 保留 `scanned` |
| 句式包含「未来/将要/规划/计划/探索」等词 | **强制**保留不升级 | 保留 `scanned` |
| 版本标识与代码 changelog 不一致（如 wiki 描述 v2，代码仍 v1）| 自动标记 | `scanned` → `auto-stale` |
| 遇到 P0 代码事实冲突 | 强制降级 | `auto-verified` → `auto-stale` |

### auto-verified / auto-stale 子状态语义

- **`auto-verified`**：代码佐证通过的机器升级。与人工 `verified` 区分，供审计与衰减使用。排序上仅次于人工 `verified`（同级接近 verified，但在 `confidence_score` 上 -5 调节）。
- **`auto-stale`**：代码佐证发现不一致的机器标记。与未升级的 `stale` 同为不采纳状态，但保留原始 wiki 摘要供设计意图参考。
- 二者均在 frontmatter 的 `confidence` 字段中完整保留字面值（「`auto-verified`」「`auto-stale`」），**不拆为 `confidence + auto: true` 两个字段**，避免与现有 schema 冲突。

### auto-verified 专属字段

```yaml
auto_upgrade:
  upgraded_at: YYYY-MM-DD            # 本次自动升级时间
  upgraded_by: step-1-arbitration    # 触发源：step-1-arbitration / dev:kb-sync / dev:kb-scan
  code_anchor: "src/x.ts::foo"        # 佐证使用的代码锚点（函数/类/常量完全限定名）
  source_ref: "知识库平台/wiki/..."     # 原始 wiki / doc_platform / mr 引用
  ttl_days: 90                        # 默认 90 天未被检索命中 → 衰减为 archived
```

### 严格自动升级门控

同时满足**以下全部**才能升级为 `auto-verified`：

1. 必须找到代码锚点（`code_anchor` 不能为空）——仅文字匹配不够
2. 不存在「未来/规划/将要」句式
3. 版本标识（如有）与代码 changelog 一致
4. 未与 P0 事实发生冲突

任一不满足 → 保留 `scanned` 或标为 `auto-stale`。

#### 反模式（常见误判）

以下场景看似应该升级但**禁止**升级为 `auto-verified`：

- “本文档将于 {未来日期} 更新”“下一期考虑”“后续路线图”——是规划表述不是事实
- 代码中只有同名函数但参数/返回值与 wiki 描述不同——需标 `auto-stale` 而非 `auto-verified`
- wiki 在「背景/动机」中提及某机制，但「实现」章节明确说「未实现」——保留 `scanned`
- 代码锚点是测试文件中的 mock 而非生产代码——不足以佐证，保留 `scanned`

### 异步审计与反悔机制

- 用户在任何时机可运行 `dev:kb audit` 查看 auto-verified / auto-stale 全量（默认仅展示 auto-stale）
- 用户可对单条执行 `reject` / `confirm`：
  - `reject` → 状态回退为 `scanned`，并记录 `auto_upgrade.rejected_at`，后续不再重复升级同一条目
  - `confirm` → 状态提升为人工 `verified`
- 步骤 1 仲裁冲突时，本轮打包输出「本次自动升级 X 条 / 标 stale Y 条 / 未确认 Z 条」（详见 `dev-flow/steps/step-1-research.md` § 多源仲裁与升级摘要）。

### 90 天衰减与归档

- `auto-verified` 状态存活超过 `auto_upgrade.ttl_days`（默认 90 天）**且未被检索命中**（检索心跳仅仅踩到会重置存活时间） → 衰减为 `archived`（不在检索中采纳，仅可达 `dev:kb audit --archived` 查看）
- 衰减不会删除原始文件，仅修改 frontmatter。重新被检索命中时手动重新扫描验证后可恢复。
- `dev:kb sync` / `dev:kb verify` 中包含「衰减检查」环节，由调度时查询 `auto_upgrade.upgraded_at`。

### 价值与限制

- 价值：在不打断用户节奏的前提下提高 design-intent.md 的可用信任度；同时保留「衰减与反悔」阅门，避免 AI 误判被长期锁定。
- 限制：auto-verified 不能被作为 P1 仲裁依据使用（只能类同 P3）——仅表示「远程知识与代码一致」，不等同于「用户验证」。

---

## 代码漂移检测

### 触发时机

- 步骤 1 加载知识时（检索模式）
- 步骤 7/10 沉淀前（沉淀模式）
- `dev:kb verify` / `dev:kb sync` 命令（管理模式）
- `dev:kb health` 健康检查（管理模式）

### 检测逻辑

1. 读取 `_overview.md` 中的核心文件列表（或主题文件顶部的 `code_anchors` 字段）
2. 对每个核心文件：获取 git 最后修改时间 vs `stability.last_verified`
3. 文件修改时间 > stability.last_verified → 标记可能漂移
4. 发现不一致 → 置信度降级为 `stale` + `drift_count += 1` + 输出提醒

> 只做时间戳比较 + 关键词存在性检查，不做全文 diff，控制性能。

### 自动刷新 stability.last_verified

以下场景自动刷新：

- 被动沉淀更新了内容
- 主动扫描确认无变化
- 用户手动验证（`dev:kb verify`）
- 步骤 1 加载后 AI 确认一致

### stale 恢复路径

| 当前状态 | 恢复动作 | 恢复后级别 |
|---------|---------|-----------|
| stale（原 verified） | 用户确认/重新沉淀 | verified |
| stale（原 pending） | 在原创建分支上重新沉淀 | pending |
| stale（原 scanned） | 重新扫描 | scanned |

---

## 相关命令

| 命令 | 作用 |
|------|------|
| `dev:kb sync` | `git pull` 后一键对齐知识库（处理两类场景）：<br>① **场景 A**：他人代码合入 master 后，检测我已有的 `verified` 知识是否过期 → 降 `stale` + 增量重扫<br>② **场景 B**：我的 feature 分支被合入 master 后，把我之前沉淀的 `pending` 自动升级为 `verified`<br>详细流程见 `modes/manage.md` § dev:kb sync |
| `dev:kb verify` | 手动验证并刷新 stability.last_verified |
| `dev:kb audit` | 查看 auto-verified / auto-stale 条目清单（默认仅展 auto-stale），支持 `--all` 全量、`--archived` 查看已衰减、`--reject <id>` 单条回退、`--confirm <id>` 提升为人工 verified |
| `dev:kb mark-release` | 标记 release 字段（不改变 confidence 级别）|
| `dev:kb health` | 输出置信度分布、漂移条目、过期提醒 |
