#!/bin/bash
# ============================================================
# dev-flow 安装脚本
# 将 dev-flow 及其依赖【复制】为独立副本安装到 ~/.codebuddy/
# （skills/agents 均为实体副本，与源仓库完全隔离：改动 ~/.codebuddy/
#   下的内容不会影响 clone 仓库，反之亦然）
#
# 快速开始：
#   bash install.sh              # 默认：全部关联 Skill（15 个）+ 2 条核心规则 + Agents
#   bash install.sh --all-repo   # 整仓全量（仓库 skills/ 全部 28 个 + rules/ 全部 16 条 + all Agents）
#
# 完整用法（管理命令 / 示例）见：
#   bash install.sh --help
#
# 版本：1.3.0
# ============================================================

set -e

# ==================== 配置 ====================
VERSION="1.3.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR"
GLOBAL_DIR="$HOME/.codebuddy"

# Skills 列表（分级）
CORE_SKILLS=("dev-flow")  # 核心引擎

# 核心依赖（流程断点，无则步骤中断）
CORE_DEPS=(
  "requirement-intake"
  "knowledge-loop"
  "design-advisor"
  "code-review"
  "tech-doc"
  "verification-pipeline"
  "smart-commit"
)

# 强化依赖（缺失时降级运行，不影响主流程）
ENHANCED_DEPS=(
  "coding-standards"
  "frontend-patterns"
  "self-improving-agent"
  "browser-compat"
)

# 可选依赖（按场景加载）
OPTIONAL_DEPS=(
  "i18n"
  "dom-animation"
  "browser-toolkit"
)

# 完整安装列表
ALL_DEPS=("${CORE_DEPS[@]}" "${ENHANCED_DEPS[@]}" "${OPTIONAL_DEPS[@]}")
ALL_SKILLS=("${CORE_SKILLS[@]}" "${ALL_DEPS[@]}")

# 规则列表
RULES=("AI行为规范.mdc" "开发规范-红线.mdc")

# Agent 列表（dev-flow 子代理）
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

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==================== 工具函数 ====================

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_ok() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_fail() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "   $1"; }

show_help() {
  cat << 'EOF'
dev-flow 安装脚本 v1.3.0

用法：
  bash install.sh [选项...]

安装命令（二选一）：
  （无参数）      默认安装：dev-flow + 全部 14 依赖（共 15 Skill）+ 2 条核心规则 + Agents
  --all-repo      整仓全量：仓库根 skills/ 下所有 skill + rules/ 下所有规则 + agents/ 下所有 Agent
                  （含非 dev-flow 依赖的独立 skill 和按需规则）；仅本地 clone 仓库可用

说明：默认安装即会一并安装 Skill、规则（Rules）和 Agents，无需额外开关。
      规则 / Agents / 配置若已存在则不覆盖，保护你的本地改动。

管理命令：
  --uninstall     卸载所有已安装的 Skills、Agents 和规则
  --status        健康检查（检查安装状态、副本完整性）
  --help          显示此帮助

兼容说明：
  --global        历史参数，现已默认全局安装（加不加都装到 ~/.codebuddy/，保留兼容）

示例：
  # 首次安装（推荐）
  bash install.sh

  # 整仓全量安装（仓库所有 skill，本地 clone 场景）
  bash install.sh --all-repo

  # 检查安装状态
  bash install.sh --status

  # 卸载
  bash install.sh --uninstall
EOF
}

# ==================== 参数解析 ====================

ACTION="install"
INSTALL_LEVEL="default"  # default | all-repo

for arg in "$@"; do
  case "$arg" in
    --all-repo)   INSTALL_LEVEL="all-repo" ;;
    --uninstall)  ACTION="uninstall" ;;
    --status)     ACTION="status" ;;
    --global)     : ;;  # 历史参数：现默认即全局安装，保留兼容（不做任何事）
    --help|-h)    show_help; exit 0 ;;
    *)            log_fail "未知参数: $arg"; show_help; exit 1 ;;
  esac
done

# ==================== 安装逻辑 ====================

