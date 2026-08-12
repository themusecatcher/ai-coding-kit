#!/usr/bin/env bash
# issue-trace skill 安装脚本
# 用法: bash install.sh
# 行为: 备份旧版本 → rsync 复制到 ~/.codebuddy/skills/issue-trace → 设置脚本可执行权限 → 校验

set -euo pipefail

SKILL_NAME="issue-trace"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BASE="${HOME}/.codebuddy/skills"
TARGET_DIR="${TARGET_BASE}/${SKILL_NAME}"
BACKUP_BASE="${HOME}/.codebuddy/.backup"

echo "📦 准备安装 ${SKILL_NAME}"
echo "   源目录: ${SOURCE_DIR}"
echo "   目标目录: ${TARGET_DIR}"
echo ""

# 防止源目录就是目标目录（在 ~/.codebuddy/skills/issue-trace/ 内自调用会自毁）
if [ "${SOURCE_DIR}" = "${TARGET_DIR}" ]; then
  echo "❌ 源目录与目标目录相同，禁止自毁式安装"
  echo "   请将 ${SKILL_NAME} 解压到其他位置（如 /tmp/${SKILL_NAME}）后再运行 install.sh"
  exit 1
fi

# 1. 备份已有版本（红线：修改前必须备份）
if [ -d "${TARGET_DIR}" ]; then
  BACKUP_DATE_DIR="${BACKUP_BASE}/$(date +%Y%m%d)"
  BACKUP_DIR="${BACKUP_DATE_DIR}/${SKILL_NAME}.$(date +%H%M%S)"
  mkdir -p "${BACKUP_DATE_DIR}"
  cp -r "${TARGET_DIR}" "${BACKUP_DIR}"
  echo "✅ 已备份旧版本 → ${BACKUP_DIR}"
fi

# 2. 准备目标目录
mkdir -p "${TARGET_DIR}"

# 3. 复制（rsync 比 cp 更稳，自动处理软链/属性）
#    --delete: 删除目标目录里源中不存在的文件（保证幂等）
#    --delete-excluded: 主动删除目标目录里被 exclude 的旧文件
#                      （否则覆盖装时旧的 install.sh / README.md 等会留在目标目录污染）
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --delete-excluded \
    --exclude='install.sh' \
    --exclude='preflight.sh' \
    --exclude='README.md' \
    --exclude='.git' \
    --exclude='.git/' \
    --exclude='.DS_Store' \
    "${SOURCE_DIR}/" "${TARGET_DIR}/"
else
  echo "⚠️  rsync 未安装，降级使用 cp（无 --delete 语义，旧文件可能残留）"
  cp -R "${SOURCE_DIR}/." "${TARGET_DIR}/"
  rm -f "${TARGET_DIR}/install.sh" "${TARGET_DIR}/preflight.sh" "${TARGET_DIR}/README.md"
fi

# 4. 给脚本加执行权限（git 上 .sh 权限可能丢失）
if [ -d "${TARGET_DIR}/scripts" ]; then
  find "${TARGET_DIR}/scripts" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
fi

# 5. 校验
if [ ! -f "${TARGET_DIR}/SKILL.md" ]; then
  echo "❌ 安装失败：${TARGET_DIR}/SKILL.md 未找到"
  exit 1
fi

# 读取版本（容错 fallback）
VERSION="unknown"
if [ -f "${TARGET_DIR}/_meta.json" ]; then
  VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "${TARGET_DIR}/_meta.json" 2>/dev/null \
    | head -n 1 \
    | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || echo "unknown")
  [ -z "${VERSION}" ] && VERSION="unknown"
fi

echo ""
echo "✅ ${SKILL_NAME} v${VERSION} 已安装到 ${TARGET_DIR}"
echo "📖 重启 CodeBuddy 后即可通过自然语言触发本 skill"
echo "   触发关键词示例：「深挖一下 XXX 为什么会这样」「trace 一下这个调用链」"
echo ""
echo "ℹ️  卸载: bash ${TARGET_DIR}/uninstall.sh"
