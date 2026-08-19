---
component: autoComplete
mode: component-dev
phase: P1
phases_total: 1
status: completed
branch: feat/auto-complete
ref_primary: antdv
api_style: "v-model:value（antdv 风格，雏形已用）"
start_date: "2026-08-14"
artifacts:
  component: components/autocomplete/
  demo: src/views/autoComplete/Index.vue
  doc: docs/guide/components/autocomplete.md
  devlog: ~/.codebuddy/dev-logs/20260818_feat_自动完成组件/devlog.md
  knowledge:
    - ~/.codebuddy/knowledge/vue-amazing-ui/autocomplete/
---

# autoComplete 开发上下文

## 目标 & 参考
- 对齐目标：antdv AutoComplete API（**已全量对齐官网**）— Props: allowClear/autofocus/backfill/bordered/defaultActiveFirstOption/defaultOpen/disabled/open/placeholder/popupClassName/dropdownMatchSelectWidth/dropdownMenuStyle/options/v-model:value/size/status/to；Events: search/select/change/focus/blur/clear/dropdownVisibleChange(+openChange 兼容)；Slots: #option/#default/#clearIcon；Expose: focus()/blur()
- 参考源：antdv 官网 https://www.antdv.com/components/auto-complete-cn/
- 本地源码：~/myGithub/ant-design-vue/components/auto-complete/（antdv ^4.2.6）

## 阶段规划（大组件分 P1-Pn）
| 阶段 | 范围 | 状态 |
|:--|:--|:--|
| P1 | 组件本体（输入+面板+search/select 等核心能力） | ✅ 完成 |
| P2 | 增强能力（#option/#default/#clearIcon 插槽 + status/bordered + 分组渲染） | ✅ 完成 |
| P3 | 演示页（antdv 9 demo 全对齐 + 4 补充用例，共 13 用例） | ✅ 完成 |
| P4 | 文档（autocomplete.md + 侧边栏 + changelog + README×2） | ✅ 完成 |
| P5 | 验收（lint/type-check/浏览器实测/devlog/commit） | ✅ 完成 |
| P5.5 | 清除演示页 antd 对照 + 修正遗漏（未提交，待 commit） | ✅ 完成（2026-08-19 复核） |

## 可复用项目资产（先搜索后编码）
| 需求 | 项目已有 | 位置 |
|:--|:--|:--|
| 面板定位/flip/滚动父元素监听 | Select 内联实现（无公共工具，参考模式重写） | `components/select/Select.vue` |
| 主题注入 | useInject | `components/utils/index.ts` L752 |
| 空态展示 | Empty 组件 | `components/empty` |
| 滚动条 | Scrollbar | `components/scrollbar` |
| 事件监听 | useEventListener/useMutationObserver | `components/utils/index.ts` |

## 进度 & 接续指引
- P1+P2+P3 已完成：组件本体全量能力 + 演示页 19 分区（全部分区含 antd 真身双组件对照）
- P4 已完成：组件文档 + 周边文档联动（侧边栏/changelog 2.5.0/README×2/package.json/components.ts 补导出）
- P5 已完成：type-check/ESLint 通过 + 基线清单勾销（API 四维 + 9 个 antdv demo 用例全对齐）+ 浏览器实测（分组缩进/键盘循环/清除按钮）+ devlog/metrics/knowledge 沉淀
- commit：3491d54b `feat: 新增自动完成组件`（12 files, +2219/-307）
- 状态：✅ 主体已提交；另有「清除演示页 antd 对照 + 修正遗漏 + 版本号 2.5.0 修正」12 文件改动在工作区待提交（2026-08-19 复核确认）
- 遗留：docs:build 全量构建在 image.md L89 失败——已在待提交改动中修复（`<Image loop` 标签断行导致的 Invalid end tag）；filterOption 默认 false（antdv 为 true）待用户裁决
- 下一步（next_action）：生成待提交改动的 commit message → 用户确认后提交 → 等待合入 main
- 验证红线：浏览器验证用 snapshot/evaluate，**禁止截图**（本模型无图像能力）；阶段收尾清理产物并反向验证；报告可详细，交付物必须简洁
- 待确认：API 风格已定 v-model:value
- ⚠️ 失效引用已清理：`.codebuddy/autocomplete-improvement-plan.md` 已不存在（此前误记，2026-08-17 复核确认）

