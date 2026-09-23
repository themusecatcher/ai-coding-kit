---
name: dev-comp
category: dev-tools
description: 面向 vue-amazing-ui 组件库的单组件开发迭代工作流。轻量领域流程（6 阶段）+ 软交付前精修与三方一致性收口（品牌信息清除 / 注释精修 / Props 排序 / 演示用例排序布局 / docs↔views↔源码对账，兼容分批提交）+ 软复用 dev-flow 生态能力（工作上下文/plan/开发日志/度量/知识沉淀/提交），全程不进入 dev-flow 流程状态机与门控，因此轻量不臃肿。适用于在该组件库中新增或完善单个组件（如Menu/Table），参考源为 Ant Design Vue 与 Naive UI（官网+ 本地 clone 源码）。触发命令：dc: / 组件开发 / 开发 xxx 组件 / 完善 xxx 组件。
---

# dev-comp —— 组件库开发迭代工作流

> 定位：vue-amazing-ui 单组件开发迭代领域 SOP。
> 架构：**轻量领域流程 + 软复用 dev-flow 能力模块**。全程❌ 不产生 `.flow` 锁、❌ 不走 dev-flow 重型门控（`.validated` 物理检查点 / JSON 逐步校验 / 门控 subagent / post-step 脚本 / 工具门禁）；✅ 仅保留**轻量交互式 Gate**——每阶段完成后输出「阶段完成报告」并弹 `ask_followup_question`，等用户确认再进入下一阶段（详见「6 阶段 + Gate 流程总览」）；✅ 另配 1 个**轻量校验脚本** `scripts/validate-component.sh` 承载 Gate 5 确定性检查（A/B/C/E/F/G 配置项 + S 提交红线，设计哲学「确定性用代码」，详见「能力复用索引」）。

## ⚙️ 个人化配置区（复用/分享时只改这一块）

> 本 skill 核心流程通用；下列配置**换人换机时只需填 4 个本地路径**，其余保持默认即可。

### 必填（首次使用前填写；`ARTIFACTS_FALLBACK_DIR` 可留空）

| 配置项 | 填写你的本地路径 | 说明 |
|:--|:--|:--|
| `PROJECT_ROOT` | `~/myGithub/vue-amazing-ui` | 组件库项目根 |
| `REF_ANTDV_LOCAL` | `~/myGithub/ant-design-vue` | Ant Design Vue 本地 clone 路径（留空则降级用官网） |
| `REF_NAIVE_LOCAL` | `~/myGithub/naive-ui` | Naive UI 本地 clone 路径（留空则降级用官网） |
| `ARTIFACTS_FALLBACK_DIR` | `~/myGithub/ai-coding-kit/skills/dev-comp/artifacts/` | 产物归档兜底目录（用户将产物归档到 skill 下时使用；留空则仅扫 `~/.codebuddy/` 运行时目录） |

### 默认可用（无需修改）

| 配置项 | 当前值 | 说明 |
|:--|:--|:--|
| `REF_ANTDV_GH` | https://github.com/vueComponent/ant-design-vue | Ant Design Vue GitHub |
| `REF_NAIVE_GH` | https://github.com/tusen-ai/naive-ui | Naive UI GitHub |
| `REF_ANTDV_DOC` | https://www.antdv.com/components/overview-cn/ | antdv 官网 |
| `REF_NAIVE_DOC` | https://www.naiveui.com/zh-CN/os-theme/docs/introduction | naive 官网 |
| `CAP_WORKING_CONTEXT_DIR` | `~/.codebuddy/dev-comp/working-context/` | 工作上下文目录（dev-comp 专属） |
| `CAP_METRICS_DIR` | `~/.codebuddy/dev-comp/metrics/` | 度量报告目录（dev-comp 专属） |

> 本地 clone 不存在时：降级为仅用官网（web_fetch）参考，并提示用户可clone 以获得源码级复用。

## 📋 项目规范权威源（必读 · 2026-09-15 新增）

