---
module: "autocomplete"
theme: "pitfalls"
confidence: "pending"
created: "2026-08-18"
last_updated: "2026-08-18"
---

# AutoComplete 易错点

## P1：antdv 4.2.6 调色板是「键从 1 开始的对象」，禁止按数组索引推演

```javascript
// antdv 4.2.6 generateColorPalettes 真实实现（theme/themes/shared/genColorMapToken.js）
return {
  1: colors[0], 2: colors[1], 3: colors[2], 4: colors[3],
  5: colors[4], 6: colors[5], 7: colors[6],
  8: colors[4], 9: colors[5], 10: colors[6]   // ← 8/9/10 复用 4/5/6 号色！
}
```

- 教训：对齐 antdv 色值时，**必须运行 antdv 源码函数实测**（`genColorMapToken` + `getAlphaColor`），禁止凭数组索引心算
- 实测结果：`colorErrorHover=errorColors[5]=#ff7875`，`colorWarningHover=warningColors[4]=#ffd666`（键 4 对应 colors[3]）
- AutoComplete/Select 的 status 三态（默认/hover/focus）边框**同色**（都用 borderHoverColor），与 Input 不同（Input 默认态用主色、hover 才用 hover 色）

## P2：filterOption 默认值与 antdv 一致（已裁决，无需修改）

- 本库默认 `false`（远程搜索场景：不筛选、全量显示，由 `search` 事件更新 options）
- **antdv 4.2.6 源码默认也是 `false`**（`auto-complete/index.tsx` L35 与 `es/auto-complete/index.js` L46-49：`filterOption: { type: [Boolean, Function], default: false }`）
- antdv 官网 API 文档写 `true` 是**文档错误**，以源码为准
- 结论：本库 `false` 与 antdv 源码行为完全一致，保持现状

## P3：面板定位依赖面板渲染后的 offsetWidth

- `display: none` 时 `offsetWidth` 读到 0 → `getAlign` 判定失效
- `getPosition` 必须 await `nextTick()` 后再读，且 Teleport 挂载后 `positionedContainerRect` 才有值
- 首次打开面板时若宽度异常，检查读取时机而非判定逻辑

## P4：水平对齐判定禁止简化成「面板宽 vs 视口宽」

- 反例：视口 500、面板 300、输入框靠右（left=280）→ 左对齐溢出右侧，但「面板宽<视口宽」判断会漏掉右对齐切换
- 正解：实际遮挡检测（左对齐是否溢出右侧 → 右对齐是否溢出左侧 → 都溢出贴视口左）

## P5：vitepress 文档环境从 dist 加载组件

- 新增/修改组件后，文档页会出现 `Failed to resolve component: XXX`
- 解决：先 `npm run build:dist` 再刷新文档（docs:dev 不会自动重建 dist）

## P6：回填与 lastUserValue 的污染边界

- `emit('update:value', 回填值)` **不会**触发子组件自身的 onInput（v-model 是父→子回流）
- 因此 lastUserValue 只在 onInput/onCompositionEnd/onSelectOption/onClear 维护即可
- 若把 lastUserValue 更新放进 emit 回填路径，Esc 还原会失效

## P7：demo 双组件对照页的测试注入注意

- 演示页本库/antdv 组件各 21 个，Playwright 定位必须用索引而非首个匹配
- 编程式 `input.focus()` 不触发 Vue 的 onFocus（合成事件无效），需真实 click 或 `focus()+click()` 组合
- `querySelector('.auto-complete-panel')` 只取第一个面板，Teleport 到 body 后多面板共存，需按 `style.width` 过滤目标面板
