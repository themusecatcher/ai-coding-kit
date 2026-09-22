<script setup lang="ts">
// dev-comp template: 演示页骨架
// ⚠️ 骨架 ≠ 规范：动笔前 read_file 2-3 个同类已有组件演示页（如 src/views/popover/Index.vue），
//    并读 development/demo-doc-guide.md 与 references/demo-description.md，项目既有惯例 > 本骨架。
// 结构要求（阶段 3 核心）：
//   1. 完整复制 antdv 官网（https://www.antdv.com/components/{组件名}-cn/）全部展示用例，
//      只保留「用例标题 + 必要描述」；分区按官网原序【排列】——
//      ⚠️ 标题与 script 注释【不带数字序号】（写 `// 基础用法` / `<h2>基础用法</h2>`，
//      不写 `// 1. 基础用法` / `<h2>1. 基础用法</h2>`；实测项目演示页无序号写法，见 checklists F7 / 脚本 F7）
//   2. 每个分区两个组件对照：①本项目组件（左/上）②antd 官网组件（右/下），行为 1:1 一致
//   3. 项目特有场景（主题切换、边界态等官网没有的用例）单独追加分区
//   4. 简介描述规范：读 references/demo-description.md
//      - 权威源 = 演示页（本文件）；docs 是派生副本，任何改动先改这里再同步 docs
//      - 仅信息增量时添加；代码标记原生 <code>（引用组件前 search_file 确认存在）
//      - ⚠️ 演示页 <p> 自带间距，描述与组件之间【无需 <br/>】（<br/> 是 docs 才需要）
//   5. ⚠️ 品牌信息红线 + 交付前精修（阶段 5 第 5 步，权威源 references/refine-spec.md）：
//      本骨架注释里的 antdv/naive 仅用于指导对照，【落地后必须清干净】——
//      对照分区、真身组件/数据（avalue*/aoptions*）、ant-design-vue import、antdv 专属图标，
//      以及全部品牌字样（含注释与文案；「对齐 antd 口径」类来源标注改中性表述）都要删；
//      最终交付文件不得出现 antdv / antd / ant-design-vue / naive 等字样
//      （例外：@ant-design/icons-vue 图标依赖）；脚本 C5 拦截，收尾还需做用例排序/布局精修
import { ref } from 'vue'
// ⚠️ 本项目组件【无需 import】：由 main.ts 的 app.use(VueAmazingUI) 全局注册，模板直接写 <Xxx> 标签。
//    ❌ 禁止 `import { Xxx } from 'vue-amazing-ui'`（checklists F8 / 脚本 F8 会拦截）；
//    确需在 script 中拿到组件对象时，改用具名插槽或 `<component :is="'Xxx'">`，不引入组件库 import。
// 引入 antdv/naive 真身两种方式（按项目配置择一，详见 references/flow.md 阶段 3）：
//   方式 A（优先）：项目已配 unplugin-vue-components 的 AntDesignVueResolver 时，
//     template 直接用 <a-xxx> 全局标签（如 <a-auto-complete>），无需手动 import
//   方式 B：项目未配 resolver 时，显式 import 如下
// import { Xxx as AXxx } from 'ant-design-vue'         // antdv 真身（方式 B；项目 devDependencies 已有，用于对照）
// 或 naive 对照：import { NXxx } from 'naive-ui'

// ============ 演示数据（官网各用例数据原样复制于此，逐个分区声明） ============
// 基础用法数据
const items = ref([
  // { key: '1', label: 'xxx' }
])

// ============ 事件处理 ============
function handleClick(info: unknown) {
  // 处理逻辑（⚠️ 禁止残留 console.log —— checklists C4 / 脚本 C4 会拦截）
}
</script>

<template>
  <div class="demo-container">
    <!-- 用例：基础用法（官网用例名：xxx） -->
    <h2>基础用法</h2>
    <!-- 简介描述（可选）：仅信息增量时添加；代码标记原生 <code>；演示页 <p> 自带间距，【无需 <br/>】；
         class 落地到项目时替换为目标项目既有间距 class（vue-amazing-ui 为 mb10，.demo-desc 仅骨架占位） -->
    <p class="demo-desc">通过 <code>xxx</code> 控制 xxx（隐藏行为/区分点的必要说明）</p>
    <div class="demo-row">
      <div class="demo-col">
        <h3>本项目组件</h3>
        <!-- <Xxx :items="items" @click="handleClick" /> -->
      </div>
      <div class="demo-col">
        <h3>antd 官网组件</h3>
        <!-- 原样复制官网该用例代码与数据 -->
        <!-- 方式 A（优先，已配 resolver）：<a-xxx :items="items" @click="handleClick" /> -->
        <!-- 方式 B（显式 import）：<AXxx :items="items" @click="handleClick" /> -->
      </div>
    </div>

    <!-- 用例：禁用（官网用例名：xxx） -->
    <!-- 标题「禁用」已自解释，无需简介描述（反例：禁止给自解释标题加描述） -->
    <h2>禁用</h2>
    <div class="demo-row">
      <div class="demo-col">
        <h3>本项目组件</h3>
        <!-- 同场景本项目实现 -->
      </div>
      <div class="demo-col">
        <h3>antd 官网组件</h3>
        <!-- 官网禁用用例原样复制 -->
      </div>
    </div>

    <!-- 官网剩余用例按官网顺序逐一复制分区，一个不落（标题不带序号，顺序由排列体现） -->

    <!-- 项目特有场景（官网没有的用例，单独追加分区；也用于覆盖官方 demo 未触及的渲染分支） -->
    <h2>主题切换（项目特有）</h2>
    <div class="demo-row">
      <div class="demo-col">
        <h3>light</h3>
        <!-- <Xxx :items="items" /> -->
      </div>
      <div class="demo-col">
        <h3>dark</h3>
        <!-- <Xxx :items="items" /> -->
      </div>
    </div>
  </div>
</template>

<style lang="less" scoped>
// 演示页辅助样式（非组件样式，色值可按项目演示页风格调整）
.demo-container {
  padding: 16px;
}
h2 {
  margin: 24px 0 4px;
}
.demo-desc {
  margin: 0 0 12px;
  color: #999;
  font-size: 13px;
}
h3 {
  margin: 0 0 8px;
  color: #999;
  font-size: 13px;
  font-weight: normal;
}
.demo-row {
  display: flex;
  flex-wrap: wrap;
  gap: 24px;
}
.demo-col {
  flex: 1;
  min-width: 320px;
  padding: 16px;
  border: 1px dashed #d9d9d9;
  border-radius: 4px;
}
</style>
