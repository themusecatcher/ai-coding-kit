#!/usr/bin/env bash
# browser-compat 元门控：单一真相源同步校验
#
# 校验 ~/.codebuddy/rules/浏览器兼容性规范.mdc 中标注为「检测」的规则
# 与 scripts/compat-check.js 中 JS_RULES + CSS_RULES 集合是否双向一致。
#
# 退出码：
#   0 - 双向一致
#   1 - 不一致（打印差异）
#   2 - 脚本执行错误（依赖缺失等）
#
# 临时绕过：SKIP_COMPAT_RULES_SYNC=1 bash validate-rules-sync.sh

set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RULE_FILE="$HOME/.codebuddy/rules/浏览器兼容性规范.mdc"
SCRIPT_FILE="$SKILL_DIR/scripts/compat-check.js"

if [ "${SKIP_COMPAT_RULES_SYNC:-0}" = "1" ]; then
  echo "⚠️  SKIP_COMPAT_RULES_SYNC=1 → 跳过元门控校验"
  exit 0
fi

if [ ! -f "$RULE_FILE" ]; then
  echo "❌ 规则文件不存在: $RULE_FILE" >&2
  exit 2
fi

if [ ! -f "$SCRIPT_FILE" ]; then
  echo "❌ 脚本文件不存在: $SCRIPT_FILE" >&2
  exit 2
fi

# 规则文件中「应实现的规则 ID」清单（手维护，与 compat-check.js 中 rule.id 对齐）
# 仅纳入「🔴 CRITICAL（自动检测）」+ 明确实现自动检测的 🟡 项
declare_rule_ids=(
  # JS CRITICAL
  "no-array-at"
  "no-structured-clone"
  "no-object-hasown"
  "no-array-tosorted"
  "no-object-groupby"
  "no-promise-withresolvers"
  "no-crypto-randomuuid"
  # CSS CRITICAL
  "no-has-selector"
  "no-container-type"
  "no-color-mix"
  "no-subgrid"
  "no-flexbox-gap"
  "no-aspect-ratio"
  "no-inset-shorthand"
  "no-text-wrap"
  "no-css-layer"
  "no-accent-color"
  # CSS WARNING（脚本明确实现）
  "warn-backdrop-filter"
)

# 关键字映射（用 case 实现，兼容 bash 3.2 / macOS 默认 bash）
keyword_for() {
  case "$1" in
    "no-array-at") echo "Array.prototype.at" ;;
    "no-structured-clone") echo "structuredClone" ;;
    "no-object-hasown") echo "Object.hasOwn" ;;
    "no-array-tosorted") echo "toSorted" ;;
    "no-object-groupby") echo "Object.groupBy" ;;
    "no-promise-withresolvers") echo "Promise.withResolvers" ;;
    "no-crypto-randomuuid") echo "crypto.randomUUID" ;;
    "no-has-selector") echo ":has()" ;;
    "no-container-type") echo "container-type" ;;
    "no-color-mix") echo "color-mix" ;;
    "no-subgrid") echo "subgrid" ;;
    "no-flexbox-gap") echo "Flexbox \`gap\`" ;;
    "no-aspect-ratio") echo "aspect-ratio" ;;
    "no-inset-shorthand") echo "\`inset\` 简写" ;;
    "no-text-wrap") echo "text-wrap: balance" ;;
    "no-css-layer") echo "@layer" ;;
    "no-accent-color") echo "accent-color" ;;
    "warn-backdrop-filter") echo "backdrop-filter" ;;
    *) echo "" ;;
  esac
}

expected_set=$(printf "%s\n" "${declare_rule_ids[@]}" | sort -u)

# 脚本「实际实现」集合
actual_set=$(node -e "
  const m = require('$SCRIPT_FILE');
  const ids = [...(m.JS_RULES||[]), ...(m.CSS_RULES||[])].map(r => r.id);
  console.log(ids.sort().join('\n'));
" 2>/dev/null) || {
  echo "❌ 无法从 compat-check.js 读取 JS_RULES/CSS_RULES" >&2
  exit 2
}

errors=()

missing_in_script=$(comm -23 <(echo "$expected_set") <(echo "$actual_set") || true)
missing_in_rule=$(comm -13 <(echo "$expected_set") <(echo "$actual_set") || true)

if [ -n "$missing_in_script" ]; then
  errors+=("❌ 规则文件声明但脚本未实现的规则:")
  while IFS= read -r id; do
    [ -n "$id" ] && errors+=("   - $id")
  done <<< "$missing_in_script"
fi

if [ -n "$missing_in_rule" ]; then
  errors+=("❌ 脚本实现但规则文件/映射表未声明的规则:")
  while IFS= read -r id; do
    [ -n "$id" ] && errors+=("   - $id")
  done <<< "$missing_in_rule"
fi

# 关键字落地校验
while IFS= read -r id; do
  [ -z "$id" ] && continue
  keyword=$(keyword_for "$id")
  if [ -z "$keyword" ]; then
    errors+=("⚠️  规则 $id 未在 keyword_for 映射中声明关键字（元门控元数据漏洞）")
    continue
  fi
  if ! grep -qF -- "$keyword" "$RULE_FILE"; then
    errors+=("❌ 规则 $id 对应关键字 '$keyword' 在规则文件中未找到（疑似规则文件已删除该项但脚本/映射表未同步）")
  fi
done <<< "$expected_set"

if [ ${#errors[@]} -gt 0 ]; then
  echo "==================================================================="
  echo "🔴 browser-compat 规则同步校验失败"
  echo "==================================================================="
  for line in "${errors[@]}"; do
    echo "$line"
  done
  echo ""
  echo "📌 修复指引:"
  echo "   1. 若规则文件新增了规则 → 在 compat-check.js 添加 JS_RULES/CSS_RULES 条目"
  echo "                            + 在本脚本 declare_rule_ids 和 keyword_for 中登记"
  echo "   2. 若脚本删除了规则 → 同步从规则文件移除对应行"
  echo "   3. 临时绕过（不推荐）: SKIP_COMPAT_RULES_SYNC=1 bash $0"
  echo "==================================================================="
  exit 1
fi

if [ "${1:-}" = "--debug" ]; then
  echo "===== expected (rule + map) ====="
  echo "$expected_set"
  echo "===== actual (script) ====="
  echo "$actual_set"
fi

echo "✅ browser-compat 规则同步校验通过（共 $(echo "$expected_set" | wc -l | tr -d ' ') 条规则）"
exit 0
