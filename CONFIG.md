# 配置指南

> 平台集成配置指南。所有配置项均为**可选**：编辑 `config/org.yaml` 让 skill 适配你的环境；不填也能用。

## 快速开始

克隆仓库后，通过 dev-flow 安装器安装 skill，再按需编辑配置：

```bash
git clone <your-repo-url> ~/ai-coding-kit
cd ~/ai-coding-kit/skills/dev-flow/dist
bash install.sh
# 按需编辑配置文件（可选，零配置也能用）
vim ~/.codebuddy/config/org.yaml
```

> 安装器首次安装后会弹出**非阻塞**的配置向导，可现在配置 / 稍后配置 / 零配置直接用。

**零配置也能用**：所有 skill 的核心功能运行在纯本地模式（git + bash + 本地文件），无需任何外部平台即可正常使用。平台集成是可选增强。

---

## 配置字段说明

### 代码仓库平台

| 字段 | 示例 | 何时需要 |
|------|------|---------|
| `repo_platform_url` | `git.example.com` | 脚本中展示仓库链接时 |
| `repo_platform_ssh` | `git@git.example.com:org/repo.git` | 远程安装脚本 |

### 平台 URL（可选增强）

> 留空时相关功能自动降级为本地模式，不影响核心流程。

| 字段 | 控制的能力 | 不配置时的行为 |
|------|----------|--------------|
| `doc_platform_url` | 技术方案在线发布 | 降级为本地 `~/.codebuddy/tech-docs/` |
| `task_platform_url` | 任务链接解析、需求自动拉取 | 降级为口头描述 / 纯文本 |
| `log_platform_url` | 日志平台查询 | issue-trace 跳过日志追溯 |
| `ci_platform_url` | CI / 代码评审平台 | 仅使用本地 git 操作 |

### MCP 工具名称

> 如果你的环境中有 MCP 工具（组件库、搜索引擎等），在此填写工具名即可启用。

| 字段 | 用途 |
|------|------|
| `mcp_tools.component_library` | 组件库查询 |
| `mcp_tools.internal_search` | 内部搜索引擎 |
| `mcp_tools.internal_docs` | 内部文档平台 |
| `mcp_tools.knowledge_base` | 远程知识库 |
| `mcp_tools.task_platform` | 任务平台 MCP |
| `mcp_tools.log_platform` | 日志平台 MCP |
| `mcp_tools.code_platform` | 代码平台 MCP |

### 组织与个人信息

| 字段 | 示例 | 用途 |
|------|------|------|
| `org_name` | `MyOrg` | 文档示例中替换占位 |
| `org_email_domain` | `example.com` | 文档模板邮箱后缀 |
| `user_name` | `Your Name` | 替换文档中的作者名 |
| `user_dir_name` | `yourname` | 替换 `/Users/xxx` 中的用户名 |

### 路径

| 字段 | 默认值 | 说明 |
|------|--------|------|
| `workspace_root` | — | 工作空间目录（替代脚本中的硬编码路径） |
| `tech_docs_dir` | `~/.codebuddy/tech-docs/` | 本地技术文档输出目录 |

### 项目与文档

| 字段 | 默认值 | 说明 |
|------|--------|------|
| `project_name` | `my-project` | 文档示例中的默认项目名 |
| `default_org` | — | 同 org_name，模板独立引用 |
| `tech_docs_mode` | `auto` | 文档发布模式：`auto`（有平台则用）、`local`（始终本地）、`wiki`（仅平台） |

---

## 平台集成能力一览

详见 `skills/_platform-integrations.yaml`。核心原则：**平台集成是可选增强，核心流程始终本地可用**。

| Skill | 可选增强 | 本地模式行为 |
|-------|---------|------------|
| tech-doc | 在线发布技术方案 | 本地 `~/.codebuddy/tech-docs/` |
| smart-commit | 任务平台链接增强 commit | 仅基于 git diff 生成 |
| requirement-intake | 自动拉取任务详情 | 口头描述 / 截图 / 交互式提问 |
| dev-flow | 知识库 / 搜索 / 文档平台增强 | 对应分支静默跳过 |
| knowledge-loop | 远程知识库交叉验证 | 本地 `~/.codebuddy/knowledge/` 始终可用 |
| issue-trace | 日志 / 跨项目 MCP 追溯 | grep + read_file + codebase_search |

---

## 验证配置

```bash
# 检查配置是否生效
npm run config:check
```

---

## 自定义 Skill

### 添加自己的 Skill

1. 在 `~/.codebuddy/skills/` 下创建新目录和 `SKILL.md`
2. 运行 `npm run sync` 同步到仓库

### 移除不需要的 Skill

直接删除 `skills/<name>/` 目录即可，不影响其他 skill。

### 修改现有 Skill

编辑对应 skill 目录下的文件，运行 `npm run sync` 同步回 `~/.codebuddy/`。
