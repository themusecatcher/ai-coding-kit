# Scripts

> CodeBuddy 配置管理脚本集合

## 📋 脚本列表

| 脚本 | 说明 |
|------|------|
| `sync.sh` | 从 `~/.codebuddy` 同步 skills/agents/rules 到本 Git 仓库 |
| `gen-docs.mjs` | 扫描源文件生成 VitePress 文档站内容 + 侧边栏（`pnpm docs:gen`） |
| `deploy.sh` | 构建文档站并部署到 GitHub Pages（`pnpm docs:deploy "<描述>"`） |
| `push.sh` | 一键 `add + commit + push`（`pnpm push "<描述>"`） |
| `generate_marketplace.py` | 生成 `.codebuddy-plugin/marketplace.json` 和各 skill 的 `plugin.json`（支持 `--check` 校验模式） |
| `hooks/pre-commit` | Git hook：提交时校验市场元数据是否过期 |
| `hooks/install.sh` | 将 pre-commit hook 安装到 `.git/hooks/` |
| `lib/load-config.py` | Python 配置加载工具（读取 `config/org.yaml`） |
| `lib/load-config.sh` | Shell 配置加载工具（读取 `config/org.yaml`） |

## 🔄 sync.sh

将本地 `~/.codebuddy` 下的 `skills`、`agents`、`rules` 目录同步到仓库对应目录，并提供交互式 Git 提交与推送。

### 使用方式

在仓库根目录（`ai-coding-kit/`）下通过 pnpm scripts 调用：

```bash
# 同步全部（skills + agents + rules）
pnpm sync

# 仅同步 skills
pnpm sync:skills

# 仅同步 agents
pnpm sync:agents

# 仅同步 rules
pnpm sync:rules

# 查看帮助
bash scripts/sync.sh -h
```

> 也可以直接调用 `bash scripts/sync.sh [目录名...]`

### 功能特性

- **增量同步** — 使用 `rsync --delete` 确保仓库与 `.codebuddy` 完全一致
- **智能排除** — 自动排除 `skills/.clawhub/` 等运行时数据，保护仓库独有的 `README.md` 不被删除
- **变更预览** — 同步后展示新增/修改/删除的文件统计
- **交互式提交** — 确认后才提交，支持自定义 commit message
- **二次确认推送** — 提交和推送分开确认，避免误操作

> ⚠️ 与 pre-commit hook 联动：若同步的变更涉及 skill frontmatter（`SKILL.md` 头部元数据）或 skill 增删，交互式提交会被已安装的 hook 拦截，需先执行 `pnpm mp` 生成市场元数据（见下方 hooks 章节）。

### 同步流程

```
~/.codebuddy/skills/  ──rsync──▶  ai-coding-kit/skills/
~/.codebuddy/agents/  ──rsync──▶  ai-coding-kit/agents/
~/.codebuddy/rules/   ──rsync──▶  ai-coding-kit/rules/
                                       │
                                  Git 变更预览
                                       │
                              交互确认 commit & push
```

## 🏷️ generate_marketplace.py

从各 skill 的 `SKILL.md` frontmatter 中提取名称和描述，生成 CodeBuddy 市场源所需的元数据文件。

```bash
pnpm mp           # 生成
pnpm mp:check     # 只校验磁盘元数据是否与 frontmatter 一致，不写入
```

### 生成产物

| 产物 | 路径 | 说明 |
|------|------|------|
| 市场清单 | `.codebuddy-plugin/marketplace.json` | 所有 skill 的汇总元数据 |
| 插件清单 | `skills/<name>/.codebuddy-plugin/plugin.json` | 每个 skill 目录下的独立清单 |

> 📌 插件清单位置遵循 CodeBuddy 插件市场规范：`<plugin>/.codebuddy-plugin/plugin.json`，且不声明 `skills` 字段（由系统自动发现 plugin 根的平铺 `SKILL.md`）。

### 何时需要执行 `pnpm mp`

| 改动类型 | 需要执行 `pnpm mp` 吗 |
|---------|------------------------|
| 只改 `SKILL.md` 正文（frontmatter 之后的内容） | 不需要 |
| 改 `references/`、`scripts/`、`templates/` 等子文件 | 不需要 |
| 改了 frontmatter（`name` / `description` / `category` / `keywords` / `author`） | ✅ 需要 |
| 新增 / 删除 skill | ✅ 需要 |

### 校验规则

脚本会检查每个 skill 的 `description` 字段质量，如果发现低质量占位符（如 "skill-name skill"）或描述过短，会报错退出并提示具体 skill 名称。

## 🪝 hooks/（元数据过期自动拦截）

防止「改了 frontmatter / 增删 skill 却忘了执行 `pnpm mp`」导致市场元数据过期。

```bash
# 一次性安装 pre-commit hook（复制到 .git/hooks/pre-commit）
pnpm hooks:install
```

安装后，`git commit` 时若 staged 变更涉及 `skills/` 或 `.codebuddy-plugin/`，会自动执行 `pnpm mp:check`：

- 元数据与 frontmatter **一致** → 放行
- 元数据**过期** → 阻止提交，提示执行 `pnpm mp`
- 确认无误可强制跳过：`git commit --no-verify`

> `scripts/hooks/pre-commit` 有更新时，需重新执行 `pnpm hooks:install`。

## ⚙️ lib/（配置加载工具）

提供 `config/org.yaml` 的读取能力，供各脚本和 skill 复用。

| 文件 | 语言 | 调用方 |
|------|------|--------|
| `load-config.py` | Python 3 | `pnpm config:check`、Python 脚本 |
| `load-config.sh` | Bash | Shell 脚本、skill 内部脚本 |
