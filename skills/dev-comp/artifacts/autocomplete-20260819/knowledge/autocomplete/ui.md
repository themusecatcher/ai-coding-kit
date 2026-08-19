---
module: "autocomplete"
theme: "ui"
confidence: "pending"
created: "2026-08-18"
last_updated: "2026-08-18"
---

# AutoComplete UI 层

## 组件结构

```html
<div class="auto-complete-wrap">                     <!-- 根（含 status/size/disabled/focused/borderless 修饰类） -->
  <div class="auto-complete-content">                <!-- 内容框（边框/背景/尺寸样式载体） -->
    <slot name="default" />                          <!-- 自定义输入组件（default 插槽，替代原生 input） -->
    <input class="auto-complete-input" v-else />     <!-- 原生输入框（无 default 插槽时） -->
    <svg class="clear-svg">                          <!-- 清除图标（默认 Close 图标）或 -->
    <span class="clear-svg"><slot name="clearIcon"/></span>
  </div>
  <Teleport :to="to">
    <Transition name="zoom">
      <div class="auto-complete-panel">              <!-- 下拉面板（定位由 panelPlacement 计算） -->
        <div class="auto-complete-option-group">     <!-- 分组项 -->
          <p class="auto-complete-group-title" />    <!-- 分组标题（padding 5px 12px） -->
          <p class="auto-complete-option option-grouped" /> <!-- 组内选项（padding-left 24px 缩进） -->
        </div>
        <p class="auto-complete-option" />           <!-- 普通选项（padding 5px 12px） -->
      </div>
    </Transition>
  </Teleport>
</div>
```

## Props（21 项）

| Prop | 类型 | 默认 | 说明 |
|------|------|------|------|
| options | `(string\|number\|Option\|GroupOption)[]` | `[]` | 数据源 |
| value | `string` | `undefined` | 当前输入值（v-model） |
| placeholder | `string` | `undefined` | 占位文本 |
| disabled | `boolean` | `false` | 禁用 |
| size | `'small'\|'middle'\|'large'` | `'middle'` | 尺寸（本库扩展，antdv 无） |
| allowClear | `boolean` | `false` | 有值即显示清除图标 |
| autofocus | `boolean` | `false` | 自动聚焦 |
| backfill | `boolean` | `false` | 键盘导航回填 |
| bordered | `boolean` | `true` | 是否有边框 |
| defaultActiveFirstOption | `boolean` | `true` | 默认高亮首项 |
| defaultOpen | `boolean` | `false` | 默认展开 |
| open | `boolean` | `undefined` | 受控展开 |
| status | `'error'\|'warning'` | `undefined` | 校验状态 |
| dropdownMatchSelectWidth | `boolean\|number` | `true` | 面板宽度（true 同宽 / number 指定 px / false 自适应） |
| dropdownMenuStyle | `CSSProperties` | `undefined` | 面板样式 |
| popupClassName | `string` | `undefined` | 面板 className |
| to | `string\|HTMLElement\|false` | `'body'` | 面板挂载容器 |
| filterOption | `boolean\|Function` | `false` | 筛选（⚠️ antdv 默认 true） |

## 数据源类型

```typescript
export type Option = string | number | {
  value: string | number
  label?: string
  disabled?: boolean
  [key: string]: any
}
export type GroupOption = Option | {
  label?: string        // 分组名（显示为分组标题）
  value?: string | number
  options?: Option[]    // 子选项，存在该字段即视为分组
}
```

## 修饰类（根节点）

| 类 | 触发 |
|----|------|
| `auto-complete-focused` | 聚焦时 |
| `auto-complete-disabled` | disabled |
| `auto-complete-borderless` | `bordered: false` |
| `auto-complete-status-error` / `auto-complete-status-warning` | status |
| `auto-complete-size-small` / `auto-complete-size-large` | size |
