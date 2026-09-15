<script setup lang="ts">
// dev-comp template: 组件本体骨架
// ⚠️ 骨架 ≠ 规范。动笔前必读项目规范权威源：
//    development/component-design.md（SFC 结构 / Props / 插槽类型 / 主题注入 / 样式）
//    并 read_file 2-3 个同类已有组件（如 components/statistic/Statistic.vue、components/divider/Divider.vue），
//    项目既有惯例 > 本骨架。
// ⚠️ 项目统一约定（骨架已按此写，勿改回）：
//    · Props 与 Slots 类型在 SFC 内 `export interface`（入口 index.ts 用 `Props as XxxProps` 转出）
//    · 插槽类型命名固定 <组件名>Slots，配合 defineSlots 使用
//    · 根类名 = `{组件名}-wrap`（BEM 前缀，参照 statistic-wrap / divider-wrap / comment-wrap）
//      ❌ 禁止 m- / vui- 等自拟前缀（全库无此惯例）
import { computed } from 'vue'
import type { VNode } from 'vue'
// 有「插槽存在性判断」需求时引入；只传实际使用的插槽名，禁止多传冗余项
import { useSlotsExist } from 'components/utils'

/* eslint-disable @typescript-eslint/no-empty-object-type */
export interface Props {
  // 在此定义 props（字段名/类型/默认值/必填逐项对齐参考库；每个字段必须带中文注释）
}
// 声明组件插槽类型（命名固定 <组件名>Slots；仅在 SFC 内 export，不经入口 / components.ts 对外导出）
export interface XxxSlots {
  default?: () => VNode[]
}

const props = withDefaults(defineProps<Props>(), {
  // 默认值（与参考库逐字段核对，禁止遗漏带默认值的字段）
})
defineSlots<XxxSlots>()

const emit = defineEmits<{
  // 在此定义事件（事件名 + 回调参数结构与参考库对齐；无事件则整段删除）
}>()
/* eslint-enable @typescript-eslint/no-empty-object-type */

const slotsExist = useSlotsExist(['default'])
const showDefault = computed(() => slotsExist.default)

// 主题色（组件含主题色时启用）：单层组件 `../utils`，双层子组件 `../../utils`
// const { colorPalettes, shadowColor } = useInject('Xxx')

// 暴露给父组件的方法/状态（有则定义，如 focus / select；无则删除）
// defineExpose({})

// 组件逻辑
</script>

<template>
  <div class="xxx-wrap">
    <slot></slot>
  </div>
</template>

<style lang="less" scoped>
// 根类名 = `{组件名}-wrap`；内部类名统一 `{组件名}-xxx` 前缀
.xxx-wrap {
  // light 主题：主题相关颜色必须用 CSS 变量（colorPalettes 经模板内联 style 注入，见 component-design.md），
  // 中性灰阶可用 rgba 字面量（项目惯例）；scoped、缩进 2 空格、嵌套 ≤3 层
}
</style>
