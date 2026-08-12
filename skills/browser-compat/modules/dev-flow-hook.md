---
module: browser-compat/dev-flow-hook
load_when: 被 code-review / dev-flow 按需调用
---

# Dev-Flow Hook - 被调用模式

## 适用场景

本模块用于**被其他 skill 或 dev-flow 步骤调用**的场景，区别于独立使用（见 `quick-scan.md`）：

- `code-review` L1 审查第 5 条：有 JS/CSS 改动时代理调用
- dev-flow 步骤 5（执行修改）：编码时实时参考
- dev-flow 步骤 5.5a（编码后置钩子）：L1 审查内部触发
- dev-flow 步骤 6 V4 Browser：确定跨浏览器测试版本范围

---

## 与 `code-review` L1 的协作协议（核心）

### 调用方视角（code-review）

`code-review/SKILL.md` §二 L1 第 5 条改造为：

```markdown
5. 浏览器兼容性（涉及 JS API 或 CSS 属性时必须检查）：
   - 调用 `use_skill('browser-compat')` 对本轮新增/修改的代码执行扫描
   - 将 browser-compat 输出的问题列表按严重度回填到 L1 报告的 🔴/🟡/🟢 分类中
```

### 被调用方视角（本 skill）

被 code-review 调用时：

1. **输入**：本轮 diff 或指定代码片段
2. **加载规则**：`~/.codebuddy/rules/浏览器兼容性规范.mdc`
3. **快速扫描**（仅扫本轮 diff，不扩展）
4. **输出**：统一格式的问题列表，回给 code-review 汇总，**不自己弹出交互**（交互由 code-review L1 流程统一处理）

---

## 标准输出格式（统一契约）

> 📄 **Schema 契约**：`schemas/finding.schema.json`。脚本输出后自动调用 `scripts/lib/output-validator.js` 校验，失败仅 stderr 警告不阻断退出码，调用方可信任 stdout JSON 结构。

被调用场景必须输出以下结构化数据，便于调用方消费：

```json
{
  "skill": "browser-compat",
  "scan_scope": "diff | staged | file | directory",
  "baseline": {
    "level": "conservative | standard | aggressive",
    "source": "package.json>browserslist | .browser-compat.json | .browserslistrc | default",
    "minVersions": { "chrome": 70, "safari": 12, "firefox": 68, "edge": 79 }
  },
  "findings": [
    {
      "severity": "CRITICAL | WARNING | INFO",
      "type": "js | css",
      "rule_id": "no-has-selector",
      "file": "src/components/Foo.tsx",
      "line": 42,
      "code_snippet": "div:has(> .child) { ... }",
      "message": "使用了 :has() 选择器",
      "reason": "项目基线 Safari 12+ 不支持 :has()（需 Safari 15.4+）",
      "fix_hint": "改用 JS 逻辑 + className 切换"
    }
  ],
  "skipped": [
    { "rule_id": "no-inset-shorthand", "reason": "baseline:standard" },
    { "rule_id": "no-has-selector", "reason": "ignore: 后台仅 Chrome 访问" }
  ],
  "summary": {
    "critical": 1,
    "warning": 2,
    "info": 0,
    "conclusion": "block | warning | approve"
  }
}
```

> 新增字段 `baseline` / `skipped` / `scan_scope` 是向后兼容追加，旧消费方仅读 `findings` / `summary` 仍能正常工作。

---

## 调用方交互契约

| 调用方 | 本 skill 的责任 | 交互责任归属 |
|-------|----------------|------------|
| `code-review` L1 | 只输出问题列表 | code-review 统一弹出 🟡 决策选项 |
| dev-flow 步骤 5 | 只提示"该 API 禁用 + 替代方案" | dev-flow AI 直接采用替代方案生成代码 |
| dev-flow 步骤 6 V4 | 只输出"需要跨浏览器测试的版本范围" | `browser-toolkit` 执行实测 |

**本 skill 绝不越俎代庖**：被调用时不弹自己的交互选项，避免与调用方的流程冲突。

---

## 性能优化（避免重复加载）

被 `code-review` 调用时：

1. 如果 `~/.codebuddy/rules/浏览器兼容性规范.mdc` **已在上下文**，不重复 `read_file`
2. 如果 diff 中**不涉及** `.js/.ts/.jsx/.tsx/.css/.scss/.less`，直接返回空 findings，不启动扫描
3. 如果 diff < 50 行，AI 直接对照清单扫描，不调用脚本
4. 如果 diff > 200 行或涉及 > 5 个文件，优先调 `scripts/compat-check.js`
5. 脚本已内置 `excludePaths` / `includePaths` 支持，无需 AI 判断路径过滤

---

## 降级与熔断

- 规则文件加载失败 → 降级为仅检查**最高频 5 条**（`:has()` / `structuredClone` / `Object.hasOwn` / `Flexbox gap` / `aspect-ratio`）
- 本 skill 同一次调用中连续 3 次分析失败 → 返回 `{ "skill": "browser-compat", "status": "degraded", "findings": [] }`，由调用方决定是否继续
