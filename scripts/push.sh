#!/bin/bash

# ============================================================
# AI Coding Kit 一键提交推送脚本
# 用法：pnpm push "<type>: <描述>"
#   例：pnpm push "docs: update readme"
# 效果：git add . → commit（传入的描述）→ push 到当前分支的远程
# ============================================================

# 确保脚本抛出遇到的错误
set -e

commitDesc=$1

# 强制要求传入语义化的提交描述，避免产生无信息量的 commit
if [ -z "$commitDesc" ]; then
  echo "❌ 缺少提交描述。用法: pnpm push \"<type>: <描述>\"（如 pnpm push \"docs: update readme\"）"
  exit 1
fi

git add .
git commit -m "$commitDesc"
git push

echo ⏰ "$(date '+%Y-%m-%d %H:%M:%S')"
