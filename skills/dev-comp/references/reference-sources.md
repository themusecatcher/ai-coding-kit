# 参考源与 antdv/naive 取舍规则

> dev-comp 阶段 0/2 加载。定义参考源位置与"对齐谁"的决策规则。
> 术语：**antd = Ant Design Vue**（官网 https://www.antdv.com/ ），非 React 版 ant.design；本文档中 antdv 与 antd 同义。

## 参考源位置（见 SKILL.md 个人化配置区）

| 源 | GitHub | 本地 clone | 官网 |
|:--|:--|:--|:--|
| Ant Design Vue | `REF_ANTDV_GH` | `REF_ANTDV_LOCAL` | `REF_ANTDV_DOC` |
| Naive UI | `REF_NAIVE_GH` | `REF_NAIVE_LOCAL` | `REF_NAIVE_DOC` |

**使用优先级**：本地 clone 源码（读实现细节、可复用算法）> 官网文档（对齐 API/交互/示例）。
本地 clone 不存在 → 降级用 `web_fetch` 读官网，并提示用户可clone 获得源码级复用。

## 对齐谁？（主参考源决策）

| 场景 | 主参考 | 理由 |
|:--|:--|:--|
| 项目已有该组件的雏形且用了某库 API风格 | **跟随雏形** | 保持一致，最小改动（如 Menu 雏形用 antdv `items` 风格 → 对齐 antdv） |
| 全新组件，antdv 有对应组件 | **antdv 优先** | 项目整体更贴近 antdv 生态（依赖含 ant-design-vue、@ant-design/icons-vue） |
| antdv 无但 naive 有 | naive | — |
| 两库都有且差异大 | 询问用户 | 让用户定API 风格，不擅自决定 |

## 实现方式复用优先级

> 开发组件时，**功能/样式/布局/逻辑**四个层面的实现（算法思路/结构组织/动画方案/主题处理/交互细节/样式布局）按以下优先级逐级查找复用，**禁止跳过上级直接自研**：

| 优先级 | 来源 | 查找方式 | 说明 |
|:--:|:--|:--|:--|
| 1 | 项目已有组件/功能/样式/逻辑 | 读 `references/reusable-assets.md` + 搜索 `components/` 下同类型组件 | 复用项目资产（组件/动画/浮层/主题/utils/既有样式布局），保持项目风格统一，**禁止重复开发** |
| 2 | antdv 源码实现 | 读 `{REF_ANTDV_LOCAL}/components/{组件名}/src/` | 算法思路改写为项目风格（Vue3 setup + less），禁整段拷贝 |
| 3 | naive 源码实现 | 读 `{REF_NAIVE_LOCAL}/src/{组件名}/` | antdv 无对应实现或实现不适配时参考 |
| 4 | 自研 | — | 前三级均无可复用实现时才允许 |

> 典型场景（autoComplete 下拉等）：滚动条、暂无数据、清除按钮、下拉列表等能力，**先在项目 `components/` 中检索**（如 Scrollbar/Empty/输入框清除按钮等既有实现），有则直接复用组件或抽取其逻辑；无则按 2→3→4 级参考实现，**不重新开发全新组件/样式/逻辑**。
> 与「对齐谁」的关系：对齐谁 = API 风格跟随谁；复用优先级 = 实现参考谁。二者独立——API 对齐 antdv 但实现可复用 naive 的某段算法（在代码注释注明来源）。

## naive 差异登记

> 主参考为 antdv 时，naive 的独有特性可能成为验收盲区。规则：**知道差异、显式决策，不要求对齐**。

1. 阶段 2 若 naive 也有该组件：浏览 naive 官网该组件页，识别「naive 有而 antdv 无」的属性/插槽/事件/交互
2. 差异写入工作上下文「naive 差异登记」区，逐项给出决策：
   - **对齐**：naive 实现更好/更常用，额外实现该项
   - **不覆盖**：超出本项目组件职责，附理由
   - **待用户确认**：Gate 5 汇总呈现，用户一次性决策
3. 主参考为 naive 时（antdv 无对应组件），本条反向适用（登记 antdv 独有特性）

## API 风格

- antdv 组件多为**配置式（items 数组）+ 组件式（插槽）双模式**，本项目倾向对齐这种双模式
- 大组件可分阶段：先配置式（P1），再组件式插槽（P2）

## 源码定位技巧

- antdv 组件源码：`{REF_ANTDV_LOCAL}/components/{组件名}/`（含 `index.en-US.md` 是权威 API 文档）
- naive 组件源码：`{REF_NAIVE_LOCAL}/src/{组件名}/`
- 找API 定义、Props 类型、事件回调参数结构时，直接读源码的 types 文件最准

## Demo 源码定位

> **对齐范围必须包含 demo**：demo 定义了「用户如何感知和使用」这个组件，是演示页/文档用例的对齐基准。

- antdv demo：`{REF_ANTDV_LOCAL}/components/{组件名}/demo/`（每个 `.vue` 文件一个用例）
- naive demo：`{REF_NAIVE_LOCAL}/src/{组件名}/demos/`（enUS/zhCN 各一份）
- antdv 文档页（成品效果）：antdv 官网 `https://www.antdv.com/components/{组件名}-cn/`
- 对齐方式：先读 demo 源码理解数据和交互方式，再浏览器打开官网对照成品效果
- **演示页必须完整复制官网全部展示用例**：每个官网用例对应一个分区（顺序与官网一致），分区内含 ①本项目组件（左/上）+ ②antd 官网组件（右/下，原样复制），不得遗漏（详见 `flow.md` 阶段 3）

## 注意

- 参考库版本：antdv `^4.2.6`、naive `^2.44.0`（devDependencies），对齐时以此版本为准；依赖升级后以项目 `package.json` devDependencies 实际安装版本为准（本处快照可能过时）
- License：复用算法思路可以，禁止整段拷贝带版权声明的代码；改写为项目风格
