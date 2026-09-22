# dev-comp 开发 checklist

> 阶段 1/2/4/5 按需加载。覆盖组件开发全链路的检查项。
> ⚠️ 项目内已有权威规范 `development/*.md`（见 `project-map.md` §项目规范权威源索引），本清单与之冲突时**以项目规范为准**并立即回填本文件。
> 2026-09-15（Comment 事故）扩充：新增 **F 类（组件本体与跨文件规范）**、修正 B5、补演示页/文档写法条目。
> 2026-09-22（多次实践复盘）扩充：新增 **G 类（交付前精修与三方一致性）** + **C5（品牌信息残留）**，权威源 `references/refine-spec.md`；对应脚本 `C5` / `G2` / `G4`。

---

## 分支（阶段 1）

- [ ] 确认当前分支名：`git branch --show-current`
- [ ] 全新组件 → 从主干新建 `feat/{组件名}`，已有雏形 → 在既有分支续做
- [ ] 分支名遵循 `feat/` 或 `fix/` 前缀

## 注册同步（阶段 1）

- [ ] `components/{组件名}/index.ts`：`import { withInstall }` → `export default withInstall(Xxx)` + 类型导出
- [ ] `components/components.ts`：追加 `export type { XxxProps }` + `export { default as Xxx }`
- [ ] 多子组件：外层 `index.ts` 聚合 `export { Menu, MenuItem }` + 导出所有子类型
- [ ] 确认无需手动修改 `components/index.ts`（自动 install 循环）和 `src/router/index.ts`（glob 自动扫描）
- [ ] withInstall 时的 `utils/type` import 路径层级：单层 `../utils/type`，双层 `../../utils/type`
- [ ] **⭐ `components/utils/style-deps.ts` `componentsMap`**（2026-09-22 修正：四张表已从 `resolver.ts` 收敛到此单一数据源，`resolver.ts` 只读不再定义表）：组件名 → 样式目录映射（按字母序插入，value 用 `ls` 实测目录名，详见 `linkage-map.md` §④）
- [ ] **⭐ `components/utils/style-deps.ts` `componentDependencies`**：列出组件 `.vue` 内 `import ... from 'components/xxx'` 的实际组件依赖（**复合组件逐子组件各自登记**，无依赖则跳过）；必要时同步 `styleSources`（自身无样式文件时指向来源组件）——详见 `linkage-map.md` §④，权威校验 `pnpm verify:deps`
- [ ] **⭐ `types/global-components.d.ts` 登记全局组件声明**：按字母序插入 `Xxx: typeof VueAmazingUI.Xxx`，覆盖 `componentsMap` 全量（含复合子组件 / Provider）——见 F5 与 `linkage-map.md` §⑮

## 组件规范（阶段 1/2 · F 类）

> 权威源：`development/component-design.md`（SFC 结构 / Props / 插槽类型 / 主题 / 样式）。

