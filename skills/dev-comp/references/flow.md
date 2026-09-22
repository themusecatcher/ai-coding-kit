# dev-comp 6 阶段执行规范

> 本文件是 dev-comp 各阶段的详细执行手册。SKILL.md 触发后按需加载本文件。
> 原则：轻量、领域聚焦、软复用能力。全程不进dev-flow 状态机。

---

## 阶段 0 · 接续 / 初始化

**目标**：判断是新组件还是接续已有组件，建立/恢复工作上下文，列出计划。

1. **目录自举 + 两级扫描已有工作上下文**（首次使用专属目录不存在，禁止假设已存在；扫描顺序固定：运行时目录优先 → artifacts 兜底）：
   - 先建目录：`mkdir -p ~/.codebuddy/dev-comp/working-context ~/.codebuddy/dev-comp/metrics`
   - **第一级（运行时目录，优先）**：`ls ~/.codebuddy/dev-comp/working-context/ | grep -i {组件名}`
   - **第二级（归档兜底）**：`ls {ARTIFACTS_FALLBACK_DIR}/{组件名}-*/working-context/ | grep -i {组件名}`（`ARTIFACTS_FALLBACK_DIR` 配置留空则跳过本级）
   - 第一级命中 → 读取该文件，恢复 phase/进度/决策，跳到「下一步动作」继续，**不新建**
   - 第一级未命中、第二级命中 → `cp` 复制回运行时目录后读取恢复，向用户一句话说明「已从 skill artifacts 归档副本恢复运行时状态」
   - 两级均未命中 → 用 `templates/working-context-lite.tpl.md` 新建到运行时目录（命名：`vaui-{组件名}-{YYYYMMDD}.md`）
   - ⚠️ 归档兜底同样适用于 devlog（`{ARTIFACTS_FALLBACK_DIR}/{组件名}-*/devlog/`）、knowledge（`{ARTIFACTS_FALLBACK_DIR}/{组件名}-*/knowledge/`）与 metrics（`{ARTIFACTS_FALLBACK_DIR}/{组件名}-*/metrics/`）：运行时目录检索不到时提示用户归档副本存在，经用户同意后复制回运行时目录（⚠️ 二者为软复用 skill（tech-doc/knowledge-loop）产物，**不自动复制**，避免干扰其自身检索逻辑；与工作上下文「命中即自动恢复」的行为差异是**有意设计**）
2. **复杂度与分阶段决策**：
   - 简单组件（单文件、无子组件、API < 8个）→ 单轮做完，不分 P（Gate 仍逐阶段确认，不因单轮而跳过）
   - 复杂组件（多子组件/递归/多模式，如 Menu/Table/Cascader）→ **必须分阶段 P1-Pn**，本轮只做一个 P，避免半成品
   - 分阶段时在工作上下文「阶段规划」表里写清每个 P 的范围
3. **列 plan**：用 `todo_write` 把本轮要做的事拆成 todo（对应阶段 1-5 的具体动作）
4. **确认参考源与 API 风格**：读 `references/reference-sources.md`，确定主参考（antdv/naive）与 API 风格，写入工作上下文
5. **项目特有需求确认**：向用户确认参考库没有、但项目需要的额外功能/属性/行为，登记到工作上下文「项目特有需求」区——**验收基准 = 对齐清单 + 项目特有需求**，两源合并，避免「参考库没有的功能」成为盲区
6. **git 身份实测登记**：`git config user.name` + `git config user.email` 实测，写入工作上下文 frontmatter `git_identity`（阶段 5 提交前与实测值比对，不符拦截——对应模板注释「阶段 0 实测登记」）

**产出**：工作上下文文件 + todo plan + 分阶段决策。

**🚦 Gate 0**：输出阶段 0 报告（组件名 / 分阶段计划 / 主参考源 / 项目特有需求）→ 弹 `ask_followup_question`（✅ 继续 / ⏸️ 暂停 / ⬅️ 回退）→ 用户确认后进入阶段 1。未确认不得继续。

---

## 阶段 1 · 准备（分支 + 目录 + 注册占位）

**目标**：建好骨架，让组件能被导入（哪怕还是空壳）。

1. **分支策略**（读 `references/checklists.md` §分支）：
   - 全新组件 → 从主干新建 `feat/{组件名}`
   - 已有雏形（如 Menu 在 layout 分支）→ 在既有特性分支续做，不新建
   - ⚠️ 先 `git branch --show-current` 确认当前分支，不盲目切换
   - **⭐ 登记 `base_ref`（分批提交必需）**：`git merge-base origin/main HEAD`（主干名按实际调整）实测后写入工作上下文 frontmatter `base_ref` —— 组件常分批开发、每批单独提交，阶段 5 的 C5 品牌扫描要用基点回溯**已提交批次**（只查工作区会漏，详见 `refine-spec.md` §1.3）
