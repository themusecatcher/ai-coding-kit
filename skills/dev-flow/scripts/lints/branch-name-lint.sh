#!/bin/bash
# branch-name-lint.sh - Git 分支命名 lint（4 项检查）
# 实现 references/shared-rules.md §6「Git 分支命名规范」的程序化校验
#
# 用法：
#   bash branch-name-lint.sh <branch-name>           # 默认输出 JSON
#   bash branch-name-lint.sh --raw <branch-name>     # 仅返回 0/1，不输出 JSON
#   bash branch-name-lint.sh --shell <branch-name>   # 输出 4 个 boolean shell 变量
#
# 校验规则（对齐 shared-rules.md §6）：
#   1. prefix_valid: 前缀 ∈ {feature/, bugfix/, hotfix/, test/, i18n/, private/, feature_dev/, sub-master/, dev/}
#   2. words_count_ok: 功能简述部分 ≤3 个单词（短横线分割计数）
#   3. lowercase_hyphen: 功能简述全小写 + 短横线连接（无驼峰/下划线/大写）
#   4. no_invalid_chars: 无空格/中文/特殊符号
#
# 特殊处理：
#   - feature_dev/ 格式为 feature_dev/<功能简述>/<开发者>，功能简述取中间段
#   - sub-master/ 前缀含短横线，整体视为前缀
#   - user_specified 场景（用户直接告知已有分支）可传 --skip 跳过校验
#
# 返回码：
#   0  4 项全部通过
#   1  任一项失败
#   2  参数错误

set -u

# 解析参数
MODE="json"
BRANCH_NAME=""

case "${1:-}" in
  --raw)   MODE="raw"; BRANCH_NAME="${2:-}" ;;
  --shell) MODE="shell"; BRANCH_NAME="${2:-}" ;;
  --skip)
    # 用户指定分支，跳过校验
    echo '{"branch_name":"user_specified","branch_name_lint":{"prefix_valid":true,"words_count_ok":true,"lowercase_hyphen":true,"no_invalid_chars":true},"skipped":true}'
    exit 0
    ;;
  --help|-h)
    sed -n '2,25p' "$0"
    exit 0
    ;;
  *) BRANCH_NAME="${1:-}" ;;
esac

if [ -z "$BRANCH_NAME" ]; then
  echo "❌ 用法: $0 [--raw|--shell|--skip] <branch-name>" >&2
  exit 2
fi

# ========================================
# 合法前缀列表（对齐 shared-rules.md §6 命名格式表）
# ========================================
VALID_PREFIXES=(
  "feature/"
  "bugfix/"
  "hotfix/"
  "test/"
  "i18n/"
  "private/"
  "feature_dev/"
  "sub-master/"
  "dev/"
)

# ========================================
# 提取前缀和功能简述
# ========================================
PREFIX=""
BRIEF=""

for p in "${VALID_PREFIXES[@]}"; do
  if [[ "$BRANCH_NAME" == ${p}* ]]; then
    PREFIX="$p"
    BRIEF="${BRANCH_NAME#$p}"
    break
  fi
done

# feature_dev/ 特殊处理：格式为 feature_dev/<功能简述>/<开发者>
# 功能简述取中间段（去掉最后一个 / 后的开发者名）
if [[ "$PREFIX" == "feature_dev/" ]] && [[ "$BRIEF" == */* ]]; then
  # 去掉最后一段（开发者用户名）
  BRIEF="${BRIEF%/*}"
fi

# ========================================
# 4 项检查
# ========================================

# 1. prefix_valid: 前缀是否在合法列表中
prefix_valid=false
if [ -n "$PREFIX" ]; then
  prefix_valid=true
fi

# 2. words_count_ok: 功能简述 ≤3 个单词（短横线分割计数）
words_count_ok=false
if [ -n "$BRIEF" ]; then
  # 按短横线分割计数
  WORD_COUNT=$(echo "$BRIEF" | awk -F'-' '{print NF}')
  if [ "$WORD_COUNT" -le 3 ]; then
    words_count_ok=true
  fi
fi

# 3. lowercase_hyphen: 全小写 + 短横线连接
#    - 无大写字母（排除驼峰）
#    - 无下划线（排除 snake_case，但 feature_dev 前缀本身的下划线已在提取时去除）
#    - 仅允许 [a-z0-9-]
lowercase_hyphen=false
if [ -n "$BRIEF" ]; then
  if echo "$BRIEF" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    lowercase_hyphen=true
  fi
fi

# 4. no_invalid_chars: 无空格/中文/特殊符号
#    功能简述中不含空格、中文字符、特殊符号（仅允许 [a-z0-9-]）
no_invalid_chars=false
if [ -n "$BRIEF" ]; then
  # 检测是否含有非法字符（非 a-z0-9-）
  if ! echo "$BRIEF" | grep -qE '[^a-z0-9-]'; then
    no_invalid_chars=true
  fi
fi

# ========================================
# 输出
# ========================================
case "$MODE" in
  raw)
    # 仅返回退出码
    ;;
  shell)
    echo "branch_lint_prefix_valid=$prefix_valid"
    echo "branch_lint_words_count_ok=$words_count_ok"
    echo "branch_lint_lowercase_hyphen=$lowercase_hyphen"
    echo "branch_lint_no_invalid_chars=$no_invalid_chars"
    echo "branch_lint_word_count=$WORD_COUNT"
    echo "branch_lint_prefix=$PREFIX"
    echo "branch_lint_brief=$BRIEF"
    ;;
  json|*)
    cat <<EOF
{
  "branch_name": "$BRANCH_NAME",
  "branch_name_lint": {
    "prefix_valid": $prefix_valid,
    "words_count_ok": $words_count_ok,
    "lowercase_hyphen": $lowercase_hyphen,
    "no_invalid_chars": $no_invalid_chars
  },
  "details": {
    "prefix": "$PREFIX",
    "brief": "$BRIEF",
    "word_count": ${WORD_COUNT:-0}
  }
}
EOF
    ;;
esac

# 任一失败即 exit 1
if $prefix_valid && $words_count_ok && $lowercase_hyphen && $no_invalid_chars; then
  exit 0
else
  exit 1
fi
