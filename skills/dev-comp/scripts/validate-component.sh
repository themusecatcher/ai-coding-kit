#!/bin/bash
# ============================================================
# validate-component.sh - dev-comp 阶段 5 收尾轻量校验脚本
#
# 定位：dev-comp 唯一的程序化校验入口（轻量定位：不做 .validated
# 物理锁、不接状态机、不做 gate 链、不做 hooks 自动触发）。
# 把 references/checklists.md §发布前配置项终检（A/B/C/E 类）+
# 提交红线（S 类：S1 git 身份 / S2 分支核对 / S3 commit hash 回填真实性 /
# S4 能力沉淀三件套 / S5 归档双份）中的确定性 grep 检查收拢为单一可执行体，
# 作为 Gate 5 报告「发布前配置项终检」区块的数据来源。
#
# 规则权威源（双向引用，规则变更必须同步改本脚本）：
#   ← references/checklists.md §发布前配置项终检（ID 一一对应）
#   ← references/linkage-map.md §④⑩⑪⑫⑬⑭
#   ← references/flow.md 阶段 5 第 1/4/6 步
#   ← SKILL.md §能力复用索引
#
# 用法：
#   validate-component.sh <组件名> [项目根] [--context <工作上下文.md>]
#   环境变量：VAUI_PROJECT_ROOT 替代参数 2；VAUI_ARTIFACTS_DIR 替代归档兜底目录
#
# 输出：每项 [PASS]/[FAIL]/[WARN]/[SKIP] + 证据行 + 汇总
# 退出码：0=无 FAIL（WARN/SKIP 不阻断）；1=存在 FAIL；2=参数错误
#
# 兼容：macOS bash 3.2（不依赖关联数组 / mapfile）
# ============================================================

set -u

NAME="${1:-}"
ROOT="${2:-${VAUI_PROJECT_ROOT:-$HOME/myGithub/vue-amazing-ui}}"
CTX=""
while [ $# -gt 0 ]; do
  case "$1" in
    --context) CTX="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "用法: validate-component.sh <组件名> [项目根] [--context <工作上下文.md>]" >&2
  exit 2
fi

# 归一化组件名：AutoComplete -> autocomplete（小写、去分隔符）。
# 项目目录命名约定不统一（components/ 全小写连写、src/views/ 驼峰、
# docs/guide/components/ 全小写连写），禁止用 kebab 猜测路径，必须解析真实条目。
LCNAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
FALLBACK="${VAUI_ARTIFACTS_DIR:-$HOME/myGithub/ai-coding-kit/skills/dev-comp/artifacts}"

