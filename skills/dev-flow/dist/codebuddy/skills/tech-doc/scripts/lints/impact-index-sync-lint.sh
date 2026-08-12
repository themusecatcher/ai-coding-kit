#!/bin/bash
# impact-index-sync-lint.sh — 检查 devlog ↔ impact-index 因果闭环（tech-doc Skill 资产）
#
# 设计哲学：「确定性事实用代码」——devlog 与 impact-index 之间是否双向闭环是物理事实，
# 不应只用提示词约束 LLM「禁止跳过索引追加」，而要在物理上验证。
#
# 规则真相源：
#   - tech-doc/modules/devlog.md §七：「devlog 生成 = 索引追加，两者绑定执行」
#   - 索引管理模块：模板与字段提取规则
#
# 检查 5 项：
#   1. devlog_has_index_entry      每个 dev-logs/<folder>/devlog.md 在 impact-index.md 中有索引条目
#   2. index_entry_devlog_exists   每个索引条目引用的 devlog 文件实际存在（无僵尸条目）
#   3. devlog_link_valid           索引条目末尾的 [详情](./xxx/devlog.md) 链接路径合法
#   4. required_fields_present     每个索引条目包含 8 个必填字段（项目/分支/任务平台/涉及文件/涉及接口/涉及功能模块/关键字段/Key/上下游/devlog）
#   5. no_critical_pending         严禁字段（涉及文件/涉及功能模块/关键字段/Key/上下游）不应保留「待补充」作为唯一值
#
# 用法：
#   bash impact-index-sync-lint.sh                                       # 默认扫描 ~/.codebuddy/dev-logs/，JSON 输出
#   bash impact-index-sync-lint.sh --raw                                  # 仅退出码
#   bash impact-index-sync-lint.sh --shell                                # 输出 shell 变量供 source
#   bash impact-index-sync-lint.sh --dev-logs <dir> --index <file>        # 显式指定路径（测试用）
#   bash impact-index-sync-lint.sh --skip-folder <folder>                 # 排除指定 dev-logs 子目录（可多次）
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
DEV_LOGS_DIR="$HOME/.codebuddy/dev-logs"
INDEX_FILE=""
SKIP_FOLDERS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --raw)         MODE="raw"; shift ;;
    --shell)       MODE="shell"; shift ;;
    --dev-logs)    DEV_LOGS_DIR="${2:-}"; shift 2 ;;
    --index)       INDEX_FILE="${2:-}"; shift 2 ;;
    --skip-folder) SKIP_FOLDERS+=("${2:-}"); shift 2 ;;
    -h|--help)
      sed -n '2,32p' "$0"
      exit 0
      ;;
    *)
      echo "❌ 未知参数: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$INDEX_FILE" ]; then
  INDEX_FILE="$DEV_LOGS_DIR/impact-index.md"
fi

if [ ! -d "$DEV_LOGS_DIR" ]; then
  echo "❌ dev-logs 目录不存在: $DEV_LOGS_DIR" >&2
  exit 2
fi
if [ ! -f "$INDEX_FILE" ]; then
  echo "❌ impact-index.md 不存在: $INDEX_FILE" >&2
  exit 2
fi

# ========================================
# 工具函数
# ========================================

# 列出 dev-logs 下所有「devlog 子目录」（即包含 devlog.md 的子目录）
list_devlog_folders() {
  local dir="$1"
  if [ ! -d "$dir" ]; then return 0; fi
  find "$dir" -mindepth 2 -maxdepth 2 -name 'devlog.md' -type f 2>/dev/null | while IFS= read -r f; do
    basename "$(dirname "$f")"
  done
}

is_skipped_folder() {
  local folder="$1"
  for s in "${SKIP_FOLDERS[@]:-}"; do
    [ -z "$s" ] && continue
    [ "$folder" = "$s" ] && return 0
  done
  return 1
}

# 从 impact-index.md 提取所有 devlog 链接引用的文件夹名
# 匹配形如 [详情](./20260421_fix_xxx/devlog.md) 的链接
extract_index_devlog_folders() {
  local file="$1"
  grep -oE '\[详情\]\(\./[^/)]+/devlog\.md\)' "$file" 2>/dev/null \
    | sed -E 's|^\[详情\]\(\./||;s|/devlog\.md\)$||'
}

