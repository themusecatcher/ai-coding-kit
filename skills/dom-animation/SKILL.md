---
name: dom-animation
description: DOM 定位与动画开发规范。适用于涉及 DOM 定位、PopperJS、CSS 动画、transform 的开发场景。涵盖渲染链路分析、调试日志、生命周期管理等核心规则。
keywords: ["DOM定位", "CSS动画", "PopperJS", "transform", "渲染链路", "动画开发", "dom-animation"]
---

# DOM 定位与动画开发规范

> 从开发规范附录 G 迁移，按需加载。适用于涉及 DOM 定位、PopperJS、CSS 动画、transform 的开发场景。

## 1. 必须完整分析渲染链路
- ✅ 从组件追溯到底层实现（如 Bubble → Popover → OverlayLayer → PopperJS → ScaleTransition）
- ✅ 明确 DOM 节点完整生命周期（插入 → 定位 → 动画 → 可见）
- ✅ 明确 transform/transition/animation 的具体参数和时序
- ❌ 禁止跳过源码分析直接基于表面行为假设

## 2. 第一版代码必须包含调试日志
- ✅ 关键 DOM API 返回值（`getBoundingClientRect`、`offsetWidth`、`getComputedStyle`）
- ✅ 计算过程中间值（overflowLeft、overflowRight、offset）
- ✅ 时序信息（哪个回调先触发、动画处于什么阶段）
- ❌ 禁止连续多轮修复都不加日志让用户"肉眼验证"

## 3. offsetWidth 优先于 getBoundingClientRect
当存在 CSS transform（如 `scale3d`）时：
- `getBoundingClientRect()` → transform 后的视觉尺寸（随动画逐帧变化）
- `offsetWidth`/`offsetHeight` → CSS 布局真实尺寸（不受 transform 影响）
- ✅ 定位计算用 `offsetWidth`/`offsetHeight`
- ❌ 禁止在 transform 动画时用 `getBoundingClientRect` 做定位计算

## 4. "首次锁定"模式
- ✅ 计算一次 → 锁定 → 后续不再重算（如 `initialAdjustDoneRef`）
- ❌ 禁止动画进行中持续重算定位偏移

## 5. DOM 查询时序（优化时破坏 DOM 获取时序反模式）
- DOM 查询需要每次回调获取最新引用时，**必须放在回调内部**
- 唯一例外是用于注册 `ResizeObserver` 的一次性调用（但仅用于注册，不用于计算）
- 优化前必须分析执行时序：effect 执行时 DOM 是否已挂载？回调是否需要最新引用？
- **优化核心原则**：不改变代码行为，只改善代码表达。改变执行时序或闭包捕获的不是优化，是破坏。
