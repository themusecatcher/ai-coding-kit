# 触发规则速查（预编译常量）

> 本文件是 AI 做触发判断时的**超精简规则集**，目标 ≤300 tokens。
> 完整规则：`SKILL.md` §「触发规则」 / `references/skill-full.md`「触发规则」章节。
>
> **2026-06-01 改版**：仅显式命令触发 + 活跃流程相关时恢复，不再基于关键词主观判断自动触发。

## 触发判定（按优先级从高到低）

| # | 触发方式 | 条件 | 动作 |
| --- | --- | --- | --- |
| 1 | 显式命令 | `dev-flow` / `dev:` / `/dev-flow` | `use_skill('dev-flow')` |
| 2 | 子命令 | `dev:help` / `dev:h` / `--help` / `-h` / `dev:status` / `dev:st` / `dev:kb` / `dev:k` / `dev:metrics` / `dev:m` / `dev:onboard` / `dev:ob` / `dev:flowchart` / `dev:chart` | `use_skill('dev-flow')` → 对应子命令 |
| 3 | 修饰命令 | `--fast` / `--micro`（与基础命令组合） | `use_skill('dev-flow')` + 修饰层 |
| 4 | 活跃流程恢复 | `.active-flows/*.flow` 存在 **且**用户消息与 `match_keywords` / `brief` 相关 | `use_skill('dev-flow')` → 智能恢复 |
| 5 | 开发意图（**不自动触发**） | 含 `修复` / `优化` / `新需求` / 任务平台 / Figma 等关键词 | **不调用 `use_skill('dev-flow')`**；在回复中**主动建议**用户使用 `dev-flow` 命令 |
| 6 | 其他 | — | 普通对话 |

> **流程内信号**（仅 dev-flow 已激活时生效，不属触发规则）：`提测反馈` / `继续上次需求` / `继续下一批` / `跨项目修复衔接` / `少问我` / `每步都问我` / `改个错别字`（micro-fix 辅助）等。普通对话中说这些词**不会触发任何行为**。详见 `references/skill-full.md` §5。

## 不触发 dev-flow（普通对话）

- 询问规则/流程如何工作（讨论性质）
- 修改 Skill/规则文件本身
- 技术咨询、代码解读（非改动需求）
- 文档生成（非代码开发）
- 用户说"直接改" / "帮我加个判空"等明确不需要走流程的小修改 → 直接改，但遵守 `开发规范-红线.mdc` 红线
- 含开发意图关键词但用户未输入显式命令 → 主动建议 `dev-flow` 命令，等待用户决策

## 反绕过 & 强执行规则

- 一旦显式命令触发 dev-flow，**严格执行完整流程**，不得以"任务简单"为由跳步
- AI **严禁**基于关键词主观判断自动触发；命中开发意图必须先建议 `dev-flow` 命令
- 步骤不可跳过：dev-flow 触发后，每个步骤必须按顺序执行
- 活跃流程恢复仅在用户消息与 `match_keywords` / `brief` 相关时触发；不相关（纯咨询/元讨论/其他需求）时不恢复

## 优先级

```text
用户显式 dev-flow 命令
  > 活跃流程恢复（相关时）
  > issue-trace
  > 普通对话（含开发意图建议）
```

## 需要详细规则时

若检测到模糊场景（多个信号同时命中、边界情况），加载完整版：

```text
read_file("references/skill-full.md")   # 完整触发规则
read_file("references/mode-matrix.md")   # 模式切换矩阵
```
