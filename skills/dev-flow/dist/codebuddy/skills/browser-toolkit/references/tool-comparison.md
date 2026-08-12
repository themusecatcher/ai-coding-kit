# 三工具详细对比矩阵

> 从多个维度深度对比 agent-browser / Playwright 系（脚本 + MCP + 官方 CLI）/ Chrome DevTools MCP，辅助决策。
>
> ⚠️ **Playwright 2026 新增 `@playwright/cli`**（[microsoft/playwright-cli](https://github.com/microsoft/playwright-cli)）——官方明确推荐 coding agent 使用它而不是 Playwright MCP，如 agent-browser 不可用时可考虑它作为替代。

---

## 维度 1：定位与设计哲学

| 工具 | 定位 | 设计哲学 |
|------|------|---------|
| **agent-browser** | LLM-friendly 浏览器 CLI | 让 AI 以最少 token 操作浏览器 |
| **Playwright 脚本** | 端到端测试框架 | 让人写稳定可维护的测试 |
| **Playwright MCP** | MCP 化的 Playwright | 让 AI 通过 MCP 协议用 Playwright |
| **Chrome DevTools MCP** | MCP 化的 DevTools | 让 AI 拥有 Chrome DevTools 的全部调试能力 |

## 维度 2：维护者与生态

| 工具 | 维护方 | 发布时间 | 社区规模 |
|------|--------|---------|---------|
| agent-browser | 社区项目 | 2024 | 新兴但增长快 |
| Playwright | Microsoft 官方 | 2020 | 超大，npm 周下载 10M+ |
| Playwright MCP | Microsoft 官方 | 2025 | 伴随 MCP 协议发展 |
| Chrome DevTools MCP | Google Chrome 官方 | 2025 公开预览 | 官方背书 |

## 维度 3：技术栈与底层

| 工具 | 底层 | 协议 | 浏览器内核 |
|------|------|------|-----------|
| agent-browser | Playwright/CDP（实验性 Rust） | CLI/daemon | Chromium（实验 Safari） |
| Playwright 脚本 | CDP + WebDriver BiDi | 原生 API | Chromium/Firefox/WebKit |
| Playwright MCP | Playwright | MCP (stdio/HTTP) | 同上 |
| Chrome DevTools MCP | CDP | MCP (stdio) | 仅 Chrome/Chromium |

## 维度 4：能力矩阵（✅ 原生 / ⚠️ 可选/可模拟 / ❌ 不支持）

| 能力 | AB | PW 脚本 | PW MCP | PW CLI | DT MCP |
|------|:--:|:------:|:------:|:------:|:------:|
| 页面导航/点击/填表 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 截图 | ✅ | ✅ | ✅ | ✅ | ✅ |
| PDF 导出 | ✅ | ✅ | ✅ `browser_pdf_save` | ✅ | ❌ |
| A11y Snapshot | ✅ | ✅ | ✅ | ✅ | ✅ |
| 网络请求抓取 | ⚠️ eval | ✅ | ✅ `browser_network_requests` | ✅ | ✅ |
| 控制台消息 | ⚠️ eval | ✅ | ✅ | ✅ | ✅ |
| 性能 Trace/Insights | ⚠️ profiler | ⚠️ tracing | ⚠️ `browser_start/stop_tracing`（无 Insights） | ⚠️ | ✅ ⭐ insights 丰富 |
| Lighthouse 审计 | ❌ | ❌ | ❌ | ❌ | ✅ ⭐ `lighthouse_audit` |
| 内存堆快照 | ❌ | ❌ | ❌ | ❌ | ✅ ⭐ `take_memory_snapshot` |
| CPU/网络限速 | ⚠️ | ✅ | ✅ | ✅ | ✅ `emulate` |
| 视频录制 | ✅ | ✅ | ✅ `browser_start_video` | ✅ | ⚠️ `--experimentalScreencast` |
| 跨浏览器（FF/WebKit） | ⚠️ 实验 | ✅ ⭐ | ✅ | ✅ | ❌ |
| iOS 真机/模拟器 | ✅ ⭐ | ⚠️ BrowserStack | ❌ | ❌ | ❌ |
| 连接用户当前 Chrome | ⚠️ --auto-connect | ✅ | ✅ | ✅ | ✅ ⭐ 3 种方式 |
| Cookie/Storage 操作 | ⚠️ eval | ✅ | ✅ ⭐ 完整 API | ✅ | ⚠️ |
| Auth vault 凭据管理 | ✅ ⭐ | ❌ | ❌ | ❌ | ❌ |
| Session 持久化 | ✅ 精细 | ✅ storageState | ✅ `browser_storage_state` | ✅ | ⚠️ |
| 测试 runner/断言 | ❌ | ✅ ⭐ | ❌（但有 `browser_verify_*`） | ❌ | ❌ |
| CI 报告（HTML/JUnit） | ❌ | ✅ ⭐ | ❌ | ❌ | ❌ |
| Annotated 截图 | ✅ ⭐ | ❌ | ⚠️ `browser_highlight` | ❌ | ❌ |
| JS eval（复杂） | ✅ stdin/b64 | ✅ | ✅ `browser_evaluate` | ✅ | ✅ |
| 扩展管理 | ❌ | ✅ | ❌ | ❌ | ✅ `install_extension` 等 4 个 |
| Diff 可视化（像素/快照） | ✅ ⭐ | ✅ | ❌ | ❌ | ❌ |

## 维度 5：Token 成本（重要）

| 操作 | AB | PW MCP | DT MCP |
|------|----|--------|---------|
| snapshot 100 元素页面 | ~1K | ~5K | ~8K |
| 5 条网络请求 | eval ~2K | ~3K | ~5K |
| 控制台 10 条错误 | eval ~1K | ~2K | ~3K |
| 性能 trace 报告 | trace.json 路径 | — | ~3K-10K insights |

## 维度 6：上手成本

| 工具 | 安装 | 首次运行 | 学习曲线 |
|------|------|---------|---------|
| agent-browser | `npm i -g` + `install` | 30 秒 | 低（CLI 直观） |
| Playwright 脚本 | `npm i` + `install browsers` | 2-5 分钟 | 中（需学 API） |
| Playwright MCP | `npx` 开箱 | 即时 | 低（MCP 工具自描述） |
| Chrome DevTools MCP | `npx` 开箱 | 即时（需 Chrome） | 低 |

## 维度 7：维护成本与稳定性

| 工具 | API 稳定性 | 版本更新频率 | Breaking Change 风险 |
|------|-----------|-------------|---------------------|
| agent-browser | 中（项目较新） | 高 | 中 |
| Playwright 脚本 | 高（官方成熟） | 月度稳定版 | 低 |
| Playwright MCP | 中 | 跟随 Playwright | 中 |
| Chrome DevTools MCP | 中（预览期） | 周更 | 中（但有 GPG 签名） |

## 维度 8：安全与隐私

| 工具 | 风险点 | 规避建议 |
|------|--------|---------|
| agent-browser | CLI 可执行任意 JS/HTTP | 启用 ACTION_POLICY / ALLOWED_DOMAINS |
| Playwright 脚本 | 测试环境凭据泄露 | 用 .env + secret manager |
| Playwright MCP | MCP 工具权限 | IDE 层权限控制 |
| Chrome DevTools MCP | ⭐ 9222 端口高风险 | 仅本地使用 + 独立 profile + 用完关闭 |

## 维度 9：AI 友好度（token + 结构化输出）

| 工具 | AI 友好度 | 原因 |
|------|:--------:|------|
| agent-browser | ⭐⭐⭐⭐⭐ | 专为 LLM 设计，ref 系统（@e1/@e2）省 token |
| Playwright 脚本 | ⭐⭐ | API 为人设计，LLM 需理解 TS 类型 |
| Playwright MCP | ⭐⭐⭐⭐ | MCP 原生，但 snapshot 较大 |
| Chrome DevTools MCP | ⭐⭐⭐⭐ | MCP 原生 + 结构化 insights |

---

## 📌 核心结论（一句话版本）

- **AI 驱动自动化 + 省 token** → agent-browser
- **若无 agent-browser 但仍需 AI 核心 CLI** → `@playwright/cli`（官方 2026 新推，[playwright-cli](https://github.com/microsoft/playwright-cli)）
- **跨浏览器测试 + CI 工程化** → Playwright 脚本（`e2e-testing` skill）
- **在 IDE MCP 环境内做 AI 测试 + 跨浏览器** → Playwright MCP（65+ 工具）
- **性能/内存/调试/真实 Chrome** → Chrome DevTools MCP（33 工具）
- **组合以上** → 本 skill 的 `hybrid-workflows.md`
