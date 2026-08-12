#!/bin/bash
# help-consistency.sh - help.md 与权威源一致性检查（5 项）
#
# 用法:
#   bash help-consistency.sh          # 默认 JSON 输出
#   bash help-consistency.sh --raw    # 仅返回 0/1，不输出 JSON
#
# 检查项:
#   1. commands:   help.md 命令 ⊆ SKILL.md 命令速查表
#   2. triggers:   help.md 触发词 ⊆ SKILL.md 流程内信号表
#   3. modes:      help.md 模式 ⊆ mode-matrix.md 基础模式全景矩阵
#   4. cmd_detail: 输出区块命令表行数 = 参考区块 CMD_DETAIL 标签数
#   5. steps:      help.md 步骤名 ⊆ step-router.md 流程总览步骤名
#
# 返回码: 0 全部通过 / 1 任一项失败 / 2 参数错误

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

HELP_FILE="$DEV_FLOW_ROOT/references/help.md"
SKILL_FILE="$DEV_FLOW_ROOT/SKILL.md"
MODE_MATRIX="$DEV_FLOW_ROOT/references/mode-matrix.md"
STEP_ROUTER="$DEV_FLOW_ROOT/steps/step-router.md"

MODE="json"
case "${1:-}" in
  --raw) MODE="raw" ;;
  --help|-h) sed -n '2,15p' "$0"; exit 0 ;;
  "") ;;
  *) echo "❌ 用法: $0 [--raw]" >&2; exit 2 ;;
esac

for f in "$HELP_FILE" "$SKILL_FILE" "$MODE_MATRIX" "$STEP_ROUTER"; do
  if [ ! -f "$f" ]; then
    echo "{\"error\":\"文件不存在: $f\"}" >&2
    exit 2
  fi
done

# ========================================
# JSON 辅助：将多行文本转为 JSON 数组
# ========================================
to_json_array() {
  local result="["
  local first=true
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local escaped
    escaped=$(echo "$line" | sed 's/\\/\\\\/g; s/"/\\"/g')
    if $first; then first=false; else result="$result,"; fi
    result="$result\"$escaped\""
  done <<< "$1"
  result="$result]"
  echo "$result"
}

# ========================================
# 1. 命令完整性检查
# ========================================
check_commands() {
  local skill_tmp help_tmp
  skill_tmp=$(mktemp) ; help_tmp=$(mktemp)

  # SKILL.md 命令速查表 → 第一列
  sed -n '/^## 命令速查$/,/^## 必要节点/p' "$SKILL_FILE" \
    | awk -F'|' '/^\| `/{gsub(/^[ \t]+|[ \t]+$/, "", $2); gsub(/`/, "", $2); print $2}' \
    | sort -u > "$skill_tmp"
  # 补 dev-flow（触发规则表中）
  if grep -q '显式命令.*dev-flow' "$SKILL_FILE" 2>/dev/null; then
    echo "dev-flow" >> "$skill_tmp"
  fi
  local skill_cmds ; skill_cmds=$(sort -u "$skill_tmp")

  # help.md 输出区块（MODE_TABLE 之前的表格行）→ 第一列
  sed -n '1,/<!-- MODE_TABLE -->/p' "$HELP_FILE" \
    | awk -F'|' '/^\| `/{gsub(/^[ \t]+|[ \t]+$/, "", $2); gsub(/`/, "", $2); sub(/ <[^>]*>$/, "", $2); print $2}' \
    | sort -u > "$help_tmp"
  local help_cmds ; help_cmds=$(sort -u "$help_tmp")

  rm -f "$skill_tmp" "$help_tmp"

  local st ht ; st=$(echo "$skill_cmds" | grep -c .) ; ht=$(echo "$help_cmds" | grep -c .)
  local mih eih
  mih=$(comm -23 <(echo "$skill_cmds") <(echo "$help_cmds") | grep -v '^dev:help$')
  eih=$(comm -13 <(echo "$skill_cmds") <(echo "$help_cmds"))

  local passed=true
  [ -n "$mih" ] && passed=false ; [ -n "$eih" ] && passed=false

  echo "\"commands\":{\"passed\":$passed,\"skill_total\":$st,\"help_total\":$ht,\"missing_in_help\":$(to_json_array "$mih"),\"extra_in_help\":$(to_json_array "$eih")}"
}

