#!/usr/bin/env bash
# ===========================================================================
# trace-depth-check.sh (v2 / 方案 Z 重构版 2026-05-20)
# ---------------------------------------------------------------------------
# 用途：校验 issue-trace 根因报告中的「调用方追溯深度」，纯报告自检模式。
#       如果报告代码块里出现 wrapper 函数 import（如 import { post } from
#       '@scope/lib-name'），但报告正文未提供该来源的实现位置（包名/路径
#       + L行号），则判定为「调用方追溯偷懒」。
#
# 用法：
#   bash trace-depth-check.sh <报告 md 文件>
#
# 退出码：
#   0 — 全部通过（无 wrapper / 所有 wrapper 都已追溯到实现位置）
#   1 — 检测到追溯断链
#   2 — 参数错误 / 文件不存在
#
# 设计哲学（方案 Z，2026-05-20 实测后重构）：
#   - 完全脱离 workspace 文件查找，避免 find 性能问题
#   - 同时支持相对路径 import 和 npm 包 import（@your-org/* / 任意 scope）
#   - 仅校验报告自身的逻辑完整性：说了 A 调用 B，必须同时说明 B 的实现位置
#   - "B 的实现位置存在"判定标准：报告中出现 from 后的包名/路径，且其后或前有 L行号
# ===========================================================================

set -uo pipefail

REPORT="${1:-}"

# ---------- 参数校验 ----------
if [[ -z "$REPORT" ]]; then
  echo "❌ 缺少参数：报告 md 文件路径" >&2
  echo "用法: bash trace-depth-check.sh <报告.md>" >&2
  exit 2
fi
if [[ ! -f "$REPORT" ]]; then
  echo "❌ 报告文件不存在: $REPORT" >&2
  exit 2
fi

# ---------- 关键 wrapper 函数白名单 ----------
# 这些函数在业务代码里出现时，几乎都是从某个 wrapper 模块 import 的
# 扩展名单：除经典 HTTP 动词外，加入了 React Query / SWR / RPC 风格的常见名
SUSPECT_FUNCS_REGEX='^(get|post|put|delete|patch|request|fetch|http|api|client|axios|send|useRequest|query|mutate|invoke|call|rpc)$'