2. **建组件目录**（读 `references/project-map.md` §组件结构）：
   - 单组件：`components/{组件名}/` → `{Xxx}.vue` + `index.ts`
   - 多子组件：`components/{组件名}/{子}/` 各自 `.vue` + `index.ts`，外层 `index.ts` 聚合
   - 用 `templates/component.tpl.vue` 作骨架
3. **注册占位**（读 `references/checklists.md` §注册同步 + `references/linkage-map.md` §④）：
   - `components/{组件名}/index.ts`：`withInstall` + 类型导出
   - `components/components.ts`：追加 `export type {...}` + `export { default as Xxx }`
   - **⭐ `components/utils/style-deps.ts`**（2026-09-22 修正：四张表的**单一数据源**，D 方案后 `resolver.ts` 只读不再定义表）：`componentsMap` 映射 + `componentDependencies` 依赖（组件 `.vue` 内实际 `import` 的组件逐一列出，**复合组件逐子组件各自登记**）+ 必要时 `styleSources` / `stylelessComponents`——**这是功能缺陷级联动点，漏配会导致按需引入缺样式**；权威校验 `pnpm verify:deps`
   - 顶层 `components/index.ts` 与 router **无需手改**（自动）

**产出**：可import 的组件骨架 + 注册完成。

**🚦 Gate 1**：输出阶段 1 报告（分支名 / 新建目录与文件 / 注册链路）→ 弹 `ask_followup_question`（✅ 继续 / ⏸️ 暂停 / ⬅️ 回退）→ 用户确认后进入阶段 2。未确认不得继续。

---

## 阶段 2 · 组件本体开发

**目标**：实现组件功能，对齐参考库，最大化复用项目资产。

1. **先搜索后编码（红线）**：读 `references/reusable-assets.md`，需要的**功能/样式/布局/逻辑**（动画/浮层/主题/尺寸监听/工具函数/滚动条/暂无数据/清除按钮等）**先查项目已有**，有则直接复用（引用组件或抽取逻辑），无则按复用优先级参考实现，**禁止重复开发**。必要时 `use_skill('knowledge-loop')` 检索历史组件经验。
   **实现方式复用优先级**（读 `references/reference-sources.md` §实现方式复用优先级）：项目已有组件/功能/样式/布局/逻辑 > antdv 源码实现 > naive 源码实现 > 自研，逐级确认无可用实现后才允许自研。
2. **对照参考库**（读 `references/reference-sources.md`）：
   a) 读取源码：`{REF_ANTDV_LOCAL}/components/{组件名}/src/*.tsx` 与 `interface.ts`（API/Props/默认值/字段名权威源；Menu 例：`Menu.tsx` / `interface.ts` / `SubMenu.tsx`）
   b) 读取**全部 demo**：`{REF_ANTDV_LOCAL}/components/{组件名}/demo/*.vue`（用户视角用例，逐个理解数据与交互）
   c) 生成完备性基线（**写入工作上下文「对齐清单」区**，`templates/working-context-lite.tpl.md` 已含该区域；接续时直接读取，不重做）：
      - **API 四维对比清单**：Props / Events（事件名 + 回调参数结构）/ Slots（插槽名 + 参数）/ Expose（暴露方法 + 签名，⚠️ 内部分析术语，文档章节标题对应 `## Methods`），逐项对比类型/默认值/必填/字段名
      - **源码渲染分支清单**（2026-09-15 新增）：读参考库渲染实现，逐分支列出（类型分支 / 空值兜底 / prop vs slot 优先级 / 数组归一 / falsy 边界）并与本实现对照，差异显式决策（详见 `references/reference-sources.md` §渲染分支与兜底逻辑对齐）
      - **Demo 用例对齐清单**：官网全部展示用例逐一列出（顺序与官网一致）
      - **naive 差异登记**（读 `references/reference-sources.md` §naive 差异登记）：naive 也有该组件时，登记「naive 有而 antdv 无」的特性到工作上下文「naive 差异登记」区，逐项给出决策（对齐 / 不覆盖（理由）/ 待用户确认）
   d) 对齐顺序：先 API 四维接口（Props/Events/Slots/Expose/默认值/字段名）→ 再逐个 Demo 用例
   e) 复杂功能参考源码算法思路（改写为项目风格，禁整段拷贝带版权代码）
3. **编码红线**：
   - 主题 **light/dark 双份**（沿用 `useInject('组件名')` + ConfigProvider）
   - 所有链式访问用可选链 `?.`；禁 `any`（用 `unknown` + 守卫）；`const` 优先；`===`
   - **SSR 安全**：docs 会 SSR 渲染，禁裸用 `window`/`document`，需判断或 onMounted 内用
   - CSS：scoped；缩进 2 空格；嵌套 ≤3 层；颜色/间距用主题变量
4. **类型定义**：Props/事件/暴露方法定义明确类型，从 `Xxx.vue` 导出，经`index.ts` 对齐到 `components.ts`

**产出**：功能完整的组件本体 + 类型。