- [ ] **F1 插槽类型**：SFC 内 `export interface {组件名}Slots` + `defineSlots<{组件名}Slots>()`（❌ 不用内联对象类型；插槽类型不经入口对外导出）
- [ ] **F2 根类名 = `{组件名}-wrap`**，内部类名统一 `{组件名}-xxx` 前缀（❌ 禁止 `m-` / `vui-` 等自拟前缀，全库无此惯例）
- [ ] **F3 Props/Slots 注释**：每字段带中文注释；❌ 注释内不写 `string | slot` / `Array | slot`（插槽形态统一由 `{组件名}Slots` 类型 + 文档 Slots 表表达）
- [ ] **F4 `useSlotsExist` 只传实际使用的插槽名**（半确定性：脚本仅提示，须人工确认无冗余探测项）
- [ ] Props：`withDefaults(defineProps<Props>())` + `export interface Props`（重命名在组件级 index.ts 完成，入口透传 `XxxProps`）；❌ 不用内联 `defineProps<{...}>()`
- [ ] **Props 定义时就按六段式排序**（双向绑定 → 内容数据 → 形态外观 → 状态反馈 → 行为交互 → 进阶透传；段内语义相邻，**不强制字母序**）——阶段 2 就按序写，避免收尾返工；权威源 `refine-spec.md` §3，收尾由 G2 校验
- [ ] 事件用 `defineEmits`；暴露方法用 `defineExpose`（有则定义）
- [ ] **实现分支对齐（阶段 2）**：对照参考库源码的**渲染分支/兜底逻辑**逐条核对（非仅 API 四维），差异显式决策；详见 `reference-sources.md` §渲染分支与兜底逻辑对齐
- [ ] **单测**：组件含分支/合并/边界逻辑（prop×slot 双源、多形态 prop、空值/空数组）时补 `tests/{组件名}.spec.ts`（Vitest + @vue/test-utils，中文 describe/it）
- [ ] 类型安全：禁 `any`（用 `unknown` + 守卫）；链式访问一律 `?.`；`===`；`const` 优先

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
- [ ] API **四维**对比清单已完成（Props / Events（事件名+回调参数）/ Slots（插槽名+参数）/ Expose（暴露方法+签名，⚠️ 内部术语，文档标题为 `## Methods`）逐项对比类型/默认值/必填），并已写入工作上下文
- [ ] **源码实现分支清单已完成**：参考库渲染函数/模板的每个分支（字符串 vs VNode、有无默认值、空值兜底、优先级 prop vs slot）已逐条核对并决策（见 `reference-sources.md` §渲染分支与兜底逻辑对齐）
- [ ] 默认值与 antdv 一致（逐字段核对，如 `mode`/`size`/`type` 等所有带默认值的 prop）
- [ ] **组件主体完成后，已对照 antdv 官网 API 属性列表（官网组件文档页 API 表格）逐项确认覆盖**，无遗漏
- [ ] 接口字段名与 antdv 一致（逐字段核对 ItemType/Options 等嵌套接口，差异项按 antdv 命名）
- [ ] 关键行为对齐（按组件特性逐项列出：展开收起行为/高亮逻辑/延迟参数等）
- [ ] naive 差异已登记（naive 有而 antdv 无的特性）并逐项给出决策（对齐 / 不覆盖（理由）/ 待用户确认）
- [ ] 实现方式已按复用优先级检索（项目已有组件/功能/样式/布局/逻辑 > antdv 源码 > naive 源码 > 自研），未重复开发

## 演示用例（阶段 3）

- [ ] **格式参考先行**：动笔前已 `read_file` 2-3 个同类已有组件演示页，提取项目既有惯例（标题层级/间距 class/分区结构/描述风格/数据组织）+ 读 `development/demo-doc-guide.md`，**项目惯例 > 模板骨架**（详见 `flow.md` 阶段 3 第 0 步）
- [ ] `src/views/{组件名}/Index.vue` + `index.ts`（`export default { title: '中文名' }`）
- [ ] **F7 注释与标题不带数字序号**：script 注释写 `// 基本评论`（❌ 不写 `// 1. 基本评论`）；`<h2 class="mt30 mb10">` 标题同样不带序号（「与官网用例顺序一致」指**分区排列顺序**，不指标题编号）。实测：`src/views/` 全量无序号写法
- [ ] **F8 演示页禁止 import 本项目组件**：组件由 `main.ts` 的 `app.use(VueAmazingUI)` 全局注册，直接写 `<Xxx>` 标签；❌ 不写 `import { Xxx } from 'vue-amazing-ui'`。（确需 VNode/编程式引用时改用 `#插槽`、`<component :is="'Xxx'">`，或保留 `h()` + 具名插槽方案，不引入组件库 import）
- [ ] 仅保留必要 import：`vue` 的 API（`ref`/`h`/`computed` 等）、`@ant-design/icons-vue` 图标、`ant-design-vue` 真身（对照期，阶段 5 清除）
- [ ] antdv 官网全部展示用例已完整复制（每个官网用例对应一个分区，只保留标题 + 必要描述）
- [ ] **用例顺序与官网展示用例顺序一致**（1、2、3… 按官网原序**排列**，标题不写序号）
- [ ] **新增用例插回官网原序位置**（❌ 不 append 末尾）；项目特有用例统一归末尾「项目特有场景」区块；**同类型用例布局一致**（单例整块 / 多例并排 / 交互类全宽）——权威源 `refine-spec.md` §4，收尾由 G3/G4 校验
- [ ] 每个分区含两个组件对照：①本项目组件（左/上）②antd 官网组件（右/下，原样复制官网代码与数据）
- [ ] antd 真身引入方式已确认（已配 `AntDesignVueResolver` → 直接用 `<a-xxx>` 标签免 import；未配 → 显式 `import ... from 'ant-design-vue'`，详见 `flow.md` 阶段 3）
- [ ] 两组件行为/视觉 1:1 一致
- [ ] **简介描述遵循 `references/demo-description.md`**：权威源=演示页、标题纯场景名、仅信息增量时添加、代码标记原生 `<code>`（引用组件前 `search_file` 确认存在）、docs 要 `<br/>` 而演示页 `<p>` 自带间距无需 `<br/>`、段落数两处一致
- [ ] **改动即同步（禁止单边）**：改演示页描述后立即 `grep` 同步 docs 对应描述（文本逐字一致，仅 `<code>` ↔ 反引号转换）
- [ ] 额外覆盖：禁用态、空数据、极值、主题切换（官网没有的项目特有场景）

