#!/usr/bin/env bash
# ============================================================================
# optional-chain-lint.sh — 扫描 git diff **增量**中缺少 ?. 的属性访问
#
# ⚠️ 只检查增量代码：通过 git diff HEAD 提取 ^+ 行，不扫描预存代码。
#    若无未提交改动则直接通过。
#
# 用法:
#   bash optional-chain-lint.sh              # 扫描当前 working tree 增量
#   git diff ... | bash optional-chain-lint.sh  # 从 stdin 读 diff
#
# 返回码: 0=无违规, 1=发现违规
# ============================================================================
set -euo pipefail

# 获取 diff 输入
if [[ ! -t 0 ]]; then
  DIFF=$(cat)
else
  DIFF=$(git diff --unified=0 HEAD 2>/dev/null || true)
fi

if [[ -z "$DIFF" ]]; then
  echo "✅ 可选链检查通过（无增量改动）"
  exit 0
fi

# 提取 + 行 → 排除安全模式 → 匹配 word.word 模式
# 关闭 pipefail，避免中间 grep 无匹配时整条管道失败
set +o pipefail
RESULT=$(echo "$DIFF" \
  | grep '^\+' \
  | grep -v '^+++' \
  | sed 's/?\./??/g' \
  | grep -v '^\+\s*//' \
  | grep -v '^\+\s*\*' \
  | grep -v '^\+\s*/\*' \
  | grep -vE '^\+\s*(import|export|require)\s' \
  | grep -vE 'console\.' \
  | grep -vE '\bstyles?\b\.' \
  | grep -vE '\.(then|catch|finally)' \
  | grep -vE '[0-9]\.[0-9]' \
  | grep -vE 'classNames?' \
  | grep -vE '\]\]\.|\}\]\.' \
  | grep -E '([a-zA-Z_][a-zA-Z0-9_]*|])\.[a-zA-Z_][a-zA-Z0-9_]+' \
  | sed 's/^+//')
set -o pipefail

if [[ -n "$RESULT" ]]; then
  COUNT=$(echo "$RESULT" | wc -l | tr -d ' ')
  echo "❌ 可选链检查未通过：发现 ${COUNT} 处疑似缺少 ?. 的属性访问"
  echo ""
  echo "$RESULT"
  echo ""
  echo "⛔ 请将以上行中的裸 . 属性访问替换为 ?."
  exit 1
else
  echo "✅ 可选链检查通过"
  exit 0
fi
