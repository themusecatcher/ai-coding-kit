#!/bin/bash
# test-secret-grep-lint.sh - 测试硬编码密钥/XSS lint

run_tests() {
  local LINT="$VP_ROOT/scripts/lints/secret-grep-lint.sh"
  local TMP
  TMP="$(mktemp -d -t vp-test-secret.XXXXXX)"

  # 1. 干净文件应通过
  cat > "$TMP/clean.ts" <<'EOF'
export const API_BASE = process.env.API_BASE;
export function fetchUser(id: string) {
  return fetch(`${API_BASE}/users/${id}`);
}
EOF
  bash "$LINT" --raw "$TMP/clean.ts"
  assert_exit_code "$?" "0" "干净文件 → 通过"

  # 2. 含 OpenAI key 应失败
  cat > "$TMP/leak1.ts" <<'EOF'
const key = "sk-AbCdEfGh1234567890XyZAbCdEfGh12";
EOF
  bash "$LINT" --raw "$TMP/leak1.ts"
  assert_exit_code "$?" "1" "OpenAI key 应被检测"

  # 3. 含 dangerouslySetInnerHTML 应失败
  cat > "$TMP/xss.tsx" <<'EOF'
export const Risky = ({ html }) => (
  <div dangerouslySetInnerHTML={{ __html: html }} />
);
EOF
  bash "$LINT" --raw "$TMP/xss.tsx"
  assert_exit_code "$?" "1" "dangerouslySetInnerHTML 应被检测"

  # 4. innerHTML 应失败
  cat > "$TMP/inner.ts" <<'EOF'
function setContent(el, raw) {
  el.innerHTML = raw;
}
EOF
  bash "$LINT" --raw "$TMP/inner.ts"
  assert_exit_code "$?" "1" "innerHTML 赋值应被检测"

  # 5. 行内豁免 [VP-IGNORE-SECRET] 应通过
  cat > "$TMP/exempt.ts" <<'EOF'
const fakeKey = "sk-fakeKeyForTestingOnly12345"; // [VP-IGNORE-SECRET]
EOF
  bash "$LINT" --raw "$TMP/exempt.ts"
  assert_exit_code "$?" "0" "[VP-IGNORE-SECRET] 行内豁免生效"

  # 6. 测试 fixture 文件应豁免
  mkdir -p "$TMP/tests/fixtures"
  cat > "$TMP/tests/fixtures/sample.ts" <<'EOF'
export const sample = { apiKey: "sk-realLookingButFakeKeyAbcDefGh" };
EOF
  bash "$LINT" --raw "$TMP/tests/fixtures/sample.ts"
  assert_exit_code "$?" "0" "tests/fixtures 路径文件被豁免"

  # 7. JSON 输出包含 violations 字段
  local json
  json="$(bash "$LINT" --json "$TMP/leak1.ts" 2>/dev/null)"
  assert_contains "$json" '"openai_api_key":false' "JSON 含规则结果"
  assert_contains "$json" '"total":' "JSON 含 total 字段"

  # 8. 通用密钥赋值
  cat > "$TMP/leak2.ts" <<'EOF'
const config = {
  password: "myV3rySecretPassword123456",
};
EOF
  bash "$LINT" --raw "$TMP/leak2.ts"
  assert_exit_code "$?" "1" "通用 password 赋值应被检测"

  rm -rf "$TMP"
}
