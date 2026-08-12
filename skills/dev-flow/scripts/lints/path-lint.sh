#!/bin/bash
# path-lint.sh - 路径可点击性 lint
# 根据 references/gate-validator.md §「路径可点击性门控」实现 R1-R5 规则
# 用法: bash path-lint.sh <markdown-file>
# 返回码: 0 通过 / 1 R1/R4 违规（Block）/ 2 R2/R3/R5 违规（Warn）

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/lib/audit.sh"

INPUT="${1:-}"
if [ -z "$INPUT" ]; then
  log_error "用法: $0 <file>"
  exit 1
fi
if [ ! -f "$INPUT" ]; then
  log_error "文件不存在: $INPUT"
  exit 1
fi

# ========================================
# 预处理：抽取「需要扫描的行」
# - 跳过代码块（``` 包裹）
# - 跳过 YAML frontmatter
# - 跳过 HTML 注释 <!-- ... -->
# 输出格式：行号:行内容（用于精确报告位置）
# ========================================
extract_scannable_lines() {
  local file="$1"
  awk '
    BEGIN { in_code=0; in_fm=0; fm_count=0 }
    /^---$/ {
      if (NR == 1) { in_fm=1; next }
      if (in_fm == 1) { in_fm=0; next }
    }
    in_fm { next }
    /^```/ { in_code = 1 - in_code; next }
    in_code { next }
    /<!--/ && /-->/ { next }
    { printf "%d:%s\n", NR, $0 }
  ' "$file"
}

# 全局违规计数
R1_COUNT=0   # Block
R2_COUNT=0   # Warn
R3_COUNT=0   # Warn
R4_COUNT=0   # Block
R5_COUNT=0   # Warn

R1_LINES=()
R2_LINES=()
R3_LINES=()
R4_LINES=()
R5_LINES=()

# ========================================
# 工具函数：判断某段位置是否处于反引号内
# 参数：原始行内容、列偏移
# 返回：0 在反引号内（豁免）/ 1 不在反引号内
# ========================================
is_in_backticks() {
  local line="$1"
  local match="$2"
  # 在 match 之前的部分计算反引号数（奇数=在反引号内）
  local before="${line%%${match}*}"
  local count=0
  local i=0
  while [ $i -lt ${#before} ]; do
    [ "${before:$i:1}" = '`' ] && count=$((count + 1))
    i=$((i + 1))
  done
  [ $((count % 2)) -eq 1 ]
}

# ========================================
# R1: 禁止裸绝对路径（/Users|/home|/opt 开头未被反引号包裹）
# ========================================
check_r1() {
  local file="$1"
  while IFS= read -r record; do
    local lineno="${record%%:*}"
    local content="${record#*:}"
    
    # 提取所有 /Users|/home|/opt 路径
    local matches
    matches=$(echo "$content" | grep -oE '/(Users|home|opt)/[^ ]+\.(tsx?|jsx?|scss|css|md|sh|json|yaml|yml)' 2>/dev/null || true)
    [ -z "$matches" ] && continue
    
    while IFS= read -r m; do
      [ -z "$m" ] && continue
      # 豁免：~/.codebuddy/ 简写或路径范例 https/http
      if echo "$content" | grep -qE "(\\\${USER}|<workspace>|占位符|\\\$HOME|示例|范例|样例)"; then
        continue
      fi
      # 检查是否被反引号包裹
      if is_in_backticks "$content" "$m"; then
        continue
      fi
      R1_COUNT=$((R1_COUNT + 1))
      R1_LINES+=("L${lineno}: ${m}")
    done <<< "$matches"
  done < <(extract_scannable_lines "$file")
}

# ========================================
# R2: 禁止裸相对源码路径（src/... 或 app/... 等未反引号包裹）
# ========================================
check_r2() {
  local file="$1"
  while IFS= read -r record; do
    local lineno="${record%%:*}"
    local content="${record#*:}"
    
    # 匹配 src/path/file.ext 或类似格式
    local matches
    matches=$(echo "$content" | grep -oE '\b(src|app|components|pages|utils|hooks|store|services|types)/[a-zA-Z0-9_/-]+\.(tsx?|jsx?|scss|css|less|vue|md)' 2>/dev/null || true)
    [ -z "$matches" ] && continue
    
    while IFS= read -r m; do
      [ -z "$m" ] && continue
      # 反引号包裹的豁免
      if is_in_backticks "$content" "$m"; then
        continue
      fi
      R2_COUNT=$((R2_COUNT + 1))
      R2_LINES+=("L${lineno}: ${m}")
    done <<< "$matches"
  done < <(extract_scannable_lines "$file")
}

