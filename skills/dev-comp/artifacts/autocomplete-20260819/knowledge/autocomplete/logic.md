---
module: "autocomplete"
theme: "logic"
confidence: "pending"
created: "2026-08-18"
last_updated: "2026-08-18"
---

# AutoComplete 逻辑层

## 1. 面板定位（panelPlacement / getPosition / getAlign）

### 数据流

```
panelVisible=true → getPosition()
  ├─ getPositionedContainer()          // 定位容器 rect
  ├─ contentRect / panelWidth / panelHeight
  ├─ panelOffset = contentHeight + 4
  ├─ panelPlace = getPlacement()       // 垂直：bottom/top（下方空间不足翻转）
  └─ panelAlign = getAlign()           // 水平：left/right/viewport-left
panelPlacement（computed）输出 top/bottom + left/right + transformOrigin + widthStyle
```

### 水平三态对齐（getAlign，核心算法）

```typescript
// 实际遮挡检测，禁止用「面板宽>视口宽」简化判定
function getAlign(): 'left' | 'right' | 'viewport-left' {
  const { left, right } = contentRect.value as DOMRect
  const width = panelWidth.value ?? 0
  const rightSpace = viewportWidth.value - left
  if (width > viewportWidth.value) return 'viewport-left'   // 面板比视口宽，贴视口左
  if (rightSpace < width && right >= width) return 'right'   // 左对齐溢出右侧且右对齐不溢出左侧
  return 'left'
}
```

| 态 | 定位 | transformOrigin | 触发条件 |
|----|------|----------------|---------|
| left | `left: offsetLeft` | `0 0/100%` | 左对齐不溢出 |
| right | `right: offsetRight` | `100% 0/100%` | 左对齐溢出右侧 + 右对齐左边缘 ≥ 0 |
| viewport-left | `left: -containerLeft` | `0 0/100%` | 面板宽 > 视口宽（左右都放不下） |

⚠️ 经验：`right >= width` 兜底防止右对齐后面板左边缘越过视口左侧；`panelWidth` 必须在面板渲染后读 `offsetWidth`（display:none 时读到 0）。

## 2. 键盘导航（onKeydown）

```typescript
function onKeydown(e: KeyboardEvent): void {
  if (props.disabled) return
  const list = flattenOptions.value  // 已展开的叶子选项（含 disabled 标记）
  // ↑↓：环形循环查找下一个未禁用项
  const currentIdx = list.findIndex((o) => !o.disabled && o.value === hoverValue.value)
  const start = e.key === 'ArrowDown'
    ? (currentIdx === -1 ? 0 : currentIdx + 1)
    : (currentIdx === -1 ? list.length - 1 : currentIdx - 1)
  const direction = e.key === 'ArrowDown' ? 1 : -1
  for (let i = 0; i < list.length; i++) {
    const idx = (start + direction * i + list.length) % list.length
    if (!list[idx].disabled) { /* 命中 */ break }
  }
  // backfill 时 emit update:value 回填（与 onHover 行为一致）
  // Enter：面板开 + 有未禁用高亮 → onSelectOption
  // Escape：emit update:value(lastUserValue) + setPanelOpen(false)
}
```

### lastUserValue 维护点

| 时机 | 值 |
|------|-----|
| onInput / onCompositionEnd | 用户主动输入内容 |
| onSelectOption | 选中项 value |
| onClear | `''` |

⚠️ 回填（onHover/onKeydown emit update:value）不会触发 onInput，lastUserValue 不会被回填污染——这是 Esc 还原正确性的关键。

## 3. 清除按钮显隐（showClear）

```typescript
// computed：有值即显示，不依赖 hover（与项目 Input 惯例一致；antdv 为 hover 显示）
const showClear = computed(() => props.allowClear && !props.disabled && Boolean(props.value))
```

- 模板 `:class="{ 'show-svg': showClear }"` 控制 opacity 0→1
- `onEnter`/`onLeave` 仅管理 `disabledBlur`（点击清除图标时防 blur 关闭）

## 4. 数据源归一化（flattenOptions）

```typescript
// 分组识别：item.options 存在即为 GroupOption
// 展开为叶子数组 [{ value, label, disabled }]
// 叶子渲染：分组内加 option-grouped 类（24px 缩进）
```

## 5. status 样式（antdv 4.2.6 实测值）

| 状态 | 三态边框（同色） | focus 阴影 |
|------|----------------|-----------|
| error | `#ff7875` | `0 0 0 2px rgba(255, 38, 5, 0.06)` |
| warning | `#ffd666` | `0 0 0 2px rgba(255, 215, 5, 0.1)` |