## 周边文档（阶段 4）

- [ ] `docs/guide/components/{组件名}.md`（复用演示页 script+template，加 API 表格）；结构参照 `development/demo-doc-guide.md` + `docs/guide/template.md`
- [ ] **B5 API 章节标题按组件实际能力**：`## APIs` **必须**有；`## Events` / `## Methods` **仅当组件有 emit / `defineExpose` 时才要求**（❌ 无事件却凭空补 `## Events`）；命名统一 `## Methods`（对外暴露方法），❌ 禁止 `## Expose` 等内部术语作标题
- [ ] **B6 `## APIs` 下必须有 `### {组件名}` 子标题**（实测：项目所有单组件文档均有；多组件文档用 `### Xxx Slots` 等分节）
- [ ] **B7 API 表类型列写法**：prop 类型写真实 TS 类型（`string` / `Array<string | VNode>` / `VNode | (() => VNode)`）；❌ 禁止 `string | slot` / `Array | slot`（2026-09-15 实测全仓仅 Comment 残留，已清理）；VNode 类 prop 说明写法参照 `avatar.md`：`prop 支持 \`VNode\` / 渲染函数；插槽形态请用同名 \`#xxx\` 插槽`
- [ ] docs 已剔除「antd 官网组件」分区与 `ant-design-vue` 真身 import（对照只在演示页）
- [ ] **docs 用例顺序在迁移时即与演示页保持一致**（`## 用例标题` 序列 = 演示页 `<h2>` 序列，含项目特有用例归末尾区块）——这是 G4 的前置保障，避免收尾返工；另：docs 用例标题/描述**不得残留品牌字样**（C5）
- [ ] vitepress 侧边栏配置 `docs/.vitepress/config.ts` 新增组件入口（按字母序插入）
- [ ] `docs/guide/changelog.md` 新增变更记录（**按 `references/changelog-spec.md`**：新增组件 → minor+1 patch 归 0；非新增 → patch+1；`package.json` version 与 changelog 双处一致；条目格式 + 插顶部；**链接用站内相对路径 + kebab 目录名**）
- [ ] **F6 changelog 三查**：① 版本章节唯一（❌ 不重复，如出现两个 `2.6.0`）；② 严格递减无错序；③ `## future` 清单删除已落地组件行（详见 `changelog-spec.md` §3.4）
- [ ] `README.md` + `README.zh-CN.md` 组件清单更新（中英双份，按字母序）
- [ ] `docs/index.md`（若有组件清单）
- [ ] **⭐ 组件总数数字 +1（4 处）**：`docs/guide/features.md` §简要介绍 / `docs/index.md` hero `details` / `README.zh-CN.md` §特性 / `README.md` §Features，逐一 +1（详见 `linkage-map.md` §⑩⑪⑫，含 grep 自检命令）

## 发布前配置项终检（阶段 5 · 配置项类检查唯一权威源）

