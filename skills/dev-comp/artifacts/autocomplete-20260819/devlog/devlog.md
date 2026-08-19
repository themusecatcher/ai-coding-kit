# 新增 AutoComplete 自动完成组件

> **项目**：vue-amazing-ui
> **类型**：feat
> **状态**：✅ 主体已提交；清除对照改动待提交（2026-08-19 复核）
> **日期**：2026-08-14 ~ 2026-08-19
> **分支**：`feat/auto-complete`
> **Commit**：`3491d54b feat: 新增自动完成组件`（12 files, +2219/-307）+ 待提交清除对照改动（12 files, +74/-406）

---

## 相关文档

| 文档名 | 链接 |
|--------|------|
| Ant Design Vue AutoComplete 官网（参考源） | https://www.antdv.com/components/auto-complete-cn |
| antdv 本地源码 | `~/myGithub/ant-design-vue/components/auto-complete/` |
| 组件文档 | `docs/guide/components/autocomplete.md` |
| 演示页 | `src/views/autoComplete/Index.vue` |

## What（做了什么）

新增 `AutoComplete` 自动完成组件：输入框自动完成功能，支持远程搜索、自定义选项插槽、自定义输入组件、分组数据源、字符串数组数据源、键盘导航回填、清除按钮、三种尺寸、error/warning 校验状态、无边框、禁用/禁用选项、受控/默认展开、自定义下拉面板宽度等能力，API 与 Ant Design Vue 对齐。同步交付演示页（21 用例含 antdv 真身 1:1 对照）、组件文档、周边文档联动（侧边栏/changelog/README/版本号）。

## Why（为什么做）

组件库（vue-amazing-ui）缺少自动完成类输入组件。用户需要"带提示的输入框，可自由输入，关键词辅助输入"的场景（区别于 Select 的选择场景）。参考源为 Ant Design Vue 4.2.6（API 对齐）与 Naive UI（部分惯例如 `to` 属性）。

## How（怎么做的）

### 技术方案

1. **组件架构**：单文件组件 `components/autocomplete/AutoComplete.vue` + 类型导出。API 四维（Props 21 项 / Events 9 项 / Slots 3 项 / Expose 2 项）对齐 antdv 4.2.6 官方文档
2. **数据源统一**：`options` 支持 `(string|number|Option|GroupOption)[]`，内部归一化为 Option 列表（`flattenOptions`），分组通过 `{label, options}` 结构识别（与 antdv 一致）
3. **面板定位**：Teleport 到 `to`（默认 body），垂直翻转（bottom/top）+ 水平三态对齐（left/right/viewport-left）+ 自定义面板宽度（`dropdownMatchSelectWidth`）
4. **键盘交互**：↑↓ 环形循环导航（跳过 disabled）+ backfill 回填 + Enter 选中 + Esc 还原（`lastUserValue`）
5. **清除按钮**：有值即显示（computed），与项目 `Input` 组件惯例一致
6. **注册链路**：`components.ts` 补导出类型 + `components.d.ts` 自动生成

### Round 1：主体开发 + 演示页 + 文档（2026-08-14 ~ 2026-08-18）

#### 涉及文件

| 文件 | 操作 | 改动说明 |
|------|------|---------|
| `components/autocomplete/AutoComplete.vue` | 新增 | 组件本体全量能力 |
| `components/autocomplete/index.ts` | 新增 | 组件入口与类型导出 |
| `src/views/autoComplete/Index.vue` | 新增 | 演示页 19 分区（21 本库用例 + 21 antdv 真身对照） |
| `src/views/autoComplete/index.ts` | 新增 | 演示页路由配置 |
| `src/App.vue` | 修改 | 导航菜单注册 |
| `components/components.ts` | 修改 | 补导出 `AutoCompleteOption`/`AutoCompleteGroupOption` |
| `components.d.ts` | 修改 | 类型声明自动生成 |
| `docs/guide/components/autocomplete.md` | 新增 | 组件文档（19 用例 + API 表格） |
| `docs/.vitepress/config.ts` | 修改 | 侧边栏入口 |
| `docs/guide/changelog.md` | 修改 | 2.5.0 条目 |
| `package.json` | 修改 | 版本 2.5.0 |
| `README.md` / `README.zh-CN.md` | 修改 | 组件清单（字母序重排） |

### Round 2：验证反馈修复（2026-08-17 ~ 2026-08-18）

