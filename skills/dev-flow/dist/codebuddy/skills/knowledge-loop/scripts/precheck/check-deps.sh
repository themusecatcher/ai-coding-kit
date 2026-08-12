#!/usr/bin/env bash
# ============================================================================
#  check-deps.sh — knowledge-loop Skill 依赖前置检查
#  ----------------------------------------------------------------------------
#  作用：在任何 lint / verify / scan 脚本运行前，确认本机已安装必需依赖；
#        可选依赖缺失时给出降级提示但不阻塞流程。
#  ----------------------------------------------------------------------------
#  必需（任一缺失 → exit 1）：
#    - jq      ：JSON 操作（frontmatter / schema 解析）
#    - git     ：sha 提取、分支查询（sync/scan --diff 必备）
#    - ajv     ：JSON Schema 编译与校验（守护 frontmatter.schema.json）
#
#  可选（缺失 → 退化路径，exit 2 但脚本自身仍 OK）：
#    - yq                   ：YAML 命令行（首选 state-machine / thresholds 解析）
#    - python3 + pyyaml     ：YAML 解析（yq 不在时退化使用）
#    - ruby + yaml stdlib   ：YAML 解析（python pyyaml 也不在时最终 fallback）
#    - sha256sum / shasum   ：文件指纹（任一即可，macOS 默认仅 shasum）
#
#  退出码：
#    0 = 全部 OK（必需 + 可选）
#    1 = 缺必需依赖
#    2 = 必需 OK，可选缺失（脚本可降级运行）
#
#  最后一行机器可解析输出：RESULT: ok | degraded | fail
#  ----------------------------------------------------------------------------
#  单一权威源：依赖清单只在本文件维护，SKILL.md / references 仅引用。
#  ============================================================================

set -uo pipefail

# 颜色（仅当 stdout 是 tty 时启用）
if [ -t 1 ]; then
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_DIM=$'\033[2m'
  C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_DIM=""; C_RESET=""
fi

ok()   { printf "  %s✓%s %s\n" "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf "  %s!%s %s%s\n" "$C_YELLOW" "$C_RESET" "$1" "${2:+ ${C_DIM}($2)${C_RESET}}"; }
fail() { printf "  %s✗%s %s%s\n" "$C_RED" "$C_RESET" "$1" "${2:+ ${C_DIM}($2)${C_RESET}}"; }

# 检查可执行命令是否存在；可选附加版本检查命令（参数 2）
# 参数：name [version_cmd] [min_version]
have() {
  command -v "$1" >/dev/null 2>&1
}

# 提取版本号（best-effort，失败/异常输出统一返回空，避免污染日志）
ver_of() {
  local bin="$1" arg="${2:---version}" out=""
  command -v "$bin" >/dev/null 2>&1 || { echo ""; return; }
  out=$("$bin" "$arg" 2>/dev/null | head -n 1 | tr -d '\n' || true)
  # 过滤明显的错误信息（含 "error" / "unknown" / "usage"）
  case "$out" in
    *error*|*Error*|*ERROR*|*unknown*|*Unknown*|*Usage:*|*usage:*) out="" ;;
  esac
  printf '%s' "$out"
}

REQUIRED_MISSING=0
OPTIONAL_MISSING=0

printf "\n%s[knowledge-loop] precheck: dependencies%s\n" "$C_DIM" "$C_RESET"
printf "%s%s%s\n" "$C_DIM" "============================================" "$C_RESET"

printf "\nRequired:\n"
for bin in jq git ajv; do
  if have "$bin"; then
    ok "$bin $(ver_of "$bin" --version)"
  else
    fail "$bin" "missing — install via: brew install $bin"
    REQUIRED_MISSING=$((REQUIRED_MISSING + 1))
  fi
done

printf "\nOptional (YAML parsing, prefer in order yq → python3-pyyaml → ruby-yaml):\n"
YAML_BACKEND=""
if have yq; then
  ok "yq $(ver_of yq --version)"
  YAML_BACKEND="yq"
else
  warn "yq not found" "install via: brew install yq"
  if have python3 && python3 -c "import yaml" >/dev/null 2>&1; then
    ok "python3 + pyyaml $(python3 -c 'import yaml; print(yaml.__version__)' 2>/dev/null)"
    YAML_BACKEND="python3-pyyaml"
  elif have ruby && ruby -ryaml -e '' >/dev/null 2>&1; then
    ok "ruby + yaml stdlib $(ruby -e 'puts RUBY_VERSION' 2>/dev/null)"
    YAML_BACKEND="ruby-yaml"
  else
    fail "no YAML parser available" "install one of: brew install yq | pip3 install pyyaml"
    OPTIONAL_MISSING=$((OPTIONAL_MISSING + 1))
  fi
fi

printf "\nOptional (file fingerprinting, either is fine):\n"
HASH_BACKEND=""
if have sha256sum; then
  ok "sha256sum"
  HASH_BACKEND="sha256sum"
elif have shasum; then
  ok "shasum (macOS default)"
  HASH_BACKEND="shasum"
else
  warn "no hash tool found" "install via: brew install coreutils"
  OPTIONAL_MISSING=$((OPTIONAL_MISSING + 1))
fi

printf "\nOptional (Python for advanced lints):\n"
if have python3; then
  ok "python3 $(python3 --version 2>&1)"
else
  warn "python3 not found" "some lints may degrade"
  OPTIONAL_MISSING=$((OPTIONAL_MISSING + 1))
fi

# ----------------------------------------------------------------------------
# 总结 + 机器可解析摘要
# ----------------------------------------------------------------------------
printf "\n%s%s%s\n" "$C_DIM" "============================================" "$C_RESET"
printf "Backends: yaml=%s, hash=%s\n" "${YAML_BACKEND:-none}" "${HASH_BACKEND:-none}"

if [ "$REQUIRED_MISSING" -gt 0 ]; then
  printf "%sFAIL%s: %d required tool(s) missing.\n" "$C_RED" "$C_RESET" "$REQUIRED_MISSING"
  echo "RESULT: fail"
  exit 1
elif [ "$OPTIONAL_MISSING" -gt 0 ]; then
  printf "%sDEGRADED%s: %d optional tool(s) missing — fallbacks active.\n" "$C_YELLOW" "$C_RESET" "$OPTIONAL_MISSING"
  echo "RESULT: degraded"
  exit 2
else
  printf "%sOK%s: all dependencies present.\n" "$C_GREEN" "$C_RESET"
  echo "RESULT: ok"
  exit 0
fi
