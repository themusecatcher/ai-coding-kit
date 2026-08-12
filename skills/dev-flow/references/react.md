# React 开发规范

> 基础底线（函数式组件、useEffect cleanup、memo/useMemo/useCallback、JSX 布尔属性、避免复杂表达式等）见 `开发规范-红线.mdc` § React，本文不重复。本文为 step-5 按需加载的专项补充。

---

## 代码风格与结构

- 函数式 + 声明式编程，禁止 class 组件
- 组件定义使用 `function` 关键字（非箭头函数），工具函数/回调仍可用箭头函数
- 偏向迭代和模块化，避免代码重复
- 描述性变量名：`isLoading`、`hasError`、`isSubmitting`
- 文件结构：导出组件 → 子组件 → 辅助函数 → 静态内容 → 类型
- 条件语句中简单语句省略不必要的大括号，使用简洁语法

## 命名约定

- 组件用 PascalCase：`UserProfile`、`ArticleCard`
- 偏向为组件使用命名导出（`export function UserProfile`）
- 目录用小写 + 短横线：`components/auth-wizard/`
- 自定义 Hook 以 `use` 开头：`useDebounce`、`useIsMounted`
- 事件处理函数以 `handle` 开头：`handleClick`、`handleSubmit`

## TypeScript 使用

- 所有代码用 TypeScript，启用严格模式
- 优先用 `interface` 定义 props 类型，而非 `type`
- 避免 enum，用字面量联合类型或 `as const` 映射替代
- 组件 props 用接口定义：`interface UserCardProps { user: User; onEdit: (id: string) => void }`

## 性能优化

- 避免不必要的重渲染：`React.memo` 包裹纯展示组件
- 稳定引用：非原始类型 props（对象/数组/回调）用 `useMemo` / `useCallback`
- 惰性初始化：`useState(() => computeExpensiveValue())`
- 图片优化：优先 WebP 格式，使用懒加载
- 代码分割：`React.lazy` + `Suspense` 分割非关键路由
- Portal：Modal、Tooltip、Dropdown 等需要脱离父容器 DOM 层级渲染时使用 `createPortal`

```jsx
// ✅ 稳定的回调引用
const handleSave = useCallback((id: string) => {
  saveData(id, formState);
}, [formState]);

// ❌ 每次渲染都产生新引用
const handleSave = (id: string) => saveData(id, formState);
```

## 状态管理

- 简单局部状态用 `useState` + `useReducer`
- 跨层级共享用 React Context，避免 props 层层传递
- 服务端数据用 `react-query`（@tanstack/react-query）管理缓存和请求
- 复杂全局状态考虑 Zustand（轻量）或 Redux Toolkit
- URL 状态（搜索参数、筛选条件）用路由参数，非本地 state

```jsx
// react-query 典型用法
const { data, isLoading, error } = useQuery({
  queryKey: ['article', articleId],
  queryFn: () => fetchArticle(articleId),
  enabled: !!articleId,
});
```

## 错误处理

- 组件树顶层用 Error Boundary 兜底崩溃
- 事件处理中的错误必须捕获并提示用户，禁止空 catch
- 用早返回（early return）处理异常分支，避免深层嵌套

```jsx
// ✅ 早返回
function ArticleDetail({ article }: { article?: Article }) {
  if (!article) return <NotFound message='文章不存在' />;
  if (article.status === 'archived') return <ArchivedNotice article={article} />;
  return <ArticleContent article={article} />;
}

// ❌ 深层嵌套
function ArticleDetail({ article }: { article?: Article }) {
  if (article) {
    if (article.status !== 'archived') {
      return <ArticleContent article={article} />;
    } else {
      return <ArchivedNotice article={article} />;
    }
  } else {
    return <NotFound />;
  }
}
```

## 安全性

- 用户输入渲染前必须转义（React 默认防 XSS，但 `dangerouslySetInnerHTML` 必须 `DOMPurify.sanitize`）
- 敏感数据（token/密钥）存放在环境变量，禁止硬编码
- API 通信强制 HTTPS，使用适当身份验证头

## 测试

- 单元测试：Jest + React Testing Library，侧重行为而非实现
- 关键用户流程：考虑集成测试覆盖（如 Cypress / Playwright）
- 纯工具函数必须有测试覆盖

