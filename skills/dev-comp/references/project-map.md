# 项目结构地图（vue-amazing-ui）

> dev-comp 执行阶段 1/3/4 时的项目结构权威参考。

## 项目规范权威源索引（必读 · 2026-09-15 新增）

> 项目内已有一组面向贡献者的设计规范（`development/`），是组件实现的**权威源**；dev-comp 只做「引用 + 增量补充」，**禁止另起一套平行规则**。
> ⚠️ 强制：动笔前读下表中与本次阶段相关的文件；dev-comp 的 checklist / 模板与项目规范冲突时**以项目规范为准**，并**立即回填本 skill**（单向断链正是历史欠账的根因，见 `rules/按需-Skill设计-跨文件协作.mdc` §2.1/§2.2）。

| 项目规范文件 | 覆盖内容 | 对应阶段 |
|:--|:--|:--|
| `development/component-design.md` | SFC 三段式 / `export interface Props` + `withDefaults` / **插槽类型 `defineSlots` + `<组件名>Slots`** / `useInject` 主题注入 / `useSlotsExist` / 样式与 CSS 变量 / 复合组件 / 无样式组件登记 | 1-2 |
| `development/import-export.md` | 三层导出模型 / 组件级 `index.ts` 三件套 / 复合组件目录级聚合 / `withInstall` 实现 / resolver 四张表 / **新增组件「三步接线」Checklist** / 新增工具函数 Checklist | 1 |
| `development/demo-doc-guide.md` | `src/views/` 演示页结构（`h1` + `h2.mt30.mb10` + `<Space>`）/ 自动路由机制 / 文档站结构 / 组件文档模板 / 内联 demo 机制 / 侧边栏维护 / **演示与文档必须一致** | 3-4 |
| `development/project-structure.md` | 顶层目录职责 / `components/` 内部结构 / `src/` 演示环境 / `docs/` 文档站 / 命名规范速查 | 1/3/4 |
| `development/build-system.md` | 三产物构建（dist / es / lib）/ 别名与模块解析 / 发布前守卫 | 5（发布） |

**其他关键结构文件（非规范但必知）**：

| 文件 / 目录 | 说明 |
|:--|:--|
| `types/global-components.d.ts` | **手工维护**的自有组件全局类型声明（覆盖全部组件），`tsconfig.app.json` 已 include `types/*.d.ts` → 新增组件**必须登记**（⭐ `linkage-map.md` §⑮，2026-09-15 事故点。⚠️ 漏登记不报错、type-check 仍 PASS） |
| `types/env.d.ts` | 环境变量类型声明 |
| `tests/*.spec.ts` | Vitest 单测（`tests/resolver.spec.ts` 自动校验 resolver 与无样式组件登记完整性；为含分支逻辑的新组件补 `tests/{组件名}.spec.ts` 见 `checklists.md` §F） |
| `docs/guide/template.md` | 组件文档骨架（章节顺序：何时使用 → 基本使用 → APIs → Slots → Methods → Events） |
| `components.d.ts` | unplugin-vue-components **自动生成**（勿手改；验收清理幽灵声明见 `linkage-map.md` §⑭） |
| `components/style/global.less` | 全局默认样式（`--primary-color` 等 CSS 变量） |
| `development/` | 上述贡献者设计规范目录（**项目规范权威源**） |

## 目录命名约定（⚠️ 2026-09-15 实测更新，原表已过时）

三处组件目录命名约定**不统一**，建目录时按各层实际惯例执行：

| 层 | 实际惯例 | 示例 | 说明 |
|:--|:--|:--|:--|
| `components/` | **kebab-case（短横线）** | `auto-complete` / `input-number` / `color-picker` | 单词组件无连字符（`comment` / `badge`） |
| `src/views/` | **camelCase** | `autoComplete` / `inputNumber` / `configProvider` | 首单词小写、后续单词首字母大写 |
| `docs/guide/components/` | **kebab-case（短线）** | `auto-complete.md` | 与 `components/` 层一致 |

- 📌 **历史变更**：2026-08-28（2.6.0「规范化组件目录及文档为短横线命名」）后，`components/` 与 `docs/guide/components/` 已由「全小写连写」（`autocomplete`）**改为 kebab-case**；本表此前一直描述旧形态，于 2026-09-15 实测更正。
- ⚠️ 建目录前必须 `ls` 同层既有同类组件确认实际形态（如开发 AutoComplete 看既有 `auto-complete`），**禁止凭记忆或猜测命名**。
- 校验脚本 `scripts/validate-component.sh` 按归一化名（小写去分隔符）解析三处目录，任何形态均能识别；但目录名仍须符合所在层惯例。
- 联动影响：`components/utils/resolver.ts` 的 `componentsMap` value、changelog 链接（`changelog-spec.md` §3.2）均**以实测目录名为准**。

## 组件结构（三件套 + 注册链路）

