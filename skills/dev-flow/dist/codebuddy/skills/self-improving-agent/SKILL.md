---
name: self-improving-agent
description: "经验回顾与规则质量管理。提供三大能力：(1) 任务前经验回顾——从 .learnings/ 和规则文件中检索相关经验；(2) 规则质量审计——检测规则冲突/过时/重复；(3) 学习记录管理——查询/清理/promote .learnings/ 条目到规则。适用于 dev-flow 步骤 9 调用、用户主动请求回顾/审计、日常对话中检测到可改进模式。"
keywords: ["经验回顾", "规则审计", "自我改进", "learnings管理", "规则质量", "self-improving-agent"]
---

# Self-Improving Agent

> 经验回顾与规则质量管理系统。聚焦三个可落地的能力，不依赖外部 hooks。

## 职责边界

```
红线规范（alwaysApply，每次对话自动生效）
  └── 基础自我改进：用户纠正→create_rule、3次提升为规则、首次约定写规则

continuous-learning-v2（dev-flow 步骤 9 调用）
  └── 深度反思：原子本能提取、置信度评分、本能演化为技能

self-improving-agent（本 Skill）
  └── 经验管理：任务前回顾、规则审计、.learnings/ 记录的生命周期管理
```

**不做的事**：不重复红线规范已覆盖的自动触发逻辑；不重复 continuous-learning-v2 的本能提取和演化流程。

## 触发场景

| 场景 | 触发方式 |
|------|---------|
| 开始复杂任务前回顾相关经验 | dev-flow 步骤 1 自动调用，或用户说"回顾经验" |
| dev-flow 步骤 9 反思阶段 | dev-flow 自动调用 |
| 用户请求审计规则质量 | 用户说"审计规则"/"检查规则冲突" |
| 用户请求管理学习记录 | 用户说"查看学习记录"/"清理 learnings"/"promote 学习" |

## 能力一：任务前经验回顾

在开始复杂任务前，检索相关历史经验，避免重蹈覆辙。

### 回顾流程

1. **提取任务关键词**：从当前任务描述中提取技术领域、模块名、问题类型等关键词
2. **检索 `.learnings/`**：在 `~/.codebuddy/.learnings/` 下搜索匹配条目
3. **检索规则文件**：在 `~/.codebuddy/rules/` 下搜索相关规则
4. **输出回顾摘要**：

```
📋 经验回顾（与当前任务相关）：
- [LRN-xxx] {摘要} → 建议：{行动}
- [RULE] {规则名} → 要点：{核心内容}
- 无相关历史经验 ✅
```

### 回顾时机判断

| 任务复杂度 | 是否回顾 |
|-----------|---------|
| 简单修改（改文案/删 console.log） | 跳过 |
| 中等任务（样式调整/小功能） | 快速检索，有则展示 |
| 复杂任务（新需求/跨模块/不熟悉领域） | 必须回顾 |

## 能力二：规则质量审计

检测已有规则中的问题，保持规则库健康。

### 审计维度

| 维度 | 检测内容 | 处理建议 |
|------|---------|---------|
| **冲突** | 两条规则给出相反指导 | 合并或标注优先级 |
| **重复** | 多条规则描述同一件事 | 合并为一条 |
| **过时** | 规则引用的 API/模式已不再使用 | 标记废弃或更新 |
| **覆盖度** | 重要领域缺少规则 | 建议补充 |

### 审计流程

1. 读取 `~/.codebuddy/rules/` 下所有规则文件
2. 读取 `.learnings/LEARNINGS.md` 中的 promoted 条目
3. 逐维度扫描，输出审计报告：

```
🔍 规则审计报告：
- ⚠️ 冲突：rule-A 与 rule-B 在 xxx 场景下矛盾
- 🔄 重复：rule-C 和 rule-D 描述相同内容，建议合并
- 📅 过时：rule-E 引用的 API 已废弃
- ✅ 无问题的规则：N 条
```

4. 用户确认后执行修复

## 能力三：学习记录管理

管理 `.learnings/` 目录的完整生命周期。

### 存储位置（固定）

```
~/.codebuddy/.learnings/
├── LEARNINGS.md    # 学习记录（纠正、经验）
├── ERRORS.md       # 错误记录（命令失败、异常）
└── FEATURE_REQUESTS.md  # 功能请求记录
```

### 操作命令

| 操作 | 说明 |
|------|------|
| **查看** | 列出所有条目，按状态/优先级/时间筛选 |
| **清理** | 删除已 promoted 或过期（>90 天未更新）的条目 |
| **promote** | 将高价值条目提升为规则（`create_rule`） |
| **统计** | 输出学习记录概览（总数、各状态/类型分布） |

### 写入前去重协议（模式识别核心机制）

> 借鉴 MemPalace Agent Diary 的模式识别能力。每次写入新 learning 前，必须先检查是否已有同类条目，避免 Recurrence-Count 永远为 1。

**写入新 learning 前的强制流程**：