# ---------- Step 1: 提取报告中所有代码块（含语言标识） ----------
# 用 awk 提取 ```ts ... ``` 之间的内容
CODE_BLOCK_CONTENT=$(awk '
  /^```[a-zA-Z]+$/ { in_block=1; next }
  /^```$/          { in_block=0; next }
  in_block         { print }
' "$REPORT")

if [[ -z "$CODE_BLOCK_CONTENT" ]]; then
  echo "ℹ️  报告中无代码块，无 wrapper 引用可校验，跳过追溯深度检查"
  exit 0
fi

# ---------- Step 2: 提取代码块中的 import 语句 ----------
# 匹配两种形式：
#   import { funcA, funcB } from 'xxx';
#   import { funcA as wbGet } from "xxx";
IMPORT_LINES=$(echo "$CODE_BLOCK_CONTENT" | grep -nE "^import[[:space:]]*\{[^}]+\}[[:space:]]*from[[:space:]]*['\"][^'\"]+['\"]" 2>/dev/null || true)

if [[ -z "$IMPORT_LINES" ]]; then
  echo "ℹ️  报告代码块中无 named import 语句，跳过追溯深度检查"
  exit 0
fi

# ---------- Step 3: 解析每条 import，找出 wrapper 调用 ----------
# 同时构建报告"正文"作为追溯证据池（去除代码块后的内容，因为 wrapper 实现位置应该在正文标注）
NON_CODE_CONTENT=$(awk '
  /^```/ { in_block = !in_block; next }
  !in_block { print }
' "$REPORT")

BROKEN_LINKS=()
WRAPPER_HITS_TOTAL=0

while IFS= read -r IMP_LINE; do
  [[ -z "$IMP_LINE" ]] && continue

  # 提取大括号内的函数名列表
  NAMES=$(echo "$IMP_LINE" \
    | sed -nE "s/.*\{([^}]*)\}.*/\1/p" \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/.*[[:space:]]+as[[:space:]]+//')

  # 提取 from 来源（去除引号）
  FROM_SRC=$(echo "$IMP_LINE" | sed -nE "s/.*from[[:space:]]*['\"]([^'\"]+)['\"].*/\1/p")

  [[ -z "$NAMES" || -z "$FROM_SRC" ]] && continue

  # 检测哪些函数名命中 wrapper 白名单
  HIT_FUNCS=()
  while IFS= read -r FN; do
    [[ -z "$FN" ]] && continue
    if echo "$FN" | grep -qE "$SUSPECT_FUNCS_REGEX"; then
      HIT_FUNCS+=("$FN")
    fi
  done <<< "$NAMES"

  [[ ${#HIT_FUNCS[@]} -eq 0 ]] && continue
  WRAPPER_HITS_TOTAL=$((WRAPPER_HITS_TOTAL + ${#HIT_FUNCS[@]}))

  # 关键追溯校验：
  # 报告正文是否提到了 FROM_SRC + 至少一个 L行号？
  # FROM_SRC 形式可能是：
  #   - 相对路径 './http' / '../api/index'
  #   - npm 包名 '@scope/lib-name' / 'lodash'
  # 取一个稳定的关键标识符做匹配（去掉前导 ./ 或 ../，npm 包则取完整名）
  IDENTIFIER=$(echo "$FROM_SRC" | sed -E 's|^\.\.?/||g')

  # 判定标准：
  # (a) 正文中存在 IDENTIFIER（说明用户引用了这个来源）
  # (b) 正文中存在与 IDENTIFIER 在同一段（同行或前后 5 行内）的 `L行号` 模式
  # 用 grep -B5 -A5 快速近邻判定
  HAS_REF=$(echo "$NON_CODE_CONTENT" | grep -nF "${IDENTIFIER}" 2>/dev/null || true)

  if [[ -z "$HAS_REF" ]]; then
    # 完全没提到这个来源 → 明显断链
    BROKEN_LINKS+=("【断链】wrapper { ${HIT_FUNCS[*]} } from '$FROM_SRC' → 报告正文未引用『${IDENTIFIER}』来源")
    continue
  fi

  # 提到了来源，再校验是否带有 L行号（追溯到具体实现位置）
  # 取所有命中行的行号集合，对每行读取 ±5 行做局部窗口
  HAS_LINE_NUM=0
  while IFS= read -r REF_LINE; do
    [[ -z "$REF_LINE" ]] && continue
    LN=$(echo "$REF_LINE" | cut -d: -f1)
    [[ -z "$LN" ]] && continue
    LN_START=$((LN > 5 ? LN - 5 : 1))
    LN_END=$((LN + 5))
    WINDOW=$(echo "$NON_CODE_CONTENT" | sed -n "${LN_START},${LN_END}p")
    if echo "$WINDOW" | grep -qE 'L[0-9]+'; then
      HAS_LINE_NUM=1
      break
    fi
  done <<< "$HAS_REF"

  if [[ $HAS_LINE_NUM -eq 0 ]]; then
    BROKEN_LINKS+=("【断链】wrapper { ${HIT_FUNCS[*]} } from '$FROM_SRC' → 报告引用了『${IDENTIFIER}』但未标注实现行号 L行号")
  fi
done <<< "$IMPORT_LINES"

# ---------- Step 4: 输出结果 ----------
echo "� 报告代码块中共发现 $WRAPPER_HITS_TOTAL 处 wrapper 函数 import"
echo ""

if [[ ${#BROKEN_LINKS[@]} -eq 0 ]]; then
  if [[ $WRAPPER_HITS_TOTAL -eq 0 ]]; then
    echo "✅ 调用方追溯深度校验通过：报告未引用任何 wrapper 函数（无可校验对象）"
  else
    echo "✅ 调用方追溯深度校验通过：所有 wrapper 函数均已追溯到实现位置（含包名 + L行号）"
  fi
  exit 0
fi

echo "❌ 检测到 ${#BROKEN_LINKS[@]} 处追溯断链："
echo ""
for LINK in "${BROKEN_LINKS[@]}"; do
  echo "  • $LINK"
done
echo ""
echo "💡 修复建议：在根因报告中补充 wrapper 函数实现位置（包名/路径 + L行号 + 关键代码）"
echo "   参考反模式 #9『调用方追溯偷懒』：~/.codebuddy/skills/issue-trace/SKILL.md"

exit 1
