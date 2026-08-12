# 三工具常见坑与规避方案

> 按工具分类的实战踩坑清单，避免重复犯错。

---

## agent-browser 常见坑

### 坑 1：ref 失效
- **现象**：`click @e1` 报错元素不存在
- **原因**：页面跳转/DOM 变更后旧 ref 失效
- **规避**：跳转/提交后立即 `snapshot -i` 刷新 ref

### 坑 2：eval 复杂 JS 被 shell 吞字符
- **现象**：带反引号/$()/!的 JS 表达式报 syntax error
- **规避**：用 `--stdin <<'EVALEOF'` heredoc 或 `-b base64`

### 坑 3：daemon 泄漏
- **现象**：脚本结束但 Chrome 进程残留
- **规避**：用 `--session` 命名 + 任务结束显式 `agent-browser close`

### 坑 4：并行 session 冲突
- **现象**：多 agent 同时跑相互干扰
- **规避**：每个 agent 用独立 `--session <name>`

---

## Playwright 常见坑

### 坑 1：flaky test（时序不稳定）
- **现象**：本地过 CI 挂
- **规避**：禁用 `waitForTimeout(5000)`，改用 `waitForResponse` / `waitForLoadState` / auto-wait locator

### 坑 2：selector 耦合实现细节
- **规避**：优先 `data-testid` 而非 CSS class

### 坑 3：storageState 泄露到仓库
- **规避**：`auth.json` 加入 `.gitignore`

### 坑 4：Playwright MCP 连续操作 snapshot 膨胀
- **现象**：每次操作后 a11y tree 被完整返回，token 快速耗尽
- **规避**：指定 selector scope，或改用 agent-browser

### 坑 5：`test.fixme`/`test.skip` 堆积
- **规避**：每次挂起必须关联 Issue 号，定期清理

---

## Chrome DevTools MCP 常见坑

### 坑 1：9222 端口已被占用
- **现象**：`Port already in use`
- **规避**：`lsof -i:9222` 找到进程杀掉，或换 9223

### 坑 2：连接到错误的 Chrome 实例
- **现象**：AI 看到的页面和你当前在看的不一样
- **规避**：`list_pages` 后用 `select_page` 精确选中目标 tab

### 坑 3：共享真实 user-data-dir 导致账号泄露
- **现象**：AI 意外访问了你的 Gmail/Slack/企业 SSO
- **规避**：生产数据敏感时必须用独立 profile 目录

### 坑 4：性能 trace 过大导致 token 爆炸
- **现象**：`performance_stop_trace` 返回上万行
- **规避**：trace 时间控制在 5-10 秒；关注 TopInsights 而非完整数据

### 坑 5：`lighthouse_audit` 版本不稳定
- **现象**：某些 Chrome 版本上 Lighthouse 跑失败
- **规避**：用稳定 Chrome；或退回手动在 DevTools 里跑

---

## 跨工具协同时的坑

### 坑 1：session/凭据不共享
- **现象**：agent-browser 登录过的站点，切换到 Playwright 又要重新登录
- **规避**：
  - agent-browser 用 `state save auth.json`
  - Playwright 用 `storageState: 'auth.json'`（两者 JSON 结构兼容需验证）
  - 不兼容时用 DevTools MCP 连接用户真实 Chrome

### 坑 2：ref/selector 命名冲突
- **现象**：agent-browser 的 `@e1` 在 Playwright/DevTools 中不存在
- **规避**：跨工具协同时统一用 CSS/data-testid 选择器

### 坑 3：浏览器实例互相抢占
- **现象**：三个工具都想启动 Chrome 导致资源紧张
- **规避**：串行执行（不要并行）；或三个工具共享一个 9222 Chrome 实例

---

## 紧急诊断 checklist

工具不工作时，按顺序检查：

```
1. 版本正确？ agent-browser --version / npx chrome-devtools-mcp@latest --help
2. Chrome 安装？ which google-chrome / mac 上 ls /Applications/Google\\ Chrome.app
3. 9222 端口通？ curl -s http://localhost:9222/json/version
4. 磁盘/内存？ df -h / vm_stat
5. 权限够？ （macOS 可能需要允许远程控制）
```
