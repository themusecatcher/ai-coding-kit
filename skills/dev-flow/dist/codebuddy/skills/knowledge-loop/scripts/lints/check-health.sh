#!/usr/bin/env bash
# ============================================================================
#  check-health.sh — 知识库整库健康度评分（基于 thresholds.yaml::health）
#  ----------------------------------------------------------------------------
#  作用：扫描指定目录下所有 *.md，逐文件抽取 frontmatter，按 thresholds.yaml
#        中预定的公式计算整库健康度综合分（0-100），输出绿/黄/红 grade。
#  ----------------------------------------------------------------------------
#  评分公式（thresholds.yaml::health）：
#    health = w_coverage * coverage% + w_freshness * freshness% + w_drift * (100 - drift%)
#  ----------------------------------------------------------------------------
#  当前 Phase 3 阶段实现（与 §refactor-plan §9.2 决策 C-2 一致）：
#    - coverage：暂置为 100（待 sync 完整跑通后再启用），权重转嫁
#    - freshness：按 last_verified（无则 created）距今天数，
#                 ≤fresh_max_days(30) 满分 100；≥decay_max_days(180) 0 分；
#                 中间线性衰减
#    - drift：drift_count > 0 的文件占比 → drift% = ratio * 100
#  ----------------------------------------------------------------------------
#  失败/异常处理：
#    - 无 frontmatter 的文件不计入分母（视为非知识条目）
#    - 缺 last_verified 也缺 created → freshness 视为 0（最旧）
#    - 缺 drift_count → 视为 0（无漂移）
#  ----------------------------------------------------------------------------
#  数据驱动 + fallback：
#    - 主路径：yaml-bridge.sh + jq 读 thresholds.yaml
#    - 兜底：本文件顶部 FALLBACK_* 常量（与 thresholds.yaml::health 同步）
#  ----------------------------------------------------------------------------
#  消费方：
#    - scripts/tests/test-check-health.sh （端到端单测，4 用例）
#    - SKILL.md「执行链路」章节（lint 表 Phase 3 新增项）
#    - dev:kb health 高层命令的 sanity gate
#  ----------------------------------------------------------------------------
#  CLI:
#    check-health.sh <dir>
#  退出码：
#    0 = 综合分 >= healthy_min（绿）
#    1 = 综合分 < healthy_min（黄/红） / 输入错
#    2 = 必需依赖缺失，已尽力降级
#  最后一行机器可解析输出：RESULT: ok | warn | fail | degraded
#  ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
THRESHOLDS_YAML="$SKILL_ROOT/config/thresholds.yaml"
YAML_BRIDGE="$SKILL_ROOT/scripts/lib/yaml-bridge.sh"

# 颜色（仅 tty）
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_DIM=""; C_RESET=""
fi

have() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------------------
# Fallback 常量（与 thresholds.yaml::health 同步；yaml 解析失败时使用）
# ----------------------------------------------------------------------------
FALLBACK_W_COVERAGE=40       # 0.4 * 100，整数算术
FALLBACK_W_FRESHNESS=30      # 0.3 * 100
FALLBACK_W_DRIFT=30          # 0.3 * 100
FALLBACK_HEALTHY_MIN=80
FALLBACK_WARNING_MIN=60
FALLBACK_FRESH_MAX_DAYS=30
FALLBACK_DECAY_MAX_DAYS=180

# ----------------------------------------------------------------------------
# 参数解析
# ----------------------------------------------------------------------------
usage() {
  cat >&2 <<'USAGE'
usage: check-health.sh <dir>
  扫描目录下所有 *.md，按 thresholds.yaml::health 计算整库健康度综合分。
USAGE
}

