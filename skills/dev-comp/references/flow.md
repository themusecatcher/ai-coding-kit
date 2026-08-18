# dev-comp 6 阶段执行规范

> 本文件是 dev-comp 各阶段的详细执行手册。SKILL.md 触发后按需加载本文件。
> 原则：轻量、领域聚焦、软复用能力。全程不进dev-flow 状态机。

---

## 阶段 0 · 接续 / 初始化

**目标**：判断是新组件还是接续已有组件，建立/恢复工作上下文，列出计划。

1. **扫描已有工作上下文**：`ls ~/.codebuddy/working-context/ | grep -i {组件名}`
   - 命中 → 读取该文件，恢复 phase/进度/决策，跳到「下一步动作」继续，**不新建**
   - 未命中 → 用 `templates/working-context-lite.tpl.md` 新建（命名：`vaui-{组件名}-{YYYYMMDD}.md`）
2. **复杂度与分阶段决策**：
   - 简单组件（单文件、无子组件、API < 8个）→ 单轮做完，不分 P（Gate 仍逐阶段确认，不因单轮而跳过）
   - 复杂组件（多子组件/递归/多模式，如 Menu/Table/Cascader）→ **必须分阶段 P1-Pn**，本轮只做一个 P，避免半成品
   - 分阶段时在工作上下文「阶段规划」表里写清每个 P 的范围
3. **列 plan**：用 `todo_write` 把本轮要做的事拆成 todo（对应阶段 1-5 的具体动作）
4. **确认参考源与 API 风格**：读 `references/reference-sources.md`，确定主参考（antdv/naive）与 API 风格，写入工作上下文
5. **项目特有需求确认**：向用户确认参考库没有、但项目需要的额外功能/属性/行为，登记到工作上下文「项目特有需求」区——**验收基准 = 对齐清单 + 项目特有需求**，两源合并，避免「参考库没有的功能」成为盲区

**产出**：工作上下文文件 + todo plan + 分阶段决策。

**🚦 Gate 0**：输出阶段 0 报告（组件名 / 分阶段计划 / 主参考源 / 项目特有需求）→ 弹 `ask_followup_question`（✅ 继续 / ⏸️ 暂停 / ⬅️ 回退）→ 用户确认后进入阶段 1。未确认不得继续。

---

## 阶段 1 · 准备（分支 + 目录 + 注册占位）

**目标**：建好骨架，让组件能被导入（哪怕还是空壳）。

1. **分支策略**（读 `references/checklists.md` §分支）：
   - 全新组件 → 从主干新建 `feat/{组件名}`
   - 已有雏形（如 Menu 在 layout 分支）→ 在既有特性分支续做，不新建
   - ⚠️ 先 `git branch --show-current` 确认当前分支，不盲目切换
2. **建组件目录**（读 `references/project-map.md` §组件结构）：
   - 单组件：`components/{组件名}/` → `{Xxx}.vue` + `index.ts`
   - 多子组件：`components/{组件名}/{子}/` 各自 `.vue` + `index.ts`，外层 `index.ts` 聚合
   - 用 `templates/component.tpl.vue` 作骨架
3. **注册占位**（读 `references/checklists.md` §注册同步）：
   - `components/{组件名}/index.ts`：`withInstall` + 类型导出
   - `components/components.ts`：追加 `export type {...}` + `export { default as Xxx }`
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
      - **API 四维对比清单**：Props / Events（事件名 + 回调参数结构）/ Slots（插槽名 + 参数）/ Expose（暴露方法 + 签名），逐项对比类型/默认值/必填/字段名
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

**🚦 Gate 2**：输出阶段 2 报告（改动文件清单 + **API 四维对比清单** + **Demo 用例对齐清单** + **naive 差异登记** + 默认值/字段名对齐检查 + vue-tsc/ESLint 结果）→ 弹 `ask_followup_question`（✅ 继续 / ⏸️ 暂停 / ⬅️ 回退）→ 用户确认后进入阶段 3。未确认不得继续。

---

## 阶段 3 · 演示用例

**目标**：在 `src/views` 建演示页，作为验收基准（阶段 4 文档会复用它）。演示页 = **antdv 官网展示用例的完整复制 + 本项目组件对照**。

1. 建 `src/views/{组件名}/`：
   - `Index.vue`：用 `templates/demo.tpl.vue` 作骨架（结构要求见下）
   - `index.ts`：`export default { title: '{中文名}' }`（路由自动注册，无需改 router）
2. **用例结构（核心要求）**：
   - **完整复制 antdv 官网全部展示用例**：官网组件页（如 `https://www.antdv.com/components/{组件名}-cn/`）的每个展示用例都要在演示页中有对应分区，**分区顺序与官网展示用例顺序一致**（1、2、3… 按官网原序编号），只保留**用例标题 + 必要描述**（仿照项目其他组件演示页的写法，不复制大段官网文案）
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
   - ⚠️ **迁移时剔除对照内容**：docs 仅保留本项目 `<Xxx>` 用例，**剔除「antd 官网组件」分区及 `ant-design-vue` 真身 import**（对照只存在于演示页 `src/views`，不进文档）
   - API 表格：Props/Events/Slots/暴露方法，参照 antdv 文档结构
