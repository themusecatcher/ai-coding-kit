#!/bin/bash
# devlog-template-lint.sh — devlog.md 模板质量 lint（tech-doc Skill 资产）
#
# 与 dev-flow/scripts/lints/devlog-integrity-lint.sh 的分工：
#   - dev-flow 的 devlog-integrity-lint.sh：批量扫描所有 dev-logs/ 目录，校验 plan.md/devlog.md 双件齐全
#   - 本脚本：校验单个 devlog.md 的内部模板结构合规性（六段 + 头部元信息 + Round N 规范）
#
# 用法：
#   bash devlog-template-lint.sh <devlog.md>             # 默认 JSON 输出
#   bash devlog-template-lint.sh --raw <devlog.md>       # 仅退出码
#   bash devlog-template-lint.sh --shell <devlog.md>     # 输出 shell 变量供 source
#
# 5 项检查：
#   1. six_sections          六段必备：## What / ## Why / ## How / ## Issues / ## Result / ## 相关文档
#   2. header_complete       头部元信息齐全：项目 / 类型 / 状态 / 日期 / 分支
#   3. status_valid          状态字段值合法：🟡 开发中 / 🟢 已归档
#   4. round_numbering       Round N 编号连续（如有 Round 段）
#   5. bugfix_round_complete 上线后 bugfix Round 必含三要素：Bug: / 影响范围： / 根因
#
# 退出码：
#   0  全部通过
#   1  任一项失败
#   2  参数/文件错误

set -u

# ========================================
# 参数解析
# ========================================
MODE="json"
FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --raw)   MODE="raw"; shift ;;
    --shell) MODE="shell"; shift ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    -*)
      echo "❌ 未知参数: $1" >&2
      exit 2
      ;;
    *)
      FILE="$1"; shift
      ;;
  esac
done

if [ -z "$FILE" ]; then
  echo "❌ 用法: $0 [--raw|--shell] <devlog.md>" >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  echo "❌ 文件不存在: $FILE" >&2
  exit 2
fi

