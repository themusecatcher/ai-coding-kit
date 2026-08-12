#!/bin/bash
# state-machine.sh - dev-flow 步骤状态机驱动
# 把流程总览表 + 步骤 7 执行深度分支等代码化，AI 通过查询脚本而非记忆来决策
#
# 用法:
#   bash state-machine.sh --query-next --current=<step> --mode=<mode> [--status=<status>] [--batch-current=N --batch-total=N]
#   bash state-machine.sh --query-valid --current=<step> --mode=<mode>
#   bash state-machine.sh --query-step7-variant --mode=<mode> [--batch-final=true]
#   bash state-machine.sh --query-step5_5-variant --mode=<mode>
#   bash state-machine.sh --query-step6-variant --mode=<mode>
#   bash state-machine.sh --list-steps --mode=<mode>
#   bash state-machine.sh --help
#
# 返回码:
#   0 查询成功（结果输出到 stdout）
#   1 不合法的转移
#   2 参数错误

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/lib/audit.sh"

# ========================================
# 参数解析
# ========================================
ACTION=""
CURRENT=""
MODE=""
STATUS="completed"
BATCH_CURRENT=""
BATCH_TOTAL=""
BATCH_FINAL="false"

for arg in "$@"; do
  case "$arg" in
    --query-next)            ACTION="query-next" ;;
    --query-valid)           ACTION="query-valid" ;;
    --query-step7-variant)   ACTION="query-step7" ;;
    --query-step5_5-variant) ACTION="query-step5_5" ;;
    --query-step6-variant)   ACTION="query-step6" ;;
    --list-steps)            ACTION="list-steps" ;;
    --current=*)             CURRENT="${arg#--current=}" ;;
    --mode=*)                MODE="${arg#--mode=}" ;;
    --status=*)              STATUS="${arg#--status=}" ;;
    --batch-current=*)       BATCH_CURRENT="${arg#--batch-current=}" ;;
    --batch-total=*)         BATCH_TOTAL="${arg#--batch-total=}" ;;
    --batch-final=*)         BATCH_FINAL="${arg#--batch-final=}" ;;
    --help|-h)
      sed -n '2,15p' "$0"
      exit 0
      ;;
  esac
done

if [ -z "$ACTION" ]; then
  log_error "缺少 action（--query-next / --query-valid / --query-step7-variant / --query-step5_5-variant / --query-step6-variant / --list-steps）"
  exit 2
fi

# ========================================
# 模式 → 完整步骤列表
# ========================================
# v3.1: 优先从 gates.yaml::state_machine.step_sequences 读取
# YAML 解析失败时回退到硬编码 fallback
_fallback_get_steps_for_mode() {
  case "$1" in
    standard|cross-project|batch)
      echo "0 0.5 1 2 3 4 4.5 5 5.5 6 7"
      ;;
    full)
      echo "0 0.5 1 2 3 4 4.5 5 5.5 6 7 8 9 10"
      ;;
    micro-fix|iteration-fix)
      echo "0 4.5 5 5.5 6 7"
      ;;
    wrap-standard)
      echo "7"
      ;;
    wrap-full)
      echo "7 8 9 10"
      ;; 
    *)
      log_error "未知 mode: $1"
      return 1
      ;;
  esac
}

get_steps_for_mode() {
  local mode="$1"
  local gates_yaml="${DF_GATES_YAML:-$DEV_FLOW_ROOT/config/gates.yaml}"
  local steps=""
  
  # 优先从 gates.yaml 读取（v3.1 数据驱动）
  if [ -f "$gates_yaml" ] && type df_get_yaml_list >/dev/null 2>&1; then
    steps=$(df_get_yaml_list "$gates_yaml" "state_machine.step_sequences.$mode" 2>/dev/null) || steps=""
  fi
  
  # YAML 读取失败 → 回退到硬编码
  if [ -z "$steps" ]; then
    _fallback_get_steps_for_mode "$mode"
    return $?
  fi
  
  echo "$steps"
}

