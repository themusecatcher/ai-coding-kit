---
module: browser-compat/quick-scan
load_when: 用户主动触发兼容性检查（独立使用场景）
---

# Quick Scan - 独立扫描模式

## 适用场景

用户主动提出兼容性检查需求，非 dev-flow 流程内：

- "帮我检查一下兼容性"
- "这段代码能在 Safari 12 上跑吗"
- "扫一下 diff 的兼容性"
- "升级 browserslist 前全仓扫描一下"
- "`foo.tsx` 有没有兼容性问题"

---

## 执行步骤

### Step 1：加载规则文件（必须）

```
read_file("~/.codebuddy/rules/浏览器兼容性规范.mdc")
```

该规则是单一真相源，本 skill 的所有判定必须基于此。

### Step 2：判定项目基线（脚本自动执行）

本步骤由 `scripts/lib/load-config.js` 自动执行，按优先级依次检查：

1. `.browser-compat.json` 是否存在 → 读 `target` 字段
2. `package.json > browserslist` → 解析为基线级别（调用 `baseline-resolver.js`）
3. `.browserslistrc` → 同上
4. 以上皆无 → 使用**保守型**默认（Safari 12+ / Chrome 70+）

人工查看当前判定结果：

```bash
node ~/.codebuddy/skills/browser-compat/scripts/compat-check.js --print-baseline [项目路径]
```

详细对照见 `references/browser-baseline.md`。AI 不需手动判断。

### Step 3：确定扫描范围

| 用户输入 | 扫描范围 |
|---------|---------|
| 未指定 | `git diff` + `git diff --staged`（本地未提交改动） |
| 指定文件 | 该文件全部内容 |
| 指定目录 | 该目录下所有 `.js/.ts/.jsx/.tsx/.css/.scss/.less` |
| "全仓扫描" | 整个项目（排除 `.gitignore` + `node_modules`）|

### Step 4：执行扫描

**首选调用脚本**（推荐）：

```bash
node ~/.codebuddy/skills/browser-compat/scripts/compat-check.js <path>
```

脚本自动完成：

- 加载项目配置（load-config.js）
- 按 baseline / polyfills / ignore 过滤规则（rule-filter.js）
- 按 excludePaths / includePaths 过滤文件
- Flexbox gap 上下文区分（gap-context-scanner.js）
- 输出 schema 校验（output-validator.js）

**仅在以下场景 AI 手动对照**（<50 行微型代码块）：

- 用户只贴了一小段代码问「这段能用么」
- 用 `grep_search` 快速定位候选违规点
- 用 `read_file` 确认上下文（避免误报）

### Step 5：输出报告

按 `SKILL.md §输出规范`：

- 单项违规格式（严重度 + 文件路径 + 问题 + 修复）
- Summary 表格
- 结论（Approve / Warning / Block）

### Step 6：违规后交互

发现违规时，必须调用 `ask_followup_question` 弹出交互式选项：

| 选项 | 说明 |
|------|------|
| 🔧 全部修复 | AI 自动修复所有 🔴 违规（🟡 按用户选择）|
| ✏️ 部分修复 | 告诉 AI 修哪几项 |
| 📖 查看修复方案详情 | 加载 `references/fix-patterns.md` 展开详细方案 |
| ⏭️ 跳过 | 仅记录，不修复（需说明业务理由）|

---

## 示例输出

```markdown
## 兼容性扫描报告

**扫描范围**：`git diff`（3 个文件，127 行改动）
**项目基线**：保守型（Safari 12+ / Chrome 70+，来自 `package.json > browserslist`）

### 发现问题

[🔴 CRITICAL] 使用了 `structuredClone()`
文件：`src/utils/clone.ts` L15
问题：Safari 15.4+ 才支持，项目基线为 Safari 12+
修复：改用 `JSON.parse(JSON.stringify(x))` 或引入 `lodash.cloneDeep`

[🟡 WARNING] 使用了 `backdrop-filter`
文件：`src/components/Modal.module.scss` L28
问题：Safari 需 `-webkit-` 前缀，且不支持时需兜底
修复：添加 `-webkit-backdrop-filter` 前缀 + `@supports not (backdrop-filter: blur())` 降级

### Summary

| 严重度 | 数量 | 状态 |
|--------|------|------|
| 🔴 CRITICAL | 1 | 🚫 Block |
| 🟡 WARNING | 1 | ⚠️ 需确认 |

结论: 🚫 BLOCK — 1 个 CRITICAL 必须修复后才能合并。
```
