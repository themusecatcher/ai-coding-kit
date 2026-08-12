#!/usr/bin/env python3
"""
为 ai-coding-kit 仓库生成 CodeBuddy 市场源所需的：
1) 根目录 .codebuddy-plugin/marketplace.json
2) 每个 skill 目录下的 plugin.json

数据来源：每个 skills/<name>/SKILL.md 头部的 YAML frontmatter（name + description）。
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
MARKETPLACE_DIR = ROOT / ".codebuddy-plugin"

MARKET_NAME = "skillhub"
MARKET_DESCRIPTION = "个人 Skill 集合，包含 dev-flow、code-review、smart-commit 等研发效能工具"
MARKET_VERSION = "1.0.0"
OWNER = {"name": "", "email": ""}
DEFAULT_AUTHOR = {"name": ""}
DEFAULT_CATEGORY = "productivity"


def parse_frontmatter(skill_md: Path):
    """从 SKILL.md 顶部 YAML frontmatter 提取 name 和 description。"""
    text = skill_md.read_text(encoding="utf-8")
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return None, None
    fm = m.group(1)
    name_m = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
    name = name_m.group(1).strip().strip('"').strip("'") if name_m else None

    # description 可能是多种 YAML 格式：
    # 1) 单行: description: 一些文字
    # 2) 多行块: description: |  或 description: >
    # 3) 多行续行: description:\n  缩进行（无 | 或 >）
    description = ""
    desc_m = re.search(r"^description:\s*(.*)$", fm, re.MULTILINE)
    if desc_m:
        first_line = desc_m.group(1).strip()
        # 找到 description: 之后的所有缩进行
        rest_start = desc_m.end()
        rest_text = fm[rest_start:]
        # 收集后续缩进行（以空格开头的行）
        indented_lines = []
        for line in rest_text.split("\n"):
            if line and (line[0] == " " or line[0] == "\t"):
                indented_lines.append(line.strip())
            elif line.strip() == "":
                continue  # 跳过空行
            else:
                break  # 遇到非缩进行则停止

        if first_line in ("|", ">", "|+", ">+", "|-", ">-"):
            # 块标量，内容全在缩进行
            raw = " ".join(indented_lines)
        elif first_line:
            # 单行或首行有内容 + 后续缩进续行
            all_parts = [first_line] + indented_lines
            raw = " ".join(all_parts)
        else:
            # description: 后面直接换行，内容在缩进行
            raw = " ".join(indented_lines)

        description = raw.strip().strip('"').strip("'")
    return name, description


def truncate(text: str, limit: int = 200) -> str:
    """市场清单里的描述做长度截断，避免太长。"""
    if not text:
        return ""
    return text if len(text) <= limit else text[: limit - 1] + "…"


def build_keywords(slug: str) -> list:
    """简单基于 slug 拆分关键词。"""
    return [w for w in re.split(r"[-_]+", slug) if w]


def is_low_quality_description(name: str, description: str) -> bool:
    """检测描述是否为低质量占位符。"""
    if not description:
        return True
    # 匹配 "{name} skill" 这类占位模式
    if re.match(r"^[\w-]+\s+skill$", description, re.IGNORECASE):
        return True
    # 描述太短（少于 10 个字符）
    if len(description) < 10:
        return True
    return False


def main():
    plugins_meta = []
    skipped = []
    warnings = []

    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            skipped.append(skill_dir.name)
            continue

        name_in_fm, description = parse_frontmatter(skill_md)
        slug = skill_dir.name
        # 优先用 frontmatter 里的 name；否则用目录名
        plugin_name = name_in_fm or slug
        if not description:
            description = f"{plugin_name} skill"

        # 校验 description 质量
        if is_low_quality_description(plugin_name, description):
            warnings.append(
                f"  ⚠️  {slug}: description 为低质量占位符 \"{description}\"\n"
                f"      → 请在 skills/{slug}/SKILL.md frontmatter 中补充完整的中文描述"
            )

        # 1) 写入 skills/<slug>/plugin.json
        plugin_json = {
            "name": plugin_name,
            "version": "1.0.0",
            "description": description,
            "author": DEFAULT_AUTHOR,
            "keywords": build_keywords(slug),
            "category": DEFAULT_CATEGORY,
            "skills": ["./SKILL.md"],
        }
        (skill_dir / "plugin.json").write_text(
            json.dumps(plugin_json, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        # 2) 收集到 marketplace.json
        plugins_meta.append({
            "name": plugin_name,
            "source": f"skills/{slug}",
            "description": truncate(description, 200),
            "version": "1.0.0",
            "author": DEFAULT_AUTHOR,
            "keywords": build_keywords(slug),
            "category": DEFAULT_CATEGORY,
            "strict": False,
        })

    # 3) 写入根 .codebuddy-plugin/marketplace.json
    MARKETPLACE_DIR.mkdir(exist_ok=True)
    marketplace = {
        "name": MARKET_NAME,
        "description": MARKET_DESCRIPTION,
        "version": MARKET_VERSION,
        "owner": OWNER,
        "plugins": plugins_meta,
    }
    (MARKETPLACE_DIR / "marketplace.json").write_text(
        json.dumps(marketplace, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"✅ Generated {len(plugins_meta)} plugin.json files")
    if skipped:
        print(f"⏭️  Skipped (no SKILL.md): {skipped}")
    print(f"📦 Marketplace: {MARKETPLACE_DIR / 'marketplace.json'}")

    # 校验报告
    if warnings:
        print(f"\n{'='*60}")
        print(f"❌ 发现 {len(warnings)} 个 skill 的 description 不合格：")
        print(f"{'='*60}")
        for w in warnings:
            print(w)
        print(f"{'='*60}")
        print("请修复上述 SKILL.md 的 frontmatter description 后重新生成。")
        sys.exit(1)
    else:
        print("✅ 所有 plugin description 校验通过")


if __name__ == "__main__":
    main()