**🚦 Gate 2**：输出阶段 2 报告（改动文件清单 + **API 四维对比清单** + **源码渲染分支清单** + **Demo 用例对齐清单** + **naive 差异登记** + 默认值/字段名对齐检查 + vue-tsc/ESLint 结果）→ 弹 `ask_followup_question`（✅ 继续 / ⏸️ 暂停 / ⬅️ 回退）→ 用户确认后进入阶段 3。未确认不得继续。

---

## 阶段 3 · 演示用例

**目标**：在 `src/views` 建演示页，作为验收基准（阶段 4 文档会复用它）。演示页 = **antdv 官网展示用例的完整复制 + 本项目组件对照**。

0. **格式参考先行（动笔前必做）**：`read_file` 2-3 个**同类已有组件**的演示页（如开发 Tooltip 参考 `src/views/popover/Index.vue`、`src/views/select/Index.vue`），提取项目既有格式惯例并在编写时**逐项遵循**：
   - **标题层级与间距 class**：项目惯例（如 `<h2 class="mt30 mb10">`）优先，模板骨架的 `.demo-desc` 等占位 class 仅作注释参考，落地时替换为项目实际 class
   - **分区结构**：对照分区用 `demo-row`/`demo-col` 还是项目其他容器写法，沿用项目惯例
   - **描述风格**：`<p class="mb10">` + `<code>` 的实际用法样例（项目其他演示页怎么写的就怎么写）
   - **数据声明/事件处理组织惯例**：script 顶部集中声明还是分区就近声明，沿用项目惯例
   > 原则：**项目既有惯例 > 模板骨架**；`templates/demo.tpl.vue` 只提供结构与注释，格式细节一律以项目内已有演示页为准。演示用例与文档用例的格式规范权威源：`references/demo-description.md`。

1. 建 `src/views/{组件名}/`：
   - `Index.vue`：用 `templates/demo.tpl.vue` 作骨架（结构要求见下）
   - `index.ts`：`export default { title: '{中文名}' }`（路由自动注册，无需改 router）
2. **用例结构（核心要求）**：
   - **完整复制 antdv 官网全部展示用例**：官网组件页（如 `https://www.antdv.com/components/{组件名}-cn/`）的每个展示用例都要在演示页中有对应分区，**分区顺序与官网展示用例顺序一致**（1、2、3… 按官网原序编号），只保留**用例标题 + 必要描述**（仿照项目其他组件演示页的写法，不复制大段官网文案）
   - **简介描述规范**：读 `references/demo-description.md`（标题纯场景名 / 信息增量评估 / 代码标记 / 权威源=演示页 / 改动即同步）。核心红线：**演示页是简介描述的唯一权威源，docs 是派生副本，任何改动先改演示页再同步 docs，禁止单边修改**
   - **每个分区两个组件对照**：①「本项目组件」——本项目 `<Xxx>` 实现同一场景（**左/上**）；②「antd 官网组件」——原样复制官网该用例的代码与数据（**右/下**）
   - 两组件并排对照，行为/视觉 1:1 一致——这是**验收标准**
   - 项目特有场景（主题切换 light/dark 等官网没有的用例）单独追加分区
3. **引入真身**（两种方式，按项目配置择一）：
   - **方式 A（自动按需，优先）**：项目 `vite.config.ts` 已配 `unplugin-vue-components` 的 `AntDesignVueResolver`（vue-amazing-ui 即此配置）时，模板中直接用 `<a-xxx>` 全局标签（如 `<a-auto-complete>`），插件自动按需导入，**无需手动 import**
   - **方式 B（显式 import）**：项目未配 resolver 时，演示页 dev 环境显式 `import { Xxx as AXxx } from 'ant-design-vue'`（项目 devDependencies 已有）
   - ⚠️ 先确认项目是否配置 resolver（`grep AntDesignVueResolver vite.config.ts`）再择一；两种方式本地 clone 不存在时同样可用
4. 覆盖要求：官网全部用例（不遗漏、**顺序一致**）+ 边界（禁用/空数据/极值）+ 主题切换

**产出**：可在 `pnpm dev` 中访问的演示页。

**🚦 Gate 3**：输出阶段 3 报告（演示页分区清单 + antdv 官网用例完整复制对照表 + 每分区双组件对照检查 + 顺序一致性检查 + 浏览器实测截图）→ 弹 `ask_followup_question`（✅ 继续 / ⏸️ 暂停 / ⬅️ 回退）→ 用户确认后进入阶段 4。未确认不得继续。

---

## 阶段 4 · 文档

**目标**：补vitepress 组件文档及周边文档。