## 常见错误模式

### 错误 1：props 内联对象导致无效重渲染

```jsx
// ❌ 每次渲染 style 都是新对象，子组件必然重渲染
<Avatar style={{ width: 32, height: 32 }} />

// ✅ 静态值：提取到组件外
const AVATAR_SIZE = { width: 32, height: 32 };
<Avatar style={AVATAR_SIZE} />

// ✅ 依赖 props/state 的动态值：用 useMemo 稳定引用
const style = useMemo(() => ({ width: size, height: size }), [size]);
<Avatar style={style} />
```

### 错误 2：条件渲染时 Hooks 顺序变化

```jsx
// ❌ Hook 在条件分支内，违反 Hooks 规则
if (isAdmin) {
  const data = useAdminData(); // bug: Hook 数量可能变化
}

// ✅ Hook 始终调用，内部做条件判断
const { data } = useQuery({
  queryKey: ['admin', 'data'],
  queryFn: fetchAdminData,
  enabled: isAdmin,
});
```

### 错误 3：状态提升过早

```jsx
// ❌ 为单一组件提升到父级，增加传染范围
function Parent() {
  const [open, setOpen] = useState(false);
  return <Child open={open} onToggle={setOpen} />;
}

// ✅ 状态就近，需要共享时才提升
function Child() {
  const [open, setOpen] = useState(false);
  return <Modal open={open} onClose={() => setOpen(false)} />;
}
```

---

## useRef 模式

`useRef` 是除 `useState`/`useEffect` 外第三高频 Hook，两个核心用途：

### 用途 1：DOM 节点引用

```jsx
function SearchInput() {
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    // 组件挂载后自动聚焦
    inputRef.current?.focus();
  }, []);

  return <input ref={inputRef} placeholder='搜索...' />;
}
```

### 用途 2：可变值（不触发重渲染）

```jsx
function Timer() {
  const timerRef = useRef<ReturnType<typeof setInterval>>();
  const [count, setCount] = useState(0);

  useEffect(() => {
    timerRef.current = setInterval(() => {
      setCount(prev => prev + 1);
    }, 1000);
    return () => clearInterval(timerRef.current);
  }, []);

  return <span>{count}</span>;
}
```

### 用途 3：保存前值

```jsx
function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T>();
  useEffect(() => { ref.current = value; });
  return ref.current;
}
```

> ⚠️ 关键区别：`ref.current = ...` 不触发重渲染，`setState(...)` 触发。不要用 state 存储定时器 ID、动画实例等不需要驱动 UI 的值。

### useLayoutEffect vs useEffect

- `useEffect`：浏览器绘制**后**异步执行，适合数据请求、订阅
- `useLayoutEffect`：DOM 变更**后**、浏览器绘制**前**同步执行，适合 DOM 测量和同步更新

```jsx
// ✅ 测量 DOM 尺寸后再渲染，避免闪烁
useLayoutEffect(() => {
  setHeight(measureRef.current?.offsetHeight ?? 0);
}, [content]);
```

---

## 受控 vs 非受控组件

React 表单元素的核心分歧点，混淆会导致 "A component is changing an uncontrolled input" warning。

- **受控**：值由 React state 管理，需要 `value` + `onChange`（如 `<input value={name} onChange={handleChange} />`）
- **非受控**：值由 DOM 自身管理，用 `defaultValue` + `ref`（如 `<input defaultValue='初始值' ref={ref} />`）

```jsx
// ❌ 从非受控切换到受控（或反之）触发 warning
<input value={isEditing ? text : undefined} />  // undefined → 非受控

// ✅ 始终受控，用空字符串代表空值
<input value={text ?? ''} onChange={handleChange} />

// ✅ 始终非受控，用 key 强制重新挂载来重置
<input key={resetKey} defaultValue='' />
```

> 核心原则：给定 input 的生命周期内，`value` 属性 **始终** 为 `undefined`（非受控）或始终为定义值（受控），禁止中途切换。

---

## Keys 与列表渲染

```jsx
// ❌ 用 index 做 key：列表重排序/增删时状态错乱
{todos.map((todo, index) => <TodoItem key={index} todo={todo} />)}

// ✅ 用稳定唯一标识做 key
{todos.map(todo => <TodoItem key={todo.id} todo={todo} />)}
```

