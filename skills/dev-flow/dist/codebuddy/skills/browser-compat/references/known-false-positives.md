---
reference: browser-compat/known-false-positives
load_when: 用户对扫描结果有疑问 / 想了解误报场景与豁免方法 / 配置 customRules 前
---

# 已知误报场景与豁免方法

> compat-check.js 基于正则 + 简易词法状态机实现，故意取「性价比折中」而非完整 AST 解析。
> 本文档记录已知误报场景及对应豁免手段，便于用户决策时参考。

---

## 一、JS 正则误报场景

### 1.1 `no-array-at`：第三方库的 `.at()` 同名方法

**触发**：脚本正则 `\b(\w+)\.at\(\s*-?\d+\s*\)` 会匹配所有形如 `xxx.at(N)` 的调用。

**误报代码**：

```js
// 第三方库自定义的 .at（与 Array.prototype.at 无关）
const node = tree.at(0);                 // tree 是 react-flow 的某种节点容器
const point = pathBuilder.at(-1);        // svg-path-builder 的命令查询
```

**豁免方法**：

- 行级：在该行末尾加 `// @compat-ignore: 第三方库 xxx 的非数组方法`
- 项目级：在 `.browser-compat.json` 的 `ignore` 中追加 `{ "rule_id": "no-array-at", "reason": "..." }`（**不推荐**，会全局禁用此检查）

### 1.2 `no-structured-clone`：自定义同名函数

**误报代码**：

```js
// 项目内部封装了同名函数
function structuredClone(x) { return JSON.parse(JSON.stringify(x)); }
const a = structuredClone(b);   // ❌ 会被报警，但其实是项目内部安全实现
```

**豁免方法**：

- 行级：`@compat-ignore` 标记
- **更好**：把项目内部封装重命名（如 `safeClone`），避免与原生 API 同名

### 1.3 `no-crypto-randomuuid`：Node.js 服务端代码

**触发**：脚本不区分浏览器 / Node 环境。Node 14.17+ / 16+ 的 `crypto.randomUUID()` 可用。

**误报代码**：

```js
// server/utils/id.js（仅 Node 环境运行）
import crypto from 'node:crypto';
export const newId = () => crypto.randomUUID();
```

**豁免方法**：

- 在 `.browser-compat.json` 的 `excludePaths` 中加入服务端目录（如 `"server/**"`）
- 或在 `includePaths` 显式声明仅扫描 `src/**` 等浏览器侧目录

---

## 二、CSS 正则误报场景

### 2.1 `no-flexbox-gap`：SCSS 嵌套继承未实现（v1 限制）

**触发**：gap-context-scanner 第一版仅判定「直接所在块的 display 声明」，不向外层继承。

**误报代码**：

```scss
.parent {
  display: flex;
  .child {
    gap: 8px;            // 实际语义上属于 flex 子项的样式，但在 scanner 眼中此块无 display → WARNING
  }
}
```

**当前行为**：报 WARNING（不报 CRITICAL，避免阻断），但仍提示「需要人工确认」。

**豁免方法**：

- 行级：`gap: 8px; /* @compat-ignore: 嵌套于 flex 父级 */`
- **更好**：把 gap 写在与 display:flex 同一块内（也是 SCSS 最佳实践）

### 2.2 `no-inset-shorthand`：误吞 `box-shadow: inset`

**触发**：正则 `(^|[\s;{])inset\s*:\s*[^;]+` 已用「冒号紧跟」避免大部分情况。

**残余误报**：

```scss
.foo {
  box-shadow:
    inset 0 0 4px rgba(0,0,0,.5);   // 不会报（'inset' 后无冒号）
  inset: 0;                          // 会报 ✅ 正确
}
```

**豁免方法**：通常无需。若确实有罕见 false-positive，用行级 `@compat-ignore`。

### 2.3 `warn-backdrop-filter`：原代码已用 `-webkit-` 前缀

**触发**：正则 `(?<!-webkit-)backdrop-filter:` 只跳过紧邻前缀的情况。

**残余误报**：跨行声明时可能漏判：

```scss
.modal {
  -webkit-backdrop-filter: blur(8px);
  backdrop-filter: blur(8px);   // 会被报警（与 -webkit- 不同行）
}
```

**当前行为**：报 WARNING，提示用户「确认是否已加前缀」。

**豁免方法**：行级 `@compat-ignore: 已加 -webkit- 前缀`，或忽略 WARNING（不阻断合并）。

---

## 三、上下文相关的兜底策略

### 3.1 行级豁免（最常用，推荐）

```js
const last = arr.at(-1); // @compat-ignore: 第三方库非数组对象
```

```scss
gap: 12px; /* @compat-ignore: 嵌套于 flex 父级 */
```

支持位置：

- 同行行尾（任意位置出现 `@compat-ignore` 关键字即生效）
- 同行块注释 `/* @compat-ignore: ... */`

### 3.2 文件级豁免（通过排除路径）

`.browser-compat.json`：

```json
{
  "excludePaths": [
    "src/server/**",
    "src/legacy/**"
  ]
}
```

### 3.3 规则级豁免（业务理由必填）

`.browser-compat.json`：

```json
{
  "ignore": [
    { "rule_id": "no-has-selector", "reason": "管理后台仅 Chrome 105+ 访问" }
  ]
}
```

### 3.4 Polyfill 声明（自动跳过对应规则）

`.browser-compat.json`：

```json
{
  "polyfills": ["ResizeObserver", "IntersectionObserver"]
}
```

> 注：当前规则集中并未对 ResizeObserver/IntersectionObserver 做自动检测，
> 此字段为面向未来扩展。详见 `scripts/lib/rule-filter.js` 中的 `POLYFILL_MAP`。

---

## 四、性能边界与已知限制

| 场景 | 边界 | 建议 |
|------|------|------|
| 单文件 > 5000 行 | 正则扫描时间 < 200ms | 无影响 |
| 项目 > 10000 文件 | 全量扫描可能 > 30s | 用 `--diff` 模式或拆批扫描 |
| Vue 单文件组件 `.vue` | **当前不识别** | v2 规划支持，临时方案：用 `<script>` `<style>` 拆出后扫描 |
| TypeScript 类型注解 | 已识别 `.ts/.tsx` 扩展名 | 无影响 |
| 动态字符串拼接 | **不识别**（如 `el['at'](-1)`） | 这类代码本身就难审计，建议改写 |

---

## 五、与设计哲学的对应

> 「确定性的事情用代码，模糊的事情用 LLM」。

本文档列出的所有「误报判定 + 是否豁免」**都属于「模糊性」**，由 LLM/用户决策。
脚本的职责是「找出疑似违规点」，而非「判断这一处该不该豁免」。

如果某类误报 ×3 次以上稳定出现，应：

1. 优先调整 `.browser-compat.json` 配置（确定性兜底）
2. 仍无法解决再考虑修改 `compat-check.js` 的正则（精确化）
3. 修改正则前必须更新本文档 + 跑 `tests/run-tests.sh` 全量回归