1. **组件文档**：`docs/guide/components/{组件名}.md`
   - **关键：复用演示页**——docs 与 `src/views/{组件名}/Index.vue` 的 script+template 高度同源，直接迁移并加 vitepress 说明块（何时使用/API 表格）
   - **简介描述同源**：读 `references/demo-description.md` §4 同步机制——docs 描述**从演示页逐字复制**（仅 `<code>` ↔ 反引号转换、docs 加 `<br/>`、演示页无 `<br/>`），段落数一致，禁止单边改写
   - ⚠️ **迁移时剔除对照内容**：docs 仅保留本项目 `<Xxx>` 用例，**剔除「antd 官网组件」分区及 `ant-design-vue` 真身 import**（对照仅验收期存在于演示页 `src/views`，阶段 5 收尾清除，不进文档）
   - API 表格：Props/Events/Slots/暴露方法，参照 antdv 文档结构
   - **API 章节标题按组件实际能力（2026-09-15 修正）**：`## APIs`（含 Props 表 + 类型定义子表）**必有**，且其下含 `### {组件名}` 子标题；`## Events` / `## Methods`（对外暴露方法）**仅当组件有 emit / defineExpose 时才要求**（❌ 无事件却凭空补章节）；⚠️ 内部术语「Expose」**禁止直接作标题**，落地为 `## Methods`
2. **周边文档联动**（读 `references/checklists.md` §周边文档 + `references/linkage-map.md` §⑩⑪⑫）：
   - vitepress 侧边栏配置（新增组件入口）
   - `docs/index.md`（若有组件清单）
   - `docs/guide/changelog.md`（新增变更记录，**先读 `references/changelog-spec.md`**：版本号升级规则 + 双处同步 `package.json` version + 条目格式）
   - `README.md` + `README.zh-CN.md`（组件清单，中英双份）
   - **⭐ 组件总数数字 +1（4 处）**：`docs/guide/features.md` / `docs/index.md` hero `details` / `README.zh-CN.md` / `README.md`，逐一 +1，改完 grep 自检数字一致

**产出**：可在 `pnpm docs:dev` 中访问的组件文档 + 周边同步。

**🚦 Gate 4**：输出阶段 4 报告（组件文档 + 周边文档改动清单 + docs 与演示页同源性检查）→ 弹 `ask_followup_question`（✅ 继续 / ⏸️ 暂停 / ⬅️ 回退）→ 用户确认后进入阶段 5。未确认不得继续。

---

## 阶段 5 · 验收收尾

**目标**：质量验证 + 能力沉淀 + 清除对照与交付前精修 + 提交。

1. **质量验证**（读 `references/checklists.md` §验收）：
   - `pnpm lint:check`（ESLint，须 EXIT 0）
   - `pnpm type-check`（vue-tsc，须无本组件错误）
   - `pnpm test`（Vitest 全量，新增或改动组件时必跑）与 `pnpm docs:build`（阶段 4 改过文档 demo / 内联 script 时验证文档站可编译）
   - **浏览器实测**：`pnpm dev` 打开演示页，与真身 1:1 对照；按 `checklists.md` §交互操作清单逐项勾销（每个用例的可枚举操作点）；控制台 0 error/warning
   - **交互验收 e2e（可选软复用）**：`e2e-testing` skill 可用时跑关键交互用例，缺失则降级为手动勾销并一句话提示
   - ⚠️ 后台 watch 进程会干扰终端输出 → 复杂命令重定向到文件再 `read_file` 读取；验证后关端口
2. **基线全量勾销（核心红线）**：把工作上下文「对齐清单」区（API 四维 + Demo 用例）+「naive 差异登记」+「项目特有需求」**全量回显**到 Gate 5 报告，逐行标注 ✅/❌；❌ 项必须带处置码（`延后 P{n}` / `不覆盖（理由）` / `待用户确认`）；**禁止摘要式报告**（清单与验收同源，杜绝漏项）
   - **API 四维对账以 antdv 官网 API 属性列表为最终对照源**（官网组件文档页的 API 表格 + 本地源码 `interface.ts` 双源核对），确认每个属性/事件/插槽/暴露方法都已覆盖
3. **能力沉淀**（软复用，读 `references/capability-reuse.md`）：
   - devlog：`use_skill('tech-doc')` 生成开发日志
   - metrics：`mkdir -p ~/.codebuddy/dev-comp/metrics` 后按 `templates/metrics-lite.tpl.yaml` 写一份到 `CAP_METRICS_DIR`
   - knowledge：`use_skill('knowledge-loop')` 沉淀组件经验（接口/易错点）
   - ⚠️ **三件套为阶段 5 必做项**：被调 skill 缺失时允许降级跳过，但必须在 Gate 5 报告「能力沉淀三件套」区块登记 ❌ + 降级原因，并向用户明示、经用户确认后才视为收尾完成（历史事故：三次开发均跳过 devlog/knowledge，产物不完整）
   - **适用范围（2026-09-22 修正）**：三件套只对**本次在途开发**的组件（分支净改动含其 `components/` / `src/views/` / `docs` 路径）必做；对**存量组件**（顺手校验的历史组件）脚本 S4 整块 **SKIP**——避免把「历史组件本就没有产物」当成待办（原实现会产生 3 条误导性 WARN）
