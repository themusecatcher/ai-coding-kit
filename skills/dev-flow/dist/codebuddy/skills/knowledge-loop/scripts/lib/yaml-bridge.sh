#!/usr/bin/env bash
# ============================================================================
#  yaml-bridge.sh — YAML / Markdown frontmatter 解析 → JSON 桥接
#  ----------------------------------------------------------------------------
#  作用：为 knowledge-loop 全部 lib/lints/tests 脚本提供「读 YAML 文件 →
#        stdout 单行 compact JSON」的唯一入口。封装 yq / python3-pyyaml /
#        ruby-yaml 三档 backend 自动选择，调用方无需关心。
#  ----------------------------------------------------------------------------
#  消费方：
#    - scripts/lib/score.sh           （读 thresholds.yaml）
#    - scripts/lib/state.sh           （读 state-machine.yaml）
#    - scripts/lints/check-frontmatter.sh （提取 markdown frontmatter）
#    - scripts/lints/check-state.sh   （Phase 3）
#  ----------------------------------------------------------------------------
#  约束（与 check-deps.sh 单一权威源对齐）：
#    - yq / python3-pyyaml / ruby-yaml 三档优先级、可用性判定保持一致
#    - 任一可用即返回 0；全部不可用返回 2（degraded：调用方可决定 fallback）
#  ----------------------------------------------------------------------------
#  暴露的子命令：
#    yaml_to_json <yaml_file>           完整 yaml 转 JSON（compact 单行）
#    frontmatter_to_json <md_file>      抽取 markdown 头部 --- yaml --- 块转 JSON
#    detect_yaml_backend                打印当前可用 backend 名（yq/python3-pyyaml/ruby-yaml/none）
#  ----------------------------------------------------------------------------
#  退出码：
#    0 = ok
#    1 = 输入文件错误（不存在 / 不可读 / frontmatter 缺失）
#    2 = 无可用 YAML backend（全部 fallback 失败）
#    3 = backend 解析 yaml 失败（语法错误等）
#  ============================================================================

set -uo pipefail

# ----------------------------------------------------------------------------
# 依赖探测（与 check-deps.sh 等价）
# ----------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

detect_yaml_backend() {
  if have yq; then
    echo "yq"; return 0
  fi
  if have python3 && python3 -c "import yaml" >/dev/null 2>&1; then
    echo "python3-pyyaml"; return 0
  fi
  if have ruby && ruby -ryaml -e "" >/dev/null 2>&1; then
    echo "ruby-yaml"; return 0
  fi
  echo "none"; return 2
}

# ----------------------------------------------------------------------------
# yaml_to_json <yaml_file>
#   读取 yaml 文件，stdout 输出 compact 单行 JSON（无尾换行）。
#   失败时 stderr 给出原因，按上文退出码返回。
# ----------------------------------------------------------------------------
yaml_to_json() {
  local f="${1:-}"
  if [ -z "$f" ] || [ ! -r "$f" ]; then
    echo "yaml-bridge: file not readable: ${f:-<empty>}" >&2
    return 1
  fi
  local backend
  backend=$(detect_yaml_backend)
  case "$backend" in
    yq)
      # yq 4.x：-o=json 输出 JSON；-I=0 关闭缩进得到 compact
      yq -o=json -I=0 eval "." "$f" 2>/tmp/yaml-bridge.err
      local rc=$?
      if [ $rc -ne 0 ]; then
        echo "yaml-bridge[yq]: parse failed: $(cat /tmp/yaml-bridge.err 2>/dev/null)" >&2
        return 3
      fi
      return 0
      ;;
    python3-pyyaml)
      python3 -c "import sys, json, yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1])), separators=(\",\",\":\"), ensure_ascii=False))" "$f" 2>/tmp/yaml-bridge.err
      local rc=$?
      [ $rc -eq 0 ] && return 0
      echo "yaml-bridge[python3-pyyaml]: parse failed: $(cat /tmp/yaml-bridge.err 2>/dev/null)" >&2
      return 3
      ;;
    ruby-yaml)
      ruby -ryaml -rjson -rdate -e "puts YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Symbol, Date, Time]).to_json" "$f" 2>/tmp/yaml-bridge.err
      local rc=$?
      [ $rc -eq 0 ] && return 0
      echo "yaml-bridge[ruby-yaml]: parse failed: $(cat /tmp/yaml-bridge.err 2>/dev/null)" >&2
      return 3
      ;;
    *)
      echo "yaml-bridge: no YAML backend available (need yq | python3-pyyaml | ruby-yaml)" >&2
      return 2
      ;;
  esac
}

# ----------------------------------------------------------------------------
# frontmatter_to_json <md_file>
#   抽取 markdown 文件头部 --- ... --- 之间的 YAML frontmatter，转 JSON。
#   要求：第一行必须是 `---`；遇到第二个 `---` 结束。
#   失败时 stderr 报错，return 1（无 frontmatter 或不可读）/ 3（解析错）。
# ----------------------------------------------------------------------------
frontmatter_to_json() {
  local md="${1:-}"
  if [ -z "$md" ] || [ ! -r "$md" ]; then
    echo "yaml-bridge: file not readable: ${md:-<empty>}" >&2
    return 1
  fi
  # 用 awk 抽取 ---...--- 之间的 yaml 块（首块）；首行必须是 ---
  local tmp
  tmp=$(mktemp -t yaml-bridge-fm.XXXXXX) || { echo "yaml-bridge: mktemp failed" >&2; return 1; }
  awk 'BEGIN{state=0} {
    if (NR==1) {
      if ($0 != "---") { exit 2 }
      state=1; next
    }
    if (state==1 && $0 == "---") { exit 0 }
    if (state==1) print $0
  }' "$md" > "$tmp"
  local awk_rc=$?
  if [ $awk_rc -eq 2 ]; then
    rm -f "$tmp"
    echo "yaml-bridge: no frontmatter (file does not start with ---): $md" >&2
    return 1
  fi
  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    echo "yaml-bridge: empty frontmatter block: $md" >&2
    return 1
  fi
  yaml_to_json "$tmp"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# ----------------------------------------------------------------------------
# CLI 入口（被 source 时不执行）
# ----------------------------------------------------------------------------
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cmd="${1:-}"
  case "$cmd" in
    yaml_to_json)         shift; yaml_to_json "$@" ;;
    frontmatter_to_json)  shift; frontmatter_to_json "$@" ;;
    detect_yaml_backend)  detect_yaml_backend ;;
    "")  echo "usage: $0 {yaml_to_json|frontmatter_to_json|detect_yaml_backend} [file]" >&2; exit 1 ;;
    *)   echo "yaml-bridge: unknown subcommand: $cmd" >&2; exit 1 ;;
  esac
fi

