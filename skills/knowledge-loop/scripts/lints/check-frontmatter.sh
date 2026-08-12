#!/usr/bin/env bash
# ============================================================================
#  check-frontmatter.sh — Markdown frontmatter 守卫（基于 frontmatter.schema.json）
#  ----------------------------------------------------------------------------
#  作用：扫描指定的 markdown 文件 / 目录，对每个文件抽取 frontmatter，注入
#        __kind 判别字段，用 ajv + frontmatter.schema.json 校验合法性。
#  ----------------------------------------------------------------------------
#  消费方：
#    - scripts/tests/test-check-frontmatter.sh （端到端单测）
#    - SKILL.md「执行链路」章节（先 precheck 后 lint）
#    - dev:kb verify / dev:kb scan 等高层命令的 sanity gate
#  ----------------------------------------------------------------------------
#  __kind 注入规则（按文件名）：
#    _index.md     → __kind = "index"
#    _overview.md  → __kind = "overview"
#    其他 *.md     → __kind = "topic"  （topic 字段值由 schema topicEnum 进一步校验）
#  ----------------------------------------------------------------------------
#  CLI:
#    check-frontmatter.sh <file_or_dir> [<file_or_dir> ...]
#  退出码：
#    0 = 全部通过
#    1 = 至少一个文件校验失败 / 输入错
#    2 = 必需依赖（jq / ajv / yaml backend）缺失，已尽力降级
#  最后一行机器可解析输出：RESULT: ok | fail | degraded
#  ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA="$SKILL_ROOT/config/frontmatter.schema.json"
YAML_BRIDGE="$SKILL_ROOT/scripts/lib/yaml-bridge.sh"

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
usage: check-frontmatter.sh <file_or_dir> [<file_or_dir> ...]
  传入 *.md 文件或目录（递归 *.md），逐个抽取 frontmatter 并按 schema 校验。
USAGE
}

if [ $# -eq 0 ]; then
  usage; exit 1
fi

# 收集目标 md 文件列表（去重保序）
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
    echo "check-frontmatter: not found: $input" >&2
    echo "RESULT: fail"
    exit 1
  fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "check-frontmatter: 未找到任何 *.md 文件" >&2
  echo "RESULT: fail"
  exit 1
fi

# 依赖检查
MISSING=0
for bin in jq ajv; do
  have "$bin" || { echo "${C_RED}missing dep: $bin${C_RESET}" >&2; MISSING=$((MISSING+1)); }
done
if [ ! -r "$SCHEMA" ]; then
  echo "${C_RED}missing schema: $SCHEMA${C_RESET}" >&2; MISSING=$((MISSING+1))
fi
if [ ! -r "$YAML_BRIDGE" ]; then
  echo "${C_RED}missing yaml-bridge: $YAML_BRIDGE${C_RESET}" >&2; MISSING=$((MISSING+1))
fi
if [ "$MISSING" -gt 0 ]; then
  echo "RESULT: degraded"
  exit 2
fi

# ----------------------------------------------------------------------------
# 核心：__kind 注入规则（按文件名）
# ----------------------------------------------------------------------------
kind_for_file() {
  local base
  base="$(basename "$1")"
  case "$base" in
    _index.md|_index.MD)        echo index ;;
    _overview.md|_overview.MD)  echo overview ;;
    *)                          echo topic ;;
  esac
}

# ----------------------------------------------------------------------------
# 校验单个文件：抽 frontmatter → 注入 __kind → ajv 校验
# ----------------------------------------------------------------------------
check_one() {
  local md="$1"
  local kind json_with_kind tmp_data
  kind="$(kind_for_file "$md")"
  # 1) 抽 frontmatter JSON
  local fm_json
  if ! fm_json=$(bash "$YAML_BRIDGE" frontmatter_to_json "$md" 2>/dev/null); then
    printf "  %s✗%s %s  %s(no/invalid frontmatter)%s\n" "$C_RED" "$C_RESET" "$md" "$C_DIM" "$C_RESET"
    return 1
  fi
  # 2) 注入 __kind（若已存在则覆盖，确保与文件名规则一致）
  json_with_kind=$(printf "%s" "$fm_json" | jq --arg k "$kind" ". + {\"__kind\":\$k}" 2>/dev/null) || {
    printf "  %s✗%s %s  %s(jq inject __kind failed)%s\n" "$C_RED" "$C_RESET" "$md" "$C_DIM" "$C_RESET"
    return 1
  }
  # 3) ajv 校验（写到 tmp 文件再喂给 ajv，规避 stdin 限制）
  #    ajv-cli 要求数据文件后缀必须是 .json，否则按非 JSON 处理失败。
  local tmp_base
  tmp_base=$(mktemp -t check-fm.XXXXXX) || return 1
  tmp_data="${tmp_base}.json"
  mv "$tmp_base" "$tmp_data"
  printf "%s" "$json_with_kind" > "$tmp_data"
  local ajv_out ajv_rc
  ajv_out=$(ajv validate -s "$SCHEMA" -d "$tmp_data" --spec=draft2019 --strict=false 2>&1)
  ajv_rc=$?
  rm -f "$tmp_data"
  if [ $ajv_rc -eq 0 ]; then
    printf "  %s✓%s %s  %s(__kind=%s)%s\n" "$C_GREEN" "$C_RESET" "$md" "$C_DIM" "$kind" "$C_RESET"
    return 0
  else
    printf "  %s✗%s %s  %s(__kind=%s)%s\n" "$C_RED" "$C_RESET" "$md" "$C_DIM" "$kind" "$C_RESET"
    # ajv 错误缩进显示
    printf "%s" "$ajv_out" | sed "s/^/      /" >&2
    echo >&2
    return 1
  fi
}

# ----------------------------------------------------------------------------
# 主循环 + 汇总
# ----------------------------------------------------------------------------
printf "\n%s[knowledge-loop] check-frontmatter%s\n" "$C_DIM" "$C_RESET"
printf "%s%s%s\n" "$C_DIM" "============================================" "$C_RESET"
printf "schema:  %s\n" "$SCHEMA"
printf "targets: %d file(s)\n\n" "${#TARGETS[@]}"

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
