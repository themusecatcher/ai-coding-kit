# ai-coding-kit

> 个人 CodeBuddy 资源管理仓库 —— 集中管理 Skills、Agents、Rules

## 📁 目录结构

```
ai-coding-kit/
├── skills/        # AI 技能定义（Skill 文件及其引用资源）
├── agents/        # AI Agent 配置
├── rules/         # 编码规范与项目规则
├── config/        # 环境配置（org.yaml，首次使用需填写）
├── scripts/       # 同步与构建脚本（含 lib/ 配置加载工具，详见 scripts/README.md）
├── .codebuddy-plugin/  # 市场源文件（marketplace.json，由 pnpm mp 生成）
├── CONFIG.md      # 配置指南
├── package.json   # pnpm scripts 配置
└── README.md
```

## 🔧 资源说明

### Skills

AI 技能集合，每个 Skill 是一个独立目录，包含 `SKILL.md` 主文件及可选的 `references/`、`scripts/`、`templates/` 等子目录。

仓库共托管 **29 个 Skills**，完整清单：

| Skill | 简介 |
|-------|------|
| `dev-flow` | 系统化开发工作流引擎（核心） |
| `requirement-intake` | 需求输入与理解 |
| `knowledge-loop` | 代码知识沉淀与复用 |
| `design-advisor` | 方案分析与避坑指南 |
| `code-review` | 三级代码审查工作流 |
| `tech-doc` | 文档处理中心（开发日志/方案/同步） |
| `verification-pipeline` | 验证管线工具箱 |
| `smart-commit` | 智能 Commit Message 生成器 |
| `coding-standards` | 编码规范与最佳实践 |
| `frontend-patterns` | 前端开发模式 |
| `self-improving-agent` | 经验回顾与规则质量管理 |
| `browser-compat` | 浏览器兼容性检查 |
| `i18n` | 国际化翻译资源操作 |
| `dom-animation` | DOM 定位与动画开发规范 |
| `browser-toolkit` | 浏览器自动化工具路由中枢 |
| `issue-trace` | 问题根因定位与调用链追溯 |
| `agent-browser` | 浏览器自动化 CLI |
| `e2e-testing` | Playwright 端到端测试 |
| `security-review` | 安全审查 |
| `complexity-optimizer` | 代码复杂度检测 |
| `verification-loop` | 编码会话质量保证 |
| `find-skills` | Skill 发现与安装 |
| `search-first` | 先搜索后编码工作流 |
| `pdf-reader` | PDF 全能工具包 |
| `research-doc` | 外网资料搜索与文档生成 |
| `tavily-search` | AI 优化的网页搜索 |
| `continuous-learning-v2` | 基于本能的学习系统 |
| `proactive-agent` | 主动式 AI Agent |
| `dev-comp` | vue-amazing-ui 组件库开发迭代工作流 |

> 排名不分先后。前 15 个（`dev-flow` ~ `browser-toolkit`）为默认安装项，其余为独立 Skill，通过 `--all-repo` 安装。

### Agents

10 个 AI Agent 配置文件（`.md` 格式），定义不同场景下的 Agent 行为和角色：

- **1 号 ~ 9 号**：覆盖代码搜索、审查、样式分析、测试验证、安全检查、性能分析、需求分析、文档管理等通用场景
- **step-gate**：步骤门控审查 Agent，专用于 dev-flow 关键步骤的完整性审计

### Rules

编码规范和项目规则文件（`.mdc` 格式），用于约束 AI 的代码生成行为。

仓库共 **16 条规则**，分两类：
- **核心规则**（2 条）：`AI行为规范.mdc`、`开发规范-红线.mdc` —— 随默认安装自动部署
- **按需规则**（14 条）：如 CSS 规范、TypeScript 规范、浏览器兼容性规范等 —— 位于仓库 `rules/` 目录，按需手动引用或通过 `--all-repo` 安装

## 📦 使用方式

### 1. 克隆仓库

克隆到任意目录（**不要**直接克隆到 `~/.codebuddy`）：

```bash
git clone <your-repo-url> ~/ai-coding-kit
cd ~/ai-coding-kit
```

### 2. 安装 dev-flow

通过 dev-flow 自带的安装器将 skill 安装到 `~/.codebuddy/`（**复制**为独立副本，与本仓库完全隔离——改动 `~/.codebuddy/` 下的内容不会影响本仓库，反之亦然）：

```bash
cd skills/dev-flow/dist
bash install.sh   # 默认：dev-flow + 全部 14 依赖（共 15 个 skill）+ 规则 + Agents
```

安装命令：

| 命令 | 内容 |
|------|------|
| `bash install.sh` | 默认安装：dev-flow + 全部 14 依赖（共 **15 个 Skill**）+ **2 条核心规则** + 10 个 Agents |
| `bash install.sh --all-repo` | 整仓全量：仓库根 `skills/` 下**全部 28 个 Skill**（含 issue-trace 等独立 skill）+ 全部 **16 条规则** + 10 Agents |

> **远程安装**（无需预先 clone）：`bash <(curl -sSL <your-repo-url>/raw/main/skills/dev-flow/dist/remote-install.sh)`，详见 [skills/dev-flow/dist/README.md](skills/dev-flow/dist/README.md)。

> 默认安装即会一并装好 Skill、规则和 Agents，无需额外开关（已存在的规则 / Agents / 配置不覆盖，保护本地改动）。`--all-repo` 仅本地 clone 场景可用（需访问仓库根 `skills/`）。

> 安装器会在首次安装后弹出**可选**的配置向导（现在配置 / 稍后配置 / 零配置直接用，非阻塞）。
> 管理命令：`bash install.sh --status`（健康检查）、`bash install.sh --uninstall`（卸载）。
> 维护者：`bash package.sh` 打包 dist 分发包（详见 `skills/dev-flow/dist/README.md`）。
> 详细安装说明见 [skills/dev-flow/dist/README.md](skills/dev-flow/dist/README.md)。

