# dev-flow 安装与使用指南

> **dev-flow** 是一个系统化的 AI 辅助开发工作流，覆盖从需求理解到代码交付的完整生命周期。

---

## 快速安装

### 方式一：本地安装（已有源码）

```bash

# 默认安装（dev-flow + 全部 14 依赖，共 15 个 Skill + 规则 + Agents）
bash install.sh

# 整仓全量（仓库根 skills/ 下所有 skill，含 issue-trace 等独立 skill）
bash install.sh --all-repo

# 检查安装状态
bash install.sh --status

```

### 方式二：远程安装（团队分发）

```bash

# 默认安装（全部 Skill + 规则 + Agents）
bash remote-install.sh

# 整仓全量安装
bash remote-install.sh --all-repo

```

---

## 安装包内容

### 核心依赖（7 个，流程断点，必装）

| 组件 | 说明 |
| --- | --- |
| `requirement-intake` | 需求理解与解析（阶段 0） |
| `knowledge-loop` | 代码知识沉淀与复用（步骤 1/5/7/10） |
| `design-advisor` | 方案分析与避坑指南（步骤 3） |
| `code-review` | 三级代码审查工作流（步骤 5.5/7/8） |
| `tech-doc` | 文档处理中心（步骤 5.5/7/10） |
| `verification-pipeline` | 验证管线工具箱（步骤 6） |
| `smart-commit` | 智能 Commit Message 生成（步骤 7/10） |

### 强化依赖（4 个，缺失时降级运行）

| 组件 | 说明 |
| --- | --- |
| `coding-standards` | 通用编码规范（步骤 5） |
| `frontend-patterns` | 前端开发模式（步骤 5） |
| `self-improving-agent` | 经验回顾与规则质量管理（步骤 9，仅完整执行） |
| `browser-compat` | 浏览器兼容性检查（code-review 子依赖） |

### 可选依赖（3 个，按场景加载）

| 组件 | 说明 |
| --- | --- |
| `i18n` | 国际化翻译资源操作 |
| `dom-animation` | DOM 定位与动画开发规范 |
| `browser-toolkit` | 浏览器自动化工具路由中枢 |

### 可选规则

| 组件 | 说明 |
| --- | --- |
| `AI行为规范.mdc` | AI 行为管理规范 |
| `开发规范-红线.mdc` | 编码红线与最佳实践 |

### 配置文件（可选）

安装器会把 `config/org.yaml` 复制到 `~/.codebuddy/config/`（已存在则不覆盖，保留你的配置）。所有字段默认全空，**零配置也能用**——平台集成是可选增强，留空时相关能力自动降级为本地模式。

安装完成后会弹出**非阻塞**的配置向导，可选择：

1. 现在配置（用默认编辑器打开 org.yaml，可只填部分字段）
2. 稍后手动配置（仅记住路径）
3. 不配置，直接使用（零配置模式，默认）

> 非交互式环境（CI / 管道调用）会自动跳过向导，不阻塞安装。

---

## 使用方式

安装完成后，在 CodeBuddy IDE 中通过**显式命令**触发 dev-flow（v3 改版 2026-06-01：仅支持命令触发，不再基于关键词自动触发）：

```text

# 开始一个新功能开发（触发 dev-flow 统一流程）
用户：dev-flow 帮我实现用户头像上传功能

# 或缩写
用户：dev: 实现用户头像上传功能

# AI 进入 dev-flow 流程：

#   阶段 0: 需求理解

#   步骤 1-3: 研究 → 确认范围 → 制定方案

#   步骤 4: 方案决策（标准/完整/分批执行）

#   步骤 4.5: 环境检查

#   步骤 5: 执行编码

#   步骤 5.5: L1 审查 + 文档同步 + 自检

#   步骤 6: 质量验证

#   步骤 7: 清理 + Commit（标准执行在此结束）

#   步骤 8-10: L3 审查 + 反思 + 归档（仅完整执行）

```text

### 触发方式（仅显式命令）

| 命令 | 快捷 | 说明 |
| --- | --- | --- |
| `dev-flow` / `dev:` | — | 进入统一流程 |
| `dev:status` | `dev:st` | 工作上下文进度概览 |
| `dev:kb` | `dev:k` | 知识库管理 |
| `--fast` | — | 精简交互模式（可与任意命令组合） |
| `--micro` | — | micro-fix 快速修复模式 |

> ⚠️ **注意**：dev-flow 不再基于自然语言关键词（如"修复"/"优化"等）自动触发。
> AI 检测到开发意图关键词时会在回复中主动建议使用 `dev-flow` 命令，由用户决策。

---

## 管理命令

```bash

# 查看安装状态
bash install.sh --status

# 完全卸载
bash install.sh --uninstall

```

---

