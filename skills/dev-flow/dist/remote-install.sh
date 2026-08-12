#!/bin/bash
# ============================================================
# dev-flow 远程安装脚本
# 从 Git 仓库克隆并安装 dev-flow 及其依赖
#
# 快速开始：
#   bash remote-install.sh              # 克隆最新稳定版并安装（全部 Skill + 规则 + Agents）
#   bash remote-install.sh --all-repo   # 克隆并整仓全量安装（含独立 skill）
#
# 完整用法（版本管理 / 更新 / 卸载 / 示例）见：
#   bash remote-install.sh --help
#
# 版本：1.3.0
# ============================================================

set -e

# ==================== 配置 ====================
# 仓库地址 — 通过环境变量 DEV_FLOW_REPO_URL 覆盖
REPO_URL="${DEV_FLOW_REPO_URL:-}"  # 通过环境变量 DEV_FLOW_REPO_URL 设置你的仓库地址
LOCAL_DIR="$HOME/.dev-flow-dist"
VERSION_FILE="$LOCAL_DIR/.installed-version"
INSTALL_SCRIPT="$LOCAL_DIR/skills/dev-flow/dist/install.sh"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_ok() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_fail() { echo -e "${RED}❌ $1${NC}"; }

show_help() {
  cat << 'EOF'
dev-flow 远程安装脚本 v1.3.0

用法：
  bash remote-install.sh [选项]

安装命令（二选一）：
  (无参数)         安装最新稳定版：dev-flow + 全部 14 依赖 + 规则 + Agents
  --all-repo      整仓全量（clone 仓库根 skills/ 下所有 skill，含独立 skill）

版本 / 管理：
  --version <tag>  指定版本安装（如 v1.1.0）
  --update         更新到最新版
  --list           列出所有可用版本（tags）
  --status         检查安装状态
  --uninstall      卸载（移除仓库 + 受管副本）
  --help           显示此帮助

说明：安装即会一并安装 Skill、规则（Rules）和 Agents，无需额外开关。
      规则 / Agents / 配置若已存在则不覆盖，保护你的本地改动。

环境变量：
  DEV_FLOW_REPO_URL  自定义仓库地址

示例：
  # 首次安装（推荐）
  bash remote-install.sh

  # 整仓全量安装（clone 仓库所有 skill）
  bash remote-install.sh --all-repo

  # 更新到最新版
  bash remote-install.sh --update

  # 安装指定版本
  bash remote-install.sh --version v1.1.0

  # 完全卸载
  bash remote-install.sh --uninstall
EOF
}

# ==================== 参数解析 ====================

ACTION="install"
TARGET_VERSION=""
INSTALL_LEVEL=""  # 传递给 install.sh：空=默认全装 / --all-repo=整仓全量

while [ $# -gt 0 ]; do
  case "$1" in
    --version)    ACTION="install"; TARGET_VERSION="$2"; shift ;;
    --update)     ACTION="update" ;;
    --list)       ACTION="list" ;;
    --status)     ACTION="status" ;;
    --uninstall)  ACTION="uninstall" ;;
    --all-repo)   INSTALL_LEVEL="--all-repo" ;;
    --help|-h)    show_help; exit 0 ;;
    *)            log_fail "未知参数: $1"; show_help; exit 1 ;;
  esac
  shift
done

# ==================== 工具函数 ====================

check_git() {
  if ! command -v git &>/dev/null; then
    log_fail "Git 未安装，请先安装 Git"
    exit 1
  fi
}

clone_repo() {
  if [ -d "$LOCAL_DIR" ]; then
    log_info "仓库已存在，更新中..."
    cd "$LOCAL_DIR"
    git fetch --tags --depth 1 --quiet 2>/dev/null || {
      log_fail "无法连接仓库: $REPO_URL"
      log_info "请检查网络连接和仓库权限"
      exit 1
    }
  else
    log_info "克隆仓库: $REPO_URL"
    git clone --depth 1 --quiet "$REPO_URL" "$LOCAL_DIR" 2>/dev/null || {
      log_fail "克隆失败: $REPO_URL"
      log_info "请检查:"
      log_info "  1. 网络连接是否正常"
      log_info "  2. SSH key 是否配置"
      log_info "  3. 仓库地址是否正确"
      exit 1
    }
  fi
}

get_latest_tag() {
  cd "$LOCAL_DIR"
  git tag --sort=-v:refname 2>/dev/null | head -1
}

