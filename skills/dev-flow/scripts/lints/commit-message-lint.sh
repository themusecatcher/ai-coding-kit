#!/bin/bash
# commit-message-lint.sh - Commit message 格式校验
# 实现 开发规范-红线.mdc §「Commit 格式」的程序化校验
#
# 用法：
#   bash commit-message-lint.sh <message>        # JSON 输出
#   bash commit-message-lint.sh --raw <message>  # 仅返回 0/1
#
# 校验规则（对齐 开发规范-红线.mdc + shared-rules.md §1）：
#   1. format_valid: 匹配 ^(feat|fix|opt|refactor|chore|docs|style|test|ci|perf|revert): .+$
#   2. no_scope: type 后不含括号 ()（禁止 feat(scope): xxx 格式）
#   3. no_trailing_dot: header 末尾不含句号
#
# 返回码：
#   0  全部通过
#   1  任一项失败
#   2  参数错误

set -u

# 解析参数
MODE="json"
MSG=""

case "${1:-}" in
  --raw)   MODE="raw"; shift; MSG="$*" ;;
  --help|-h) sed -n '2,17p' "$0"; exit 0 ;;
  *) MSG="$*" ;;
esac

if [ -z "$MSG" ]; then
  echo "❌ 用法: $0 [--raw] <message>" >&2
  exit 2
fi

# 取第一行（commit header）
HEADER=$(echo "$MSG" | head -1)

# ========================================
# 3 项检查
# ========================================

# 1. format_valid: 必须匹配 <type>: <description>
#    合法 type: feat|fix|opt|refactor|chore|docs|style|test|ci|perf|revert
format_valid=false
if echo "$HEADER" | grep -qE '^(feat|fix|opt|refactor|chore|docs|style|test|ci|perf|revert): .+$'; then
  format_valid=true
fi

# 2. no_scope: type 后不含括号（禁止 type(scope): 格式）
no_scope=false
if ! echo "$HEADER" | grep -qE '^[a-z]+\('; then
  no_scope=true
fi

# 3. no_trailing_dot: header 末尾不含句号（中/英）
no_trailing_dot=false
if ! echo "$HEADER" | grep -qE '[.。]$'; then
  no_trailing_dot=true
fi

# ========================================
# 输出
# ========================================
case "$MODE" in
  raw)
    # 仅返回退出码
    ;;
  json|*)
    # 转义 JSON 中的特殊字符
    HEADER_ESC=$(printf '%s' "$HEADER" | sed 's/\\/\\\\/g; s/"/\\"/g')
    cat <<EOF
{
  "header": "$HEADER_ESC",
  "commit_lint": {
    "format_valid": $format_valid,
    "no_scope": $no_scope,
    "no_trailing_dot": $no_trailing_dot
  }
}
EOF
    ;;
esac

# 任一失败即 exit 1
if $format_valid && $no_scope && $no_trailing_dot; then
  exit 0
else
  exit 1
fi
