---
name: verification-pipeline
description: "验证管线工具箱：提供 Browser MCP / E2E / Runtime 三类按需验证手册 + 可程序化检查脚本（lock 文件、密钥泄漏、3 次熔断计数）。被 dev-flow step-6 在 V4/V5 等场景按需调用。"
keywords: ["验证管线", "自动化验证", "lock文件检查", "密钥泄漏检查", "熔断计数", "verification-pipeline"]
---

# 验证管线工具箱

> ⚠️ **本 skill 的权威边界**（2026-05-15 重构）
>
> - **V1~V3 + V6 + V7 的执行规范**（Build / TypeCheck / Lint / Security / Diff Review）以 dev-flow `skills/dev-flow/steps/step-6-verify.md` 为**单一权威源**
> - 本 skill **不重复定义** 7 阶段总览/并行分组/3 次熔断的交互式选项/验证报告 JSON Schema 等流程性内容
> - 本 skill 只提供：① V4 Browser / V5 E2E / Runtime 自检日志的「操作手册」② 可被任意流程复用的「程序化检查脚本」③ 验证管线的「数据驱动配置」
>
> 设计哲学（确定性 vs 模糊性）见 `skills/dev-flow/references/core-principles.md` §19/§20

## 一、使用方式

### 1.1 三类调用入口

| 入口 | 触发场景 | 权威文件 |
|------|---------|---------|
| **被 dev-flow step-6 调用** | V4 Browser / V5 E2E / Runtime 自检日志手册查阅 | `references/browser-mcp-verification.md` / `references/e2e-verification.md` / `references/runtime-verification.md` |
| **独立运行验证管线** | 用户说「跑一下检查」/「帮我验证一下」/「verify 改动」 | `scripts/run-verify.sh`（推荐）|
| **被任意 lint 流程复用** | 检查 lock 文件 / 检测密钥泄漏 / 计算熔断次数 | `scripts/lints/*.sh` + `scripts/state/circuit-breaker.sh` |

### 1.2 独立验证管线（推荐用法）

```bash
# 默认：执行核心 3 阶段（Build + TypeCheck + Lint）+ Diff Review
bash skills/verification-pipeline/scripts/run-verify.sh

# 指定阶段：仅 build + typecheck
bash skills/verification-pipeline/scripts/run-verify.sh --stages=build,typecheck

# 完整 7 阶段
bash skills/verification-pipeline/scripts/run-verify.sh --stages=all

# 只输出 JSON 报告（CI 友好）
bash skills/verification-pipeline/scripts/run-verify.sh --json
```

输出 JSON 报告（结构由 `references/report.schema.json` 校验）；3 次熔断计数自动持久化到 `~/.codebuddy/working-context/.verify-state/{stage}.count`。

---

## 二、可程序化能力清单（确定性用代码）

> 以下能力由脚本/配置承载，**不再以提示词形式重复定义**。

### 2.1 调度引擎

| 能力 | 实现 | 说明 |
|------|------|------|
| 7 阶段定义 + 依赖图 | `config/stages.yaml` | 数据驱动；调度器读 YAML 而非记忆 |
| 串/并行调度 | `scripts/run-verify.sh` | 第一批 Build/TypeCheck/Lint 并行；第二批 Browser/Test/Security/Diff 依赖第一批通过 |
| JSON 报告输出 | `scripts/run-verify.sh --json` | Schema：`references/report.schema.json` |
| 3 次失败熔断 | `scripts/state/circuit-breaker.sh` | 物理计数文件兜底，AI 不可绕过 |

### 2.2 Lint 系列脚本

| 脚本 | 检查内容 | 触发阶段 |
|------|---------|---------|
| `scripts/lints/lock-file-lint.sh` | `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` 的 lockfileVersion 变化；`locales/*.json` 等 i18n 自动生成文件变更 | V7 Diff Review |
| `scripts/lints/secret-grep-lint.sh` | 硬编码 `sk-*` / `api_key` / `secret` / `password` + `dangerouslySetInnerHTML` / `innerHTML` / `document.write` | V6 Security |

### 2.3 决策表（半确定性 + LLM fallback）

| 配置 | 用途 | LLM fallback |
|------|------|-------------|
| `config/browser-mcp-routing.yaml` | V4 Browser 选择 Playwright MCP / Chrome DevTools MCP / BrowserMCP 的决策表 | 配置未命中时由 LLM 综合上下文决策 |
| `config/v4-trigger-rules.yaml` | V4 Browser 触发条件关键字（DOM/CSS/接口/UI 交互） | 关键字命中后仍由 LLM 评估改动语义是否真的需要浏览器验证 |

> 双层结构（YAML + LLM fallback）范式参考 `skills/dev-flow/references/core-principles.md` §20.2。

---

## 三、按需手册（模糊性用 LLM）

> 以下三块**只能靠 LLM 综合上下文判断**，按提示词手册形式呈现。被 dev-flow step-6 V4/V5 按需 `read_file` 引用。

### 3.1 V4 Browser MCP 验证

**何时读**：dev-flow step-6 V4 触发后，需要选择 MCP Server 并执行验证流程时。