> 项目内已有面向贡献者的设计规范（`{PROJECT_ROOT}/development/`），是组件实现的**权威源**；本 skill 只做「引用 + 增量补充」，**禁止另起平行规则**。
> ⚠️ 本 skill 的 checklist / 模板 / 脚本与项目规范冲突时，**以项目规范为准**，并**立即回填本 skill**（单向断链是历史欠账的根因，见 `rules/按需-Skill设计-跨文件协作.mdc` §2.1）。映射表详见 `references/project-map.md` §项目规范权威源索引。

| 必读文件 | 关键内容 | 对应阶段 |
|:--|:--|:--|
| `development/component-design.md` | SFC 三段式 / `export interface Props` / **`defineSlots` + `<组件名>Slots`** / 主题注入 / 样式与 CSS 变量 / **根类名 `{组件名}-wrap`** | 1-2 |
| `development/import-export.md` | 三层导出模型 / 组件 `index.ts` 三件套 / **新增组件「三步接线」Checklist** / **`style-deps.ts` 四张表**（D 方案单一数据源） | 1 |
| `development/demo-doc-guide.md` | 演示页结构 / 自动路由 / 组件文档模板 / 侧边栏维护 / **演示与文档必须一致** | 3-4 |
| `development/project-structure.md` | 顶层目录职责 / 命名规范速查 | 1/3/4 |
| `development/build-system.md` | 三产物构建（dist / es / lib）/ 别名与模块解析 | 5（发布） |
| `types/global-components.d.ts` | **手工维护**的自有组件全局类型声明 → 新增组件**必登记**（⚠️ 漏登记不报错、`pnpm type-check` 仍 PASS，见 `linkage-map.md` §⑮） | 1 |

## 📦 产物存储设计原则（2026-08-18 固化 · 2026-08-19 补第 6 条 · 2026-08-21 第 6 条收敛为「统一运行时目录」）

> 决策背景：深入评估过「产物入仓库」方案，被开源仓库 git 污染 + dev-flow 生态路径硬绑定否决。产物**一律**留在 `~/.codebuddy/`（第 1-5 条 2026-08-18 固化；第 6 条 2026-08-19 初版为「用户可选归档到 `artifacts/`」，**2026-08-21 按用户决策收敛为「统一运行时目录 + 收尾告知位置」，不再弹归档决策**）。`artifacts/` 目录保留（skill 内置 `skills/dev-comp/.gitignore` 忽略其内容、仅保留 `artifacts/README.md`），但**仅作为历史归档的读取兜底**，不再接收新产物；⚠️ 换仓库分发本 skill 时须连同该 `.gitignore` 一起复制。本小节固化六条原则，防止后续迭代被顺手改回。

1. **产物不入仓库**：vue-amazing-ui 是开源项目，工作上下文/对齐清单/决策记录/度量是个人私有开发过程，进 git 污染公开历史，进 `.gitignore` 污染所有 fork 者（**历史归档到 `ARTIFACTS_FALLBACK_DIR` 的快照同样不入库**，见第 6 条）
2. **软复用产物沿用固有约定**：devlog（`~/.codebuddy/dev-logs/{YYYYMMDD}_{类型}_{简述}/devlog.md`，tech-doc 实际规范，目录名由 tech-doc 生成规则决定，**禁止自拟** `<项目>/<分支>/` 结构）、knowledge（`~/.codebuddy/knowledge/vue-amazing-ui/`）路径由被软复用的 tech-doc / knowledge-loop skill 硬编码，改不得也不该改（零硬依赖原则）
3. **自建产物物理隔离**：工作上下文、metrics 放 dev-comp 专属根目录 `~/.codebuddy/dev-comp/`（`working-context/` + `metrics/` 子目录）。不与 dev-flow 混放，避免被 dev-flow 的 lint 全量扫描 / dashboard 统计 / 度量闸门校验误伤
4. **命名前缀不变**：`vaui-` 前缀保留，专属目录内按组件检索不受影响
5. **目录自举（写前必建）**：`~/.codebuddy/dev-comp/` 专属目录首次使用不存在，阶段 0 初始化与阶段 5 写 metrics 前必须 `mkdir -p` 兜底，禁止假设目录已存在
6. **产物归档（统一运行时目录 · 2026-08-19 固化 · 2026-08-21 修订）**：产物**一律留在 `~/.codebuddy/` 运行时目录**（原位即归档，**不搬移、不产生副本**）；阶段 5 收尾**不弹归档决策**，只需在 Gate 5 报告中**告知四项产物位置**（working-context / metrics / devlog / knowledge）。`ARTIFACTS_FALLBACK_DIR` 仅保留为**历史归档的读取兜底** —— 阶段 0 接续扫描按「**运行时目录优先 → 兜底**」两级顺序（详见 `references/flow.md` 阶段 0），命中历史归档时复制回运行时目录恢复活跃状态；该目录**不再作为新产物的归档目标**