2. **周边文档联动**（读 `references/checklists.md` §周边文档）：
   - vitepress 侧边栏配置（新增组件入口）
   - `docs/index.md`（若有组件清单）
   - `docs/guide/changelog.md`（新增变更记录）
   - `README.md` + `README.zh-CN.md`（组件清单，中英双份）

**产出**：可在 `pnpm docs:dev` 中访问的组件文档 + 周边同步。

**🚦 Gate 4**：输出阶段 4 报告（组件文档 + 周边文档改动清单 + docs 与演示页同源性检查）→ 弹 `ask_followup_question`（✅ 继续 / ⏸️ 暂停 / ⬅️ 回退）→ 用户确认后进入阶段 5。未确认不得继续。

---

## 阶段 5 · 验收收尾

**目标**：质量验证 + 能力沉淀 + 提交。

1. **质量验证**（读 `references/checklists.md` §验收）：
   - `pnpm lint:check`（ESLint，须 EXIT 0）
   - `pnpm type-check`（vue-tsc，须无本组件错误）
   - **浏览器实测**：`pnpm dev` 打开演示页，与真身 1:1 对照；按 `checklists.md` §交互操作清单逐项勾销（每个用例的可枚举操作点）；控制台 0 error/warning
   - **交互验收 e2e（可选软复用）**：`e2e-testing` skill 可用时跑关键交互用例，缺失则降级为手动勾销并一句话提示
   - ⚠️ 后台 watch 进程会干扰终端输出 → 复杂命令重定向到文件再 `read_file` 读取；验证后关端口
2. **基线全量勾销（核心红线）**：把工作上下文「对齐清单」区（API 四维 + Demo 用例）+「naive 差异登记」+「项目特有需求」**全量回显**到 Gate 5 报告，逐行标注 ✅/❌；❌ 项必须带处置码（`延后 P{n}` / `不覆盖（理由）` / `待用户确认`）；**禁止摘要式报告**（清单与验收同源，杜绝漏项）
   - **API 四维对账以 antdv 官网 API 属性列表为最终对照源**（官网组件文档页的 API 表格 + 本地源码 `interface.ts` 双源核对），确认每个属性/事件/插槽/暴露方法都已覆盖
3. **能力沉淀**（软复用，缺失则降级跳过，读 `references/capability-reuse.md`）：
   - devlog：`use_skill('tech-doc')` 生成开发日志
   - metrics：按 `templates/metrics-lite.tpl.yaml` 写一份到 `CAP_METRICS_DIR`
   - knowledge：`use_skill('knowledge-loop')` 沉淀组件经验（接口/易错点）
4. **提交**：`use_skill('smart-commit')` 生成 `feat: ...` message（无 scope）→ **等用户确认才提交**
5. **收尾**：更新工作上下文 status（本P 完成 → 若还有下一 P，标注接续指引；全部完成 → 可归档）

**产出**：验收通过 + devlog/metrics/knowledge + commit（待用户确认）。

**🚦 Gate 5**：输出阶段 5 报告（基线全量勾销表 + lint / type-check / 浏览器实测结果 + 交互操作清单勾销结果 + commit message 预览）→ **「待用户确认」项须在报告中单独汇总，用户逐项决策后验收才算通过** → 弹 `ask_followup_question`（📦 确认提交 / 🔧 继续修复 / ⏸️ 暂停）→ 用户确认后由 smart-commit 执行提交。**未经用户明确选择「确认提交」不得 `git commit`**。

---

## Gate 门控机制

> dev-comp 的轻量门控：借鉴 dev-flow 4 层门控，只保留两个核心层，**不引入** `.validated` 物理文件 / JSON 逐步校验 / post-step 脚本 / 门控 subagent / 工具门禁。

### 两个核心层

| 层 | 名称 | 说明 |
|---|------|------|
| G1 | **交互式推进选项** | 每阶段完成后弹 `ask_followup_question`：✅ 继续 / ⏸️ 暂停 / ⬅️ 回退 |
| G2 | **阶段完成报告** | 每阶段结束必须先输出标准化报告；未输出报告禁止弹推进选项、禁止进入下一阶段 |

> 核心约定：Gate **不依赖文件系统级验证**，而依赖 AI 遵循「先输出报告 → 再弹交互式选项 → 等用户确认」的顺序。这在简单领域流程中足够，避免了 scripts/precheck 等复杂基础设施。

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
| Expose | | | | |

### naive 差异登记对账（阶段 5 适用）
| 特性 | 决策 | 状态 |
|------|------|:--:|

### 项目特有需求对账（阶段 5 适用）
| 需求 | 状态 |
|------|:--:|

### 验证结果
- [ ] vue-tsc 通过
- [ ] ESLint 通过
- [ ] 浏览器实测截图
- [ ] 交互操作清单逐项勾销（含 e2e 软复用结果，可选）

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

---

## dc:st / dc:status 子命令

读取当前组件的工作上下文，输出：组件名/当前 phase/进度/下一步/未完成的 P。
