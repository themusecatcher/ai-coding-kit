# scripts/ 程序化执行层

> dev-flow v3 重构（2026-05-14）引入的程序化执行层，将确定性规则下沉为脚本，减少对 AI 注意力的依赖。
> 设计哲学见 `skills/dev-flow/README.md` §「设计哲学：确定性用代码，模糊性用 LLM」。

## 目录结构

```text
scripts/
├── README.md                    # 本文件
│
├── hooks/                       # 步骤前后统一钩子
│   ├── pre-step.sh              #   加载下一步骤前：物理检查点 + 步骤 5 前置硬卡点
│   └── post-step.sh             #   步骤完成后：Schema 校验 + 产物归档 + 步骤专属 lint + 步骤间质量门禁
│                                #   v3.1 (2026-06-09) 增强：
│                                #   §3.6 YAML 物理存在性检查（P0 阻断）
│                                #   §3.7 devlog 状态一致性检查（P1 警告）
│                                #   §3.8 devlog-integrity-lint 兜底（P0 阻断）
│                                #   §6 修复 7-standard/7-full/7-batch 不触发 bug
│
├── lints/                       # 确定性规则校验脚本（11 项）
│   ├── branch-name-lint.sh      #   分支命名规范校验
│   ├── commit-message-lint.sh   #   commit message 格式校验
│   ├── debug-code-lint.sh       #   调试代码残留检测
│   ├── devlog-dir-name-lint.sh  #   dev-logs 目录命名 4 项校验
│   ├── devlog-integrity-lint.sh #   devlog 双件齐全校验
│   ├── interactive-options-lint.sh # C1-C8 交互式选项一致性校验
│   ├── doc-platform-lint.sh            #   文档决策 6 项校验
│   ├── mark-step5-start.sh      #   标记步骤 5 开始
│   ├── path-lint.sh             #   R1-R5 路径规范校验
│   ├── working-context-freshness-lint.sh # 工作上下文更新新鲜度门控
│   └── working-context-location-lint.sh  # 工作上下文位置/状态完整性门控
│
├── precheck/                    # 前置校验（物理拦截）
│   ├── physical-checkpoint.sh   #   7 种模式物理检查点白名单校验（21 测试用例）
│   ├── step5-precheck.sh        #   编码前置硬卡点
│   └── iteration-fix-classify.sh # 迭代修复场景分类
│
├── harness/                     # 步骤门控脚本（14 个）
│   ├── harness-engine.sh        #   门控引擎入口
│   ├── gate-0-to-0_5.sh         #   阶段 0 → 0.5 门控
│   ├── gate-0_5-to-1.sh         #   阶段 0.5 → 步骤 1 门控
│   ├── gate-1-to-2.sh           #   步骤 1 → 2 门控
│   ├── gate-2-to-3.sh
│   ├── gate-3-to-4.sh
│   ├── gate-4-to-4_5.sh
│   ├── gate-4_5-to-5.sh
│   ├── gate-5-to-5_5.sh
│   ├── gate-5_5-to-6.sh
│   ├── gate-6-to-7.sh
│   ├── gate-7-to-8.sh
│   ├── gate-8-to-9.sh
│   └── gate-9-to-10.sh
│
├── lib/                         # 公共库
│   ├── common.sh                #   公共函数
│   ├── logger.sh                #   日志工具
│   ├── audit.sh                 #   审计工具
│   └── metrics_lib.py           #   度量采集 Python 库
│
├── recovery/                    # 恢复机制
│   ├── recovery-engine.sh       #   恢复引擎
│   └── strategies.yaml          #   恢复策略配置
│
├── tests/                       # 单元测试（90+ 用例）
│   ├── cases/                   #   测试用例目录
│   └── README.md                #   测试说明
│
├── validate-output.sh           # 步骤完成标记 JSON Schema 校验
├── validate-output.sh           # 步骤完成标记 JSON Schema 校验
├── validate-step7.sh            # 步骤 7 专项校验
├── validate-working-context.sh  # 工作上下文文件校验
├── state-machine.sh             # 状态机查询（替代记忆查表）
├── status.sh                    # 工作上下文进度概览
├── clean-artifacts.sh           # 清理产物
├── find-context-by-branch.sh    # 按分支查找工作上下文
├── gen-dashboard.py             # 度量仪表盘生成（读取 reports/*.yaml → summary.yaml + dashboard.html）
│                                #   输出 YAML 覆盖率（devlog_dir_count / coverage_pct/ total_requirements）
├── gen-flow-report.py           # 单需求 HTML 复盘报告生成（读取 report.yaml → flow-report.html）
└── validate-metrics-yaml.sh     # 度量 YAML schema 校验（requirement_id 一致性 + 字段完整性）

```

## 核心入口

### 步骤前后统一钩子（推荐使用）

```bash

# 步骤完成后（自动跑 Schema 校验 + 产物归档 + 步骤专属 lint + 质量门禁）

# 步骤 7-standard 额外触发：

#   - §3.6 YAML 物理存在性检查（P0 阻断）

#   - §3.7 devlog 状态一致性检查（P1 警告）

#   - §3.8 devlog-integrity-lint 兜底扫描（P0 阻断）
bash scripts/hooks/post-step.sh <step-id> <json-file> <flow-name>

# 加载下一步骤前（自动跑物理检查点白名单 + 步骤 5 硬卡点）
bash scripts/hooks/pre-step.sh <flow-name> <target-step-id>

```

### Schema 机器校验

```bash
bash scripts/validate-output.sh <step-id> <json-file> <flow-name>

# 返回码 0 → 通过 + .validated 已创建

# 返回码 1/2/3 → 失败，禁止加载下一步骤

```

### 状态机查询

```bash
bash scripts/state-machine.sh --query-next --current=N --mode=M
bash scripts/state-machine.sh --query-step7-variant
bash scripts/state-machine.sh --list-steps

```

## 设计原则

1. **单一权威源**：脚本/配置是规则真相，文档只引用不重复
2. **物理事实兜底**：`.validated` / `.done` 文件由脚本原子创建，AI 不可绕过
3. **确定性用代码**：可机械枚举的规则进 `lints/` 和 `precheck/`

## 相关文档

- 门控规则配置：`config/gates.yaml`
- 钩子注册表：`config/hooks.json`
- 参考文件索引：`references/_index.md`
- 门控校验规范：`references/gate-validator.md`
- Schema 目录：`references/schemas/`