> 新增组件的全部固定配置项集中于此，阶段 5 验收时**逐项勾销 + grep 自检实测**，禁止靠记忆。
> ⚠️ **埋入阶段检查不能替代终检**：阶段 1/4 埋入时检查过 ≠ 发布前仍正确（埋入后文件可能再被改动），收尾必须全量回检。
> 详细判定规则 → `linkage-map.md` 对应小节；类别 D「质量验证」（lint/type-check/浏览器实测）并入下方 §验收。
>
> **🔧 确定性检查的权威执行体 = `scripts/validate-component.sh`**（设计哲学「确定性用代码」落地）：Gate 5 前置跑 `bash scripts/validate-component.sh {组件名} {PROJECT_ROOT} --context {工作上下文文件}`（**分批提交 / 长生命周期分支加 `--base <ref>`**，确保 C5 回溯已提交批次），一次性获取 A/B/C/E/F/G + S 全部勾销证据（输出 `[PASS/FAIL/WARN/SKIP]`），**禁止逐条手敲 grep**。本节 ID（A1-A5/B1-B7/C1-C5/E1-E2/F1-F8/G1-G6）与下方 §验收 的提交红线（S1 git 身份 / S2 分支核对 / S3 commit hash 回填真实性 / S4 沉淀三件套 / S5 归档双份）均与脚本输出一一对应；本节定义规则语义（人类阅读），脚本是执行真相，**规则变更必须同步改脚本**，禁止只改文档（详见 `rules/按需-Skill设计-跨文件协作.mdc` §2.1 双向引用）。FAIL 阻断收尾，WARN/SKIP 须人工确认并回显 Gate 5 报告。脚本对 components/views/docs 三处目录按归一化名解析真实路径（项目命名约定不统一，禁止猜测路径）。

### A · 代码注册链路（埋入于阶段 1）

- [ ] A1 `components/{组件名}/index.ts`：`withInstall` + 类型导出。⚠️ **复合组件**：聚合层 index.ts 只做 `import/export 子组件`，**withInstall 在子组件层** index.ts（如 `dropdown/dropdown/index.ts`）——脚本已按此适配（2026-09-22 自查修正假 FAIL）
- [ ] A2 `components/components.ts`：`export type { XxxProps }`（汇总级透传）+ 组件导出两条都在；组件导出**两种形态均可**——单组件 `export { default as Xxx }`、复合组件 `export { Xxx, XxxButton }`（脚本已适配，避免误命中 `XxxProps`/`XxxKey` 等类型导出）
- [ ] A3 ⭐ **`components/utils/style-deps.ts`** `componentsMap` 按需样式映射（`grep -n "{组件名}:" components/utils/style-deps.ts` 命中且按字母序，value 为实测目录名，详见 `linkage-map.md` §④）。⚠️ 2026-09-22 修正：表源已从 `resolver.ts` 迁到 `style-deps.ts`（D 方案）；脚本按结构自动选源（`style-deps.ts` 优先，缺失回退 `resolver.ts`）
- [ ] A4 ⭐ **`components/utils/style-deps.ts`** `componentDependencies` 样式依赖（`grep -rn "import .* from 'components/" components/{组件名}/` 逐一与映射条目对上；**复合组件逐子组件各自核对**，无依赖则确认跳过，详见 `linkage-map.md` §④）；权威校验另跑 `pnpm verify:deps`（项目自带双向比对）
- [ ] A5 自动注册确认：`git diff` 中无 `components/index.ts` / `src/router/index.ts` 手改痕迹（glob 自动扫描，无需手改）

### B · 文档联动链路（埋入于阶段 4）

- [ ] B1 `docs/guide/components/{组件名}.md` 存在且复用演示页（script+template 同源）
- [ ] B2 vitepress 侧边栏入口（`grep -n "{组件名}" docs/.vitepress/config.ts` 命中）
- [ ] B3 `docs/guide/changelog.md` 变更记录（`grep -n "{组件名}" docs/guide/changelog.md` 命中）+ **版本号规则校验**（`references/changelog-spec.md` §4：新增组件 → minor+1 patch 归 0；`package.json` version 与 changelog 顶部版本号逐字一致）
- [ ] B4 ⭐ 组件总数 +1（4 处）：`docs/guide/features.md` §简要介绍 / `docs/index.md` hero `details` / `README.zh-CN.md` §特性 / `README.md` §Features 逐一 +1（详见 `linkage-map.md` §⑩⑪⑫）
- [ ] B5 API 章节标题按实际能力：`## APIs` 必有；`## Events` / `## Methods` 有 emit / expose 才要求；无 `## Expose`
- [ ] B6 `## APIs` 下有 `### {组件名}` 子标题
- [ ] B7 API 表类型列无 `string | slot` / `Array | slot`（VNode 类 prop 说明参照 `avatar.md`）

