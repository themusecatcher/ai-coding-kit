#!/bin/bash
# doc-platform-lint.sh - 文档平台 技术方案决策门控（doc_platform_lint 7 项）
# 实现 references/gate-validator.md §「文档平台 技术方案决策门控」
#
# 7 项检查：
#   1. decision_made          决策必须已完成
#   2. action_valid           action 必须合法
#   3. probe_executed         空间探测必须已执行（auto_inherited_skip 豁免）
#   4. docid_when_update_relink  update/relink 时 matched_docid 非空
#   5. parent_docid_nonempty   create 时 parent_docid 非空
#   6. create_update_closure   create/update 时必须完成发布闭环
#   7. parent_docid_verified   create 时 parent_docid 必须为合法子类型目录（非个人空间首页）
#
# 用法:
#   bash doc-platform-lint.sh <step-4-json-file>
#   bash doc-platform-lint.sh --raw <step-4-json-file>  # 仅返回退出码
#
# 输入：step-4 完成标记 JSON（含 outputs.user_decision 和 outputs.doc_platform_tech_proposal）
# 返回码：0 全部通过；1 任一项失败；2 参数/文件错误；3 缺工具

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/lib/audit.sh"

MODE="json"
[ "${1:-}" = "--raw" ] && { MODE="raw"; shift; }

JSON_FILE="${1:-}"
if [ -z "$JSON_FILE" ]; then
  log_error "用法: $0 [--raw] <step-4-json-file>"
  exit 2
fi
if [ ! -f "$JSON_FILE" ]; then
  log_error "文件不存在: $JSON_FILE"
  exit 2
fi
if ! df_has_jq; then
  log_error "需要 jq 工具"
  exit 3
fi
if ! df_jq_validate "$JSON_FILE"; then
  log_error "JSON 格式错误"
  exit 2
fi

# 读取关键字段
USER_DECISION=$(jq -r '.outputs.user_decision // empty' "$JSON_FILE")
doc_platform=$(jq -c '.outputs.doc_platform_tech_proposal // {}' "$JSON_FILE")
DECISION_MADE=$(echo "$doc_platform" | jq -r '.decision_made // false')
ACTION=$(echo "$doc_platform" | jq -r '.action // empty')
PROBE_EXECUTED=$(echo "$doc_platform" | jq -r '.probe_executed // false')
MATCHED_DOCID=$(echo "$doc_platform" | jq -r '.matched_docid // empty')
PARENT_DOCID=$(echo "$doc_platform" | jq -r '.parent_docid // empty')
DOCID=$(echo "$doc_platform" | jq -r '.docid // empty')
STATUS=$(echo "$doc_platform" | jq -r '.status // empty')
TRIGGER_STEP=$(echo "$doc_platform" | jq -r '.trigger_step // empty')

[ "$MODE" = "json" ] && {
  log_info "文档平台 决策门控校验"
  log_kv "user_decision" "${USER_DECISION:-(none)}"
  log_kv "decision_made" "$DECISION_MADE"
  log_kv "action" "${ACTION:-(none)}"
  log_kv "probe_executed" "$PROBE_EXECUTED"
  log_kv "docid" "${DOCID:-(none)}"
  log_kv "status" "${STATUS:-(none)}"
}

# ========================================
# 仅当 user_decision 属于执行类时强制校验
# ========================================
case "$USER_DECISION" in
  execute_standard|execute_micro|execute_full|execute_partial|execute_batched)
    # 进入硬性校验流程
    ;;
  modify|change_plan|pause|cancel|"")
    # 非执行类决策，doc_platform_lint 不强制
    [ "$MODE" = "json" ] && log_pass "user_decision=$USER_DECISION 非执行类，doc_platform_lint 跳过"
    exit 0
    ;;
  *)
    log_error "未知 user_decision: $USER_DECISION"
    exit 2
    ;;
esac

violations=()

