#!/bin/bash
# validate-metrics-yaml.sh — 度量 YAML 确定性校验（2026-06-05 重写）
# 设计哲学：确定性的事情用代码。
# 校验内容：
#   1. Tier 1 必填字段完整性（与 gen-dashboard.py REQUIRED_FIELDS 同步）
#   2. requirement_id 与文件名一致性（命名规范门控）
#   3. working-context 文件存在性（交叉验证）
# 用法: bash validate-metrics-yaml.sh <yaml-file>
# 退出码: 0=通过 / 1=校验失败

set -euo pipefail

YAML_FILE="${1:-}"

if [ ! -f "$YAML_FILE" ]; then
  echo '{"result":"fail","reason":"yaml_file_not_found"}'
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:?}"
REPORTS_DIR="${HOME}/.codebuddy/.metrics/reports"
WC_DIR="${HOME}/.codebuddy/working-context"

# ========================================
# 辅助：从 YAML 读取顶层字段值
# ========================================
get_field() {
  local field="$1"
  python3 -c "
import yaml, sys, json
with open('$YAML_FILE') as f:
    for doc in yaml.safe_load_all(f):
        if isinstance(doc, dict):
            val = doc.get('$field')
            if val is not None:
                print(json.dumps(val, ensure_ascii=False))
                sys.exit(0)
print('__MISSING__')
" 2>/dev/null || echo "__ERROR__"
}

# ========================================
# 校验 1：Tier 1 必填字段完整性
# （与 gen-dashboard.py REQUIRED_FIELDS 保持严格同步）
# ========================================
TIER1_FIELDS=(
  "requirement_id" "title" "mode" "complexity"
  "files_changed" "lines_added" "lines_deleted"
  "rollback_count" "user_corrections" "first_time_right"
  "l2_issues_found" "bugs_found_in_verify"
  "plan_adherence"  # 2026-07-22: 与 metrics_lib.py 同步升级为 REQUIRED
)

# ========================================
# 辅助：从 YAML 读取嵌套字段值（如 extra.title）
# ========================================
get_nested_field() {
  local field_path="$1"  # e.g., "extra.title"
  python3 -c "
import yaml, sys, json
with open('$YAML_FILE') as f:
    for doc in yaml.safe_load_all(f):
        if isinstance(doc, dict):
            val = doc
            for key in '$field_path'.split('.'):
                if isinstance(val, dict) and key in val:
                    val = val[key]
                else:
                    val = None
                    break
            if val is not None:
                # Convert non-string values to string for comparison
                if isinstance(val, str):
                    print(json.dumps(val, ensure_ascii=False))
                else:
                    print(json.dumps(str(val), ensure_ascii=False))
                sys.exit(0)
print('__MISSING__')
" 2>/dev/null || echo "__ERROR__"
}

# ========================================
# 辅助：从工作上下文中读取 doc_platform_tech_proposal.locked_title
# ========================================
get_wc_locked_title() {
  local slug="$1"
  local wc_file="${WC_DIR}/${slug}.md"
  if [ ! -f "$wc_file" ]; then
    echo "__MISSING__"
    return
  fi
  python3 -c "
import yaml, sys, json
with open('$wc_file') as f:
    content = f.read()
parts = content.split('---', 2)
if len(parts) >= 3:
    fm = yaml.safe_load(parts[1])
    lt = fm.get('doc_platform_tech_proposal', {}).get('locked_title')
    if lt:
        print(json.dumps(lt, ensure_ascii=False))
        sys.exit(0)
print('__MISSING__')
" 2>/dev/null || echo "__ERROR__"
}

errors=()

for field in "${TIER1_FIELDS[@]}"; do
  val=$(get_field "$field")
  # 移除 JSON 引号包裹
  val_clean=$(echo "$val" | sed 's/^"//;s/"$//')
  if [ "$val_clean" = "__MISSING__" ] || [ "$val_clean" = "__ERROR__" ] || [ "$val_clean" = "null" ] || [ "$val_clean" = "" ]; then
    errors+=("missing_tier1:$field")
  fi
done

# ========================================
# 校验 2：requirement_id == 文件名（不含 .yaml）
# ========================================
REPORT_FILENAME=$(basename "$YAML_FILE" .yaml)
REQ_ID_RAW=$(get_field "requirement_id" | sed 's/^"//;s/"$//')

if [ "$REQ_ID_RAW" != "$REPORT_FILENAME" ]; then
  errors+=("naming_mismatch:requirement_id='$REQ_ID_RAW' != filename='$REPORT_FILENAME'")
