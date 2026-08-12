#!/bin/bash
# dev-flow 步骤完成标记 JSON 校验器 + 物理检查点生成器
#
# 规范反向引用：
#   - step4 分支的 plan.md 物理事实兜底 → references/gate-validator.md §「dev-logs 物理事实兜底（P0/P1 闭环）」 §P0
#   - 门控完整规则 → config/gates.yaml + references/gate-validator.md
#
# 用法:
#   validate-output.sh <step-id> <json-file> [flow-name]
#
# 参数:
#   step-id   步骤标识: 1 / 2 / 3 / 4 / 4.5 / 5 / 5.5 / 5.5-micro-fix /
#             6 / 6-micro-fix / 7-standard / 7-full / 7-batch / 7-micro-fix / 8 / 9 / 10
#   json-file JSON 文件路径
#   flow-name （可选）活跃流程名称（对应 .active-flows/{name}.flow）
#             提供时：校验通过后自动 touch .active-flows/{name}.step-{N}.validated
#             不提供：仅做 Schema 校验，不生成物理检查点
#
# 返回码:
#   0  校验通过（若提供 flow-name，已同时写入 .validated 检查点）
#   1  JSON 格式错误 / 文件不存在 / 参数错误
#   2  Schema 校验失败（禁止 touch .validated）
#   3  缺少必需工具（提示但不阻塞，会降级到 jq-only 模式）
#
# 🔒 物理检查点规则（防止 AI 绕过校验）:
#   - .validated 文件**只能**由本脚本创建，AI 不得自行 touch
#   - 下一步骤加载前必须 ls .step-{N}.validated 存在（而非 .done）
#   - 此机制确保"Schema 校验通过"与"物理标记"原子绑定
#
# 📌 文件名编码规则:
#   step-id 中的 "." 和 "-" 会被统一替换为 "_"（tr '.-' '__'），
#   以避免 "." 在 bash glob 中被误解析。映射示例：
#     4.5         → 实际文件名 .step-4_5.validated
#     5.5         → 实际文件名 .step-5_5.validated
#     7-standard  → 实际文件名 .step-7_standard.validated
#     5 / 10 等整数步骤保持不变
#   AI 执行 ls 校验时，必须使用下划线形式的文件名。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMAS_DIR="$(cd "$SCRIPT_DIR/../references/schemas" && pwd)"
UNIFIED_SCHEMA="$SCHEMAS_DIR/all-steps.schema.json"
ACTIVE_FLOWS_DIR="$HOME/.codebuddy/working-context/.active-flows"

STEP_ID="$1"
JSON_FILE="$2"
FLOW_NAME="$3"

# 基本参数校验
if [ -z "$STEP_ID" ] || [ -z "$JSON_FILE" ]; then
  echo "❌ 用法: $0 <step-id> <json-file> [flow-name]" >&2
  echo "   step-id ∈ {1, 2, 3, 4, 4.5, 5, 5.5, 6, 7-standard, 7-full, 7-batch, 7-micro-fix, 8, 9, 10}" >&2
  echo "   flow-name 可选；提供则校验通过后自动 touch .active-flows/{name}.step-{N}.validated" >&2
  exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
  echo "❌ 文件不存在: $JSON_FILE" >&2
  exit 1
fi

