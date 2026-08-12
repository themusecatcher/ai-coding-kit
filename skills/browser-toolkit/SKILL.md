---
name: browser-toolkit
description: "浏览器自动化工具智能路由中枢。面向「我该用哪个工具」的决策场景，在 agent-browser、Playwright、Chrome DevTools MCP 三大执行后端之间基于任务特征自动推荐最优方案，并支持多工具协同编排。触发场景：工具选型咨询、页面性能调试（页面慢/LCP/CLS/网络瀑布/内存泄漏）、连接真实浏览器（我当前的Chrome/已登录状态/remote-debugging）、跨浏览器兼容（Safari/Firefox/WebKit）、混合工作流（先调试再复现再固化测试）。注意：单一工具的具体命令用法请用专门 skill（agent-browser / e2e-testing）。"
---

# browser-toolkit — 浏览器自动化工具智能路由

> **定位**：浏览器自动化的「决策中枢/调度层」。根据任务意图自动路由到最合适的执行工具。
> **与 agent-browser skill 边界**：本 skill 负责「选哪个工具」，agent-browser skill 负责「怎么用 agent-browser」。

---

## ⚡ 快速决策矩阵（60 秒速查）

| 任务特征 | 首选工具 | 理由 |
|---------|---------|------|
| AI 驱动自动化（登录/填表/爬取/下单） | **agent-browser** | LLM-friendly snapshot，最省 token |
| 页面性能分析（LCP/CLS/TTI/CPU trace） | **Chrome DevTools MCP** | 原生 Performance Insights |
| 网络请求/控制台错误排查 | **Chrome DevTools MCP** | 完整 DevTools 能力 |
| 连接用户当前 Chrome（复用已登录态） | **Chrome DevTools MCP** | 官方原生支持 |
| 端到端测试 & CI 回归 | **Playwright（脚本）** | 生态最完整，POM 成熟 |
| 跨浏览器测试（Firefox/WebKit/Safari） | **Playwright** | 唯一支持全内核 |
| iOS 真机/模拟器测试 | **agent-browser** | 内置 Appium 集成 |
| 内存泄漏调查 | **Chrome DevTools MCP** | `take_memory_snapshot` |
| 批量 URL 验证/爬取 | **agent-browser**（并行 sessions） | CLI 易并行 |
| 一次性 AI 交互任务（无 CLI） | **Playwright MCP** | 开箱即用，免装 CLI |

> 矩阵未覆盖？→ 加载 `modules/decision-engine.md` 做三维决策。

---

## 🧭 模块懒加载路由

按意图识别加载对应模块（只加载一个，避免 token 浪费）：

| 意图 | 加载模块 | 触发关键词 |
|------|---------|----------|
| 不确定用哪个 | `modules/decision-engine.md` | "用什么工具"/"哪个合适"/"帮我选"/"对比 xx 工具" |
| 调试真实页面 | `modules/devtools-mcp-adapter.md` | "性能"/"LCP"/"CLS"/"内存泄漏"/"网络瀑布"/"已登录状态"/"我的 Chrome"/"remote-debugging" |
| 自动化执行（仅决策时） | `modules/agent-browser-adapter.md` | 仅当用户**明确询问选型**时触发（如"自动化该用 AB 还是 PW"）；单纯"截图/填表/登录"直接走 `agent-browser` skill |
| 编写测试 | `modules/playwright-adapter.md` | "E2E"/"回归"/"跨浏览器"/"CI 集成"/"Playwright MCP vs ..." |
| 多工具协同 | `modules/hybrid-workflows.md` | "先调试再复现"/"bug 复现+回归测试"/"端到端调试" |

### 加载方式

```
# 示例：用户说"帮我分析下这个页面为什么慢"
read_file("modules/devtools-mcp-adapter.md")

# 示例：用户说"不确定用什么工具"
read_file("modules/decision-engine.md")
```

---

## 🎯 三维决策摘要

当矩阵无法命中时，按三维特征打分：

