# 浏览器 MCP 实时验证规范

## 背景

AI 在开发前端功能后无法"看到"页面实际状态。通过 MCP 协议连接浏览器，AI 可以直接获取控制台日志、截图、网络请求、DOM 状态，实现自主验证。

**与其他验证方案的关系**：
- `runtime-verification.md`（自检日志）→ 被动等用户反馈
- `e2e-verification.md`（Playwright 测试）→ 需要写测试代码
- **本方案（浏览器 MCP）→ AI 实时操控浏览器，主动获取信息**

## 可用的 MCP Server

当前已配置三个浏览器相关 MCP Server：

| MCP Server | 包名 | 核心能力 | 适用场景 |
|-----------|------|---------|---------|
| **Playwright MCP** | `@playwright/mcp` | 启动新浏览器实例，完整自动化 | 无需登录的页面、完整交互流程 |
| **Chrome DevTools MCP** | `chrome-devtools-mcp` | 连接已打开的 Chrome | 需要登录态的页面调试 |
| **BrowserMCP** | `@browsermcp/mcp` | 连接当前浏览器会话 | 实时调试当前页面 |

## 使用策略

### 场景选择决策树

```
需要验证前端页面？
├── 页面无需登录？
│   └── → Playwright MCP（自动打开、操作、截图、获取日志）
├── 页面需要登录，用户已在浏览器中打开？
│   └── → Chrome DevTools MCP / BrowserMCP（连接已有会话）
└── 需要复杂交互序列？
    └── → Playwright MCP（用保存的 storage state 处理登录）
```

### 优先级

1. **Playwright MCP**（主力）— 功能最全，微软官方维护
2. **Chrome DevTools MCP**（辅助）— 需要登录态时的首选
3. **BrowserMCP**（备选）— 轻量连接已有会话

## Playwright MCP 使用指南

### 核心工具

| 工具 | 用途 | 示例 |
|------|------|------|
| `browser_navigate` | 导航到指定 URL | 打开目标页面 |
| `browser_snapshot` | 获取页面无障碍快照 | 查看页面结构和文本内容 |
| `browser_screenshot` | 页面截图 | 验证视觉渲染 |
| `browser_click` | 点击元素 | 模拟用户交互 |
| `browser_type` | 输入文本 | 填写表单 |
| `browser_evaluate` | 执行 JavaScript | 获取 DOM 状态、计算值、控制台变量 |
| `browser_console_messages` | 获取控制台消息 | 查看 console.log 输出 |
| `browser_network_requests` | 获取网络请求 | 验证接口调用 |
| `browser_wait_for` | 等待条件满足 | 等待元素出现、网络空闲 |

### 验证流程

```
1. browser_navigate → 打开目标 URL
2. browser_wait_for → 等待页面加载完成
3. browser_snapshot → 获取页面结构，确认渲染正常
4. browser_console_messages → 检查是否有报错
5. browser_network_requests → 确认接口请求正常
6. browser_evaluate → 执行自定义 JS 获取状态
7. browser_screenshot → 截图留档（可选）
```

### 常用验证模式

#### 1. 页面是否正常渲染
```
→ browser_navigate(url)
→ browser_snapshot()  // 查看页面结构和文本
→ browser_console_messages()  // 检查是否有 JS 错误
```

#### 2. 接口联调验证
```
→ browser_navigate(url)
→ browser_network_requests()  // 查看请求列表
→ browser_evaluate("JSON.stringify(window.__STORE__)")  // 获取页面状态
```

#### 3. 交互流程验证
```
→ browser_navigate(url)
→ browser_click(element)  // 点击按钮
→ browser_wait_for(selector)  // 等待弹窗出现
→ browser_snapshot()  // 确认弹窗内容
```

#### 4. 自检日志验证（配合 runtime-verification）
```
→ browser_navigate(url)
→ browser_evaluate("执行触发操作的 JS")
→ browser_console_messages()  // 过滤 [模块名] 前缀的日志
→ 分析日志判断逻辑是否正确
```

## Chrome DevTools MCP 使用指南

### 前置条件

用户需要用 `--remote-debugging-port` 参数启动 Chrome：

```bash
# macOS
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
```

或者让 Chrome DevTools MCP 自动启动带调试端口的 Chrome 实例。

### 核心工具

| 工具 | 用途 |
|------|------|
| `list_console_messages` | 获取控制台所有消息（含 log/warn/error） |
| `take_screenshot` | 当前页面截图 |
| `evaluate_script` | 在页面上下文执行 JS |
| `list_network_requests` | 列出所有网络请求及响应 |
| `navigate_page` | 页面导航 |
| `click` | 点击元素 |
| `fill` | 填写输入框 |

### 适用场景

当用户已经在浏览器中打开了需要调试的页面（已登录、已进入正确页面），AI 可以通过 Chrome DevTools MCP 直接获取：
- 控制台日志（验证自检日志输出）
- 网络请求（验证接口调用和返回数据）
- 页面截图（验证渲染效果）

## 验证结果判断标准

### 通过标准

| 检查项 | 通过条件 |
|--------|---------|
| 控制台无 Error | `console_messages` 中无 `error` 级别消息（忽略已知无害错误） |
| 接口请求成功 | 关键接口返回 2xx，响应体包含预期字段 |
| 页面结构正确 | `snapshot` 中包含预期的文本/元素 |
| 自检日志正常 | 所有 `[模块名]` 前缀的日志值在合理范围内 |
| 无 assert 失败 | `console_messages` 中无 `Assertion failed` |

### 失败处理

1. 控制台有 Error → 分析错误堆栈，定位到具体文件和行号
2. 接口返回异常 → 检查请求参数是否正确，对比预期响应格式
3. 页面结构缺失 → 检查组件渲染条件，确认数据是否到位
4. 自检日志异常 → 根据日志值分析计算逻辑问题

## 限制与注意

1. **登录态**：Playwright MCP 启动的是新浏览器实例，默认无登录态。需要通过 `--save-storage` / `--load-storage` 管理登录状态
2. **内网环境**：如果页面只能通过公司内网/VPN 访问，MCP Server 需要在同一网络环境下运行
3. **动态内容**：SPA 页面需要适当等待（`browser_wait_for`），避免快照到加载中的状态
4. **非视觉验证**：截图能看到渲染效果，但 AI 对图片的理解有限。结合 snapshot（文本结构）+ console（日志数据）更可靠
5. **性能开销**：频繁截图和 evaluate 会拖慢页面。验证完成后应关闭连接

## 与 dev-flow 的集成

在 dev-flow 步骤 6（系统化验证）中可选使用：

```
步骤 6：系统化验证
├── 6.1 编译检查
├── 6.2 类型检查
├── 6.3 Lint 检查
└── 6.4 浏览器验证（可选，需用户确认）
    ├── 询问用户："是否需要进行浏览器验证？"
    ├── 用户提供测试 URL 或确认本地 dev server
    ├── 选择合适的 MCP Server
    └── 执行验证流程
```

**触发条件**（建议验证的场景）：
- 涉及 DOM 操作/样式计算的改动
- 新增或修改了接口调用
- UI 交互流程变更
- 用户主动要求验证

**不触发**（无需浏览器验证）：
- 纯类型定义修改
- 配置文件调整
- 代码重构（无行为变更）
- 纯文案修改
