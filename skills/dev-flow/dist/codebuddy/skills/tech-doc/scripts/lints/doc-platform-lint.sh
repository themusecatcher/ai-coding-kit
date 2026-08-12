#!/bin/bash
# doc-platform-lint.sh — 文档平台 技术方案文档质量 lint（tech-doc Skill 资产）
#
# 与 dev-flow/scripts/lints/doc-platform-lint.sh 的分工：
#   - dev-flow 的 doc-platform-lint.sh：校验 step-4 决策 JSON（决策门控，7 项）
#   - 本脚本：校验 doc_platform 文档正文质量（发布前 lint，8 项）
#
# 用法：
#   bash doc-platform-lint.sh <markdown-file>             # 默认 JSON 输出
#   bash doc-platform-lint.sh --raw <markdown-file>       # 仅退出码
#   bash doc-platform-lint.sh --shell <markdown-file>     # 输出 shell 变量供 source
#   bash doc-platform-lint.sh --doc-type tech-proposal <file>   # 显式指定文档类型
#
# 文档类型（默认 tech-proposal，仅 tech-proposal 跑全部 8 项；其他类型仅跑通用项）：
#   - tech-proposal：技术方案（8 项全跑）
#   - tech-sharing：技术分享（占位符 + 链接 URL + 标题格式）
#   - release-doc：发布文档（占位符 + 链接 URL + 标题格式）
#
# 8 项检查（tech-proposal）：
#   1. placeholder_clean         人员类占位符必须替换（链接类占位符允许保留）
#   2. urls_valid                所有 URL 必须以 http(s):// 开头
#   3. section_numbering         中文章节编号一二三...连续不跳号
#   4. design_image_filled       「三、页面功能」表格设计图列每行非空
#   5. designer_when_figma       含 figma_url 时视觉设计行必须存在
#   6. required_strings          「前端技术方案」行的说明列必须为「本文档」或「本方案开发」
#   7. required_chapters         8 大必填章节必须齐全（按标题关键字识别，编号自适应；「数据埋点」为选填）
#   8. no_body_title             文档 body 不应包含 # 标题行（文档平台 title 参数管理标题）
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
DOC_TYPE="tech-proposal"
FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --raw)        MODE="raw"; shift ;;
    --shell)      MODE="shell"; shift ;;
    --doc-type)   DOC_TYPE="${2:-tech-proposal}"; shift 2 ;;
    -h|--help)
      sed -n '2,40p' "$0"
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
  echo "❌ 用法: $0 [--raw|--shell] [--doc-type tech-proposal|tech-sharing|release-doc] <markdown-file>" >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  echo "❌ 文件不存在: $FILE" >&2
  exit 2
fi

# ========================================
# 工具函数：剥离代码块（防止 ``` 内的 {xxx} 误判为占位符）
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

# 工具函数：提取 markdown 表格区段（指定章节标题）
extract_section_table() {
  local file="$1"
  local regex="$2"
  awk -v re="$regex" '
    BEGIN { in_section = 0 }
    /^### / {
      if ($0 ~ re) { in_section = 1; next }
      else if (in_section) { in_section = 0 }
    }
    in_section && /^\|/ { print }
  ' "$file"
}

# ========================================
# 检查 1: placeholder_clean
# ========================================
check_placeholder_clean() {
  local file="$1"
  local stripped
  stripped=$(strip_code_blocks "$file")

  local people_pattern='\{产品负责人\}|\{后台开发\}|\{PM\}|\{测试负责人\}|\{前端开发\}|\{视觉设计\}|\{后台负责人\}|\{开发者\}|\{待补充\}'
  local people_hits
  people_hits=$(echo "$stripped" | grep -oE "$people_pattern" | sort -u)
  if [ -n "$people_hits" ]; then
    echo "$people_hits" | while IFS= read -r ph; do
      [ -n "$ph" ] && echo "  - 人员占位符未替换: $ph"
    done
    return 1
  fi
  if echo "$stripped" | grep -qE '\bTBD\b'; then
    echo "  - 占位文本 TBD 未替换"
    return 1
  fi
  return 0
}

# ========================================
# 检查 2: urls_valid
# ========================================
check_urls_valid() {
  local file="$1"
  local stripped
  stripped=$(strip_code_blocks "$file")
  local urls
  urls=$(echo "$stripped" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//;s/\)$//')
  local invalid_count=0
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    case "$url" in
      \#*) continue ;;
    esac
    case "$url" in
      \{*\}) continue ;;
    esac
    case "$url" in
      http://*|https://*) ;;
      *)
        echo "  - 非法 URL 格式: $url"
        invalid_count=$((invalid_count + 1))
        ;;
    esac
  done <<EOF
$urls
EOF
  [ "$invalid_count" -gt 0 ] && return 1
  return 0
}

