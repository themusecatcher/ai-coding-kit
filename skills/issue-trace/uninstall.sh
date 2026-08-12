#!/usr/bin/env bash
# issue-trace skill 卸载脚本
# 用法: bash uninstall.sh
# 行为: 备份当前安装版本 → 删除 ~/.codebuddy/skills/issue-trace

set -euo pipefail

SKILL_NAME="issue-trace"
TARGET_DIR="${HOME}/.codebuddy/skills/${SKILL_NAME}"
BACKUP_BASE="${HOME}/.codebuddy/.backup"

if [ ! -d "${TARGET_DIR}" ]; then
  echo "ℹ️  ${TARGET_DIR} 不存在，无需卸载"
  exit 0
fi

# 1. 备份（即使是卸载，也保留一份，避免误删后无法恢复）
BACKUP_DATE_DIR="${BACKUP_BASE}/$(date +%Y%m%d)"
BACKUP_DIR="${BACKUP_DATE_DIR}/${SKILL_NAME}.uninstall.$(date +%H%M%S)"
mkdir -p "${BACKUP_DATE_DIR}"
cp -r "${TARGET_DIR}" "${BACKUP_DIR}"
echo "✅ 已备份当前版本 → ${BACKUP_DIR}"

# 2. 删除
rm -rf "${TARGET_DIR}"
echo "✅ 已卸载 ${SKILL_NAME}（${TARGET_DIR} 已删除）"
echo "ℹ️  如需恢复: cp -r ${BACKUP_DIR} ${TARGET_DIR}"
