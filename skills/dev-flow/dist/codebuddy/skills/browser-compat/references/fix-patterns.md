---
reference: browser-compat/fix-patterns
load_when: 发现兼容性违规需要查修复方案时
---

# Polyfill / 替代方案 Cookbook

违规后的具体修复方案。**内容源自远程知识库 `browser-compat-guide.md`**。

---

## JS API 替代方案

### `Array.prototype.at()` → slice/length

```js
// ❌ 禁用
const last = arr.at(-1);
const second = arr.at(1);

// ✅ 替代
const last = arr[arr.length - 1];
// 或
const last = arr.slice(-1)[0];
const second = arr[1];
```

### `structuredClone()` → JSON 克隆 / lodash

```js
// ❌ 禁用
const copy = structuredClone(obj);

// ✅ 方案 A：JSON 克隆（适用于无 Function / undefined / Date 的纯数据）
const copy = JSON.parse(JSON.stringify(obj));

// ✅ 方案 B：lodash.cloneDeep（推荐，处理复杂场景）
import cloneDeep from 'lodash/cloneDeep';
const copy = cloneDeep(obj);
```

### `Object.hasOwn()` → hasOwnProperty.call

```js
// ❌ 禁用
if (Object.hasOwn(obj, 'key')) { ... }

// ✅ 替代
if (Object.prototype.hasOwnProperty.call(obj, 'key')) { ... }
```

### `Array.prototype.toSorted/toReversed/toSpliced` → 展开 + 原方法

```js
// ❌ 禁用
const sorted = arr.toSorted();
const reversed = arr.toReversed();

// ✅ 替代
const sorted = [...arr].sort();
const reversed = [...arr].reverse();
```

### `Object.groupBy / Map.groupBy` → reduce

```js
// ❌ 禁用
const grouped = Object.groupBy(items, item => item.category);

// ✅ 替代
const grouped = items.reduce((acc, item) => {
  const key = item.category;
  (acc[key] ||= []).push(item);
  return acc;
}, {});
```

### `Promise.withResolvers` → 手写

```js
// ❌ 禁用
const { promise, resolve, reject } = Promise.withResolvers();

// ✅ 替代
let resolve, reject;
const promise = new Promise((res, rej) => {
  resolve = res;
  reject = rej;
});
```

### `crypto.randomUUID()` → uuid 包

```js
// ❌ 禁用
const id = crypto.randomUUID();

// ✅ 替代
import { v4 as uuidv4 } from 'uuid';
const id = uuidv4();
```

---

## CSS 属性替代方案

### `:has()` 选择器

**原理**：`:has()` 是父选择器，Safari 15.4+ / Chrome 105+ 才支持。保守型基线不可用。

```scss
// ❌ 禁用
.card:has(> .badge) {
  padding-right: 40px;
}

// ✅ 替代：JS 判断 + className
```

```jsx
// 组件内
<div className={`card ${hasBadge ? 'card--with-badge' : ''}`}>
  {hasBadge && <Badge />}
</div>
```

```scss
.card--with-badge {
  padding-right: 40px;
}
```

### `container-type` / 容器查询

**替代**：`ResizeObserver` + JS 计算

```jsx
const containerRef = useRef(null);
const [size, setSize] = useState('small');

useEffect(() => {
  const ro = new ResizeObserver(([entry]) => {
    const w = entry.contentRect.width;
    setSize(w > 600 ? 'large' : w > 300 ? 'medium' : 'small');
  });
  if (containerRef.current) ro.observe(containerRef.current);
  return () => ro.disconnect();
}, []);

return <div ref={containerRef} className={`card card--${size}`}>...</div>;
```

### Flexbox `gap` → margin

```scss
// ❌ 禁用（Safari 14.1 以下不支持）
.list {
  display: flex;
  gap: 12px;
}

// ✅ 替代：margin + 负 margin 抵消
.list {
  display: flex;
  margin: -6px;

  > * {
    margin: 6px;
  }
}
```

### `aspect-ratio` → padding-bottom 百分比

```scss
// ❌ 禁用
.thumb {
  aspect-ratio: 16 / 9;
}

// ✅ 替代
.thumb-wrapper {
  position: relative;
  padding-bottom: 56.25%; // 9 / 16 * 100%

  .thumb {
    position: absolute;
    inset: 0;
    top: 0; right: 0; bottom: 0; left: 0; // inset 也禁用时展开
  }
}
```

### `inset` 简写 → 展开四个方向

```scss
// ❌ 禁用
.overlay { inset: 0; }
.overlay { inset: 10px 20px; }

// ✅ 替代
.overlay {
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
}
```

### `color-mix()` → CSS 变量 + 预计算

```scss
// ❌ 禁用
.btn {
  background: color-mix(in srgb, var(--brand) 80%, white);
}

// ✅ 替代：设计阶段预计算 + CSS 变量
:root {
  --brand: #4a90e2;
  --brand-80: #6aa5e8; // 手动混合后的结果
}

.btn {
  background: var(--brand-80);
}
```

### `@layer` 级联层 → 选择器优先级

```scss
// ❌ 禁用
@layer base, components, utilities;
@layer components { .btn { ... } }

// ✅ 替代：命名空间 + BEM
.app {
  .btn { ... }  // 通过嵌套提升优先级
}
```

### `backdrop-filter` + 降级

```scss
// ✅ 需降级
.modal-bg {
  background: rgba(0, 0, 0, 0.5); // 降级兜底

  @supports (backdrop-filter: blur(10px)) or (-webkit-backdrop-filter: blur(10px)) {
    background: rgba(255, 255, 255, 0.2);
    -webkit-backdrop-filter: blur(10px);
    backdrop-filter: blur(10px);
  }
}
```

---

## 特性检测模板

```js
// JS 特性检测
if (typeof ResizeObserver !== 'undefined') {
  // 使用 ResizeObserver
} else {
  // 降级为 window.resize + getBoundingClientRect
}

// CSS 特性检测（@supports）
@supports (display: grid) {
  // 使用 Grid
}
@supports not (display: grid) {
  // Flexbox 降级
}
```

---

## 工具链兜底（工程化方案）

> 本节内容源自浏览器兼容性知识库

### 自动降级工具链

| 工具 | 作用 | 配置位置 |
|------|------|---------|
| **Babel** + `@babel/preset-env` | 根据 `browserslist` 自动转译 JS 语法 | `babel.config.js` |
| **Autoprefixer**（PostCSS）| 自动添加 `-webkit-` / `-moz-` 前缀 | `postcss.config.js` |
| **PostCSS Preset Env** | 让新 CSS 特性自动降级 | `postcss.config.js` |
| **core-js** | Polyfill ES 新 API（useBuiltIns: 'usage'）| Babel 配置引用 |

### 关键：browserslist 统一基线

确保 `package.json > browserslist` 和 `.browser-compat.json > target` 一致，这样 Babel / Autoprefixer / 本 skill 的判定会对齐。