# ========================================
# 查询下一步骤
# ========================================
query_next() {
  [ -z "$CURRENT" ] || [ -z "$MODE" ] && {
    log_error "需要 --current 和 --mode 参数"
    return 2
  }
  
  # 步骤 7 是终结点（standard/batch/iteration-fix/micro-fix/cross-project）
  # 仅 full 模式 7 → 8 → 9 → 10
  
  local steps
  steps=$(get_steps_for_mode "$MODE") || return 2
  
  # batch 模式特殊：步骤 7 完成后判断是否最后一批
  if [ "$MODE" = "batch" ] && [ "$CURRENT" = "7" ]; then
    if [ -n "$BATCH_CURRENT" ] && [ -n "$BATCH_TOTAL" ]; then
      if [ "$BATCH_CURRENT" -lt "$BATCH_TOTAL" ]; then
        echo "4.5"  # 进入下一批次循环
        return 0
      else
        echo "end"  # 所有批次完成
        return 0
      fi
    fi
  fi
  
  # 通用：找到 current 在列表中的位置，返回下一个
  local found=false
  for s in $steps; do
    if [ "$found" = "true" ]; then
      echo "$s"
      return 0
    fi
    [ "$s" = "$CURRENT" ] && found=true
  done
  
  # 没找到 next（current 是最后一步）
  if [ "$found" = "true" ]; then
    echo "end"
    return 0
  fi
  
  log_error "current=$CURRENT 不在 mode=$MODE 的步骤列表中"
  return 1
}

# ========================================
# 查询合法转移
# ========================================
query_valid() {
  [ -z "$CURRENT" ] || [ -z "$MODE" ] && {
    log_error "需要 --current 和 --mode 参数"
    return 2
  }
  
  local steps
  steps=$(get_steps_for_mode "$MODE") || return 2
  
  # 合法转移 = next + 重做当前步骤
  # 输出 JSON 数组格式
  local found=false
  local next=""
  for s in $steps; do
    if [ "$found" = "true" ]; then
      next="$s"
      break
    fi
    [ "$s" = "$CURRENT" ] && found=true
  done
  
  if [ -n "$next" ]; then
    echo "[\"$next\", \"$CURRENT\"]"
  else
    echo "[\"end\", \"$CURRENT\"]"
  fi
  return 0
}

# ========================================
# 查询步骤 7 的子类型（standard/full/batch/micro-fix）
# ========================================
# v3.1: 优先从 gates.yaml::state_machine.step7_variants 读取
_fallback_query_step7_variant() {
  case "$MODE" in
    standard|cross-project)
      echo "step7_standard"
      ;;
    full)
      echo "step7_full"
      ;;
    batch)
      if [ "$BATCH_FINAL" = "true" ]; then
        echo "step7_standard"  # 最后一批走标准
      else
        echo "step7_batch"
      fi
      ;;
    micro-fix)
      echo "step7_micro_fix"
      ;;
    iteration-fix)
      echo "step7_standard"  # 迭代修复走标准 step7（commit + devlog）
      ;;
    *)
      log_error "mode=$MODE 不支持步骤 7 子类型查询"
      return 2
      ;;
  esac
}

query_step7_variant() {
  [ -z "$MODE" ] && {
    log_error "需要 --mode 参数"
    return 2
  }
  
  local gates_yaml="${DF_GATES_YAML:-$DEV_FLOW_ROOT/config/gates.yaml}"
  local variant=""
  local yaml_key=""
  
  # 构造 YAML key：batch 模式按 BATCH_FINAL 区分
  if [ "$MODE" = "batch" ]; then
    if [ "$BATCH_FINAL" = "true" ]; then
      yaml_key="state_machine.step7_variants.batch_final"
    else
      yaml_key="state_machine.step7_variants.batch_not_final"
    fi
  else
    yaml_key="state_machine.step7_variants.$MODE"
  fi
  
  # 优先从 gates.yaml 读取（v3.1 数据驱动）
  if [ -f "$gates_yaml" ] && type df_get_yaml_value >/dev/null 2>&1; then
    variant=$(df_get_yaml_value "$gates_yaml" "$yaml_key" 2>/dev/null) || variant=""
  fi
  
  # YAML 读取失败 → 回退到硬编码
  if [ -z "$variant" ]; then
    _fallback_query_step7_variant
    return $?
  fi
  
  echo "$variant"
}