# 拒绝临时文件路径（强制落盘到 dev-flow-artifacts/，便于后续审计追溯）
# 背景：若 step-4 用 /tmp 临时文件，会导致 dev-flow-artifacts/ 缺 step-4.json，
# 事后无法回溯 AI 当时声明的字段值。
case "$JSON_FILE" in
  /tmp/*|/var/folders/*|/var/tmp/*)
    echo "❌ JSON 文件路径不合法: $JSON_FILE" >&2
    echo "   禁止使用临时目录（/tmp/ /var/folders/ /var/tmp/）作为步骤完成标记落盘位置。" >&2
    echo "   规范路径：~/.codebuddy/dev-flow-artifacts/<flow-name>/step-<id>.json" >&2
    echo "   理由：临时文件无法事后审计，无法支撑跨步骤的物理事实回溯。" >&2
    exit 1
    ;;
esac

# JSON 格式校验（前置）
if ! jq empty "$JSON_FILE" > /dev/null 2>&1; then
  echo "❌ JSON 格式错误: $JSON_FILE" >&2
  exit 1
fi

# ====== 物理检查点写入函数（仅在 flow-name 提供 + 校验通过时调用）======
# 设计原则：
#   1. 仅本函数可创建 .validated 文件，AI 不得 touch 伪造
#   2. 同时记录 validation_log 元信息到 .json 辅助文件，供审计
#   3. 跨平台 date 处理（macOS / Linux）
write_validation_checkpoint() {
  local step_id="$1"
  local flow_name="$2"
  local validator_type="$3"   # "ajv" | "jq-only"
  local step_slug
  # 将 step_id 中的 "-" / "." 规范化为 "_"（与 schema $ref 一致）
  step_slug=$(echo "$step_id" | tr '.-' '__')

  if [ -z "$flow_name" ]; then
    return 0   # 未提供 flow-name，跳过物理检查点写入
  fi

  # 确保目录存在
  mkdir -p "$ACTIVE_FLOWS_DIR"

  # ====== 漏洞 #7 修复（2026-05-29）：flow_name 一致性自检 ======
  # 历史问题：同一流程的 step-1/2/3/4 .validated.json 记录 flow_name=A，但 step-4.5+ 改成 flow_name=B；
  # 物理 .validated 文件却被 AI 后期手动重命名以匹配 flow_name=B（违反红牌 #14）。
  # 修复：写入 .validated 前，扫描 ACTIVE_FLOWS_DIR 下同 prefix 已有 .validated.json 中的 flow_name，
  # 若发现与当前 flow_name 不一致，立即拒绝写入。
  # 见 ajv 路径物理事实兜底校验 §漏洞#7
  local sibling_meta
  for sibling_meta in "$ACTIVE_FLOWS_DIR/${flow_name}".step-*.validated.json; do
    [ -f "$sibling_meta" ] || continue
    local recorded_flow
    recorded_flow=$(jq -r '.flow_name // ""' "$sibling_meta" 2>/dev/null)
    if [ -n "$recorded_flow" ] && [ "$recorded_flow" != "$flow_name" ]; then
      echo "❌ flow_name 漂移检测：" >&2
      echo "   当前传入: $flow_name" >&2
      echo "   已有 .validated.json 记录: $recorded_flow（来自 $(basename "$sibling_meta")）" >&2
      echo "   原因：同一流程内 flow_name 必须一致；切换流程请创建新 .flow 文件，禁止改名复用旧 .validated。" >&2
      echo "   红牌 #14：AI 不得自行 touch / 改名 .validated 文件以掩盖 flow_name 漂移。" >&2
      exit 2
    fi
  done

  # ====== current_step 一致性校验（2026-07-08 新增）======
  # 设计动机：2026-07-08 发现 file-export 流程 .flow.current_step=6 但 step-7 校验通过。
  #   step-router 动作顺序：动作 2（更新 .flow.current_step）→ 动作 3（本脚本）。
  #   若动作 2 遗漏，current_step 会滞后于实际校验步骤，导致后续清理链路断裂。
  # 规则：.flow.current_step 必须等于 STEP_ID 去变体后缀后的基步骤号
  #   例：STEP_ID="7-standard" → .flow.current_step 应为 "7"
  #        STEP_ID="4.5"      → .flow.current_step 应为 "4.5"
  local flow_file="$ACTIVE_FLOWS_DIR/${flow_name}.flow"
  if [ -f "$flow_file" ]; then
    local flow_cur
    flow_cur=$(grep "^current_step:" "$flow_file" 2>/dev/null | head -1 | sed 's/current_step:\s*//' | tr -d '"' | xargs)
    local base_step
    base_step=$(echo "$step_id" | sed 's/-.*//')
    if [ -n "$flow_cur" ] && [ -n "$base_step" ] && [ "$flow_cur" != "$base_step" ]; then
      echo "❌ current_step 不一致：" >&2
      echo "   .flow.current_step: $flow_cur" >&2
      echo "   当前校验步骤: $step_id（期望 .flow.current_step=$base_step）" >&2
      echo "   原因：步骤路由器动作 2（更新 .flow.current_step）可能遗漏" >&2
      echo "   修复：将 .flow.current_step 更新为 $base_step 后重跑 validate-output.sh" >&2
      exit 2
    fi
  fi

  # 生成 ISO 8601 时间戳
  local now
  now=$(date +"%Y-%m-%dT%H:%M:%S")

  # touch .validated 文件
  local validated_file="$ACTIVE_FLOWS_DIR/${flow_name}.step-${step_slug}.validated"
  touch "$validated_file"

  # 写入审计元信息（.validated.json 辅助文件）
  local meta_file="$ACTIVE_FLOWS_DIR/${flow_name}.step-${step_slug}.validated.json"
  cat > "$meta_file" <<EOF
{
  "step_id": "${step_id}",
  "step_slug": "${step_slug}",
  "flow_name": "${flow_name}",
  "validated_at": "${now}",
  "validator_type": "${validator_type}",
  "json_file": "${JSON_FILE}",
  "schema_version": "all-steps.schema.json@2026-04-30"
}
EOF

  echo "🔐 物理检查点已写入: ${validated_file}" >&2
  echo "   审计元信息: ${meta_file}" >&2
}

# 将 step-id 映射到 schema 内部的 $ref 名称
case "$STEP_ID" in
  1)              STEP_REF="step1" ;;
  2)              STEP_REF="step2" ;;
  3)              STEP_REF="step3" ;;
  4)              STEP_REF="step4" ;;
  4.5)            STEP_REF="step4_5" ;;
  5)              STEP_REF="step5" ;;
  5.5)            STEP_REF="step5_5" ;;
  5.5-micro-fix)  STEP_REF="step5_5_micro_fix" ;;
  6)              STEP_REF="step6" ;;
  6-micro-fix)    STEP_REF="step6_micro_fix" ;;
  7-standard)     STEP_REF="step7_standard" ;;
  7-full)         STEP_REF="step7_full" ;;
  7-batch)        STEP_REF="step7_batch" ;;
  7-micro-fix)    STEP_REF="step7_micro_fix" ;;
  8)              STEP_REF="step8" ;;
  9)              STEP_REF="step9" ;;
  10)             STEP_REF="step10" ;;
  *)
    echo "❌ 未知 step-id: $STEP_ID" >&2
    echo "   合法值: 1, 2, 3, 4, 4.5, 5, 5.5, 6, 7-standard, 7-full, 7-batch, 7-micro-fix, 8, 9, 10" >&2
    exit 1
    ;;
esac