### 3. 配置（可选）

```bash
# 安装后配置文件位于此处（由安装器自动复制，已存在则不覆盖）
vim ~/.codebuddy/config/org.yaml
```

> 详细配置说明见 [CONFIG.md](CONFIG.md)。所有 skill 默认纯本地运行，平台集成是可选增强，**零配置也能用**。也可直接编辑仓库中的 `config/org.yaml`。

### 4. 从本地同步回仓库（维护者）

修改 `~/.codebuddy/` 下的 skills、agents、rules 后，同步回本仓库：

```bash
pnpm sync        # 同步全部（skills + agents + rules）
pnpm sync:skills # 仅同步 skills
pnpm sync:agents # 仅同步 agents
pnpm sync:rules  # 仅同步 rules
```

### 5. 检查与维护

```bash
pnpm mp               # 生成 marketplace.json 和各 skill 的 plugin.json
pnpm mp:check         # 校验市场元数据是否过期（改了 frontmatter / 增删 skill 后未执行 mp 时提示）
pnpm hooks:install    # 安装 pre-commit hook（提交时自动拦截过期元数据）
pnpm config:check     # 检查当前生效的配置文件路径
```

> ⚠️ 改了 skill 的 frontmatter（描述/关键词/分类等）或增删 skill 后，**必须**执行 `pnpm mp` 再提交，否则插件市场看不到更新。只改 SKILL.md 正文或子文件则无需执行。
> 脚本详细说明见 [scripts/README.md](scripts/README.md)。

## 📖 文档站（VitePress）

本仓库内置一个可视化文档网站，以 `dev-flow` 为核心旗舰，自动整合全部 Skills、Rules、Agents，形成「AI 辅助编程方法论门户」。

```bash
pnpm install         # 首次运行前安装依赖（VitePress 需 Node 18+，包管理器统一用 pnpm）
pnpm docs:gen        # 从 skills/ rules/ agents/ 生成文档站内容 + 侧边栏
pnpm docs:dev        # 本地启动（热更新，默认 http://localhost:5173）
pnpm docs:build      # 构建静态站点到 docs/.vitepress/dist
pnpm docs:preview    # 预览构建产物
pnpm docs:deploy "docs: xxx"  # 一键部署到 GitHub Pages（需传 commit 描述）
```

| 命令 | 作用 |
|------|------|
| `pnpm docs:gen` | 扫描源文件 frontmatter，把内容「投影」到 `docs/`（含 dev-flow 多级板块、Mermaid 流程图、按主题分组侧边栏）|
| `pnpm docs:dev` | 本地开发服务器 |
| `pnpm docs:build` | 生产构建（先自动 `docs:gen` 再构建，含死链检测）|
| `pnpm docs:preview` | 预览已构建的静态站点 |
| `pnpm docs:deploy "<type>: <描述>"` | 构建 → 强推 `gh-pages` 分支 → 提交并推送主仓库源码，发布到 GitHub Pages |

> **单一权威源**：文档站通过构建时脚本 `scripts/gen-docs.mjs` 把源文件投影到 `docs/`，绝不复制维护第二份。`docs/{skills,rules,agents,dev-flow}/` 与侧边栏均为生成产物（已在 `.gitignore` 忽略），改动源文件后重新 `docs:gen` 即同步。手写页面仅 `docs/index.md`（首页）、`docs/guide/`（指南）与 `docs/public/`（logo 等静态资源）。

### 🌐 部署到 GitHub Pages

文档站可一键部署到 GitHub Pages，效果类似 [vue-amazing-ui 文档站](https://themusecatcher.github.io/vue-amazing-ui/)：

```bash
pnpm docs:deploy "docs: update site"   # 必须传入语义化 commit 描述
```

该命令（`scripts/deploy.sh`）会自动完成：`docs:gen` 生成内容 → 以 `DOCS_BASE=/ai-coding-kit/` 构建 → 在 `docs/.vitepress/dist` 内初始化临时 git 仓库并**强制推送**到远程 `gh-pages` 分支 → 清理临时 git → **提交并推送主仓库源码**（commit 描述用你传入的参数）。发布地址：<https://themusecatcher.github.io/ai-coding-kit/>。

> - 首次部署后，需到 GitHub 仓库 **Settings → Pages** 将 Source 设为 `Deploy from a branch`、分支选 `gh-pages` / `/ (root)`。
> - 与本地参考仓库 `vue-amazing-ui/scripts/deploy.sh` 保持一致：先部署 dist 产物，再提交源码；缺少 commit 描述会直接报错拦截。
> - 部署地址子路径为 `/ai-coding-kit/`（对应仓库名），如仓库改名或用自定义域名，需同步调整 `scripts/deploy.sh` 中的 base 与远程地址。

### 🚀 一键提交推送

日常改动后一键 `git add . && commit && push`：

```bash
pnpm push "<type>: <描述>"   # 例：pnpm push "docs: update readme"
```

## 🎯 核心特性

- **零配置可用**：所有 skill 核心功能运行在纯本地模式，无需任何外部平台
- **可选平台增强**：配置 `config/org.yaml` 后可接入文档平台、任务平台、知识库等
- **平台集成清单**：详见 `skills/_platform-integrations.yaml`

## 📊 分别管理

```bash
# 查看 Skills 变更历史
git log -- skills/

# 查看 Rules 变更历史
git log -- rules/

# 查看 Agents 变更历史
git log -- agents/

# 查看某个具体 Skill 的变更
git log -- skills/dev-flow/
```
