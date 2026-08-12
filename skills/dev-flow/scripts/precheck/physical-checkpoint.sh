#!/bin/bash
# physical-checkpoint.sh - 物理检查点白名单预检
# 实现 references/gate-validator.md §「物理检查点白名单（按基础模式分流）」
#
# 用法:
#   bash physical-checkpoint.sh <flow-name> <target-step-id>
#
# 输入:
#   flow-name      .active-flows/{name}.flow 的 name 部分
#   target-step-id 即将加载的下一步骤 ID（如 5 / 4.5 / 7-standard）
#
# 输出: 简明合规报告 + 缺失检查点清单
# 返回码:
#   0 通过；可加载 target-step
#   1 缺失前置 .validated 文件（红牌 #14）
#   2 mode 解析失败 / 配置错误
#   3 工具缺失

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/lib/audit.sh"

FLOW_NAME="${1:-}"
TARGET_STEP="${2:-}"
ACTIVE_FLOWS="$(df_active_flows_dir)"
GATES_YAML="$DEV_FLOW_ROOT/config/gates.yaml"

if [ -z "$FLOW_NAME" ] || [ -z "$TARGET_STEP" ]; then
  log_error "用法: $0 <flow-name> <target-step-id>"
  log_info  "示例: $0 20260514_feat_用户登录 5"
  exit 2
fi

# ========================================
# 步骤 1：定位 .flow 文件
# ========================================
FLOW_FILE="$ACTIVE_FLOWS/${FLOW_NAME}.flow"
if [ ! -f "$FLOW_FILE" ]; then
  log_error ".flow 文件不存在: $FLOW_FILE"
  exit 2
fi

# ========================================
# 步骤 2：读取 mode（支持 mode_history.from 优先）
# ========================================
MODE=$(df_get_flow_mode "$FLOW_FILE")
MODE_HISTORY_FROM=$(df_get_flow_field "$FLOW_FILE" "mode_history_from")
[ -z "$MODE" ] && MODE="standard"

log_info "Flow=$FLOW_NAME, mode=$MODE, target=step-$TARGET_STEP"
[ -n "$MODE_HISTORY_FROM" ] && log_info "  mode_history_from=$MODE_HISTORY_FROM"

# ========================================
# 步骤 3：白名单矩阵（与 gate-validator.md §物理检查点白名单 完全对齐）
# ========================================
get_required_steps() {
  local mode="$1"
  case "$mode" in
    standard)
      echo "1 2 3 4 4_5 5 5_5 6 7"
      ;;
    full)
      # 完整执行：standard 全部 + 8/9/10
      echo "1 2 3 4 4_5 5 5_5 6 7 8 9 10"
      ;;
    micro-fix)
      # micro-fix v2 轻量保留：仅 4.5 → 7
      echo "4_5 5 5_5 6 7"
      ;;
    iteration-fix)
      # 迭代修复：跳过 1-4
      echo "4_5 5 5_5 6 7"
      ;;
    batch)
      # 批次执行：批次内按 standard 链路
      echo "1 2 3 4 4_5 5 5_5 6 7"
      ;;
    cross-project)
      # 同 standard
      echo "1 2 3 4 4_5 5 5_5 6 7"
      ;;
    *)
      log_warn "未知 mode=$mode，回退到 standard 白名单"
      echo "1 2 3 4 4_5 5 5_5 6 7"
      ;;
  esac
}

REQUIRED_STEPS=$(get_required_steps "$MODE")

# ========================================
# 步骤 4：规范化 target-step ID 用于比较
# ========================================
TARGET_NORM=$(df_normalize_step_id "$TARGET_STEP")

# 跨步骤比较（用浮点数比较）
step_lt() {
  # $1 < $2 ?  返回 0=yes
  local a b
  # 把 _ 还原成 . 用于浮点比较
  a=$(echo "$1" | tr '_' '.' | sed 's/[^0-9.]//g')
  b=$(echo "$2" | tr '_' '.' | sed 's/[^0-9.]//g')
  [ -z "$a" ] && a=0
  [ -z "$b" ] && b=0
  awk -v x="$a" -v y="$b" 'BEGIN{exit !(x+0 < y+0)}'
}

# ========================================
# 步骤 5：逐项校验白名单中"位于 target 之前"的检查点
# ========================================
missing=0
checked=0
missing_list=()
existing=0