# 优先使用 ajv-cli（完整 Schema 校验）
if command -v ajv > /dev/null 2>&1; then
  # 生成步骤专用的临时 Schema（从 unified schema 抽出对应 $ref）
  TMP_SCHEMA="/tmp/dev-flow-schema-$$.json"
  trap "rm -f $TMP_SCHEMA" EXIT

  jq --arg ref "$STEP_REF" '
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "allOf": [.properties[$ref]],
      "$defs": .["$defs"]
    }
  ' "$UNIFIED_SCHEMA" > "$TMP_SCHEMA"

  if ajv validate -s "$TMP_SCHEMA" -d "$JSON_FILE" --spec=draft2020 --strict=false 2>&1; then
    echo "✅ [ajv] Schema 校验通过: step=$STEP_ID"

    # ========================================
    # ajv 通过后的物理事实校验（Schema 只管结构，这里验证 AI 填的内容是否属实）
    # ========================================
    # step4: doc-platform-doc-lint 物理事实门控（P1，详见 references/gate-validator.md §「doc_platform 发布前 lint 门控」）
    # 必须在其他 step4 物理检查之前执行，避免被 dev-logs / plan.md 等检查的 exit 2 短路。
    # 来源：2026-06-12 复盘——AI 可通过跳过 doc-platform-lint.sh 绕过发布前校验。
    if [ "$STEP_REF" = "step4" ]; then
      DECISION=$(jq -r '.outputs.user_decision // "missing"' "$JSON_FILE")
      doc_platform_ACTION=$(jq -r '.outputs.doc_platform_tech_proposal.action // "skip"' "$JSON_FILE")
      if ! echo "$DECISION" | grep -qE '^(cancel|change_plan|pause|modify)$'; then
        case "$doc_platform_ACTION" in
          create|update)
            doc_platform_LINT_PASSED=$(jq -r '.outputs.doc_platform_tech_proposal.doc_platform_lint_passed // "false"' "$JSON_FILE")
            if [ "$doc_platform_LINT_PASSED" != "true" ]; then
              echo "❌ doc-platform-doc-lint 门控未通过: doc_platform_lint_passed=$doc_platform_LINT_PASSED" >&2
              echo "   doc_platform_action=$doc_platform_ACTION，发布前必须运行 doc-platform-lint.sh 并通过（0 violations + exit 0）" >&2
              echo "   修复：运行 bash ~/.codebuddy/skills/tech-doc/scripts/lints/doc-platform-lint.sh --doc-type tech-proposal <草稿路径>" >&2
              echo "        确认通过后将 doc_platform_tech_proposal.doc_platform_lint_passed 设为 true" >&2
              exit 2
            fi
            ;;
        esac
      fi
    fi

    # step4: 分支命名 · 物理事实校验（用脚本重算，不信 AI 自填的 branch_name_lint_passed）
    if [ "$STEP_REF" = "step4" ]; then
      DECISION=$(jq -r '.outputs.user_decision // "missing"' "$JSON_FILE")
      case "$DECISION" in
        execute_standard|execute_micro|execute_full|execute_partial|execute_batched)
          BRANCH_STATUS=$(jq -r '.outputs.branch_recommendation.branch_status // "missing"' "$JSON_FILE")
          if [ "$BRANCH_STATUS" != "user_specified" ]; then
            BRANCH_NAME=$(jq -r '.outputs.branch_recommendation.branch_workspace // .outputs.branch_recommendation.branch // ""' "$JSON_FILE")
            if [ -n "$BRANCH_NAME" ]; then
              if ! "$SCRIPT_DIR/lints/branch-name-lint.sh" --raw "$BRANCH_NAME" > /dev/null 2>&1; then
                echo "❌ 分支命名 lint 校验失败: $BRANCH_NAME" >&2
                "$SCRIPT_DIR/lints/branch-name-lint.sh" "$BRANCH_NAME" >&2
                echo "   修复：调整分支名使其符合 shared-rules.md §6 规范后重新运行校验。" >&2
                exit 2
              fi
            fi
          fi
          ;;
      esac
    fi

    # step4: 工作上下文文件名 · 物理事实校验（检查实际文件命名和结构）
    if [ "$STEP_REF" = "step4" ]; then
      WC_PATH=$(jq -r '.outputs.plan_saved_to_disk.path // ""' "$JSON_FILE")
      if [ -n "$WC_PATH" ]; then
        # 展开 ~ 为 $HOME
        WC_PATH_EXPANDED="${WC_PATH/#\~/$HOME}"
        # 漏洞 #8 修复（2026-05-29）：path 字段非空 → 必须真实存在
        # 历史问题：原逻辑 `if [ -f "$WC_PATH_EXPANDED" ]` 在文件不存在时直接跳过校验，
        # AI 可填假 path 字段（如 "~/.codebuddy/working-context/虚构文件.md"）绕过 working-context lint。
        # 见 ajv 路径物理事实兜底校验 §漏洞#8
        if [ ! -f "$WC_PATH_EXPANDED" ]; then
          echo "❌ 工作上下文文件物理不存在: $WC_PATH_EXPANDED" >&2
          echo "   JSON 字段已声明 plan_saved_to_disk.path，但磁盘上没有该文件。" >&2
          echo "   原因可能：AI 只填了 JSON 字段没真写入磁盘 / 路径错误 / 写入失败被吞。" >&2
          echo "   修复：将工作上下文文件实际写入 $WC_PATH_EXPANDED 后重新运行校验。" >&2
          exit 2
        fi
        if ! "$SCRIPT_DIR/validate-working-context.sh" "$WC_PATH_EXPANDED" > /dev/null 2>&1; then
          echo "❌ 工作上下文文件名/结构校验失败:" >&2
          "$SCRIPT_DIR/validate-working-context.sh" "$WC_PATH_EXPANDED" >&2
          echo "   修复：按 references/working-context.md §命名规则 重命名文件后重新运行校验。" >&2
          exit 2
        fi
      fi
    fi

    # step4: dev-logs 目录命名 · 物理事实校验（用脚本重算，不信 AI 自填的 name_lint 字段）
    if [ "$STEP_REF" = "step4" ]; then
      DIR_NAME=$(jq -r '.outputs.plan_saved_to_disk.dir_name // ""' "$JSON_FILE")
      if [ -n "$DIR_NAME" ]; then
        if ! "$SCRIPT_DIR/lints/devlog-dir-name-lint.sh" --raw "$DIR_NAME" > /dev/null 2>&1; then
          echo "❌ dev-logs 目录命名物理事实校验失败: $DIR_NAME" >&2
          "$SCRIPT_DIR/lints/devlog-dir-name-lint.sh" "$DIR_NAME" >&2
          echo "   修复：调整目录名使其符合 gate-validator.md 命名规范后重新运行校验。" >&2
          exit 2
        fi
      fi
    fi

    # step4: plan.md 物理事实兜底（P0，详见 references/gate-validator.md §「dev-logs 物理事实兜底（P0/P1 闭环）」）
    # 与 jq-only 模式（下方 step4 case 块）对齐——ajv 路径不能跳过此校验，否则 P0 完全失效。
    # 采用黑名单策略：排除不涉及代码执行的非标决策（如 ship_bug_a_only 等自定义决策也会被强制要求落盘 plan.md）
    if [ "$STEP_REF" = "step4" ]; then
      DECISION=$(jq -r '.outputs.user_decision // "missing"' "$JSON_FILE")
      # 排除：cancel（取消流程）/ change_plan（回退步骤 3 重新规划）/ pause（暂存）/ modify（修改循环，回退步骤 2）
      # 其他所有决策（含非标自定义决策如 ship_bug_a_only）均要求落盘 plan.md
      if ! echo "$DECISION" | grep -qE '^(cancel|change_plan|pause|modify)$'; then
          DIR_NAME=$(jq -r '.outputs.plan_saved_to_disk.dir_name // ""' "$JSON_FILE")
          if [ -z "$DIR_NAME" ]; then
            echo "❌ plan_saved_to_disk.dir_name 不可为空（执行类 user_decision 必须落盘 plan.md）" >&2
            exit 2
          fi
          PLAN_FILE="$HOME/.codebuddy/dev-logs/$DIR_NAME/plan.md"
          if [ ! -f "$PLAN_FILE" ]; then
            echo "❌ plan.md 物理文件不存在: $PLAN_FILE" >&2
            echo "   JSON 字段已声明 plan_saved_to_disk.status=true，但磁盘上没有 plan.md。" >&2
            echo "   原因可能：AI 只填了 JSON 字段没真写入磁盘 / 路径错误 / 写入失败被吞。" >&2
            echo "   修复：将完整执行计划写入 $PLAN_FILE 后重新运行校验。" >&2
            exit 2
          fi
          # 防空文件：plan.md 必须 ≥10 字节（最起码有标题与一个段落）
          if [ "$(wc -c < "$PLAN_FILE" | tr -d ' ')" -lt 10 ]; then
            echo "❌ plan.md 内容过短（< 10 字节）: $PLAN_FILE，疑似空写入或占位文件" >&2
            exit 2
          fi
      fi
    fi

    # step7 §K: devlog_integrity_check 物理事实校验（P1，对齐 jq-only 路径行 443+/481+）
    # 背景：ajv 路径若无 §K 校验，AI 可声明 devlog_integrity_check=clean 绕过实际扫描
    if [ "$STEP_REF" = "step7_standard" ] || [ "$STEP_REF" = "step7_full" ] || [ "$STEP_REF" = "step7_batch" ]; then
      DLI=$(jq -r '.outputs.devlog_integrity_check // "missing"' "$JSON_FILE")
      case "$DLI" in
        clean|warns_*) ;;
        blocked_errors_*)
          echo "❌ devlog_integrity_check=$DLI 表示存在 ERROR，必须先修复 ~/.codebuddy/dev-logs/ 完整性问题" >&2
          echo "   运行 scripts/lints/devlog-integrity-lint.sh 查看详情" >&2
          exit 2
          ;;
        *)
          echo "❌ devlog_integrity_check 字段缺失或非法 [当前: $DLI]" >&2
          echo "   必须运行 devlog-integrity-lint.sh --quiet 后填入 clean|warns_N|blocked_errors_N" >&2
          exit 2
          ;;
      esac
      # 物理事实兜底：用脚本重算，不信 AI 自填的字段（防止 AI 声明 clean 但实际有 ERROR）
      INTEGRITY_OUTPUT=$("$SCRIPT_DIR/lints/devlog-integrity-lint.sh" --quiet 2>&1)
      ACTUAL_ERRORS=$(echo "$INTEGRITY_OUTPUT" | grep -c "^  ❌ " || true)
      if [ "$ACTUAL_ERRORS" -gt 0 ] 2>/dev/null; then
        case "$DLI" in
          blocked_errors_*) ;;  # 已诚实声明，前面已 exit
          *)
            echo "❌ devlog_integrity_check=$DLI 与物理事实不符——脚本扫描发现 $ACTUAL_ERRORS 个 ERROR" >&2
            echo "$INTEGRITY_OUTPUT" >&2
            echo "   修复：先修复 dev-logs/ 完整性问题，再如实填写 devlog_integrity_check 字段" >&2
            exit 2
            ;;
        esac
      fi
    fi

    # 通用: commit message 格式 · 物理事实校验（用脚本验证实际格式，不只查非空）
    COMMIT_MSG_VAL=$(jq -r '.outputs.commit_message // ""' "$JSON_FILE")
    if [ -n "$COMMIT_MSG_VAL" ]; then
      if ! "$SCRIPT_DIR/lints/commit-message-lint.sh" --raw "$COMMIT_MSG_VAL" > /dev/null 2>&1; then
        echo "❌ commit message 格式物理事实校验失败: $COMMIT_MSG_VAL" >&2
        "$SCRIPT_DIR/lints/commit-message-lint.sh" "$COMMIT_MSG_VAL" >&2
        echo "   规范：<type>: <description>（无 scope 括号，type ∈ feat|fix|opt|refactor|chore|docs|style|test|ci|perf|revert）" >&2
        exit 2
      fi
    fi

    # step7: 调试代码清除 · 物理事实校验（扫描实际文件，不信 AI 自填的 debug_code_cleaned=true）
    if [ "$STEP_REF" = "step7_standard" ] || [ "$STEP_REF" = "step7_full" ]; then
      if [ -n "$FLOW_NAME" ]; then
        STEP5_ARTIFACT="$HOME/.codebuddy/dev-flow-artifacts/$FLOW_NAME/step-5.json"
        if [ -f "$STEP5_ARTIFACT" ]; then
          debug_lint_fail=0
          while IFS= read -r modified_file; do
            [ -z "$modified_file" ] && continue
            if [ -f "$modified_file" ]; then
              if ! "$SCRIPT_DIR/lints/debug-code-lint.sh" --raw "$modified_file" > /dev/null 2>&1; then
                echo "❌ 调试代码残留: $modified_file" >&2
                "$SCRIPT_DIR/lints/debug-code-lint.sh" "$modified_file" >&2
                debug_lint_fail=1
              fi
            fi
          done < <(jq -r '.outputs.files_modified[]?' "$STEP5_ARTIFACT" 2>/dev/null)
          if [ "$debug_lint_fail" -eq 1 ]; then
            echo "   JSON 声明 debug_code_cleaned=true 但物理检测发现调试代码残留。" >&2
            echo "   修复：清除上述文件中的 console.log/debugger/TODO 后重新运行校验。" >&2
            exit 2
          fi
        fi
      fi
    fi

    # step10: 字段对等校验（漏洞 #5 修复，2026-05-29）
    # 历史问题：schema required 列表里没有 rules_archived，AI 可不填该字段通过 ajv 校验。
    # 修复：在 ajv 通过后追加与 jq-only 路径对等的字段必填校验。
    # 见 ajv 路径物理事实兜底校验 §漏洞#5
    if [ "$STEP_REF" = "step10" ]; then
      for f in delivery_report devlog_generated knowledge_updated rules_archived; do
        VAL=$(jq -r ".outputs.$f // \"missing\"" "$JSON_FILE")
        if [ "$VAL" != "true" ]; then
          echo "❌ outputs.$f 必须为 true [当前: $VAL]" >&2
          exit 2
        fi
      done
      COMMIT_MSG=$(jq -r '.outputs.commit_message // ""' "$JSON_FILE")
      if [ -z "$COMMIT_MSG" ]; then
        echo "❌ commit_message 不能为空" >&2
        exit 2
      fi
      doc_platform_SYNC=$(jq -r '.outputs.doc_platform_sync_result // "missing"' "$JSON_FILE")
      case "$doc_platform_SYNC" in
        synced|relinked|created|skipped_no_changes|skipped_user_opt_out) ;;
        *)
          echo "❌ doc_platform_sync_result 非法: [$doc_platform_SYNC]（必须是 synced|relinked|created|skipped_no_changes|skipped_user_opt_out 之一）" >&2
          exit 2
          ;;
      esac
    fi

    # step10: P2 归档前总校验（漏洞 #6 修复，2026-05-29）
    # 历史问题：gate-validator.md §P2 规范要求步骤 10 归档前执行 dev-logs 完整性 + working-context
    # 引用一致性总校验，但脚本两条路径都没实现。
    # 修复：在 ajv 通过后追加 P2 总校验（与 step7 §K 同思路：脚本重算物理事实）。
    # 见 ajv 路径物理事实兜底校验 §漏洞#6
    if [ "$STEP_REF" = "step10" ]; then
      # P2.1 dev-logs 完整性总校验
      P2_INTEGRITY_OUTPUT=$("$SCRIPT_DIR/lints/devlog-integrity-lint.sh" --quiet 2>&1)
      P2_ACTUAL_ERRORS=$(echo "$P2_INTEGRITY_OUTPUT" | grep -c "^  ❌ " || true)
      if [ "$P2_ACTUAL_ERRORS" -gt 0 ] 2>/dev/null; then
        echo "❌ [P2] step-10 归档前总校验：dev-logs/ 存在 $P2_ACTUAL_ERRORS 个 ERROR" >&2
        echo "$P2_INTEGRITY_OUTPUT" >&2
        echo "   修复：归档前必须先解决全量 dev-logs/ 完整性问题（gate-validator.md §P2）" >&2
        exit 2
      fi
      # P2.2 working-context 引用一致性（若有 validate-working-context.sh 且当前流程的 wc 文件能定位）
      if [ -n "$FLOW_NAME" ]; then
        WC_FILE="$HOME/.codebuddy/working-context/${FLOW_NAME}.md"
        if [ -f "$WC_FILE" ]; then
          if ! "$SCRIPT_DIR/validate-working-context.sh" "$WC_FILE" > /dev/null 2>&1; then
            echo "❌ [P2] step-10 归档前总校验：working-context 引用一致性失败" >&2
            "$SCRIPT_DIR/validate-working-context.sh" "$WC_FILE" >&2
            echo "   修复：按 references/working-context.md §命名规则 + §引用一致性 修复后重新运行（gate-validator.md §P2）" >&2
            exit 2
          fi
        else
          # 反沉默失败：文件不存在不能跳过，必须区分「真的不存在」和「被错误移动到 archive/」
          # 出处：rules/AI行为规范.mdc §「验证行为规范 > 编辑工具假性成功兜底」
          ARCHIVED_PATH=""
          if [ -d "$HOME/.codebuddy/working-context/archive" ]; then
            ARCHIVED_PATH=$(find "$HOME/.codebuddy/working-context/archive" -type f -name "${FLOW_NAME}.md" 2>/dev/null | head -1)
          fi
          if [ -n "$ARCHIVED_PATH" ]; then
            echo "❌ [P2] step-10 归档前总校验：working-context 文件被错误移动到 archive/ 子目录" >&2
            echo "   期望位置: $WC_FILE" >&2
            echo "   实际位置: $ARCHIVED_PATH" >&2
            echo "   ⚠️  dev-flow 不存在自动归档机制（详见 skills/dev-flow/references/working-context.md §九「目录结构禁令」）" >&2
            echo "   修复: mv \"$ARCHIVED_PATH\" \"$WC_FILE\"" >&2
            exit 2
          else
            echo "❌ [P2] step-10 归档前总校验：working-context 文件丢失" >&2
            echo "   期望位置: $WC_FILE" >&2
            echo "   修复：恢复该文件后重新运行（gate-validator.md §P2）" >&2
            exit 2
          fi
        fi
      fi
    fi

    write_validation_checkpoint "$STEP_ID" "$FLOW_NAME" "ajv"
    exit 0
  else
    echo "❌ [ajv] Schema 校验失败: step=$STEP_ID" >&2
    exit 2
  fi