```
components/{组件名}/                     # ① 组件本体
  ├─ {Xxx}.vue                           # 单组件（SFC 三段式）
  ├─ index.ts                            # withInstall + 类型导出
  └─ {子组件}/{Sub}.vue + index.ts       # 多子组件时（如 descriptions/descriptions-item）
components/components.ts                 # ← 手动追加导出（注册点 A）
components/utils/resolver.ts             # ← 手动追加样式映射（注册点 B，⭐易遗漏：componentsMap + componentDependencies）
types/global-components.d.ts             # ← 手动登记全局组件声明（注册点 D，⭐易遗漏：2026-09-15 事故点）
components/index.ts                      # 自动 install 循环（无需手改）

src/views/{组件名}/                      # ② 演示用例
  ├─ Index.vue                           # 演示页
  └─ index.ts                            # export default { title: '中文名' }（路由自动注册）
src/router/index.ts                      # import.meta.glob 自动扫描（无需手改）

docs/guide/components/{组件名}.md        # ③ vitepress 文档
docs/.vitepress/config.ts                # ← 手动追加入口（注册点 C）
components.d.ts                          # ← 自动生成；验收清理幽灵声明（⭐易遗漏，见 linkage-map §⑭）
```

## 注册点真实写法（实证）

### 注册点 A：`components/components.ts`
```ts
export type { XxxProps } from './xxx'
export { default as Xxx } from './xxx'
```

### 注册点 D：`types/global-components.d.ts`（⭐ 2026-09-15 新增）
```ts
declare module 'vue' {
  export interface GlobalComponents {
    // 按字母序插入；值 = 自有组件导出名
    Comment: typeof VueAmazingUI.Comment
    ConfigProvider: typeof VueAmazingUI.ConfigProvider
    // 复合子组件 / Provider 同样需要（与 resolver componentsMap 一一对应）
    DescriptionsItem: typeof VueAmazingUI.DescriptionsItem
    MessageProvider: typeof VueAmazingUI.MessageProvider
  }
}
```

### 组件 `index.ts`（单组件，如 tabs）
```ts
import Xxx from './Xxx.vue'
export type { Props, Item } from './Xxx.vue'
import { withInstall } from '../utils/type'
export default withInstall(Xxx)
```

### 组件 `index.ts`（多子组件，如 descriptions 聚合层）
```ts
import Descriptions from './descriptions'
import DescriptionsItem from './descriptions-item'
export type { DescriptionsProps } from './descriptions'
export type { DescriptionsItemProps } from './descriptions-item'
export { Descriptions, DescriptionsItem }
```
子组件层 `descriptions/descriptions/index.ts`：
```ts
import Descriptions from './Descriptions.vue'
export type { Props as DescriptionsProps } from './Descriptions.vue'
import { withInstall } from '../../utils/type'   // 注意层级 ../../
export default withInstall(Descriptions)
```

### 用例 `src/views/{组件名}/index.ts`
```ts
export default { title: '标签页' }   // title 为中文名，用于路由 meta + 侧边栏
```

## 自动化机制（无需手动维护）

| 机制 | 实现 | 含义 |
|:--|:--|:--|
| 全局注册 | `components/index.ts` 遍历 `components` 调 `app.install` | 组件在 `components.ts` 导出即自动全局注册 |
| 路由生成 | `src/router/index.ts` 用 `import.meta.glob('../views/**/index.ts')` | 建 `views/{名}/Index.vue` + `index.ts` 即自动生成路由 |
| 类型产物 | vite-plugin-dts | 构建时自动生成 `es/index.d.ts` |
| 按需引入样式 | `components/utils/resolver.ts` | ⚠️ 非自动：`componentsMap` / `componentDependencies` 必须手动维护 |
| 全局组件类型 | `types/global-components.d.ts` | ⚠️ 非自动：必须手动登记（`components.d.ts` 不承担此职责） |

## 关键脚本（package.json · 2026-09-15 实测）

| 脚本 | 用途 |
|:--|:--|
| `pnpm dev` | 启动演示（vite，端口 9000） |
| `pnpm docs:dev` | 启动文档（vitepress，端口 8000） |
| `pnpm docs:build` | 构建文档站（验证文档内联 demo 可编译，阶段 4/5 建议跑） |
| `pnpm lint:check` | ESLint 检查（不 fix） |
| `pnpm type-check` | vue-tsc 类型检查 |
| `pnpm test` | Vitest 单测（`vitest run`） |
| `pnpm format:check` | Prettier 检查（`src/` + `components/`） |
| `pnpm check` | `lint:check` + `format:check` + `type-check` + `test`（**4 项串行**，非仅前两项） |

## 门禁

- **lint-staged**：commit 时对暂存文件跑 prettier + eslint --fix（`*.{js,ts}` / `*.vue` / `*.{html,css,less}`；⚠️ **md 不在其中**，changelog/docs 改动不会被 lint-staged 兜底）
- **commitlint**：`<type>: <description>`，**scope-empty**（禁止 scope）
- **pre-push**：跑 type-check