## 决策记录
- [2026-08-14] 接续开发；主参考 antdv；雏形演示页已用 v-model:value + search/select 事件
- [2026-08-14] 分阶段 P1/P2：按功能能力切分（后复盘为错误维度，已改为按 demo 群组对齐，见改进方案文档）
- [2026-08-14] P2 补齐全部能力：演示页 13 用例全为真用例，无占位
- [2026-08-14] 34 张验证截图已全部清理；新对话验证规范：snapshot/evaluate 替代截图
- [2026-08-17] 复核阶段 2/3：组件本体质量达标；**阶段 3 演示页原仅 2/13 分区有 antd 对照，本次回退补齐全部 15 分区双组件对照**（本项目左/antd 右），lint+type-check 通过，浏览器实测远程搜索/下拉面板正常（控制台 0 error）
- [2026-08-17] 组件本体 API 全量对齐 antdv 官网：补齐 10 项缺口 —— P0: focus()/blur() Expose + dropdownVisibleChange 事件(与 openChange 并存) + filterOption 默认值 false→true；P1: autofocus/backfill/open(受控)/defaultOpen/defaultActiveFirstOption；P2: popupClassName/dropdownMatchSelectWidth/dropdownMenuStyle。lint+type-check 通过，浏览器实测 filterOption 默认 true 不破坏远程搜索用例、本地过滤生效、defaultActiveFirstOption 高亮首项均正常（0 error）
- [2026-08-17] 演示页追加 5 个新 API 对照用例（共 19 分区）：backfill / 受控 open / defaultOpen / 关闭 defaultActiveFirstOption / dropdownMatchSelectWidth=300。浏览器实测 defaultOpen 默认展开、dropdownMatchSelectWidth 面板宽 300px 均生效；2 个 console warning 均来自 antd 真身(非本项目组件)
- [2026-08-17] 修复 bug：空选项聚焦时错误弹出「暂无数据」空态面板（与官网不一致）。根因：沿用 Select 空态模式，但 antd AutoComplete(combobox 模式)无选项时 notFoundContent=null 且面板不显示。修复：面板显隐条件 `showOptions`→`showOptions && flattenOptions.length`，移除 options-empty 空态块 + Empty import + 孤儿样式。实测空选项聚焦不弹面板、有选项正常显示，lint+type-check 通过
- [2026-08-17] 修复 2 个 bug：①width 不生效——`.auto-complete-content` 缺 `width:100%`，外部 style width 只作用根元素未传递到内层，补 width:100%（保留 min-width:120px 兜底），实测 content 宽度=200px；②选中后再聚焦选项被误过滤——**根因是上一轮误将 filterOption 默认值改为 true**（antd 源码 auto-complete/index.tsx L35 实为 default:false，官网 API 文档写 true 有误，以源码为准），改回 false。实测输入123→选中123123→再聚焦仍显示全部[123,123123,123123123]，且显式传 filterOption 函数的「不区分大小写」用例过滤正常。lint+type-check 通过
- [2026-08-17] 修复 bug：hover 高亮在面板关闭后未重置，重开时停留在旧 hover 项而非选中项。根因：hoverValue 只在 flattenOptions 变化时由 watchEffect 重置，面板关闭不重置。修复：抽 `resetHoverValue()`(优先定位当前选中值对应选项→否则 defaultActiveFirstOption 逻辑)，`watch(showOptions)` 打开/关闭均调用(关闭时重置确保下次打开正确+兜底面板未真正关闭场景)。**真实 playwright 交互**验证完整场景(选中123123→hover123→点别处关闭→重开)高亮=123123 pass。lint+type-check 通过
- [2026-08-17] 修复 bug：中文输入法(IME)合成期就触发筛选，与官网不一致(官网合成完成才筛选)。根因：onInput 直接响应原生 input 未处理 IME；且本地 filterOption 筛选(filteredData computed)直接依赖 props.value，合成期为回显更新 value 就触发了筛选。修复：①新增 isComposing ref + compositionstart/compositionend 事件(input 与 custom-input 容器均绑定)，合成期 onInput 仅回显不 emit search，合成结束统一触发；②filteredData 增加 `|| isComposing.value` 判断，合成期返回全部不本地筛选。实测：合成中输入拼音w显示全部3项、合成结束上屏w筛选出含w项、英文直接输入b即时筛选均正常。lint+type-check 通过
- [2026-08-17] 修复 bug：自定义输入组件模式(如查询模式内嵌 InputSearch)聚焦时，外层 focus 阴影覆盖了整个组件含搜索按钮。根因：`.auto-complete-custom` 已把 content 的 border/bg 重置交给内部组件渲染，但 `.auto-complete-focused .auto-complete-content` 的 box-shadow 仍叠加在包裹了整个 InputSearch 的 content 上。修复：`.auto-complete-custom` 下 hover/focused 时 content 的 border-color:transparent + box-shadow:none，聚焦阴影交由内部 InputSearch(自身 :focus-within 已正确处理，按钮区不带阴影)渲染。实测聚焦时外层 content boxShadow=none，阴影只在输入框范围。lint+type-check 通过
- [2026-08-17] 修复 bug：输入无匹配选项导致面板隐藏时无 leave 动画过渡。根因：面板 `v-show="showOptions && flattenOptions.length"`，无匹配时选项 v-for 内容同 tick 清空→面板高度塌缩→打断 leave 动画。修复：①抽 `panelVisible` computed 驱动 v-show；②新增保留态 `displayData` ref + watch(filteredData)(有值即同步、变空时保留上次内容)，模板 v-for 改用 displayData，使隐藏动画期间内容不清空、高度不塌缩。实测 opacity 从~1 平滑渐变至隐藏(slideOut 动画完整~200ms)，且重新输入正常显示新筛选内容。lint+type-check 通过

