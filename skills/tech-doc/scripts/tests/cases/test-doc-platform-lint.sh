#!/bin/bash
# test-doc-platform-lint.sh — doc-platform-lint.sh 的黑盒测试
#
# 覆盖：
#   - 8 项检查的正反场景（含 check #8 title_format_valid）
#   - 文档类型路由（tech-sharing / release-doc 仅跑通用 3 项）
#   - 三种输出模式（json / raw / shell）
#   - 边界场景（代码块 fence 内的 {xxx} 不应误判；锚点链接不应误判 URL）
#
# 用法：bash test-doc-platform-lint.sh
# 退出码：0 全过；1 任一用例失败

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="$SCRIPT_DIR/../../lints/doc-platform-lint.sh"

if [ ! -f "$LINT" ]; then
  echo "❌ 找不到被测脚本: $LINT" >&2
  exit 2
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0
declare -a FAILED_CASES

# 4-8 章占位内容（供用例 4/9/10/16 追加复用，保证"完整合格"测试和"边界场景"测试都有完整 8 章）
# 注：跳过「数据埋点」（模板标记为选填，删除后编号顺延）
# 用例 1 在 heredoc 中已自带四/总体设计，不需要本内容
CH04TO08_CONTENT='
### 四、总体设计

略

### 五、相关接口

| 接口 | 是否已有 | 提供方 | 调用时机 | 调用方式 |
|------|---------|--------|---------|----------|
| 测试接口A | 已有 | 张三 | 调用时 | 直接调用 |

### 六、兼容性问题

略

### 七、风控能力/回滚方案

| 边界点 | 处理方式 |
|--------|----------|
| 边界A | 处理A |

**回滚方案**：略

### 八、测试建议

- [ ] 测试用例A
'

# ========================================
# 测试辅助
# ========================================
run_case() {
  local name="$1"
  local file="$2"
  local expected_exit="$3"
  shift 3
  local actual_exit
  bash "$LINT" "$@" "$file" >/dev/null 2>&1
  actual_exit=$?
  if [ "$actual_exit" = "$expected_exit" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ $name"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name (expected exit=$expected_exit, got=$actual_exit)")
    echo "  ❌ $name (expected exit=$expected_exit, got=$actual_exit)"
  fi
}

# 验证 JSON 输出包含特定字段值
run_case_with_field() {
  local name="$1"
  local file="$2"
  local field="$3"
  local expected_value="$4"
  shift 4
  local output
  output=$(bash "$LINT" "$@" "$file" 2>&1)
  # 提取 "field": <value>（不含引号）
  local actual_value
  actual_value=$(echo "$output" | grep -E "\"$field\":" | head -1 | sed -E "s/.*\"$field\":[[:space:]]*([a-zA-Z\"]+).*/\1/" | tr -d '"' | tr -d ',')
  if [ "$actual_value" = "$expected_value" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ $name ($field=$actual_value)"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name ($field expected=$expected_value, got=$actual_value)")
    echo "  ❌ $name ($field expected=$expected_value, got=$actual_value)"
  fi
}

# ========================================
# 用例 1：完整合格的 tech-proposal 文档应通过（2026-07-03 扩为 8 章）
# ========================================
cat > "$TMPDIR/01-clean-tech-proposal.md" <<'EOF'
### 一、需求背景