1. **提取新条目的 Pattern-Key 和 Tags**
2. **搜索已有条目**：`grep` LEARNINGS.md 中所有条目的 `Pattern-Key` 和 `Tags` 字段
3. **判断是否重复**：
   - Pattern-Key 完全匹配 → 视为同一模式
   - Tags 重叠 ≥ 60% 且 Summary 语义相似 → 视为同一模式
4. **匹配到已有条目时**：
   - ❌ 不创建新条目
   - ✅ 更新已有条目：`Recurrence-Count += 1`、`Last-Seen` 更新为当前日期
   - ✅ 在 Details 末尾追加本次触发的简要描述（一行）
   - ✅ 检查提升阈值：
     - `Recurrence-Count >= 2` 且 `Priority = critical` → 输出 `⚠️ 此问题已出现 {N} 次（critical），建议立即提升为规则`
     - `Recurrence-Count >= 3` 且 `Priority = high` → 输出 `⚠️ 此问题已出现 {N} 次，建议提升为规则`
     - `Recurrence-Count >= 5`（任意优先级） → 输出 `🔴 此问题已出现 {N} 次，必须提升为规则`
5. **未匹配到时**：正常创建新条目，`Recurrence-Count: 1`

**禁止行为**：
- ❌ 禁止不检查就直接创建新条目（这是 Recurrence-Count 失效的根因）
- ❌ 禁止跳过提升阈值检查

### Promote 决策表

| 条件 | 操作 |
|------|------|
| Status = promoted | 已提升，确认对应规则存在后可清理 |
| Priority = critical + 出现 ≥2 次 | 必须 promote |
| Priority = high + 出现 ≥3 次 | 建议 promote |
| 超过 90 天无复现 | 标记为历史归档 |

## 能力四：主动 Patch

检测到 rule/skill 存在缺陷时，主动发起 patch 修正流程。

### 触发条件

1. 流程执行中发现矛盾：dev-flow 步骤指令与实际冲突
2. 用户纠正的行为直接对应某条规则指令
3. dev-flow 步骤 9 反思阶段识别出可优化规则
4. 能力二规则审计发现可自动修正项

### 安全前置条件（硬性）

执行 patch 前必须全部满足：

- 已完成 .backup/ 备份
- 已执行 Unicode/注入扫描
- 使用原子写入范式
- 获得用户显式确认（rule/SKILL 改动必须二次确认）

### 执行流程

完整 8 步流程见 `references/auto-patch.md`。精要：识别 → 备份 → 扫描 → diff 展示 → 用户确认 → 原子写入 → 记录 PATCHES.md → 交互式提醒。

### 禁止触发的场景

- 修改 alwaysApply=true 的规则（须用户主动发起）
- 删除规则条目（只能新增/修改）
- 跨文件级联 patch（单次只能影响一个文件）
- 无实际冲突证据的「主观改进」

### Patch 记录

所有 patch 记录到 `~/.codebuddy/.learnings/PATCHES.md`，结构化条目含：timestamp / file / reason / trigger / diff / confirmed_by。

## 快速决策路由

当检测到可改进模式时，快速判断该走哪条路径：

| 情况 | 路由 | 说明 |
|------|------|------|
| 用户纠正 AI | → 红线规范自动执行 `create_rule` | 不经过本 Skill |
| 命令失败（非零退出码） | → 记录到工作上下文 or `.learnings/ERRORS.md` | 本 Skill 负责记录 |
| 首次项目约定 | → 红线规范自动执行 `create_rule` | 不经过本 Skill |
| 同一问题 ≥3 次 | → 红线规范自动提升为规则 | 不经过本 Skill |
| dev-flow 步骤 9 反思 | → 本 Skill 的经验回顾 + 记录管理 | 与 continuous-learning-v2 配合 |
| 用户主动请求 | → 本 Skill 的对应能力 | 直接执行 |

## 保留的脚本资产

以下文件保留在目录中供参考，但不在主流程中使用：

| 文件 | 用途 |
|------|------|
| `scripts/activator.sh` | 会话提醒钩子（需 Claude Code CLI） |
| `scripts/error-detector.sh` | 错误自动检测（需 Claude Code CLI） |
| `scripts/extract-skill.sh` | 学习提取为 Skill |
| `assets/LEARNINGS.md` | 学习记录模板 |
| `assets/SKILL-TEMPLATE.md` | Skill 创建模板 |
| `hooks/` | OpenClaw hooks 集成（需外部环境） |
| `references/` | 详细配置指南和示例 |

## 与 dev-flow 的集成点

| dev-flow 步骤 | 本 Skill 参与方式 |
|--------------|------------------|
| 步骤 1（研究与定位） | 经验回顾：检索相关历史经验 |
| 步骤 5（执行修改） | 错误记录：命令失败时记录到 `.learnings/ERRORS.md` |
| 步骤 9（反思与学习） | 全面参与：回顾 + 记录 + 建议 promote |
| 步骤 10（归档） | promote 检查：确认高价值条目已提升为规则 |
