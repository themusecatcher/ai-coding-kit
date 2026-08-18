# 安装与配置

> 所有配置项均为**可选**：编辑 `config/org.yaml` 让 skill 适配你的环境；不填也能用。

## 前置要求

- **Node** 18+（本文档站基于 VitePress，需 Node 18+）
- **git** + **bash**（skill 核心功能依赖）
- **Python 3**（仅维护脚本 `npm run mp` / `mp:check` / `config:check` 需要）

## 1. 克隆仓库

克隆到任意目录（**不要**直接克隆到 `~/.codebuddy`）：

```bash
git clone <your-repo-url> ~/ai-coding-kit
cd ~/ai-coding-kit
```

## 2. 安装

通过 dev-flow 自带安装器将 skill 安装到 `~/.codebuddy/`（**复制**为独立副本，与本仓库完全隔离——改动 `~/.codebuddy/` 下的内容不会影响本仓库，反之亦然）：

```bash
cd skills/dev-flow/dist
bash install.sh   # 默认：dev-flow + 全部 14 依赖 + 规则 + Agents
```

安装命令：

| 命令 | 内容 |
|------|------|
| `bash install.sh` | 默认安装：dev-flow + 全部 14 依赖（共 **15 个 Skill**）+ **2 条核心规则** + 10 个 Agents |
| `bash install.sh --all-repo` | 整仓全量：仓库根 `skills/` 下**全部 28 个 Skill** + 全部 **16 条规则** + 10 Agents |

> **远程安装**（无需预先 clone）：`bash <(curl -sSL <your-repo-url>/raw/main/skills/dev-flow/dist/remote-install.sh)`。
>
> `--all-repo` 仅本地 clone 场景可用（需访问仓库根 `skills/`）。已存在的规则 / Agents / 配置不会被覆盖，保护本地改动。

管理命令：

- `bash install.sh --status` — 健康检查
- `bash install.sh --uninstall` — 卸载

## 3. 配置（可选）

安装后配置文件位于 `~/.codebuddy/config/org.yaml`（由安装器自动复制，已存在则不覆盖）：

```bash
vim ~/.codebuddy/config/org.yaml
```

> **零配置也能用**：所有 skill 的核心功能运行在纯本地模式（git + bash + 本地文件），无需任何外部平台。平台集成是可选增强。

### 主要配置字段

| 字段 | 控制的能力 | 不配置时的行为 |
|------|----------|--------------|
| `doc_platform_url` | 技术方案在线发布 | 降级为本地 `~/.codebuddy/tech-docs/` |
| `task_platform_url` | 任务链接解析、需求自动拉取 | 降级为口头描述 / 纯文本 |
| `log_platform_url` | 日志平台查询 | issue-trace 跳过日志追溯 |
| `ci_platform_url` | CI / 代码评审平台 | 仅使用本地 git 操作 |

### 验证配置

```bash
npm run config:check   # 检查当前生效的配置文件路径
```

## 4. 从本地同步回仓库（维护者）

修改 `~/.codebuddy/` 下的 skills、agents、rules 后，同步回本仓库：

```bash
npm run sync        # 同步全部（skills + agents + rules）
npm run sync:skills # 仅同步 skills
npm run sync:agents # 仅同步 agents
npm run sync:rules  # 仅同步 rules
```

> 改动 skill 的 frontmatter 或增删 skill 后，提交前需执行 `npm run mp` 重新生成插件市场元数据；建议执行一次 `npm run hooks:install`，让 pre-commit hook 自动拦截过期元数据。

## 5. 本地运行文档站

```bash
npm install         # 安装 VitePress 等依赖
npm run docs:dev     # 本地启动文档站（热更新）
npm run docs:build   # 构建静态站点
npm run docs:preview # 预览构建产物
```
