---
layout: home

hero:
  name: AI Coding Kit
  text: AI 辅助编程方法论门户
  tagline: 以 dev-flow 为核心旗舰，整合 29 个 Skills、16 条 Rules、10 个 Agents，构建系统化的 AI 结对编程工作流。
  image:
    src: /logo.svg
    alt: AI Coding Kit
  actions:
    - theme: brand
      text: 5 分钟快速上手
      link: /guide/quick-start
    - theme: alt
      text: 了解 dev-flow
      link: /dev-flow/
    - theme: alt
      text: 安装与配置
      link: /guide/installation

features:
  - icon: 🚩
    title: dev-flow 工作流引擎
    details: 系统化开发工作流（阶段 0 + 步骤 1~10），强制执行需求理解、根因定位、最小入侵、反模式规避等核心原则，覆盖从需求到交付的完整生命周期。
    link: /dev-flow/
    linkText: 进入旗舰板块
  - icon: 🧩
    title: 29 个 Skills 生态
    details: 从需求输入、方案设计、代码审查到验证测试，按流程协作 / 质量保障 / 工具能力 / 学习进化四大角色分组，即插即用。
    link: /skills/
    linkText: 浏览全部 Skills
  - icon: 📏
    title: 16 条 Rules 规范
    details: 核心红线（alwaysApply）+ 官方规范（CSS/SQL/TypeScript）+ 按需规范，约束 AI 代码生成行为，守住工程质量底线。
    link: /rules/
    linkText: 查看规范清单
  - icon: 🤖
    title: 10 个专职 Agents
    details: 1 号~9 号覆盖代码搜索、审查、样式分析、测试验证、安全检查等场景，step-gate 专职 dev-flow 关键步骤门控审计。
    link: /agents/
    linkText: 查看 Agents
  - icon: 🔒
    title: 零配置可用
    details: 所有 skill 核心功能运行在纯本地模式（git + bash + 本地文件），无需任何外部平台。平台集成是可选增强。
    link: /guide/installation
    linkText: 安装指南
  - icon: 🌱
    title: 单一权威源
    details: 文档站通过构建时脚本把源文件「投影」到站点，绝不复制维护第二份 —— 与 dev-flow「单一权威源」设计哲学一致。
    link: /guide/what-is-it
    linkText: 设计理念
---

## 快速安装

克隆仓库到任意目录（**不要**直接克隆到 `~/.codebuddy`），通过 dev-flow 自带安装器安装：

```bash
git clone <your-repo-url> ~/ai-coding-kit
cd ~/ai-coding-kit/skills/dev-flow/dist
bash install.sh   # 默认：dev-flow + 全部依赖 + 核心规则 + Agents
```

| 命令 | 内容 |
|------|------|
| `bash install.sh` | 默认安装：dev-flow + 全部 14 依赖（共 **15 个 Skill**）+ **2 条核心规则** + 10 个 Agents |
| `bash install.sh --all-repo` | 整仓全量：**全部 29 个 Skill** + 全部 **16 条规则** + 10 Agents |

> 安装器为**复制**式独立副本，与本仓库完全隔离 —— 改动 `~/.codebuddy/` 下的内容不会影响本仓库，反之亦然。详见 [安装与配置](/guide/installation)。