- [2026-08-18] 补齐下拉面板水平右对齐：右侧空间不足时右对齐（panelAlign left/right + panelWidth + getAlign）。根因：原实现仅垂直翻转，水平恒左对齐（left: offsetLeft），宽面板靠右时会溢出视口。修复：getPosition 读面板 offsetWidth，getAlign 计算右侧空间，panelPlacement 按对齐方向输出 right/left + transformOrigin 锚点跟随。浏览器实测右对齐/左对齐回归均通过
- [2026-08-18] 扩展对齐第三态 viewport-left：面板宽度超过视口（左右都放不下）时贴视口左边缘（left: -containerLeft）。实测 250px 视口 + 300px 面板贴左、左不溢出
- [2026-08-18] 修复对齐判定缺陷：原 viewport-left 条件「width > viewportWidth」过于严格，视口>面板宽但输入框靠右时左对齐溢出右侧仍走左对齐。改为**实际遮挡检测**：左对齐溢出右侧→试右对齐→右对齐也溢出左侧→viewport-left。三场景（左对齐溢出切右/左右都溢出贴左/空间充足左对齐）实测通过
- [2026-08-18] 修复清除按钮输入后不显示：showClear ref 仅 onEnter(mouseenter) 置 true，点击聚焦+输入路径不触发。改为 computed（allowClear && !disabled && 有值），与项目 Input 组件「有值即显示」一致；onEnter/onLeave 仅保留 disabledBlur 管理。实测有值即显示
- [2026-08-18] 修复自定义清除图标偏大偏上：.clear-svg 用 inline-block + margin:auto 0 居中，插槽结构（span 包 svg）下失效且尺寸未约束。改 inline-flex + align-items/justify-content:center + 固定 12px + :deep(svg) 约束 1em。实测默认/自定义图标一致居中
- [2026-08-18] 修复 status 边框色（3 轮迭代，以 antdv 4.2.6 源码为准）：①误对齐 5.x（#ffa39e/#ffd666 hover）→改回 4.2.6（#ff7875/#ffc53d）；②用户验证默认态边框应为 #ff7875/#ffd666——根因：antdv 4.2.6 generateColorPalettes 返回**键从 1 开始的对象**（8/9/10 复用 4/5/6 号色），此前按数组索引推演全部错位。AutoComplete 复用 Select 样式，status 三态边框同色（borderHoverColor=colorErrorHover/colorWarningHover）。最终：error 三态 #ff7875 + focus 阴影 rgba(255,38,5,0.06)；warning 三态 #ffd666 + 阴影 rgba(255,215,5,0.1)（getAlphaColor 实测计算）
- [2026-08-18] 修复分组数据源选项无缩进：分组标题与组内选项 padding 一致（5px 12px）。对齐 antdv 4.2.6（grouped paddingInlineStart = controlPaddingHorizontal*2=24px）：模板加 option-grouped class + CSS padding-left:24px
- [2026-08-18] 补齐键盘导航 backfill：原模板无任何键盘事件处理。新增 onKeydown（input 与 custom-input 容器均绑定）+ lastUserValue ref（onInput/onCompositionEnd/onSelectOption/onClear 同步）：↑↓ 移动 hoverValue（跳过 disabled），backfill 时回填；Enter 确认选中；Esc 还原 lastUserValue 并关面板。实测 ↑↓/Enter/Esc 全链路通过
- [2026-08-18] 键盘导航循环移动：边界（最后一项按↓/第一项按↑）无响应。改环形查找（direction*step+len)%len），仅一项可用或全禁用时保持不动。实测循环通过
- [2026-08-18] 阶段 4 文档完成：docs/guide/components/autocomplete.md（19 用例剔除 antd 对照 + 何时使用 + APIs Props/Option/GroupOption/Events/Slots/Expose）+ 侧边栏（Alert 与 Avatar 之间）+ changelog 2.5.0 + package.json 2.5.0 + README×2 组件清单整表重排（字母序）+ components.ts 补导出 AutoCompleteOption/AutoCompleteGroupOption（对齐 SelectOption 惯例）。dist 重新构建后 vitepress 页面实测：19 用例 21 组件实例全渲染、远程搜索交互正常、0 error
- [2026-08-19] 版本号规范修正：初版误升 patch（2.4.28），按 `changelog-spec.md`「新增组件 → minor+1 patch 归 0」规则修正为 **2.5.0**（package.json 与 changelog 双处同步，历史先例 2.3.0/2.4.0）
- [2026-08-19] changelog「future」区清理：删除已完成的「新增 自动完成 AutoComplete 组件」条目（其余 6 项 layout/menu/transfer/tour/comment/dropdown 组件目录不存在，保留）
- [2026-08-19] 流程复核（用户发起深度审查）：发现阶段 5 四处收尾缺口并补齐——① metrics 缺失→补写 `~/.codebuddy/dev-comp/metrics/vaui-autocomplete-20260818.yaml`；② 清除演示页 antd 对照红线动作在 commit 3491d54b 之后才执行且未提交（commit 时演示页仍含 26 处 a-auto-complete）→ 清除已做（Index.vue -380 行），待提交；③ 工作上下文/devlog 状态与实际不符→已更新；④ 清除后未跑验证→代跑 lint exit 0 / vue-tsc exit 0 / 浏览器实测 19 分区全渲染、控制台 0 error/warning。另核实待提交 12 文件全部合理必要（含 resolver.ts 补 AutoComplete→Scrollbar 依赖声明、README 组件数 67→68、image.md 修复 Invalid end tag、package.json/changelog 版本号 2.5.0 规范修正）


