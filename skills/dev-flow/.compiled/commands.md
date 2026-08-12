# dev: 命令速查（预编译常量）

> 本文件是所有 `dev:` 命令的精简索引。完整说明见 `references/skill-full.md`。

## 命令表

| 命令 | 快捷 | 作用 | 详细规范 |
| --- | --- | --- | --- |
| `dev-flow` / `dev:` | — | 进入统一流程（步骤4智能评估深度） | `flow.md` |
| `dev:sync` | `dev:s2` | 全量文档同步，支持任意时机调用 | `references/in-flow-sync.md` |
| `--fast` | — | 附加精简交互模式（可组合任意命令） | `references/interaction-mode.md` |
| `--micro` | — | 显式启动 micro-fix 模式（单文件 + ≤10 行 + 已知位置） | `references/micro-fix-light.md` |
| `dev:fix --drift` | — | 显式触发需求漂移（完成后自动 dev:sync + 门控校验） | `references/drift-handling.md` |
| `dev:fix --iteration` | — | 显式触发迭代修复（调 iteration-fix-classify.sh） | `references/iteration-fix.md` |
| `dev:kb` | `dev:k` | 知识库管理（查看/沉淀/扫描/搜索） | `use_skill('knowledge-loop')` |
| `dev:status` | `dev:st` | 当前工作上下文进度概览 | `scripts/status.sh` |
| `dev:status --trace` | — | 实时观测（Token/红牌/步骤耗时） | `scripts/status.sh` |
| `dev:metrics` | `dev:m` | 度量查看 | `references/metrics-rules.md` |
| `dev:metrics --all` | — | 全部历史 | — |
| `dev:metrics --trend` | — | 度量趋势分析 | — |
| `dev:metrics --report {需求ID}` | — | 指定需求度量报告 | — |
| `dev:metrics --dashboard` | — | 生成可视化仪表盘 | `references/metrics-rules.md` |
| `dev:onboard` | `dev:ob` | 项目首次接触/profile 刷新 | `references/onboard-flow.md` |
| `dev:flowchart` | `dev:chart` | 生成/更新 dev-flow 流程图（md + html + png） | `flowchart/SPEC.md` |
| `dev:help` | `dev:h` | 显示帮助信息（命令/模式/工作流） | `references/help.md` |

## 命令规范

- `dev:` 前缀可不加 `/`（`/dev-flow` 与 `dev-flow` 等价）
- 命令与自然语言触发等效
- 命令组合：`dev: --fast 修复登录问题` = 统一流程 + streamlined 模式

## 未知命令处理

遇到以 `dev:` 开头但不在此表的命令 → `read_file("references/skill-full.md")` 查找完整命令列表。
