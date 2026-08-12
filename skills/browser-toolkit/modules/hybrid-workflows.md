# 混合工作流（Hybrid Workflows）

> 本 skill 的核心创新：三工具协同编排。单一工具无法完整解决的场景，组合使用事半功倍。

---

## 🧩 工作流 1：Bug 三步闭环（DevTools → AB → Playwright）

**场景**：用户线上报 bug → 调试定位 → 稳定复现 → 固化为回归测试

```
┌────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
│  Step 1: 定位根因   │ → │  Step 2: 稳定复现  │ → │  Step 3: 固化回归  │
│  Chrome DevTools   │   │  agent-browser     │   │  Playwright 脚本   │
│  MCP               │   │                    │   │                    │
├────────────────────┤   ├────────────────────┤   ├────────────────────┤
│ • 连接用户 Chrome   │   │ • 在隔离环境复现    │   │ • 写成 *.spec.ts   │
│ • list_console_msg  │   │ • 记录命令序列     │   │ • 加 expect() 断言 │
│ • list_network_req  │   │ • screenshot --annotate │ • 加入 CI 矩阵     │
│ • 找到根因          │   │ • 生成可回放脚本    │   │ • 永久防回归       │
└────────────────────┘   └────────────────────┘   └────────────────────┘
```

**每步产出**：

- Step 1：bug 根因报告（console / network / trace 证据）
- Step 2：可重复的 CLI 脚本（agent-browser 命令序列）
- Step 3：仓库内 `.spec.ts` 测试文件 + CI 配置

---

## 🧩 工作流 2：性能优化验证（DevTools + Playwright）

**场景**：优化前后性能对比，提供数据证据

```
Step 1: DevTools MCP 采集基线
  performance_start_trace → navigate → performance_stop_trace
  保存 insights-before.json

Step 2: 执行代码优化（开发过程）

Step 3: DevTools MCP 采集优化后
  performance_start_trace → navigate → performance_stop_trace
  保存 insights-after.json

Step 4: Playwright 写性能回归测试（防回退）
  // 在 playwright.config.ts 开启 trace 方便失败时复现
  use: { trace: 'on-first-retry' }

  // 在测试中通过 PerformanceObserver 读 LCP 做断言
  const lcp = await page.evaluate(() => new Promise<number>((resolve) => {
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      resolve(entries[entries.length - 1].startTime);
    }).observe({ type: 'largest-contentful-paint', buffered: true });
  }));
  expect(lcp).toBeLessThan(2500);  // LCP < 2500ms
  // 加入 CI 作为性能门禁
```

---

## 🧩 工作流 3：AI 探索 → 脚本沉淀（AB → Playwright）

**场景**：AI 帮你摸索新功能的交互路径，再把稳定的路径固化

```
Step 1: agent-browser 探索式自动化
  agent-browser open <新功能页面>
  agent-browser snapshot -i
  AI 试不同交互 → 找到可行路径

Step 2: 用 agent-browser session state 验证路径稳定
  agent-browser --session try1 ...
  agent-browser --session try2 ...

Step 3: 由 AI 把命令序列翻译为 Playwright 脚本
  → 交给 e2e-testing skill 按 POM 规范产出 .spec.ts
```

---

## 🧩 工作流 4：视觉回归验证（AB + DevTools）

**场景**：UI 改动后，既要验证视觉不回归，又要验证性能不变差

```
Step 1: agent-browser diff screenshot
  agent-browser screenshot baseline.png  # 改动前
  # 提交代码
  agent-browser diff screenshot --baseline baseline.png
  # 生成红色像素 diff 图

Step 2: DevTools MCP 性能对比
  同"工作流 2"执行基线 → 改动 → 对比
  重点关注：布局偏移（CLS）是否回归
```

---

## 🧩 工作流 5：跨浏览器 bug 定位（Playwright + DevTools）

**场景**：仅 Safari 出现的 bug

```
Step 1: Playwright 脚本跑 WebKit 复现
  npx playwright test --project=webkit --trace=on
  获取 trace.zip

Step 2: Chrome DevTools MCP 反向验证 Chrome 正常
  同一个 URL 跑一遍性能/网络，确认 Chrome 没问题

Step 3: 把差异点交给 AI 分析
  - WebKit trace 里哪些请求失败 / JS 报错
  - Chrome 里这些点都正常
  - 推导出 Safari 独有的兼容性问题（polyfill / API 差异）
```

---

## 编排原则

1. **优先单工具**：能一个工具解决就不上多工具
2. **串行而非并行**：三工具协同时严格串行（后一步依赖前一步产出）
3. **中间产物持久化**：每一步输出落盘（JSON/PNG/脚本文件），下一步从文件读入
4. **节点可替代**：任何一步失败，回退到单工具方案
5. **上下文传递**：关键信息（URL/session/selector）通过 working-context 或脚本参数传递

---

## 触发提示模板（给用户的交互）

用户说"帮我排查这个 bug"时，主动提议混合工作流：

```
这个 bug 排查我建议走 Bug 三步闭环（工作流 1）：

1. 🔍 **Chrome DevTools MCP** 连接你当前 Chrome，抓 console/network/性能证据
2. 🤖 **agent-browser** 在隔离环境稳定复现（防止环境因素干扰）
3. 🧪 **Playwright 脚本** 固化为回归测试（防止下次复发）

是否按这个流程走？或你想直接跳到某一步？
```
