#!/usr/bin/env bash
# browser-compat 全量回归测试
# 用法：bash run-tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色
G='\033[0;32m'
R='\033[0;31m'
Y='\033[1;33m'
N='\033[0m'

pass=0
fail=0

run_test() {
  local name="$1"
  local cmd="$2"
  local expect_exit="$3"
  echo -e "\n${Y}▶ $name${N}"
  set +e
  eval "$cmd" >/tmp/run-tests-stdout.txt 2>/tmp/run-tests-stderr.txt
  local actual_exit=$?
  set -e
  if [ "$actual_exit" = "$expect_exit" ]; then
    echo -e "  ${G}✅ exit=$actual_exit (expected)${N}"
    pass=$((pass + 1))
  else
    echo -e "  ${R}❌ exit=$actual_exit (expected $expect_exit)${N}"
    echo "  stdout: $(head -c 300 /tmp/run-tests-stdout.txt)"
    echo "  stderr: $(head -c 300 /tmp/run-tests-stderr.txt)"
    fail=$((fail + 1))
  fi
}

# Test 1: 元门控同步校验
run_test "Test 1: 元门控同步校验" \
  "bash $SKILL_DIR/scripts/meta/validate-rules-sync.sh" \
  0

# Test 2: baseline-resolver 单元测试
run_test "Test 2: baseline-resolver 单元测试" \
  "node $SCRIPT_DIR/test-baseline-resolver.js" \
  0

# Test 3: load-config 单元测试
run_test "Test 3: load-config 单元测试" \
  "node $SCRIPT_DIR/test-load-config.js" \
  0

# Test 4: conservative 项目应有 CRITICAL → exit 1
run_test "Test 4: conservative fixture 扫描应 block" \
  "node $SKILL_DIR/scripts/compat-check.js $SCRIPT_DIR/fixtures/conservative-project/src" \
  1

# Test 5: standard 项目 inset 应被跳过
run_test "Test 5: standard fixture 扫描应 block (但 inset/has 跳过)" \
  "node $SKILL_DIR/scripts/compat-check.js $SCRIPT_DIR/fixtures/standard-project/src" \
  1

# Test 5b: 检查 standard 输出的 skipped 包含预期项
echo -e "\n${Y}▶ Test 5b: standard 跳过项内容验证${N}"
out=$(node "$SKILL_DIR/scripts/compat-check.js" "$SCRIPT_DIR/fixtures/standard-project/src" 2>/dev/null || true)
if echo "$out" | grep -q '"rule_id": "no-inset-shorthand"' && \
   echo "$out" | grep -q '"reason": "baseline:standard"' && \
   echo "$out" | grep -q '"rule_id": "no-has-selector"' && \
   echo "$out" | grep -q '"reason": "ignore'; then
  echo -e "  ${G}✅ skipped 包含 inset(baseline) + has(ignore)${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ skipped 字段缺失预期项${N}"
  fail=$((fail + 1))
fi

# Test 6: flex-grid-mix 应区分 flex/grid/unknown
echo -e "\n${Y}▶ Test 6: flex-grid-mix gap 上下文区分${N}"
out=$(node "$SKILL_DIR/scripts/compat-check.js" "$SCRIPT_DIR/fixtures/conservative-project/src/flex-grid-mix.scss" 2>/dev/null || true)
critical_count=$(echo "$out" | grep -c '"severity": "CRITICAL"' || true)
warning_count=$(echo "$out" | grep -c '"severity": "WARNING"' || true)
# 期望：2 CRITICAL（flex + inline-flex）+ 1 WARNING（unknown）+ 0 grid 报警
if [ "$critical_count" = "2" ] && [ "$warning_count" = "1" ]; then
  echo -e "  ${G}✅ CRITICAL=2 WARNING=1（grid 不报）${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ CRITICAL=$critical_count WARNING=$warning_count（期望 2/1）${N}"
  fail=$((fail + 1))
fi

# Test 7: empty-project 默认兜底 + 空目录无违规 → exit 0
run_test "Test 7: empty-project 默认兜底应 approve" \
  "node $SKILL_DIR/scripts/compat-check.js $SCRIPT_DIR/fixtures/empty-project/src" \
  0

