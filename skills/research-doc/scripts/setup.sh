#!/bin/bash
# research-doc Skill 依赖安装脚本
# 用法：bash setup.sh

set -e

echo "🔧 检查并安装 research-doc 所需依赖..."

PACKAGES=()

# 检查 python-pptx
python3 -c "import pptx" 2>/dev/null || PACKAGES+=("python-pptx")

# 检查 python-docx
python3 -c "import docx" 2>/dev/null || PACKAGES+=("python-docx")

# 检查 openpyxl
python3 -c "import openpyxl" 2>/dev/null || PACKAGES+=("openpyxl")

# 检查 Jinja2（模板引擎）
python3 -c "import jinja2" 2>/dev/null || PACKAGES+=("Jinja2")

# 检查 Markdown
python3 -c "import markdown" 2>/dev/null || PACKAGES+=("markdown")

if [ ${#PACKAGES[@]} -eq 0 ]; then
  echo "✅ 所有依赖已安装"
else
  echo "📦 需要安装：${PACKAGES[*]}"
  pip3 install --user "${PACKAGES[@]}"
  echo "✅ 依赖安装完成"
fi

# 可选：weasyprint（PDF 生成，安装较重，不强制）
if ! python3 -c "import weasyprint" 2>/dev/null; then
  echo ""
  echo "ℹ️  可选依赖 weasyprint 未安装（用于 HTML→PDF 转换）"
  echo "   如需 PDF 生成功能，请手动执行：pip3 install --user weasyprint"
fi

echo ""
echo "🎉 research-doc Skill 环境就绪"
