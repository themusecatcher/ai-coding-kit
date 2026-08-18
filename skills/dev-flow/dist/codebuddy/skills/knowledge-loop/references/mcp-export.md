# 跨工具导出与 MCP 集成（Cross-Tool Export）

> 按需加载：用户询问跨工具使用、MCP 集成、导出知识库时。

## 设计目标

使知识库不仅在 CodeBuddy 中可用，也能被 Claude Code、Cursor、Windsurf 等任何支持 MCP 或 Markdown 指令的 AI 编程工具消费。

## 导出命令

| 命令 | 快捷 | 说明 |
|------|------|------|
| `dev:kb export --format=claude-md` | `dev:k e claude` | 导出为 CLAUDE.md 兼容格式 |
| `dev:kb export --format=cursor-rules` | `dev:k e cursor` | 导出为 .cursorrules 格式 |
| `dev:kb export --format=mcp-resources` | `dev:k e mcp` | 生成 MCP Resource 定义文件 |
| `dev:kb export --format=markdown` | `dev:k e md` | 导出为独立 Markdown 知识包 |

---

## 导出格式详情

### 1. CLAUDE.md 格式（Claude Code 兼容）

将项目知识导出为 Claude Code 可消费的 `CLAUDE.md` + `.claude/rules/` 结构：

```
{project-root}/
├── CLAUDE.md                          # 项目概览 + 知识索引（从 _index.md 生成）
└── .claude/rules/
    ├── {module}-data-model.md         # 从 knowledge/{module}/data-model.md 生成
    ├── {module}-api.md                # 从 knowledge/{module}/api.md 生成
    ├── {module}-logic.md              # 从 knowledge/{module}/logic.md 生成
    ├── {module}-pitfalls.md           # 从 knowledge/{module}/pitfalls.md 生成
    └── {module}-ui.md                 # 从 knowledge/{module}/ui.md 生成
```

**转换规则**：
- YAML frontmatter 转换为 Claude Code rules 的 `paths` frontmatter（按模块核心文件路径匹配）
- `verified` 知识直接输出（`release.verified_in_production: true` 的优先）
- `scanned` 知识添加注释 `<!-- auto-scanned, verify before relying on -->`
- `stale` / `draft` 知识不导出（质量不足）
- `_patterns/*.md` 导出为不限定路径的通用规则
- `_recipes/*.md` 导出为独立规则文件

**paths 映射示例**：
```yaml
---
paths:
  - "src/views/AccountSetting/components/MeetingSetting/**"
---
# 会议设置 - 易错点
（从 pitfalls.md 导出的内容）
```

### 2. Cursor Rules 格式

将项目知识导出为 `.cursorrules` 文件：

```
{project-root}/.cursorrules
```

**转换规则**：
- 合并所有 `verified` 知识为单文件（`release.verified_in_production: true` 的排在前面）
- 按模块分章节组织
- 优先展示 pitfalls（易错点最有指导价值）
- 控制总长度 ≤ 500 行（Cursor 对 rules 文件大小敏感）
- 超出时按 `stability.confidence_score` 倒序裁剪（低分先裁，保留高分条目）

### 3. MCP Resources 格式

生成 MCP Server 配置，将知识库暴露为可查询的 MCP Resources：

**产出文件**：`~/.codebuddy/knowledge/{project-name}/_mcp-resources.json`

```json
{
  "resources": [
    {
      "uri": "knowledge://{project-name}/{module}/overview",
      "name": "{module} 模块概述",
      "mimeType": "text/markdown"
    },
    {
      "uri": "knowledge://{project-name}/{module}/{topic}",
      "name": "{module} - {topic}",
      "mimeType": "text/markdown"
    }
  ],
  "tools": [
    {
      "name": "search_knowledge",
      "description": "搜索项目知识库",
      "inputSchema": {
        "type": "object",
        "properties": {
          "query": { "type": "string", "description": "搜索关键词" },
          "project": { "type": "string", "description": "项目名（可选，默认当前项目）" }
        },
        "required": ["query"]
      }
    },
    {
      "name": "get_knowledge",
      "description": "获取指定模块的知识",
      "inputSchema": {
        "type": "object",
        "properties": {
          "project": { "type": "string" },
          "module": { "type": "string" },
          "topic": { "type": "string", "enum": ["overview", "data-model", "api", "logic", "ui", "pitfalls"] }
        },
        "required": ["project", "module"]
      }
    }
  ]
}
```

> MCP Server 的实际运行时实现属于阶段 3（平台级），当前仅生成配置定义文件供未来接入。

### 4. Markdown 知识包

将项目知识导出为独立可分享的 Markdown 包：

**产出目录**：`~/knowledge-export/{project-name}/`

```
{project-name}/
├── README.md                          # 从 _index.md 生成，含目录导航链接
├── {module}/
│   ├── overview.md
│   ├── data-model.md
│   ├── api.md
│   ├── logic.md
│   ├── ui.md
│   └── pitfalls.md
└── patterns/
    └── {pattern-name}.md
```

**适用场景**：分享给不使用任何 AI 编程工具的团队成员，作为项目文档补充。

---

## 导出执行流程

1. 确定项目名称（同管理模式前置检查）
2. 读取 `_index.md` 获取模块清单
3. 按目标格式转换每个知识文件
4. 向用户确认导出位置和内容摘要
5. 写入目标位置
6. 输出导出结果

```text
📤 知识库导出完成：
├── 格式：CLAUDE.md + .claude/rules/
├── 项目：user-project
├── 导出模块：meeting-setting（5 个知识文件）
├── 导出位置：/path/to/user-center/
└── 跳过：0 个文件（无 stale/draft 知识）
```

---

## 团队 AI 基础设施整合路径

### 短期整合（当前可做）

| 整合点 | 方式 | 说明 |
|--------|------|------|
| Claude Code | `dev:kb export --format=claude-md` | 导出到项目目录，纳入 git |
| Cursor | `dev:kb export --format=cursor-rules` | 导出 .cursorrules |
| 其他 AI 工具 | `dev:kb export --format=markdown` | 通用 Markdown 格式 |

### 中期整合（Knowledge MCP Server）

构建独立 MCP Server 进程，暴露 `search_knowledge` / `get_knowledge` / `deposit_knowledge` 三个工具：

```
┌──────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│  CodeBuddy   │────▶│                  │◀────│  Claude Code        │
│  (Skill 调用) │     │  Knowledge MCP   │     │  (MCP Client)       │
└──────────────┘     │  Server          │     └─────────────────────┘
                     │                  │
┌──────────────┐     │  - search        │     ┌─────────────────────┐
│  Cursor      │────▶│  - get           │◀────│  Windsurf / Other   │
│  (MCP Client) │     │  - deposit       │     │  (MCP Client)       │
└──────────────┘     └────────┬─────────┘     └─────────────────────┘
                              │
                     ~/.codebuddy/knowledge/
```

### 长期整合（CI/CD + 任务平台）

| 整合点 | 触发方式 | 行为 |
|--------|---------|------|
| 任务平台 新需求创建 | Webhook → Knowledge MCP | 自动检索相关知识，推荐到需求评论 |
| Git MR 合并 | CI Pipeline → `dev:kb scan --diff` | 知识漂移自动检测 |
| 部署上线 | CD Pipeline → 写入 `release.released=true` + `verified_in_production=true` | 标记 release 字段，不修改 confidence 级别 |
| Code Review | MR 评审 → 知识推荐 | 推荐评审者关注的 pitfalls |