checkout_version() {
  local version="$1"
  cd "$LOCAL_DIR"

  if [ -z "$version" ]; then
    # 获取最新 tag
    version=$(get_latest_tag)
    if [ -z "$version" ]; then
      log_warn "无版本 tag，使用 main/master 分支"
      version="HEAD"
    fi
  fi

  if [ "$version" != "HEAD" ]; then
    if ! git tag | grep -q "^${version}$"; then
      log_fail "版本不存在: $version"
      log_info "可用版本:"
      git tag --sort=-v:refname | head -10 | sed 's/^/  /'
      exit 1
    fi
    git checkout --quiet "$version" 2>/dev/null
  fi

  echo "$version"
}

run_install() {
  local extra_args="$1"
  if [ ! -f "$INSTALL_SCRIPT" ]; then
    log_fail "install.sh 不存在: $INSTALL_SCRIPT"
    exit 1
  fi
  bash "$INSTALL_SCRIPT" --global $extra_args
}

# ==================== 动作执行 ====================

do_install() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🌐 dev-flow 远程安装"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  check_git
  clone_repo

  local version
  version=$(checkout_version "$TARGET_VERSION")
  log_ok "版本: $version"
  echo ""

  # 执行本地安装
  run_install "$INSTALL_LEVEL"

  # 记录版本
  echo "$version" > "$VERSION_FILE"
  log_ok "版本信息已记录"
}

do_update() {
  echo ""
  log_info "更新 dev-flow..."

  if [ ! -d "$LOCAL_DIR" ]; then
    log_fail "未安装，请先执行: bash remote-install.sh"
    exit 1
  fi

  check_git
  clone_repo

  local old_version=""
  [ -f "$VERSION_FILE" ] && old_version=$(cat "$VERSION_FILE")

  local new_version
  new_version=$(checkout_version "")
  log_ok "版本: ${old_version:-unknown} → $new_version"
  echo ""

  # 重新安装
  run_install "$INSTALL_LEVEL"

  # 更新版本记录
  echo "$new_version" > "$VERSION_FILE"
  log_ok "更新完成"
}

do_list() {
  echo ""
  log_info "可用版本列表:"
  echo ""

  if [ ! -d "$LOCAL_DIR" ]; then
    check_git
    clone_repo
  fi

  cd "$LOCAL_DIR"
  git fetch --tags --quiet 2>/dev/null

  local tags
  tags=$(git tag --sort=-v:refname 2>/dev/null)

  if [ -z "$tags" ]; then
    log_warn "暂无发布版本（使用 main 分支）"
  else
    local current=""
    [ -f "$VERSION_FILE" ] && current=$(cat "$VERSION_FILE")

    while IFS= read -r tag; do
      if [ "$tag" = "$current" ]; then
        echo -e "  ${GREEN}$tag ← 当前安装${NC}"
      else
        echo "  $tag"
      fi
    done <<< "$tags"
  fi
  echo ""
}

do_status() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🔍 远程安装状态"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if [ -d "$LOCAL_DIR" ]; then
    log_ok "仓库已克隆: $LOCAL_DIR"
    if [ -f "$VERSION_FILE" ]; then
      log_ok "已安装版本: $(cat "$VERSION_FILE")"
    else
      log_warn "版本信息缺失"
    fi
    echo ""
    # 委托给 install.sh --status
    if [ -f "$INSTALL_SCRIPT" ]; then
      bash "$INSTALL_SCRIPT" --status
    fi
  else
    log_warn "未通过远程安装（仓库不存在）"
    log_info "如果是本地安装，请使用: bash install.sh --status"
  fi
}

do_uninstall() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🗑  dev-flow 完全卸载"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # 先卸载链接
  if [ -f "$INSTALL_SCRIPT" ]; then
    bash "$INSTALL_SCRIPT" --global --uninstall
  fi

  # 移除本地仓库
  if [ -d "$LOCAL_DIR" ]; then
    rm -rf "$LOCAL_DIR"
    log_ok "已移除本地仓库: $LOCAL_DIR"
  fi

  echo ""
  log_ok "卸载完成"
  echo ""
}

# ==================== 主逻辑 ====================

case "$ACTION" in
  install)   do_install ;;
  update)    do_update ;;
  list)      do_list ;;
  status)    do_status ;;
  uninstall) do_uninstall ;;
esac
