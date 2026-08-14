<script setup lang="ts">
// dev-comp template: 组件本体骨架
// 用 useInject 获取主题配置（单层组件路径 ../utils；双层子组件路径 ../../utils）
// import { useInject } from '../utils'

defineOptions({ name: 'Xxx' })

/* eslint-disable @typescript-eslint/no-empty-object-type */
const props = withDefaults(
  defineProps<{
    // 在此定义 props（参考 antdv/naive 对应组件的 API，字段名/默认值对齐）
  }>(),
  {}
)

const emit = defineEmits<{
  // 在此定义事件（事件名与回调参数结构与参考库对齐）
}>()

// 插槽（有则定义，如 default / icon）
defineSlots<{
  default?: () => unknown
}>()
/* eslint-enable @typescript-eslint/no-empty-object-type */

// 暴露给父组件的方法/状态（有则定义，如 focus / select）
// defineExpose({})

// 组件逻辑
</script>

<template>
  <div class="vui-xxx">
    <!-- 组件模板 -->
  </div>
</template>

<style lang="less" scoped>
.vui-xxx {
  // light 主题（颜色/间距优先使用项目主题变量，不硬编码）
}

// dark 主题（通过 useInject 主题配置或 CSS 变量适配）
</style>