## 对齐基线清单（Gate 5 验收基准，2026-08-18 由 antdv 4.2.6 官方 API 文档 + demo 源码生成）

### API 四维对照（antdv 官网 index.zh-CN.md）

**Props（18 + 2 slots）**：
- allowClear ✅ / autofocus ✅ / backfill ✅ / bordered ✅ / clearIcon(slot) ✅ / default(slot) ✅ / defaultActiveFirstOption ✅ / defaultOpen ✅ / disabled ✅ / popupClassName ✅ / dropdownMatchSelectWidth ✅ / dropdownMenuStyle ✅ / filterOption ⚠️ / open ✅ / option(slot) ✅ / options ✅ / placeholder ✅ / status ✅ / v-model:value ✅
- ⚠️ filterOption 默认值：antdv=true，本库=false（本库注释：默认不筛选、全量显示，由 search 事件远程更新 options）。**待用户裁决**：对齐 true 或保持 false
- 本库扩展（antdv 无）：size（'small'|'middle'|'large'，antdv 靠 default 插槽自定义输入框传 size）、openChange 事件（antdv 仅 dropdownVisibleChange）、to（挂载容器，对齐 naive 惯例）

**Events（7）**：blur ✅ / change ✅ / dropdownVisibleChange ✅ / focus ✅ / search ✅ / select ✅ / clear ✅