# resolve_entry <目录>：按归一化名（去 .md 后缀）在该目录下匹配真实条目名，
# 命中输出条目名（可能带 .md 后缀），未命中输出空。
resolve_entry() {
  local dir="$1" p b n
  [ -d "$dir" ] || return 0
  for p in "$dir"/*; do
    [ -e "$p" ] || continue
    b=$(basename "$p")
    n=$(echo "$b" | sed 's/\.md$//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    if [ "$n" = "$LCNAME" ]; then echo "$b"; return 0; fi
  done
  return 0
}

COMP_DIR=$(resolve_entry "$ROOT/components")
VIEW_DIR=$(resolve_entry "$ROOT/src/views")
DOC_ENTRY=$(resolve_entry "$ROOT/docs/guide/components")
DOC_FILE="$ROOT/docs/guide/components/$DOC_ENTRY"

PASS=0; FAIL=0; WARN=0; SKIP=0
ok()   { PASS=$((PASS+1)); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }
warn() { WARN=$((WARN+1)); echo "  [WARN] $1"; }
skip() { SKIP=$((SKIP+1)); echo "  [SKIP] $1"; }
section() { echo; echo "== $1 =="; }

echo "[dev-comp validate] 组件: $NAME | 项目: $ROOT"
[ -d "$ROOT" ] || { echo "[FATAL] 项目根不存在: ${ROOT}（参数 2 或 VAUI_PROJECT_ROOT 指定）" >&2; exit 2; }

# ============================================================
# A · 代码注册链路（对应 checklists.md A1-A5）
# ============================================================
section "A 代码注册链路"

# A1 withInstall + 类型导出
A1_F="$ROOT/components/$COMP_DIR/index.ts"
if [ -n "$COMP_DIR" ] && [ -f "$A1_F" ] && grep -q "withInstall" "$A1_F"; then
  ok "A1 components/$COMP_DIR/index.ts 存在且含 withInstall"
else
  fail "A1 components/ 下未解析到 $NAME 目录或 index.ts 未用 withInstall（目录解析：${COMP_DIR:-未找到}；检查 ${A1_F}）"
fi

# A2 components.ts 两条导出（-i：组件名输入可能小写/驼峰，文件内为 PascalCase）
if grep -qi "default as $NAME" "$ROOT/components/components.ts"; then
  ok "A2 components.ts 组件导出命中（export { default as $NAME }）"
else
  fail "A2 components.ts 缺组件导出：grep 'default as $NAME' components/components.ts"
fi
if grep -qi "Props as ${NAME}Props" "$ROOT/components/components.ts"; then
  ok "A2 components.ts 类型导出命中（export type { Props as ${NAME}Props }）"
else
  fail "A2 components.ts 缺类型导出：grep 'Props as ${NAME}Props' components/components.ts"
fi

# A3 resolver componentsMap 映射 + 字母序
RESOLVER="$ROOT/components/utils/resolver.ts"
A3_OK=0
if grep -qiE "^[[:space:]]+$NAME:[[:space:]]*'" "$RESOLVER" 2>/dev/null; then
  ok "A3 resolver componentsMap 映射命中（$NAME: '...'）"
  A3_OK=1
else
  fail "A3 resolver componentsMap 缺映射：grep '$NAME:' components/utils/resolver.ts"
fi
if [ "$A3_OK" = "1" ]; then
KEYS=$(sed -n '/componentsMap[[:space:]]*=/,/^}/p' "$RESOLVER" 2>/dev/null \
  | grep -E '^[[:space:]]+[A-Za-z][A-Za-z0-9]*:' \
  | sed -E 's/^[[:space:]]+([A-Za-z0-9]+):.*/\1/')
# 字母序做局部检查（前一 key < 当前 key）；项目存在 Row/Col 等按目录分组的
# 特殊条目，全段有序判定会误报，故只查插入位置（乱序为风格问题 → WARN）
PREV=$(echo "$KEYS" | grep -iB1 "^$NAME$" | head -1)
if [ -n "$PREV" ] && [ "$PREV" != "$NAME" ]; then
  # 比较统一转小写，避免 locale 排序对大小写敏感性的差异
  if printf '%s\n%s\n' "$(echo "$PREV" | tr '[:upper:]' '[:lower:]')" "$(echo "$NAME" | tr '[:upper:]' '[:lower:]')" | sort -C 2>/dev/null; then
    ok "A3 字母序 OK（${PREV} < ${NAME}，局部有序）"
  else
    warn "A3 插入位置可能未按字母序（前一 key=${PREV} 当前=${NAME}），请人工核对（linkage-map.md §④ 要求按字母序插入）"
  fi
else
  ok "A3 字母序 OK（${NAME} 为段首条目）"
fi
else
  skip "A3 字母序检查跳过（映射缺失，先修复映射）"
fi

# A4 resolver componentDependencies 与源码 import 对上
if [ -n "$COMP_DIR" ]; then
  # 单双引号两种 import 写法都要覆盖
  DEPS=$(grep -rhoE "from ['\"]components/[^'\"]+['\"]" "$ROOT/components/$COMP_DIR/" 2>/dev/null \
    | grep -vE "^from ['\"]components/utils(/|['\"])" \
    | sed -E "s|from ['\"]components/([^'\"]+)['\"].*|\1|" | sort -u)
else
  DEPS=""
fi
DEP_ENTRY=$(grep -iE "^[[:space:]]+$NAME:[[:space:]]*\[" "$RESOLVER" 2>/dev/null)
if [ -z "$COMP_DIR" ]; then
  skip "A4 组件目录未解析到，跳过依赖核对"
elif [ -z "$DEPS" ]; then
  if [ -n "$DEP_ENTRY" ]; then
    warn "A4 源码无 components/ import，但 resolver 有 ${NAME} 依赖条目（可能冗余：${DEP_ENTRY}）"
  else
    ok "A4 源码无组件间依赖，resolver 无条目（一致）"
  fi
else
  MISSING=""
  for d in $DEPS; do
    # 大小写不敏感：源码 import 路径小写（components/scrollbar），resolver 条目 PascalCase（['Scrollbar']）
    echo "$DEP_ENTRY" | grep -qi "$d" || MISSING="$MISSING $d"
  done
  if [ -n "$DEP_ENTRY" ] && [ -z "$MISSING" ]; then
    ok "A4 componentDependencies 与源码 import 逐一对上（${DEPS}）"
  else
    fail "A4 componentDependencies 缺失依赖:${MISSING:-（条目本身缺失 $NAME: [...]）} 源码 import: $DEPS"
  fi
fi

# A5 自动注册无手改
A5_DIFF=$(git -C "$ROOT" diff HEAD -- components/index.ts src/router/index.ts 2>/dev/null | grep -E '^[+-]' | head -3)
if [ -z "$A5_DIFF" ]; then
  ok "A5 自动注册文件无手改（components/index.ts / router 无 diff）"
else
  fail "A5 自动注册文件有手改痕迹，应依赖 glob 自动扫描：$A5_DIFF"
fi

# ============================================================
# B · 文档联动链路（对应 checklists.md B1-B5）
# ============================================================
section "B 文档联动链路"

if [ -f "$DOC_FILE" ]; then
  ok "B1 组件文档存在：docs/guide/components/${DOC_ENTRY:-未解析}"
else
  fail "B1 组件文档缺失：${DOC_FILE}（目录解析：${DOC_ENTRY:-未找到}）"
fi

if grep -qiE "$NAME|$LCNAME" "$ROOT/docs/.vitepress/config.ts" 2>/dev/null; then
  ok "B2 vitepress 侧边栏入口命中（config.ts）"
else
  fail "B2 vitepress 侧边栏缺入口：grep '$NAME' docs/.vitepress/config.ts"
fi

CHANGELOG="$ROOT/docs/guide/changelog.md"
if grep -qi "$NAME" "$CHANGELOG" 2>/dev/null; then
  ok "B3 changelog 变更记录命中"
else
  fail "B3 changelog 缺变更记录：grep '$NAME' docs/guide/changelog.md"
fi
VER_PKG=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9.]+"' "$ROOT/package.json" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
VER_LOG=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$CHANGELOG" 2>/dev/null | head -1)
if [ -n "$VER_PKG" ] && [ "$VER_PKG" = "$VER_LOG" ]; then
  ok "B3 版本号一致：package.json=$VER_PKG = changelog 顶部=$VER_LOG"
