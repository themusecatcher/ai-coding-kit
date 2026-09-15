# 新增组件联动配置地图（linkage-map）

> dev-comp 阶段 1/4/5 必读。新增一个组件时，除组件本体外，还需同步以下**全部**联动点。
> ⚠️ 本清单的「⭐ 易遗漏」标注来自历史事故复盘，**禁止跳过**：
> - **2026-08-18（AutoComplete）漏 4 处**：resolver 依赖映射、4 处组件总数、components.d.ts 幽灵声明、App.vue 孤儿变量；2026-08-19 追加第 5 处：**发布版本号升级错误**（新增组件只升 patch，2.4.28 应为 2.5.0，规范见 `changelog-spec.md`）。
> - **2026-09-15（Comment）漏 1 处**：**`types/global-components.d.ts` 未登记**（全仓唯一缺失项，见 §⑮）。⚠️ 该遗漏**不报错、不中断构建、`pnpm type-check` 仍 PASS**——演示页标签静默失去类型检查，隐蔽性最强，只能靠显式 grep/脚本发现。
> - 同批复盘还修正了 2 处**存量不一致**：目录命名约定过时（→ `project-map.md` §目录命名约定）、changelog 链接规则与版本章节唯一性（→ `changelog-spec.md`）。规则变更必须同步脚本与检查清单，详见 `rules/按需-Skill设计-跨文件协作.mdc` §2.1。

---

## 一图总览

> ⚠️ ⑮ 为**追加编号**（阶段 1 执行），排在末尾只为不改动既有 ①-⑭ 编号，避免引用断链；执行顺序按「阶段」列，不按编号。

```
components/{name}/{Xxx}.vue          # ① 组件本体（阶段 2）
components/{name}/index.ts           # ② withInstall + 类型导出（阶段 1）
components/components.ts             # ③ 组件/类型导出（注册点 A，阶段 1）
components/utils/resolver.ts         # ④ 按需引入样式映射（注册点 B，阶段 1）⭐易遗漏
types/global-components.d.ts         # ⑮ 全局组件类型声明登记（注册点 D，阶段 1）⭐易遗漏
src/views/{name}/Index.vue           # ⑤ 演示页（阶段 3）
src/views/{name}/index.ts            # ⑥ 演示页 meta title（阶段 3）
docs/guide/components/{name}.md      # ⑦ 组件文档（阶段 4）
docs/.vitepress/config.ts            # ⑧ 侧边栏入口（注册点 C，阶段 4）
docs/guide/changelog.md              # ⑨ 更新日志（阶段 4）⭐版本号规则 → changelog-spec.md
docs/guide/features.md               # ⑩ 组件总数（阶段 4）⭐易遗漏
docs/index.md                        # ⑪ 首页 hero 组件总数（阶段 4）⭐易遗漏
README.md + README.zh-CN.md          # ⑫ 特性行组件总数 + 组件表格（阶段 4）⭐易遗漏
src/App.vue                          # ⑬ 全局配置残留清理（阶段 5）⭐易遗漏（仅涉及时）
components.d.ts                      # ⑭ 幽灵声明清理（自动生成，阶段 5）⭐易遗漏
```

## 各联动点详解

### ④ `components/utils/resolver.ts`（按需引入样式映射）⭐ 最高优先级

> 功能缺陷级遗漏：漏配会导致用户按需引入组件时**缺样式**（本次 AutoComplete 漏了 Scrollbar 依赖样式）。

两处需同步：

1. **`componentsMap`**：组件名 → 样式目录路径。按字母序插入：
   ```ts
   AutoComplete: 'auto-complete',
   ```
   - key 为组件导出名（PascalCase）；value 为该组件在 `components/` 下的**真实目录名**，必须 `ls components/` 实测后照抄（多子组件用子目录路径，如 `Descriptions: 'descriptions/descriptions'`、`Row: 'grid/row'`）。
   - ⚠️ 目录名以**实测为准**，禁止用 kebab/连写猜测（详见 `project-map.md` §目录命名约定）。