### C · 残留清理（阶段 5 执行）

- [ ] C1 ⭐ `components.d.ts` 幽灵声明清理：`grep -rEn "<a-xxx|AButton|AAutoComplete" src/ components/ docs/` 0 匹配的 antdv 声明已删除，**删除随本次 commit 一起提交**（详见 `linkage-map.md` §⑭；⚠️ 不依赖 unplugin 自动清理）
- [ ] C2 ⭐ `src/App.vue` 孤儿变量清理（仅本次动了全局 ConfigProvider/主题时）：grep 确认无「定义未使用」的残留变量（详见 `linkage-map.md` §⑬）
- [ ] C3 演示页对照清除：`git diff src/views/{组件名}/Index.vue` 仅剩本库用例（antdv 真身/对应数据/`ant-design-vue` import/antdv 专属图标已删）
- [ ] **C5 ⭐ 品牌信息 0 残留（2026-09-22 新增 · 同日扩充分批提交口径）**：**两段扫描口径**（①本分支**净改动**新增行 `git diff <base>`（基点 → **当前工作区**，一次覆盖「已提交的每一批 + 未提交改动」）②未跟踪新增文件全文）中无 `antdv` / `antd` / `ant-design-vue` / `Ant Design Vue` / `naive` / `naive-ui` / `<a-xxx>` / `avalue*`·`aoptions*` / `antdTheme` 等品牌字样。⚠️ **分批开发/分批提交时必须回溯已提交批次**（只查工作区会漏），base 取 `--base` / 工作上下文 `base_ref` / `merge-base 主干`；净改动为 0 但「已提交批次」仍有残留时脚本给 WARN——**删除必须随本次 commit 提交，否则复活**。**范围含 docs 全部内容**（组件文档 + changelog/features/index 周边文档）+ 组件源码 / 演示页 / 单测 / 根级 README。**处置**：品牌对比/差异说明类内容（如「与 Ant Design Vue 的差异」段落、changelog 的「对齐 XX」说明）**整段直接删除、不保留**；注释来源标注删除或去品牌化（`refine-spec.md` §1.4）。**例外**：`@ant-design/*` 基础包（图标/色板，已确认豁免）。详见 `refine-spec.md` §1，脚本 C5 拦截
- [ ] C4 调试代码清理（console.log、临时样式）

### E · 一致性校验（阶段 5 执行）

- [ ] E1 组件总数 4 处数字一致：`grep -rEn "共包含|includes.*components|个基础" README.md README.zh-CN.md docs/index.md docs/guide/features.md`，4 处数字一致且 = 实际组件数（`ls -d components/*/ | grep -v -E 'components/(style|utils|discrete)/' | wc -l`）
- [ ] E2 演示页 ↔ docs 简介描述同源：按 `references/demo-description.md` §5 用 grep 双向对比——文本逐字一致、段落数一致、`.vue` 用 `<code>` 而 `.md` 用反引号、`.md` 有 `<br/>` 而 `.vue` 无

### F · 组件本体与跨文件规范（阶段 1/2 埋入 · 阶段 5 全量回检）⭐ 2026-09-15 新增

> 事故背景：Comment 开发漏了 `types/global-components.d.ts` 登记（静默失效、type-check 仍 PASS），并暴露 `defineSlots` 缺失、根类名 `m-` 前缀、Props 注释 `string | slot` 残留、演示页序号注释与组件库 import 等无检查项覆盖的问题。
> 本类全部进 `scripts/validate-component.sh`（F1-F8），Gate 5 必跑。