4. **提交**：`use_skill('smart-commit')` 生成 `feat: ...` message（无 scope）→ **等用户确认才提交**。提交前强制执行：
   a) **git 身份实测（红线）**：`git config user.name` + `git config user.email` 实测输出，与工作上下文 frontmatter `git_identity` 预期值逐字对比；不符 → 🔴 拦截提交，弹 `ask_followup_question` 呈现「实测值 vs 预期值」，用户决策后（修正 local config / 确认改用实测值 / 取消提交）方可继续（历史事故：comment 提交误用全局公司身份 `deardai@tencent.com`）
   b) **提交后 hash 实测回填**：`git log -1 --format='%h'` **实测** commit hash 回填工作上下文 frontmatter `commit` 字段，禁止凭记忆记录（历史事故：Dropdown 记录 `7c6ab6a5` 与真实 `e4d8c9a0` 不符）
5. **清除对照 + 交付前精修（红线 · ⭐ 2026-09-22 扩展）**：本步一次性完成「清品牌 → 精修三处产物 → 三方对账」，**权威源 `references/refine-spec.md`**（判定标准 / 改写范式 / 对照矩阵），执行顺序不可颠倒（先清避免白改、后对保证三方一致）。
   a) **清除演示页对照**：删除演示页全部 antdv/naive 真身组件、对应数据（如 `avalue*`/`aoptions*`）、`ant-design-vue` 相关 import 及 antdv 专属图标（本库用例仍使用的图标保留）；⚠️ **`components.d.ts` 中 antdv 组件声明不会自动消失**——清除对照后必须显式 `grep` 确认无幽灵声明并手动删除、**随本次 commit 一起提交**（`linkage-map.md` §⑭；幽灵声明已提交进 git，删除不随 commit 提交会「复活」）；同时检查 `src/App.vue` 是否有全局配置迁移残留的孤儿变量（`linkage-map.md` §⑬）；验收前确保 `git diff` 中演示页仅剩本库用例
   b) **品牌信息全量清除**（`refine-spec.md` §1）：**两段口径**（⚠️ 兼容分批开发/分批提交）——①本分支**净改动**新增行（`git diff <base>`，基点 → **当前工作区**，一次覆盖「已提交的每一批 + 未提交改动」）②未跟踪新增文件全文；最小入侵、存量不追溯。覆盖组件源码 / **docs 全部内容（组件文档 + changelog/features/index）** / 演示页 / 单测 / 根级 README；清除 `antdv` `antd` `ant-design-vue` `Ant Design Vue` `naive` `naive-ui` `<a-xxx>` `avalue*`·`aoptions*` `antdTheme` 等品牌字样，以及**注释里的来源标注**。**处置**：品牌对比/差异说明类内容（docs「与 XX 的差异」段落、changelog「对齐 XX」说明）**整段直接删除、不保留**，其余去品牌化或删除（§1.4）。例外：`@ant-design/*` 基础包（图标/色板）。脚本 `C5` 实测 0 命中；⚠️ base 未解析时会 WARN（分批提交必须 `--base <ref>` 重跑或用工作上下文 `base_ref`）
   c) **组件源码精修**：①注释（§2）——组件级 ≤3 行 / 字段级每字段中文语义注释 / 分支级写「为什么」；删复述代码、**过期注释**、品牌来源标注，>3 行的原理解释移入 devlog；②Props 排序（§3）——**六段式**（双向绑定 → 内容数据 → 形态外观 → 状态反馈 → 行为交互 → 进阶透传）+ 段内语义相邻（不强制字母序），增量属性**插入所属段**（❌ 禁追末尾），并**同步 docs `## APIs` 表顺序**（两者逐项同序，脚本 `G2` 校验——脚本保「一致」、人工保「合理」）
   d) **演示用例精修**（§4）：官网用例**保序**、新增用例**插回官网原序位置**（❌ 不 append 末尾）、项目特有用例统一归末尾区块；布局——单例整块 / 2+ 同构示例并排 / **交互类单独全宽**，**同类型用例布局必须一致**；分区结构统一（`<h2 class="mt30 mb10">` → 可选 `<p class="mb10">` → 示例容器）
   e) **docs ↔ views 对齐 + 三方对账**（§5）：按对照矩阵逐格核对——「源码 Props/Events/Slots/Methods ↔ docs 表 ↔ views 覆盖」与「views 用例集合/顺序/标题/描述/布局 ↔ docs」；用例**数量/顺序/标题**由脚本 `G4` 实测；差异一律**先改权威源、再同步派生副本**（`demo-description.md` §0），❌ 项带处置码
   f) **精修后复验（必须，不可省）**：精修属实质改动 → 重跑 `pnpm lint:check` + `pnpm type-check` + `pnpm test` + `pnpm dev` 浏览器实测（对照已删，确认本库用例正常、无孤儿引用、控制台 0 error/warning），结果补进 Gate 5 报告「验证结果」（标注**精修后重跑**）；同时**回填 devlog**（第 3 步产物）记录精修要点，必要时更新工作上下文「对齐清单」
   ⚠️ 精修记录（品牌清除 / 注释 / Props 排序 / 用例排序布局 / 三方一致性）写入工作上下文「交付前精修记录」区，Gate 5 回显。