# Test 8: --print-baseline 子命令
run_test "Test 8: --print-baseline 子命令" \
  "node $SKILL_DIR/scripts/compat-check.js --print-baseline $SCRIPT_DIR/fixtures/standard-project" \
  0

# Test 9: schema 校验：正常输出 stderr 应为空
echo -e "\n${Y}▶ Test 9: 输出 schema 校验通过（stderr 为空）${N}"
err=$(node "$SKILL_DIR/scripts/compat-check.js" "$SCRIPT_DIR/fixtures/conservative-project/src/sample.js" 2>&1 >/dev/null || true)
if [ -z "$err" ]; then
  echo -e "  ${G}✅ stderr 为空${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ stderr 非空: $err${N}"
  fail=$((fail + 1))
fi

# Test 10: 行级 @compat-ignore 豁免
echo -e "\n${Y}▶ Test 10: 行级 @compat-ignore 豁免${N}"
out=$(node "$SKILL_DIR/scripts/compat-check.js" "$SCRIPT_DIR/fixtures/conservative-project/src/sample.js" 2>/dev/null || true)
# sample.js 中含 `arr.at(0); // @compat-ignore` → 不应被报
if ! echo "$out" | grep -q 'arr.at(0)'; then
  echo -e "  ${G}✅ @compat-ignore 行未被报${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ @compat-ignore 失效${N}"
  fail=$((fail + 1))
fi

