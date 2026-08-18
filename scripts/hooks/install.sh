#!/bin/bash
# ==============================================================================
# install.sh — 将 pre-commit hook 安装到 .git/hooks/
#
# 用法：bash scripts/hooks/install.sh
# 说明：采用复制方式安装。scripts/hooks/pre-commit 更新后需重新执行本脚本。
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

if [ ! -d "$HOOKS_DIR" ]; then
  echo "❌ 未找到 .git/hooks 目录（当前目录不是 git 仓库？）"
  exit 1
fi

cp "$SCRIPT_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ pre-commit hook 已安装到 .git/hooks/pre-commit"
echo "   - 提交涉及 skills/ 或 .codebuddy-plugin/ 的变更时，自动校验元数据是否过期"
echo "   - scripts/hooks/pre-commit 有更新时，请重新执行本脚本"
echo "   - 卸载：rm .git/hooks/pre-commit"