# ========================================
# 检查 3: section_numbering
# ========================================
check_section_numbering() {
  # 临时关闭 set -u：macOS bash 3.2 中，local + while read + heredoc + 数组下标
  # 四重交互在 set -u 下会导致 cn / cn_nums 变量在 echo 中 unbound（已知 bug）
  # 修复（2026-07-07）：macOS BSD grep 不支持多字节字符在 [...] 类中，
  #   改用 (一|二|三|...) 交替匹配替代 [一二三四...] 字符类。
  set +u
  local file="$1"
  local stripped
  stripped=$(strip_code_blocks "$file")
  local cn_nums=("一" "二" "三" "四" "五" "六" "七" "八" "九" "十")
  local titles
  titles=$(echo "$stripped" | grep -E '^### (一|二|三|四|五|六|七|八|九|十)、' | sed -E 's/^### //' | sed -E 's/、.*//')
  if [ -z "$titles" ]; then
    echo "  - 未找到任何中文编号章节（### 一、xxx）"
    set -u
    return 1
  fi
  local idx=0
  local prev_num=0
  local cn=""
  local n=0
  while IFS= read -r cn; do
    [ -z "${cn:-}" ] && continue
    n=0
    for i in 0 1 2 3 4 5 6 7 8 9; do
      if [ "${cn_nums[$i]}" = "$cn" ]; then
        n=$((i + 1))
        break
      fi
    done
    if [ "$idx" -eq 0 ]; then
      if [ "$n" -ne 1 ]; then
        echo "  - 首个章节编号必须为「一」（实际: $cn）"
        return 1
      fi
    else
      if [ "$n" -ne $((prev_num + 1)) ]; then
        echo "  - 章节编号跳号: 「${cn_nums[$((prev_num - 1))]}」之后应为「${cn_nums[$prev_num]}」，实际为「$cn」"
        return 1
      fi
    fi
    prev_num=$n
    idx=$((idx + 1))
  done <<EOF
$titles
EOF
  if [ "$idx" -eq 0 ]; then
    echo "  - 未找到任何中文编号章节（### 一、xxx）"
    set -u
    return 1
  fi
  set -u
  return 0
}