- [ ] **F1** `defineSlots` + `export interface {组件名}Slots` 存在于**每个使用插槽的**组件 SFC（`grep -n "defineSlots" components/{组件名}/**/*.vue`）。⚠️ 2026-09-22 修正：① **无插槽组件豁免**（无 `<slot` / `useSlotsExist` / `$slots` 的内部渲染内核组件，如 `loading-bar/LoadingBar.vue`，原判定假 FAIL）；② 复合组件**逐 .vue 校验**
- [ ] **F2** 根类名 = `{组件名}-wrap`，无 `m-` / `vui-` 自拟前缀（`grep -nE 'class="[a-z]+-{组件名}|class="m-|class="vui-' components/{组件名}/*.vue` 应为 0 命中）
- [ ] **F3** Props/Slots 注释无 `string | slot` / `Array | slot` 残留（`grep -nE "//.*(string|Array) \| slot" components/{组件名}/*.vue`）
- [ ] **F4** `useSlotsExist([...])` 数组内每个插槽名都有实际消费点（半确定性 → 脚本提示 + 人工确认，禁止冗余探测）
- [ ] **F5** ⭐ `types/global-components.d.ts` 已登记（差集校验：`style-deps.ts` 的 `componentsMap` keys − 该文件声明 = 空）。⚠️ 2026-09-22 修正：表源改为 `style-deps.ts`；**表源解析为空时脚本不得判 PASS**（假绿灯守护），改 WARN 提示人工核对
- [ ] **F6** ⭐ changelog 三查：版本章节唯一（无重复版本号）/ 严格递减 / 组件链接为站内相对路径 + kebab 目录名 / `## future` 无已落地组件残留
- [ ] **F7** 演示页与文档 script 注释、`<h2>` 标题无数字序号（`grep -nE "^// [0-9]\.|<h2[^>]*>[0-9]+\." src/views/{组件名}/ docs/guide/components/{组件名}.md`）
- [ ] **F8** 演示页无本项目**组件值** import（默认导入整库、或具名导入中出现 PascalCase 组件名 → 违规）。⚠️ 2026-09-22 修正：**命令式 API / hook 允许 import**（`useLoadingBar` / `useMessage` / `createDiscreteApi`，规范依据 `development/demo-doc-guide.md`）；`import type` 允许

### G · 交付前精修与三方一致性（阶段 5 第 5 步 · ⭐ 2026-09-22 新增）

> 复盘背景（多次实践）三类收尾欠账：①品牌痕迹随注释/文案沉淀（对照清了、注释没清）；②增量开发导致注释臃肿、Props 追到末尾乱序、演示用例乱序/布局不统一；③docs 与 views 用例集合/顺序漂移。
> **权威源**：`references/refine-spec.md`（判定标准与改写范式）；描述类同源规则另见 `demo-description.md`。
> **确定性下沉**：G2（Props 顺序）/ G4（用例对齐）由脚本实测；G1/G3/G5/G6 为模糊项，按 `refine-spec.md` 人工勾销（脚本 SKIP 提示）。

- [ ] **G1 组件源码注释精修**（`refine-spec.md` §2）：组件级 ≤3 行、字段级每字段带中文语义注释、分支级写「为什么」；删复述代码 / 过期注释 / 品牌来源标注；无「行行注释」或「复杂分支零注释」
- [ ] **G2 Props 排序**（`refine-spec.md` §3）：按六段式分组（双向绑定 → 内容数据 → 形态外观 → 状态反馈 → 行为交互 → 进阶透传）+ 段内语义相邻（**不强制字母序**，与项目既有惯例一致）；增量属性**插入所属段**（❌ 不追末尾）；**源码 `interface Props` 顺序 ≡ docs `## APIs` → `### {组件名}` 表行顺序**（脚本 G2 校验，不一致 FAIL——脚本保「一致」、人工保「合理」）；**复合组件按子组件逐一比对**（`Dropdown.vue ↔ ### Dropdown`、`DropdownButton.vue ↔ ### DropdownButton`，脚本已支持含一层子目录）；Slots/Events/Methods 表顺序同步
- [ ] **G3 演示用例排序与布局精修**（`refine-spec.md` §4）：官网用例保序、**新增用例插回官网原序位置**、项目特有用例归末尾区块；单例整块 / 多例并排 / 交互类全宽，**同类型布局一致**；分区结构统一（`<h2>` → 可选 `<p>` → 示例容器）
- [ ] **G4 docs ↔ views 用例对齐**（`refine-spec.md` §5.1）：用例**数量一致**、**顺序一致**、**标题逐字一致**（脚本 G4 校验）；描述文本同源（斜体 + `<br/>` vs `<p class="mb10">`）、示例代码同源（docs 仅剔对照分区）、布局同源
- [ ] **G5 三方一致性对照矩阵逐格勾销**（`refine-spec.md` §5.1）：源码 ↔ docs ↔ views 全维度（用例 / Props 名称类型默认值 / Props 顺序 / 字段注释 / Events / Slots / Methods / 品牌）；差异**先改权威源再同步副本**，❌ 项带处置码
- [ ] **G6 精修记录 + 精修复验**（`refine-spec.md` §6）：5 项记录（品牌清除 / 注释 / Props 排序 / 用例排序布局 / 三方一致性）已写入工作上下文「交付前精修记录」区；精修后已重跑 `lint:check` + `type-check` + `test` + 浏览器实测（对照已删，确认无孤儿引用），结果补进 Gate 5 报告

