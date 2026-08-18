---
name: smart-commit
description: "智能 Commit Message 生成器。基于代码 Diff 自动生成符合 Conventional Commits 规范的 commit message，包含精简版和标准版两套 body。支持剪贴板复制、可选自动提交。可被 dev-flow 按需调用，也可在任何 Git 仓库中独立使用。触发关键词：commit message、提交信息、生成提交、smart commit、帮我提交、针对当前 diff 生成 commit。"
---

# Smart Commit

> 智能 Commit Message 生成器 —— 基于 diff 分析自动生成规范的 commit message。

## 设计哲学

> 遵循「**确定性用代码，模糊性用 LLM**」原则（详见 `~/.codebuddy/skills/dev-flow/references/core-principles.md` §19）。

| 类型 | 实现方式 | 本 Skill 涉及范围 |
|------|---------|------------------|
| 🟢 **确定性规则** | 脚本 | git diff 获取、体量阈值判断（超过 200 行降级为 stat） |
| 🔴 **模糊性判断** | LLM 提示词 | 基于 diff 生成简短描述、action 决策、分组排序生成 body |

## 用途

基于代码增量 Diff，自动生成符合 Conventional Commits 规范的 commit message。
同时输出**精简版**和**标准版**两套 commit body，由用户选择使用。

## 使用场景

- 用户请求生成 commit message / 提交信息
- 用户说"帮我提交"/"smart commit"/"生成提交"
- dev-flow 流程中「Commit Message 生成」步骤调用

## 关键资源

| 资源 | 路径 | 用途 |
|------|------|------|
| 配置 | `config/action-map.yaml` | diff 阈值、合法 action 白名单 |
| 脚本 | `scripts/git-diff-summary.sh` | 智能选择 full diff / stat 概览（按阈值自动降级） |

## Commit Message 格式规范

### Header 格式

```
{action}: {简短描述}
```

**不使用 scope**，header 中不包含 `(scope)` 部分。

| 部分 | 来源 | 示例 |
|------|------|------|
| `{action}` | LLM 基于 diff + 描述决定 | `feat` / `fix` / `chore` |
| `{简短描述}` | LLM 基于 diff 生成 / 用户自定义 | `新增用户头像组件` |

### Action 决策规则（LLM 模糊判断）

LLM 基于 diff 内容 + 用户描述判断 action，参考以下映射：

| diff 特征 / 描述关键词 | action | 示例 |
|------------------------|--------|------|
| 新增文件/功能、新模块 | `feat` | `feat: 新增暗色模式开关` |
| 修复 bug、异常处理 | `fix` | `fix: 修复支付金额计算错误` |
| 性能优化相关 | `perf` | `perf: 优化首屏加载性能` |
| 代码重构（不改功能） | `refactor` | `refactor: 提取通用表单校验逻辑` |
| 文档/注释更新 | `docs` | `docs: 更新 API 使用说明` |
| 代码格式/缩进（无逻辑变更） | `style` | `style: prettier 格式化` |
| 测试用例 | `test` | `test: 补充用户模块单元测试` |
| 依赖/构建/配置变更 | `chore` | `chore: 更新依赖版本` |
| 回滚 | `revert` | `revert: 回滚到 v1.2` |

> ⚠️ **禁止反模式**：用户未提供描述时，LLM 基于 diff **实际内容**判断 action，不得一律用 `chore`。

### Commit Body 双模式

始终同时生成两套 body，分开展示供用户选择。

#### 精简版 Body

每个改动模块一行概述，格式：`- {动作} {模块/文件简称}`

```
- 新增屏幕共享限制配置组件
- 修改账户设置页面集成新入口
- 新增权限策略查询 Hook
```

#### 标准版 Body

详细说明「改了什么」+「为什么改/改动效果」，格式：`- {动作} {具体文件/模块}，{原因或效果}`

```
- 新增 ScreenShareRestriction 组件，支持按成员维度配置屏幕共享权限，包含成员搜索和批量选择功能
- 修改 AccountSettings 页面，在安全设置区块集成屏幕共享限制入口，使用条件渲染控制可见性
- 新增 useScreenSharePolicy Hook，封装权限策略的 CRUD 操作和本地缓存逻辑
```

#### Body 生成规则（LLM 模糊判断）

1. 按改动文件/模块分组，每组用 `- ` 开头
2. 按重要性排序（核心逻辑 > 辅助功能 > 配置/样式）
3. 每条控制在一行内
4. body 与 header 之间必须有一个空行

## 工作流程

### 步骤 1：获取代码改动信息（脚本化）

```bash
~/.codebuddy/skills/smart-commit/scripts/git-diff-summary.sh
```

脚本自动：
- 优先检查 staged，无暂存改动则降级到工作区
- 默认输出 full diff，超过 200 行（阈值在 YAML）自动降级为 `--stat`
- 元信息（mode/line_count/source）写到 stderr 便于 LLM 感知