# ========================================
# 2. 触发词完整性检查
# ========================================
check_triggers() {
  local skill_tmp help_tmp
  skill_tmp=$(mktemp) ; help_tmp=$(mktemp)

  # SKILL.md 流程内信号表 → 第三列（关键词列：$3 是管道分割后的触发词列）
  sed -n '/^### 流程内信号/,/^## 命令速查/p' "$SKILL_FILE" \
    | awk -F'|' '!/---/ && !/流程内信号|关键词|作用/ && NF>=4 {
        line=$3  # 第三列是触发词列
        while (match(line, /`([^`]+)`/)) {
          w=substr(line, RSTART+1, RLENGTH-2)
          # 过滤技术术语（来自作用列的可能残留）
          if (w !~ /^(iteration-fix|interaction_mode|batch_mode=true|micro-fix)$/ && w !~ /^\.(flow|md)/ && w !~ /\.md$|\.sh$/) {
            print w
          }
          line=substr(line, RSTART+RLENGTH)
        }
      }' \
    | sort -u > "$skill_tmp"
  local skill_triggers ; skill_triggers=$(sort -u "$skill_tmp")

  # help.md 流程内信号表格 → 第二列（触发词列：$3 是管道分割后的触发词列）
  sed -n '/^### 流程内信号（仅 dev-flow 激活时生效）/,/^### 修饰/p' "$HELP_FILE" \
    | awk -F'|' '!/---/ && !/场景|你可以说/ && NF>=3 {
        line=$3
        while (match(line, /`([^`]+)`/)) {
          w=substr(line, RSTART+1, RLENGTH-2)
          gsub(/\.\.\./, "", w)
          print w
          line=substr(line, RSTART+RLENGTH)
        }
      }' \
    | sort -u > "$help_tmp"
  local help_triggers ; help_triggers=$(sort -u "$help_tmp")

  rm -f "$skill_tmp" "$help_tmp"

  local st ht ; st=$(echo "$skill_triggers" | grep -c .) ; ht=$(echo "$help_triggers" | grep -c .)
  local mih
  mih=$(comm -23 <(echo "$skill_triggers") <(echo "$help_triggers"))

  local passed=true ; [ -n "$mih" ] && passed=false

  echo "\"triggers\":{\"passed\":$passed,\"skill_total\":$st,\"help_total\":$ht,\"missing_in_help\":$(to_json_array "$mih")}"
}

# ========================================
# 3. 模式完整性检查
# ========================================
check_modes() {
  local matrix_tmp help_tmp
  matrix_tmp=$(mktemp) ; help_tmp=$(mktemp)

  # mode-matrix.md 基础模式全景矩阵 → 第一列（去掉 ** 粗体标记）
  sed -n '/^## 一、基础模式全景矩阵$/,/^## 二/p' "$MODE_MATRIX" \
    | awk -F'|' '/^\| \*\*/{gsub(/\*\*/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' \
    | sort -u > "$matrix_tmp"
  local matrix_modes ; matrix_modes=$(sort -u "$matrix_tmp")

  # help.md MODE_TABLE → 第一列
  sed -n '/<!-- MODE_TABLE -->/,/^##/p' "$HELP_FILE" \
    | awk -F'|' '/^\| `/{gsub(/`/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' \
    | sort -u > "$help_tmp"
  local help_modes ; help_modes=$(sort -u "$help_tmp")

  rm -f "$matrix_tmp" "$help_tmp"

  local mt ht ; mt=$(echo "$matrix_modes" | grep -c .) ; ht=$(echo "$help_modes" | grep -c .)
  local mih
  mih=$(comm -23 <(echo "$matrix_modes") <(echo "$help_modes"))

  local passed=true ; [ -n "$mih" ] && passed=false

  echo "\"modes\":{\"passed\":$passed,\"matrix_total\":$mt,\"help_total\":$ht,\"missing_in_help\":$(to_json_array "$mih")}"
}

