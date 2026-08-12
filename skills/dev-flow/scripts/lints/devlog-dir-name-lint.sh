#!/bin/bash
# devlog-dir-name-lint.sh - dev-logs 目录命名 lint（4 项检查的单一权威源）
# 实现 references/gate-validator.md §「dev-logs 目录命名门控」的 4 项检查
#
# 用法：
#   bash devlog-dir-name-lint.sh <dir-name>           # 默认输出 JSON
#   bash devlog-dir-name-lint.sh --raw <dir-name>     # 仅返回 0/1，不输出 JSON
#   bash devlog-dir-name-lint.sh --shell <dir-name>   # 输出 4 个 boolean shell 变量（供脚本 source 使用）
#
# 返回码：
#   0  4 项全部通过
#   1  任一项失败
#   2  参数错误

set -u

# 解析参数
MODE="json"
DIR_NAME=""

case "${1:-}" in
  --raw)   MODE="raw"; DIR_NAME="${2:-}" ;;
  --shell) MODE="shell"; DIR_NAME="${2:-}" ;;
  --help|-h)
    sed -n '2,15p' "$0"
    exit 0
    ;;
  *) DIR_NAME="${1:-}" ;;
esac

if [ -z "$DIR_NAME" ]; then
  echo "❌ 用法: $0 [--raw|--shell] <dir-name>" >&2
  exit 2
fi

# ========================================
# 4 项检查（与 schema 定义和 gate-validator.md 保持完全一致）
# ========================================

# 1. format_matched: ^\d{8}_(feat|fix|opt|refactor)_[^\s/\\]+$
format_matched=false
if [[ "$DIR_NAME" =~ ^[0-9]{8}_(feat|fix|opt|refactor)_[^\ /\\]+$ ]]; then
  format_matched=true
fi

# 2. type_valid: 类型段 ∈ {feat, fix, opt, refactor}
type_valid=false
if echo "$DIR_NAME" | grep -qE '_(feat|fix|opt|refactor)_'; then
  type_valid=true
fi

# 3. brief_has_chinese: 简述段至少含 1 个汉字
brief_has_chinese=false
if printf '%s' "$DIR_NAME" | LC_ALL=C grep -qE $'[\xe4-\xe9][\x80-\xbf][\x80-\xbf]'; then
  # macOS bash 3 + grep 对 UTF-8 中文字符的兼容写法（[一-龥] 在某些 locale 下失效）
  brief_has_chinese=true
fi

# 4. no_project_suffix: 末尾不含项目缩写
# 用户可根据自己的项目名自定义此列表（或从 config/org.yaml 读取）
no_project_suffix=true
for suffix in my-project my-lib my-components my-app my-service; do
  if [[ "$DIR_NAME" =~ _${suffix}$ ]]; then
    no_project_suffix=false
    break
  fi
done

# ========================================
# 输出
# ========================================
case "$MODE" in
  raw)
    # 仅返回退出码
    ;;
  shell)
    # 输出 4 个变量供 source 使用
    echo "name_lint_format_matched=$format_matched"
    echo "name_lint_type_valid=$type_valid"
    echo "name_lint_brief_has_chinese=$brief_has_chinese"
    echo "name_lint_no_project_suffix=$no_project_suffix"
    ;;
  json|*)
    # 默认输出 JSON
    cat <<EOF
{
  "dir_name": "$DIR_NAME",
  "name_lint": {
    "format_matched": $format_matched,
    "type_valid": $type_valid,
    "brief_has_chinese": $brief_has_chinese,
    "no_project_suffix": $no_project_suffix
  }
}
EOF
    ;;
esac

# 任一失败即 exit 1
if $format_matched && $type_valid && $brief_has_chinese && $no_project_suffix; then
  exit 0
else
  exit 1
fi
