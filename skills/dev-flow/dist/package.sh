#!/bin/bash
# ============================================================
# dev-flow 打包脚本
# 从 ~/.codebuddy/ 同步最新依赖到 dist/codebuddy/
#
# 用法：
#   bash package.sh                   # 同步所有依赖（从 ~/.codebuddy/）
#   bash package.sh --source <path>   # 从指定目录同步（如 ai-coding-kit/）
#   bash package.sh --dry-run         # 仅显示将要复制的文件，不实际复制
#   bash package.sh --help            # 帮助
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_SKILLS="$HOME/.codebuddy/skills"
SRC_RULES="$HOME/.codebuddy/rules"
SRC_AGENTS="$HOME/.codebuddy/agents"
DIST_SKILLS="$SCRIPT_DIR/codebuddy/skills"
DIST_RULES="$SCRIPT_DIR/codebuddy/rules"
DIST_AGENTS="$SCRIPT_DIR/codebuddy/agents"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 依赖清单（与 install.sh 保持一致）
CORE_DEPS=(
  "requirement-intake"
  "knowledge-loop"
  "design-advisor"
  "code-review"
  "tech-doc"
  "verification-pipeline"
  "smart-commit"
)
ENHANCED_DEPS=(
  "coding-standards"
  "frontend-patterns"
  "self-improving-agent"
  "browser-compat"
)
OPTIONAL_DEPS=(
  "i18n"
  "dom-animation"
  "browser-toolkit"
)
RULES=(
  "AI行为规范.mdc"
  "开发规范-红线.mdc"
)
AGENTS=(
  "1号.md"
  "2 号.md"
  "3 号.md"
  "4 号.md"
  "5 号.md"
  "6 号.md"
  "7 号.md"
  "8 号.md"
  "9 号.md"
  "step-gate.md"
)

DRY_RUN=false
SRC_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --source) SRC_ROOT="$2"; shift 2 ;;
    --help|-h)
      echo "dev-flow 打包脚本"
      echo "用法: bash package.sh [--source <path>] [--dry-run]"
      echo "  --source <path>  指定源目录，如 ~/ai-coding-kit 或 /path/to/ai-coding-kit"
      echo "  --dry-run        仅预览将要复制的文件"
      exit 0
      ;;
    *) shift ;;
  esac
done

# 如果指定了 --source，则从该目录下找 skills/ rules/ agents/；否则默认 ~/.codebuddy/
if [ -n "$SRC_ROOT" ]; then
  SRC_ROOT="$(cd "$SRC_ROOT" && pwd)"
  SRC_SKILLS="$SRC_ROOT/skills"
  SRC_RULES="$SRC_ROOT/rules"
  SRC_AGENTS="$SRC_ROOT/agents"
fi

sync_skill() {
  local name="$1"
  local src="$SRC_SKILLS/$name"
  local dst="$DIST_SKILLS/$name"

  if [ ! -d "$src" ]; then
    echo -e "  ${YELLOW}⚠️  源不存在，跳过: $name${NC}"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    echo -e "  📋 将同步: $name"
    return
  fi

  rm -rf "$dst"
  cp -R "$src" "$dst"
  echo -e "  ${GREEN}✅ $name${NC} ($(du -sh "$dst" | cut -f1))"
}

sync_rule() {
  local name="$1"
  local src="$SRC_RULES/$name"
  local dst="$DIST_RULES/$name"

  if [ ! -f "$src" ]; then
    echo -e "  ${YELLOW}⚠️  源不存在，跳过: $name${NC}"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    echo -e "  📋 将同步: $name"
    return
  fi

  cp "$src" "$dst"
  echo -e "  ${GREEN}✅ $name${NC}"
}

sync_agent() {
  local name="$1"
  local src="$SRC_AGENTS/$name"
  local dst="$DIST_AGENTS/$name"

  if [ ! -f "$src" ]; then
    echo -e "  ${YELLOW}⚠️  源不存在，跳过: $name${NC}"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    echo -e "  📋 将同步: $name"
    return
  fi

  cp "$src" "$dst"
  echo -e "  ${GREEN}✅ $name${NC}"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📦 dev-flow 打包同步"
if [ "$DRY_RUN" = true ]; then
  echo "  🧪 Dry Run 模式（仅预览）"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 确保目标目录存在
mkdir -p "$DIST_SKILLS"
mkdir -p "$DIST_RULES"
mkdir -p "$DIST_AGENTS"

echo -e "${BLUE}源:${NC} ${SRC_SKILLS}"
echo ""

echo -e "${BLUE}核心依赖（7个）:${NC}"
for skill in "${CORE_DEPS[@]}"; do
  sync_skill "$skill"
done

echo ""
echo -e "${BLUE}强化依赖（4个）:${NC}"
for skill in "${ENHANCED_DEPS[@]}"; do
  sync_skill "$skill"
done

echo ""
echo -e "${BLUE}可选依赖（3个）:${NC}"
for skill in "${OPTIONAL_DEPS[@]}"; do
  sync_skill "$skill"
done

echo ""
echo -e "${BLUE}规则文件（2个）:${NC}"
for rule in "${RULES[@]}"; do
  sync_rule "$rule"
done

echo ""
echo -e "${BLUE}Agent 文件（10个）:${NC}"
for agent in "${AGENTS[@]}"; do
  sync_agent "$agent"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DRY_RUN" = true ]; then
  echo "  📋 预览完成"
else
  echo -e "  ${GREEN}✅ 同步完成${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