for step in $REQUIRED_STEPS; do
  # 仅校验 target 之前的检查点
  if ! step_lt "$step" "$TARGET_NORM"; then
    continue
  fi
  checked=$((checked + 1))
  
  validated_file="$ACTIVE_FLOWS/${FLOW_NAME}.step-${step}.validated"
  legacy_done_file="$ACTIVE_FLOWS/${FLOW_NAME}.step-${step}.done"
  
  if [ -f "$validated_file" ]; then
    log_pass "前置检查点已存在: step-$step"
    existing=$((existing + 1))
  elif [ -f "$legacy_done_file" ]; then
    log_pass "前置检查点已存在（旧版 .done 兼容）: step-$step"
    existing=$((existing + 1))
  else
    log_fail "🔴 缺失前置物理检查点: step-$step"
    missing_list+=("$validated_file")
    missing=$((missing + 1))
  fi
done

# ========================================
# 步骤 5bis：pre-v3 流程宽容模式
# ========================================
#仅对「v3 重构（2026-05-14）之前创建」的旧流程放宽，让其平滑过渡。
# 修复（2026-08-07）：原逻辑条件①「完全没有 .validated 文件」会把「全新流程
# 且中间产物缺失」误判为 pre-v3 而绕过红牌 #14（全新流程同样是 0 个 .validated），
# 造成物理检查点门控形同虚设。现改为：.flow 的 mtime 是判定 pre-v3 的「权威且
# 必要」条件——mtime 晚于 v3 日期的流程一律不宽容；仅当 mtime 早于 v3（或存在
# 旧版 .done 后缀这一v1/v2 独有产物）时才降级为警告。
is_pre_v3_flow=false
if [ $checked -gt 0 ] && [ $missing -gt 0 ]; then
  # v3 重构日期 2026-05-14 00:00 = epoch 1778803200
  V3_EPOCH=1778803200
  flow_mtime=""
  if [ -f "$ACTIVE_FLOWS/${FLOW_NAME}.flow" ]; then
    flow_mtime=$(stat -f %m "$ACTIVE_FLOWS/${FLOW_NAME}.flow" 2>/dev/null \
                  || stat -c %Y "$ACTIVE_FLOWS/${FLOW_NAME}.flow" 2>/dev/null)
  fi

  # 权威条件 A：.flow mtime 早于 v3 重构日期 → 确属旧流程
  if [ -n "$flow_mtime" ] && [ "$flow_mtime" -lt "$V3_EPOCH" ] 2>/dev/null; then
    is_pre_v3_flow=true
  fi
  # 权威条件 B：存在 .done 旧后缀（v1/v2 独有产物，v3 用 .validated）→ 跨周期旧流程
  if ls "$ACTIVE_FLOWS/${FLOW_NAME}".step-*.done 2>/dev/null | head -1 | grep -q "\.done$"; then
    is_pre_v3_flow=true
  fi
  # 注意：不再以「.validated 全空」单独作为 pre-v3 依据 —— 全新流程同样全空，
  # 若中间产物缺失必须报红牌 #14，不得宽容放行。
fi

# ========================================
# 步骤 6：汇总
# ========================================
echo ""
log_kv "已检查检查点" "$checked"
log_kv "缺失数量" "$missing"

if [ "$is_pre_v3_flow" = "true" ]; then
  log_warn "⚠️ 检测到 pre-v3 流程（无任何 .validated 检查点）"
  echo "    流程在 v3 重构（2026-05-14）之前创建，按宽容模式处理：" >&2
  echo "    - 不报红牌 #14，允许旧流程继续推进" >&2
  echo "    - 建议：从下次步骤完成开始用 validate-output.sh 写入新检查点" >&2
  df_audit "physical_checkpoint.pre_v3_flow" "pre-v3 flow detected, downgrading to warning" \
           flow="$FLOW_NAME" target="$TARGET_STEP" missing="$missing"
  log_pass "✅ pre-v3 兼容模式通过：可加载 step-$TARGET_STEP"
  exit 0
fi

if [ $missing -gt 0 ]; then
  log_fail "🔴 红牌 #14: 缺失 $missing 个前置物理检查点"
  echo "缺失文件清单：" >&2
  for f in "${missing_list[@]}"; do
    echo "    - $f" >&2
  done
  echo "" >&2
  echo "处理建议：" >&2
  echo "  1. 回退到对应步骤，重新执行 validate-output.sh" >&2
  echo "  2. 调用：bash $DEV_FLOW_ROOT/scripts/validate-output.sh <step-id> <json-file> $FLOW_NAME" >&2
  
  df_audit_redcard "physical_checkpoint_missing" flow="$FLOW_NAME" target="$TARGET_STEP" missing="$missing"
  exit 1
fi

log_pass "物理检查点预检通过：可加载 step-$TARGET_STEP"
df_audit_gate_pass "physical_checkpoint" flow="$FLOW_NAME" target="$TARGET_STEP" mode="$MODE" checked="$checked"
exit 0
