#!/bin/bash
# circuit-breaker.sh - 3 次失败熔断的物理计数器
#
# 设计意图（兑现「确定性用代码」哲学）：
# - 把"同一阶段连续失败 3 次必须停止"从 SKILL.md 提示词转为物理事实
# - AI 不可能"忘记数到第几次"，因为计数文件由本脚本原子维护
# - 与 dev-flow scripts/state-machine.sh 的设计风格对齐（数据驱动 + fallback）
#
# 计数文件位置：$VP_STATE_DIR/<stage>.count（默认 ~/.codebuddy/working-context/.verify-state/）
#
# 用法：
#   bash circuit-breaker.sh --inc <stage>           # 累加 1，返回当前次数
#   bash circuit-breaker.sh --reset <stage>         # 重置为 0
#   bash circuit-breaker.sh --get <stage>           # 仅读取当前次数
#   bash circuit-breaker.sh --check <stage>         # 检查是否已达熔断阈值
#   bash circuit-breaker.sh --threshold <stage> <N> # 设定阈值（默认 3）
#   bash circuit-breaker.sh --list                  # 列出所有阶段计数
#   bash circuit-breaker.sh --clear-all             # 清空所有计数
#
# 返回码：
#   0 操作成功，未达熔断
#   1 已达熔断阈值（仅 --check / --inc 时可能返回）
#   2 参数错误

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VP_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/common.sh
source "$VP_ROOT/scripts/lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$VP_ROOT/scripts/lib/logger.sh"

# 阈值（可被 stages.yaml 中 circuit_breaker.threshold 覆盖）
DEFAULT_THRESHOLD=3
THRESHOLD="$DEFAULT_THRESHOLD"
if [ -f "$VP_CONFIG/stages.yaml" ]; then
  cfg_threshold="$(vp_yaml_get_scalar "$VP_CONFIG/stages.yaml" 'circuit_breaker.threshold' 2>/dev/null || true)"
  if [ -n "$cfg_threshold" ] && [ "$cfg_threshold" -eq "$cfg_threshold" ] 2>/dev/null; then
    THRESHOLD="$cfg_threshold"
  fi
fi

# 状态目录
mkdir -p "$VP_STATE_DIR" 2>/dev/null || true

ACTION=""
STAGE=""
NEW_THRESHOLD=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --inc)        ACTION="inc";       STAGE="${2:-}"; shift 2 ;;
    --reset)      ACTION="reset";     STAGE="${2:-}"; shift 2 ;;
    --get)        ACTION="get";       STAGE="${2:-}"; shift 2 ;;
    --check)      ACTION="check";     STAGE="${2:-}"; shift 2 ;;
    --threshold)  ACTION="threshold"; STAGE="${2:-}"; NEW_THRESHOLD="${3:-}"; shift 3 ;;
    --list)       ACTION="list";      shift ;;
    --clear-all)  ACTION="clear-all"; shift ;;
    --help|-h)    sed -n '2,28p' "$0"; exit 0 ;;
    *)
      log_error "未知参数: $1"
      exit 2
      ;;
  esac
done

if [ -z "$ACTION" ]; then
  log_error "缺少 action 参数"
  sed -n '2,28p' "$0" >&2
  exit 2
fi

# 校验 stage 名（仅允许字母数字下划线短横）
validate_stage() {
  local s="$1"
  if [ -z "$s" ]; then
    log_error "缺少 stage 参数"
    return 2
  fi
  if ! printf '%s' "$s" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    log_error "stage 名包含非法字符: $s"
    return 2
  fi
  return 0
}

count_file() {
  echo "$VP_STATE_DIR/$1.count"
}

read_count() {
  local f
  f="$(count_file "$1")"
  if [ -f "$f" ]; then
    local n
    n="$(cat "$f" 2>/dev/null | tr -d ' \n\r')"
    if [ -n "$n" ] && [ "$n" -eq "$n" ] 2>/dev/null; then
      echo "$n"
      return
    fi
  fi
  echo 0
}

write_count() {
  local stage="$1"
  local n="$2"
  local f
  f="$(count_file "$stage")"
  # 原子写：先写 tmp 再 mv
  local tmp="${f}.tmp.$$"
  printf '%s\n' "$n" > "$tmp"
  mv -f "$tmp" "$f"
}

case "$ACTION" in
  inc)
    validate_stage "$STAGE" || exit 2
    cur="$(read_count "$STAGE")"
    new=$((cur + 1))
    write_count "$STAGE" "$new"
    log_warn "[$STAGE] 失败计数: $cur → $new (threshold=$THRESHOLD)"
    echo "$new"
    if [ "$new" -ge "$THRESHOLD" ]; then
      log_fail "[$STAGE] 已达熔断阈值，必须停止试错并由用户决定"
      exit 1
    fi
    exit 0
    ;;

  reset)
    validate_stage "$STAGE" || exit 2
    write_count "$STAGE" 0
    log_pass "[$STAGE] 失败计数已重置为 0"
    echo 0
    exit 0
    ;;

  get)
    validate_stage "$STAGE" || exit 2
    read_count "$STAGE"
    exit 0
    ;;

  check)
    validate_stage "$STAGE" || exit 2
    cur="$(read_count "$STAGE")"
    if [ "$cur" -ge "$THRESHOLD" ]; then
      log_fail "[$STAGE] 已熔断 ($cur/$THRESHOLD)"
      exit 1
    fi
    log_info "[$STAGE] 未熔断 ($cur/$THRESHOLD)"
    exit 0
    ;;

  threshold)
    validate_stage "$STAGE" || exit 2
    if [ -z "$NEW_THRESHOLD" ] || ! [ "$NEW_THRESHOLD" -eq "$NEW_THRESHOLD" ] 2>/dev/null; then
      log_error "无效的阈值: $NEW_THRESHOLD"
      exit 2
    fi
    THRESHOLD="$NEW_THRESHOLD"
    # 阈值变更只影响本进程内后续操作；持久化阈值应改 stages.yaml
    log_info "[$STAGE] 临时阈值设为 $THRESHOLD（持久化请修改 config/stages.yaml）"
    exit 0
    ;;

  list)
    if [ ! -d "$VP_STATE_DIR" ]; then
      echo "(no state)"
      exit 0
    fi
    found=0
    for f in "$VP_STATE_DIR"/*.count; do
      [ -f "$f" ] || continue
      found=1
      stage="$(basename "$f" .count)"
      n="$(read_count "$stage")"
      printf "  %-20s %s\n" "$stage" "$n"
    done
    [ "$found" -eq 0 ] && echo "(no state)"
    exit 0
    ;;

  clear-all)
    if [ -d "$VP_STATE_DIR" ]; then
      rm -f "$VP_STATE_DIR"/*.count 2>/dev/null || true
      log_pass "已清空所有阶段失败计数"
    fi
    exit 0
    ;;

  *)
    log_error "未实现的 action: $ACTION"
    exit 2
    ;;
esac
