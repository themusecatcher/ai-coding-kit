#!/usr/bin/env bash
# ===========================================================================
# code-block-purity-check.sh
# ---------------------------------------------------------------------------
# 用途：校验 issue-trace 根因报告中的「代码块原文一致性」，防止 LLM 在
#       引用源码时添加 `// ❌` `// ⚠️` `// 🚨` `// root cause` 等评价性自创注释。
#
# 用法：
#   bash code-block-purity-check.sh <报告 md 文件>
#
# 退出码：
#   0 — 全部通过（无可疑评价性自创注释）
#   1 — 检测到代码块内有自创评价性注释
#   2 — 参数错误 / 文件不存在
#
# 设计哲学（确定性用代码）：
#   - 反模式 #10：代码块内的 `// ❌` / `// ⚠️` / `// 🚨` / `// root cause`
#     等评价性注释通常是 LLM 自创，不在磁盘原文 → 直接拒收
#   - 严格的字符级原文比对成本高，本脚本采用「明显违规模式扫描」做快速门控
#     深度比对建议人工 sed -n 抽查（成本/收益最优）
# ===========================================================================

set -uo pipefail

REPORT="${1:-}"

# ---------- 参数校验 ----------
if [[ -z "$REPORT" ]]; then
  echo "❌ 缺少参数：报告 md 文件路径" >&2
  echo "用法: bash code-block-purity-check.sh <报告.md>" >&2
  exit 2
fi
if [[ ! -f "$REPORT" ]]; then
  echo "❌ 报告文件不存在: $REPORT" >&2
  exit 2
fi

# ---------- 评价性自创注释模式（违反即拒收） ----------
# 这些 emoji + 评价词在源码原文中极少出现，几乎都是 LLM 自创
FORBIDDEN_PATTERNS=(
  '//[[:space:]]*❌'
  '//[[:space:]]*⚠️'
  '//[[:space:]]*🚨'
  '//[[:space:]]*✅[[:space:]]+'
  '//[[:space:]]*🎯'
  '//[[:space:]]*root[[:space:]]*cause'
  '//[[:space:]]*ROOT[[:space:]]*CAUSE'
  '//[[:space:]]*这里是问题'
  '//[[:space:]]*这里有问题'
  '//[[:space:]]*问题所在'
  '//[[:space:]]*关键代码'
  '//[[:space:]]*核心代码'
  '#[[:space:]]*❌'
  '#[[:space:]]*⚠️'
  '#[[:space:]]*🚨'
)

# ---------- Step 1: 提取所有代码块的内容 ----------
# 用 awk 提取 ```...``` 之间的内容（含语言标识 ts/tsx/js/jsx/ts 等）
CODE_BLOCK_CONTENT=$(awk '
  /^```[a-zA-Z]+$/ { in_block=1; next }
  /^```$/          { in_block=0; next }
  in_block         { print }
' "$REPORT")

if [[ -z "$CODE_BLOCK_CONTENT" ]]; then
  echo "ℹ️  报告中无代码块，跳过原文一致性检查"
  exit 0
fi

# ---------- Step 2: 扫描违规模式 ----------
VIOLATIONS=()

for PATTERN in "${FORBIDDEN_PATTERNS[@]}"; do
  # -E 启用扩展正则；-n 显示行号
  HITS=$(echo "$CODE_BLOCK_CONTENT" | grep -nE "$PATTERN" || true)
  if [[ -n "$HITS" ]]; then
    while IFS= read -r HIT; do
      VIOLATIONS+=("[$PATTERN] $HIT")
    done <<< "$HITS"
  fi
done

# ---------- Step 3: 输出结果 ----------
TOTAL_BLOCKS=$(grep -c '^```[a-zA-Z]' "$REPORT" 2>/dev/null || echo 0)
echo "🔍 报告中共有约 $TOTAL_BLOCKS 个代码块（含语言标识）"
echo ""

if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
  echo "✅ 代码块原文一致性校验通过：未检测到自创评价性注释"
  exit 0
fi

echo "❌ 检测到 ${#VIOLATIONS[@]} 处疑似自创评价性注释："
echo ""
for V in "${VIOLATIONS[@]}"; do
  echo "  • $V"
done
echo ""
echo "💡 修复建议："
echo "   1. 将所有评价性注释从代码块**内**移到代码块**外**（如『⭐ 关键证据 N：xxx』）"
echo "   2. 用 sed -n '起,止p' 文件 提取磁盘原文，与报告代码块字符级比对"
echo "   3. 参考反模式 #10『代码块自创注释污染』：skills/issue-trace/SKILL.md"

exit 1