**详细规范**：[`references/browser-mcp-verification.md`](references/browser-mcp-verification.md)

**关键判断（LLM 负责）**：
- 选择哪个 MCP Server（决策表初筛 + LLM 综合）
- 控制台 error 是否「无害」（项目特异性强）
- 接口返回异常的根因定位

### 3.2 V5 E2E 验证

**何时读**：dev-flow step-6 V5 触发且涉及 DOM/交互/布局时。

**详细规范**：[`references/e2e-verification.md`](references/e2e-verification.md)

**关键判断（LLM 负责）**：
- 是否需要写 verify-*.spec.ts（项目复杂度评估）
- 写哪些用例（断言哪些 DOM 状态/样式值）

### 3.3 Runtime 自检日志

**何时读**：改动涉及 DOM 操作/样式计算/动画定位/事件监听等运行时行为时。

**详细规范**：[`references/runtime-verification.md`](references/runtime-verification.md)

**关键判断（LLM 负责）**：
- 哪些代码节点必须打日志（按场景判断）
- 自检日志生命周期（开发→清理→提交）由 dev-flow `scripts/lints/debug-code-lint.sh` 兜底（D1-D6 自动检查）

---

## 四、与 dev-flow 的协作关系

### 4.1 调用关系图

```
dev-flow step-6-verify.md（权威源：V1~V7 完整规范 + JSON 完成标记）
   ├── V1~V3 编译/类型/Lint   → AI 直接执行（命令规范在 step-6）
   ├── V4 Browser 触发后     → use_skill('verification-pipeline')
   │                            → references/browser-mcp-verification.md
   │                            → config/browser-mcp-routing.yaml（选型决策表）
   ├── V5 Test (E2E)         → use_skill('verification-pipeline')
   │                            → references/e2e-verification.md
   ├── V6 Security           → bash scripts/lints/secret-grep-lint.sh
   ├── V7 Diff Review        → bash scripts/lints/lock-file-lint.sh
   └── 3 次失败熔断           → bash scripts/state/circuit-breaker.sh
```

### 4.2 边界声明

| 内容 | 由谁权威定义 |
|------|------------|
| 7 阶段总览表 / 并行分组 / 3 次熔断交互选项 | **dev-flow step-6** |
| 验证报告 JSON 完成标记结构 | **dev-flow step-6** |
| Browser MCP 选型决策树 / E2E 测试模板 / 自检日志规范 | **本 skill references/** |
| 验证脚本 / 配置文件 | **本 skill scripts/ + config/** |

### 4.3 反向引用清单（双向闭环）

dev-flow 中引用本 skill 的位置（自动同步基准）：

- `skills/dev-flow/steps/step-6-verify.md` L50：V4 Browser 调用入口
- `skills/dev-flow/references/topic-specs.md` L14/L16/L25：V4/V5/系统化验证条目
- `skills/dev-flow/references/shared-rules.md` L318：步骤 6 配套 Skill 清单
- `skills/dev-flow/config/gates.yaml` L143：`verification-pipeline-report` 输出契约
- `skills/dev-flow/README.md` L146：架构图

---

## 五、目录结构

```
skills/verification-pipeline/
├── SKILL.md                          # 入口（本文件）
├── config/
│   ├── stages.yaml                   # 7 阶段定义/依赖图/并行分组/超时
│   ├── browser-mcp-routing.yaml      # V4 MCP Server 选型决策表
│   └── v4-trigger-rules.yaml         # V4 Browser 触发条件配置
├── references/
│   ├── browser-mcp-verification.md   # V4 操作手册（LLM 提示词）
│   ├── e2e-verification.md           # V5 E2E 操作手册（LLM 提示词）
│   ├── runtime-verification.md       # 自检日志规范（LLM 提示词）
│   └── report.schema.json            # 验证报告 JSON Schema
├── scripts/
│   ├── run-verify.sh                 # 主调度引擎
│   ├── lib/
│   │   ├── common.sh                 # 公共函数（参数解析/JSON 转义）
│   │   └── logger.sh                 # 日志输出（color/level）
│   ├── lints/
│   │   ├── lock-file-lint.sh         # V7：lockfileVersion / locales 检查
│   │   └── secret-grep-lint.sh       # V6：硬编码密钥 / XSS 模式
│   ├── state/
│   │   └── circuit-breaker.sh        # 3 次熔断物理计数
│   └── tests/
│       ├── test-runner.sh            # 测试入口
│       └── cases/                    # 测试用例
└── README.md（本 skill 暂不创建，规则不强制）
```

---

## 六、版本与变更

| 版本 | 时间 | 变更要点 |
|------|------|---------|
| v1 | 2026 早期 | 初版：7 阶段管线提示词 + browser/e2e/runtime 三个 references |
| **v2** | **2026-05-15** | **重构**：消除与 dev-flow step-6 的重复；落地「确定性用代码」哲学，新增脚本/配置/Schema；收敛为按需手册 + 工具箱 |

> 历史版本备份：`~/.codebuddy/.backup/20260515/SKILL.md.174812`