6. **发布前配置项终检（核心红线）**：**先跑轻量校验脚本** `bash scripts/validate-component.sh {组件名} {PROJECT_ROOT} --context {工作上下文文件}`（⚠️ 分批提交 / 长生命周期分支加 `--base <ref>` 或依赖工作上下文 `base_ref`，确保 C5 回溯已提交批次）一次性获取 A/B/C/E/F/G + S 全部勾销证据（脚本是确定性检查的权威执行体，见 `checklists.md` §发布前配置项终检 顶部声明；S1-S5 对应提交红线：git 身份 / 分支核对 / commit hash 回填真实性 / 沉淀三件套 / 归档双份），再读 `references/checklists.md` §发布前配置项终检 逐项核对。⚠️ 埋入阶段（1/4）的检查不能替代本终检——埋入后文件可能再被改动，发布前必须全量回检。脚本输出 `[PASS/FAIL/WARN/SKIP]` 逐项回显到 Gate 5 报告（A/B/C/E/F/G 回显「发布前配置项终检」区块，S 回显「提交前检查」区块）：FAIL 阻断收尾须修复后重跑；WARN/SKIP 须人工确认；❌ 项必带处置码，禁止摘要式报告。
7. **引导发布（组件全部 P 完成且验收通过时）**：读 `references/release-flow.md`，向用户呈现「合入 main（GitHub PR）→ main 上构建发布 → 发布后清理」完整链路并引导执行；若用户本轮不发布，将「待发布：合入 main + 发布」写入工作上下文接续指引，**验收完成 ≠ 任务结束**（历史事故：AutoComplete 验收后停 8 个提交在 feat 分支，npm 与源码脱节）
8. **收尾**：更新工作上下文 status + `release` 字段（本 P 完成 → 标注下一 P 接续指引；全部 P 完成但未发布 → `release: pending` + 接续指引标注「待发布」；本轮已完成发布 → `release: released: {版本号}` + 可归档）
9. **产物归档（统一运行时目录 · 无需决策 · 2026-08-21 修订）**：产物一律留在 `~/.codebuddy/` 运行时目录（原位即归档，**不搬移、不产生副本**）；**禁止再弹归档决策**（2026-08-19/20 的 A/B 决策做法已废止）。收尾时只需在 Gate 5 报告的「能力沉淀三件套与产物位置」表中**列出四项产物路径**（working-context / metrics / devlog / knowledge），让用户知道文件在哪。⚠️ `ARTIFACTS_FALLBACK_DIR` 仅用于**读取历史归档**（阶段 0 两级扫描兜底），不再作为新产物的归档目标

**产出**：验收通过 + devlog/metrics/knowledge + commit（待用户确认）。

**🚦 Gate 5**：输出阶段 5 报告（发布前配置项终检表 + 基线全量勾销表 + **交付前精修记录表** + lint / type-check / 浏览器实测结果 + 交互操作清单勾销结果 + commit message 预览）→ **「待用户确认」项须在报告中单独汇总，用户逐项决策后验收才算通过** → 弹 `ask_followup_question`（📦 确认提交 / 🔧 继续修复 / ⏸️ 暂停）→ 用户确认后由 smart-commit 执行提交。**未经用户明确选择「确认提交」不得 `git commit`**。

---

## Gate 门控机制

> dev-comp 的轻量门控：借鉴 dev-flow 4 层门控，只保留交互式 Gate（G1/G2）+ 轻量校验脚本（G3，仅作确定性检查数据源），**不引入** `.validated` 物理文件 / JSON 逐步校验 / post-step 自动门控 / 门控 subagent / 工具门禁。

### 三个核心层

| 层 | 名称 | 说明 |
|---|------|------|
| G1 | **交互式推进选项** | 每阶段完成后弹 `ask_followup_question`：✅ 继续 / ⏸️ 暂停 / ⬅️ 回退 |
| G2 | **阶段完成报告** | 每阶段结束必须先输出标准化报告；未输出报告禁止弹推进选项、禁止进入下一阶段 |
| G3 | **轻量校验脚本** | `scripts/validate-component.sh`（确定性检查数据源，仅 Gate 5 阶段必跑）。定位是**数据源**而非门控：不做 `.validated` 物理锁、不接状态机、不阻断其他阶段；输出 `[PASS/FAIL/WARN/SKIP]` 嵌入 Gate 5 报告（设计哲学「确定性用代码，模糊性用 LLM」：确定性项下沉脚本，模糊性项保留 G1/G2 由用户决策） |