# ========================================
# 查询步骤 5.5 的子类型（standard / micro-fix）
# ========================================
_fallback_query_step5_5_variant() {
  case "$MODE" in
    micro-fix)
      echo "step5_5_micro_fix"
      ;;
    standard|full|batch|cross-project|iteration-fix)
      echo "step5_5"
      ;;
    *)
      log_error "mode=$MODE 不支持步骤 5.5 子类型查询"
      return 2
      ;;
  esac
}

query_step5_5_variant() {
  [ -z "$MODE" ] && {
    log_error "需要 --mode 参数"
    return 2
  }

  local gates_yaml="${DF_GATES_YAML:-$DEV_FLOW_ROOT/config/gates.yaml}"
  local variant=""
  local yaml_key="state_machine.step5_5_variants.$MODE"

  # 优先从 gates.yaml 读取
  if [ -f "$gates_yaml" ] && type df_get_yaml_value >/dev/null 2>&1; then
    variant=$(df_get_yaml_value "$gates_yaml" "$yaml_key" 2>/dev/null) || variant=""
  fi

  # YAML 读取失败 → 回退到硬编码
  if [ -z "$variant" ]; then
    _fallback_query_step5_5_variant
    return $?
  fi

  echo "$variant"
}

# ========================================
# 查询步骤 6 的子类型（standard / micro-fix）
# ========================================
_fallback_query_step6_variant() {
  case "$MODE" in
    micro-fix)
      echo "step6_micro_fix"
      ;;
    standard|full|batch|cross-project|iteration-fix)
      echo "step6"
      ;;
    *)
      log_error "mode=$MODE 不支持步骤 6 子类型查询"
      return 2
      ;;
  esac
}

query_step6_variant() {
  [ -z "$MODE" ] && {
    log_error "需要 --mode 参数"
    return 2
  }

  local gates_yaml="${DF_GATES_YAML:-$DEV_FLOW_ROOT/config/gates.yaml}"
  local variant=""
  local yaml_key="state_machine.step6_variants.$MODE"

  # 优先从 gates.yaml 读取
  if [ -f "$gates_yaml" ] && type df_get_yaml_value >/dev/null 2>&1; then
    variant=$(df_get_yaml_value "$gates_yaml" "$yaml_key" 2>/dev/null) || variant=""
  fi

  # YAML 读取失败 → 回退到硬编码
  if [ -z "$variant" ]; then
    _fallback_query_step6_variant
    return $?
  fi

  echo "$variant"
}

# ========================================
# 列出步骤
# ========================================
list_steps() {
  [ -z "$MODE" ] && {
    log_error "需要 --mode 参数"
    return 2
  }
  
  local steps
  steps=$(get_steps_for_mode "$MODE") || return 2
  
  # 输出 JSON 数组
  local first=true
  echo -n "["
  for s in $steps; do
    [ "$first" = "true" ] && first=false || echo -n ","
    echo -n "\"$s\""
  done
  echo "]"
}

# ========================================
# 主调度
# ========================================
case "$ACTION" in
  query-next)            query_next ;;
  query-valid)           query_valid ;;
  query-step7)           query_step7_variant ;;
  query-step5_5)         query_step5_5_variant ;;
  query-step6)           query_step6_variant ;;
  list-steps)            list_steps ;;
  *)
    log_error "未知 action: $ACTION"
    exit 2
    ;;
esac
