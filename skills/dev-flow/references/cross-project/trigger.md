# 跨项目联调 · 触发与检测

> 父文件 → `references/cross-project-flow.md`（主流程概览 + 字段定义）。
> 本文件按需加载：`cross_project_signal_detected` 命中时由 step-2 加载。

## 适用场景

| 模式 | 描述 | 示例 |
| --- | --- | --- |
| **A→B→A（三段式）** | A 发现问题，根因在 B，修复 B 后回 A 安装新版本并验证 | my-app 发现 bug → my-lib 修复 → my-app 安装+验证 |
| **A→B（两段式）** | A 分析完成，去 B 执行修改和收尾 | user-project 分析 → my-lib 修复+提交 |
| **A→B→C→A（多段式）** | 涉及多个上下游项目的链式修复 | 少见，按三段式规则递归处理 |

## 知识库平台 在跨项目联调中的特殊价值

> 跨项目场景下 A/B/C 项目的代码本地未必都能访问。知识库平台 全库检索是准确定位上下游消费方代码的单一可行路径。

| 能力 | 适用段 | 价值 |
| --- | --- | --- |
| **消费方反查** | step-2 影响范围 | 修改 B 项目导出函数前，从 知识库平台 网罗 A/C 调用点，避免漏改 |
| **历史类似 MR 检索** | step-3 制定方案 | "上次修改这函数时哪些消费方同时改了？"——用 `git_merge_request` 查联动 |
| **联调目标项目 profile 预检（C3）** | step-2 触发跨项目后 | 检测 B 项目 `_profile.md` 是否存在，提示是否一并 `dev:onboard` |

## 知识库平台 信号 4 强制触发

一旦 `cross_project.enabled=true`，本轮 dev-flow 的 [remote-knowledge.md](../remote-knowledge.md) §一 **信号 4（cross_project_consumer_verify）必定命中**：

- **调用方式**：`data_type=[git, git_doc_platform]`，**不传 `search_domain`**（全库检索，跨项目唯一场景）
- **Token 预算**：≤6000，`top_k=5`，最多 3 次 MCP 调用
- **价值**：拉取 B 项目（消费方）的使用方式与架构文档，让 A 项目改动能提前预判 B 适配点
- **记入 step-1 JSON**：`remote_kb_signals_hit` 含 `"signal_4"`，`remote_kb_calls_made ≥ 1`
- **降级**：调用失败时本轮沉默，不阻塞跨项目流程（衔接 prompt 不依赖 MCP）

## step-2 挂载：跨项目检测钩子

### 触发条件（任一）

1. 根因定位的文件不在当前工作区目录下
2. 修改目标是当前项目的**依赖包**（node_modules 中的包，需在源码仓库修改）
3. 用户明确说"需要去 XX 项目修改"
4. 分析发现问题出在上游组件库/公共包
5. **`package.json` 含内部组件库依赖**（隐式跨项目信号，结合需求描述判断是否影响共享逻辑）

### 检测执行

```text
step-2 影响范围报告完成后：

1. 扫描文件清单中所有文件路径
2. 判断是否有文件不在当前 workspace 下
3. 判断是否有依赖包需要修改源码
4. 扫描 package.json dependencies，检查内部组件库依赖
5. 任一命中 → 触发跨项目流程 → 标记 cross_project=true

```

### 知识库平台 辅助反查（标记 cross_project=true 后立即执行）

在生成衔接 prompt 之前，必须进行一次 知识库平台 全库反查以补给影响面：

```text
工具：    use_mcp_tool(server={remote_kb|knowledge}, tool=knowledgebase_search)
参数：    knowledge_uuid: your-knowledge-base-uuid
data_type:      git
query:          "{待修改的导出符号/组件名/包导出路径}"
keyword:        "{中英变体 ≥3}"

# 不传 search_domain → 全库检索
预算：    ≤2k token（top_k=5）

```

**返回处理**：

- 命中的仓库路径 → 提取消费方项目名单，写入 `cross_project.consumers: [projectA, projectC]`
- 消费方列表追加到影响范围表格，标签 `[remote-kb/git]`
- **命中 0 条**：仅提醒"未扫到其他消费方，仅修 B 项目即可"，不阻塞流程
- 超时/失败 → 降级，提醒用户手动确认消费方列表

### 历史类似 MR 检索（B 项目 step-3 前可选）

```text
data_type: git_merge_request
filter:    { title: { $regex: "{关键词}" }, state: "merged" }
作用：     识别"以前改这个函数时同时改动了哪些消费方"的联动历史

```

### 触发后行为（step-2 末尾）

1. **标记**：在工作上下文 YAML 头部写入 `cross_project` 字段（详见父文件）
2. **生成 B 项目衔接 prompt** → 详见 [handoff.md](./handoff.md)
3. **交互式选项**（**必须用 `ask_followup_question` 弹出**）：

- 📋 复制衔接 prompt（去 B 项目新对话粘贴；当前流程在 step-2 暂存）
- ⏭️ 当前项目继续（如 monorepo 场景，不走跨项目流程）
- ✏️ 调整项目信息（修改 B 项目名称/路径等）

1. 用户选「复制衔接 prompt」时：工作上下文 status → `paused_for_cross_project`；`cross_project.status = pending_fix`；恢复指令更新为跨项目恢复说明