# 把 impact-index.md 切成多个「条目块」，每块以 `## ` 开头并到下一个 `## ` 或文件末为止
# 输出：每个块用 `␞` 分隔（ASCII 0x1E），便于后续按索引读取
split_index_blocks() {
  local file="$1"
  awk '
    BEGIN { buf = ""; first = 1 }
    /^## / {
      if (!first) { printf "%s\036", buf }
      buf = $0 "\n"; first = 0; next
    }
    { buf = buf $0 "\n" }
    END { if (!first) printf "%s\036", buf }
  ' "$file"
}

# ========================================
# 检查 1: devlog_has_index_entry
# 每个 dev-logs/<folder>/devlog.md 都应在 impact-index 中有对应条目
# ========================================
check_devlog_has_index_entry() {
  local missing=()
  local index_folders
  index_folders=$(extract_index_devlog_folders "$INDEX_FILE")

  while IFS= read -r folder; do
    [ -z "$folder" ] && continue
    if is_skipped_folder "$folder"; then continue; fi
    # 在 index_folders 中查找
    if ! echo "$index_folders" | grep -Fxq "$folder"; then
      missing+=("$folder")
    fi
  done < <(list_devlog_folders "$DEV_LOGS_DIR")

  if [ "${#missing[@]}" -gt 0 ]; then
    for m in "${missing[@]}"; do
      echo "  - devlog 缺失索引条目: $m"
    done
    return 1
  fi
  return 0
}

# ========================================
# 检查 2: index_entry_devlog_exists
# 每个索引条目引用的 devlog 路径必须实际存在
# ========================================
check_index_entry_devlog_exists() {
  local missing=()
  local index_folders
  index_folders=$(extract_index_devlog_folders "$INDEX_FILE")

  while IFS= read -r folder; do
    [ -z "$folder" ] && continue
    if [ ! -f "$DEV_LOGS_DIR/$folder/devlog.md" ]; then
      missing+=("$folder")
    fi
  done <<< "$index_folders"

  if [ "${#missing[@]}" -gt 0 ]; then
    for m in "${missing[@]}"; do
      echo "  - 索引条目引用的 devlog 不存在: $m/devlog.md"
    done
    return 1
  fi
  return 0
}

# ========================================
# 检查 3: devlog_link_valid
# 索引条目末尾的 devlog 链接路径必须符合 [详情](./folder/devlog.md) 格式
# 检查每个 ## 条目块中是否含有合法的 **devlog**：[详情](./xxx/devlog.md)
# ========================================
check_devlog_link_valid() {
  local invalid=()
  local current_title=""
  local has_link_in_block=0
  local in_block=0

  # 用 awk 流式扫描，检测每个 ## 块是否含合法 devlog 链接
  awk '
    BEGIN { in_block = 0; title = ""; has_link = 0 }
    /^## / {
      if (in_block && has_link == 0) { print "MISSING:" title }
      title = $0
      in_block = 1
      has_link = 0
      next
    }
    /\*\*devlog\*\*：?\[详情\]\(\.\/[^\/)]+\/devlog\.md\)/ {
      if (in_block) has_link = 1
    }
    END { if (in_block && has_link == 0) print "MISSING:" title }
  ' "$INDEX_FILE" | while IFS= read -r line; do
    case "$line" in
      MISSING:*)
        title="${line#MISSING:}"
        echo "  - 条目缺失合法 devlog 链接: $title"
        ;;
    esac
  done | tee /tmp/.iils_check3_$$ >/dev/null

  if [ -s "/tmp/.iils_check3_$$" ]; then
    cat "/tmp/.iils_check3_$$"
    rm -f "/tmp/.iils_check3_$$"
    return 1
  fi
  rm -f "/tmp/.iils_check3_$$"
  return 0
}

