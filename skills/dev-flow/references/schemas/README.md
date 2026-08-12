# Step Completion JSON Schemas

> dev-flow 步骤完成标记 JSON 的**机器可校验 Schema**。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| `all-steps.schema.json` | 统一 Schema（14 个步骤），用 `$defs` 共享公共结构，`oneOf` 匹配具体步骤 |

## 与 `references/output-schemas.md` 的关系

- `output-schemas.md` —— **人类可读版本**（Markdown 表格，供 AI 输出完成标记时参考）
- `all-steps.schema.json` —— **机器可校验版本**（JSON Schema Draft 2020-12，供 `validate-output.sh` 使用）

两者是**同一套规范的两种表达**。修改任一文件时必须同步更新另一份。

## 校验器使用

```bash

# 1. AI 输出完成标记 JSON 到临时文件
cat > /tmp/step-4-output.json <<'EOF'
{
"step": 4,
"name": "方案汇报与用户决策",
"status": "completed",
...
}
EOF

# 2. 执行校验（v2 硬化：传 flow-name 以触发物理检查点）
bash ~/.codebuddy/skills/dev-flow/scripts/validate-output.sh 4 /tmp/step-4-output.json <flow-name>

# flow-name 从工作上下文文件名推导（去 .md 后缀）：

# 工作上下文：~/.codebuddy/working-context/20260422_fix_xxx_my-project.md

# → <flow-name>: 20260422_fix_xxx_my-project

# 3. 返回码

# 0 → 校验通过 + .validated 物理检查点已创建（可加载下一步骤）

# 1 → JSON 格式错误

# 2 → Schema 校验失败（字段缺失/类型错误/枚举越界；.validated 不创建）

# 3 → ajv-cli 缺失，降级到 jq-only 模式（仍写 .validated 但标注 jq-only）

```

## 覆盖的步骤

- `step1` / `step2` / `step3` / `step4` / `step4_5`
- `step5` / `step5_5`
- `step6`
- `step7_standard` / `step7_full` / `step7_batch` / `step7_micro_fix`（步骤 7 四种执行变体：标准 / 完整 / 批次 / 微修复）
- `step8` / `step9` / `step10`

## 关键校验规则

### 步骤 4 `plan_saved_to_disk.name_lint` 四项强校验

```text
format_matched = true        (正则 ^\d{8}_(feat|fix|opt|refactor)_[^\s/\\]+$)
type_valid = true            (类型段 ∈ {feat, fix, opt, refactor})
brief_has_chinese = true     (简述段至少含 1 个汉字)
no_project_suffix = true     (末尾不含 _myProject/_user-project/_crossProject 等项目缩写)

```

### 步骤 5 `lint_errors_remaining` 必须为 0

确保编码完成时无 lint 错误遗留。

### 步骤 7（标准执行）9 项产出全部必填

`debug_code_cleaned` / `l2_review_result` / `commit_message` / `devlog_generated` /
`knowledge_updated` / `metrics_report_generated` / `reflection` /
`flow_report_generated` / `flow_report_file`

> 📌 `flow_report_opened` 不进入 required（headless / 远程 SSH 失败时允许为 false）。
> 📌 完整执行步骤 9 同样要求 `flow_report_generated` / `flow_report_file`。

### 分支命名规范正则（适用于 step-4 `branch_recommendation` 中的三个分支字段：branch / branch_dev / branch_workspace）

```text
^(feature|bugfix|hotfix|test|i18n|private|feature_dev|sub-master|dev)(/[a-z0-9][a-z0-9-]*){1,3}$

```

- 必须以以下 9 种前缀之一开头（详细语义见 `references/shared-rules.md` §6）：
- `feature/` —— 新功能开发分支
- `bugfix/` —— Bug 修复分支
- `hotfix/` —— 线上紧急修复分支
- `test/` —— 测试分支
- `i18n/` —— 国际化分支
- `private/` —— 私有化分支
- `feature_dev/` —— 孙分支（必须为 `feature_dev/<功能>/<开发者>` 三段式，结尾固定 `/{username}`）
- `sub-master/` —— 混合云主干分支（前缀本身含短横线，作为整体枚举项匹配）
- `dev/` —— 混合云开发分支
- 每段必须小写，支持短横线和数字
- 1~3 段（与 `feature_dev/<功能>/<开发者>` 三段式兼容）
- 功能简述部分遵守「≤3 词 + kebab-case + 无驼峰/下划线/缩写」强约束（单一真相源见 `references/shared-rules.md` §6）

## 维护规则

修改 Schema 时必须同步：

1. `references/output-schemas.md`（人类可读版本）
2. `references/gate-validator.md`（文字校验规则）
3. 相关 `steps/step-N-*.md` 文件的「必须输出」章节

> 📌 Schema 文件是真相源。当 Schema 与 Markdown 描述冲突时，以 Schema 为准。
