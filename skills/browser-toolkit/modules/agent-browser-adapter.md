# agent-browser 适配器

> 本模块**不重复** `agent-browser` skill 的内容，只说明何时委托过去以及与本 skill 的协作方式。

---

## 何时委托给 agent-browser skill

满足以下任一条件时，直接 `use_skill("agent-browser")`：

- 单工具 how-to 咨询（"agent-browser 怎么点击"/"怎么截图"）
- 标准 AI 自动化任务（填表/登录/批量/爬数据/Web 测试）
- 无跨工具协同需求
- 无性能/调试诉求

---

## 本 skill 相对 agent-browser skill 的增量价值

| 维度 | agent-browser skill | browser-toolkit skill |
|------|---------------------|----------------------|
| 职责 | 单工具 how-to | 多工具决策与编排 |
| 输入 | 已知要用 agent-browser | 不确定用哪个 / 需要协同 |
| 输出 | CLI 命令链 | 路由决策 + 可能的多步流水线 |

---

## agent-browser 在决策矩阵中的首选场景

- `(EXEC, ISOLATED, AI)` — AI 驱动的隔离环境自动化
- 并行批量任务（`--session` 隔离）
- iOS 模拟器/真机测试（agent-browser 内置 Appium 集成）
- Token 敏感的大规模爬取（snapshot 最省）
- Chrome DevTools 不可用时的 fallback

---

## 调用范式

```
# 识别到需要 agent-browser → 委托
use_skill("agent-browser")
```

后续所有 CLI 命令细节交由 agent-browser skill 处理。本 skill 仅保留"何时选 agent-browser"的决策逻辑。
