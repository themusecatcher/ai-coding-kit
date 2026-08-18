# 这是什么

**AI Coding Kit** 是一套面向 AI 辅助编程的方法论工具集，集中管理 **Skills、Agents、Rules** 三类资源，以 [`dev-flow`](/dev-flow/) 工作流引擎为核心旗舰，构建从需求理解到代码交付的完整开发生命周期。

## 为什么做

AI 结对编程强大但也容易失控：猜测需求、过度重构、遗漏边界、延续老代码缺陷……本工具集把工程团队沉淀的最佳实践固化为**可被 AI 直接加载执行的规范与流程**，让 AI 编程既高效又可控。

核心解决三个问题：

- **流程无序** → `dev-flow` 提供阶段 0 + 步骤 1~10 的系统化工作流，强制需求理解、根因定位、最小入侵。
- **质量失守** → Rules 红线 + 质量保障类 Skills（code-review / verification-* / security-review）守住工程底线。
- **经验流失** → 学习进化类 Skills（knowledge-loop / self-improving-agent）沉淀并复用代码知识。

## 三类资源

| 资源 | 数量 | 作用 |
|------|------|------|
| [Skills](/skills/) | 29 个 | AI 技能定义，每个是独立目录含 `SKILL.md` 主文件 |
| [Rules](/rules/) | 16 条 | 编码规范与项目规则（`.mdc`），约束 AI 代码生成行为 |
| [Agents](/agents/) | 10 个 | 不同场景下的专职 Agent 配置 |

## 设计哲学：单一权威源

本文档站遵循 dev-flow 的核心哲学 —— **单一权威源（Single Source of Truth）**。

源文件始终保持原位（`skills/`、`rules/`、`agents/`），文档站通过**构建时脚本**把内容「投影」到站点，绝不复制维护第二份。这意味着：

- 修改源文件后，重新生成即同步到文档站，无需手动同步两处。
- 文档与实际生效的规范永远一致，杜绝「文档说一套、代码做一套」。

## 下一步

- 想快速体验 → [5 分钟快速上手](/guide/quick-start)
- 想了解安装细节 → [安装与配置](/guide/installation)
- 想深入核心引擎 → [dev-flow 旗舰板块](/dev-flow/)