## 触发规则

| 信号 | 行为 |
|:--|:--|
| `dc:`（技能名 `dev-comp` 也生效） | 进入 dev-comp，提示指定组件名 |
| `dc: {组件名}` / `dc: 开发 Menu` | 进入，开发指定组件 |
| `dc:status` / `dc:st` | 查看当前组件进度 |
| 仅输入 `dc:`（无后续） | 提示补充组件名 |
| `组件开发` / `开发 {X} 组件` / `完善 {X} 组件` / `补全 {X} 组件` | 进入 dev-comp |
| 仅提及组件但无开发意图（如"看看 Menu 怎么实现的"）| 不触发，普通对话 |

**优先级**：incident-triage（告警硬触发）> 用户显式 dev-flow 命令 > dev-comp > 普通对话。
**与 dev-flow 互斥**：用户显式用 `dev-flow` 命令时走 dev-flow；用 `dc:` / `dev-comp` 或组件开发意图时走本 skill。二者不同时激活。

## 6 阶段 + Gate 流程总览

> 术语约定：**antd = Ant Design Vue**（官网 https://www.antdv.com/ ），非 React 版 ant.design；本文档中 antdv 与 antd 同义。
> 每阶段完成后插入一道 🚦 **Gate**：先输出「阶段完成报告」，再弹 `ask_followup_question`（✅ 继续 / ⏸️ 暂停 / ⬅️ 回退），**未获用户确认不得进入下一阶段**。
> 「一次性走完」仅指**不分 P1-Pn**（单轮交付），Gate 仍逐阶段必弹，不得跳过。

```
阶段 0  接续/初始化   → 读/建精简工作上下文 + todo plan + 分阶段决策
阶段 1  准备          → 分支 + 建目录/配置 + 注册占位（含 types/global-components.d.ts 登记）
阶段 2  组件本体      → 对照antdv/naive 源码开发（API 四维 + 渲染分支 + 先搜索复用项目资产）
阶段 3  演示用例      → 完整复制官网用例（顺序一致）+ 双组件对照（src/views/xxx/Index.vue + index.ts）（⚠️ 对照为验收期临时结构，阶段 5 收尾清除）
阶段 4  文档          → docs 复用演示页 + 周边文档联动
阶段 5  验收收尾      → 配置项终检 + 基线全量勾销 + lint+type-check+浏览器对照 → devlog+metrics+knowledge → **清除对照 + 交付前精修**（品牌清零/注释/Props 排序/用例布局/docs 对齐 + 复验）→ smart-commit → 引导发布（合入 main + 构建发布）
```

**各阶段对应 Gate**：Gate 0 确认组件名/分阶段计划/参考源/项目特有需求 · Gate 1 确认分支/目录/注册骨架（含全局类型声明登记）· Gate 2 确认功能 + API 四维/渲染分支/Demo 用例对齐清单 · Gate 3 确认演示页完整复制官网用例（顺序一致）+ 双组件对照 · Gate 4 确认文档完整 · Gate 5 配置项终检 + 基线全量勾销 + 交付前精修记录 + 确认验收结果 + 提交。

