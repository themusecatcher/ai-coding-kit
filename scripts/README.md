# Scripts

> CodeBuddy 配置管理脚本集合

## 📋 脚本列表

| 脚本 | 说明 |
|------|------|
| `sync.sh` | 从 `~/.codebuddy` 同步 skills/agents/rules 到本 Git 仓库 |
| `generate_marketplace.py` | 生成 `.codebuddy-plugin/marketplace.json` 和各 skill 的 `plugin.json` |
| `lib/load-config.py` | Python 配置加载工具（读取 `config/org.yaml`） |
| `lib/load-config.sh` | Shell 配置加载工具（读取 `config/org.yaml`） |

## 🔄 sync.sh

将本地 `~/.codebuddy` 下的 `skills`、`agents`、`rules` 目录同步到仓库对应目录，并提供交互式 Git 提交与推送。

### 使用方式

在仓库根目录（`ai-coding-kit/`）下通过 npm scripts 调用：

```bash
# 同步全部（skills + agents + rules）
npm run sync

# 仅同步 skills
npm run sync:skills

# 仅同步 agents
npm run sync:agents

# 仅同步 rules
npm run sync:rules

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
npm run mp
```

### 生成产物

| 产物 | 路径 | 说明 |
|------|------|------|
| 市场清单 | `.codebuddy-plugin/marketplace.json` | 所有 skill 的汇总元数据 |
| 插件清单 | `skills/<name>/plugin.json` | 每个 skill 目录下的独立清单 |

### 校验规则

脚本会检查每个 skill 的 `description` 字段质量，如果发现低质量占位符（如 "skill-name skill"）或描述过短，会报错退出并提示具体 skill 名称。

## ⚙️ lib/（配置加载工具）

提供 `config/org.yaml` 的读取能力，供各脚本和 skill 复用。

| 文件 | 语言 | 调用方 |
|------|------|--------|
| `load-config.py` | Python 3 | `npm run config:check`、Python 脚本 |
| `load-config.sh` | Bash | Shell 脚本、skill 内部脚本 |
