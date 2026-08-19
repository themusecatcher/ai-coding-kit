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
- [ ] **⭐ `components/utils/resolver.ts` `componentsMap`**：组件名 → 样式目录映射（按字母序插入，详见 `linkage-map.md` §④）
- [ ] **⭐ `components/utils/resolver.ts` `componentDependencies`**：列出组件 `.vue` 内 `import ... from 'components/xxx'` 的实际组件依赖（grep 源文件判定，无依赖则跳过，详见 `linkage-map.md` §④）

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
- [ ] antd 真身引入方式已确认（已配 `AntDesignVueResolver` → 直接用 `<a-xxx>` 标签免 import；未配 → 显式 `import ... from 'ant-design-vue'`，详见 `flow.md` 阶段 3）
- [ ] 两组件行为/视觉 1:1 一致
- [ ] **简介描述遵循 `references/demo-description.md`**：权威源=演示页、标题纯场景名、仅信息增量时添加、代码标记原生 `<code>`（引用组件前 `search_file` 确认存在）、docs 要 `<br/>` 而演示页 `<p>` 自带间距无需 `<br/>`、段落数两处一致
- [ ] **改动即同步（禁止单边）**：改演示页描述后立即 `grep` 同步 docs 对应描述（文本逐字一致，仅 `<code>` ↔ 反引号转换）
- [ ] 额外覆盖：禁用态、空数据、极值、主题切换（官网没有的项目特有场景）

## 周边文档（阶段 4）

- [ ] `docs/guide/components/{组件名}.md`（复用演示页 script+template，加 API 表格）
- [ ] **API 章节标题四件套**：`## APIs`（Props 表 + 类型定义）/ `## Events` / `## Slots` / `## Methods`（对外暴露方法），禁止 `## Expose` 等内部术语直接作标题（先 grep ≥2 个同类组件文档确认实际命名再落笔）
- [ ] docs 已剔除「antd 官网组件」分区与 `ant-design-vue` 真身 import（对照只在演示页）
- [ ] vitepress 侧边栏配置 `docs/.vitepress/config.ts` 新增组件入口
- [ ] `docs/guide/changelog.md` 新增变更记录（**按 `references/changelog-spec.md`**：新增组件 → minor+1 patch 归 0；非新增 → patch+1；`package.json` version 与 changelog 双处一致；条目格式 + 插顶部）
- [ ] `README.md` + `README.zh-CN.md` 组件清单更新（中英双份）
- [ ] `docs/index.md`（若有组件清单）
- [ ] **⭐ 组件总数数字 +1（4 处）**：`docs/guide/features.md` §简要介绍 / `docs/index.md` hero `details` / `README.zh-CN.md` §特性 / `README.md` §Features，逐一 +1（详见 `linkage-map.md` §⑩⑪⑫，含 grep 自检命令）

## 发布前配置项终检（阶段 5 · 配置项类检查唯一权威源）

> 新增组件的全部固定配置项集中于此，阶段 5 验收时**逐项勾销 + grep 自检实测**，禁止靠记忆。
> ⚠️ **埋入阶段检查不能替代终检**：阶段 1/4 埋入时检查过 ≠ 发布前仍正确（埋入后文件可能再被改动），收尾必须全量回检。
> 详细判定规则 → `linkage-map.md` 对应小节；类别 D「质量验证」（lint/type-check/浏览器实测）并入下方 §验收。

### A · 代码注册链路（埋入于阶段 1）

- [ ] A1 `components/{组件名}/index.ts`：`withInstall` + 类型导出
- [ ] A2 `components/components.ts`：`export type { Props as XxxProps }` + `export { default as Xxx }` 两条都在
- [ ] A3 ⭐ resolver `componentsMap` 按需样式映射（`grep -n "{组件名}:" components/utils/resolver.ts` 命中且按字母序，详见 `linkage-map.md` §④）
- [ ] A4 ⭐ resolver `componentDependencies` 样式依赖（`grep -rn "import .* from 'components/" components/{组件名}/` 逐一与映射条目对上，无依赖则确认跳过，详见 `linkage-map.md` §④）
- [ ] A5 自动注册确认：`git diff` 中无 `components/index.ts` / `src/router/index.ts` 手改痕迹（glob 自动扫描，无需手改）

### B · 文档联动链路（埋入于阶段 4）

- [ ] B1 `docs/guide/components/{组件名}.md` 存在且复用演示页（script+template 同源）
- [ ] B2 vitepress 侧边栏入口（`grep -n "{组件名}" docs/.vitepress/config.ts` 命中）
- [ ] B3 `docs/guide/changelog.md` 变更记录（`grep -n "{组件名}" docs/guide/changelog.md` 命中）+ **版本号规则校验**（`references/changelog-spec.md` §4：新增组件 → minor+1 patch 归 0；`jq -r .version package.json` 与 changelog 顶部版本号逐字一致）
- [ ] B4 ⭐ 组件总数 +1（4 处）：`docs/guide/features.md` §简要介绍 / `docs/index.md` hero `details` / `README.zh-CN.md` §特性 / `README.md` §Features 逐一 +1（详见 `linkage-map.md` §⑩⑪⑫）
- [ ] B5 **API 章节标题四件套**：`grep -nE "^## " docs/guide/components/{组件名}.md` 确认 `## APIs` / `## Events` / `## Slots` / `## Methods` 齐全且命名正确，无 `## Expose` 等内部术语直接作标题

### C · 残留清理（阶段 5 执行）

- [ ] C1 ⭐ `components.d.ts` 幽灵声明清理：`grep -rEn "<a-xxx|AButton|AAutoComplete" src/ components/ docs/` 0 匹配的 antdv 声明已删除，**删除随本次 commit 一起提交**（详见 `linkage-map.md` §⑭；⚠️ 不依赖 unplugin 自动清理）
- [ ] C2 ⭐ `src/App.vue` 孤儿变量清理（仅本次动了全局 ConfigProvider/主题时）：grep 确认无「定义未使用」的残留变量（详见 `linkage-map.md` §⑬）
- [ ] C3 演示页对照清除：`git diff src/views/{组件名}/Index.vue` 仅剩本库用例（antdv 真身/对应数据/`ant-design-vue` import/antdv 专属图标已删）
- [ ] C4 调试代码清理（console.log、临时样式）

### E · 一致性校验（阶段 5 执行）

- [ ] E1 组件总数 4 处数字一致：`grep -rEn "共包含|includes.*components|个基础" README.md README.zh-CN.md docs/index.md docs/guide/features.md`，4 处数字一致且 = 实际组件数（`ls -d components/*/ | grep -v -E 'components/(style|utils)/' | wc -l`）
- [ ] E2 演示页 ↔ docs 简介描述同源：按 `references/demo-description.md` §5 用 grep 双向对比——文本逐字一致、段落数一致、`.vue` 用 `<code>` 而 `.md` 用反引号、`.md` 有 `<br/>` 而 `.vue` 无

## 验收（阶段 5）

> 配置项类检查（注册/文档/残留/一致性）已独立为上方「发布前配置项终检」章节，本节只保留质量验证与基线勾销。

- [ ] `pnpm lint:check` EXIT 0
- [ ] `pnpm type-check` 无本组件错误
- [ ] **浏览器实测**：`pnpm dev` 与真身 1:1 对照，覆盖多实例/边界/交互/主题切换
- [ ] 控制台 0 error / 0 warning
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
