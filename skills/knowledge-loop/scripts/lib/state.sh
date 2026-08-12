#!/usr/bin/env bash
# ============================================================================
#  state.sh — 知识条目状态判定（基于 state-machine.yaml）
#  ----------------------------------------------------------------------------
#  作用：给定 frontmatter JSON（含 confidence + stability.drift_count），判定
#        条目当前生命周期状态：dirty / clean / synced / stale / deprecated。
#  ----------------------------------------------------------------------------
#  数据驱动 + fallback：
#    - 主路径：通过 yaml-bridge.sh 读取 config/state-machine.yaml +
#      config/thresholds.yaml + jq 抽取 confidence_to_state_default 映射 +
#      drift_count_stale_threshold
#    - 兜底：本文件顶部硬编码同名映射；yaml 解析失败时静默退化（stderr 提示）
#  ----------------------------------------------------------------------------
#  判定流程（与 state-machine.yaml priority + confidence_to_state_default 一致）：
#    1. confidence == "deprecated" → deprecated（终态优先）
#    2. drift_count >= drift_count_stale_threshold → stale（强制升级）
#    3. confidence_to_state_default[confidence] → 基础映射
#    4. 若基础映射为 clean 且 --synced-flag=true → 提升为 synced
#  ----------------------------------------------------------------------------
#  CLI:
#    state.sh --json <json> [--synced-flag <true|false>]
#    cat fm.json | state.sh [--synced-flag <true|false>]
#  退出码：
#    0 = 判定成功（stdout = 状态名）
#    1 = 参数错 / JSON 不合法 / confidence 缺失
#  ----------------------------------------------------------------------------
#  消费方：
#    - scripts/tests/test-state.sh （单元测试，5 状态 + drift 升级 + stdin + 3 错误）
#    - scripts/lints/check-state.sh （state 可判定性 lint，已落盘 / 6.1 KB / 164 行）
#    2 = yaml 不可用但已 fallback（仍正常输出状态名）
#  ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_YAML="$SKILL_ROOT/config/state-machine.yaml"
THRESHOLDS_YAML="$SKILL_ROOT/config/thresholds.yaml"
YAML_BRIDGE="$SCRIPT_DIR/yaml-bridge.sh"

# ----------------------------------------------------------------------------
# Fallback 映射（与 state-machine.yaml §confidence_to_state_default 同步）
# macOS bash 3 兼容：用 case 函数替代关联数组
# ----------------------------------------------------------------------------
fallback_state_for() {
  case "$1" in
    draft|pending)               echo dirty ;;
    scanned|verified|auto-verified) echo clean ;;
    stale|auto-stale|archived)   echo stale ;;
    deprecated)                  echo deprecated ;;
    *)                           echo "" ;;
  esac
}
FALLBACK_DRIFT_STALE_THRESHOLD=3

# ----------------------------------------------------------------------------
# 参数解析
# ----------------------------------------------------------------------------
usage() {
  cat >&2 <<'USAGE'
usage: state.sh --json <json> [--synced-flag <true|false>]
       cat frontmatter.json | state.sh [--synced-flag <true|false>]
options:
  --json          frontmatter JSON 字符串；不传则从 stdin 读取
  --synced-flag   last_synced_sha 是否对齐 base HEAD（true 时 clean→synced）
USAGE
}

JSON_INPUT=""
SYNCED_FLAG="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --json)         JSON_INPUT="${2:-}"; shift 2 ;;
    --synced-flag)  SYNCED_FLAG="${2:-false}"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "state.sh: unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

# 从 stdin 读 JSON（仅当 --json 未传且 stdin 非 tty 时）
if [ -z "$JSON_INPUT" ]; then
  if [ ! -t 0 ]; then
    JSON_INPUT="$(cat)"
  fi
fi

if [ -z "$JSON_INPUT" ]; then
  echo "state.sh: 缺少输入 JSON（--json 或 stdin）" >&2
  usage; exit 1
fi

# JSON 合法性 + 必含 confidence
command -v jq >/dev/null 2>&1 || { echo "state.sh: jq 不可用" >&2; exit 1; }
CONFIDENCE=$(printf "%s" "$JSON_INPUT" | jq -r ".confidence // empty" 2>/dev/null) || {
  echo "state.sh: JSON 解析失败" >&2; exit 1; }
if [ -z "$CONFIDENCE" ]; then
  echo "state.sh: 输入 JSON 缺少 .confidence 字段" >&2; exit 1
fi

# drift_count（缺失视为 0）
DRIFT_COUNT=$(printf "%s" "$JSON_INPUT" | jq -r ".stability.drift_count // 0" 2>/dev/null)
if ! [[ "$DRIFT_COUNT" =~ ^[0-9]+$ ]]; then DRIFT_COUNT=0; fi

# 加载 yaml 阈值 + state 映射
STALE_THRESHOLD=""
MAPPED_STATE=""
DEGRADED=0
load_from_yaml() {
  [ -r "$STATE_YAML" ] || return 1
  [ -r "$THRESHOLDS_YAML" ] || return 1
  [ -r "$YAML_BRIDGE" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local sm_json th_json
  sm_json=$(bash "$YAML_BRIDGE" yaml_to_json "$STATE_YAML" 2>/dev/null) || return 1
  th_json=$(bash "$YAML_BRIDGE" yaml_to_json "$THRESHOLDS_YAML" 2>/dev/null) || return 1
  STALE_THRESHOLD=$(printf "%s" "$th_json" | jq -r ".lifecycle.drift_count_stale_threshold // empty" 2>/dev/null)
  [ -z "$STALE_THRESHOLD" ] && return 1
  # 注意：MAPPED_STATE 为空时不视为 yaml 失败 —— 那只意味着 confidence 不在映射表中，
  # 由后续主流程统一报"未知 confidence"，避免把"未知输入"误报成"yaml 不可用"。
  MAPPED_STATE=$(printf "%s" "$sm_json" | jq -r --arg c "$CONFIDENCE" ".confidence_to_state_default[\$c] // empty" 2>/dev/null)
  return 0
}
if ! load_from_yaml; then
  echo "state.sh: yaml 不可用，使用 fallback 映射" >&2
  STALE_THRESHOLD=$FALLBACK_DRIFT_STALE_THRESHOLD
  MAPPED_STATE="$(fallback_state_for "$CONFIDENCE")"
  DEGRADED=1
fi
if [ -z "$MAPPED_STATE" ]; then
  echo "state.sh: 未知 confidence: $CONFIDENCE" >&2; exit 1
fi
FINAL_STATE=""
if [ "$CONFIDENCE" = "deprecated" ]; then
  FINAL_STATE="deprecated"
elif [ "$DRIFT_COUNT" -ge "$STALE_THRESHOLD" ]; then
  FINAL_STATE="stale"
else
  FINAL_STATE="$MAPPED_STATE"
  if [ "$FINAL_STATE" = "clean" ] && [ "$SYNCED_FLAG" = "true" ]; then
    FINAL_STATE="synced"
  fi
fi
echo "$FINAL_STATE"
[ "$DEGRADED" -eq 1 ] && exit 2
exit 0