#### 涉及文件

| 文件 | 操作 | 改动说明 |
|------|------|---------|
| `components/autocomplete/AutoComplete.vue` | 修改 | 面板水平右对齐/贴视口左三态定位、清除按钮有值即显示、自定义清除图标 flex 居中、status 边框色对齐 4.2.6 实测值、键盘导航环形循环 |

### Round 3：验收收尾（2026-08-19）

流程复核补齐阶段 5 收尾缺口（清除演示页对照 + 修正遗漏，待提交）：

#### 涉及文件

| 文件 | 操作 | 改动说明 |
|------|------|---------|
| `src/views/autoComplete/Index.vue` | 修改 | 清除全部 antd 真身对照（-380 行：`a-auto-complete` 组件 + `avalue*`/`aoptions*` 数据 + `ant-design-vue` import） |
| `src/App.vue` | 修改 | 删除 antdv ConfigProvider `antTheme` 配置 |
| `components.d.ts` | 修改 | antdv 组件声明随使用删除自动消失 |
| `components/utils/resolver.ts` | 修改 | 补 `AutoComplete: ['Scrollbar']` 依赖声明（按需引入缺依赖修复） |
| `README.md` / `README.zh-CN.md` / `docs/guide/features.md` / `docs/index.md` | 修改 | 组件数 67→68 |
| `docs/guide/components/autocomplete.md` | 修改 | 用例标题精简、受控展开用例 Space 布局、Expose→Methods |
| `docs/guide/components/image.md` | 修改 | 修复 `<Image loop` 标签断行导致的 Invalid end tag（Issues#9 遗留问题） |

#### 验证

- ESLint `lint:check` exit 0；`vue-tsc --build --force` exit 0
- 浏览器实测：19 分区全部渲染、默认展开面板正常、控制台 0 error / 0 warning

### 上下游影响

- 上游：使用组件库的业务方
- 下游：无（独立组件，仅依赖库内 `useOptionsSupported`/`useInject` 等既有资产）

## Issues（遇到的问题）

1. **面板水平定位缺失**：原实现仅垂直翻转，水平恒左对齐，宽面板靠右时溢出视口。补 `panelAlign` 三态 + `getAlign` 遮挡检测
2. **viewport-left 判定缺陷**：初版用「面板宽>视口宽」判定，视口>面板宽但输入框靠右时仍左对齐溢出。改为实际遮挡检测（左对齐溢出→试右对齐→都溢出→贴视口左）
3. **清除按钮 hover 依赖**：`showClear` 仅 mouseenter 置 true，点击聚焦+输入路径不显示。改 computed 有值即显示
4. **status 边框色 3 轮迭代**：antdv 4.2.6 `generateColorPalettes` 返回**键从 1 开始的对象**（8/9/10 复用 4/5/6 号色），按数组索引推演全部错位。最终以源码函数实测：error 三态 `#ff7875` + 阴影 `rgba(255,38,5,0.06)`；warning 三态 `#ffd666` + 阴影 `rgba(255,215,5,0.1)`
5. **键盘导航完全缺失**：模板无 keydown 处理，backfill 仅悬浮回填。补 `onKeydown` + `lastUserValue`
6. **键盘循环边界**：到边界后无响应，改环形查找
7. **分组选项无缩进**：组内选项 padding 与标题一致，补 `option-grouped` 24px 缩进（对齐 antdv `controlPaddingHorizontal*2`）
8. **文档环境加载旧产物**：vitepress 从 dist 加载，`Failed to resolve component`，重新 `build:dist` 解决
9. **`docs:build` 全量构建失败**：`docs/guide/components/image.md` L89 Invalid end tag，为仓库既有问题（该文件无未提交改动），本次未动。**Round 3 已修复**：根因是 `<Image ... loop` 后换行断开了闭合标签，重新合行解决

## Result（结果）

- [x] 编译通过（`build:dist` 成功）
- [x] 类型检查通过（`vue-tsc --build --force` exit 0）
- [x] ESLint 通过（改动文件全量检查 0 error）
- [x] 自测验证通过（浏览器实测：分组缩进 24/12px、键盘循环回填、清除按钮有值即显示、文档页 21 实例渲染）
- [x] 对齐验收通过（API 四维 18 Props+7 Events+3 Slots+2 Expose 全量勾销、9 个 antdv demo 用例全覆盖）

---

> 由 CodeBuddy dev-flow 自动生成