if [ $# -ne 1 ]; then
  usage; echo "RESULT: fail"; exit 1
fi

ROOT="$1"
if [ ! -d "$ROOT" ]; then
  echo "check-health: not a directory: $ROOT" >&2
  echo "RESULT: fail"; exit 1
fi

# 收集 *.md 列表
TARGETS=()
while IFS= read -r f; do TARGETS+=("$f"); done < <(find "$ROOT" -type f -name "*.md" 2>/dev/null | sort)

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "check-health: 目录下未找到任何 *.md：$ROOT" >&2
  echo "RESULT: fail"; exit 1
fi

# 依赖检查
MISSING=0
have jq || { echo "${C_RED}missing dep: jq${C_RESET}" >&2; MISSING=$((MISSING+1)); }
if [ ! -r "$YAML_BRIDGE" ]; then
  echo "${C_RED}missing yaml-bridge: $YAML_BRIDGE${C_RESET}" >&2; MISSING=$((MISSING+1))
fi
if [ "$MISSING" -gt 0 ]; then
  echo "RESULT: degraded"; exit 2
fi

# ----------------------------------------------------------------------------
# 加载阈值（主路径：yaml-bridge + jq；失败：fallback 常量）
# ----------------------------------------------------------------------------
W_COVERAGE=""; W_FRESHNESS=""; W_DRIFT=""
HEALTHY_MIN=""; WARNING_MIN=""
FRESH_MAX_DAYS=""; DECAY_MAX_DAYS=""
DEGRADED=0

load_from_yaml() {
  [ -r "$THRESHOLDS_YAML" ] || return 1
  local json
  json=$(bash "$YAML_BRIDGE" yaml_to_json "$THRESHOLDS_YAML" 2>/dev/null) || return 1
  [ -z "$json" ] && return 1
  local fields
  fields=$(printf "%s" "$json" | jq -r '[
    .health.weights.coverage // empty,
    .health.weights.freshness // empty,
    .health.weights.drift // empty,
    .health.grade.healthy_min // empty,
    .health.grade.warning_min // empty,
    .health.freshness.fresh_max_days // empty,
    .health.freshness.decay_max_days // empty
  ] | @tsv' 2>/dev/null) || return 1
  IFS=$'\t' read -r WC WF WD HM WM FMD DMD <<<"$fields"
  for v in "$WC" "$WF" "$WD" "$HM" "$WM" "$FMD" "$DMD"; do
    [ -z "$v" ] && return 1
  done
  # 权重 0.4 → 40（×100 转整数）
  W_COVERAGE=$(printf "%.0f" "$(awk "BEGIN{print $WC*100}")")
  W_FRESHNESS=$(printf "%.0f" "$(awk "BEGIN{print $WF*100}")")
  W_DRIFT=$(printf "%.0f" "$(awk "BEGIN{print $WD*100}")")
  HEALTHY_MIN="$HM"
  WARNING_MIN="$WM"
  FRESH_MAX_DAYS="$FMD"
  DECAY_MAX_DAYS="$DMD"
  return 0
}

if ! load_from_yaml; then
  echo "check-health: thresholds.yaml 不可用，使用 fallback 常量" >&2
  W_COVERAGE=$FALLBACK_W_COVERAGE
  W_FRESHNESS=$FALLBACK_W_FRESHNESS
  W_DRIFT=$FALLBACK_W_DRIFT
  HEALTHY_MIN=$FALLBACK_HEALTHY_MIN
  WARNING_MIN=$FALLBACK_WARNING_MIN
  FRESH_MAX_DAYS=$FALLBACK_FRESH_MAX_DAYS
  DECAY_MAX_DAYS=$FALLBACK_DECAY_MAX_DAYS
  DEGRADED=1
fi

# ----------------------------------------------------------------------------
# 工具函数
# ----------------------------------------------------------------------------
# 计算 ISO 日期距今天数（macOS bash 3.2 兼容；失败返回空）
days_since() {
  local iso="$1"
  [ -z "$iso" ] && { echo ""; return; }
  local then_sec now_sec
  # macOS date 用 -j -f
  if then_sec=$(date -j -f "%Y-%m-%d" "$iso" +%s 2>/dev/null); then :
  elif then_sec=$(date -d "$iso" +%s 2>/dev/null); then :   # GNU date 兜底
  else echo ""; return; fi
  now_sec=$(date +%s)
  echo $(( (now_sec - then_sec) / 86400 ))
}

# 单文件 freshness 分（0-100；不可计算返回空，调用方按 0 处理）
freshness_score_of() {
  local fm_json="$1"
  local lv created days
  lv=$(printf "%s" "$fm_json" | jq -r '.last_verified // empty' 2>/dev/null)
  created=$(printf "%s" "$fm_json" | jq -r '.created // empty' 2>/dev/null)
  days=$(days_since "${lv:-$created}")
  [ -z "$days" ] && { echo 0; return; }
  if [ "$days" -le "$FRESH_MAX_DAYS" ]; then echo 100; return; fi
  if [ "$days" -ge "$DECAY_MAX_DAYS" ]; then echo 0; return; fi
  # 线性衰减：100 * (DECAY - days) / (DECAY - FRESH)
  echo $(( 100 * (DECAY_MAX_DAYS - days) / (DECAY_MAX_DAYS - FRESH_MAX_DAYS) ))
}

# ----------------------------------------------------------------------------
# 主循环：聚合 freshness 总分 + drift 计数
# ----------------------------------------------------------------------------
printf "\n%s[knowledge-loop] check-health%s\n" "$C_DIM" "$C_RESET"
printf "%s%s%s\n" "$C_DIM" "============================================" "$C_RESET"
printf "root:    %s\n" "$ROOT"
printf "targets: %d *.md file(s)\n\n" "${#TARGETS[@]}"

KB_TOTAL=0          # 计入分母的 md（有 frontmatter）
FRESH_SUM=0
DRIFT_FILES=0       # drift_count > 0 的文件数

for md in "${TARGETS[@]}"; do
  fm_json=$(bash "$YAML_BRIDGE" frontmatter_to_json "$md" 2>/dev/null) || continue
  [ -z "$fm_json" ] || [ "$fm_json" = "null" ] && continue
  KB_TOTAL=$((KB_TOTAL + 1))
  fs=$(freshness_score_of "$fm_json")
  FRESH_SUM=$((FRESH_SUM + fs))
  drift=$(printf "%s" "$fm_json" | jq -r '.drift_count // 0' 2>/dev/null)
  [[ "$drift" =~ ^[0-9]+$ ]] || drift=0
  if [ "$drift" -gt 0 ]; then
    DRIFT_FILES=$((DRIFT_FILES + 1))
  fi
  printf "  %s•%s %s  %s(fresh=%s, drift=%s)%s\n" \
    "$C_DIM" "$C_RESET" "$md" "$C_DIM" "$fs" "$drift" "$C_RESET"
done

if [ "$KB_TOTAL" -eq 0 ]; then
  echo "check-health: 无任何带 frontmatter 的 *.md（分母为 0）" >&2
  echo "RESULT: fail"; exit 1
fi

# 维度分（0-100 整数）
COVERAGE=100   # Phase 3 暂置 100（决策 C-2=C）
FRESHNESS=$(( FRESH_SUM / KB_TOTAL ))
DRIFT_PCT=$(( 100 * DRIFT_FILES / KB_TOTAL ))
DRIFT_INVERSE=$(( 100 - DRIFT_PCT ))

# 综合分：weights 已 ×100，所以再除 10000
HEALTH=$(( (W_COVERAGE * COVERAGE + W_FRESHNESS * FRESHNESS + W_DRIFT * DRIFT_INVERSE) / 100 ))

# Grade
if [ "$HEALTH" -ge "$HEALTHY_MIN" ]; then
  GRADE="healthy"; GRADE_COLOR="$C_GREEN"; RESULT_LINE="ok"; EXIT_CODE=0
elif [ "$HEALTH" -ge "$WARNING_MIN" ]; then
  GRADE="warning"; GRADE_COLOR="$C_YELLOW"; RESULT_LINE="warn"; EXIT_CODE=1
else
  GRADE="critical"; GRADE_COLOR="$C_RED"; RESULT_LINE="fail"; EXIT_CODE=1
fi

printf "\n%s%s%s\n" "$C_DIM" "============================================" "$C_RESET"
printf "kb_total:   %d (with frontmatter)\n" "$KB_TOTAL"
printf "coverage:   %d%%  %s(phase3 placeholder)%s\n" "$COVERAGE" "$C_DIM" "$C_RESET"
printf "freshness:  %d%%  %s(avg of %d files)%s\n" "$FRESHNESS" "$C_DIM" "$KB_TOTAL" "$C_RESET"
printf "drift_inv:  %d%%  %s(%d/%d clean)%s\n" "$DRIFT_INVERSE" "$C_DIM" "$((KB_TOTAL - DRIFT_FILES))" "$KB_TOTAL" "$C_RESET"
printf "%s%s%s\n" "$C_DIM" "--------------------------------------------" "$C_RESET"
printf "%shealth:     %d / 100  [%s]%s\n" "$GRADE_COLOR" "$HEALTH" "$GRADE" "$C_RESET"

if [ "$DEGRADED" -eq 1 ]; then
  echo "RESULT: degraded"
  exit 2
fi
echo "RESULT: $RESULT_LINE"
exit $EXIT_CODE