# ========================================
# 检查 4: design_image_filled
# ========================================
check_design_image_filled() {
  local file="$1"
  local table
  table=$(extract_section_table "$file" "三、页面功能")
  if [ -z "$table" ]; then
    return 0
  fi
  local data_rows
  # 跳过表头（含「功能点」字样）和分隔行（| --- | --- |...）
  # macOS BSD grep 在 [-] 处理上严格，使用 fgrep -v + 单独排除分隔行的 awk 判断
  data_rows=$(echo "$table" | awk '
    /功能点/ { next }
    /^\|[[:space:]:|-]+\|[[:space:]]*$/ { next }
    /^\|/ { print }
  ')
  if [ -z "$data_rows" ]; then
    echo "  - 「三、页面功能」表格无数据行"
    return 1
  fi
  local empty_count=0
  local row_idx=0
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    row_idx=$((row_idx + 1))
    local IFS_BAK="$IFS"
    IFS='|'
    local cells
    read -r -a cells <<<"$row"
    IFS="$IFS_BAK"
    local design_cell="${cells[3]:-}"
    design_cell=$(echo "$design_cell" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
    if [ -z "$design_cell" ]; then
      echo "  - 「三、页面功能」第 $row_idx 行设计图列为空"
      empty_count=$((empty_count + 1))
    fi
  done <<EOF
$data_rows
EOF
  [ "$empty_count" -gt 0 ] && return 1
  return 0
}

# ========================================
# 检查 5: designer_when_figma
# ========================================
check_designer_when_figma() {
  local file="$1"
  local stripped
  stripped=$(strip_code_blocks "$file")
  if ! echo "$stripped" | grep -qE 'figma\.com'; then
    return 0
  fi
  if ! echo "$stripped" | grep -qE '设计稿（Figma）|设计稿\(Figma\)'; then
    echo "  - 文档含 Figma 链接但「需求背景」表格缺「设计稿（Figma）」行"
    return 1
  fi
  return 0
}

# ========================================
# 检查 6: required_strings — 「前端技术方案」行说明列必须是「本文档」或「本方案开发」
# 来源：2026-06-12 复盘——AI 生成「本方案」过于模糊；
#       2026-07-22 修订——「本方案开发」表达生硬，新增「本文档」为推荐写法（兼容旧写法）
# ========================================
check_required_strings() {
  local file="$1"
  local stripped
  stripped=$(strip_code_blocks "$file")
  # 提取「一、需求背景」表格中「前端技术方案」行的第 3 列（说明/地址列）
  # 修复（2026-07-03）：用 grep -q 判断行是否存在 + 取列值；绕过 bash 3.2 的
  #                   local + 命令替换 + set -u 交互导致变量 unset 的已知 bug
  if ! printf "%s\n" "$stripped" | sed -n '/^### 一、需求背景/,/^### /p' | grep -q '前端技术方案'; then
    echo "  - 未找到「前端技术方案」行，无法校验说明列内容"
    return 1
  fi
  local found
  found=$(printf "%s\n" "$stripped" | sed -n '/^### 一、需求背景/,/^### /p' | grep '前端技术方案' | head -1 | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}') 2>/dev/null
  found="${found:-}"
  if [ "$found" != "本文档" ] && [ "$found" != "本方案开发" ]; then
    echo "  - 「前端技术方案」行说明列内容错误: 期望「本文档」或「本方案开发」，实际「${found}」"
    return 1
  fi
  return 0
}

# ========================================
# 检查 7: required_chapters — 8 大必填章节必须齐全（数据埋点选填）
# 来源：2026-07-03 复盘——AI 生成 doc_platform 文档时漏写「代码归属模块/页面功能/回滚方案」等
#        整章，旧 6 项检查只校验内容正确性、不校验章节完整性，导致静默通过。
# 设计：按章节标题关键字识别章节类型（不依赖编号），支持「数据埋点」选填场景——
#       编号自适应（删除数据埋点后，「兼容性问题」从七变六依然能识别）。
# 模板来源：doc-platform-doc.md L478-576 模板一「tech-proposal」
# ========================================
check_required_chapters() {
  local file="$1"
  local stripped
  stripped=$(strip_code_blocks "$file")
  # 提取所有「### N、xxx」的中文章节标题（剥离编号，保留标题文本）
  local titles
  titles=$(printf "%s\n" "$stripped" | grep -E '^### (一|二|三|四|五|六|七|八|九|十)、' | sed -E 's/^### (一|二|三|四|五|六|七|八|九|十)、//')
  # 8 大必填章节（数据埋点「六」为选填，不在强制清单）
  local required=("需求背景" "代码归属模块" "页面功能" "总体设计"
                  "相关接口" "兼容性问题" "风控能力/回滚方案" "测试建议")
  local missing=()
  local kw
  for kw in "${required[@]}"; do
    if ! echo "$titles" | grep -qF "$kw"; then
      missing+=("$kw")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "  - 缺少必填章节（共 ${#missing[@]} 个）: ${missing[*]}"
    return 1
  fi
  return 0
}

# ========================================
# 检查 8: no_body_title — 文档 body 不应包含 # 标题行（文档平台 已通过 title 参数管理）
# 来源：2026-07-07 复盘——AI 生成的 doc_platform 文档 body 中包含 # 标题行，与 文档平台
#       平台 title 字段重复显示，造成视觉冗余。
#       旧 title_format_valid 仅校验 # 行格式，未禁止其存在，方向性错误。
# 设计：
#   - 文档平台有独立 title 参数，平台自动渲染标题
#   - body 应以内容章节开头（### 一、需求背景），不应重复含 # 标题行
#   - 若 body 首行非空为 # xxx（单 #，非 ##/###），视为违规
#   - tech-sharing/release-doc 同样适用此规则
# 规范源：tech-doc/modules/doc-platform-doc.md §模板一（以 ### 一、需求背景 开头无 # 标题）
# ========================================
check_no_body_title() {
  local file="$1"
  local stripped
  stripped=$(strip_code_blocks "$file")

  # 取首个非空行，检查是否为单 # 标题行（非 ##/### 子标题）
  local first_line
  first_line=$(printf "%s\n" "$stripped" | grep -v '^[[:space:]]*$' | head -1)
  if [ -z "$first_line" ]; then
    return 0
  fi

  # 匹配 ^# 但排除 ^##（即仅匹配单 # 标题，不匹配 ##/### 子章节）
  if echo "$first_line" | grep -qE '^#[^#]'; then
    echo "  - body 不应以标题行开头: 「${first_line}」"
    echo "    文档平台已通过 title 参数管理文档标题"
    echo "    请移除 body 中的 # 标题行，直接从 ##/### 内容章节开始"
    echo "    规范源: doc-platform-doc.md 模板一（以 ### 一、需求背景 开头）"
    return 1
  fi
  return 0
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

# 通用项（所有类型都跑）
run_check "placeholder_clean" check_placeholder_clean
run_check "urls_valid" check_urls_valid
run_check "no_body_title" check_no_body_title

# tech-proposal 专属项
case "$DOC_TYPE" in
  tech-proposal)
    run_check "section_numbering" check_section_numbering
    run_check "design_image_filled" check_design_image_filled
    run_check "designer_when_figma" check_designer_when_figma
    run_check "required_strings" check_required_strings
    run_check "required_chapters" check_required_chapters
    ;;
  tech-sharing|release-doc)
    check_results+=("section_numbering=skipped")
    check_results+=("design_image_filled=skipped")
    check_results+=("designer_when_figma=skipped")
    ;;
  *)
    echo "❌ 未知 doc-type: $DOC_TYPE（合法值: tech-proposal|tech-sharing|release-doc）" >&2
    exit 2
    ;;
esac

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
      echo "doc_platform_lint_${kv}"
    done
    [ "$fail_count" -gt 0 ] && exit 1
    exit 0
    ;;
  json|*)
    echo "{"
    echo "  \"file\": \"$FILE\","
    echo "  \"doc_type\": \"$DOC_TYPE\","
    echo "  \"doc_platform_lint\": {"
    last_idx=$((${#check_results[@]} - 1))
    i=0
    for kv in "${check_results[@]}"; do
      k="${kv%%=*}"
      v="${kv#*=}"
      if [ "$v" = "skipped" ]; then
        printf '    "%s": "skipped"' "$k"
      else
        printf '    "%s": %s' "$k" "$v"
      fi
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
