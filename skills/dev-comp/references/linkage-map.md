# 新增组件联动配置地图（linkage-map）

> dev-comp 阶段 1/4/5 必读。新增一个组件时，除组件本体外，还需同步以下**全部**联动点。
> ⚠️ 本清单的「⭐ 易遗漏」标注来自历史事故复盘（`AutoComplete` 组件），**禁止跳过**——2026-08-18 一批事故漏了 4 处：resolver 依赖映射、4 处组件总数、components.d.ts 幽灵声明、App.vue 孤儿变量；2026-08-19 追加第 5 处：**发布版本号升级错误**（新增组件只升 patch，2.4.28 应为 2.5.0，规范见 `changelog-spec.md`）。

---

## 一图总览

```
components/{name}/{Xxx}.vue          # ① 组件本体（阶段 2）
components/{name}/index.ts           # ② withInstall + 类型导出（阶段 1）
components/components.ts             # ③ 组件/类型导出（注册点 A，阶段 1）
components/utils/resolver.ts         # ④ 按需引入样式映射（注册点 B，阶段 1）⭐易遗漏
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
   AutoComplete: 'autocomplete',
   ```
   - 多子组件映射规则（参照已有）：`Descriptions: 'descriptions/descriptions'`、`Row: 'grid/row'` 等（子目录路径）。

2. **`componentDependencies`**：组件内部**实际 import 的其它组件**，需列出其样式依赖。按字母序插入：
   ```ts
   AutoComplete: ['Scrollbar'],
   ```
   - **判定依据 = 组件 `.vue` 里的 `import Xxx from 'components/xxx'`**，逐个列出（grep 组件源文件的 `import .* from 'components/`）。
   - 只列**会渲染且带样式**的组件依赖；纯逻辑/工具函数（`components/utils`）不列。
   - 同款组件可参照既有条目（如 `Select: ['Empty', 'Scrollbar']`——AutoComplete 与 Select 同为下拉输入类，依赖模式一致）。

3. **无样式组件列表**（`getSideEffects` 内的 `['ConfigProvider', 'Highlight', 'NumberAnimation', 'Watermark']`）：新组件若**无 `<style>` 块且无外部 CSS 依赖**才需加入；有样式块则不加。

4. **特殊外部样式**（`getSideEffects` 内 DatePicker/Swiper 分支）：新组件若 import 了第三方带样式的库（如 datepicker/swiper），需仿照追加对应 `.css`。

### ⑩⑪⑫ 组件总数数字（4 处）⭐

> 文档一致性遗漏。新增组件后，下列 4 处的「共 X 个组件」数字必须 +1：

| 文件 | 位置 | 原文形态 |
|:--|:--|:--|
| `docs/guide/features.md` | §简要介绍 | `目前共包含 \`67\` 个基础 \`UI\` 组件以及 \`18\` 个工具函数...` |
| `docs/index.md` | hero `features` 的 `details` | `目前共包含 67 个基础 UI 组件以及 18 个工具函数...` |
| `README.zh-CN.md` | §特性 | `目前共包含 \`67\` 个基础 \`UI\` 组件以及 \`18\` 个工具函数...` |
| `README.md` | §Features | `includes \`67\` basic UI components and \`18\` utility functions...` |

- **自检命令**：`grep -rEn "共包含|includes.*components|个基础" README.md README.zh-CN.md docs/index.md docs/guide/features.md`，确认数字一致且 = `components/` 实际组件数。（已下沉 `scripts/validate-component.sh` B4/E1，脚本 FAIL 时用此命令诊断）
- 实际组件数口径 = `ls -d components/*/ | grep -v -E 'components/(style|utils)/' | wc -l`（排除 style/utils 非组件目录）。

### ⑬ `src/App.vue` 全局配置残留 ⭐（仅涉及时）

> 迁移遗留：若开发中把 `<a-config-provider>` 换成本项目 `<ConfigProvider>`（或反之），旧的主题配置变量会残留为孤儿变量。

- 检查点：`src/App.vue` 内是否存在**定义但未使用**的变量（如迁移后残留的 `antTheme`）。
- 判定：grep 该变量名，若仅出现在定义处、模板/逻辑均未引用 → 孤儿，删除。
- 触发条件：仅当本次开发**动了全局 ConfigProvider/主题配置**时才检查；纯单组件开发通常不涉及。

### ⑭ `components.d.ts` 幽灵声明 ⭐

> 自动生成文件的过时残留，**双重根源**：① 开发期用 `<a-xxx>`（antdv 真身）对照时 unplugin 写入声明；② 该声明随「新增组件」提交被**连带提交进 git（已提交的过时声明）**。unplugin v30 的 d.ts 同步默认**不清理**已不存在的声明（`syncMode` 非 `overwrite` 时保留旧条目），对照清除后声明**不会自动消失**，需手动清理。

- 位置：项目根 `components.d.ts`（`@ts-nocheck` 自动生成文件）。
- 检查点：文件中是否存在代码里**已不再使用**的 antdv 声明（如 `AAutoComplete`/`AButton` 等指向 `ant-design-vue/es` 的条目）。
- 清理判定：`grep -rEn "<a-xxx|AButton|AAutoComplete" src/ components/ docs/`（大小写两种形态都要查），0 匹配 → 该声明是幽灵，删除该行。
- **保留**实际仍在使用的（如 `GlobalLayout.vue` 用了 `<a-menu>` → `AMenu`/`AMenuItem` 保留）。
- **持久化红线（⭐ 关键）**：幽灵声明已提交进 git，手动删除后 `git checkout components.d.ts` 或 dev 重新生成**都可能恢复它**；必须**删除 + 随本次组件开发的 commit 一起提交**（阶段 5 收尾同步处理），否则清理不持久、下次即「复活」。
- 兜底：`pnpm dev` 重启后 unplugin 会重写该文件，但**不能依赖**它自动清理（默认不删除旧声明）——验收阶段必须显式 grep 确认，且确认后的删除要纳入本次 commit。

---

## 遗漏根因（复盘结论）

> 事故暴露的共同根因：新增组件的联动点分散在 10+ 个文件，且**无集中清单**。人（AI）靠记忆逐处更新，必然漏。

| 原则 | 说明 |
|:--|:--|
| **清单驱动，不靠记忆** | 阶段 1 起即以本 map 为唯一权威源逐项勾销，禁止「顺手补几处」 |
| **易遗漏点显式标注** | ⭐ 项是历史事故点，Gate 报告必须逐项回显确认 |
| **自动化自检兜底** | 确定性 grep 自检（§④⑩⑪⑫⑭ 的 A3/A4/B4/E1/C1）已收拢于 `scripts/validate-component.sh`——Gate 5 前置必跑，下方各节 grep 命令保留为脚本实现依据与失败诊断用；AI 输出「已完成」前必须实测 |

> 本清单随每次新增组件实践持续补全——若再次出现新遗漏，第一时间回填本 map 并复盘。