# 可选配置向导（非阻塞）：安装后引导用户按需配置 org.yaml
# - 交互式环境：提供 现在配置 / 稍后配置 / 不配置直接用 三选项，默认（回车）不配置
# - 非交互式环境（CI / 管道调用）：自动跳过，仅打印提示，不阻塞
prompt_config() {
  local user_config="$GLOBAL_DIR/config/org.yaml"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ⚙️  配置提醒（可选，非必需）"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  log_info "dev-flow 及依赖 skill 支持可选的平台集成（文档 / 任务 / 日志 / CI / MCP 等）。"
  log_info "全部为「可选增强」——不配置也能用，核心功能在纯本地模式下完整可用。"
  echo ""
  [ -f "$user_config" ] && log_step "配置文件: $user_config"
  echo ""

  # 非交互式环境（CI / 管道调用）：跳过向导，仅提示，不阻塞
  if [ ! -t 0 ]; then
    log_info "（检测到非交互式环境，跳过配置向导）"
    log_info "如需平台增强，稍后编辑上述配置文件即可（可只填部分字段）。"
    echo ""
    return 0
  fi

  echo "  请选择配置方式："
  echo "    1) 现在配置（用默认编辑器打开 org.yaml，可只填需要的字段）"
  echo "    2) 稍后手动配置（仅记住路径，跳过）"
  echo "    3) 不配置，直接使用（零配置模式，全部走本地）"
  echo ""
  local choice=""
  read -r -p "  输入选项 [1/2/3，回车默认 3]: " choice || true
  echo ""

  case "$choice" in
    1)
      if [ ! -f "$user_config" ]; then
        log_warn "未找到配置文件，跳过（可稍后手动创建 $user_config）"
        return 0
      fi
      local editor="${EDITOR:-vi}"
      log_info "使用 $editor 打开配置文件（保存退出后继续）..."
      "$editor" "$user_config" || log_warn "编辑器退出异常，可稍后手动编辑 $user_config"
      log_ok "配置完成。如需再次修改：编辑 $user_config"
      ;;
    2)
      log_ok "已跳过。稍后可编辑 $user_config 按需启用平台增强（可只填部分字段）。"
      ;;
    *)
      log_ok "已选择零配置模式，所有功能将以纯本地模式运行。"
      ;;
  esac
  echo ""
}

