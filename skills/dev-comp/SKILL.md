---
name: dev-comp
category: dev-tools
description: 面向 vue-amazing-ui 组件库的单组件开发迭代工作流。轻量领域流程（6 阶段）+ 软复用 dev-flow 生态能力（工作上下文/plan/开发日志/度量/知识沉淀/提交），全程不进入 dev-flow 流程状态机与门控，因此轻量不臃肿。适用于在该组件库中新增或完善单个组件（如Menu/Table），参考源为 Ant Design Vue 与 Naive UI（官网+ 本地 clone 源码）。触发命令：dc: / 组件开发 / 开发 xxx 组件 / 完善 xxx 组件。
---

# dev-comp —— 组件库开发迭代工作流

> 定位：vue-amazing-ui 单组件开发迭代领域 SOP。
> 架构：**轻量领域流程 + 软复用 dev-flow 能力模块**。全程❌ 不产生 `.flow` 锁、❌ 不走 dev-flow 重型门控（`.validated` 物理检查点 / JSON 逐步校验 / 门控 subagent / post-step 脚本 / 工具门禁）；✅ 仅保留**轻量交互式 Gate**——每阶段完成后输出「阶段完成报告」并弹 `ask_followup_question`，等用户确认再进入下一阶段（详见「6 阶段 + Gate 流程总览」）。

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

## 📦 产物存储设计原则（2026-08-18 固化 · 2026-08-19 补充归档兜底）

> 决策背景：深入评估过「产物入仓库」方案，被开源仓库 git 污染 + dev-flow 生态路径硬绑定否决。产物**默认**留在 `~/.codebuddy/`（第 1-5 条，2026-08-18 固化）；2026-08-19 按用户决策补充第 6 条——用户可显式选择归档到 skill 下 `artifacts/` 目录（⚠️ 归档前须确认该目录已被 `.gitignore` 忽略，否则私有产物有污染仓库 git 历史的风险，与第 1 条精神相悖），本小节固化六条原则，防止后续迭代被顺手改回。