```
维度 1：任务目标（What）
  ├─ 自动化执行     → agent-browser
  ├─ 测试验证      → Playwright
  └─ 调试分析      → Chrome DevTools MCP

维度 2：浏览器状态（Where）
  ├─ 全新隔离实例   → agent-browser / Playwright
  ├─ 用户当前 Chrome → Chrome DevTools MCP
  └─ 跨浏览器内核   → Playwright

维度 3：执行主体（Who）
  ├─ AI 实时决策    → agent-browser / Playwright MCP
  ├─ 人维护脚本库   → Playwright（脚本）
  └─ AI 辅助人调试  → Chrome DevTools MCP
```

> 详细打分表、场景样例 → `modules/decision-engine.md`

---

## 🛡️ 智能降级策略（可用性兜底）

按优先级检测环境可用性：

```
1. agent-browser CLI 可用？ ─── agent-browser --version
   ├─ 是 → 首选
   └─ 否 → 继续 ↓
2. @playwright/cli 可用？ ─── playwright-cli --help
   ├─ 是 → 选它（Playwright 官方 2026 新推，AI 友好 + 跨浏览器）
   └─ 否 → 继续 ↓
3. Chrome 9222 调试端口开放 或 DevTools MCP 已配置？
   ├─ 是 → Chrome DevTools MCP（性能/调试类任务最优）
   └─ 否 → 继续 ↓
4. 直接用 Playwright MCP 或脚本（npx 开箱可用）
```

---

## 🚦 边界声明（重要）

为避免与现有 skill 冲突，本 skill **只处理**以下场景：

- ✅ **多工具决策咨询**："这个任务用什么工具"
- ✅ **Chrome DevTools MCP 独占场景**：性能分析、网络抓包、内存快照、复用真实 Chrome
- ✅ **跨工具协同编排**：先调试 → 再复现 → 再固化测试的混合工作流

**不处理**（交给专门 skill）：

- ❌ 纯 agent-browser 命令 how-to → `agent-browser` skill
- ❌ 纯 Playwright 测试代码编写 → `e2e-testing` skill
- ❌ 简单"打开网站"/"截图"/"填表" → 直接走 `agent-browser` skill

---

## 🤔 不确定时的澄清询问

如果用户需求模糊（如"帮我看看这个页面"），先询问：

```
为了给你选最合适的工具，我想确认一下：

1. 🔍 **调试分析**（排查为什么慢/出错/内存泄漏）
2. 🤖 **自动化执行**（批量操作/爬数据/模拟用户）
3. 🧪 **测试验证**（写可回放的测试用例）
4. 🔀 **混合场景**（先调试再复现再固化为测试）

请选 1/2/3/4，或直接描述你想达成的结果。
```

---

## 📚 参考资料

### 模块（按需加载）

| 文档 | 用途 |
|------|------|
| `modules/decision-engine.md` | 三维决策引擎 + 27 组合 + 反模式 + Token 预算 |
| `modules/devtools-mcp-adapter.md` | Chrome DevTools MCP 完整指南（核心差异化） |
| `modules/agent-browser-adapter.md` | 何时委托给 agent-browser skill |
| `modules/playwright-adapter.md` | Playwright 脚本 vs MCP 双模式选型 |
| `modules/hybrid-workflows.md` | 5 个三工具协同工作流 |

### 参考文档（references/）

| 文档 | 用途 |
|------|------|
| `references/tool-comparison.md` | 9 维度工具对比矩阵 |
| `references/common-pitfalls.md` | 三工具 + 跨工具协同共 15 个常见坑 |

### 模板（templates/）

| 文档 | 用途 |
|------|------|
| `templates/debug-live-page.sh` | 启动带 9222 调试端口的 Chrome（安全隔离 profile） |
| `templates/bug-repro-pipeline.sh` | Bug 复现三步流水线（DevTools→AB→PW） |

---

## 🎁 与生态集成

- **独立调用**（已实现）：用户任何工具选型咨询 → 本 skill
- **委托执行**（已实现）：决策后 `use_skill("agent-browser")` 或 `use_skill("e2e-testing")`
- **被 dev-flow 调用**（✅ 已接入）：dev-flow 步骤 1 研究（bug 复现现场采集，信号触发）/ 步骤 5 执行（UI 操作/调试场景智能路由）/ 步骤 6 验证（V4 Browser 进阶场景工具选型前置）均可通过 `use_skill("browser-toolkit")` 按需调用