> Gate 报告模板 + 交互式选项定义 → `references/flow.md` §Gate 门控机制
> 完整执行规范 → `read_file("references/flow.md")`

## 能力复用索引（软复用，零硬依赖 dev-flow）

| 能力 | 复用方式 | 何时用 | 详见 |
|:--|:--|:--|:--|
| 工作上下文 | 自建精简版模板 | 阶段 0 建/接续 | `templates/working-context-lite.tpl.md` |
| plan | `todo_write` 工具 | 阶段 0 列计划 | — |
| 开发日志 | `use_skill('tech-doc')` | 阶段 5 收尾 | `references/capability-reuse.md` |
| 度量采集 | 自建精简 YAML | 阶段 5 收尾 | `templates/metrics-lite.tpl.yaml` |
| 知识沉淀 | `use_skill('knowledge-loop')` | 阶段 2 检索 / 阶段 5 沉淀 | `references/capability-reuse.md` |
| 提交 | `use_skill('smart-commit')` | 阶段 5 提交 | `references/capability-reuse.md` |
| 交互验收 e2e | `use_skill('e2e-testing')`（可选） | 阶段 5 关键交互用例 | `references/checklists.md` §交互操作清单 |
| 配置项终检 + 精修校验 + 提交红线校验 | `scripts/validate-component.sh`（本 skill 自带） | 阶段 5 收尾必跑（Gate 5 数据源） | `references/checklists.md` §发布前配置项终检 |

> ⚠️ 上述被调 skill 缺失时**优雅降级**：跳过该环节并一句话提示用户，不阻断主流程。

## 按需加载索引

| 场景 | 加载文件 |
|:--|:--|
| 执行任一阶段 | `references/flow.md` |
| 项目规范权威源映射 / 项目结构/注册链路 | `references/project-map.md` |
| 参考源路径 + antdv/naive 取舍 + **渲染分支对齐** | `references/reference-sources.md` |
| 找可复用的项目已有资产 | `references/reusable-assets.md` |
| 全链路 checklist（含 **F 类组件规范** + **G 类交付前精修**）+ 发布前配置项终检 | `references/checklists.md` |
| **交付前精修与三方一致性**（品牌清除 / 注释精修 / Props 排序 / 用例排序布局 / docs↔views↔源码对账） | `references/refine-spec.md` |
| 新增组件联动配置地图（⭐易遗漏点全集，含 ⑮ 全局类型声明） | `references/linkage-map.md` |
| 用例标题/简介描述规范（权威源 + 同步） | `references/demo-description.md` |
| changelog 编写规范（版本号升级 + 双处同步 + 章节唯一性） | `references/changelog-spec.md` |
| 发布流程（合入 main + 构建发布 + 清理） | `references/release-flow.md` |
| 如何软复用 dev-flow 能力 + 降级 | `references/capability-reuse.md` |

## 核心红线（继承项目规范）

