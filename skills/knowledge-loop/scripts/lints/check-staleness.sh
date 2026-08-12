#!/usr/bin/env bash
# ============================================================================
#  check-staleness.sh — 腐烂条目识别（基于 state.sh 输出筛选）
#  ----------------------------------------------------------------------------
#  作用：扫描指定的 markdown 文件 / 目录，对每个文件抽取 frontmatter，调用
#        scripts/lib/state.sh 计算 state，筛出 state ∈ {stale, deprecated} 的
#        文件作为「腐烂条目」，输出列表 + 计数 + grade banner。
#  ----------------------------------------------------------------------------
#  与 check-state.sh 的边界（互补，非重叠）：
#    - check-state.sh    验"调得动"——任何 state.sh 失败的文件均报错
#    - check-staleness.sh 验"调出来是不是 stale"——基于已"调得动"的 state 做集合筛选
#  ----------------------------------------------------------------------------
#  腐烂集合定义（语义 a2，2026-05-16 与用户对齐）：
#    state ∈ {stale, deprecated} → 腐烂条目
#    （state.sh 内部：confidence ∈ {stale, auto-stale, archived} 都映射为 state=stale；
#     confidence == "deprecated" 终态优先 → state=deprecated；
#     drift_count ≥ drift_count_stale_threshold 强制升级 → state=stale）
#  ----------------------------------------------------------------------------
#  消费方：
#    - scripts/tests/test-check-staleness.sh （端到端单测，4 用例）
#    - SKILL.md「执行链路」章节（lint 表 Phase 3 新增项）
#    - dev:kb staleness / dev:kb audit 等高层命令的 sanity gate
#  ----------------------------------------------------------------------------
#  CLI:
#    check-staleness.sh <file_or_dir> [<file_or_dir> ...]
#  退出码：
#    0 = 无腐烂条目
#    1 = 至少一个腐烂条目 / 输入错
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
usage: check-staleness.sh <file_or_dir> [<file_or_dir> ...]
  传入 *.md 文件或目录（递归 *.md），逐个调用 state.sh 计算 state，
  筛出 state ∈ {stale, deprecated} 的文件作为腐烂条目。
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
    echo "check-staleness: not found: $input" >&2
    echo "RESULT: fail"
    exit 1
  fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "check-staleness: 未找到任何 *.md 文件" >&2
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
# 主循环：调 state.sh 分类，stale/deprecated 计入腐烂
# ----------------------------------------------------------------------------
printf "\n%s[knowledge-loop] check-staleness%s\n" "$C_DIM" "$C_RESET"
printf "%s%s%s\n" "$C_DIM" "============================================" "$C_RESET"
printf "state.sh:    %s\n" "$STATE_SH"
printf "stale set:   {stale, deprecated}\n"
printf "targets:     %d file(s)\n\n" "${#TARGETS[@]}"

KB_TOTAL=0          # 计入分母（state.sh 调得动的）
STALE_FILES=()      # state ∈ {stale, deprecated}
SKIPPED=0           # state.sh 调不动（无 frontmatter / confidence 缺失 / 未知 confidence）

for md in "${TARGETS[@]}"; do
  fm_json=$(bash "$YAML_BRIDGE" frontmatter_to_json "$md" 2>/dev/null) || { SKIPPED=$((SKIPPED+1)); continue; }
  [ -z "$fm_json" ] || [ "$fm_json" = "null" ] && { SKIPPED=$((SKIPPED+1)); continue; }
  conf=$(printf "%s" "$fm_json" | jq -r '.confidence // empty' 2>/dev/null)
  [ -z "$conf" ] && { SKIPPED=$((SKIPPED+1)); continue; }
  state_out=$(printf "%s" "$fm_json" | bash "$STATE_SH" 2>/dev/null)
  state_rc=$?
  if [ "$state_rc" -ne 0 ] && [ "$state_rc" -ne 2 ]; then
    SKIPPED=$((SKIPPED+1))
    printf "  %s?%s %s  %s(state.sh failed, rc=%s — skipped)%s\n" \
      "$C_YELLOW" "$C_RESET" "$md" "$C_DIM" "$state_rc" "$C_RESET"
    continue
  fi
  KB_TOTAL=$((KB_TOTAL+1))
  final_state=$(printf "%s" "$state_out" | tail -n 1)
  case "$final_state" in
    stale|deprecated)
      STALE_FILES+=("$md")
      printf "  %s✗%s %s  %s(state=%s, confidence=%s)%s\n" \
        "$C_RED" "$C_RESET" "$md" "$C_DIM" "$final_state" "$conf" "$C_RESET"
      ;;
    *)
      printf "  %s✓%s %s  %s(state=%s, confidence=%s)%s\n" \
        "$C_GREEN" "$C_RESET" "$md" "$C_DIM" "$final_state" "$conf" "$C_RESET"
      ;;
  esac
done

# ----------------------------------------------------------------------------
# 汇总
# ----------------------------------------------------------------------------
STALE_COUNT=${#STALE_FILES[@]}
FRESH_COUNT=$((KB_TOTAL - STALE_COUNT))

printf "\n%s%s%s\n" "$C_DIM" "============================================" "$C_RESET"
printf "kb_total:    %d (state-decidable)\n" "$KB_TOTAL"
printf "fresh:       %s%d%s\n" "$C_GREEN" "$FRESH_COUNT" "$C_RESET"
printf "stale:       %s%d%s\n" "$C_RED" "$STALE_COUNT" "$C_RESET"
if [ "$SKIPPED" -gt 0 ]; then
  printf "skipped:     %d (no frontmatter / undecidable)\n" "$SKIPPED"
fi

if [ "$STALE_COUNT" -eq 0 ]; then
  printf "%sgrade:       healthy (no stale entries)%s\n" "$C_GREEN" "$C_RESET"
  echo "RESULT: ok"
  exit 0
else
  printf "%sgrade:       has stale entries (need attention)%s\n" "$C_RED" "$C_RESET"
  echo "stale entries:"
  for f in "${STALE_FILES[@]}"; do
    printf "  - %s\n" "$f"
  done
  echo "RESULT: fail"
  exit 1
fi
