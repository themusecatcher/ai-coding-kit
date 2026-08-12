# Chrome DevTools MCP 适配器

> 官方仓库：<https://github.com/ChromeDevTools/chrome-devtools-mcp>
> 版本基线：v0.23.0（2026-04）
> 维护方：Google Chrome DevTools 官方团队

---

## 何时使用

- ✅ 页面性能分析（LCP/CLS/TTI/INP 等 Core Web Vitals）
- ✅ 网络请求瀑布图/失败请求/慢请求定位
- ✅ 控制台错误收集
- ✅ 内存泄漏调查（堆快照）
- ✅ 连接用户当前 Chrome，复用已登录会话
- ✅ DOM 结构/样式实时检查

## 何时不用

- ❌ 跨浏览器测试（只支持 Chrome/Chromium）
- ❌ CI 自动化回归（无测试 runner）
- ❌ Token 敏感的大规模爬取（DevTools 输出较大）

---

## 安装与启用

### Claude Code CLI

```bash
claude mcp add chrome-devtools -- npx chrome-devtools-mcp@latest
```

### CodeBuddy / Cursor / Qoder 等 IDE（MCP JSON）

在 MCP 配置文件中加入：

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"]
    }
  }
}
```

**系统要求**：Node.js v20.19+，Chrome 稳定版或更新

---

## 核心工具集（33 个工具，按官方 docs/tool-reference.md 分类）

> 源：<https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md>

### 🎯 Input automation（9 个）

| 工具 | 用途 |
|------|------|
| `click` | 点击元素（基于 snapshot UID） |
| `drag` | 拖拽 |
| `fill` | 填单个表单字段 |
| `fill_form` | 批量填表 |
| `handle_dialog` | 处理 alert/confirm/prompt |
| `hover` | 悬停 |
| `press_key` | 键盘按键 |
| `type_text` | 输入文本 |
| `upload_file` | 文件上传 |

### 🧭 Navigation automation（6 个）

| 工具 | 用途 |
|------|------|
| `navigate_page` | 打开 URL / 后退 / 前进（通过 `type` 参数） |
| `new_page` | 新建标签页 |
| `close_page` | 关闭标签页 |
| `list_pages` | 列出所有打开的 tab |
| `select_page` | 切换当前激活 tab |
| `wait_for` | 等待条件（URL / 文本 / 函数） |

### 🌐 Emulation（2 个）

| 工具 | 用途 |
|------|------|
| `emulate` | 统一仿真入口：CPU 节流 / 网络限速 / 设备模拟 / 地理定位等 |
| `resize_page` | 改视口尺寸 |

### ⚡ Performance（3 个，⭐核心竞争力）

| 工具 | 用途 |
|------|------|
| `performance_start_trace` | 开始性能记录 |
| `performance_stop_trace` | 停止并返回 Insights（LCP/CLS/TTI/长任务等） |
| `performance_analyze_insight` | 深度分析单项 insight |

### 📡 Network（2 个）

| 工具 | 用途 |
|------|------|
| `list_network_requests` | 网络请求列表（瀑布视图的数据源） |
| `get_network_request` | 单个请求详情（含请求/响应头和 body） |

### 🔍 Debugging（6 个）

| 工具 | 用途 |
|------|------|
| `list_console_messages` | 控制台日志列表 |
| `get_console_message` | 单条控制台消息详情（含 source map 还原后的堆栈） |
| `evaluate_script` | 执行 JavaScript |
| `lighthouse_audit` | Lighthouse 审计（默认 navigation 模式，支持 snapshot） |
| `take_snapshot` | DOM / 可访问性快照（获取元素 UID） |
| `take_screenshot` | 截图（支持 `fullPage` 和元素截图） |

### 🧠 Memory（1 个）

| 工具 | 用途 |
|------|------|
| `take_memory_snapshot` ⭐ | 内存堆快照（查 JS 内存泄漏，输出 `.heapsnapshot` 文件） |

### 🧩 Extensions（4 个，需 `--categoryExtensions` 启用；⚠️ 当前只支持 pipe 连接，不兼容 autoConnect/browserUrl/wsEndpoint，直到 Chrome 149 才会放开）

| 工具 | 用途 |
|------|------|
| `list_extensions` | 列出已安装的浏览器扩展 |
| `install_extension` | 从本地路径安装扩展 |
| `reload_extension` | 重新加载扩展（调试开发中的扩展） |
| `trigger_extension_action` | 触发扩展的 action 按钮 |

---

## 关键场景：连接用户当前 Chrome（⭐独占能力）

这是 DevTools MCP 相对 agent-browser / Playwright 的**最大差异化**。

### 启动用户 Chrome 带远程调试端口

**macOS**：

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/Library/Application Support/Google/Chrome"
```

> ⚠️ 使用用户真实 user-data-dir 会复用**所有**已登录态（含 Google/GitHub/企业 SSO），便利但敏感。若只需部分，新建 profile：

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-devtools-mcp-profile
```

### 连接方式三选一（官方 v0.23.0 支持）

**方式 A：`--autoConnect`（推荐，Chrome 144+）** — 让 MCP 自动发现并连接本地 Chrome：

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--autoConnect"]
    }
  }
}
```

> 前置：Chrome 访问 `chrome://inspect/#remote-debugging` 开启远程调试许可。

**方式 B：`--browserUrl`（显式端口，最通用）**

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y", "chrome-devtools-mcp@latest",
        "--browserUrl=http://127.0.0.1:9222"
      ]
    }
  }
}
```

**方式 C：`--wsEndpoint`（WebSocket，支持自定义 headers 如企业代理认证）**

```json
{
  "args": [
    "-y", "chrome-devtools-mcp@latest",
    "--wsEndpoint=ws://127.0.0.1:9222/devtools/browser/<id>",
    "--wsHeaders={\"Authorization\":\"Bearer <token>\"}"
  ]
}
```

---

## 典型工作流：性能分析三步法

```
Step 1: 让 AI 调用 performance_start_trace 工具
Step 2: 让页面完成首屏（navigate_page → 等待 networkidle）
Step 3: 调用 performance_stop_trace，AI 拿到 Insights → 分析 LCP 元素/长任务/布局偏移
```

**对 AI 的提示词模板**：

```
请用 chrome-devtools MCP 工具分析 https://example.com 的首屏性能：
1. 先 navigate_page 到该 URL
2. 用 performance_start_trace 开始记录
3. 等待页面稳定（wait_for 或 2s）
4. 用 performance_stop_trace 获取 insights
5. 针对 LCP > 2.5s 的情况调用 performance_analyze_insight 深挖
6. 给出优化建议，并用 `lighthouse_audit` 补充指标
```

---

## 安全与隐私注意事项

1. **远程调试端口 9222 危险**：外部任意程序可通过该端口控制浏览器。只在本地使用，不暴露到公网，使用后关闭。
2. **共享真实 user-data-dir 的风险**：AI 可读取所有 cookie / 已登录会话。敏感账号（企业 SSO、支付）场景**必须**用独立 profile 目录。
3. **MCP 权限分层**：在 Claude / Cursor 中可限制 MCP 只读工具（list_*/ get_*），禁用 `evaluate_script` 等可写操作。
4. **日志脱敏**：trace 结果含 URL 和响应头，分享给他人前需脱敏。

---

## 已知限制

- 只支持 Chrome / Chromium（不支持 Firefox/Safari）
- 无内置 CI runner（回归测试需配合 Playwright）
- 单次性能 trace 输出较大，长会话注意 token 消耗
- `lighthouse_audit` 受 Chrome 主版本影响，老版本可能不稳定
