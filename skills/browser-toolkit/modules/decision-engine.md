# 决策引擎（Decision Engine）

> 三维特征打分 + 场景样例库，用于 SKILL.md 速查矩阵未覆盖时的深度决策。

---

## 三维特征打分法

对任务提取三个维度的特征，每个维度选一个标签，得到 `(A, B, C)` 三元组，查下表定路由。

### 维度 A：任务目标（What）

| 标签 | 识别信号 |
|------|---------|
| `EXEC`（自动化执行） | 做某事/操作/登录/下单/填表/爬取/截图/批量 |
| `TEST`（测试验证） | 测试/E2E/回归/断言/CI/POM |
| `DEBUG`（调试分析） | 为什么/排查/慢/卡/泄漏/性能/瀑布/错误 |

### 维度 B：浏览器状态（Where）

| 标签 | 识别信号 |
|------|---------|
| `ISOLATED` | 干净环境/新建实例/不影响我的浏览器 |
| `LIVE` | 我的 Chrome/当前浏览器/已登录/活跃会话 |
| `CROSS` | Safari/Firefox/WebKit/跨浏览器/兼容性 |

### 维度 C：执行主体（Who）

| 标签 | 识别信号 |
|------|---------|
| `AI` | AI 实时决策/对话式/一次性任务 |
| `HUMAN` | 写代码/维护脚本/加入仓库/CI 回归 |
| `HYBRID` | AI 辅助人类调试/边看边改 |

---

## 三元组 → 工具映射表（27 种组合，核心 12 组）

| (A, B, C) | 推荐工具 | 备选 | 典型场景 |
|-----------|---------|------|---------|
| (EXEC, ISOLATED, AI) | **agent-browser** | Playwright MCP | AI 帮我登录并下单 |
| (EXEC, LIVE, AI) | **Chrome DevTools MCP** | agent-browser --auto-connect | 在我当前 Chrome 里填这个表单 |
| (EXEC, CROSS, AI) | **Playwright（脚本）** | - | Safari 上自动走通流程 |
| (EXEC, ISOLATED, HUMAN) | **Playwright（脚本）** | agent-browser | 写个定时爬虫 |
| (TEST, ISOLATED, HUMAN) | **Playwright** | - | 端到端测试套件 |
| (TEST, CROSS, HUMAN) | **Playwright** | - | 跨浏览器回归 |
| (TEST, ISOLATED, AI) | **Playwright MCP** | agent-browser | 临时写个测试验证 |
| (DEBUG, LIVE, HYBRID) | **Chrome DevTools MCP** | - | 这个页面为什么慢 |
| (DEBUG, LIVE, AI) | **Chrome DevTools MCP** | - | AI 分析我线上页面 |
| (DEBUG, ISOLATED, AI) | **Chrome DevTools MCP**（新启动） | agent-browser profiler | 隔离环境下复现 + 分析 |
| (DEBUG, CROSS, *) | **Playwright** + 手动 DevTools | - | Safari 独有性能问题 |
| (*, LIVE, HUMAN) | **Chrome DevTools MCP**（浏览器亲和） | - | 浏览器里手动调试 |

> 💡 若 agent-browser 不可用且任务在 `(EXEC, *, AI)` 象限，可考虑 `@playwright/cli`（Playwright 2026 官方新推，专为 coding agent 优化，Token 成本接近 agent-browser）：
>
> - `npm i -g @playwright/cli && playwright-cli install --skills`
> - 详见 [microsoft/playwright-cli](https://github.com/microsoft/playwright-cli)

---

## 反模式检测（主动纠偏）

检测到以下错配时，主动提示用户：

| 用户说法 | 潜在错配 | 纠偏建议 |
|---------|---------|---------|
| "用 Playwright 测首屏 LCP" | Playwright 不是性能分析工具 | → Chrome DevTools MCP 的 `performance_start_trace` 更准 |
| "用 DevTools MCP 跨浏览器测" | DevTools MCP 只支持 Chrome | → Playwright 支持 Chromium/Firefox/WebKit |
| "用 agent-browser 连接我当前 Chrome" | 可以但不是首选 | → DevTools MCP 的 list_pages / select_page 更顺滑 |
| "用 DevTools MCP 做 CI 回归" | 缺 CI 集成/断言/报告 | → Playwright（脚本）+ POM |
| "用 agent-browser 做性能 trace" | 有 profiler 但不如 DevTools 丰富 | → Chrome DevTools MCP |
| "写个 Playwright 脚本让 AI 对话式操作" | 脚本模式不适合实时对话 | → agent-browser 或 Playwright MCP |

---

## Token 预算对比（选最省的）

| 操作 | agent-browser | Playwright MCP | DevTools MCP |
|------|---------------|----------------|--------------|
| 页面 snapshot | 500-2K ⭐⭐⭐⭐⭐ | 3K-8K ⭐⭐⭐ | 5K-15K ⭐⭐ |
| 网络请求列表 | 需 eval 取 | 直接返回 | 直接返回（最详细） |
| 性能 trace | trace.json 输出 | 不支持 | 直接返回 insights |
| 截图 | 路径返回 | 路径返回 | 路径返回 |

> **Token 敏感场景优先级**：agent-browser > Playwright MCP > DevTools MCP
>
> 💡 若必须用 DevTools MCP 但在意 token，加 `--slim` 只暴露 3 个核心工具（导航/截图/执行脚本），可减少 ~70% 工具描述 token；或通过 `--categoryExtensions=false`/`--categoryNetwork=false` 按需关闭工具类别。
