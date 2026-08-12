#!/usr/bin/env bash
# ============================================================================
#  score.sh — confidence_score 计算器（基于 thresholds.yaml）
#  ----------------------------------------------------------------------------
#  作用：根据 confidence level + drift_count + days_since_merge，按 thresholds
#        .yaml 中的公式计算 0-100 整数 confidence_score。
#  ----------------------------------------------------------------------------
#  公式（与 references/confidence.md §confidence_score 计算约定一致）：
#    score = base[level]
#          + (drift == 0 ? bonus.no_drift : -penalty.per_drift * drift)
#          + (days_merged >= lifecycle.days_since_merge_stable ? bonus.merged_stable : 0)
#    score = clamp(score, clamp.min, clamp.max)
#  ----------------------------------------------------------------------------
#  数据驱动 + fallback 范式：
#    - 主路径：通过 yaml-bridge.sh 读取 config/thresholds.yaml + jq 抽字段
#    - 兜底：本文件顶部硬编码同名常量；yaml 解析失败时静默退化（stderr 提示）
#    - 修改 thresholds.yaml 后必须同步更新本文件 FALLBACK_* 常量
#  ----------------------------------------------------------------------------
#  CLI:
#    score.sh --level <verified|auto-verified|pending|scanned|draft|auto-stale|stale|archived|deprecated> \
#             --drift <int>  --days_merged <int>
#  退出码:
#    0 = 计算成功（stdout = 整数 0-100）
#    1 = 参数错误
#    2 = thresholds.yaml 读取失败但已 fallback（stderr 提示，仍输出整数）
#  ----------------------------------------------------------------------------
#  消费方：
#    - scripts/tests/test-score.sh （单元测试，6 数值 + 3 错误用例）
#    - scripts/lints/check-health.sh （已落盘 / 250 行 / 6.1 KB；不直接调 score 计算综合分，
#                                      而是复用本文件验证过的 yaml-bridge + jq + fallback 范式）
#  ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
THRESHOLDS_YAML="$SKILL_ROOT/config/thresholds.yaml"
YAML_BRIDGE="$SCRIPT_DIR/yaml-bridge.sh"

# ----------------------------------------------------------------------------
# Fallback 常量（与 thresholds.yaml 同步；yaml 解析失败时使用）
# 注意：macOS 默认 bash 3.2 不支持 declare -A，改用 case 函数实现 level→base 映射
# ----------------------------------------------------------------------------
fallback_base() {
  case "$1" in
    verified)        echo 95 ;;
    auto-verified)   echo 85 ;;
    pending)         echo 70 ;;
    scanned)         echo 60 ;;
    draft)           echo 50 ;;
    auto-stale)      echo 35 ;;
    stale)           echo 30 ;;
    archived)        echo 15 ;;
    deprecated)      echo 0 ;;
    *)               echo "" ;;
  esac
}
FALLBACK_BONUS_NO_DRIFT=5
FALLBACK_BONUS_MERGED_STABLE=3
FALLBACK_PENALTY_PER_DRIFT=5
FALLBACK_DAYS_SINCE_MERGE_STABLE=30
FALLBACK_CLAMP_MIN=0
FALLBACK_CLAMP_MAX=100

# ----------------------------------------------------------------------------
# 参数解析
# ----------------------------------------------------------------------------
usage() {
  cat >&2 <<'USAGE'
usage: score.sh --level <level> --drift <int> --days_merged <int>
  --level         confidence 等级（verified|auto-verified|pending|scanned|draft|
                  auto-stale|stale|archived|deprecated）
  --drift         drift_count 整数（>=0）
  --days_merged   距 base 合入天数（整数 >=0；未合入传 0）
USAGE
}

LEVEL=""
DRIFT=""
DAYS_MERGED=""

while [ $# -gt 0 ]; do
  case "$1" in
    --level)        LEVEL="${2:-}"; shift 2 ;;
    --drift)        DRIFT="${2:-}"; shift 2 ;;
    --days_merged)  DAYS_MERGED="${2:-}"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "score.sh: unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

# 必填校验
if [ -z "$LEVEL" ] || [ -z "$DRIFT" ] || [ -z "$DAYS_MERGED" ]; then
  echo "score.sh: --level / --drift / --days_merged 均为必填" >&2
  usage; exit 1
fi

# 数值校验
if ! [[ "$DRIFT" =~ ^[0-9]+$ ]]; then
  echo "score.sh: --drift 必须是非负整数（got: $DRIFT）" >&2; exit 1
