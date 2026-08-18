# knowledge-loop — 本地代码知识沉淀与复用

> 📌 **本 README 为人类阅读导航**，AI 运行时入口为 `SKILL.md`。

一句话定位：**dev-flow 的唯一本地代码知识存储与检索层**，让 AI 越用越聪明。AI 自动沉淀每次开发中接触到的接口/数据模型/业务逻辑/UI/易错点，在后续需求中自动检索复用。

---

## 与 知识库平台/remote_kb 的边界（重要）

| 维度 | **knowledge-loop**（本 Skill） | **知识库平台 / remote_kb MCP** |
|------|-------------------------------|------------------------|
| 存储位置 | 本地 `~/.codebuddy/knowledge/{project}/` | 远程 `knowledge_uuid` |
| 可写性 | ✅ 可写（强制沉淀） | ❌ 只读（被动检索） |
| 内容形态 | Markdown + YAML（5 主题文件） | git/git_doc_platform/commit/MR 索引 |
| 数据来源 | AI 沉淀 + 用户验证 | 项目源码 + doc_platform + commit + MR |
| 调用方式 | `use_skill('knowledge-loop')` | `use_mcp_tool(server=remote_kb, tool=knowledgebase_search)` |
| 触发词归属 | 「代码知识」「本地知识库」「沉淀知识」 | 「MCP 知识库」「knowledge_uuid」「remote_kb」「git_doc_platform」 |

> ⚠️ 用户说「MCP 知识库」「knowledge_uuid」「remote_kb」「doc_platform」时**不要触发本 skill**——那是 知识库平台 的范畴。

---

## 何时使用

| 场景 | 触发方式 | 自动加载文件 |
|------|----------|------------|
| **dev-flow 步骤 1/5** 研究/编码时检索已有知识 | 由 dev-flow 自动调用 | `modes/retrieve.md` |
| **dev-flow 步骤 7/10/收尾** 沉淀本次开发知识（强制，禁止跳过） | 由 dev-flow 自动调用 | `modes/deposit.md` |
| 用户主动用 `dev:kb` / `dev:k` / `dev:kl` 命令管理 | 命令触发 | `modes/manage.md` |
| 非 dev-flow 对话中检测到有价值知识 | 自动捕获 | `modes/auto-capture.md` |
| 不确定时 | 默认进入管理模式 | `modes/manage.md` |

---

## 目录结构

```
knowledge-loop/
├── README.md                          # 本文件：人类导航
├── SKILL.md                           # AI 运行时入口（路由规则 + dev-flow 集成映射 + 命令清单）
│
├── modes/                             # 4 种工作模式（路由后按需加载）
│   ├── retrieve.md                    # 检索模式（dev-flow 步骤 1/5 调用）
│   ├── deposit.md                     # 沉淀模式（步骤 7/10/收尾强制调用）
│   ├── manage.md                      # 管理模式（dev:kb 命令）
│   └── auto-capture.md                # 自动捕获模式（非 dev-flow 对话中识别有价值知识）
│
├── references/                        # 参考资料（按需加载）
│   ├── schema.md                      # 目录结构规范 + 文件格式 + 项目名称映射
│   ├── confidence.md                  # 置信度体系 + 代码漂移检测 + 异步审计与反悔机制
│   ├── lifecycle.md                   # 生命周期（过期规则/刷新机制/废弃流程/跨项目模式提升）
│   ├── team-sharing.md                # 团队共享方案（Phase 2 扩展，规划中）
│   └── mcp-export.md                  # 跨工具导出与 MCP 集成
│
└── templates/                         # 知识沉淀模板（首次创建项目知识库时使用）
    ├── _index.md.tpl                  # 项目知识索引模板
    ├── _overview.md.tpl               # 模块概述模板
    ├── design-intent.md.tpl           # 设计意图模板
    └── topic.md.tpl                   # 主题文件模板
```

---

## 存储位置（重要）

所有知识统一沉淀到 `~/.codebuddy/knowledge/{project-name}/`，三级结构（项目 → 模块 → 主题）：