2. **`componentDependencies`**：组件内部**实际 import 的其它组件**，需列出其样式依赖。按字母序插入：
   ```ts
   AutoComplete: ['Scrollbar'],
   ```
   - **判定依据 = 组件 `.vue` 里的 `import Xxx from 'components/xxx'`**，逐个列出（grep 组件源文件的 `import .* from 'components/`）。
   - 只列**会渲染且带样式**的组件依赖；纯逻辑/工具函数（`components/utils`）不列。
   - 同款组件可参照既有条目（如 `Select: ['Empty', 'Scrollbar']`——AutoComplete 与 Select 同为下拉输入类，依赖模式一致）。

3. **无样式组件列表**（`getSideEffects` 内的 `['ConfigProvider', 'Highlight', 'NumberAnimation', 'Watermark']`）：新组件若**无 `<style>` 块且无外部 CSS 依赖**才需加入；有样式块则不加。

4. **特殊外部样式**（`getSideEffects` 内 DatePicker/Swiper 分支）：新组件若 import 了第三方带样式的库（如 datepicker/swiper），需仿照追加对应 `.css`。

### ⑮ `types/global-components.d.ts`（全局组件类型声明登记）⭐ 2026-09-15 事故点

> 职责区分（易混）：`components.d.ts` 是 **unplugin-vue-components 自动生成物**（只收录 `<a-xxx>` 之类第三方解析结果，勿手改）；`types/global-components.d.ts` 是**手工维护**的自有组件全量声明，被 `tsconfig.app.json` 的 `include: ["types/*.d.ts"]` 纳入 vue-tsc 模板类型检查。

- 位置：项目根 `types/global-components.d.ts` → `declare module 'vue' { export interface GlobalComponents { ... } }` 块内（缩进 4 空格）。
- 登记方式：按**字母序**插入一行，值取自有组件导出名：
  ```ts
  Comment: typeof VueAmazingUI.Comment
  ```
- 覆盖范围：**与 `components/utils/resolver.ts` 的 `componentsMap` 一一对应**（含复合子组件 `Row`/`Col`/`DescriptionsItem`/`ListItem` 与 Provider `MessageProvider`/`ModalProvider`/`DialogProvider`/`NotificationProvider`）。
- 自检命令（已下沉脚本 **F5**）：
  ```bash
  # 差集 = componentsMap 有、global-components.d.ts 无 → 即缺失项（应输出空）
  node -e "..."   # 完整实现见 scripts/validate-component.sh F5（不依赖 jq/node 亦可跑）
  ```
- **漏登记的后果（隐蔽性最强，必读）**：`<Xxx>` 未声明时，模板按未知标签处理 → 演示页 props/slots **不参与类型检查**，而 `pnpm type-check` **依然 PASS**、控制台无任何 error/warning。**「测试通过」不能证明已登记，只有显式 grep/脚本才能发现**。
- 触发条件：**任何新增组件 / 复合子组件 / Provider 都必须登记**（与其余联动点同级，**不是**"仅涉及时"）。
- 兜底：阶段 5 终检时 `git diff types/global-components.d.ts` 应含本次新增行，Gate 5 报告须回显该项证据。

### ⑩⑪⑫ 组件总数数字（4 处）⭐

> 文档一致性遗漏。新增组件后，下列 4 处的「共 X 个组件」数字必须 +1：

| 文件 | 位置 | 原文形态 |
|:--|:--|:--|
| `docs/guide/features.md` | §简要介绍 | `目前共包含 \`{N}\` 个基础 \`UI\` 组件以及 \`{M}\` 个工具函数...` |
| `docs/index.md` | hero `features` 的 `details` | `目前共包含 {N} 个基础 UI 组件以及 {M} 个工具函数...` |
| `README.zh-CN.md` | §特性 | `目前共包含 \`{N}\` 个基础 \`UI\` 组件以及 \`{M}\` 个工具函数...` |
| `README.md` | §Features | `includes \`{N}\` basic UI components and \`{M}\` utility functions...` |

- ⚠️ `{N}` / `{M}` 是**占位符**：以实测值为准（组件数 = `ls -d components/*/ | grep -vE 'components/(style|utils|discrete)/' | wc -l`），**禁止照抄任何历史数字**（2026-09-15 发现本表内示例数字已滞后 2 个版本，照抄即错）。
- **自检命令**：`grep -rEn "共包含|includes.*components|个基础" README.md README.zh-CN.md docs/index.md docs/guide/features.md`，确认 4 处数字一致且 = 实际组件数。（已下沉 `scripts/validate-component.sh` B4/E1，脚本 FAIL 时用此命令诊断）
- 实际组件数口径 = `ls -d components/*/ | grep -v -E 'components/(style|utils|discrete)/' | wc -l`（排除 style/utils/discrete 非组件目录；discrete 为命令式 API 模块，非 UI 组件）。