# ========================================
# 检查 4: required_fields_present
# 每个索引条目应包含模板规定的必填字段
# ========================================
check_required_fields_present() {
  local violations=()

  # 必填字段（每个条目必须含的字段标签）
  local required_fields=(
    "项目"
    "分支"
    "任务平台"
    "涉及文件"
    "涉及接口"
    "涉及功能模块"
    "关键字段/Key"
    "上下游"
  )

  # 用 awk 切块扫描
  local tmp_blocks="/tmp/.iils_blocks_$$"
  awk '
    BEGIN { idx = 0; buf = "" }
    /^## / {
      if (idx > 0) print buf "\036"
      buf = $0
      idx = 1
      next
    }
    idx > 0 { buf = buf "\n" $0 }
    END { if (idx > 0) print buf "\036" }
  ' "$INDEX_FILE" > "$tmp_blocks"

  # 把 0x1E 当分隔符，逐块检查
  local block_title
  while IFS= read -r -d $'\036' block; do
    [ -z "${block// /}" ] && continue
    block_title=$(echo "$block" | head -n1)
    # 跳过空标题或非 ## 开头的块（防御脸）
    case "$block_title" in
      "## "*) ;;
      *) continue ;;
    esac
    for field in "${required_fields[@]}"; do
      # 字段标签格式为 - **{name}**：xxx
      if ! echo "$block" | grep -qE "^- \*\*${field}\*\*"; then
        violations+=("$block_title -> 缺少字段: $field")
      fi
    done
  done < "$tmp_blocks"

  rm -f "$tmp_blocks"

  if [ "${#violations[@]}" -gt 0 ]; then
    for v in "${violations[@]}"; do
      echo "  - $v"
    done
    return 1
  fi
  return 0
}

# ========================================
# 检查 5: no_critical_pending
# 关键字段不应保留「待补充」作为唯一值（项目/分支/涉及文件/涉及功能模块/关键字段/Key/上下游）
# 允许保留「待补充」的字段：任务平台、上线时间
# ========================================
check_no_critical_pending() {
  # 改用单 awk 实现：避开 macOS bash 3.2 在 set -u + UTF-8 字段名（含「/」）+
  # 嵌套 for 循环时触发的字符流损坏（line N: value�: unbound variable）
  awk '
    BEGIN {
      # 关键字段：值若为占位则视为缺失。键名含「/」也安全（awk 字符串处理稳定）
      n = split("项目|分支|涉及文件|涉及功能模块|关键字段/Key|上下游", fields, "|")
      block_title = ""
      block_idx = 0
      total_violations = 0
      delete block_lines
    }
    function flush_block(   i, j, line, field, prefix, plen, rest, val, found_field, is_placeholder) {
      if (block_title == "") return
      for (j = 1; j <= n; j++) {
        field = fields[j]
        prefix = "- **" field "**"
        plen = length(prefix)
        found_field = 0
        val = ""
        for (i = 1; i <= block_idx; i++) {
          line = block_lines[i]
          if (substr(line, 1, plen) == prefix) {
            found_field = 1
            rest = substr(line, plen + 1)
            sub(/^[：:][[:space:]]*/, "", rest)
            sub(/^[[:space:]]+/, "", rest)
            val = rest
            break
          }
        }
        # 字段未找到由 check_required_fields_present 负责，本检查只判占位
        if (!found_field) continue
        is_placeholder = 0
        if (val == "" || val == "待补充" || val == "TBD" || val == "tbd" \
            || val == "无" || val == "无。" || val == "-" || val == "--") {
          is_placeholder = 1
        }
        if (is_placeholder) {
          printf "  - %s -> 字段「%s」值为占位（%s）需补全\n", block_title, field, val
          total_violations++
        }
      }
    }
    /^## / {
      flush_block()
      block_title = $0
      block_idx = 0
      delete block_lines
      next
    }
    {
      if (block_title != "") {
        block_idx++
        block_lines[block_idx] = $0
      }
    }
    END {
      flush_block()
      if (total_violations > 0) exit 1
      exit 0
    }
  ' "$INDEX_FILE"
  return $?
}

# ========================================
# 主流程：跑所有检查
# ========================================
check_results=()
failures=()

run_check() {
  local key="$1"
  local fn="$2"
  local out
  out=$("$fn" 2>&1)
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    check_results+=("${key}=true")
  else
    check_results+=("${key}=false")
    if [ -n "$out" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] && failures+=("[$key] $line")
      done <<< "$out"
    else
      failures+=("[$key] 检查失败（无详情）")
    fi
  fi
}

run_check "devlog_has_index_entry"    check_devlog_has_index_entry
run_check "index_entry_devlog_exists" check_index_entry_devlog_exists
run_check "devlog_link_valid"         check_devlog_link_valid
run_check "required_fields_present"   check_required_fields_present
run_check "no_critical_pending"       check_no_critical_pending

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
      echo "impact_index_sync_lint_${kv}"
    done
    [ "$fail_count" -gt 0 ] && exit 1
    exit 0
    ;;
  json|*)
    echo "{"
    echo "  \"dev_logs_dir\": \"$DEV_LOGS_DIR\","
    echo "  \"index_file\": \"$INDEX_FILE\","
    echo "  \"impact_index_sync_lint\": {"
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