# ─────── Schema 兼容性测试组（用户 schema + 集中式 + 优先级链）─────────
# Test 11: user-schema fixture（targets 复数 + rules ESLint 风格）解析正确
echo -e "\n${Y}▶ Test 11: user-schema fixture baseline 解析${N}"
us_out=$(node -e "
const { loadConfig } = require('$SKILL_DIR/scripts/lib/load-config.js');
const c = loadConfig('$SCRIPT_DIR/fixtures/user-schema-project');
console.log('source=' + c.baseline.source);
console.log('level=' + c.baseline.level);
console.log('chrome=' + c.baseline.minVersions.chrome);
console.log('safari=' + c.baseline.minVersions.safari);
" 2>&1)
if echo "$us_out" | grep -q 'source=\.browser-compat\.json' && \
   echo "$us_out" | grep -q 'level=conservative' && \
   echo "$us_out" | grep -q 'safari=9'; then
  echo -e "  ${G}✅ source/level/safari=9 正确（targets 字符串归一化）${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ user-schema baseline 解析异常${N}"
  echo "$us_out" | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Test 12: user-schema 的 rules.off 应被翻译为 ignore（IntersectionObserver 在豁免列表）
echo -e "\n${Y}▶ Test 12: rules.off → ignore 翻译${N}"
ig_out=$(node -e "
const { loadConfig } = require('$SKILL_DIR/scripts/lib/load-config.js');
const c = loadConfig('$SCRIPT_DIR/fixtures/user-schema-project');
const ids = c.ignore.map(x => x.rule_id).join(',');
console.log('ids=' + ids);
console.log('count=' + c.ignore.length);
" 2>&1)
if echo "$ig_out" | grep -q 'IntersectionObserver' && \
   echo "$ig_out" | grep -q 'ResizeObserver' && \
   echo "$ig_out" | grep -q 'requestIdleCallback' && \
   echo "$ig_out" | grep -q 'count=3'; then
  echo -e "  ${G}✅ 3 条 rules.off 被翻译为 ignore 列表${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ rules.off 翻译异常${N}"
  echo "$ig_out" | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Test 13: user-schema 的 ignore 路径数组应合并到 excludePaths（嗅探：第一个元素是字符串）
echo -e "\n${Y}▶ Test 13: ignore 字符串数组 → excludePaths 嗅探${N}"
ep_out=$(node -e "
const { loadConfig } = require('$SKILL_DIR/scripts/lib/load-config.js');
const c = loadConfig('$SCRIPT_DIR/fixtures/user-schema-project');
console.log('count=' + c.excludePaths.length);
console.log('has-test-ts=' + c.excludePaths.includes('**/*.test.ts'));
console.log('has-scripts=' + c.excludePaths.includes('scripts/**'));
console.log('has-default=' + c.excludePaths.includes('node_modules/**'));
" 2>&1)
if echo "$ep_out" | grep -q 'has-test-ts=true' && \
   echo "$ep_out" | grep -q 'has-scripts=true' && \
   echo "$ep_out" | grep -q 'has-default=true'; then
  echo -e "  ${G}✅ ignore 路径合并到 excludePaths（含默认值）${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ ignore 路径嗅探/合并异常${N}"
  echo "$ep_out" | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Test 14: 集中式 projects 通过 package.json>name 反查
echo -e "\n${Y}▶ Test 14: 集中式 projects 配置反查${N}"
cc_out=$(node -e "
const { loadConfig } = require('$SKILL_DIR/scripts/lib/load-config.js');
const c = loadConfig('$SCRIPT_DIR/fixtures/central-config-project');
console.log('source=' + c.baseline.source);
console.log('chrome=' + c.baseline.minVersions.chrome);
console.log('polyfill=' + c.polyfills.join(','));
" 2>&1)
if echo "$cc_out" | grep -q 'source=.browser-compat.json>projects.central-config-project' && \
   echo "$cc_out" | grep -q 'chrome=64' && \
   echo "$cc_out" | grep -q 'polyfill=react-app-polyfill/stable'; then
  echo -e "  ${G}✅ 集中式 projects.<name> 子配置生效${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ 集中式反查异常${N}"
  echo "$cc_out" | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Test 15: targets 字符串版本号归一化（"9.1" → 9）
echo -e "\n${Y}▶ Test 15: targets 字符串版本号归一化${N}"
nv_out=$(node -e "
const { _internal } = require('$SKILL_DIR/scripts/lib/load-config.js');
console.log('v91=' + _internal.normalizeMajorVersion('9.1'));
console.log('v70=' + _internal.normalizeMajorVersion('70'));
console.log('vNum=' + _internal.normalizeMajorVersion(70));
console.log('vBad=' + _internal.normalizeMajorVersion('abc'));
" 2>&1)
if echo "$nv_out" | grep -q 'v91=9' && \
   echo "$nv_out" | grep -q 'v70=70' && \
   echo "$nv_out" | grep -q 'vNum=70' && \
   echo "$nv_out" | grep -q 'vBad=undefined'; then
  echo -e "  ${G}✅ 字符串版本归一化 + 数字 + 异常输入 全通过${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ 版本归一化异常${N}"
  echo "$nv_out" | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Test 16: 优先级链 fallback（.browser-compat.json 不含 baseline 字段，但 package.json 有 browserslist）
echo -e "\n${Y}▶ Test 16: 优先级链 compat-json → browserslist fallback${N}"
TMP_DIR=$(mktemp -d)
cat > "$TMP_DIR/.browser-compat.json" <<EOF
{
  "polyfills": ["foo"],
  "_comment": "故意不含 target/targets/baseline，应 fallback 到 browserslist"
}
EOF
cat > "$TMP_DIR/package.json" <<EOF
{
  "name": "fallback-test",
  "browserslist": ["chrome >= 90", "safari >= 14"]
}
EOF
fb_out=$(node -e "
const { loadConfig } = require('$SKILL_DIR/scripts/lib/load-config.js');
const c = loadConfig('$TMP_DIR');
console.log('source=' + c.baseline.source);
console.log('chrome=' + c.baseline.minVersions.chrome);
console.log('polyfill=' + c.polyfills.join(','));
" 2>&1)
rm -rf "$TMP_DIR"
if echo "$fb_out" | grep -q 'source=package.json>browserslist' && \
   echo "$fb_out" | grep -q 'chrome=90'; then
  echo -e "  ${G}✅ 优先级链 fallback 正确（修复了原 bug）${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ 优先级链未 fallback${N}"
  echo "$fb_out" | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Test 17: rule-filter 的 fuzzy 匹配单元测试（用户名 ↔ rule.id 双向归一）
echo -e "\n${Y}▶ Test 17: rule-filter fuzzy 匹配 normalizeRuleKey + matchIgnoreRule${N}"
fz_out=$(node -e "
const { _internal, filterRules } = require('$SKILL_DIR/scripts/lib/rule-filter.js');
const cases = [
  ['structuredClone', 'no-structured-clone', true],
  ['Object.hasOwn', 'no-object-hasown', true],
  ['Array.prototype.at', 'no-array-at', true],
  ['IntersectionObserver', 'no-structured-clone', false],
  ['no-flexbox-gap', 'no-flexbox-gap', true],
];
let pass = 0, fail = 0;
cases.forEach(([user, ruleId, expect]) => {
  const r = _internal.matchIgnoreRule(ruleId, [{ rule_id: user, match: 'fuzzy', reason: 't' }]);
  if (r.matched === expect) pass++;
  else { fail++; console.log('FAIL:', user, '→', ruleId, 'expect', expect, 'got', r.matched); }
});
console.log('pass=' + pass + ' fail=' + fail);

// 端到端：filterRules 真把规则跳过
const fakeRules = [{ id: 'no-structured-clone' }, { id: 'no-flexbox-gap' }];
const cfg = {
  baseline: { level: 'conservative' },
  polyfills: [],
  ignore: [{ rule_id: 'structuredClone', match: 'fuzzy', reason: 'rules:off' }],
};
const result = filterRules(fakeRules, cfg);
const skippedIds = result.skipped.map(s => s.rule_id);
console.log('end2end_skipped=' + skippedIds.join(','));
" 2>&1)
if echo "$fz_out" | grep -q 'pass=5 fail=0' && \
   echo "$fz_out" | grep -q 'end2end_skipped=no-structured-clone'; then
  echo -e "  ${G}✅ fuzzy 匹配正确：用户名→rule.id 双向归一 + 端到端豁免${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ fuzzy 匹配异常${N}"
  echo "$fz_out" | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Test 18: 真实端到端 — 用户写 structuredClone:off，扫描真有 structuredClone 调用的代码，应豁免
echo -e "\n${Y}▶ Test 18: 用户 rules.off 端到端豁免（structuredClone）${N}"
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/src"
cat > "$TMP_DIR/.browser-compat.json" <<'EOF'
{
  "targets": { "chrome": "70", "safari": "9" },
  "rules": { "structuredClone": "off" }
}
EOF
cat > "$TMP_DIR/src/test.js" <<'EOF'
const a = structuredClone({ x: 1 });
EOF
e2e_out=$(node "$SKILL_DIR/scripts/compat-check.js" "$TMP_DIR/src" 2>/dev/null)
e2e_exit=$?
rm -rf "$TMP_DIR"
if [ "$e2e_exit" = "0" ] && \
   echo "$e2e_out" | grep -q '"critical": 0' && \
   echo "$e2e_out" | grep -q '"conclusion": "approve"' && \
   echo "$e2e_out" | grep -q 'fuzzy: structuredClone'; then
  echo -e "  ${G}✅ 用户 rules.off 端到端真实豁免，conclusion=approve，skipped 显示 fuzzy 匹配理由${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ 端到端豁免失败（exit=$e2e_exit）${N}"
  echo "$e2e_out" | head -20 | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Test 19: 精确匹配 ignore 对象数组（我们 schema 风格）应继续工作
echo -e "\n${Y}▶ Test 19: ignore 对象数组（exact 匹配，我们 schema）${N}"
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/src"
cat > "$TMP_DIR/.browser-compat.json" <<'EOF'
{
  "target": "conservative",
  "ignore": [
    { "rule_id": "no-flexbox-gap", "reason": "管理后台仅 Chrome" }
  ]
}
EOF
cat > "$TMP_DIR/src/test.scss" <<'EOF'
.x { display: flex; gap: 8px; }
EOF
ex_out=$(node "$SKILL_DIR/scripts/compat-check.js" "$TMP_DIR/src" 2>/dev/null)
ex_exit=$?
rm -rf "$TMP_DIR"
if [ "$ex_exit" = "0" ] && \
   echo "$ex_out" | grep -q '"conclusion": "approve"' && \
   echo "$ex_out" | grep -q '管理后台仅 Chrome'; then
  echo -e "  ${G}✅ 我们 schema exact 匹配仍生效，rule-filter 修改未破坏老路径${N}"
  pass=$((pass + 1))
else
  echo -e "  ${R}❌ 我们 schema exact 匹配失效${N}"
  echo "$ex_out" | head -20 | sed 's/^/    /'
  fail=$((fail + 1))
fi

echo ""
echo "=================================="
if [ "$fail" = "0" ]; then
  echo -e "${G}✅ 全部 $pass 个测试通过${N}"
  exit 0
else
  echo -e "${R}❌ $fail 个测试失败 ($pass 通过)${N}"
  exit 1
fi