fi

# ========================================
# 校验 3：working-context/{slug}.md 存在
# 同时检查 archive 子目录
# 若不存在，自动搜索同日期前缀的 WC 文件作为修正建议
# ========================================
WC_EXISTS=false
ARCHIVED=false
if [ -f "$WC_DIR/$REPORT_FILENAME.md" ]; then
  WC_EXISTS=true
elif [ -f "$WC_DIR/archive/$REPORT_FILENAME.md" ]; then
  WC_EXISTS=true
  ARCHIVED=true
fi

if [ "$WC_EXISTS" = false ]; then
  # 提取日期前缀 YYYYMMDD
  DATE_PREFIX=$(echo "$REPORT_FILENAME" | grep -oE '^[0-9]{8}' || echo "")
  SUGGESTIONS=""
  if [ -n "$DATE_PREFIX" ] && [ -d "$WC_DIR" ]; then
    # 搜索同日期前缀的 WC 文件（顶层 + archive 子目录）
    # 使用管道方式避免 subshell 内部的 grep -q 副作用
    MATCHES=""
    MATCHES=$({
      for f in "$WC_DIR"/*.md; do
        [ -f "$f" ] || continue
        basename "$f" .md
      done
      if [ -d "$WC_DIR/archive" ]; then
        find "$WC_DIR/archive" -name "*.md" -type f 2>/dev/null | while IFS= read -r f; do
          basename "$f" .md
        done
      fi
    } | grep "^${DATE_PREFIX}_" | sort -u || true)
    if [ -n "$MATCHES" ]; then
      SUGGESTIONS=$(echo "$MATCHES" | tr '\n' '|' | sed 's/|$//')
    fi
  fi

  if [ -n "$SUGGESTIONS" ]; then
    errors+=("wc_missing:working-context/$REPORT_FILENAME.md not found. Same-date WC files: $SUGGESTIONS")
  else
    errors+=("wc_missing:working-context/$REPORT_FILENAME.md not found (check archive too)")
  fi
fi

# ========================================
# 校验 4：title 交叉校验
#   title 应与 extra.title 或工作上下文 locked_title 一致
#   不一致时输出 WARN（不阻断），提示 AI 修复
# ========================================
TITLE_RAW=$(get_field "title" | sed 's/^"//;s/"$//')
EXTRA_TITLE_RAW=$(get_nested_field "extra.title" | sed 's/^"//;s/"$//')
LOCKED_TITLE_RAW=$(get_wc_locked_title "$REPORT_FILENAME" | sed 's/^"//;s/"$//')

TITLE_MISMATCH=false
# 策略 1：与 extra.title 对比
if [ "$EXTRA_TITLE_RAW" != "__MISSING__" ] && [ "$EXTRA_TITLE_RAW" != "__ERROR__" ] && [ -n "$EXTRA_TITLE_RAW" ]; then
  if [ "$TITLE_RAW" != "$EXTRA_TITLE_RAW" ]; then
    TITLE_MISMATCH=true
    TITLE_SUGGEST="$EXTRA_TITLE_RAW"
  fi
fi
# 策略 2：与工作上下文 locked_title 对比（去掉【】前缀后）
if [ "$TITLE_MISMATCH" = false ] && [ "$LOCKED_TITLE_RAW" != "__MISSING__" ] && [ "$LOCKED_TITLE_RAW" != "__ERROR__" ] && [ -n "$LOCKED_TITLE_RAW" ]; then
  # 去掉【xxx】前缀，提取核心标题
  LOCKED_CORE=$(echo "$LOCKED_TITLE_RAW" | sed 's/^【[^】]*】//')
  if [ "$TITLE_RAW" != "$LOCKED_TITLE_RAW" ] && [ "$TITLE_RAW" != "$LOCKED_CORE" ]; then
    TITLE_MISMATCH=true
    TITLE_SUGGEST="$LOCKED_CORE"
  fi
fi

if [ "$TITLE_MISMATCH" = true ]; then
  errors+=("title_mismatch:title='$TITLE_RAW' should be '$TITLE_SUGGEST' (inherited from extra.title or doc_platform locked_title)")
fi

# ========================================
# 输出
# ========================================
if [ ${#errors[@]} -eq 0 ]; then
  echo '{"result":"pass","fields_checked":'"${#TIER1_FIELDS[@]}"',"naming_consistent":true,"wc_exists":true}'
  exit 0
else
  errors_json=$(printf '%s\n' "${errors[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin]))")
  echo '{"result":"fail","violations":'"$errors_json"'}'
  exit 1
fi