## 验收（阶段 5）

> 配置项类检查（注册/文档/残留/一致性/组件规范）已独立为上方「发布前配置项终检」章节，本节只保留质量验证与基线勾销。

- [ ] `pnpm lint:check` EXIT 0
- [ ] `pnpm type-check` 无本组件错误（⚠️ 通过不代表 `types/global-components.d.ts` 已登记 —— 该遗漏不报错，见 F5）
- [ ] `pnpm test` 全量通过（新增/修改组件时）
- [ ] `pnpm docs:build` 通过（阶段 4 改了文档 demo/内联 script 时，验证文档站可编译）
- [ ] `pnpm prettier --check src/ components/`（或 `pnpm format:check`）通过
- [ ] **浏览器实测**：`pnpm dev` 与真身 1:1 对照，覆盖多实例/边界/交互/主题切换
- [ ] 控制台 0 error / 0 warning
- [ ] 后台端口已关闭
- [ ] **基线全量勾销**：Gate 5 报告已全量回显「对齐清单」（API 四维 + 源码实现分支 + Demo 用例）+「naive 差异登记」+「项目特有需求」，逐行 ✅/❌，❌ 项均带处置码（`延后 P{n}` / `不覆盖（理由）` / `待用户确认`）
- [ ] 「待用户确认」缺失项已在 Gate 5 汇总呈现，用户已逐项决策
- [ ] **交付前精修全量勾销（G1-G6 + C5）**：品牌 0 残留、注释精修、Props 六段式排序（与 docs 表逐项同序）、用例排序与布局、docs↔views 对齐、三方矩阵逐格勾销；精修后已复验（`lint:check` + `type-check` + 浏览器实测）——权威源 `refine-spec.md`，Gate 5 报告「交付前精修」区块回显
- [ ] **能力沉淀三件套必做**：devlog（tech-doc）+ metrics（lite YAML）+ knowledge（knowledge-loop）已全部生成并在 Gate 5 报告勾销；降级跳过须登记 ❌ + 原因 + 用户确认（详见 `flow.md` 阶段 5 第 3 步）
- [ ] **提交前 git 身份实测**：`git config user.name/email` 实测值与工作上下文 `git_identity` 一致，不符已拦截并经用户决策（详见 `flow.md` 阶段 5 第 4 步）
- [ ] **提交后 hash 实测回填**：`git log -1 --format='%h'` 实测值已回填工作上下文 frontmatter `commit`，禁止凭记忆记录
- [ ] **产物位置已告知**：Gate 5 报告的「能力沉淀三件套与产物位置」表已列出四项路径（working-context / metrics / devlog / knowledge）；产物一律留在 `~/.codebuddy/` 运行时目录，**不弹归档决策**（详见 `flow.md` 阶段 5 第 9 步）

## 交互操作清单（阶段 5，每个用例的可枚举操作点逐项勾销）

- [ ] 点击 / 悬停 / 聚焦
- [ ] 展开 / 收起 / 切换
- [ ] 受控更新（v-model / 受控 props 变化）
- [ ] 键盘操作（Tab/Enter/方向键，组件支持时）
- [ ] 边界输入（空数据 / 极值 / 超长内容 / 禁用态）
- [ ] 多实例共存互不干扰
- [ ] e2e（可选）：`e2e-testing` skill 可用时跑关键交互用例；缺失则手动勾销并提示用户可安装