fi
if ! [[ "$DAYS_MERGED" =~ ^[0-9]+$ ]]; then
  echo "score.sh: --days_merged 必须是非负整数（got: $DAYS_MERGED）" >&2; exit 1
fi

# level 合法性校验（与 thresholds.yaml base 字段保持同步）
case "$LEVEL" in
  verified|auto-verified|pending|scanned|draft|auto-stale|stale|archived|deprecated) : ;;
  *) echo "score.sh: 未知 level: $LEVEL" >&2; usage; exit 1 ;;
esac

# ----------------------------------------------------------------------------
# 加载阈值（主路径：yaml-bridge + jq；失败：fallback 常量）
# ----------------------------------------------------------------------------
BASE_VAL=""
BONUS_NO_DRIFT=""
BONUS_MERGED_STABLE=""
PENALTY_PER_DRIFT=""
DAYS_STABLE=""
CLAMP_MIN=""
CLAMP_MAX=""
DEGRADED=0

load_from_yaml() {
  if [ ! -r "$THRESHOLDS_YAML" ]; then return 1; fi
  if [ ! -x "$YAML_BRIDGE" ] && [ ! -r "$YAML_BRIDGE" ]; then return 1; fi
  command -v jq >/dev/null 2>&1 || return 1
  local json
  json=$(bash "$YAML_BRIDGE" yaml_to_json "$THRESHOLDS_YAML" 2>/dev/null) || return 1
  [ -z "$json" ] && return 1
  # 用 jq 一次性抽出全部字段（缺失即返回 null，下方判断）
  local fields
  fields=$(printf "%s" "$json" | jq -r --arg lv "$LEVEL" '[
    .confidence_score.base[$lv]   // empty,
    .confidence_score.bonus.no_drift // empty,
    .confidence_score.bonus.merged_stable // empty,
    .confidence_score.penalty.per_drift // empty,
    .lifecycle.days_since_merge_stable // empty,
    .confidence_score.clamp.min // empty,
    .confidence_score.clamp.max // empty
  ] | @tsv' 2>/dev/null) || return 1
  IFS=$'\t' read -r BASE_VAL BONUS_NO_DRIFT BONUS_MERGED_STABLE PENALTY_PER_DRIFT DAYS_STABLE CLAMP_MIN CLAMP_MAX <<<"$fields"
  # 任一字段为空 → 视为不完整，回退
  for v in "$BASE_VAL" "$BONUS_NO_DRIFT" "$BONUS_MERGED_STABLE" "$PENALTY_PER_DRIFT" "$DAYS_STABLE" "$CLAMP_MIN" "$CLAMP_MAX"; do
    [ -z "$v" ] && return 1
  done
  return 0
}

if ! load_from_yaml; then
  echo "score.sh: thresholds.yaml 不可用，使用 fallback 常量" >&2
  BASE_VAL="$(fallback_base "$LEVEL")"
  [ -z "$BASE_VAL" ] && BASE_VAL=0
  BONUS_NO_DRIFT=$FALLBACK_BONUS_NO_DRIFT
  BONUS_MERGED_STABLE=$FALLBACK_BONUS_MERGED_STABLE
  PENALTY_PER_DRIFT=$FALLBACK_PENALTY_PER_DRIFT
  DAYS_STABLE=$FALLBACK_DAYS_SINCE_MERGE_STABLE
  CLAMP_MIN=$FALLBACK_CLAMP_MIN
  CLAMP_MAX=$FALLBACK_CLAMP_MAX
  DEGRADED=1
fi

# ----------------------------------------------------------------------------
# 计算（公式：thresholds.yaml §confidence_score 注释中的公式）
# ----------------------------------------------------------------------------
SCORE=$BASE_VAL
if [ "$DRIFT" -eq 0 ]; then
  SCORE=$(( SCORE + BONUS_NO_DRIFT ))
else
  SCORE=$(( SCORE - PENALTY_PER_DRIFT * DRIFT ))
fi
if [ "$DAYS_MERGED" -ge "$DAYS_STABLE" ]; then
  SCORE=$(( SCORE + BONUS_MERGED_STABLE ))
fi
if [ "$SCORE" -lt "$CLAMP_MIN" ]; then SCORE=$CLAMP_MIN; fi
if [ "$SCORE" -gt "$CLAMP_MAX" ]; then SCORE=$CLAMP_MAX; fi
echo "$SCORE"
if [ "$DEGRADED" -eq 1 ]; then exit 2; fi
exit 0