## FAQ

### Q: 安装后 CodeBuddy 没有识别到 dev-flow？

A: 确认安装状态：

```bash
bash install.sh --status

```
如果某项显示"未安装"或"旧版符号链接"，重新运行安装即可（会自动清理旧链接并重建为独立副本）：

```bash
bash install.sh

```

### Q: 我已有自定义规则，安装会覆盖吗？

A: **不会**。安装规则时，如果目标位置已有同名文件，会跳过并提示"已存在"。

### Q: 我的 Skills 目录已有 dev-flow，会丢失吗？

A: **不会丢失**。若目标位置已有非本安装器的实体目录，安装器会先备份到 `~/.codebuddy/skills/.backup/`，再复制新副本。卸载时受管副本也会先备份到 `.backup/` 再移除，可手动恢复。

### Q: 在 ~/.codebuddy/ 下修改 skill 会影响 clone 仓库吗？

A: **不会**。安装采用**复制**（独立实体副本），`~/.codebuddy/` 下的内容与 clone 仓库完全隔离——改动任一方都不影响另一方。如需把 `~/.codebuddy/` 下的改动同步回仓库，在 ai-coding-kit 项目下运行 `pnpm sync`。

### Q: 默认安装 与 --all-repo 的区别？

A:

- **默认（无参数）**：`dev-flow` + 全部 14 个依赖（共 15 个 Skill）+ 规则 + Agents（dev-flow 生态全量，推荐日常使用）
- **--all-repo**：**整仓全量**——安装仓库根 `skills/` 下的**所有** skill（含 `issue-trace`、`complexity-optimizer` 等与 dev-flow 无依赖关系的独立 skill）+ 规则 + Agents。仅本地 clone 仓库场景可用（需要仓库根 `skills/` 存在）

> 默认安装是「dev-flow 生态」全量；`--all-repo` 是「整个仓库」维度的全量，范围更大（多出与 dev-flow 无依赖关系的独立 skill）。

### Q: 更新到新版本怎么做？

A: 在 clone 仓库 `git pull` 后重新运行 `bash install.sh`。安装器会用最新内容覆盖受管副本（旧副本自动备份），你在 `~/.codebuddy/` 下的自定义如需保留请先另存。

---

## 升级指南

### 从符号链接旧版升级

早期版本（v1.0.x）使用符号链接分发，当前版本改为**独立复制副本**（与源仓库隔离）。升级只需**重新运行安装**：

```bash
bash install.sh
```

安装器会自动清理旧版符号链接并重建为独立副本（旧实体目录会先备份到 `.backup/`）。

---

## 目录结构

```text
dev-flow-dist/
├── install.sh              # 本地安装脚本
├── remote-install.sh       # 远程安装脚本（可选）
├── codebuddy/
│   ├── skills/
│   │   ├── dev-flow/       # 核心 Skill
│   │   ├── knowledge-loop/ # 依赖：知识沉淀
│   │   ├── requirement-intake/  # 依赖：需求理解
│   │   └── smart-commit/   # 依赖：Commit 生成
│   └── rules/
│       ├── AI行为规范.mdc
│       └── 开发规范-红线.mdc
├── README.md               # 本文件
└── CHANGELOG.md            # 版本变更记录

```text

---

## 技术细节

### 安装原理

安装器把分发包中的 Skills / Agents **复制**为独立实体副本到 `~/.codebuddy/`：

```text
dist/codebuddy/skills/xxx      → ~/.codebuddy/skills/xxx（独立副本）
（dev-flow 本体源为 skill 根目录，复制时排除 dist/ 避免冗余嵌套）

```text

> 每个受管副本目录下会写入 `.dev-flow-managed` 标记文件，供 `--status` / `--uninstall` 识别。
> 若目标位置已存在非本安装器的实体目录/文件，安装器会先备份到 `.backup/` 再复制。

优势：

- **与源仓库完全隔离**：改动 `~/.codebuddy/` 下的副本不影响 clone 仓库，反之亦然
- 用户可自行修改 Skill 内容进行个性化定制，不会污染仓库 git 状态
- 卸载时受管副本先备份到 `.backup/` 再移除，非本安装器的实体目录会跳过保护

> 更新方式：`git pull` 后重新运行 `install.sh`（覆盖受管副本，旧副本自动备份）。
> 如需把本地改动回流到仓库，在 ai-coding-kit 项目下运行 `pnpm sync`。

### 系统要求

- macOS / Linux
- Bash 4.0+
- Git 2.0+（远程安装需要）
- CodeBuddy IDE

---

## 问题反馈

遇到问题请提供以下信息：

1. `bash install.sh --status` 输出
2. 操作系统版本
3. 错误信息截图

联系方式：[内部 IM / Issue 地址]