# ========================================
# 项 1：decision_made 必须为 true（含 auto_inherited_skip）
# ========================================
if [ "$DECISION_MADE" != "true" ]; then
  violations+=("decision_made: 必须为 true（实际: ${DECISION_MADE}）")
fi

# ========================================
# 项 2：action_valid（合法 action）
# ========================================
case "$ACTION" in
  create|update|relink|skip|auto_inherited_skip)
    ;;
  *)
    violations+=("action: 非法值 '${ACTION}'（合法: create|update|relink|skip|auto_inherited_skip）")
    ;;
esac

# ========================================
# 项 3：probe_executed（除 auto_inherited_skip 外必须为 true）
# ========================================
if [ "$ACTION" != "auto_inherited_skip" ]; then
  if [ "$PROBE_EXECUTED" != "true" ]; then
    violations+=("probe_executed: 必须为 true（仅 auto_inherited_skip 豁免）")
  fi
fi

# ========================================
# 项 4：docid_when_update_relink（update/relink 时 matched_docid 非空）
# ========================================
if [ "$ACTION" = "update" ] || [ "$ACTION" = "relink" ]; then
  if [ -z "$MATCHED_DOCID" ] || [ "$MATCHED_DOCID" = "null" ]; then
    violations+=("matched_docid: action=${ACTION} 时必须非空")
  fi
fi

# ========================================
# 项 5：parent_docid_when_create（create 时 parent_docid 非空）
# ========================================
if [ "$ACTION" = "create" ]; then
  if [ -z "$PARENT_DOCID" ] || [ "$PARENT_DOCID" = "null" ]; then
    violations+=("parent_docid: action=create 时必须非空（feat/fix/opt/refactor 子类 docid 之一）")
  fi
fi

# ========================================
# 项 6：create_update_closure（create/update 时必须完成发布闭环）
# ========================================
# 设计原则：
#   action=create/update 必须在步骤 4 环节 4 内立即完成创建/保存，
#   不允许把发布动作延后到步骤 5/7/10。
# 闭环条件（任一失败即违规）：
#   1. file_path 或 docid 非空（已发布或已关联）
#   2. status == "synced"（同步状态正确）
#   3. trigger_step == "immediate"（明示步骤 4 内已立即执行）
if [ "$ACTION" = "create" ] || [ "$ACTION" = "update" ]; then
  if [ -z "${DOCID:-}" ] || [ "${DOCID:-}" = "null" ]; then
    violations+=("docid: action=${ACTION} 时必须非空（须在步骤 4 环节 4 内立即完成创建/保存）")
  fi
  if [ "${STATUS:-}" != "synced" ]; then
    violations+=("status: action=${ACTION} 时必须为 synced（实际: ${STATUS:-empty}）；不允许延后到步骤 5/7/10 发布")
  fi
  if [ -n "${TRIGGER_STEP:-}" ] && [ "${TRIGGER_STEP:-}" != "immediate" ]; then
    case "${TRIGGER_STEP:-}" in
      step-5-5b|step-7-h3plus|step-10-archive)
        violations+=("trigger_step: action=${ACTION} 时只允许 immediate（实际: ${TRIGGER_STEP}，已废弃枚举）")
        ;;
      none)
        violations+=("trigger_step: action=${ACTION} 时只允许 immediate（实际: none）；none 仅适用于 action ∈ {skip, auto_inherited_skip, relink}")
        ;;
      *)
        violations+=("trigger_step: action=${ACTION} 时只允许 immediate（实际: ${TRIGGER_STEP}）；合法枚举: immediate | none")
        ;;
    esac
  fi
fi

