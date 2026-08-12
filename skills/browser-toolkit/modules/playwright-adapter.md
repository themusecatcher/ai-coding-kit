# Playwright 适配器

> Playwright 官方提供 **三种**工作模式：**脚本模式**（面向开发者）、**MCP 模式**（面向 AI，功能最多）、**CLI 模式**（`@playwright/cli`，官方 2026 新推，Token 最省）。本 skill 帮你选对。

---

## 🎯 三模式对比（核心区别）

| 维度 | 脚本模式（@playwright/test） | MCP 模式（@playwright/mcp） | CLI 模式（@playwright/cli）⭐ 2026 新推 |
|------|------------------------------|------------------------------|----------------------------------|
| 入口 | `npx playwright test` | `npx @playwright/mcp@latest` | `npm i -g @playwright/cli && playwright-cli` |
| 使用者 | 人（开发者） | AI（MCP 客户端） | AI（coding agent，Token 最省） |
| 产出 | 可回放测试文件 `*.spec.ts` | 一次性动作 | 一次性动作 / 脚本序列 |
| Token 消耗 | 中（人写不关注） | 高（完整 a11y tree） | **低**（命令行，不加载完整 schema） |
| CI 集成 | ✅ 原生 | ❌ 需封装 | ⚠️ 可脚本化 |
| 跨浏览器 | ✅ Chromium/Firefox/WebKit | ✅（同内核） | ✅（同内核） |
| 断言 | ✅ `expect()` 丰富 | 靠 AI 自行判断 | 有 `browser_verify_*` 类命令 |
| 官方推荐用户 | 开发者 | 适同于长会话的 agentic loop | **coding agent**（官方明确推荐这种） |
| 典型场景 | 回归测试/CI | IDE 内 AI 对话 | agent-browser 不可用时的最佳替代 |

---

## 选型决策

### ✅ 选脚本模式的场景

- 需要固化为仓库内长期维护的测试
- 需要 CI 集成（GitHub Actions/GitLab CI）
- 跨浏览器矩阵（Chromium + Firefox + WebKit）
- 需要 POM（Page Object Model）抽象
- 有明确断言和回归需求

→ **委托给 `e2e-testing` skill**（已存在，含完整 POM + CI 范式）

### ✅ 选 Playwright MCP 的场景

- 一次性 AI 驱动任务（但不想装 agent-browser CLI）
- 需要跨浏览器内核（agent-browser 默认 Chromium）
- 已在用 Playwright MCP 的 IDE 环境
- 临时验证脚本不需要固化

### ❌ 不选 Playwright 的场景

- Token 极度敏感 → agent-browser（snapshot 更省）
- 需要性能 trace → Chrome DevTools MCP
- 需要连接用户真实 Chrome → Chrome DevTools MCP
- 需要 iOS 真机 → agent-browser（内置 Appium）

---

## Playwright MCP 安装（IDE 配置）

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    }
  }
}
```

---

## Playwright MCP 核心工具（65+ 个，以官方 README 为准）

> 源：<https://github.com/microsoft/playwright-mcp>

| 分类 | 工具示例 |
|------|---------|
| 导航 | `browser_navigate` / `browser_navigate_back` |
| 交互 | `browser_click` / `browser_type` / `browser_hover` / `browser_drag` / `browser_drop` / `browser_fill_form` / `browser_select_option` |
| 坐标鼠标 | `browser_mouse_click_xy` / `browser_mouse_move_xy` / `browser_mouse_down` / `browser_mouse_up` / `browser_mouse_drag_xy` / `browser_mouse_wheel` |
| 标签页 | `browser_tabs`（统一管理，非多工具） |
| 快照截图 | `browser_snapshot`（a11y tree）/ `browser_take_screenshot` / `browser_pdf_save` |
| 调试检测 | `browser_console_messages` / `browser_network_requests` / `browser_evaluate` / `browser_run_code` |
| 验证断言 ⭐ | `browser_verify_element_visible` / `browser_verify_list_visible` / `browser_verify_text_visible` / `browser_verify_value` |
| 等待 | `browser_wait_for` / `browser_press_key` |
| 文件 | `browser_file_upload` |
| 存储管理 | `browser_cookie_{get,list,set,delete,clear}` / `browser_localstorage_{get,list,set,delete,clear}` / `browser_sessionstorage_{get,list,set,delete,clear}` / `browser_storage_state` / `browser_set_storage_state` |
| 网络路由 | `browser_route` / `browser_unroute` / `browser_route_list` / `browser_network_state_set` |
| Tracing ⭐ | `browser_start_tracing` / `browser_stop_tracing`（注：只记录 trace 文件，不提取 Insights） |
| 视频录制 | `browser_start_video` / `browser_stop_video` / `browser_video_chapter` |
| 定位辅助 | `browser_generate_locator` / `browser_highlight` / `browser_hide_highlight` |
| 其他 | `browser_resize` / `browser_resume` / `browser_close` / `browser_get_config` / `browser_handle_dialog` |

> ⚠️ **更正上轮已知误判**：Playwright MCP **支持** `browser_start/stop_tracing` （可导出 Playwright trace 文件在 trace viewer 中查看，但**不提供 Core Web Vitals insights**，性能量化指标仍需 Chrome DevTools MCP）。

---

## Playwright MCP vs agent-browser（同样面向 AI，怎么选？）

| 对比点 | Playwright MCP | agent-browser |
|--------|----------------|---------------|
| 部署 | npx 开箱 | `npm i -g` 后 `install` |
| Token 消耗 | 中（3-8K） | 低（0.5-2K）⭐ |
| iOS 支持 | ❌ | ✅ |
| 跨浏览器 | ✅ | ⚠️ 实验性 |
| session 隔离 | 标准 | `--session` 命名，很成熟 ⭐ |
| eval 灵活度 | 中 | 高（--stdin / -b base64） |
| annotated 截图 | ❌ | ✅ ⭐ |
| auth vault | ❌ | ✅ ⭐ |

**结论**：

- 若本机已装 agent-browser → 默认它
- 若只有 IDE + MCP 环境 → Playwright MCP
- 若要跨浏览器 → Playwright MCP（或直接用脚本模式）

---

## 委托规则

- 脚本模式 / 测试工程 → `use_skill("e2e-testing")`
- MCP 模式单一动作 → 直接调用 MCP 工具，无需额外委托
- **CLI 模式**（`@playwright/cli`）→ 作为 agent-browser 不可用时的替代方案；详情参考 [microsoft/playwright-cli](https://github.com/microsoft/playwright-cli)
