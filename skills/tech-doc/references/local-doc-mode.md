# 本地文档模式（Local Doc Mode）

> tech-doc 兼容模式：当用户未配置 wiki 平台时，技术方案等文档自动降级到本地目录创建。

## 一、模式切换逻辑

tech-doc 启动时读取 `config/org.yaml` 中的 `tech_docs_mode`：

| tech_docs_mode | doc_platform_url | 行为 |
|:--:|:--:|------|
| `auto`（默认） | 非空 | 使用 wiki 平台 API 创建/更新文档 |
| `auto`（默认） | 空 | 降级为本地模式（`~/.codebuddy/tech-docs/`） |
| `local` | 任意 | 始终使用本地模式 |
| `wiki` | 非空 | 仅使用 wiki 平台 |
| `wiki` | 空 | 报错提示用户配置 `doc_platform_url` |

## 二、目录结构

类似 devlog 的设计，本地文档目录默认为 `~/.codebuddy/tech-docs/`（可通过 `tech_docs_dir` 配置）：

```
~/.codebuddy/tech-docs/
├── feat/                    # 新功能
│   └── 20260801_my-feature.md
├── fix/                     # 修复
│   └── 20260715_bug-fix.md
├── opt/                     # 优化
├── refactor/                # 重构
├── tech-sharing/            # 技术分享
│   └── 20260720_react-patterns.md
├── release-doc/             # 发布文档
│   └── 20260801_v2.1.0.md
└── .index.yaml              # 文档索引（可选，方便检索）
```

## 三、文件命名规则

| 文档类型 | 命名格式 | 子类型 | 示例 |
|---------|---------|--------|------|
| tech-proposal | `{YYYYMMDD}_{slug}.md` | feat / fix / opt / refactor | `20260801_login-refactor.md` |
| tech-sharing | `{YYYYMMDD}_{title-slug}.md` | — | `20260720_react-hooks-best-practices.md` |
| release-doc | `{YYYYMMDD}_{version}.md` | — | `20260801_v2.1.0.md` |

## 四、文档操作

### 创建文档

```markdown
# 执行逻辑（LLM 指令）：

1. 确定文档类型（tech-proposal / tech-sharing / release-doc）
2. 生成文件名（按上述命名规则）
3. 创建 markdown 文件，内容包括：
   - 标题（`# 文档标题`）
   - 元信息：创建日期、作者、状态
   - 正文内容
4. 文件路径即为该文档的唯一标识
```

### 更新文档

```markdown
# 执行逻辑（LLM 指令）：

1. 根据文件路径读取现有内容
2. 按更新需求修改内容
3. 在文件头部追加更新记录（`> 更新于 YYYY-MM-DD：变更描述`）
```

### 查看/搜索文档

使用 `search_file` 和 `read_file` 即可，无需 MCP 工具。

## 五、与 wiki 模式的 API 对应

| wiki 平台操作 | 本地模式等价操作 |
|-------------|----------------|
| `createDocument(spaceId, parentId, title, content)` | 创建 `.md` 文件 |
| `getDocument(docId)` | `read_file(filePath)` |
| `saveDocument(docId, title, content)` | `write_to_file(filePath, updatedContent)` |
| `metadata(docId)` | 读取文件头部元信息 |
| 空间探测（检查是否已存在） | `search_file` + 文件名模式匹配 |

## 六、注意事项

- 本地模式下无团队协作功能，适合个人使用
- 文档索引 `.index.yaml` 可选，用于快速查找已有文档
- 切换模式后已有本地文档不受影响（不自动迁移到 wiki 平台）
- 和 devlog 的设计理念一致：零配置即可用，有配置更强大