# ========================================
# 项 7：parent_docid_verified（create 时 parent_docid 必须为合法子类型目录，非个人空间首页）
# 背景：AI 可能将文档误建到个人空间首页而非技术方案/feat/ 目录，
#       旧项 5 只查非空不查正确性。
# 设计：从 config/doc-platform-config.yaml 动态读取所有合法 parent_docid，
#       校验 JSON 中的 parent_docid 在其中。不使用硬编码数字，
#       配置变更（如新增子类型）无需改脚本。
# 豁免：action=skip/auto_inherited_skip/relink 时不检查（不涉及创建）。
# ========================================
CONFIG_FILE="$HOME/.codebuddy/skills/tech-doc/config/doc-platform-config.yaml"
PARENT_FOUND=0
if [ "$ACTION" = "create" ] && [ -f "$CONFIG_FILE" ]; then
  # 修复（2026-08-07）：
  #   ① 配置真实字段名是 parent_id（旧脚本 grep parent_docid 恒匹配不到 →
  #      VALID_PARENT_IDS 永远为空 → 项 7 静默降级为非空检查 → 门控完全失效）。
  #   ② 旧 grep -A8 'subtypes:' 只能覆盖 feat/fix，漏掉 opt/refactor。
  #   现改为：全局提取所有 parent_id（兼容旧 parent_docid），排除占位 0；
  #   并显式识别 homepage_id 为「个人空间首页」非法目标。
  HOMEPAGE_ID=$(grep -E '^[[:space:]]*homepage_id:' "$CONFIG_FILE" | grep -oE '[0-9]+' | head -1)
  VALID_PARENT_IDS=$( { grep -E '^[[:space:]]*parent_id:' "$CONFIG_FILE"; grep -E '^[[:space:]]*parent_docid:' "$CONFIG_FILE"; } \
                | grep -oE '[0-9]+' | grep -vxE '0' | sort -u | tr '\n' ' ')
  VALID_PARENT_IDS="${VALID_PARENT_IDS% }"

  if [ -n "${HOMEPAGE_ID:-}" ] && [ "${HOMEPAGE_ID}" != "0" ] && [ "${PARENT_DOCID:-}" = "$HOMEPAGE_ID" ]; then
    # 显式非法：误把个人空间首页当作父节点
    violations+=("parent_docid: action=create 时 parent_docid=${PARENT_DOCID} 命中个人空间首页 homepage_id=${HOMEPAGE_ID}；应发布到技术方案子类型目录（feat/fix/opt/refactor）")
  elif [ -n "${VALID_PARENT_IDS:-}" ]; then
    for vid in $VALID_PARENT_IDS; do
      if [ "${PARENT_DOCID:-}" = "$vid" ]; then
        PARENT_FOUND=1
        break
      fi
    done
    if [ "$PARENT_FOUND" -eq 0 ]; then
      violations+=("parent_docid: action=create 时 parent_docid=${PARENT_DOCID:-empty} 不在合法子类型目录中（合法值: ${VALID_PARENT_IDS}）；误用了个人空间首页或其他非技术方案目录")
    fi
  else
    # 降级：配置全为占位 0（未部署真实 ID）时仍做非空检查（项 5 已覆盖）
    [ "$MODE" = "json" ] && log_warn "⚠️  config 中无非占位 parent_id，parent_docid 降级为非空检查"
  fi
elif [ "$ACTION" = "create" ] && [ ! -f "$CONFIG_FILE" ]; then
  [ "$MODE" = "json" ] && log_warn "⚠️  config/doc-platform-config.yaml 不存在，parent_docid 降级为非空检查"
fi

# ========================================
# 输出
# ========================================
if [ "$MODE" = "json" ]; then
  echo ""
  if [ ${#violations[@]} -gt 0 ]; then
    log_fail "doc_platform_lint 失败：${#violations[@]} 项违规"
    for v in "${violations[@]}"; do
      echo "    - $v" >&2
    done
    df_audit_redcard "doc_platform_lint" file="$JSON_FILE" decision="$USER_DECISION" action="$ACTION"
    exit 1
  fi
  log_pass "doc_platform_lint 全部通过"
  df_audit_gate_pass "doc_platform_lint" file="$JSON_FILE" action="$ACTION"
  exit 0
else
  # raw 模式：仅退出码
  [ ${#violations[@]} -gt 0 ] && exit 1
  exit 0
fi
