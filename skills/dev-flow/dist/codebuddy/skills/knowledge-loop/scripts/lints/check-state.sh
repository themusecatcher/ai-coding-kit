#!/usr/bin/env bash
# ============================================================================
#  check-state.sh — 知识条目 state 可判定性守卫（基于 state.sh + state-machine.yaml）
#  ----------------------------------------------------------------------------
#  作用：扫描指定的 markdown 文件 / 目录，对每个文件抽取 frontmatter，调用
#        scripts/lib/state.sh 计算其生命周期状态，确认 confidence 字段合法且
#        state 可被稳定判定。frontmatter 不携带 state 字段（state 为派生量，
#        由 state.sh 实时计算），本脚本仅做"可判定性 sanity"，与 schema 字段
#        完备性检查（check-frontmatter.sh）互补。
#  ----------------------------------------------------------------------------
#  失败条件（按优先级）：
#    1. frontmatter 缺失或非法 YAML
#    2. confidence 字段缺失
#    3. confidence 值不在 state-machine.yaml::confidence_to_state_default 表内
#    4. state.sh 退出码非 0/2（2 = yaml fallback 但仍输出状态名，视为 OK）
#  ----------------------------------------------------------------------------
#  消费方：
#    - scripts/tests/test-check-state.sh （端到端单测，4 用例）
#    - SKILL.md「执行链路」章节（lint 表 Phase 2.5 新增项）
#    - dev:kb verify / dev:kb scan 等高层命令的 sanity gate
#  ----------------------------------------------------------------------------
#  CLI:
#    check-state.sh <file_or_dir> [<file_or_dir> ...]
#  退出码：
#    0 = 全部文件 state 可判定
#    1 = 至少一个文件失败 / 输入错
#    2 = 必需依赖（jq / yaml-bridge / state.sh）缺失，已尽力降级
#  最后一行机器可解析输出：RESULT: ok | fail | degraded
#  ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
YAML_BRIDGE="$SKILL_ROOT/scripts/lib/yaml-bridge.sh"
STATE_SH="$SKILL_ROOT/scripts/lib/state.sh"

# 颜色（仅 tty）
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_DIM=""; C_RESET=""
fi

have() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------------------
# 参数解析
# ----------------------------------------------------------------------------
usage() {
  cat >&2 <<'USAGE'
usage: check-state.sh <file_or_dir> [<file_or_dir> ...]
  传入 *.md 文件或目录（递归 *.md），逐个抽取 frontmatter 并调用 state.sh 判定其状态。
USAGE
}

if [ $# -eq 0 ]; then
  usage; exit 1
fi

# 收集目标 md 文件列表（保序）
TARGETS=()
for input in "$@"; do
  if [ -f "$input" ]; then
    case "$input" in
      *.md|*.MD) TARGETS+=("$input") ;;
      *) echo "skip non-md: $input" >&2 ;;
    esac
  elif [ -d "$input" ]; then
    while IFS= read -r f; do TARGETS+=("$f"); done < <(find "$input" -type f -name "*.md" 2>/dev/null | sort)
  else
    echo "check-state: not found: $input" >&2
    echo "RESULT: fail"
    exit 1
  fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "check-state: 未找到任何 *.md 文件" >&2
  echo "RESULT: fail"
  exit 1
fi

# 依赖检查
MISSING=0
have jq || { echo "${C_RED}missing dep: jq${C_RESET}" >&2; MISSING=$((MISSING+1)); }
if [ ! -r "$YAML_BRIDGE" ]; then
  echo "${C_RED}missing yaml-bridge: $YAML_BRIDGE${C_RESET}" >&2; MISSING=$((MISSING+1))
fi
if [ ! -r "$STATE_SH" ]; then
  echo "${C_RED}missing state.sh: $STATE_SH${C_RESET}" >&2; MISSING=$((MISSING+1))
fi
if [ "$MISSING" -gt 0 ]; then
  echo "RESULT: degraded"
  exit 2
fi

# ----------------------------------------------------------------------------
# 校验单个文件：抽 frontmatter → state.sh 判定
# ----------------------------------------------------------------------------
check_one() {
  local md="$1"
  local fm_json
  if ! fm_json=$(bash "$YAML_BRIDGE" frontmatter_to_json "$md" 2>/dev/null); then
    printf "  %s✗%s %s  %s(no/invalid frontmatter)%s\n" "$C_RED" "$C_RESET" "$md" "$C_DIM" "$C_RESET"
    return 1
  fi
  # confidence 缺失：state.sh 也会失败，但提前 jq 检查可给出更友好的错误信息
  local conf
  conf=$(printf "%s" "$fm_json" | jq -r ".confidence // empty" 2>/dev/null)
  if [ -z "$conf" ]; then
    printf "  %s✗%s %s  %s(missing .confidence)%s\n" "$C_RED" "$C_RESET" "$md" "$C_DIM" "$C_RESET"
    return 1
  fi
  # 调用 state.sh
  local state_out state_rc
  state_out=$(printf "%s" "$fm_json" | bash "$STATE_SH" 2>&1)
  state_rc=$?
  # 退出码 0 = 正常；2 = yaml fallback 但仍输出状态名（视为 OK，stderr 已警告）
  if [ "$state_rc" -eq 0 ] || [ "$state_rc" -eq 2 ]; then
    # state.sh 在 rc=2 时 stdout 仍为状态名，stderr 含 fallback 警告 → 取最后一行作为状态
    local final_state
    final_state=$(printf "%s" "$state_out" | tail -n 1)
    printf "  %s✓%s %s  %s(confidence=%s, state=%s)%s\n" \
      "$C_GREEN" "$C_RESET" "$md" "$C_DIM" "$conf" "$final_state" "$C_RESET"
    return 0
  else
    printf "  %s✗%s %s  %s(confidence=%s, state.sh rc=%s)%s\n" \
      "$C_RED" "$C_RESET" "$md" "$C_DIM" "$conf" "$state_rc" "$C_RESET"
    printf "%s" "$state_out" | sed "s/^/      /" >&2
    echo >&2
    return 1
  fi
}

# ----------------------------------------------------------------------------
# 主循环 + 汇总
# ----------------------------------------------------------------------------
printf "\n%s[knowledge-loop] check-state%s\n" "$C_DIM" "$C_RESET"
printf "%s%s%s\n" "$C_DIM" "============================================" "$C_RESET"
printf "state.sh: %s\n" "$STATE_SH"
printf "targets:  %d file(s)\n\n" "${#TARGETS[@]}"

PASS=0
FAIL=0
for md in "${TARGETS[@]}"; do
  if check_one "$md"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
  fi
done

printf "\n%s%s%s\n" "$C_DIM" "============================================" "$C_RESET"
printf "summary: %d total, %s%d pass%s, %s%d fail%s\n" \
  "${#TARGETS[@]}" "$C_GREEN" "$PASS" "$C_RESET" "$C_RED" "$FAIL" "$C_RESET"

if [ "$FAIL" -eq 0 ]; then
  echo "RESULT: ok"
  exit 0
else
  echo "RESULT: fail"
  exit 1
fi