fi

# 降级：jq-only 模式（只校验必需字段存在性和基础类型）
echo "⚠️  ajv-cli 未安装，降级到 jq-only 基础校验模式" >&2
echo "   完整 Schema 校验请安装: npm install -g ajv-cli ajv-formats" >&2

# 通用必填字段
REQUIRED_FIELDS=("step" "name" "status" "outputs" "working_context_updated" "next_step")
for field in "${REQUIRED_FIELDS[@]}"; do
  if ! jq -e ".$field" "$JSON_FILE" > /dev/null 2>&1; then
    echo "❌ 缺少必需字段: .$field" >&2
    exit 2
  fi
done

# status 枚举校验
STATUS=$(jq -r '.status' "$JSON_FILE")
case "$STATUS" in
  completed|partial|blocked|skipped) ;;
  *)
    echo "❌ status 非法: [$STATUS] (必须 ∈ {completed, partial, blocked, skipped})" >&2
    exit 2
    ;;
esac

# 步骤特定关键字段校验（挑选最易出错的字段重点校验）
case "$STEP_REF" in
  step1)
    # sufficiency_check 必填字段存在性
    for sc_field in search_queries_count keyword_variations_tried cross_verified confidence confidence_reason call_graph_drawn; do
      if ! jq -e ".sufficiency_check.$sc_field" "$JSON_FILE" > /dev/null 2>&1; then
        echo "❌ 缺少必需字段: .sufficiency_check.$sc_field" >&2
        exit 2
      fi
    done
    # codebase_queries_count 必须 ≥ 1（本地搜索不可缺失）
    CQ=$(jq -r '.sufficiency_check.codebase_queries_count // 0' "$JSON_FILE")
    if [ "$CQ" -lt 1 ] 2>/dev/null; then
      echo "❌ sufficiency_check.codebase_queries_count 必须 ≥ 1 [当前: $CQ]" >&2
      exit 2
    fi
    # search_queries_count 必须 ≥ 2
    SQ=$(jq -r '.sufficiency_check.search_queries_count // 0' "$JSON_FILE")
    if [ "$SQ" -lt 2 ] 2>/dev/null; then
      echo "❌ sufficiency_check.search_queries_count 必须 ≥ 2 [当前: $SQ]" >&2
      exit 2
    fi
    # keyword_variations_tried 至少 2 项
    KV=$(jq -r '.sufficiency_check.keyword_variations_tried | length' "$JSON_FILE" 2>/dev/null || echo 0)
    if [ "$KV" -lt 2 ] 2>/dev/null; then
      echo "❌ sufficiency_check.keyword_variations_tried 至少需要 2 项 [当前: $KV]" >&2
      exit 2
    fi
    # cross_verified 必须为 true
    CV=$(jq -r '.sufficiency_check.cross_verified // "missing"' "$JSON_FILE")
    if [ "$CV" != "true" ]; then
      echo "❌ sufficiency_check.cross_verified 必须为 true [当前: $CV]" >&2
      exit 2
    fi
    # confidence 不得为 low
    CONF=$(jq -r '.sufficiency_check.confidence // "missing"' "$JSON_FILE")
    case "$CONF" in
      high|medium) ;;
      *)
        echo "❌ sufficiency_check.confidence 非法: [$CONF] (必须 ∈ {high, medium}，low 时须设 status=blocked)" >&2
        exit 2
        ;;
    esac
    # call_graph_drawn 合法值
    CGD=$(jq -r '.sufficiency_check.call_graph_drawn // "missing"' "$JSON_FILE")
    case "$CGD" in
      true|not_applicable) ;;
      *)
        echo "❌ sufficiency_check.call_graph_drawn 非法: [$CGD] (必须 ∈ {true, not_applicable})" >&2
        exit 2
        ;;
    esac
    # related_files_count 必须 ≥ 1
    RFC=$(jq -r '.outputs.related_files_count // 0' "$JSON_FILE")
    if [ "$RFC" -lt 1 ] 2>/dev/null; then
      echo "❌ outputs.related_files_count 必须 ≥ 1 [当前: $RFC]" >&2
      exit 2
    fi
    ;;
  step4)
    # 目录命名 lint 四项
    for lint_field in format_matched type_valid brief_has_chinese no_project_suffix; do
      VAL=$(jq -r ".outputs.plan_saved_to_disk.name_lint.$lint_field // \"missing\"" "$JSON_FILE")
      if [ "$VAL" != "true" ]; then
        echo "❌ plan_saved_to_disk.name_lint.$lint_field 必须为 true [当前: $VAL]" >&2
        exit 2
      fi
    done
    # user_decision 枚举
    DECISION=$(jq -r '.outputs.user_decision // "missing"' "$JSON_FILE")
    case "$DECISION" in
      execute_standard|execute_micro|execute_full|execute_partial|execute_batched|modify|change_plan|pause|cancel) ;;
      *)
        echo "❌ user_decision 非法: [$DECISION]" >&2
        exit 2
        ;;
    esac
    # 物理事实兜底：所有含代码执行的 user_decision 强制 plan.md 必须真实落盘（防 AI 只填 JSON 字段绕过门控）
    # 2026-06-05 修复：排除 cancel/change_plan/pause/modify，其余均强制落盘
    DECISION=$(jq -r '.outputs.user_decision // "missing"' "$JSON_FILE")
    if ! echo "$DECISION" | grep -qE '^(cancel|change_plan|pause|modify)$'; then
      DIR_NAME=$(jq -r '.outputs.plan_saved_to_disk.dir_name // ""' "$JSON_FILE")
        if [ -z "$DIR_NAME" ]; then
          echo "❌ plan_saved_to_disk.dir_name 不可为空（执行类 user_decision 必须落盘 plan.md）" >&2
          exit 2
        fi
        PLAN_FILE="$HOME/.codebuddy/dev-logs/$DIR_NAME/plan.md"
        if [ ! -f "$PLAN_FILE" ]; then
          echo "❌ plan.md 物理文件不存在: $PLAN_FILE" >&2
          echo "   JSON 字段已声明 plan_saved_to_disk.status=true，但磁盘上没有 plan.md。" >&2
          echo "   原因可能：AI 只填了 JSON 字段没真写入磁盘 / 路径错误 / 写入失败被吞。" >&2
          echo "   修复：将完整执行计划写入 $PLAN_FILE 后重新运行校验。" >&2
          exit 2
        fi
        # 防空文件：plan.md 必须 ≥10 字节（最起码有标题与一个段落）
        if [ "$(wc -c < "$PLAN_FILE" | tr -d ' ')" -lt 10 ]; then
          echo "❌ plan.md 内容过短（< 10 字节）: $PLAN_FILE，疑似空写入或占位文件" >&2
          exit 2
        fi
    fi
    # 文档平台 决策硬性校验（仅执行类 user_decision 时强制）
    case "$DECISION" in
      execute_standard|execute_micro|execute_full|execute_partial|execute_batched)
        doc_platform_DECISION=$(jq -r '.outputs.doc_platform_tech_proposal.decision_made // "missing"' "$JSON_FILE")
        if [ "$doc_platform_DECISION" != "true" ]; then
          echo "❌ doc_platform_tech_proposal.decision_made 必须为 true（硬性要求）[当前: $doc_platform_DECISION]" >&2
          exit 2
        fi
        doc_platform_ACTION=$(jq -r '.outputs.doc_platform_tech_proposal.action // "missing"' "$JSON_FILE")
        case "$doc_platform_ACTION" in
          create|update|relink|skip|auto_inherited_skip) ;;
          *)
            echo "❌ doc_platform_tech_proposal.action 非法: [$doc_platform_ACTION]" >&2
            exit 2
            ;;
        esac
        ;;
    esac
    # 分支命名 lint（仅执行类 user_decision + 非 user_specified 时强制校验）
    case "$DECISION" in
      execute_standard|execute_micro|execute_full|execute_partial|execute_batched)
        BRANCH_STATUS=$(jq -r '.outputs.branch_recommendation.branch_status // "missing"' "$JSON_FILE")
        if [ "$BRANCH_STATUS" != "user_specified" ]; then
          BRANCH_NAME=$(jq -r '.outputs.branch_recommendation.branch_workspace // .outputs.branch_recommendation.branch // ""' "$JSON_FILE")
          if [ -n "$BRANCH_NAME" ]; then
            SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
            BRANCH_LINT_RESULT=$("$SCRIPT_DIR/lints/branch-name-lint.sh" --raw "$BRANCH_NAME" 2>/dev/null; echo $?)
            if [ "$BRANCH_LINT_RESULT" != "0" ]; then
              echo "❌ 分支命名 lint 校验失败: $BRANCH_NAME" >&2
              "$SCRIPT_DIR/lints/branch-name-lint.sh" "$BRANCH_NAME" >&2
              echo "   修复：调整分支名使其符合 shared-rules.md §6 规范后重新运行校验。" >&2
              exit 2
            fi
          fi
        fi
        # branch_name_lint_passed 字段校验
        BRANCH_LINT_PASSED=$(jq -r '.outputs.branch_recommendation.branch_name_lint_passed // "missing"' "$JSON_FILE")
        if [ "$BRANCH_LINT_PASSED" != "true" ] && [ "$BRANCH_LINT_PASSED" != "user_specified_skip_lint" ]; then
          echo "❌ branch_recommendation.branch_name_lint_passed 必须为 true 或 user_specified_skip_lint [当前: $BRANCH_LINT_PASSED]" >&2
          exit 2
        fi
        ;;
    esac
    ;;
  step5)
    LINT_ERR=$(jq -r '.outputs.lint_errors_remaining // 999' "$JSON_FILE")
    if [ "$LINT_ERR" != "0" ]; then
      echo "❌ lint_errors_remaining 必须为 0 [当前: $LINT_ERR]" >&2
      exit 2
    fi
    FILES_COUNT=$(jq -r '.outputs.files_modified | length' "$JSON_FILE" 2>/dev/null || echo 0)
    if [ "$FILES_COUNT" = "0" ]; then
      echo "❌ files_modified 不能为空数组" >&2
      exit 2
    fi
    ;;
  step7_standard)
    for f in debug_code_cleaned devlog_generated knowledge_updated metrics_report_generated; do
      VAL=$(jq -r ".outputs.$f // \"missing\"" "$JSON_FILE")
      if [ "$VAL" != "true" ]; then
        echo "❌ outputs.$f 必须为 true [当前: $VAL]" >&2
        exit 2
      fi
    done
    # 单需求 HTML 报告字段校验（必须存在，flow_report_generated 允许 true/false 但不能缺失）
    FRG=$(jq -r '.outputs.flow_report_generated // "missing"' "$JSON_FILE")
    if [ "$FRG" = "missing" ]; then
      echo "❌ outputs.flow_report_generated 字段缺失（standard 模式必须执行 gen-flow-report.py 并填写此字段）" >&2
      exit 2
    fi
    if [ "$FRG" = "true" ]; then
      FRF=$(jq -r '.outputs.flow_report_file // "missing"' "$JSON_FILE")
      if ! echo "$FRF" | grep -qE '^flow-reports/.+\.html$'; then
        echo "❌ outputs.flow_report_file 必须匹配 ^flow-reports/.+\\.html$ [当前: $FRF]" >&2
        exit 2
      fi
    fi
    # P1 dev-logs 完整性自检（详见 references/gate-validator.md §「dev-logs 物理事实兜底（P0/P1 闭环）」 §P1）
    DLI=$(jq -r '.outputs.devlog_integrity_check // "missing"' "$JSON_FILE")
    case "$DLI" in
      clean|warns_*) ;;
      blocked_errors_*)
        echo "❌ devlog_integrity_check=$DLI 表示存在 ERROR，必须先修复 ~/.codebuddy/dev-logs/ 完整性问题（运行 scripts/lints/devlog-integrity-lint.sh 查看详情）" >&2
        exit 2
        ;;
      *)
        echo "❌ devlog_integrity_check 字段缺失或非法 [当前: $DLI]，必须运行 devlog-integrity-lint.sh --quiet 后填入 clean|warns_N|blocked_errors_N" >&2
        exit 2
        ;;
    esac
    ;;
  step7_full)
    # 完整执行 step-7：与 standard 类似，但 §K 推迟到步骤 10（与 H/I/J 同节奏）
    for f in debug_code_cleaned devlog_generated knowledge_updated metrics_report_generated; do
      VAL=$(jq -r ".outputs.$f // \"missing\"" "$JSON_FILE")
      if [ "$VAL" != "true" ]; then
        echo "❌ outputs.$f 必须为 true [当前: $VAL]" >&2
        exit 2
      fi
    done
    ;;
  step7_batch)
    # 批次执行 step-7：每批结束都校验，§K 强制
    COMMIT_MSG=$(jq -r '.outputs.commit_message // ""' "$JSON_FILE")
    [ -z "$COMMIT_MSG" ] && echo "❌ commit_message 不能为空（batch step-7）" >&2 && exit 2
    DEVLOG_APP=$(jq -r '.outputs.devlog_appended // ""' "$JSON_FILE")
    case "$DEVLOG_APP" in
      round_appended|monthly_appended) ;;
      *) echo "❌ devlog_appended 非法 [当前: $DEVLOG_APP]（应为 round_appended|monthly_appended）" >&2 && exit 2 ;;
    esac
    KD=$(jq -r '.outputs.knowledge_drift_checked // ""' "$JSON_FILE")
    case "$KD" in
      no_hits|appended_history|drift_recorded) ;;
      *) echo "❌ knowledge_drift_checked 非法 [当前: $KD]" >&2 && exit 2 ;;
    esac
    # P1 §K 校验（同 standard）
    DLI=$(jq -r '.outputs.devlog_integrity_check // "missing"' "$JSON_FILE")
    case "$DLI" in
      clean|warns_*) ;;
      blocked_errors_*)
        echo "❌ devlog_integrity_check=$DLI 表示存在 ERROR（batch step-7）" >&2
        exit 2
        ;;
      *)
        echo "❌ devlog_integrity_check 字段缺失或非法 [当前: $DLI]（batch step-7 必填）" >&2
        exit 2
        ;;
    esac
    ;;
  step7_micro_fix)
    # micro-fix 模式 step-7 校验：仅 H.1 commit + 主干分支兜底 + lint，不校验 devlog/knowledge/反思
    COMMIT_MSG=$(jq -r '.outputs.commit_message // ""' "$JSON_FILE")
    if [ -z "$COMMIT_MSG" ]; then
      echo "❌ commit_message 不能为空（micro-fix 仅 H.1 但 commit_message 必填）" >&2
      exit 2
    fi
    BRANCH_SAFE=$(jq -r '.outputs.branch_safe // "missing"' "$JSON_FILE")
    if [ "$BRANCH_SAFE" != "true" ]; then
      echo "❌ outputs.branch_safe 必须为 true（micro-fix 主干分支兜底校验）[当前: $BRANCH_SAFE]" >&2
      exit 2
    fi
    LINT_PASSED=$(jq -r '.outputs.read_lints_passed // "missing"' "$JSON_FILE")
    if [ "$LINT_PASSED" != "true" ]; then
      echo "❌ outputs.read_lints_passed 必须为 true（micro-fix 强制 lint 检查）[当前: $LINT_PASSED]" >&2
      exit 2
    fi
    # 反向校验：micro-fix 不应误填 devlog/knowledge/反思（按设计应为 false）
    for f in devlog_generated knowledge_updated reflection metrics_report_generated; do
      VAL=$(jq -r ".outputs.$f // \"absent\"" "$JSON_FILE")
      if [ "$VAL" = "true" ]; then
        echo "❌ outputs.$f 不应为 true（micro-fix 设计上跳过此环节，应为 false 或省略）[当前: $VAL]" >&2
        exit 2
      fi
    done
    ;;
  step10)
    for f in delivery_report devlog_generated knowledge_updated rules_archived; do
      VAL=$(jq -r ".outputs.$f // \"missing\"" "$JSON_FILE")
      if [ "$VAL" != "true" ]; then
        echo "❌ outputs.$f 必须为 true [当前: $VAL]" >&2
        exit 2
      fi
    done
    COMMIT_MSG=$(jq -r '.outputs.commit_message // ""' "$JSON_FILE")
    if [ -z "$COMMIT_MSG" ]; then
      echo "❌ commit_message 不能为空" >&2
      exit 2
    fi
    # 文档平台 归档同步结果校验
    doc_platform_SYNC=$(jq -r '.outputs.doc_platform_sync_result // "missing"' "$JSON_FILE")
    case "$doc_platform_SYNC" in
      synced|relinked|created|skipped_no_changes|skipped_user_opt_out) ;;
      *)
        echo "❌ doc_platform_sync_result 非法: [$doc_platform_SYNC]（必须是 synced|relinked|created|skipped_no_changes|skipped_user_opt_out 之一）" >&2
        exit 2
        ;;
    esac
    ;;
esac

echo "✅ [jq-only] 基础校验通过: step=$STEP_ID"
write_validation_checkpoint "$STEP_ID" "$FLOW_NAME" "jq-only"
exit 0