1. **产物不入仓库**：vue-amazing-ui 是开源项目，工作上下文/对齐清单/决策记录/度量是个人私有开发过程，进 git 污染公开历史，进 `.gitignore` 污染所有 fork 者（**用户主动归档到 `ARTIFACTS_FALLBACK_DIR` 的快照除外**，见第 6 条）
2. **软复用产物沿用固有约定**：devlog（`~/.codebuddy/dev-logs/<项目>/<分支>/`）、knowledge（`~/.codebuddy/knowledge/vue-amazing-ui/`）路径由被软复用的 tech-doc / knowledge-loop skill 硬编码，改不得也不该改（零硬依赖原则）
3. **自建产物物理隔离**：工作上下文、metrics 放 dev-comp 专属根目录 `~/.codebuddy/dev-comp/`（`working-context/` + `metrics/` 子目录）。不与 dev-flow 混放，避免被 dev-flow 的 lint 全量扫描 / dashboard 统计 / 度量闸门校验误伤
4. **命名前缀不变**：`vaui-` 前缀保留，专属目录内按组件检索不受影响
5. **目录自举（写前必建）**：`~/.codebuddy/dev-comp/` 专属目录首次使用不存在，阶段 0 初始化与阶段 5 写 metrics 前必须 `mkdir -p` 兜底，禁止假设目录已存在
6. **产物归档与接续兜底（2026-08-19 固化）**：产物**默认留在 `~/.codebuddy/` 运行时目录**（原位即归档，无需额外动作）；用户提出归档或阶段 5 收尾时，**弹 `ask_followup_question` 由用户决策归档目标**——A 保留 `~/.codebuddy/` 运行时目录（默认）/ B 归档到 `ARTIFACTS_FALLBACK_DIR` 并删除运行时副本（**禁止双份**，归档保留为快照）。归档到 B 后，阶段 0 接续扫描按「**运行时目录优先 → `ARTIFACTS_FALLBACK_DIR` 兜底**」两级顺序（详见 `references/flow.md` 阶段 0），命中归档时复制回运行时目录恢复活跃状态

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
阶段 1  准备          → 分支 + 建目录/配置 + 注册占位
阶段 2  组件本体      → 对照antdv/naive 源码开发（先搜索复用项目资产）
阶段 3  演示用例      → 完整复制官网用例（顺序一致）+ 双组件对照（src/views/xxx/Index.vue + index.ts）（⚠️ 对照为验收期临时结构，阶段 5 收尾清除）
阶段 4  文档          → docs 复用演示页 + 周边文档联动
阶段 5  验收收尾      → 配置项终检 + 基线全量勾销 + lint+type-check+浏览器对照 → devlog+metrics+knowledge → smart-commit → 引导发布（合入 main + 构建发布）
```

**各阶段对应 Gate**：Gate 0 确认组件名/分阶段计划/参考源/项目特有需求 · Gate 1 确认分支/目录/注册骨架 · Gate 2 确认功能 + API 四维/Demo 用例对齐清单 · Gate 3 确认演示页完整复制官网用例（顺序一致）+ 双组件对照 · Gate 4 确认文档完整 · Gate 5 配置项终检 + 基线全量勾销 + 确认验收结果 + 提交。

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

> ⚠️ 上述被调 skill 缺失时**优雅降级**：跳过该环节并一句话提示用户，不阻断主流程。

## 按需加载索引

| 场景 | 加载文件 |
|:--|:--|
| 执行任一阶段 | `references/flow.md` |
| 项目结构/注册链路 | `references/project-map.md` |
| 参考源路径 + antdv/naive 取舍 | `references/reference-sources.md` |
| 找可复用的项目已有资产 | `references/reusable-assets.md` |
| 注册/主题/SSR/周边文档 checklist + 发布前配置项终检 | `references/checklists.md` |
| 新增组件联动配置地图（⭐易遗漏点全集） | `references/linkage-map.md` |
| 用例标题/简介描述规范（权威源 + 同步） | `references/demo-description.md` |
| changelog 编写规范（版本号升级 + 双处同步） | `references/changelog-spec.md` |
| 发布流程（合入 main + 构建发布 + 清理） | `references/release-flow.md` |
| 如何软复用 dev-flow 能力 + 降级 | `references/capability-reuse.md` |

## 核心红线（继承项目规范）

- ❌ 禁止自动 `git commit`：commit message仅生成，用户明确选择才提交（用 smart-commit）
- ❌ commit 格式：`<type>: <description>`（**无 scope**，项目 commitlint scope-empty）
- ❌ 先搜索后编码：新增能力前先查项目已有资产（`references/reusable-assets.md`）
- ✅ 实现方式复用优先级：项目已有组件/功能/样式/布局/逻辑 > antdv 源码实现 > naive 源码实现 > 自研；**组件库已有的功能/样式/布局/逻辑优先复用，禁止重新开发**（详见 `references/reference-sources.md`）
- ✅ 主题 light/dark 双份；链式访问用可选链 `?.`；禁 any；SSR 安全（禁裸用 window/document）
- ✅ 大组件分阶段交付（P1-Pn），避免半成品
- ✅ 验收标准：演示页与antdv/naive 真身并排 1:1 对照（本项目组件在左/上，官网组件在右/下）+ 用例顺序与官网一致 + 浏览器实测（⚠️ 对照仅为验收手段：阶段 3 引入 → 阶段 5 浏览器实测验收 → **验收完成后由阶段 5 第 5 步清除**，演示页回归纯本库组件）
- ✅ 清单即验收基线：阶段 2 对齐清单（API 四维 + Demo 用例）+ naive 差异登记 + 阶段 0 项目特有需求 = 阶段 5 验收唯一对账标准，Gate 5 全量回显勾销，❌ 项必带处置码（`延后 P{n}` / `不覆盖（理由）` / `待用户确认`），禁止摘要式报告
- ✅ **联动清单即注册基线**：`references/linkage-map.md` 是「新增组件全量联动点」唯一权威源（含 ⭐ 易遗漏点：resolver 依赖映射 / 组件总数 4 处 / components.d.ts 幽灵声明 / App.vue 孤儿变量）。阶段 1/4/5 逐项勾销，**禁止靠记忆「顺手补几处」**；每处易遗漏点配 grep 自检，宣告完成前必须实测
- ✅ **配置项终检即发布基线**：`references/checklists.md` §发布前配置项终检 是阶段 5 验收时固定配置项（代码注册/文档联动/残留清理/一致性）的唯一权威源，Gate 5 必须全量逐项回显勾销 + grep 自检实测；**埋入阶段（1/4）的检查不能替代终检**，发布前必须全量回检
- ✅ **验收完成 ≠ 任务结束**：验收通过后按 `references/release-flow.md` 引导「合入 main（GitHub PR）→ main 上构建发布（`pnpm pub`，执行前用户逐条确认）→ 发布后清理（删 feat 分支）」；❌ 严禁在 feat 分支上执行发布；用户本轮不发布则写入工作上下文接续指引
