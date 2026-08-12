# 运行时自检验证规范

## 背景

AI 无法"看到"页面实际渲染效果，所有涉及视觉表现、运行时行为的验证都依赖用户反馈。为减少"改了但不知道对不对→用户发现不对→回退修复"的低效循环，必须在改动代码中主动埋入自检机制，让代码自己报告状态。

## 适用场景

以下类型的改动**必须**添加自检日志：

| 改动类型 | 示例 |
|---------|------|
| DOM 操作/查询 | `getElementById`、`querySelector`、`getBoundingClientRect` |
| 样式/布局计算 | `getComputedStyle`、`offsetWidth`、动态 `maxWidth` |
| 动画/定位相关 | Popper、Tooltip 翻转、CSS transform、transition |
| 事件监听/回调 | `resize`、`ResizeObserver`、`IntersectionObserver` |
| 状态联动 | 多个 `useState`/`useEffect` 联动、异步状态更新 |
| 条件分支逻辑 | `if (appScreenSize === Small)`、媒体查询断点判断 |

以下类型的改动**不需要**添加自检日志：

- 纯文案/翻译修改
- 简单样式调整（颜色、字号等静态值）
- 类型定义修改
- 导入语句调整

## 自检日志规范

### 1. 日志标签格式

使用统一的标签前缀，方便在 DevTools Console 中过滤：

```ts
// 格式：[模块名:功能名]
console.log('[翻译气泡:dynamicRightSpace]', safeWidth, { rawPanelLeft, paddingCompensation });
console.log('[时间轴:maxBubbleWidth]', dynamicRightSpace);
```

### 2. 关键节点必须打日志

**DOM 获取**：验证元素是否成功获取
```ts
const rawPanel = document.getElementById('tm-video-mask-container');
console.log('[翻译气泡:DOM]', rawPanel ? '获取成功' : '❌ 获取失败（DOM 未挂载？）');
```

**计算过程**：记录输入值和输出值
```ts
const rawPanelLeft = rawPanel.getBoundingClientRect().left;
const safeWidth = Math.max(Math.floor(document.body.clientWidth - rawPanelLeft - 20), 200);
console.log('[翻译气泡:计算]', { viewportWidth: document.body.clientWidth, rawPanelLeft, safeWidth });
```

**状态更新**：验证 setState 是否被调用
```ts
setDynamicRightSpace(safeWidth);
console.log('[翻译气泡:setState]', 'dynamicRightSpace =', safeWidth);
```

**回调触发**：验证事件监听是否生效
```ts
window.addEventListener('resize', () => {
  console.log('[翻译气泡:resize] 触发');
  calcRightSpace();
});
```

### 3. console.assert 断言关键前置条件

对于"如果这个条件不满足，后续逻辑一定会出错"的关键前置条件，使用 `console.assert`：

```ts
const rawPanel = document.getElementById('tm-video-mask-container');
console.assert(rawPanel !== null, '[翻译气泡] rawPanel 为 null，检查：1. DOM 是否已挂载 2. id 是否正确');

const safeWidth = Math.max(...);
console.assert(safeWidth > 0, '[翻译气泡] safeWidth <= 0，计算逻辑有误');
console.assert(safeWidth < 2000, '[翻译气泡] safeWidth 异常大，可能取到了错误的元素');
```

### 4. 条件分支标记

当改动涉及条件分支时，标记实际走了哪个分支：

```ts
if (appScreenSize === AppScreenSize.Small) {
  console.log('[翻译气泡:分支] 小屏模式，补偿 12px');
  paddingCompensation = 12;
} else {
  console.log('[翻译气泡:分支] 大屏模式，无补偿');
  paddingCompensation = 0;
}
```

## 用户验证指南（改动汇总必须包含）

> 📌 改动汇总中引用的文件/代码位置必须按 `~/.codebuddy/rules/AI行为规范.mdc` 的「文件/代码位置引用」规范使用反引号包裹相对路径格式（`` `相对路径` `` + 空格后缀行号）。

每次涉及运行时行为的改动完成后，改动汇总中**必须**包含一个"验证指南"章节，格式如下：

```markdown
### 用户验证指南

1. 打开页面，按 F12 打开 DevTools → Console
2. 在 Console 过滤器中搜索 `[翻译气泡]`
3. 缩小浏览器窗口，应看到以下日志：
   - `[翻译气泡:resize] 触发` — 确认 resize 监听生效
   - `[翻译气泡:计算] { viewportWidth: xxx, rawPanelLeft: xxx, safeWidth: xxx }` — 确认计算正常
   - `safeWidth` 应该是一个合理的正数（通常 200~800 之间）
4. 翻译气泡应该从右侧弹出，不应该 flip 到左侧
5. 如果看到 `❌ 获取失败` 或 assert 报错，说明改动有问题
```

## 自检日志的生命周期

| 阶段 | 操作 |
|------|------|
| 开发中 | 添加自检日志，用于验证改动正确性 |
| 验证通过后 | 在步骤 7（清理与汇总）中，**将自检日志列入清理清单** |
| 用户确认清理 | 删除所有自检日志（`console.log`、`console.assert`） |
| 提交代码 | 确保不包含任何调试日志 |

**注意**：自检日志是临时的调试工具，不是生产代码。必须在验证通过后清理。

## 不适用自检日志的场景及替代方案

| 场景 | 替代方案 |
|------|---------|
| 需要验证视觉效果（颜色、布局、动画流畅度） | 告知用户具体的视觉检查点 |
| 需要验证用户交互流程 | 提供操作步骤清单 |
| 需要验证跨页面/跨组件联动 | 多个组件分别加日志 + 提供验证操作序列 |
| 需要验证性能（渲染次数、FPS） | 使用 `React Profiler` 或 `Performance` 面板 |