- ❌ 禁止自动 `git commit`：commit message仅生成，用户明确选择才提交（用 smart-commit）
- ❌ commit 格式：`<type>: <description>`（**无 scope**，项目 commitlint scope-empty）
- ❌ **提交前 git 身份实测**：`git config user.name/email` 实测值必须与工作上下文 `git_identity` 一致，不符拦截、用户决策后继续；提交后 `git log -1 --format='%h'` 实测 hash 回填（详见 `references/flow.md` 阶段 5 第 4 步）
- ❌ 先搜索后编码：新增能力前先查项目已有资产（`references/reusable-assets.md`）
- ✅ 实现方式复用优先级：项目已有组件/功能/样式/布局/逻辑 > antdv 源码实现 > naive 源码实现 > 自研；**组件库已有的功能/样式/布局/逻辑优先复用，禁止重新开发**（详见 `references/reference-sources.md`）
- ✅ 主题 light/dark 双份；链式访问用可选链 `?.`；禁 any；SSR 安全（禁裸用 window/document）
- ✅ 大组件分阶段交付（P1-Pn），避免半成品
- ✅ 验收标准：演示页与antdv/naive 真身并排 1:1 对照（本项目组件在左/上，官网组件在右/下）+ 用例顺序符合已确认排序锚点（默认官网序，见 `refine-spec.md` §4.1）+ 浏览器实测（⚠️ 对照仅为验收手段：阶段 3 引入 → 阶段 5 浏览器实测验收 → **验收完成后由阶段 5 第 5 步清除**，演示页回归纯本库组件）
- ✅ 清单即验收基线：阶段 2 对齐清单（API 四维 + **渲染分支** + Demo 用例）+ naive 差异登记 + 阶段 0 项目特有需求 = 阶段 5 验收唯一对账标准，Gate 5 全量回显勾销，❌ 项必带处置码（`延后 P{n}` / `不覆盖（理由）` / `待用户确认`），禁止摘要式报告
- ✅ **联动清单即注册基线**：`references/linkage-map.md` 是「新增组件全量联动点」唯一权威源（含 ⭐ 易遗漏点：**`style-deps.ts` 四张表**（D 方案单一数据源，含复合组件逐子组件登记）/ 组件总数 4 处 / components.d.ts 幽灵声明 / App.vue 孤儿变量 / **⑮ types/global-components.d.ts 全局类型声明登记**）。阶段 1/4/5 逐项勾销，**禁止靠记忆「顺手补几处」**；确定性 grep 自检已收拢于 `scripts/validate-component.sh`（Gate 5 必跑），宣告完成前必须实测
- ✅ **配置项终检即发布基线**：`references/checklists.md` §发布前配置项终检 是阶段 5 验收时固定配置项（代码注册/文档联动/残留清理/一致性/**组件规范**/**交付前精修**）的唯一权威源，Gate 5 必须全量逐项回显勾销 + grep 自检实测；**埋入阶段（1/4）的检查不能替代终检**，发布前必须全量回检
- ✅ **品牌信息 0 残留红线**（脚本 C5 拦截）：交付物不得残留 antdv / naive 的品牌内容与信息——库名（`antdv`/`antd`/`ant-design-vue`/`Ant Design Vue`/`naive`/`naive-ui`）、`<a-xxx>` 真身标签、`avalue*`·`aoptions*`·`antdTheme` 等残留，**以及注释里的来源标注**；**范围含 docs 全部内容（组件文档 + changelog/features/index）**、组件源码、演示页、单测、根级 README。**两段口径**（⚠️ 兼容分批开发/分批提交）=「①本分支**净改动**新增行（`git diff <base>` 基点→当前工作区，一次覆盖已提交的每一批 + 未提交改动）②未跟踪新增文件全文」（**存量不追溯**）——只查工作区会漏掉已提交的批次，base 取 `--base` / 工作上下文 `base_ref` / `merge-base 主干`（指定或登记的 ref **无法解析**时脚本给「C5 判定不完整」WARN 并回显该 ref——此 WARN ≠ 通过，须核对 ref 后重跑）；净改动为 0 但已提交批次仍有残留时会 WARN「删除须随本次 commit 提交，否则复活」。**处置**：品牌对比/差异说明类内容（docs「与 XX 的差异」段落、changelog「对齐 XX」说明）**整段直接删除、不保留**。**例外**：`@ant-design/*` 基础包（图标/色板）不清除。详见 `references/refine-spec.md` §1
- ✅ **交付前精修必做**（阶段 5 第 5 步，红线）：**范围 = 四来源**（`refine-spec.md` §0.1）——组件源码 / 演示页 / docs / **git 已提交批次**；**起手先取范围清单**：`git diff --name-only <base>` + `git ls-files --others --exclude-standard`（脚本 **`G0`** 已按三载体分类输出），一次覆盖「已提交的每一批 + 未提交改动」；❌ **只看工作区 `git diff`** 在分批提交场景会整段漏检已提交批次，❌ **范围与本轮改动面无关**（本轮没改的载体也要逐项过）。每次组件开发收尾都要①**组件源码注释精修**（三层结构 / 删复述与过期注释 / 删品牌来源标注）②**Props 排序**（六段式分组 → 双向绑定→内容数据→形态外观→状态反馈→行为交互→进阶透传，段内语义相邻；增量属性**插入所属段**、❌ 禁追末尾；源码顺序 ≡ docs `## APIs` 表顺序）③**演示用例排序与布局**（**排序锚点先确认**，见 `refine-spec.md` §4.1：A 官网保序＝默认，官网用例保序 / 新增插回原序 / 特有用例归末尾；B 合理性优先＝用户明确「无需对齐官网」时启用，主题聚簇 + 由浅入深 / 特有用例就近插入；单例整块 / 多例并排 / 交互类全宽，同类型布局一致）④**docs ↔ views 用例对齐**（数量/顺序/标题逐字）+ **三方一致性对照**（源码↔docs↔views 全维度）。⚠️ 结论为「无需改动」也必须附**逐载体核对证据**（逐层 / 逐区结论），`grep` 抽检 ≠ 精修。精修属实质改动 → **必须复验**（lint + type-check + 浏览器实测）。权威源 `references/refine-spec.md`，脚本 `G0`/`C5`/`G2`/`G4` 拦截
- ✅ **验收完成 ≠ 任务结束**：验收通过后按 `references/release-flow.md` 引导「合入 main（GitHub PR）→ main 上构建发布（`pnpm pub`，执行前用户逐条确认）→ 发布后清理（删 feat 分支）」；❌ 严禁在 feat 分支上执行发布；用户本轮不发布则写入工作上下文接续指引
- ✅ **组件规范红线**（权威源 `development/component-design.md`，脚本 F1-F3 拦截）：插槽类型 `export interface {组件名}Slots` + `defineSlots<{组件名}Slots>()`（⚠️ **无插槽组件豁免**——内部渲染内核等无 `<slot`/`useSlotsExist`/`$slots` 的 .vue 不强制声明；复合组件逐 .vue 校验）；根类名 = `{组件名}-wrap`（❌ 禁 `m-` / `vui-` 等自拟前缀）；Props/Slots 注释禁写 `string | slot`；`useSlotsExist` 只传实际使用的插槽名
- ✅ **全局类型声明必登记**（脚本 F5 拦截）：新增组件 / 复合子组件 / Provider 必须在 `types/global-components.d.ts` 登记（`linkage-map.md` §⑮）——⚠️ 漏登记**不报错、`pnpm type-check` 仍 PASS**，属静默失效，只能靠脚本兜底
- ✅ **对齐维度 = API 四维 + 渲染分支 + Demo 用例**（三者缺一不可）：必须读参考库渲染实现**逐分支**核对（字符串/VNode/空值兜底/双源优先级/数组归一/falsy 边界），差异显式决策并登记（详见 `reference-sources.md` §渲染分支与兜底逻辑对齐）
- ✅ **演示页红线**（脚本 F7/F8 拦截）：分区按已确认排序锚点**排列**（默认官网原序，锚点定义见 `refine-spec.md` §4.1），但标题与 script 注释**不带数字序号**；本项目组件**无需 import**（全局注册，直接写 `<Xxx>` 标签）
- ✅ **changelog 红线**（脚本 F6 拦截）：版本章节**唯一**且严格递减；条目链接用**站内相对路径 + 实测目录名（kebab）**；`## future` 清单同步删除已落地组件；`package.json` 与 changelog 双处一致（`changelog-spec.md` §3.4）
- ✅ **文档红线**（脚本 B5/B6/B7/B8 拦截）：`## APIs` 必有且含 `### {组件名}` 子标题；`## Events` / `## Methods` 按组件实际能力（有 emit / `defineExpose` 才写）；类型列写真实 TS 类型（❌ 禁 `string | slot`）；`## Slots` 表列头「名称 | 说明 | 用法」+ 用法列 `v-slot:xxx`