> 核心约定：Gate **不依赖文件系统级验证**，而依赖 AI 遵循「先输出报告 → 再弹交互式选项 → 等用户确认」的顺序。这在简单领域流程中足够，避免了 scripts/precheck 等复杂基础设施；G3 脚本仅承载「确定性检查的执行」这一层，与 dev-flow 的 post-step 自动门控有本质区别。

### Gate 报告模板

```markdown
## 🚦 Gate {N}：阶段 {N} 完成

### 改动文件清单
| 文件 | 改动行数 | 说明 |
|------|---------|------|

### 与 antdv 对齐检查（阶段 2/3 适用，顺序与官网一致）
| 官网用例（按官网顺序） | 本项目用例 | antd 官网用例复制 | 缺失处置 |
|-----------|:--:|:--:|---------|
（缺失处置码：`延后 P{n}` / `不覆盖（理由）` / `待用户确认`）

### API 四维对账（阶段 2 适用）
| 类别 | 项 | antdv | 本实现 | 对齐 |
|------|----|-------|--------|:--:|
| Props | | | | |
| Events | | | | |
| Slots | | | | |
| Expose（文档标题 Methods） | | | | |

### naive 差异登记对账（阶段 5 适用）
| 特性 | 决策 | 状态 |
|------|------|:--:|

### 项目特有需求对账（阶段 5 适用）
| 需求 | 状态 |
|------|:--:|

### 发布前配置项终检（Gate 5 适用，权威源 checklists.md §发布前配置项终检，逐项勾销）
| 类 | 配置项 | 状态 | 自检证据 |
|----|--------|:--:|---------|
| A | withInstall + 类型导出 | | |
| A | components.ts 类型+组件导出 | | |
| A | ⭐ `style-deps.ts` componentsMap | | grep 命中 |
| A | ⭐ `style-deps.ts` componentDependencies（复合组件逐子组件） | | grep 逐一对上 |
| A | 自动注册（index.ts / router 未手改） | | git diff 无痕迹 |
| B | 组件文档 {组件名}.md | | |
| B | vitepress 侧边栏入口 | | grep 命中 |
| B | changelog 变更记录 | | grep 命中 |
| B | ⭐ 组件总数 4 处 +1 | | grep 数字一致 |
| B | API 章节标题按能力（APIs 必有 + ### 组件名 子标题；Events/Methods 按 emit/expose） | | 脚本 B5/B6 |
| B | API 表类型列无 slot 写法 | | 脚本 B7 |
| B | ⭐ `## Slots` 表结构与用法列写法（列头 名称\|说明\|用法 + `v-slot:xxx`） | | 脚本 B8 |
| C | ⭐ components.d.ts 幽灵声明 | | grep 0 匹配 |
| C | App.vue 孤儿变量（仅涉及时） | | 不涉及 N/A 或 grep |
| C | 演示页对照清除 | | git diff 仅本库用例 |
| C | 调试代码清理 | | |
| C | ⭐ 品牌信息 0 残留（本分支净改动新增行[基点→当前工作区] + 新增文件全文；含 docs 全部内容） | | 脚本 C5 |
| E | 组件总数 4 处数字一致 | | grep 数字一致 |
| E | 演示页 ↔ docs 描述同源 | | grep 双向一致 |
| F | ⭐ 组件规范（defineSlots + 组件名Slots / 根类名 组件名-wrap / 注释无 slot 写法 / useSlotsExist 无冗余） | | 脚本 F1-F4 |
| F | ⭐ types/global-components.d.ts 全局声明登记（差集为空） | | 脚本 F5 |
| F | ⭐ changelog 三查（章节唯一 / 链接站内相对路径 / future 无残留） | | 脚本 F6 |
| F | 演示页序号注释与组件库 import | | 脚本 F7-F8 |
| G | G1 组件源码注释精修（三层结构 / 无复述与过期注释 / 无品牌来源标注） | | 人工（refine-spec §2） |
| G | G2 Props 排序（六段式分组 + 段内语义相邻 + 与 docs 表逐项同序） | | 脚本 G2 |
| G | G3 演示用例排序与布局（官网保序 / 新增插回原序 / 同类型布局一致） | | 人工（refine-spec §4） |
| G | G4 docs ↔ views 用例对齐（数量 / 顺序 / 标题逐字） | | 脚本 G4 |
| G | G5 三方一致性对照矩阵逐格勾销（源码 ↔ docs ↔ views） | | 人工（refine-spec §5.1） |
| G | G6 精修记录已入工作上下文 + 精修后已复验 | | 人工 |

（❌ 项必带处置码，同基线勾销规则；禁止摘要式报告）

### 验证结果
- [ ] vue-tsc 通过（⚠️ 第 5 步精修后已重跑）
- [ ] ESLint 通过（⚠️ 第 5 步精修后已重跑）
- [ ] pnpm test 通过（精修后已重跑）
- [ ] 浏览器实测截图（⚠️ 第 5 步清除对照 + 精修后重跑，确认无孤儿引用、控制台 0 error/warning）
- [ ] 交互操作清单逐项勾销（含 e2e 软复用结果，可选）

