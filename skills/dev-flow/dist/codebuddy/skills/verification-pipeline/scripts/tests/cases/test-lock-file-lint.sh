#!/bin/bash
# test-lock-file-lint.sh - 测试 lock 文件 / locales 检查

run_tests() {
  local LINT="$VP_ROOT/scripts/lints/lock-file-lint.sh"
  local TMP
  TMP="$(mktemp -d -t vp-test-lock.XXXXXX)"

  # 创建一个临时 git 仓库
  ( cd "$TMP" && git init -q && git config user.email a@b.c && git config user.name t )

  # 1. 干净仓库（无 diff）应通过
  ( cd "$TMP" && bash "$LINT" --raw )
  assert_exit_code "$?" "0" "无 diff 仓库 → 通过"

  # 2. 改动 lockfileVersion 应失败
  cat > "$TMP/package-lock.json" <<'EOF'
{
  "name": "demo",
  "version": "1.0.0",
  "lockfileVersion": 2
}
EOF
  ( cd "$TMP" && git add . && git commit -q -m init )
  # 修改 lockfileVersion
  sed -i.bak 's/"lockfileVersion": 2/"lockfileVersion": 3/' "$TMP/package-lock.json"
  rm "$TMP/package-lock.json.bak"

  ( cd "$TMP" && bash "$LINT" --raw )
  assert_exit_code "$?" "1" "lockfileVersion 改动应被检测"

  # 3. JSON 输出
  local json
  json="$( cd "$TMP" && bash "$LINT" --json 2>/dev/null )"
  assert_contains "$json" '"lockfile_version_changed":false' "JSON 标记 lockfileVersion 违规"

  # 4. i18n locales 改动应被检测
  ( cd "$TMP" && git checkout -q -- package-lock.json )
  mkdir -p "$TMP/src/locales"
  cat > "$TMP/src/locales/zh.json" <<'EOF'
{ "hello": "你好" }
EOF
  ( cd "$TMP" && git add . && git commit -q -m "add locale" )
  cat > "$TMP/src/locales/zh.json" <<'EOF'
{ "hello": "您好" }
EOF
  ( cd "$TMP" && bash "$LINT" --raw )
  assert_exit_code "$?" "1" "locales 文件改动应被检测"

  # 5. .DS_Store 元文件应被检测
  ( cd "$TMP" && git checkout -q -- src/locales/zh.json )
  touch "$TMP/.DS_Store"
  # 由于 .DS_Store 通常被 ignore，这里用 git add -f 强加
  ( cd "$TMP" && git add -f .DS_Store )
  ( cd "$TMP" && bash "$LINT" --staged --raw )
  assert_exit_code "$?" "1" ".DS_Store 元文件应被检测"

  rm -rf "$TMP"
}
