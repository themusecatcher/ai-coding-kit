#!/usr/bin/env bash
# issue-trace skill 打包前自检 / 安装前自检
# 用法: bash preflight.sh
# 行为: 检查必需文件 → 扫描绝对路径污染 → 检查脚本权限 → 报告

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0
WARNINGS=0

echo "🔍 issue-trace skill 打包前自检"
echo "   目录: ${SOURCE_DIR}"
echo ""

# ---------- 1. 必需文件检查 ----------
echo "[1/4] 检查必需文件..."
REQUIRED_FILES=("SKILL.md" "_meta.json" "install.sh" "uninstall.sh" "README.md")
for f in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "${SOURCE_DIR}/${f}" ]; then
    echo "  ❌ 缺失: ${f}"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✓ ${f}"
  fi
done

REQUIRED_DIRS=("references" "scripts")
for d in "${REQUIRED_DIRS[@]}"; do
  if [ ! -d "${SOURCE_DIR}/${d}" ]; then
    echo "  ⚠️  缺失目录: ${d}/（如 skill 不需要可忽略）"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "  ✓ ${d}/"
  fi
done

# ---------- 2. 绝对路径污染扫描 ----------
echo ""
echo "[2/4] 扫描绝对路径污染（/Users/<name>）..."
# 排除 .git 目录、node_modules、备份文件
HITS=$(grep -rn "/Users/[a-zA-Z0-9_-]*" "${SOURCE_DIR}" \
  --exclude-dir='.git' \
  --exclude-dir='node_modules' \
  --exclude='preflight.sh' \
  --exclude='*.bak' 2>/dev/null || true)

if [ -n "${HITS}" ]; then
  HIT_COUNT=$(echo "${HITS}" | wc -l | tr -d ' ')
  # 区分 Markdown 示例 vs 脚本硬编码
  CODE_HITS=$(echo "${HITS}" | grep -E '\.(sh|json|js|ts|py)\b' || true)
  if [ -n "${CODE_HITS}" ]; then
    echo "  ❌ 脚本/配置中存在硬编码绝对路径（必须修复）:"
    echo "${CODE_HITS}" | sed 's/^/     /'
    ERRORS=$((ERRORS + 1))
  fi
  MD_HITS=$(echo "${HITS}" | grep -E '\.md\b' || true)
  if [ -n "${MD_HITS}" ]; then
    MD_COUNT=$(echo "${MD_HITS}" | wc -l | tr -d ' ')
    echo "  ⚠️  Markdown 中含 ${MD_COUNT} 处用户家目录示例（同事看到会困惑，建议改成 \$HOME 或 ~/...）:"
    echo "${MD_HITS}" | sed 's/^/     /' | head -10
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo "  ✓ 未发现绝对路径污染"
fi

# ---------- 3. 脚本权限检查 ----------
echo ""
echo "[3/4] 检查脚本可执行性..."
SHELL_SCRIPTS=$(find "${SOURCE_DIR}" -type f -name "*.sh" \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" 2>/dev/null || true)
for s in ${SHELL_SCRIPTS}; do
  if [ ! -x "${s}" ]; then
    echo "  ⚠️  无执行权限: ${s#${SOURCE_DIR}/}（install.sh 安装时会自动 chmod +x，仓库内可忽略）"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "  ✓ ${s#${SOURCE_DIR}/}"
  fi
done

# ---------- 4. _meta.json 格式检查 ----------
echo ""
echo "[4/4] 校验 _meta.json 格式..."
if [ -f "${SOURCE_DIR}/_meta.json" ]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json,sys; json.load(open('${SOURCE_DIR}/_meta.json'))" 2>/dev/null; then
      echo "  ✓ JSON 格式合法"
    else
      echo "  ❌ _meta.json 格式不合法（python3 解析失败）"
      ERRORS=$((ERRORS + 1))
    fi
  else
    echo "  ⚠️  python3 不可用，跳过 JSON 严格校验"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# ---------- 总结 ----------
echo ""
echo "==================================================="
echo "  自检结果: ${ERRORS} 个错误, ${WARNINGS} 个警告"
echo "==================================================="
if [ "${ERRORS}" -gt 0 ]; then
  echo "❌ 存在错误，禁止打包/分发"
  exit 1
elif [ "${WARNINGS}" -gt 0 ]; then
  echo "⚠️  存在警告，可分发但建议修复"
  exit 0
else
  echo "✅ 全部通过，可分发"
  exit 0
fi