### 交付前精修记录（Gate 5 适用，第 5 步产物 · 权威源 refine-spec.md §6.2，逐项勾销）
| 项 | 状态 | 证据/说明 |
|----|:--:|------|
| 品牌信息清除（本次改动口径，命中数=0） | | 脚本 C5 |
| 组件源码注释精修（删复述 / 修过期 / 补边界） | | |
| Props 排序（是否重排 + docs 表已同步同序） | | 脚本 G2 |
| 演示用例排序与布局（调整了哪些用例/哪类布局） | | |
| 三方一致性差异项与处置（改哪边、为什么） | | |

（❌ 项必带处置码；与工作上下文「交付前精修记录」区同源）

### 能力沉淀三件套与产物位置（Gate 5 适用，逐项勾销）
| 产物 | 状态 | 位置/降级说明 |
|------|:--:|------|
| devlog | | |
| metrics | | |
| knowledge | | |
| working-context | | 收尾后原位保留（运行时目录） |

（降级跳过 → ❌ + 降级原因 + 用户已确认；禁止无声跳过。本表即「告知用户产物位置」的落点 —— 产物一律留在 `~/.codebuddy/` 运行时目录，**无需再弹归档决策**）

### 提交前检查（Gate 5 适用，逐项实测；S1-S3 由脚本实测输出回填）
| 检查项 | 实测值 vs 预期 | 状态 |
|--------|---------------|:--:|
| S1 git config user.name（对比 git_identity） | | |
| S1 git config user.email（对比 git_identity） | | |
| S2 当前分支 = 工作上下文 branch | | |
| commit message 预览 | | |
| S3 commit hash 回填（提交后 `git log -1 --format='%h'` 实测） | | |
| S4 能力沉淀三件套（devlog / metrics / knowledge；**存量组件不适用 → SKIP**） | | 脚本 S4 输出 |
| S5 产物存放位置（应在运行时目录，无新增归档副本） | | 脚本 S5 输出 |

### 工作上下文已同步（Gate 5 适用）
- [ ] status / phase / 进度接续指引已更新
- [ ] frontmatter `commit` 已回填实测 hash
- [ ] frontmatter `release` 已更新（pending / released: {版本号}）

### 👉 请确认
```

紧跟 `ask_followup_question`（**Gate 0-4** 选项固定为 A/B/C 三项：✅ 继续 / ⏸️ 暂停 / ⬅️ 回退；**Gate 5 例外**——涉及提交红线，选项为 📦 确认提交 / 🔧 继续修复 / ⏸️ 暂停）：

```json
{
  "questions": [{
    "id": "gate-N",
    "question": "阶段 N 已完成，是否继续？",
    "options": [
      {"label": "✅ 继续", "description": "进入阶段 N+1"},
      {"label": "⏸️ 暂停", "description": "我有补充/疑问"},
      {"label": "⬅️ 回退", "description": "重新执行阶段 N"}
    ]
  }]
}
```

### 与 dev-flow Gate 的差异

| 对比维度 | dev-flow | dev-comp（本 skill） |
|---------|----------|---------------------|
| `.validated` 物理文件 | ✅ 有 | ❌ 不引入 |
| JSON 完成标记 | ✅ 有 | ❌ 改为 Markdown 报告 |
| post-step.sh | ✅ 有 | ❌ 不引入 |
| 门控 Subagent | ✅ 有（步骤 4/5.5/6/7） | ❌ 不引入 |
| 工具门禁 | ✅ 有（阶段 0 禁写代码） | ❌ 不引入 |
| 交互式推进选项 | ✅ 有（A/B/C） | ✅ 保留（核心层 G1） |
| 强制等用户确认 | ✅ 有（`interactive_progression_shown`） | ✅ 保留（核心层 G2，依赖 AI 遵守「先报告再 `ask_followup_question`」约定） |
| 轻量校验脚本 | ✅ 15 个 lint + precheck/hooks 自动触发 | ✅ 1 个 `validate-component.sh`（G3 数据源，仅 Gate 5 必跑，无自动触发） |

---

## dc:st / dc:status 子命令

两级扫描 `vaui-{组件名}-*.md`：**第一级** `~/.codebuddy/dev-comp/working-context/`；**第一级无结果时第二级兜底** `{ARTIFACTS_FALLBACK_DIR}/{组件名}-*/working-context/`（配置留空则跳过，两级均无 → 提示「该组件无工作上下文，可能未开始或已归档」）。读取后输出：组件名/当前 phase/进度/下一步/未完成的 P/发布状态（`release` 字段：pending → 提示「待发布：合入 main + 发布」，released → 显示已发布版本号）；来源为 artifacts 时标注「归档副本」。