> 阈值需要调整？改 `config/action-map.yaml` 的 `diff_threshold.full_diff_max_lines`。

### 步骤 2：生成简短描述（LLM 模糊判断）

**情况 A：用户提供了自定义描述** → 直接使用，跳过 diff 分析
**情况 B：用户未提供描述** → 基于 diff 内容 AI 生成，规则：

| 改动类型 | 描述格式 | 示例 |
|---------|---------|------|
| 新增文件 | `新增 xxx` / `添加 xxx 功能` | `新增用户头像组件` |
| 修改文件 | `优化 xxx` / `更新 xxx` | `优化列表渲染逻辑` |
| 删除文件 | `移除 xxx` / `删除 xxx` | `移除废弃的工具函数` |
| 修复问题 | `修复 xxx` | `修复支付金额计算错误` |

### 步骤 3：LLM 决定 action

基于 diff 内容 + 描述，按「Action 决策规则」中的映射表判断 action。合法 actions 白名单见 `config/action-map.yaml`。

### 步骤 4：LLM 生成双模式 body

基于 diff 内容分别生成精简版和标准版 body，遵循「Commit Body 双模式」规则。

### 步骤 5：二段式展示

生成后按「**精简版 → 标准版**」二段式展示：

```
📝 Commit Message 已生成：

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 【精简版】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

feat: 新增暗色模式开关

- 新增 ThemeToggle 组件
- 修改全局样式变量
- 新增主题持久化 Hook

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 【标准版】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

feat: 新增暗色模式开关

- 新增 ThemeToggle 组件，支持一键切换亮色/暗色主题，含过渡动画
- 修改全局 CSS 变量，将硬编码颜色值替换为 CSS 自定义属性以支持主题切换
- 新增 useTheme 自定义 Hook，封装主题状态管理和 localStorage 持久化逻辑
```

### 步骤 6：用户交互决策

展示后弹出交互选项（使用 `ask_followup_question`）：

| 选项 | 说明 |
|------|------|
| ✏️ 修改 | 告诉我需要调整的内容，修改后重新展示 |
| 🔄 重新生成 | 重新分析 diff 生成 |
| 📦 精简版 + 自动提交 | 使用精简版 commit message 执行 `git add . && git commit` |
| 📦 标准版 + 自动提交 | 使用标准版 commit message 执行 `git add . && git commit` |
| ⏭️ 自行提交（继续执行后续环节） | 不执行 git commit，由用户自行提交；调用方继续执行后续环节 |

### 步骤 7：自动提交（仅当用户选择「自动提交」选项时）

⚠️ **默认不执行任何 git 操作**，仅在用户明确选择「📦 自动提交」选项时执行：

```bash
# 1. 暂存所有改动
git add .

# 2. 使用多行 commit（header + body）
git commit -m "header行" -m "body第1行" -m "body第2行" ...

# 3. 提交成功后展示结果
git log --oneline -1
```

> ❌ 禁止自动执行 `git push`，push 始终由用户自行决定。

## 异常兜底

### 无代码改动时

`git-diff-summary.sh` 的 stderr 会输出 `{"mode":"empty",...}`，此时提示用户先进行代码修改，或手动提供描述信息。

### 脚本不可用时（兜底）

如果脚本因任何原因无法执行（权限、路径不存在等），LLM 应：
1. 优先告知用户脚本错误，建议重装/修复 Skill
2. 不得回退到自己心算 diff 内容——应提示用户使用 `git diff --cached` 或 `git diff` 获取

## 完整示例

### 示例 1：用户提供描述

```
用户：帮我生成 commit message，描述：新增暗色模式

AI 执行：
1. 调用 scripts/git-diff-summary.sh → 拿到 file list / stat / diff
2. 使用用户提供的描述："新增暗色模式"
3. LLM 判断 action → feat（新增功能）→ 校验在白名单内
4. LLM 基于 diff 生成精简版/标准版 body
5. 二段式展示 + 用户交互
```

### 示例 2：用户未提供描述

```
用户：帮我生成当前 diff 的 commit message

AI 执行：
1. 调用 scripts/git-diff-summary.sh → 拿到 diff
2. LLM 基于 diff 生成简短描述："修复 marketplace 生成脚本 YAML 多行描述解析失败"
3. LLM 判断 action → fix（修复 bug）
4. LLM 基于 diff 生成精简版/标准版 body
5. 二段式展示 + 用户交互
```

最终输出形态：

```
📝 Commit Message 已生成：

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 【精简版】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

fix: 修复 marketplace 生成脚本对 YAML 多行描述解析失败的问题

- 修复 YAML 多行字段解析逻辑
- 调整 description 字段读取容错

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 【标准版】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

fix: 修复 marketplace 生成脚本对 YAML 多行描述解析失败的问题

- 修复 generate-marketplace.js 中的 YAML 多行字段解析逻辑
- 调整 description 字段读取容错，遇到非字符串值时回退到默认描述
```