# ========================================
# 工具函数：剥离代码块
# ========================================
strip_code_blocks() {
  awk '
    BEGIN { in_block = 0 }
    /^```/ {
      if (in_block) { in_block = 0; next }
      else { in_block = 1; next }
    }
    !in_block { print }
  ' "$1"
}

# ========================================
# 检查 1: six_sections
# 必须含六个二级章节（顺序不强制）
# ========================================
check_six_sections() {
  local file="$1"
  local stripped
  stripped=$(strip_code_blocks "$file")
  local missing=()
  local section
  for section in "What" "Why" "How" "Issues" "Result" "相关文档"; do
    # 兼容「## What（做了什么）」格式：行首 ## + 空格 + 章节名（可后接其它字符）
    if ! echo "$stripped" | grep -qE "^## ${section}([（(]|\$| )"; then
      missing+=("$section")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    local m
    for m in "${missing[@]}"; do
      echo "  - 缺失必备章节：## $m"
    done
    return 1
  fi
  return 0
}

# ========================================
# 检查 2: header_complete
# 头部元信息（位于 # 标题与第一个 ## 之间）必须含 5 项
# ========================================
check_header_complete() {
  local file="$1"
  # 提取头部区段（第一行 # 标题 之后到首个 ## 之前的所有内容）
  local header
  header=$(awk '
    BEGIN { in_header = 0; done = 0 }
    /^# / && !in_header { in_header = 1; next }
    in_header && /^## / { done = 1 }
    in_header && !done { print }
  ' "$file")
  if [ -z "$header" ]; then
    echo "  - 头部元信息块为空（需位于一级标题与首个二级标题之间）"
    return 1
  fi
  local missing=()
  local field
  for field in "项目" "类型" "状态" "日期" "分支"; do
    # 头部字段格式：> **{field}**：{value}
    if ! echo "$header" | grep -qE "\*\*${field}\*\*"; then
      missing+=("$field")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    local m
    for m in "${missing[@]}"; do
      echo "  - 头部缺失必备字段：**$m**"
    done
    return 1
  fi
  return 0
}

# ========================================
# 检查 3: status_valid
# 状态字段值必须是「🟡 开发中」或「🟢 已归档」之一
# ========================================
check_status_valid() {
  local file="$1"
  # 提取头部状态行
  local status_line
  status_line=$(grep -E '\*\*状态\*\*' "$file" | head -1)
  if [ -z "$status_line" ]; then
    # 头部完整性检查会另外报错；此处不重复
    echo "  - 未找到状态字段（应为 🟡 开发中 或 🟢 已归档）"
    return 1
  fi
  # 必须包含 🟡 或 🟢，且包含「开发中」或「已归档」
  if echo "$status_line" | grep -qE '🟡.*开发中'; then
    return 0
  fi
  if echo "$status_line" | grep -qE '🟢.*已归档'; then
    return 0
  fi
  echo "  - 状态字段值非法（应为 🟡 开发中 或 🟢 已归档）：$status_line"
  return 1
}

# ========================================
# 检查 4: round_numbering
# 如有 Round 段则编号必须连续（Round 1, 2, 3, ...）
# 没有 Round 段视为通过（首次生成 devlog 可能无 Round 标记）
# ========================================
check_round_numbering() {
  local file="$1"
  local stripped
  stripped=$(strip_code_blocks "$file")
  # 提取 ### Round N 标题中的 N
  local rounds
  rounds=$(echo "$stripped" | grep -E '^### Round [0-9]+' | sed -E 's/^### Round ([0-9]+).*/\1/')
  if [ -z "$rounds" ]; then
    return 0
  fi
  local idx=0
  local prev=0
  local n
  while IFS= read -r n; do
    [ -z "${n:-}" ] && continue
    idx=$((idx + 1))
    if [ "$idx" -eq 1 ]; then
      if [ "$n" -ne 1 ]; then
        echo "  - 首个 Round 必须为 Round 1（实际：Round $n）"
        return 1
      fi
    else
      if [ "$n" -ne $((prev + 1)) ]; then
        echo "  - Round 编号跳号：Round $prev 之后应为 Round $((prev + 1))，实际为 Round $n"
        return 1
      fi
    fi
    prev=$n
  done <<EOF
$rounds
EOF
  return 0
}

# ========================================
# 检查 5: bugfix_round_complete
# 上线后 bugfix Round 标题格式：### Round N：线上 Bug 修复 — xxx（YYYY-MM-DD）
# 必须含三要素：Bug: / 影响范围： / 根因
# 没有此类 Round 视为通过
# ========================================
check_bugfix_round_complete() {
  local file="$1"
  # 用 awk 提取每个「线上 Bug 修复」类 Round 段的内容
  awk '
    BEGIN { in_round = 0; round_num = ""; round_text = "" }
    /^### Round [0-9]+：线上 Bug 修复/ {
      if (in_round) {
        check_round(round_num, round_text)
      }
      in_round = 1
      match($0, /Round [0-9]+/)
      round_num = substr($0, RSTART, RLENGTH)
      round_text = $0 "\n"
      next
    }
    /^### Round [0-9]+/ && in_round {
      check_round(round_num, round_text)
      in_round = 0
      round_text = ""
      next
    }
    /^## / && in_round {
      check_round(round_num, round_text)
      in_round = 0
      round_text = ""
      next
    }
    in_round { round_text = round_text $0 "\n" }
    END {
      if (in_round) check_round(round_num, round_text)
      exit (failed > 0 ? 1 : 0)
    }
    function check_round(num, text) {
      missing = ""
      if (text !~ /Bug:/ && text !~ /Bug：/) missing = missing " Bug:"
      if (text !~ /影响范围/) missing = missing " 影响范围"
      if (text !~ /根因/) missing = missing " 根因"
      if (missing != "") {
        printf "  - %s 缺失要素：%s\n", num, missing
        failed++
      }
    }
  ' "$file"
}

# ========================================
# 执行检查
# ========================================
declare -a failures
declare -a check_results

run_check() {
  local name="$1"
  local fn="$2"
  local output
  if output=$($fn "$FILE" 2>&1); then
    check_results+=("$name=true")
  else
    check_results+=("$name=false")
    failures+=("$name:")
    while IFS= read -r line; do
      [ -n "$line" ] && failures+=("$line")
    done <<<"$output"
  fi
}

run_check "six_sections" check_six_sections
run_check "header_complete" check_header_complete
run_check "status_valid" check_status_valid
run_check "round_numbering" check_round_numbering
run_check "bugfix_round_complete" check_bugfix_round_complete

# ========================================
# 输出
# ========================================
fail_count=${#failures[@]}

case "$MODE" in
  raw)
    [ "$fail_count" -gt 0 ] && exit 1
    exit 0
    ;;
  shell)
    for kv in "${check_results[@]}"; do
      echo "devlog_template_lint_${kv}"
    done
    [ "$fail_count" -gt 0 ] && exit 1
    exit 0
    ;;
  json|*)
    echo "{"
    echo "  \"file\": \"$FILE\","
    echo "  \"devlog_template_lint\": {"
    last_idx=$((${#check_results[@]} - 1))
    i=0
    for kv in "${check_results[@]}"; do
      k="${kv%%=*}"
      v="${kv#*=}"
      printf '    "%s": %s' "$k" "$v"
      if [ "$i" -lt "$last_idx" ]; then
        echo ","
      else
        echo ""
      fi
      i=$((i + 1))
    done
    echo "  },"
    if [ "$fail_count" -gt 0 ]; then
      echo "  \"violations\": ["
      vi=0
      vl=$((${#failures[@]} - 1))
      for fv in "${failures[@]}"; do
        esc="${fv//\"/\\\"}"
        printf '    "%s"' "$esc"
        if [ "$vi" -lt "$vl" ]; then
          echo ","
        else
          echo ""
        fi
        vi=$((vi + 1))
      done
      echo "  ]"
    else
      echo "  \"violations\": []"
    fi
    echo "}"
    [ "$fail_count" -gt 0 ] && exit 1
    exit 0
    ;;
esac