```
~/.codebuddy/knowledge/
├── _global/                           # 全局说明与模板规范
│   ├── README.md
│   └── schema.md
│
├── {project-name}/                    # L1 项目级（如 user-center / my-project）
│   ├── _index.md                      # 项目知识索引（必读入口）
│   │
│   ├── {module}/                      # L2 模块级（按业务模块切分）
│   │   ├── _overview.md                #   模块概述 + 核心文件 + 变更历史
│   │   ├── data-model.md               #   数据模型
│   │   ├── api.md                      #   接口协议
│   │   ├── logic.md                    #   业务逻辑
│   │   ├── ui.md                       #   UI 结构
│   │   └── pitfalls.md                 #   易错点
│   │
│   ├── _patterns/                     #   跨模块设计模式
│   └── _recipes/                      #   操作手册（How-to）
```

> ⚠️ **集中存储原则**：knowledge/ 必须在 `~/.codebuddy/knowledge/`，**严禁在项目目录中创建**。

---

## dev-flow 集成映射

| dev-flow 步骤 | 模式 | 行为 |
|---------------|------|------|
| 步骤 1（研究定位） | 检索 | 自动检索项目知识，输出匹配结果 |
| 步骤 5（编码） | 检索 | 按改动文件类型动态加载对应主题知识 |
| 步骤 7（清理+Commit） | 沉淀 | 标准执行/批次最后一批：**强制沉淀**（禁止跳过） |
| 步骤 10（归档交付） | 沉淀 | 完整执行：**强制沉淀**（禁止跳过） |
| 收尾环节 H.3 | 沉淀 | 收尾模式：**强制沉淀**（禁止跳过） |
| `dev:kb` 命令 | 管理 | 查看 / 扫描 / 搜索 / 健康检查 / 验证 / 可视化 |

---

## 常用命令速查

所有命令支持长写法（`dev:kb`）和短写法（`dev:k` / `dev:kl`）：

| 用户输入 | 行为 |
|---------|------|
| `dev:kb` / `dev:k` / "查看代码知识库" | 进入管理模式（展示概览 + 选项） |
| `dev:kb scan [module\|--all\|--diff]` / `dev:k sc` | 扫描代码并生成知识（单模块/全量/增量） |
| `dev:kb search xxx` / `dev:k s xxx` / "搜索知识库 xxx" | 搜索知识 |
| `dev:kb sync` / `dev:k sy` / "git pull 后对齐知识库" | 双场景同步：他人改动漂移检测 + 自己 pending 升级 verified |
| `dev:kb health` / `dev:k h` | 健康检查（覆盖率 / 过期项 / 漂移项） |
| `dev:kb audit` / `dev:k a` | 审计自动升级知识（含 `--all` / `--archived` / `--reject <id>` / `--confirm <id>`） |
| `dev:kb verify` / `dev:k v` | 验证知识与代码一致性 |
| `dev:kb dashboard` / `dev:k d` | 知识地图可视化 |
| `dev:kb export --format=xxx` / `dev:k e xxx` | 导出知识库 |
| `dev:kb promote <pattern>` | 跨项目模式提升（局部模式 → 全局模式） |

> 完整命令路由表见 `SKILL.md` §「独立使用」。

---

## 核心原则

- **唯一本地来源**：本 Skill 是 dev-flow 的唯一**本地代码知识**检索和沉淀目标（远程语义知识用 知识库平台/remote_kb）
- **宁多勿少**：不仅沉淀本次需求改动，还要全面沉淀开发过程中接触到的所有模块知识
- **按需加载**：知识分主题存储在独立文件中，AI 按需加载而非全量加载，优化 token 效率
- **AI 友好**：Markdown 格式，带 YAML frontmatter 元数据，机器可读可写
- **强制沉淀**：每次需求完成都必须沉淀，禁止以任何理由跳过
- **集中存储**：knowledge/ 统一存储在 `~/.codebuddy/knowledge/`，禁止在项目目录中创建

---

## 与其他 Skill 的边界

| Skill | 与 knowledge-loop 的边界 |
|-------|-------------------------|
| `dev-flow` | dev-flow 在步骤 1/5/7/10/收尾按需调用本 Skill；本 Skill 不主动接管 dev-flow 流程 |
| `tech-doc` | tech-doc 生成 devlog（本次改动记录）；本 Skill 沉淀**项目长期知识**，二者互补 |
| `remote_kb` MCP | remote_kb 是只读远程语义检索；本 Skill 是可写本地沉淀，二者互补不冲突 |
