---
reference: browser-compat/browser-baseline
load_when: 需要判定项目基线 / 用户询问多项目基线差异
---

# 多项目基线对照表

帮助 AI 在多项目切换时快速判定当前项目的基线，以及为新项目选择合适的基线。

---

## 一、基线判定优先级（脚本自动执行）

进入一个项目后，由 `scripts/lib/load-config.js` 自动执行（AI 不需手动判断），按以下顺序判定基线，**命中一条即终止**：

1. `.browser-compat.json` 的 `target` 字段
2. `package.json > browserslist` 字段
3. `.browserslistrc` 文件
4. 以上皆无 → **保守型**（默认兜底）

人工查看当前判定结果：

```bash
node ~/.codebuddy/skills/browser-compat/scripts/compat-check.js --print-baseline [项目路径]
```

输出示例：

```json
{
  "projectRoot": "/path/to/project",
  "baseline": {
    "level": "conservative",
    "source": "package.json>browserslist",
    "minVersions": { "chrome": 70, "safari": 12, "firefox": 68, "edge": 79 }
  },
  "polyfills": [],
  "ignore": []
}
```

---

## 二、三档基线的判定规则

> **实现源**：`scripts/lib/baseline-resolver.js` 中的 `decideLevel()` 函数。
> 以下为人工可读版本，与脚本逻辑保持一致。

### 保守型（默认）

满足任一即判定为保守型：

- `browserslist` 含 `safari >= 12` / `Safari >= 12`
- `browserslist` 含 `last 4 years` 或更长时间
- `browserslist` 含 `>= 0.5%` 且 `not dead`
- 项目是 **C 端面向普通用户的 Web 应用**（会议、门户、企业客户端）

对应配置示例：

```json
// package.json
{
  "browserslist": [
    "chrome >= 70",
    "safari >= 12",
    "firefox >= 68",
    "edge >= 79",
    "not dead"
  ]
}
```

### 标准型

满足任一即判定为标准型：

- `browserslist` 含 `safari >= 14` / `chrome >= 90`
- 项目是 **内部管理后台 / 工具平台**
- 项目名含 `admin` / `dashboard` / `console` / `backend`

对应配置示例：

```json
{
  "browserslist": [
    "chrome >= 90",
    "safari >= 14",
    "firefox >= 90",
    "edge >= 90"
  ]
}
```

### 激进型

满足任一即判定为激进型：

- `browserslist` 仅含 `chrome >= 100` 或 `last 2 chrome versions`
- 项目是 **Electron 应用** / **Chrome 扩展** / **内嵌 webview**
- 明确在 `.browser-compat.json` 声明 `target: "aggressive"`

---

## 三、常见项目类型与推荐基线

| 项目类型 | 推荐基线 | 关键考虑 |
|---------|---------|---------|
| C 端 Web（门户/电商/SaaS）| 保守型 | 用户浏览器版本分布广 |
| 企业客户端 Web（会议/IM）| 保守型 | 部分企业用户环境受 IT 策略限制 |
| 管理后台 / 内部工具 | 标准型 | 用户为员工，浏览器可要求升级 |
| 开发者工具 / 设计师工具 | 标准型 | 用户技术栈较新 |
| Electron 桌面应用 | 激进型 | 浏览器版本固定，可使用最新 API |
| Chrome 扩展 | 激进型 | 仅 Chrome |
| 嵌入第三方 App 的 Web（SDK）| 保守型 | 不知道宿主环境，最保守兜底 |
| PC 独立 Web 页面（营销页）| 保守型 | 访问方不可控 |
| 移动端 H5（社交 App 内）| 保守型 | 老旧 WebView 存在 |

---

## 四、基线升级决策参考

### 升级触发场景

- 产品决策停止支持某老版本浏览器
- 统计数据显示该版本浏览器 PV 占比 < 0.5%
- 上游依赖库明确要求更高基线

### 升级前必做

1. 在本 skill 运行 `upgrade-baseline` 模式（全仓扫描）→ 列出当前代码中符合新基线但仍在避让的点
2. 更新 `browserslist` 和 `.browser-compat.json`
3. 重新跑构建 + CI，观察 Babel/Autoprefixer 产物变化
4. 产出升级报告（可选择 `devlog` 记录）

### 升级回归风险矩阵

| 升级方向 | 回归风险 | 处理 |
|---------|---------|------|
| 保守 → 标准 | 🟢 低 | 正常推进 |
| 保守 → 激进 | 🔴 高 | 必须先过标准一级，测试稳定后再进 |
| 标准 → 激进 | 🟡 中 | 需要 QA 覆盖验证 |

---

## 五、项目基线声明最佳实践

### 方案 A：仅 browserslist（轻量项目）

```json
// package.json
{
  "browserslist": ["chrome >= 70", "safari >= 12"]
}
```

**优点**：零额外配置，Babel/Autoprefixer 自动对齐
**缺点**：本 skill 需推导基线级别

### 方案 B：browserslist + .browser-compat.json（推荐）

```json
// .browser-compat.json（使用 templates/project-config.json 模板）
{
  "target": "conservative",
  "baseline": {
    "chrome": 70,
    "safari": 12,
    "firefox": 68,
    "edge": 79
  },
  "polyfills": ["ResizeObserver", "IntersectionObserver"],
  "ignore": [],
  "customRules": {}
}
```

**优点**：明确声明 target 级别 + polyfills 白名单，扫描更精准
**缺点**：多一份配置文件