else
  fail "B3 版本号不一致：package.json=${VER_PKG:-?} vs changelog 顶部=${VER_LOG:-?}（新增组件应 minor+1 patch 归 0，见 changelog-spec.md）"
fi

# B4 组件总数 4 处 +1 且一致（兼 E1）
ACTUAL=$(cd "$ROOT" && ls -d components/*/ 2>/dev/null | grep -vE 'components/(style|utils)/' | wc -l | tr -d ' ')
NUMS=""
for f in README.md README.zh-CN.md docs/index.md docs/guide/features.md; do
  n=$(grep -oE '(共包含|includes)[[:space:]]+`?[0-9]+`?' "$ROOT/$f" 2>/dev/null | grep -oE '[0-9]+' | head -1)
  NUMS="$NUMS $n"
done
UNIQ=$(echo "$NUMS" | tr ' ' '\n' | grep -v '^$' | sort -u)
if [ "$(echo "$UNIQ" | wc -l | tr -d ' ')" = "1" ] && [ "$UNIQ" = "$ACTUAL" ]; then
  ok "B4/E1 组件总数 4 处一致且 = 实际组件数 $ACTUAL"
else
  fail "B4/E1 组件总数不一致：4 处数字=[${NUMS}] 实际组件数=${ACTUAL}（详见 linkage-map.md §⑩⑪⑫）"
fi

# B5 API 章节标题四件套
if [ -f "$DOC_FILE" ]; then
  B5_CNT=$(grep -cE '^## (APIs|Events|Slots|Methods)$' "$DOC_FILE" 2>/dev/null)
  B5_EXPOSE=$(grep -cE '^## Expose' "$DOC_FILE" 2>/dev/null)
else
  B5_CNT=0
  B5_EXPOSE=0
fi
if [ "$B5_CNT" = "4" ] && [ "$B5_EXPOSE" = "0" ]; then
  ok "B5 API 章节四件套齐全（APIs/Events/Slots/Methods），无 ## Expose 内部术语"
else
  fail "B5 API 章节四件套不齐：命中 $B5_CNT/4，## Expose 出现 $B5_EXPOSE 次（文档：${DOC_ENTRY:-未解析}）"
fi

# ============================================================
# C · 残留清理（对应 checklists.md C1-C4）
# ============================================================
section "C 残留清理"

# C1 components.d.ts 幽灵声明
CDTS="$ROOT/components.d.ts"
if [ ! -f "$CDTS" ]; then
  skip "C1 components.d.ts 不存在（项目未用 unplugin，跳过）"
else
  GHOST=""
  grep -E "typeof import\('ant-design-vue/es'\)" "$CDTS" 2>/dev/null \
    | sed -E 's/^[[:space:]]*([A-Za-z0-9]+):.*/\1/' \
    | while read -r entry; do
        tag=$(echo "$entry" | sed -E 's/^A//' | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' | tr '[:upper:]' '[:lower:]')
        used=0
        grep -rqiE "<a-$tag([ >/]|$)" "$ROOT/src" "$ROOT/components" "$ROOT/docs" 2>/dev/null && used=1
        grep -rqw "$entry" "$ROOT/src" "$ROOT/components" "$ROOT/docs" 2>/dev/null && used=1
        [ "$used" = "0" ] && echo "$entry"
      done > /tmp/dc-ghost-$$.txt
  GHOST=$(cat /tmp/dc-ghost-$$.txt | tr '\n' ' '); rm -f /tmp/dc-ghost-$$.txt
  if [ -z "$GHOST" ]; then
    ok "C1 components.d.ts 无幽灵声明（antdv 条目均有源码引用）"
  else
    fail "C1 components.d.ts 幽灵声明（源码 0 引用，须删除并随本次 commit 提交）:$GHOST"
  fi
fi

# C2 App.vue 孤儿变量（半确定性：数据流分析，脚本只提示不判定）
skip "C2 App.vue 孤儿变量为数据流分析，请人工 grep 定义 vs 引用（仅本次动了全局 ConfigProvider/主题时检查，详见 linkage-map.md §⑬）"

# C3 演示页对照清除
if [ -n "$VIEW_DIR" ]; then
  DEMO="$ROOT/src/views/$VIEW_DIR/Index.vue"
fi
if [ -n "$VIEW_DIR" ] && [ -f "$DEMO" ]; then
  C3_HIT=$(grep -nE "from 'ant-design-vue'|<a-" "$DEMO" 2>/dev/null | head -3)
  if [ -z "$C3_HIT" ]; then
    ok "C3 演示页对照已清除（无 ant-design-vue import / <a- 真身标签）"
  else
    fail "C3 演示页仍残留 antdv 对照内容：$C3_HIT"
  fi
else
  skip "C3 演示页不存在（src/views/ 解析：${VIEW_DIR:-未找到}）"
fi

# C4 调试代码清理
if [ -n "$COMP_DIR" ]; then
  C4_HIT=$(grep -rnE "console\.(log|debug)" "$ROOT/components/$COMP_DIR/" 2>/dev/null | head -3)
else
  C4_HIT=""
fi
if [ -n "$COMP_DIR" ] && [ -z "$C4_HIT" ]; then
  ok "C4 组件目录无 console.log/debug"
elif [ -n "$COMP_DIR" ]; then
  fail "C4 组件目录残留调试代码：$C4_HIT"
else
  skip "C4 组件目录未解析到，跳过调试代码检查"
fi

# ============================================================
# E · 一致性（E1 已并入 B4；E2 半确定性提示人工）
# ============================================================
section "E 一致性"

skip "E2 演示页↔docs 描述同源为文本语义对比（半确定性），请按 demo-description.md §5 人工 grep 双向核对"

# ============================================================
# S · 提交红线（对应 flow.md 阶段 5 第 4 步 + checklists.md §验收：
# S1 git 身份 / S2 分支核对 / S3 commit hash 回填真实性 /
# S4 能力沉淀三件套 / S5 归档双份）
# ============================================================
section "S 提交红线"

if [ -z "$CTX" ] || [ ! -f "$CTX" ]; then
  skip "S1-S3 需工作上下文（--context {wc 文件}），未提供则跳过 git 身份 / 分支 / hash 校验"
else
  # S1 git 身份实测 vs git_identity
  IDENT=$(sed -n 's/^git_identity: "\(.*\)"/\1/p' "$CTX")
  NAME_ACT=$(git -C "$ROOT" config user.name)
  EMAIL_ACT=$(git -C "$ROOT" config user.email)
  if [ -z "$IDENT" ]; then
    skip "S1 工作上下文无 git_identity 字段（旧模板），跳过身份校验——提交前人工确认 ${NAME_ACT} / ${EMAIL_ACT} 为预期身份"
  else
    NAME_EXP=$(echo "$IDENT" | sed -E 's#[[:space:]]*/.*$##' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    EMAIL_EXP=$(echo "$IDENT" | sed -E 's#^.*/[[:space:]]*##')
    if [ "$NAME_ACT" = "$NAME_EXP" ] && [ "$EMAIL_ACT" = "$EMAIL_EXP" ]; then
      ok "S1 git 身份与 git_identity 一致（${NAME_ACT} / ${EMAIL_ACT}）"
    else
      fail "S1 git 身份不符：实测 [${NAME_ACT} / ${EMAIL_ACT}] vs 预期 [${NAME_EXP} / ${EMAIL_EXP}]（历史事故：误用公司身份提交）"
    fi
  fi

  # S2 当前分支 vs 工作上下文 branch（Gate 5「提交前检查」对应项；分支不符时 S3 hash 对比必然失真，先拦截）
  CTX_BRANCH=$(sed -n 's/^branch: *"\(.*\)"/\1/p' "$CTX")
  CUR_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null)
  if [ -n "$CTX_BRANCH" ] && [ "$CTX_BRANCH" = "$CUR_BRANCH" ]; then
    ok "S2 当前分支与工作上下文一致（${CUR_BRANCH}）"
  elif [ -n "$CTX_BRANCH" ]; then
    fail "S2 当前分支 ${CUR_BRANCH} ≠ 工作上下文 branch ${CTX_BRANCH}（提交前须切换到正确分支，且下列 S3 hash 对比在该状态下失真）"
  else
    skip "S2 工作上下文无 branch 字段，跳过分支核对"
  fi

  # S3 commit hash 回填真实性（frontmatter 有 commit 时才校验；字段可能为 "hash" 或 "hash message"，取首个 token）
  CTX_COMMIT=$(sed -n 's/^commit: "\([^ "]*\).*/\1/p' "$CTX")
  HEAD_HASH=$(git -C "$ROOT" log -1 --format='%h')
  if [ -n "$CTX_COMMIT" ]; then
    if git -C "$ROOT" cat-file -e "${CTX_COMMIT}^{commit}" 2>/dev/null; then
      if [ "$CTX_COMMIT" = "$HEAD_HASH" ]; then
        ok "S3 工作上下文 commit=$CTX_COMMIT 与 HEAD 实测一致"
      else
        warn "S3 工作上下文 commit=$CTX_COMMIT 在仓库存在但 HEAD=$HEAD_HASH 已推进（若 commit 为本次开发提交且 HEAD 含后续提交属正常；若预期 HEAD=commit 请先核对 S2 分支）"
      fi
    else
      fail "S3 工作上下文 commit=$CTX_COMMIT 在仓库中不存在（凭记忆记录的假 hash，禁止回填）"
    fi
  else
    skip "S3 工作上下文 commit 为空（尚未提交），跳过"
  fi
fi

# S4 能力沉淀三件套（两级扫描：运行时目录优先 → FALLBACK 归档兜底；
# 顺序上脚本常跑于沉淀前，缺失 → WARN 提示提交前补齐）
section "S4 能力沉淀三件套"

# devlog 两种可能结构：① tech-doc 规范 {YYYYMMDD}_{类型}_{简述}/devlog.md
# ② dev-comp 早期记载 <项目>/<分支>/devlog.md；按组件归一化名过滤路径。
# 简述纯中文不含组件名时无法自动关联 → 保守报 WARN（人工确认），不误 PASS
DEVLOG_HIT=$(find "$HOME/.codebuddy/dev-logs" -maxdepth 3 -iname "devlog.md" 2>/dev/null \
  | grep -i "$LCNAME" | head -1)
if [ -n "$DEVLOG_HIT" ]; then
  ok "S4 devlog 已存在（${DEVLOG_HIT}）"
else
  AF_DEVLOG=$(find "$FALLBACK" -maxdepth 2 -type d -iname "devlog" 2>/dev/null | grep -i "$LCNAME" | head -1)
  if [ -n "$AF_DEVLOG" ]; then
    warn "S4 devlog 仅存归档副本（${AF_DEVLOG}）——接续时经用户同意复制回运行时目录；已收尾归档则属正常"
  else
    warn "S4 devlog 缺失或简述未含组件名：提交前须 use_skill('tech-doc') 生成（历史事故：三次跳过）"
  fi
fi

METRIC_HIT=$(ls "$HOME/.codebuddy/dev-comp/metrics/" 2>/dev/null | grep -i "$LCNAME" | head -1)
if [ -n "$METRIC_HIT" ]; then
  M_F="$HOME/.codebuddy/dev-comp/metrics/$METRIC_HIT"
  if grep -q "^component:" "$M_F" 2>/dev/null; then
    ok "S4 metrics 已存在且含 component 字段（${M_F}）"
  else
    warn "S4 metrics 文件存在但缺 component 字段：${M_F}"
  fi
else
  AF_METRIC=$(ls "$FALLBACK"/ 2>/dev/null | grep -i "$LCNAME" | head -1)
  if [ -n "$AF_METRIC" ] && [ -d "$FALLBACK/$AF_METRIC/metrics" ] && ls "$FALLBACK/$AF_METRIC/metrics/" 2>/dev/null | grep -qi .; then
    warn "S4 metrics 仅存归档副本（$FALLBACK/$AF_METRIC/metrics/）——接续时经用户同意复制回运行时目录；已收尾归档则属正常"
  else
    warn "S4 metrics 缺失：提交前按 templates/metrics-lite.tpl.yaml 写入 ~/.codebuddy/dev-comp/metrics/"
  fi
fi

KNOW_HIT=$(find "$HOME/.codebuddy/knowledge/vue-amazing-ui" -maxdepth 3 -iname "*$LCNAME*" 2>/dev/null | head -1)
if [ -n "$KNOW_HIT" ]; then
  ok "S4 knowledge 已沉淀（${KNOW_HIT}）"
else
  AF_KNOW=$(ls "$FALLBACK"/ 2>/dev/null | grep -i "$LCNAME" | head -1)
  if [ -n "$AF_KNOW" ] && [ -d "$FALLBACK/$AF_KNOW/knowledge" ] && ls "$FALLBACK/$AF_KNOW/knowledge/" 2>/dev/null | grep -qi .; then
    warn "S4 knowledge 仅存归档副本（$FALLBACK/$AF_KNOW/knowledge/）——接续时经用户同意复制回运行时目录；已收尾归档则属正常"
  else
    warn "S4 knowledge 缺失：提交前须 use_skill('knowledge-loop') 沉淀"
  fi
fi

# S5 产物归档无双份（运行时目录与 artifacts 兜底目录同时存在 → WARN）
section "S5 归档双份"

RT_HIT=$(ls "$HOME/.codebuddy/dev-comp/working-context/" 2>/dev/null | grep -i "$LCNAME" | head -1)
AF_HIT=$(ls "$FALLBACK"/ 2>/dev/null | grep -i "$LCNAME" | head -1)
if [ -n "$RT_HIT" ] && [ -n "$AF_HIT" ]; then
  warn "S5 工作上下文双份：运行时[$RT_HIT] 与 artifacts[$AF_HIT] 同时存在（归档后应删运行时副本，禁止长期双份）"
elif [ -n "$RT_HIT" ] || [ -n "$AF_HIT" ]; then
  ok "S5 工作上下文单一存放（运行时=${RT_HIT:-无} / 归档=${AF_HIT:-无}）"
else
  skip "S5 运行时与归档两级均未检索到工作上下文（组件名拼写差异或未建上下文；--context 提供的文件不在两级目录内）"
fi

# ============================================================
# 汇总
# ============================================================
echo
echo "==== 汇总: PASS=$PASS FAIL=$FAIL WARN=$WARN SKIP=$SKIP ===="
if [ "$FAIL" -gt 0 ]; then
  echo "结果: 存在 FAIL，须修复后重跑；WARN 项须在提交前逐一确认"
  exit 1
else
  echo "结果: 无 FAIL（WARN 为提示项，须在提交前逐一确认；SKIP 为半确定性/条件性项，须人工核对）"
  exit 0
fi