do_install() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🚀 dev-flow 安装器 v1.3.0"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # 确定要安装的 Skills（分级）
  local skills_to_install=("${CORE_SKILLS[@]}")
  local level_label=""
  # Skills 源基准目录：
  #   - 默认级别：从 dist 分发包 codebuddy/skills 取
  #   - all-repo：从仓库根 skills/ 取（含仓库托管的全部 skill，非 dev-flow 依赖也在内）
  local SKILLS_SRC_BASE="$DIST_DIR/codebuddy/skills"
  local repo_skills_dir
  repo_skills_dir="$(cd "$DIST_DIR/../.." 2>/dev/null && pwd)"

  case "$INSTALL_LEVEL" in
    all-repo)
      # 整仓全量：动态扫描仓库根 skills/ 下所有目录（跳过隐藏/私有 _ 前缀）
      if [ -z "$repo_skills_dir" ] || [ ! -d "$repo_skills_dir" ]; then
        log_fail "未找到仓库根 skills/ 目录，--all-repo 仅支持从本地 clone 仓库运行"
        exit 1
      fi
      SKILLS_SRC_BASE="$repo_skills_dir"
      skills_to_install=()
      local d sname
      for d in "$SKILLS_SRC_BASE"/*/; do
        [ -d "$d" ] || continue
        sname="$(basename "$d")"
        case "$sname" in
          .*|_*) continue ;;  # 跳过隐藏目录 / 私有 skill
        esac
        skills_to_install+=("$sname")
      done
      if [ ${#skills_to_install[@]} -eq 0 ]; then
        log_fail "仓库根 skills/ 下未发现任何 skill: $SKILLS_SRC_BASE"
        exit 1
      fi
      level_label="整仓全量安装（仓库根下全部 ${#skills_to_install[@]} 个 Skill + 全部规则 + Agents）"
      ;;
    *)
      skills_to_install+=("${ALL_DEPS[@]}")
      level_label="默认安装（dev-flow + 全部 14 依赖，共 15 个 Skill + 2 条核心规则 + Agents）"
      ;;
  esac
  log_info "$level_label"

  # 确保目标目录存在
  mkdir -p "$GLOBAL_DIR/skills"
  mkdir -p "$GLOBAL_DIR/rules"
  mkdir -p "$GLOBAL_DIR/agents"

  # 安装 Skills
  echo ""
  log_info "安装 Skills..."
  local installed=0
  local skipped=0
  local backed_up=0

  for skill in "${skills_to_install[@]}"; do
    local src="$SKILLS_SRC_BASE/$skill"
    local dst="$GLOBAL_DIR/skills/$skill"
    local rsync_excludes=()

    # dev-flow 特殊处理：
    #   - all-repo 模式下 $SKILLS_SRC_BASE/dev-flow 即仓库根 skills/dev-flow（正确）
    #   - 常规模式下 dist/codebuddy/skills 内无 dev-flow，源需指向 dist 父目录（skill 根）
    #   两种模式都排除 dist/（分发包）和 .git/，避免冗余嵌套
    if [ "$skill" = "dev-flow" ]; then
      [ "$INSTALL_LEVEL" != "all-repo" ] && src="$(cd "$DIST_DIR/.." && pwd)"
      rsync_excludes=(--exclude "dist/" --exclude ".git/")
    fi

    # 检查源是否存在
    if [ ! -d "$src" ]; then
      log_warn "源 Skill 不存在，跳过: $skill"
      skipped=$((skipped + 1))
      continue
    fi

    # 清理旧版符号链接（历史遗留），确保后续为实体复制
    [ -L "$dst" ] && rm -f "$dst"

    # 已有实体目录但非本安装器管理（无标记）→ 先备份，避免覆盖用户内容
    if [ -d "$dst" ] && [ ! -f "$dst/.dev-flow-managed" ]; then
      local backup_dir="$GLOBAL_DIR/skills/.backup"
      mkdir -p "$backup_dir"
      local backup_name="${skill}.bak.$(date +%Y%m%d%H%M%S)"
      mv "$dst" "$backup_dir/$backup_name"
      log_warn "$skill → 原目录已备份为 .backup/$backup_name"
      backed_up=$((backed_up + 1))
    fi

    # 复制到目标（rsync 增量同步；--delete 保持与源一致，实现独立副本）
    mkdir -p "$dst"
    rsync -a --delete "${rsync_excludes[@]}" "$src/" "$dst/"
    # 打受管标记（供 status/uninstall 识别；写在 rsync 之后避免被 --delete 清除）
    echo "installed by dev-flow install.sh v$VERSION at $(date '+%Y-%m-%d %H:%M:%S')" > "$dst/.dev-flow-managed"
    log_ok "$skill → 已安装（独立副本）"
    installed=$((installed + 1))
  done

  # 安装规则
  #   - 默认模式：仅安装核心规则（从 dist 分发包）
  #   - all-repo 模式：扫描仓库根 rules/ 下所有 .mdc 文件
  echo ""
  log_info "安装规则集..."

  local rules_to_install=()
  local rules_src_dir="$DIST_DIR/codebuddy/rules"  # 默认源

  if [ "$INSTALL_LEVEL" = "all-repo" ]; then
    rules_src_dir="$repo_skills_dir/../rules"
    if [ -d "$rules_src_dir" ]; then
      for f in "$rules_src_dir"/*.mdc; do
        [ -f "$f" ] || continue
        rules_to_install+=("$(basename "$f")")
      done
    fi
    if [ ${#rules_to_install[@]} -eq 0 ]; then
      log_warn "未找到仓库根 rules/ 目录，回退到默认规则列表"
      rules_to_install=("${RULES[@]}")
      rules_src_dir="$DIST_DIR/codebuddy/rules"
    fi
    # 写入受管标记文件（供 status/uninstall 识别 all-repo 安装的规则）
    printf '%s\n' "${rules_to_install[@]}" > "$GLOBAL_DIR/rules/.dev-flow-managed"
  else
    rules_to_install=("${RULES[@]}")
  fi

  for rule in "${rules_to_install[@]}"; do
    local src="$rules_src_dir/$rule"
    local dst="$GLOBAL_DIR/rules/$rule"

    if [ ! -f "$src" ]; then
      log_warn "源规则不存在，跳过: $rule"
      continue
    fi

    if [ -f "$dst" ]; then
      log_step "📄 $rule → 已存在（不覆盖）"
    else
      cp "$src" "$dst"
      log_ok "$rule → 已安装"
    fi
  done

  # 安装 Agents
  #   - 默认模式：从 dist 分发包安装
  #   - all-repo 模式：从仓库根 agents/ 安装（支持仓库新增 Agent）
  echo ""
  log_info "安装 Agents..."
  local agent_installed=0
  local agent_skipped=0

  local agents_to_install=("${AGENTS[@]}")
  local agents_src_dir="$DIST_DIR/codebuddy/agents"

  if [ "$INSTALL_LEVEL" = "all-repo" ]; then
    local repo_agents_dir="$repo_skills_dir/../agents"
    if [ -d "$repo_agents_dir" ]; then
      agents_to_install=()
      for f in "$repo_agents_dir"/*.md; do
        [ -f "$f" ] || continue
        agents_to_install+=("$(basename "$f")")
      done
    fi
    if [ ${#agents_to_install[@]} -gt 0 ]; then
      agents_src_dir="$repo_agents_dir"
    else
      log_warn "未找到仓库根 agents/ 目录，回退到默认 Agent 列表"
      agents_to_install=("${AGENTS[@]}")
    fi
  fi

  for agent in "${agents_to_install[@]}"; do
    local src="$agents_src_dir/$agent"
    local dst="$GLOBAL_DIR/agents/$agent"

    # 检查源是否存在
    if [ ! -f "$src" ]; then
      log_warn "源 Agent 不存在，跳过: $agent"
      agent_skipped=$((agent_skipped + 1))
      continue
    fi

    # 清理旧版符号链接（历史遗留）
    [ -L "$dst" ] && rm -f "$dst"

    if [ -f "$dst" ]; then
      # 内容一致 → 跳过；不一致 → 备份旧文件后覆盖
      if cmp -s "$src" "$dst"; then
        log_step "📄 $agent → 已是最新"
        agent_skipped=$((agent_skipped + 1))
        continue
      fi
      local backup_dir="$GLOBAL_DIR/agents/.backup"
      mkdir -p "$backup_dir"
      local backup_name="${agent%.md}.bak.$(date +%Y%m%d%H%M%S).md"
      cp "$dst" "$backup_dir/$backup_name"
      cp "$src" "$dst"
      log_ok "$agent → 已更新（原文件备份为 .backup/$backup_name）"
      agent_installed=$((agent_installed + 1))
    else
      cp "$src" "$dst"
      log_ok "$agent → 已安装（副本）"
      agent_installed=$((agent_installed + 1))
    fi
  done

  # 安装配置文件（复制到 ~/.codebuddy/config/，已存在则不覆盖，保留用户已有配置）
  local repo_root config_src config_dst
  repo_root="$(cd "$DIST_DIR/../../.." 2>/dev/null && pwd)"
  config_src="$repo_root/config/org.yaml"
  config_dst="$GLOBAL_DIR/config/org.yaml"
  if [ -f "$config_src" ]; then
    echo ""
    log_info "安装配置文件..."
    mkdir -p "$GLOBAL_DIR/config"
    if [ -f "$config_dst" ]; then
      log_step "📄 config/org.yaml → 已存在（不覆盖，保留你的配置）"
    else
      cp "$config_src" "$config_dst"
      log_ok "config/org.yaml → 已安装（默认全空，可选配置）"
    fi
  fi

  # 输出汇总
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📊 安装完成"
  echo "     Skills: $installed 新安装 / $skipped 已有"
  echo "     Agents: $agent_installed 新安装 / $agent_skipped 已有"
  [ $backed_up -gt 0 ] && echo "     备份:   $backed_up（在 skills/.backup/）"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  log_info "使用 'bash install.sh --status' 检查安装状态"
  echo ""

  # 可选配置向导（非阻塞）
  prompt_config
}

# ==================== 卸载逻辑 ====================

do_uninstall() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🗑  dev-flow 卸载"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local removed=0

  # 卸载 Skills（标记驱动：扫描所有带 .dev-flow-managed 的受管副本，
  # 无论此前用哪种级别安装（含 --all-repo 的全量）都能干净卸载）
  local backup_dir="$GLOBAL_DIR/skills/.backup"
  local marker
  for marker in "$GLOBAL_DIR/skills"/*/.dev-flow-managed; do
    [ -f "$marker" ] || continue   # 无匹配时 glob 原样返回，跳过
    local dst
    dst="$(dirname "$marker")"
    local skill
    skill="$(basename "$dst")"
    mkdir -p "$backup_dir"
    local backup_name="${skill}.uninstall.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$backup_dir/$backup_name"
    log_ok "已卸载: skills/$skill（备份到 .backup/$backup_name）"
    removed=$((removed + 1))
  done

  # 清理旧版符号链接（历史遗留的链接式安装）
  for skill in "${ALL_SKILLS[@]}"; do
    local dst="$GLOBAL_DIR/skills/$skill"
    if [ -L "$dst" ]; then
      rm -f "$dst"
      log_ok "已移除旧链接: skills/$skill"
      removed=$((removed + 1))
    fi
  done

  # 卸载规则
  # 先处理 all-repo 安装的规则（通过标记文件 .dev-flow-managed 识别）
  local rule_backup_dir="$GLOBAL_DIR/rules/.backup"
  local rules_marker="$GLOBAL_DIR/rules/.dev-flow-managed"
  if [ -f "$rules_marker" ]; then
    log_info "卸载 all-repo 安装的规则..."
    while IFS= read -r rule; do
      [ -z "$rule" ] && continue
      local dst="$GLOBAL_DIR/rules/$rule"
      if [ -f "$dst" ]; then
        mkdir -p "$rule_backup_dir"
        local backup_name="${rule%.mdc}.uninstall.$(date +%Y%m%d%H%M%S).mdc"
        cp "$dst" "$rule_backup_dir/$backup_name"
        rm -f "$dst"
        log_ok "已卸载: rules/$rule（备份到 .backup/$backup_name）"
        removed=$((removed + 1))
      fi
    done < "$rules_marker"
    rm -f "$rules_marker"
  else
    # 默认模式：仅处理核心规则（符号链接 或 与源内容一致的副本）
    for rule in "${RULES[@]}"; do
      local dst="$GLOBAL_DIR/rules/$rule"
      local rule_src="$DIST_DIR/codebuddy/rules/$rule"
      if [ -L "$dst" ]; then
        rm -f "$dst"
        log_ok "已移除: rules/$rule"
        removed=$((removed + 1))
      elif [ -f "$dst" ] && [ -f "$rule_src" ] && cmp -s "$rule_src" "$dst"; then
        rm -f "$dst"
        log_ok "已移除: rules/$rule"
        removed=$((removed + 1))
      elif [ -f "$dst" ]; then
        log_warn "rules/$rule 已被修改，跳过（如需卸载请手动删除）"
      fi
    done
  fi

  # 卸载 Agents（受管副本备份后删除；符号链接直接移除）
  for agent in "${AGENTS[@]}"; do
    local dst="$GLOBAL_DIR/agents/$agent"
    if [ -L "$dst" ]; then
      rm -f "$dst"
      log_ok "已移除链接: agents/$agent"
      removed=$((removed + 1))
    elif [ -f "$dst" ]; then
      local backup_dir="$GLOBAL_DIR/agents/.backup"
      mkdir -p "$backup_dir"
      local backup_name="${agent%.md}.uninstall.$(date +%Y%m%d%H%M%S).md"
      cp "$dst" "$backup_dir/$backup_name"
      rm -f "$dst"
      log_ok "已卸载: agents/$agent（备份到 .backup/$backup_name）"
      removed=$((removed + 1))
    fi
  done

  # 检查备份恢复
  local backup_dir="$GLOBAL_DIR/skills/.backup"
  if [ -d "$backup_dir" ] && [ "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
    echo ""
    log_info "发现备份目录: $backup_dir"
    log_info "如需恢复原始 Skill，手动执行:"
    echo "  mv $backup_dir/<skill>.bak.<timestamp> $GLOBAL_DIR/skills/<skill>"
  fi

  local agent_backup_dir="$GLOBAL_DIR/agents/.backup"
  if [ -d "$agent_backup_dir" ] && [ "$(ls -A "$agent_backup_dir" 2>/dev/null)" ]; then
    echo ""
    log_info "发现 Agent 备份目录: $agent_backup_dir"
    log_info "如需恢复原始 Agent，手动执行:"
    echo "  mv $agent_backup_dir/<agent>.bak.<timestamp>.md $GLOBAL_DIR/agents/<agent>"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✅ 卸载完成（移除 $removed 项）"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ==================== 状态检查 ====================

do_status() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🔍 dev-flow 安装状态"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # 检查分发仓库
  if [ -d "$HOME/.dev-flow-dist" ]; then
    log_step "📁 仓库位置: ~/.dev-flow-dist"
    if [ -f "$HOME/.dev-flow-dist/.installed-version" ]; then
      log_step "🏷  当前版本: $(cat "$HOME/.dev-flow-dist/.installed-version")"
    fi
  else
    log_step "📁 仓库位置: $DIST_DIR (本地)"
  fi
  echo ""

  local all_ok=true

  # 检查 Skills
  for skill in "${ALL_SKILLS[@]}"; do
    local dst="$GLOBAL_DIR/skills/$skill"
    if [ -d "$dst" ] && [ -f "$dst/.dev-flow-managed" ]; then
      log_ok "skills/$skill（已安装副本）"
    elif [ -L "$dst" ]; then
      log_warn "skills/$skill（旧版符号链接，重新运行安装即可迁移为独立副本）"
    elif [ -d "$dst" ]; then
      log_step "📂 skills/$skill（实体目录，非本安装器安装）"
    else
      log_fail "skills/$skill（未安装）"
      all_ok=false
    fi
  done

  # 额外受管副本（--all-repo 安装的、不属于 dev-flow 依赖清单的独立 skill）
  local extra_marker extra_name extra_count=0
  for extra_marker in "$GLOBAL_DIR/skills"/*/.dev-flow-managed; do
    [ -f "$extra_marker" ] || continue
    extra_name="$(basename "$(dirname "$extra_marker")")"
    # 跳过已在 ALL_SKILLS 中列出的核心/依赖 skill
    case " ${ALL_SKILLS[*]} " in
      *" $extra_name "*) continue ;;
    esac
    [ $extra_count -eq 0 ] && echo "" && log_step "其他受管副本（--all-repo 额外安装）："
    log_ok "skills/$extra_name（独立 skill 副本）"
    extra_count=$((extra_count + 1))
  done

  # 检查规则
  echo ""
  local rules_marker="$GLOBAL_DIR/rules/.dev-flow-managed"
  if [ -f "$rules_marker" ]; then
    # all-repo 安装的规则：读取标记文件中的完整清单
    while IFS= read -r rule; do
      [ -z "$rule" ] && continue
      local dst="$GLOBAL_DIR/rules/$rule"
      if [ -f "$dst" ]; then
        log_ok "rules/$rule"
      else
        log_warn "rules/$rule（未安装）"
      fi
    done < "$rules_marker"
  else
    # 默认安装：仅检查核心规则
    for rule in "${RULES[@]}"; do
      local dst="$GLOBAL_DIR/rules/$rule"
      if [ -f "$dst" ]; then
        log_ok "rules/$rule"
      else
        log_warn "rules/$rule（未安装）"
      fi
    done
  fi

  # 检查 Agents
  echo ""
  for agent in "${AGENTS[@]}"; do
    local dst="$GLOBAL_DIR/agents/$agent"
    if [ -L "$dst" ]; then
      log_warn "agents/$agent（旧版符号链接，重新运行安装即可迁移为独立副本）"
    elif [ -f "$dst" ]; then
      log_ok "agents/$agent（已安装副本）"
    else
      log_fail "agents/$agent（未安装）"
      all_ok=false
    fi
  done

  # 汇总
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ "$all_ok" = "true" ]; then
    echo -e "  ${GREEN}✅ 安装状态正常${NC}"
  else
    echo -e "  ${RED}❌ 存在问题，重新运行安装（bash install.sh）修复${NC}"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ==================== 主逻辑 ====================

case "$ACTION" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  status)    do_status ;;
esac