**Methods/Expose（2）**：blur() ✅ / focus() ✅

**Slots（3）**：option ✅ / clearIcon ✅ / default ✅

### Demo 用例对照（antdv demo 目录 9 个）

- basic ✅（基本使用-远程搜索）
- allow-clear ✅（自定义清除按钮）
- border-less ✅（无边框）
- certain-category ✅（查询模式-确定类目，options 嵌套 options + InputSearch）
- custom ✅（自定义选项 #option）
- non-case-sensitive ✅（不区分大小写 filterOption 函数）
- options ✅（自定义选项 = custom 变体）
- status ✅（自定义状态 error/warning）
- uncertain-category ✅（查询模式-不确定类目）

### 本库演示页额外用例（antdv demo 无，官网文档案例/项目特有）

- 自定义输入组件（Textarea 默认插槽）✅
- 三种尺寸（size 切换，本库扩展）✅
- 禁用 / 禁用选项 ✅
- 字符串数组数据源 ✅
- 分组数据源（分组缩进）✅
- 键盘/悬浮回填 backfill ✅
- 受控展开 open ✅ / 默认展开 defaultOpen ✅ / 关闭默认高亮首项 defaultActiveFirstOption ✅
- 下拉面板宽度 dropdownMatchSelectWidth=300 ✅

### 项目特有需求 / naive 差异登记

- 垂直翻转 + 水平右对齐 + viewport-left 三态定位（超出 antdv：antdv 面板超宽时也溢出）
- 分组数据源：`{label, options}` 结构（与 antdv 一致）
- showClear 有值即显示（项目 Input 组件惯例，antdv 为 hover 显示）
- filterOption 默认 false（远程搜索优化，待裁决）


## 备注

### 参考实现
| 对象 | 位置 | 说明 |
|:--|:--|:--|
| antdv AutoComplete 本体 | ~/myGithub/ant-design-vue/components/auto-complete/index.tsx | Select combobox 模式封装 |
| antdv demo ×10 | ~/myGithub/ant-design-vue/components/auto-complete/demo/ | basic/options/custom/certain-category/uncertain-category/non-case-sensitive/status/border-less/allow-clear |
| 项目 Select 面板定位 | `components/select/Select.vue` | 参考定位/flip/滚动监听逻辑 |

### 关键调用
| 函数/接口 | 签名/路径 | 用途 |
|:--|:--|:--|