测试需求背景描述：在账户管理后台新增一个测试设置项，用于验证。

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档（任务平台） | [测试需求](https://tracker.example.com/p/123) | 张三 |
| 后端技术方案 | {后端技术方案链接} | 李四 |
| 前端技术方案 | 本方案开发 | 王五 |

### 二、代码归属模块

| 模块 | 页面名称 | 文件路径 | 核心代码 | 负责人 |
|------|---------|-------------|---------|--------|
| [测试项目](https://git.example.com/proj) | 测试页 | `src/test/index.tsx` | 核心逻辑 | 张三 |

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| 功能A | proj | *待补充设计图* | 描述A |
| 功能B | proj | ![功能B](https://example.com/img.png) | 描述B |

### 四、总体设计

#### 交互逻辑

```mermaid
flowchart TD
  A[开始] --> B{判断节点}
  B -- 是 --> C[处理1]
```

#### 方案详述

略

### 五、相关接口

| 接口 | 是否已有 | 提供方 | 调用时机 | 调用方式 |
|------|---------|--------|---------|----------|
| 测试接口A | 已有 | 张三 | 调用时 | 直接调用 |

### 六、兼容性问题

略

### 七、风控能力/回滚方案

| 边界点 | 处理方式 |
|--------|----------|
| 边界A | 处理A |

**回滚方案**：略

### 八、测试建议

- [ ] 测试用例A
EOF

# ========================================
# 用例 2：含人员占位符 → 应失败
# ========================================
cat > "$TMPDIR/02-people-placeholder.md" <<'EOF'
### 一、需求背景

| 项目 | 负责人 |
|------|--------|
| 需求文档 | {产品负责人} |
| 后端 | {后台开发} |

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF

# ========================================
# 用例 3：含 TBD → 应失败
# ========================================
cat > "$TMPDIR/03-tbd.md" <<'EOF'
### 一、需求背景

| 角色 | 负责人 |
|------|--------|
| PM | TBD |

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF

# ========================================
# 用例 4：链接类占位符（合法）→ 应通过
# ========================================
cat > "$TMPDIR/04-link-placeholder-ok.md" <<'EOF'
### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 后端技术方案 | {后端技术方案链接} | 李四 |
| 测试用例 | {测试用例链接} | 王五 |
| 前端技术方案 | 本方案开发 | 张三 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF
cat >> "$TMPDIR/04-link-placeholder-ok.md" <<EOF
${CH04TO08_CONTENT}
EOF

# ========================================
# 用例 5：非法 URL（缺 https://）→ 应失败
# ========================================
cat > "$TMPDIR/05-invalid-url.md" <<'EOF'
### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](tracker.example.com/p/123) | 张三 |

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF

# ========================================
# 用例 6：章节编号跳号（一→三）→ 应失败
# ========================================
cat > "$TMPDIR/06-section-skip.md" <<'EOF'
### 一、需求背景

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF

# ========================================
# 用例 7：设计图列存在空单元格 → 应失败
# ========================================
cat > "$TMPDIR/07-empty-design.md" <<'EOF'
### 一、需求背景

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p |  | d |
EOF

# ========================================
# 用例 8：含 figma.com 链接但缺设计稿行 → 应失败
# ========================================
cat > "$TMPDIR/08-figma-no-designer-row.md" <<'EOF'
### 一、需求背景

参考 [Figma](https://www.figma.com/file/xyz)。

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF

# ========================================
# 用例 9：含 figma.com 链接 + 设计稿行 → 应通过
# ========================================
cat > "$TMPDIR/09-figma-with-designer-row.md" <<'EOF'
### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |
| 设计稿（Figma） | [设计稿](https://www.figma.com/file/xyz) | 设计师 |
| 前端技术方案 | 本方案开发 | 李四 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF
cat >> "$TMPDIR/09-figma-with-designer-row.md" <<EOF
${CH04TO08_CONTENT}
EOF

# ========================================
# 用例 10：代码块内的 {xxx} 不应误判为占位符
# ========================================
cat > "$TMPDIR/10-code-block-fence.md" <<'EOF'
### 一、需求背景

代码示例：

```typescript
const config = { 产品负责人: 'PM', 后台开发: 'BE' };
const placeholder = `${'{产品负责人}'}`;
```

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |
| 前端技术方案 | 本方案开发 | 李四 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF
cat >> "$TMPDIR/10-code-block-fence.md" <<EOF
${CH04TO08_CONTENT}
EOF

# ========================================
# 用例 11：tech-sharing 文档类型 → section/design 跳过
# ========================================
cat > "$TMPDIR/11-tech-sharing.md" <<'EOF'
## 背景

我们最近在用 React Server Components 做实践，本文分享。

## 实践方案

参考链接：[官方文档](https://react.dev/reference/rsc)
EOF

# ========================================
# 用例 12：release-doc 文档类型 → section/design 跳过
# ========================================
cat > "$TMPDIR/12-release-doc.md" <<'EOF'
## 版本信息

v2.5.0

## 新增功能

- 支持批量导出

## 修复问题

参考 [任务平台](https://tracker.example.com/p/1)
EOF

# ========================================
# 用例 13：tech-sharing 含人员占位符 → 应失败（通用项仍跑）
# ========================================
cat > "$TMPDIR/13-tech-sharing-bad.md" <<'EOF'
## 背景

作者：{产品负责人}
EOF

# ========================================
# 用例 14：raw 模式只返回退出码（不输出 JSON）
# ========================================
# 复用 02 文件做 raw 模式测试

# ========================================
# 用例 15：shell 模式输出可 source 的变量
# ========================================
# 复用 01 文件做 shell 模式测试

# ========================================
# 用例 16：锚点链接 #section 不应被判为非法 URL
# ========================================
cat > "$TMPDIR/16-anchor-link.md" <<'EOF'
### 一、需求背景

详见[第三章](#三页面功能)和[外部](https://example.com)。

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |
| 前端技术方案 | 本方案开发 | 李四 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF
cat >> "$TMPDIR/16-anchor-link.md" <<EOF
${CH04TO08_CONTENT}
EOF

# ========================================
# 用例 17：缺 1 个必填章节（缺六/兼容性问题，编号顺延后）→ 应失败
# ========================================
cat > "$TMPDIR/17-missing-one-chapter.md" <<'EOF'
### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |

### 四、总体设计

略

### 五、相关接口

略

### 七、风控能力/回滚方案

| 边界点 | 处理方式 |
|--------|----------|
| 略 | 略 |

### 八、测试建议

- [ ] 略
EOF

# ========================================
# 用例 18：缺多个必填章节（缺三/页面功能 + 八/测试建议）→ 应失败
# ========================================
cat > "$TMPDIR/18-missing-multi-chapters.md" <<'EOF'
### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |

### 二、代码归属模块

略

### 四、总体设计

略

### 五、相关接口

略

### 六、兼容性问题

略

### 七、风控能力/回滚方案

| 边界点 | 处理方式 |
|--------|----------|
| 略 | 略 |
EOF

# ========================================
# 用例 19：数据埋点选填 + 编号顺延（无六 → 五后跳到六兼容）→ 应通过
# ========================================
cat > "$TMPDIR/19-burial-skip-number-shift.md" <<'EOF'
### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |
| 前端技术方案 | 本方案开发 | 张三 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |

### 四、总体设计

略

### 五、相关接口

略

### 六、兼容性问题

略

### 七、风控能力/回滚方案

| 边界点 | 处理方式 |
|--------|----------|
| 略 | 略 |

### 八、测试建议

- [ ] 略
EOF

# ========================================
# 执行测试
# ========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 doc-platform-lint.sh 黑盒测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "▶ 第 1 组：tech-proposal 6 项检查正反场景"
run_case "01 完整合格 tech-proposal → exit 0"   "$TMPDIR/01-clean-tech-proposal.md"  0
run_case "02 含人员占位符 → exit 1"             "$TMPDIR/02-people-placeholder.md"   1
run_case "03 含 TBD → exit 1"                    "$TMPDIR/03-tbd.md"                  1
run_case "04 链接类占位符合法 → exit 0"          "$TMPDIR/04-link-placeholder-ok.md"  0
run_case "05 非法 URL（缺 https://）→ exit 1"   "$TMPDIR/05-invalid-url.md"          1
run_case "06 章节编号跳号 → exit 1"              "$TMPDIR/06-section-skip.md"         1
run_case "07 设计图列空单元格 → exit 1"          "$TMPDIR/07-empty-design.md"         1
run_case "08 含 figma 缺设计稿行 → exit 1"      "$TMPDIR/08-figma-no-designer-row.md" 1
run_case "09 含 figma + 设计稿行齐全 → exit 0"  "$TMPDIR/09-figma-with-designer-row.md" 0

echo ""
echo "▶ 第 2 组：边界场景"
run_case "10 代码块内 {xxx} 不误判 → exit 0"    "$TMPDIR/10-code-block-fence.md"     0
run_case "16 锚点链接 #section 不误判 → exit 0" "$TMPDIR/16-anchor-link.md"          0

echo ""
echo "▶ 第 3 组：文档类型路由（tech-sharing / release-doc 跳过 3 项）"
run_case "11 tech-sharing 合格 → exit 0"   "$TMPDIR/11-tech-sharing.md"  0  --doc-type tech-sharing
run_case "12 release-doc 合格 → exit 0"    "$TMPDIR/12-release-doc.md"   0  --doc-type release-doc
run_case "13 tech-sharing 含占位符 → exit 1" "$TMPDIR/13-tech-sharing-bad.md" 1  --doc-type tech-sharing
# 文档类型字段验证
run_case_with_field "11.b tech-sharing JSON 中 section_numbering=skipped" \
  "$TMPDIR/11-tech-sharing.md" "section_numbering" "skipped" --doc-type tech-sharing

echo ""
echo "▶ 第 4 组：输出模式"
# raw 模式：只看退出码，无 stdout
RAW_OUTPUT=$(bash "$LINT" --raw "$TMPDIR/02-people-placeholder.md" 2>/dev/null)
RAW_EXIT=$?
if [ "$RAW_EXIT" = "1" ] && [ -z "$RAW_OUTPUT" ]; then
  PASS=$((PASS + 1))
  echo "  ✅ 14 raw 模式：失败时退出码 1 且无 stdout"
else
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("14 raw 模式异常 (exit=$RAW_EXIT, output='$RAW_OUTPUT')")
  echo "  ❌ 14 raw 模式异常 (exit=$RAW_EXIT, output='$RAW_OUTPUT')"
fi

# shell 模式：检查输出含 doc_platform_lint_placeholder_clean=true
SHELL_OUTPUT=$(bash "$LINT" --shell "$TMPDIR/01-clean-tech-proposal.md" 2>/dev/null)
if echo "$SHELL_OUTPUT" | grep -qE '^doc_platform_lint_placeholder_clean=true$'; then
  PASS=$((PASS + 1))
  echo "  ✅ 15 shell 模式：输出 doc_platform_lint_placeholder_clean=true"
else
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("15 shell 模式输出不符: '$SHELL_OUTPUT'")
  echo "  ❌ 15 shell 模式输出不符"
  echo "     实际: $SHELL_OUTPUT"
fi

echo ""
echo "▶ 第 5 组：章节完整性（required_chapters，2026-07-03 新增）"
run_case "17 缺 1 个必填章节 → exit 1"     "$TMPDIR/17-missing-one-chapter.md"    1
run_case "18 缺多个必填章节 → exit 1"      "$TMPDIR/18-missing-multi-chapters.md" 1
run_case "19 数据埋点选填编号顺延 → exit 0" "$TMPDIR/19-burial-skip-number-shift.md" 0

# ========================================
# 第 6 组：body 不含标题行校验（no_body_title，2026-07-07 新增）8 用例
# 设计：文档平台 通过 title 参数管理标题，body 不应重复 # 标题行
# ========================================
echo ""
echo "▶ 第 6 组：body 标题行校验（no_body_title）"

# tech-proposal 正例：无 # 标题行，直接以 ### 开头
cat > "$TMPDIR/20-body-no-title-ok.md" <<'EOF'
### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |
| 前端技术方案 | 本方案开发 | 李四 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF
cat >> "$TMPDIR/20-body-no-title-ok.md" <<EOF
${CH04TO08_CONTENT}
EOF
run_case "20 无 # 标题行 → exit 0" "$TMPDIR/20-body-no-title-ok.md" 0

# tech-proposal 反例：body 含 # 标题行（违规，文档平台 会重复显示）
cat > "$TMPDIR/21-body-has-title.md" <<'EOF'
# 【详情页】invite_token 参数透传

### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |
| 前端技术方案 | 本方案开发 | 李四 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF
cat >> "$TMPDIR/21-body-has-title.md" <<EOF
${CH04TO08_CONTENT}
EOF
run_case "21 body 含 # 标题行 → exit 1" "$TMPDIR/21-body-has-title.md" 1

# tech-proposal 反例：body 含 # 标题行（短前缀变体）
cat > "$TMPDIR/22-body-has-title-short.md" <<'EOF'
# 【Web】短前缀标题

### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |
| 前端技术方案 | 本方案开发 | 李四 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF
cat >> "$TMPDIR/22-body-has-title-short.md" <<EOF
${CH04TO08_CONTENT}
EOF
run_case "22 body 含 # 标题行（短前缀）→ exit 1" "$TMPDIR/22-body-has-title-short.md" 1

# tech-proposal 正例：空行开头后跟 ###
cat > "$TMPDIR/23-body-blank-then-section.md" <<'EOF'

### 一、需求背景

| 项目 | 说明/地址 | 负责人 |
|------|----------|--------|
| 需求文档 | [任务平台](https://tracker.example.com/p/1) | 张三 |
| 前端技术方案 | 本方案开发 | 李四 |

### 二、代码归属模块

略

### 三、页面功能

| 功能点 | 项目 | 设计图 | 说明 |
|--------|------|--------|------|
| A | p | *待补充设计图* | d |
EOF
cat >> "$TMPDIR/23-body-blank-then-section.md" <<EOF
${CH04TO08_CONTENT}
EOF
run_case "23 空行开头 + ### → exit 0" "$TMPDIR/23-body-blank-then-section.md" 0

# release-doc 正例：无 # 标题行
cat > "$TMPDIR/24-release-no-title.md" <<'EOF'
## 版本信息
v2.5.0
EOF
run_case "24 release-doc 无 # 标题行 → exit 0" "$TMPDIR/24-release-no-title.md" 0  --doc-type release-doc

# release-doc 反例：body 含 # 标题行
cat > "$TMPDIR/25-release-has-title.md" <<'EOF'
# 【详情页面】v2.5.0 发布说明

## 版本信息
v2.5.0
EOF
run_case "25 release-doc body 含 # 标题行 → exit 1" "$TMPDIR/25-release-has-title.md" 1  --doc-type release-doc

# tech-sharing 正例：无 # 标题行
cat > "$TMPDIR/26-sharing-no-title.md" <<'EOF'
## 背景
分享内容
EOF
run_case "26 tech-sharing 无 # 标题行 → exit 0" "$TMPDIR/26-sharing-no-title.md" 0  --doc-type tech-sharing

# tech-sharing 反例：body 含 # 标题行
cat > "$TMPDIR/27-sharing-has-title.md" <<'EOF'
# 分享主题标题

## 背景
分享内容
EOF
run_case "27 tech-sharing body 含 # 标题行 → exit 1" "$TMPDIR/27-sharing-has-title.md" 1  --doc-type tech-sharing

# ========================================
# 汇总
# ========================================
TOTAL=$((PASS + FAIL))
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 测试结果"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  总用例: $TOTAL"
echo "  ✅ 通过: $PASS"
echo "  ❌ 失败: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "失败用例："
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi

echo "🎉 全部用例通过"
exit 0