**关键规则**：

- key 必须在其兄弟节点中**唯一且稳定**
- 禁止 `Math.random()` / `Date.now()` 作为 key（每次渲染都变，导致全部重挂载）
- 可用 `key` **强制重挂载**组件（如重置表单、重新播放动画）
- 无合适 ID 时用 `crypto.randomUUID()` 在数据创建时生成，**不要**在渲染中生成

---

## forwardRef + useImperativeHandle

封装组件时需要暴露内部 DOM 节点或命令式 API 给父组件时使用。

```jsx
interface InputRef {
  focus: () => void;
  clear: () => void;
}

const CustomInput = forwardRef<InputRef, { label: string }>(({ label }, ref) => {
  const inputRef = useRef<HTMLInputElement>(null);

  useImperativeHandle(ref, () => ({
    focus: () => inputRef.current?.focus(),
    clear: () => { if (inputRef.current) inputRef.current.value = ''; },
  }));

  return <label>{label}<input ref={inputRef} /></label>;
});

// 父组件使用
<CustomInput ref={inputRef} label='姓名' />
```

> ⚠️ 优先通过 props 传递数据，仅在确实需要命令式控制（focus/scroll/measure）时才暴露 ref。

---

## React Native / Expo 专项

> 适用场景：React Native 项目（含 Expo 托管 / 裸工作流）。

### UI 与样式

- 使用 Flexbox + `useWindowDimensions` 实现响应式布局
- 深色模式：使用 `useColorScheme` 适配
- 可访问性：使用 ARIA 角色和平台原生可访问属性
- 高性能动画与手势：使用 `react-native-reanimated` + `react-native-gesture-handler`

### 安全区域管理

- 全局用 `SafeAreaProvider`（来自 `react-native-safe-area-context`）
- 顶层组件使用 `SafeAreaView` 包裹，处理刘海、状态栏等
- 可滚动内容用 `SafeAreaScrollView`
- **禁止**为安全区域硬编码 padding/margin，依赖 SafeAreaView 和 context hooks

### 导航

- 路由使用 `react-navigation`，遵循 Stack / Tab / Drawer 导航器最佳实践
- 使用深度链接（deep link）和通用链接（universal link）提升导航体验
- Expo 项目使用 `expo-router` 的动态路由

### 国际化（i18n）

- 使用 `react-native-i18n` 或 `expo-localization` 实现国际化
- 支持多语言和 RTL 布局
- 确保文本缩放和字体调整以保证可访问性

### 性能优化（RN 专属）

- 简单局部状态用 `useState`，复杂状态逻辑（多个子值/状态转换）用 `useReducer`
- 使用 `AppLoading` 和 `SplashScreen` 优化启动体验
- 图片优化：优先 WebP，使用 `expo-image` 实现延迟加载
- 使用 `React.lazy` + `Suspense` 为非关键组件做代码拆分
- 通过 `React.memo`、`useMemo`、`useCallback` 避免无效重渲染

### 错误处理补充

- 运行时校验使用 Zod 进行类型验证
- 使用 Sentry 或类似服务记录错误
- 生产环境使用 `expo-error-reporter` 记录和上报错误
- Error Boundary：见主节「错误处理」

### 安全性补充

- 敏感数据使用 `react-native-encrypted-storage` 安全存储
- 遵循 Expo 安全指南：[Expo Security](https://docs.expo.dev/guides/security/)

### 测试（RN 专属）

- 单元测试：Jest + React Native Testing Library
- 关键用户流程集成测试：使用 Detox
- 使用 Expo 测试工具链在不同环境中运行测试
- 考虑为组件实施快照测试以保证 UI 一致性

### Expo 关键约定

1. 依赖 Expo 托管工作流简化开发和部署
2. 优先考虑移动端核心指标（加载时间、卡顿、响应性）
3. 使用 `expo-constants` 管理环境变量和配置
4. 使用 `expo-permissions` 优雅处理设备权限
5. 实施 `expo-updates` 进行 OTA 更新
6. 遵循 Expo 部署和发布最佳实践：[Expo Distribution](https://docs.expo.dev/distribution/introduction/)
7. 在 iOS 和 Android 双平台上广泛测试确保兼容性
