#!/bin/bash
# debug-code-lint.sh - 调试代码扫描 lint
# 兑现 §2「最小入侵」+「确定性用代码」哲学：6 项 grep 检查替代 LLM 肉眼审查
#
# 用法：
#   bash debug-code-lint.sh <file>           # 默认输出 JSON（含 violations 详情）
#   bash debug-code-lint.sh --raw <file>     # 仅返回 0/1 不输出
#
# 检查项（D1-D6）：
#   D1 console_log         禁止 console.log/console.dir/console.trace（不含 error/warn/info）
#   D2 console_debug       禁止 console.debug
#   D3 debugger_statement  禁止 debugger 语句
#   D4 todo_comment        禁止 // TODO 行注释（不含 /* TODO */ 块注释）
#   D5 fixme_comment       禁止 // FIXME
#   D6 xxx_comment         禁止 // XXX
#
# 返回码：0=全部通过, 1=有违规, 2=参数错误/文件不存在

set -u

MODE="json"
[ "${1:-}" = "--raw" ] && { MODE="raw"; shift; }
[ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] && { sed -n '2,16p' "$0"; exit 0; }

TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "❌ 用法: $0 [--raw] <file>" >&2; exit 2; }
[ ! -f "$TARGET" ] && { echo "❌ 文件不存在: $TARGET" >&2; exit 2; }

# 6 项检查的 regex（macOS grep -E 兼容：用 [[:space:]] 而非 \s）
P1='(^|[^a-zA-Z_$])console\.(log|dir|trace)[[:space:]]*\('
P2='(^|[^a-zA-Z_$])console\.debug[[:space:]]*\('
P3='(^|[^a-zA-Z_$])debugger[[:space:]]*;?[[:space:]]*$|^[[:space:]]*debugger[[:space:]]*;?[[:space:]]*$'
P4='//[[:space:]]*TODO([:[:space:]]|$)'
P5='//[[:space:]]*FIXME([:[:space:]]|$)'
P6='//[[:space:]]*XXX([:[:space:]]|$)'

# 检查：grep -q 命中即违规（exit 0 表示找到 = 违规）
check() { grep -qE "$1" "$TARGET" 2>/dev/null && echo false || echo true; }
c1=$(check "$P1"); c2=$(check "$P2"); c3=$(check "$P3")
c4=$(check "$P4"); c5=$(check "$P5"); c6=$(check "$P6")

# JSON 模式额外收集 violations 详情（前 3 条/项，足够人类决策）
if [ "$MODE" = "json" ]; then
  collect() {
    grep -nE "$2" "$TARGET" 2>/dev/null | head -3 | while IFS=: read -r ln rest; do
      esc=$(printf '%s' "$rest" | sed 's/\\/\\\\/g; s/"/\\"/g')
      printf '{"rule":"%s","line":%s,"text":"%s"},' "$1" "$ln" "$esc"
    done
  }
  vs="$(collect console_log "$P1")$(collect console_debug "$P2")$(collect debugger_statement "$P3")$(collect todo_comment "$P4")$(collect fixme_comment "$P5")$(collect xxx_comment "$P6")"
  vs="[${vs%,}]"
  cat <<EOF
{"file":"$TARGET","debug_lint":{"console_log":$c1,"console_debug":$c2,"debugger_statement":$c3,"todo_comment":$c4,"fixme_comment":$c5,"xxx_comment":$c6},"violations":$vs}
EOF
fi

# 任一失败即 exit 1
$c1 && $c2 && $c3 && $c4 && $c5 && $c6 && exit 0 || exit 1
