# dev-comp 开发 checklist

> 阶段 1/2/4/5 按需加载。覆盖组件开发全链路的检查项。

---

## 分支（阶段 1）

- [ ] 确认当前分支名：`git branch --show-current`
- [ ] 全新组件 → 从主干新建 `feat/{组件名}`，已有雏形 → 在既有分支续做
- [ ] 分支名遵循 `feat/` 或 `fix/` 前缀

## 注册同步（阶段 1）

- [ ] `components/{组件名}/index.ts`：`import { withInstall }` → `export default withInstall(Xxx)` + 类型导出
- [ ] `components/components.ts`：追加 `export type { Props as XxxProps }` + `export { default as Xxx }`
- [ ] 多子组件：外层 `index.ts` 聚合 `export { Menu, MenuItem }` + 导出所有子类型
- [ ] 确认无需手动修改 `components/index.ts`（自动 install 循环）和 `src/router/index.ts`（glob 自动扫描）
- [ ] withInstall 时的 `utils/type` import 路径层级：单层 `../utils/type`，双层 `../../utils/type`

## 主题样式（阶段 2）

- [ ] light 主题样式完整
- [ ] dark 主题样式完整（通过 `useInject` 或 CSS 变量适配）
- [ ] 颜色/间距使用项目 CSS 变量，不硬编码
- [ ] CSS scoped，缩进 2 空格，嵌套 ≤3 层

## SSR 安全（阶段 2）

- [ ] 组件内无裸用 `window` / `document` / `localStorage`
- [ ] 浏览器 API 放在 `onMounted` 内或加 `typeof window !== 'undefined'` 判断

## 对齐检查（阶段 2）

- [ ] antdv 全部 demo（`{REF_ANTDV_LOCAL}/components/{组件名}/demo/*.vue`）已逐一读取
- [ ] Demo 用例对齐清单已完成：官网全部展示用例逐一列出，无遗漏（完整复制要求见 §演示用例）
- [ ] API **四维**对比清单已完成（Props / Events（事件名+回调参数）/ Slots（插槽名+参数）/ Expose（暴露方法+签名）逐项对比类型/默认值/必填），并已写入工作上下文
- [ ] 默认值与 antdv 一致（逐字段核对，如 `mode`/`size`/`type` 等所有带默认值的 prop）
- [ ] **组件主体完成后，已对照 antdv 官网 API 属性列表（官网组件文档页 API 表格）逐项确认覆盖**，无遗漏
- [ ] 接口字段名与 antdv 一致（逐字段核对 ItemType/Options 等嵌套接口，差异项按 antdv 命名）
- [ ] 关键行为对齐（按组件特性逐项列出：展开收起行为/高亮逻辑/延迟参数等）
- [ ] naive 差异已登记（naive 有而 antdv 无的特性）并逐项给出决策（对齐 / 不覆盖（理由）/ 待用户确认）
- [ ] 实现方式已按复用优先级检索（项目已有组件/功能/样式/布局/逻辑 > antdv 源码 > naive 源码 > 自研），未重复开发

## 演示用例（阶段 3）

- [ ] `src/views/{组件名}/Index.vue` + `index.ts`（`export default { title: '中文名' }`）
- [ ] antdv 官网全部展示用例已完整复制（每个官网用例对应一个分区，只保留标题 + 必要描述）
- [ ] **用例顺序与官网展示用例顺序一致**（1、2、3… 按官网原序编号）
- [ ] 每个分区含两个组件对照：①本项目组件（左/上）②antd 官网组件（右/下，原样复制官网代码与数据）
- [ ] 两组件行为/视觉 1:1 一致
- [ ] 额外覆盖：禁用态、空数据、极值、主题切换（官网没有的项目特有场景）

## 周边文档（阶段 4）

- [ ] `docs/guide/components/{组件名}.md`（复用演示页 script+template，加 API 表格）
- [ ] docs 已剔除「antd 官网组件」分区与 `ant-design-vue` 真身 import（对照只在演示页）
- [ ] vitepress 侧边栏配置 `docs/.vitepress/config.ts` 新增组件入口
- [ ] `docs/guide/changelog.md` 新增变更记录
- [ ] `README.md` + `README.zh-CN.md` 组件清单更新（中英双份）
- [ ] `docs/index.md`（若有组件清单）

## 验收（阶段 5）

- [ ] `pnpm lint:check` EXIT 0
- [ ] `pnpm type-check` 无本组件错误
- [ ] **浏览器实测**：`pnpm dev` 与真身 1:1 对照，覆盖多实例/边界/交互/主题切换
- [ ] 控制台 0 error / 0 warning
- [ ] 调试代码已清理（console.log、临时样式）
- [ ] 后台端口已关闭
- [ ] **基线全量勾销**：Gate 5 报告已全量回显「对齐清单」（API 四维 + Demo 用例）+「naive 差异登记」+「项目特有需求」，逐行 ✅/❌，❌ 项均带处置码（`延后 P{n}` / `不覆盖（理由）` / `待用户确认`）
- [ ] 「待用户确认」缺失项已在 Gate 5 汇总呈现，用户已逐项决策

## 交互操作清单（阶段 5，每个用例的可枚举操作点逐项勾销）

- [ ] 点击 / 悬停 / 聚焦
- [ ] 展开 / 收起 / 切换
- [ ] 受控更新（v-model / 受控 props 变化）
- [ ] 键盘操作（Tab/Enter/方向键，组件支持时）
- [ ] 边界输入（空数据 / 极值 / 超长内容 / 禁用态）
- [ ] 多实例共存互不干扰
- [ ] e2e（可选）：`e2e-testing` skill 可用时跑关键交互用例；缺失则手动勾销并提示用户可安装
