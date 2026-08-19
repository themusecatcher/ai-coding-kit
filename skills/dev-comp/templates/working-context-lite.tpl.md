---
component: {组件名}
mode: component-dev
phase: P1
phases_total: {N}
status: in_progress
branch: ""
release: pending
ref_primary: antdv
api_style: ""
start_date: "{YYYY-MM-DD}"
artifacts:
  component: components/{组件名}/
  demo: src/views/{组件名}/Index.vue
  doc: docs/guide/components/{组件名}.md
  devlog: null
  knowledge: []
---

# {组件名} 开发上下文

## 目标 & 参考
- 对齐目标：{对齐 antdv/naive 哪些 API/功能}
- 参考源：antdv 官网 {URL} + naive 官网 {URL}
- 本地源码：{antdv/naive clone 路径}

## 阶段规划（大组件分 P1-Pn）
| 阶段 | 范围 | 状态 |
|:--|:--|:--|
| P1 | {本轮范围} | 🔄 |
| P2 | {下轮范围} | ⏸️ |

## 可复用项目资产（先搜索后编码）
| 需求 | 项目已有 | 位置 |
|:--|:--|:--|

## 对齐清单（阶段 2 产出 = 阶段 5 验收基线，接续时直接读取不重做）
### API 四维对比清单
| 类别 | 项 | 类型 | 默认值 | antdv | 本实现 | 对齐 |
|:--|:--|:--|:--|:--|:--|:--:|
| Props | | | | | | |
| Events | | | | | | |
| Slots | | | | | | |
| Expose（文档标题 Methods） | | | | | | |

### Demo 用例对齐清单（顺序与官网一致）
| antdv 官网用例 | 本项目用例 | antd 官网用例复制 | 缺失处置 |
|:--|:--:|:--:|:--|

> 缺失处置码：延后 P{n} / 不覆盖（理由）/ 待用户确认

## naive 差异登记（naive 有而 antdv 无的特性，阶段 2 产出）
| 特性 | naive 行为 | 决策（对齐/不覆盖（理由）/待用户确认） |
|:--|:--|:--|

## 项目特有需求（阶段 0 确认，参考库没有但项目需要）
| 需求 | 描述 | 状态 |
|:--|:--|:--|

## 进度 & 接续指引
- 上次（yesterday）：{做了什么}
- 下一步（next_action）：{具体动作}
- 待确认：{有则填}
- 发布状态（release）：pending（未发布）/ released: {版本号}（{日期}）；验收完成后若未发布，此处必填「待发布：合入 main + 发布」（见 `references/release-flow.md`）

## 决策记录
- [{HH:mm}] {决策内容}

## 备注

### 参考实现
| 对象 | 位置 | 说明 |
|:--|:--|:--|

### 关键调用
| 函数/接口 | 签名/路径 | 用途 |
|:--|:--|:--|