# ========================================
# R3: 禁止孤立行号引用（L42 / L42-L60 前面没有反引号路径）
# ========================================
check_r3() {
  local file="$1"
  while IFS= read -r record; do
    local lineno="${record%%:*}"
    local content="${record#*:}"
    
    # 匹配 L42 / L42-L60 形式
    local matches
    matches=$(echo "$content" | grep -oE '\bL[0-9]+(-L[0-9]+)?\b' 2>/dev/null || true)
    [ -z "$matches" ] && continue
    
    while IFS= read -r m; do
      [ -z "$m" ] && continue
      # 检查 L42 之前是否有 ` 闭合（反引号路径 + 空格 + L42 是合规的）
      # 简化：检查 L42 前一个非空字符是否是 `（反引号闭合）或紧贴在反引号内
      local before="${content%%${m}*}"
      # 去除尾部空格后的最后一个字符
      local trimmed="${before%"${before##*[!  ]}"}"
      local last_char="${trimmed: -1}"
      if [ "$last_char" = '`' ]; then
        continue  # 合规：紧跟在反引号路径后
      fi
      # 也许 L42 在反引号内（如 `L42`）
      if is_in_backticks "$content" "$m"; then
        continue
      fi
      # 合规豁免：行号在表格头/示例/列名等场景
      if echo "$content" | grep -qE '^\s*\|.*L[0-9]+'; then
        # 在表格内但仍需进一步判断；保守标记
        :
      fi
      R3_COUNT=$((R3_COUNT + 1))
      R3_LINES+=("L${lineno}: ${m}")
    done <<< "$matches"
  done < <(extract_scannable_lines "$file")
}

# ========================================
# R4: 禁止 Markdown 链接 vscode://file 或 file:/// 协议
# ========================================
check_r4() {
  local file="$1"
  while IFS= read -r record; do
    local lineno="${record%%:*}"
    local content="${record#*:}"
    
    # 匹配 ](vscode://file 或 ](file:///
    if echo "$content" | grep -qE '\]\((vscode://file|file:///)' 2>/dev/null; then
      # 豁免：本规范文件本身的格式示例（含「示例」「禁止」「错误示例」字样的行）
      if echo "$content" | grep -qE "示例|禁止|错误|反模式|example"; then
        continue
      fi
      R4_COUNT=$((R4_COUNT + 1))
      local snippet
      snippet=$(echo "$content" | grep -oE '\]\((vscode://file|file:///)[^)]*\)' | head -1)
      R4_LINES+=("L${lineno}: ${snippet}")
    fi
  done < <(extract_scannable_lines "$file")
}

# ========================================
# R5: 禁止只写文件名（如孤立的 index.tsx）
# ========================================
check_r5() {
  local file="$1"
  while IFS= read -r record; do
    local lineno="${record%%:*}"
    local content="${record#*:}"
    
    # 匹配孤立文件名（前后均非路径分隔符 / 或反引号）
    # 用 grep -P (Perl 正则) 实现负向断言；macOS grep 不支持，改用 awk
    local matches
    matches=$(echo "$content" \
      | awk 'match($0, /[^a-zA-Z0-9_\/`.-]([a-zA-Z][a-zA-Z0-9_-]+)\.(tsx|ts|jsx|js|scss|css|less|vue)[^a-zA-Z0-9_-]/) { print substr($0, RSTART+1, RLENGTH-2) }' \
      2>/dev/null || true)
    [ -z "$matches" ] && continue
    
    while IFS= read -r m; do
      [ -z "$m" ] && continue
      # 排除常见非源码文件名
      case "$m" in
        package.json|tsconfig.json|README.md|index.tsx|index.ts) ;;
        *) continue ;;  # 太宽泛会误报，仅对极少数典型文件检查
      esac
      if is_in_backticks "$content" "$m"; then
        continue
      fi
      R5_COUNT=$((R5_COUNT + 1))
      R5_LINES+=("L${lineno}: ${m}")
    done <<< "$matches"
  done < <(extract_scannable_lines "$file")
}

# ========================================
# 主流程
# ========================================
log_info "扫描文件: $INPUT"

check_r1 "$INPUT"
check_r2 "$INPUT"
check_r3 "$INPUT"
check_r4 "$INPUT"
check_r5 "$INPUT"

# 输出报告
total_block=$((R1_COUNT + R4_COUNT))
total_warn=$((R2_COUNT + R3_COUNT + R5_COUNT))

echo ""
log_kv "R1 裸绝对路径 (Block)" "$R1_COUNT"
log_kv "R2 裸源码路径 (Warn)"   "$R2_COUNT"
log_kv "R3 孤立行号 (Warn)"     "$R3_COUNT"
log_kv "R4 Markdown 链接 (Block)" "$R4_COUNT"
log_kv "R5 孤立文件名 (Warn)"   "$R5_COUNT"

if [ ${#R1_LINES[@]} -gt 0 ]; then
  log_warn "R1 违规位置（前 5 个）:"
  printf '    %s\n' "${R1_LINES[@]:0:5}" >&2
fi
if [ ${#R4_LINES[@]} -gt 0 ]; then
  log_warn "R4 违规位置（前 5 个）:"
  printf '    %s\n' "${R4_LINES[@]:0:5}" >&2
fi

if [ $total_block -gt 0 ]; then
  log_fail "Block 违规共 $total_block 处，必须修复后再推进"
  df_audit_lint_fail "path-lint" file="$INPUT" r1="$R1_COUNT" r4="$R4_COUNT"
  exit 1
fi
if [ $total_warn -gt 0 ]; then
  log_warn "Warn 违规共 $total_warn 处，建议修复"
  df_audit_lint_fail "path-lint-warn" file="$INPUT" r2="$R2_COUNT" r3="$R3_COUNT" r5="$R5_COUNT"
  exit 2
fi

log_pass "路径可点击性 lint 通过: $INPUT"
df_audit_lint_pass "path-lint" file="$INPUT"
exit 0