# ========================================
# 4. CMD_DETAIL 对齐检查
# ========================================
check_cmd_detail() {
  local output_cmds detail_count
  output_cmds=$(sed -n '1,/<!-- MODE_TABLE -->/p' "$HELP_FILE" | grep -c '^| `')
  detail_count=$(sed -n '/<!-- OUTPUT_END -->/,$ p' "$HELP_FILE" | grep -c '<!-- CMD_DETAIL:')

  local passed=false
  [ "$output_cmds" -eq "$detail_count" ] && passed=true

  echo "\"cmd_detail\":{\"passed\":$passed,\"output_table_commands\":$output_cmds,\"reference_detail_blocks\":$detail_count}"
}

# ========================================
# 5. 步骤名一致性检查
# ========================================
check_steps() {
  local router_tmp help_tmp
  router_tmp=$(mktemp) ; help_tmp=$(mktemp)

  # step-router.md 流程总览表 → 步骤名列
  sed -n '/^## 流程总览$/,/^## micro-fix/p' "$STEP_ROUTER" \
    | awk -F'|' '/^\| [0-9]/{gsub(/^[ \t]+|[ \t]+$/, "", $3); gsub(/（仅完整执行）/, "", $3); print $3}' \
    | sort -u > "$router_tmp"
  local router_steps ; router_steps=$(sort -u "$router_tmp")

  # help.md 流程概览区域 → 提取 · 后的名称（代码块内 + 外部说明行）
  # 代码块内的行
  sed -n '/^## 流程概览$/,/^## 命令大全/p' "$HELP_FILE" \
    | grep '·' \
    | sed 's/^```//' \
    | awk -F'·' '/·/{
        name=$2
        sub(/[ \t]*→.*/, "", name)
        gsub(/[（（][^）)]*[）)]/, "", name)
        gsub(/^[ \t]+|[ \t]+$/, "", name)
        if (name != "") print name
      }' \
    | sort -u > "$help_tmp"

  # 补上步骤 8-10 的名称（来自 "标准模式执行到步骤 7 结束..." 行）
  local line810
  line810=$(sed -n '/^标准模式执行到步骤 7/p' "$HELP_FILE" | head -1)
  if [ -n "$line810" ]; then
    echo "$line810" | grep -oE '[89]·[^→。]+|10·[^→。]+' \
      | sed 's/^[0-9]*· *//;s/ *$//' \
      >> "$help_tmp" 2>/dev/null || true
  fi

  local help_steps ; help_steps=$(sort -u "$help_tmp")
  rm -f "$help_tmp"

  local rt ht ; rt=$(echo "$router_steps" | grep -c .) ; ht=$(echo "$help_steps" | grep -c .)

  # 检查 help 中每个名称是否在 router 中存在（允许子串匹配，因为 help 用简化名）
  local missing_in_router=""
  while IFS= read -r hs; do
    [ -z "$hs" ] && continue
    local found=false
    while IFS= read -r rs; do
      [ -z "$rs" ] && continue
      if [ "$hs" = "$rs" ] || echo "$rs" | grep -qF "$hs" 2>/dev/null; then
        found=true ; break
      fi
    done <<< "$router_steps"
    if ! $found; then
      missing_in_router="$missing_in_router$hs"$'\n'
    fi
  done <<< "$help_steps"
  missing_in_router=$(echo "$missing_in_router" | grep -v '^$' || true)

  rm -f "$router_tmp"

  local passed=true ; [ -n "$missing_in_router" ] && passed=false

  echo "\"steps\":{\"passed\":$passed,\"router_total\":$rt,\"help_total\":$ht,\"help_step_names\":$(to_json_array "$help_steps"),\"router_step_names\":$(to_json_array "$router_steps"),\"mismatched\":$(to_json_array "$missing_in_router")}"
}

# ========================================
# 主逻辑
# ========================================
c1=$(check_commands)
c2=$(check_triggers)
c3=$(check_modes)
c4=$(check_cmd_detail)
c5=$(check_steps)

all_passed=true
for c in "$c1" "$c2" "$c3" "$c4" "$c5"; do
  if echo "$c" | grep -q '"passed":false'; then
    all_passed=false ; break
  fi
done

if [ "$MODE" = "json" ]; then
  cat <<EOF
{
  $c1,
  $c2,
  $c3,
  $c4,
  $c5,
  "all_passed": $all_passed
}
EOF
fi

$all_passed && exit 0 || exit 1