### ⑬ `src/App.vue` 全局配置残留 ⭐（仅涉及时）

> 迁移遗留：若开发中把 `<a-config-provider>` 换成本项目 `<ConfigProvider>`（或反之），旧的主题配置变量会残留为孤儿变量。

- 检查点：`src/App.vue` 内是否存在**定义但未使用**的变量（如迁移后残留的 `antTheme`）。
- 判定：grep 该变量名，若仅出现在定义处、模板/逻辑均未引用 → 孤儿，删除。
- 触发条件：仅当本次开发**动了全局 ConfigProvider/主题配置**时才检查；纯单组件开发通常不涉及。

### ⑭ `components.d.ts` 幽灵声明 ⭐

> 自动生成文件的过时残留，**双重根源**：① 开发期用 `<a-xxx>`（antdv 真身）对照时 unplugin 写入声明；② 该声明随「新增组件」提交被**连带提交进 git（已提交的过时声明）**。

- 位置：项目根 `components.d.ts`（`@ts-nocheck` 自动生成文件）。
- 检查点：文件中是否存在代码里**已不再使用**的 antdv 声明（如 `AAutoComplete`/`AButton` 等指向 `ant-design-vue/es` 的条目）。
- 清理判定：`grep -rEn "<a-xxx|AButton|AAutoComplete" src/ components/ docs/`（大小写两种形态都要查），0 匹配 → 该声明是幽灵，删除该行。
- **保留**实际仍在使用的（如 `GlobalLayout.vue` 用了 `<a-menu>` → `AMenu`/`AMenuItem` 保留）。
- ⚠️ **2026-09-15 实测修正（原表述过于绝对）**：unplugin 的 d.ts 生成**按当前扫描结果重写文件**——改演示页触发 dev server 重扫后，Comment 开发期残留的 8 条陈旧声明（`AAvatar`/`AButton`/`AComment`/`AFormItem`/`AList`/`AListItem`/`ATextarea`/`ATooltip`）被**自动删除**，仅保留实际在用的 `AMenu`/`AMenuItem`。
  - 更正结论：**清理行为取决于「是否触发重扫 + syncMode」，不可依赖**（原「默认不清理、不会自动消失」表述已废）。
  - 仍**强制**：验收阶段显式 grep 确认（与自动化清理无关），确认后的删除/保留结果随本次 commit 提交。
- **持久化红线（⭐ 关键）**：幽灵声明已提交进 git，`git checkout components.d.ts` 或 dev 重新生成**都可能恢复它**；必须**删除 + 随本次组件开发的 commit 一起提交**（阶段 5 收尾同步处理），否则清理不持久、下次即「复活」。

---

## 遗漏根因（复盘结论）

> 事故暴露的共同根因：新增组件的联动点分散在 10+ 个文件，且**无集中清单**。人（AI）靠记忆逐处更新，必然漏。

| 原则 | 说明 |
|:--|:--|
| **清单驱动，不靠记忆** | 阶段 1 起即以本 map 为唯一权威源逐项勾销，禁止「顺手补几处」 |
| **易遗漏点显式标注** | ⭐ 项是历史事故点，Gate 报告必须逐项回显确认 |
| **自动化自检兜底** | 确定性 grep 自检（§④⑩⑪⑫⑭ 的 A3/A4/B4/E1/C1 + §⑮ 的 F5）已收拢于 `scripts/validate-component.sh`——Gate 5 前置必跑，下方各节 grep 命令保留为脚本实现依据与失败诊断用；AI 输出「已完成」前必须实测 |
| **静默失效项优先自动化** | 「不报错但失效」的检查项（如 §⑮ 漏登记、文档写法残留）不能依赖 type-check/lint 兜底，必须进脚本 |

> 本清单随每次新增组件实践持续补全——若再次出现新遗漏，第一时间回填本 map 并复盘。
