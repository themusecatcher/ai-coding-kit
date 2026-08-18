#!/usr/bin/env python3
"""
为 ai-coding-kit 仓库生成 CodeBuddy 市场源所需的：
1) 根目录 .codebuddy-plugin/marketplace.json
2) 每个 skill 目录下 .codebuddy-plugin/plugin.json

数据来源：每个 skills/<name>/SKILL.md 头部的 YAML frontmatter。
支持字段：name, description, category, keywords（均可在 frontmatter 中覆盖自动检测）。

用法：
  python3 scripts/generate_marketplace.py            # 生成（默认）
  python3 scripts/generate_marketplace.py --check    # 只校验磁盘元数据是否与 frontmatter 一致，不写入
  npm run mp:check                                   # 同上（npm 快捷方式）

说明：CodeBuddy 插件市场规范要求插件清单位于 <plugin>/.codebuddy-plugin/plugin.json，
且不声明 skills 字段（由系统自动发现 plugin 根的平铺 SKILL.md，技能名取 frontmatter name）。
历史版本把清单生成在 skills/<name>/plugin.json 平铺位置且 skills 字段指向文件，
导致插件市场安装后无法识别技能。旧产物需手动删除：
  find skills -maxdepth 2 -name plugin.json -delete
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
MARKETPLACE_DIR = ROOT / ".codebuddy-plugin"

MARKET_NAME = "ai-coding-kit"
MARKET_DESCRIPTION = "个人 Skill 集合，包含 dev-flow、code-review、smart-commit 等研发效能工具"
MARKET_VERSION = "1.0.0"
DEFAULT_CATEGORY = "productivity"


def get_author_info() -> tuple[str, str]:
    """获取作者名字和邮箱，优先级：org.yaml > git config > 环境变量 > 空字符串。

    返回 (name, email)。"""
    name = ""
    email = ""

    # 1) 从 org.yaml 逐行读取（精确匹配，避免注释被误读为值）
    config_path = ROOT / "config" / "org.yaml"
    if config_path.exists():
        try:
            for line in config_path.read_text(encoding="utf-8").splitlines():
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    continue
                # user_name: "value" — 提取双引号内的值，排除注释和长字符串
                m = re.match(r'^user_name:\s*"(.+?)"', stripped)
                if m:
                    raw = m.group(1).strip()
                    if raw and "#" not in raw and len(raw) <= 50:
                        name = raw
                    continue
                # org_email_domain: "value"
                m = re.match(r'^org_email_domain:\s*"(.+?)"', stripped)
                if m:
                    raw = m.group(1).strip()
                    if raw and "#" not in raw and "." in raw and "@" not in raw \
                            and raw != "example.com" and len(raw) <= 50:
                        email = f"{name}@{raw}" if name else raw
        except Exception:
            pass

    # 2) 从 git config 读取
    if not name:
        try:
            name = subprocess.check_output(
                ["git", "config", "user.name"], text=True, stderr=subprocess.DEVNULL
            ).strip()
        except Exception:
            pass
    if not email:
        try:
            email = subprocess.check_output(
                ["git", "config", "user.email"], text=True, stderr=subprocess.DEVNULL
            ).strip()
        except Exception:
            pass

    # 3) 从环境变量读取
    if not name:
        name = os.environ.get("GIT_AUTHOR_NAME", "") or os.environ.get("USER", "")
    if not email:
        email = os.environ.get("GIT_AUTHOR_EMAIL", "")

    return name, email


# 在模块加载时获取一次，整个脚本共用
_AUTHOR_NAME, _AUTHOR_EMAIL = get_author_info()
OWNER = {"name": _AUTHOR_NAME, "email": _AUTHOR_EMAIL}
DEFAULT_AUTHOR = {"name": _AUTHOR_NAME}

# 分类检测关键词映射（按优先级排序，同分时靠前者优先）
CATEGORY_RULES = [
    ("browser", ["浏览器自动化", "网页交互", "页面导航", "表单填写",
                  "浏览器自动化 CLI", "browser automation", "浏览器兼容"]),
    ("frontend", ["前端开发", "React", "Next.js", "DOM 定位", "CSS 动画",
                   "国际化翻译", "i18n", "多语言资源", "前端开发模式"]),
    ("testing", ["端到端测试", "e2e testing", "Playwright", "验证管线", "验证系统",
                  "自动化验证", "质量保证"]),
    ("docs", ["文档生成", "PPT", "PDF 全能", "Word", "Excel", "开发日志",
              "技术方案文档", "资料搜索", "外网资料", "文档处理"]),
    ("quality", ["代码审查", "编码规范", "复杂度", "安全审查", "code review",
                  "安全检查", "最佳实践"]),
    ("dev-tools", ["开发工作流", "commit message", "先搜索后编码", "AI Agent",
                    "CLI 工具", "发现技能", "安装技能", "智能 Commit", "AI 辅助编程"]),
    ("requirements", ["需求输入", "方案分析", "Figma", "避坑指南", "需求理解"]),
    ("knowledge", ["知识沉淀", "学习系统", "经验回顾", "本能", "规则质量"]),
    ("troubleshooting", ["根因定位", "调用链追溯", "问题深度"]),
]

# 弱匹配词（单字或通用词，在无强匹配时才计入，避免误分类）
WEAK_CATEGORY_KEYWORDS = {
    "browser": ["浏览器", "browser", "截图"],
    "frontend": ["前端", "DOM", "动画", "CSS", "国际化", "翻译 key", "样式"],
    "testing": ["验证", "e2e"],
    "docs": ["文档", ".pptx", ".pdf", ".docx", "devlog"],
    "quality": ["安全模式"],
    "dev-tools": ["commit", "提交信息"],
    "requirements": ["设计稿", "Figma 设计"],
    "knowledge": ["知识", "学习", "经验", "记忆"],
    "troubleshooting": ["根因", "追溯", "定位", "调用链"],
}


def parse_frontmatter(skill_md: Path):
    """从 SKILL.md 顶部 YAML frontmatter 提取字段。
    返回 (name, description, category, keywords, author)，各字段可为 None 表示未定义。"""
    text = skill_md.read_text(encoding="utf-8")
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return None, None, None, None, None
    fm = m.group(1)

    name_m = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
    name = name_m.group(1).strip().strip('"').strip("'") if name_m else None

    # description（支持单行/多行块/缩进续行）
    description = _parse_description(fm)

    # category
    cat_m = re.search(r"^category:\s*(.+)$", fm, re.MULTILINE)
    category = cat_m.group(1).strip().strip('"').strip("'") if cat_m else None

    # keywords（支持 YAML 流式列表 [a, b] 和块式列表 - a \n - b）
    keywords = _parse_keywords_from_frontmatter(fm)

    # author（单个字符串，如 "name <email>" 或纯 name）
    author = None
    author_m = re.search(r"^author:\s*(.+)$", fm, re.MULTILINE)
    if author_m:
        author_raw = author_m.group(1).strip().strip('"').strip("'")
        if author_raw and author_raw != "ECC":
            author = author_raw

    return name, description, category, keywords, author


def _parse_description(fm: str) -> str:
    """从 frontmatter 文本中解析 description 字段。"""
    desc_m = re.search(r"^description:\s*(.*)$", fm, re.MULTILINE)
    if not desc_m:
        return ""

    first_line = desc_m.group(1).strip()
    rest_start = desc_m.end()
    rest_text = fm[rest_start:]

    indented_lines = []
    for line in rest_text.split("\n"):
        if line and (line[0] == " " or line[0] == "\t"):
            indented_lines.append(line.strip())
        elif line.strip() == "":
            continue
        else:
            break

    if first_line in ("|", ">", "|+", ">+", "|-", ">-"):
        raw = " ".join(indented_lines)
    elif first_line:
        all_parts = [first_line] + indented_lines
        raw = " ".join(all_parts)
    else:
        raw = " ".join(indented_lines)

    return raw.strip().strip('"').strip("'")


def _parse_keywords_from_frontmatter(fm: str) -> list | None:
    """从 frontmatter 中解析 keywords 字段。支持两种 YAML 列表格式。"""
    # 流式列表: keywords: [a, b, c]
    kw_block = re.search(r"^keywords:\s*\[(.*?)\]", fm, re.MULTILINE)
    if kw_block:
        kw_text = kw_block.group(1)
        keywords = [k.strip().strip('"').strip("'") for k in kw_text.split(",") if k.strip()]
        return keywords if keywords else None

    # 块式列表: keywords:\n  - a\n  - b
    kw_list_m = re.search(r"^keywords:\s*\n((?:\s+-\s+.+\n?)+)", fm, re.MULTILINE)
    if kw_list_m:
        kw_lines = re.findall(r"^\s+-\s+(.+)$", kw_list_m.group(1), re.MULTILINE)
        keywords = [k.strip().strip('"').strip("'") for k in kw_lines if k.strip()]
        return keywords if keywords else None

    return None


def smart_truncate(text: str, limit: int = 200) -> str:
    """智能截断：优先在句子边界切断，保留完整语义。"""
    if not text or len(text) <= limit:
        return text

    truncated = text[:limit]

    # 按优先级找句子边界
    for char in ["。", "！", "？"]:
        idx = truncated.rfind(char)
        if idx > limit * 0.55:
            return truncated[:idx + 1] + "…"

    for char in ["；", "）", ")"]:
        idx = truncated.rfind(char)
        if idx > limit * 0.55:
            return truncated[:idx + 1] + "…"

    for char in ["，", "、"]:
        idx = truncated.rfind(char)
        if idx > limit * 0.55:
            return truncated[:idx + 1] + "…"

    # 英文空格
    idx = truncated.rfind(" ")
    if idx > limit * 0.55:
        return truncated[:idx] + "…"

    return truncated.rstrip() + "…"


def detect_category(slug: str, name: str, description: str) -> str:
    """根据 slug + name + description 自动检测分类（打分制，同分时按 CATEGORY_RULES 顺序优先）。
    优先级：frontmatter category > 描述关键词打分 + slug 加权 > 默认值。"""
    text = f"{slug} {name} {description}".lower()

    # 强匹配词得分 2，弱匹配词得分 1
    scores: dict[str, int] = {}
    for cat, strong_kws in CATEGORY_RULES:
        strong_hits = sum(1 for kw in strong_kws if kw.lower() in text)
        if strong_hits > 0:
            scores[cat] = strong_hits * 2

    for cat, weak_kws in WEAK_CATEGORY_KEYWORDS.items():
        weak_hits = sum(1 for kw in weak_kws if kw.lower() in text)
        if weak_hits > 0:
            scores[cat] = scores.get(cat, 0) + weak_hits

    # slug 匹配加权：若 slug 中包含分类的强/弱关键词，额外 +3
    slug_lower = slug.lower()
    for cat, strong_kws in CATEGORY_RULES:
        for kw in strong_kws:
            if kw.lower() in slug_lower:
                scores[cat] = scores.get(cat, 0) + 3
                break
    for cat, weak_kws in WEAK_CATEGORY_KEYWORDS.items():
        for kw in weak_kws:
            if kw.lower() in slug_lower:
                scores[cat] = scores.get(cat, 0) + 3
                break

    if not scores:
        return "productivity"

    # 返回得分最高的分类；同分时靠前者（CATEGORY_RULES 顺序）优先
    best_cat = max(CATEGORY_RULES, key=lambda item: scores.get(item[0], 0))
    return best_cat[0]


def extract_keywords(slug: str, description: str) -> list:
    """从 description 中智能提取中文关键词 + slug 英文词作为补充。
    优先级：frontmatter keywords > 描述中"触发关键词："段落 > 首句完整中文词 > slug 拆词。"""
    keywords: list[str] = []

    # 1) 解析"触发关键词："段落
    m = re.search(r"触发关键词[：:]\s*(.+?)(?:\n|$)", description)
    if m:
        kw_text = m.group(1)
        parts = re.split(r"[，,、；;]", kw_text)
        for p in parts:
            p = p.strip().strip('"').strip("'").rstrip("。.等")
            if p and len(p) >= 2 and p not in keywords:
                keywords.append(p)

    # 2) 解析"触发场景："段落
    m = re.search(r"触发场景[：:]\s*(.+?)(?:\n|$)", description)
    if m:
        kw_text = m.group(1)
        parts = re.split(r"[，,、；;]", kw_text)
        for p in parts:
            p = p.strip().strip('"').strip("'").rstrip("。.")
            if p and len(p) >= 2 and p not in keywords:
                keywords.append(p)

    # 3) 从首句提取关键短语（仅当步骤 1/2 未提取到关键词时作为补充）
    if not keywords:
        first_sentence = re.split(r"[。！？\n]", description)[0]
        # 按逗号/顿号拆段，取有意义的短段（2-12 字）作为关键词
        segments = re.split(r"[，,、；;]", first_sentence)
        stop_words = {
            "用于", "包括", "支持", "提供", "适用", "触发", "通过", "进行",
            "一个", "这个", "所有", "各种", "可以", "需要", "使用", "以及",
            "涵盖", "涉及", "包含", "基于", "面向", "帮助", "实现", "作为",
            "适用于", "检测", "读取", "创建", "编辑", "操作", "生成", "处理",
            "和设计", "与规则", "与文档", "等格式", "三大", "核心", "不同",
            "统一", "全面", "完整", "管理", "配置", "系统", "发现", "安装",
            "查找", "搜索", "总结", "整理", "汇总", "输出", "输入", "调用",
            "加载", "具有", "集成", "采用", "按照", "分为", "主要", "并将",
            "能预判", "能预判需求", "并持续", "并持续改进",
        }
        seen: set[str] = set()
        for seg in segments:
            seg = seg.strip().strip('"').strip("'")
            # 保留 2-12 字符的有意义短语（覆盖中英文混合词如 "TypeScript"）
            if 2 <= len(seg) <= 12 and seg not in stop_words and seg not in seen:
                seen.add(seg)
                keywords.append(seg)
                if len(keywords) >= 4:
                    break

    # 4) 补充 slug 英文关键词
    en_keywords = [w for w in re.split(r"[-_]+", slug) if w and len(w) > 1]
    for kw in en_keywords:
        if kw not in keywords:
            keywords.append(kw)

    return keywords[:8]


def build_keywords(slug: str) -> list:
    """简单基于 slug 拆分关键词（兼容旧接口）。"""
    return [w for w in re.split(r"[-_]+", slug) if w]


def is_low_quality_description(name: str, description: str) -> bool:
    """检测描述是否为低质量占位符。"""
    if not description:
        return True
    if re.match(r"^[\w-]+\s+skill$", description, re.IGNORECASE):
        return True
    if len(description) < 10:
        return True
    return False


def collect_plugins():
    """遍历 skills/ 目录收集插件元数据（不写磁盘）。

    返回 (plugins_meta, plugin_json_map, skipped, warnings, category_stats)。"""
    plugins_meta = []
    plugin_json_map = {}
    skipped = []
    warnings = []
    category_stats = {}  # 统计各分类数量

    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            skipped.append(skill_dir.name)
            continue

        fm_name, description, fm_category, fm_keywords, fm_author = parse_frontmatter(skill_md)
        slug = skill_dir.name

        # 名称：优先 frontmatter name，否则用目录名
        plugin_name = fm_name or slug
        if not description:
            description = f"{plugin_name} skill"

        # 作者：优先 frontmatter author，否则用默认作者
        author = {"name": fm_author} if fm_author else DEFAULT_AUTHOR

        # 分类：优先 frontmatter category，否则自动检测
        category = fm_category or detect_category(slug, plugin_name, description)
        category_stats[category] = category_stats.get(category, 0) + 1

        # 关键词：优先 frontmatter keywords，否则从描述中智能提取
        keywords = fm_keywords or extract_keywords(slug, description)

        # 校验 description 质量
        if is_low_quality_description(plugin_name, description):
            warnings.append(
                f"  ⚠️  {slug}: description 为低质量占位符 \"{description}\"\n"
                f"      → 请在 skills/{slug}/SKILL.md frontmatter 中补充完整的中文描述"
            )

        # 1) skills/<slug>/.codebuddy-plugin/plugin.json
        #    不声明 skills 字段：由 CodeBuddy 自动发现 plugin 根的平铺 SKILL.md
        plugin_json = {
            "name": plugin_name,
            "version": "1.0.0",
            "description": description,
            "author": author,
            "keywords": keywords,
            "category": category,
        }
        plugin_json_map[slug] = plugin_json

        # 2) marketplace.json 条目（描述使用智能截断）
        plugins_meta.append({
            "name": plugin_name,
            "source": f"skills/{slug}",
            "description": smart_truncate(description, 200),
            "version": "1.0.0",
            "author": author,
            "keywords": keywords,
            "category": category,
            "strict": False,
        })

    return plugins_meta, plugin_json_map, skipped, warnings, category_stats


def build_marketplace(plugins_meta) -> dict:
    """构造根 .codebuddy-plugin/marketplace.json 的内容。"""
    return {
        "name": MARKET_NAME,
        "description": MARKET_DESCRIPTION,
        "version": MARKET_VERSION,
        "owner": OWNER,
        "plugins": plugins_meta,
    }


def write_outputs(plugin_json_map, plugins_meta):
    """将插件元数据写入磁盘（各 plugin.json + marketplace.json）。"""
    for slug, plugin_json in plugin_json_map.items():
        plugin_meta_dir = SKILLS_DIR / slug / ".codebuddy-plugin"
        plugin_meta_dir.mkdir(exist_ok=True)
        (plugin_meta_dir / "plugin.json").write_text(
            json.dumps(plugin_json, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    MARKETPLACE_DIR.mkdir(exist_ok=True)
    (MARKETPLACE_DIR / "marketplace.json").write_text(
        json.dumps(build_marketplace(plugins_meta), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def check_outputs(plugin_json_map, plugins_meta) -> list:
    """对比生成结果与磁盘现有元数据文件，返回过期/缺失/多余的描述列表（空列表表示一致）。"""
    issues = []

    # 1) 各 skill 的 plugin.json
    for slug in sorted(plugin_json_map):
        plugin_path = SKILLS_DIR / slug / ".codebuddy-plugin" / "plugin.json"
        if not plugin_path.exists():
            issues.append(f"缺失 skills/{slug}/.codebuddy-plugin/plugin.json（新增 skill 未生成元数据）")
            continue
        try:
            disk = json.loads(plugin_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            issues.append(f"无法解析 skills/{slug}/.codebuddy-plugin/plugin.json")
            continue
        if disk != plugin_json_map[slug]:
            issues.append(f"过期 skills/{slug}/.codebuddy-plugin/plugin.json（frontmatter 变更未同步）")

    # 2) 磁盘上多余 plugin.json（skill 已删除但元数据残留）
    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        if not skill_dir.is_dir():
            continue
        slug = skill_dir.name
        plugin_path = skill_dir / ".codebuddy-plugin" / "plugin.json"
        if slug not in plugin_json_map and plugin_path.exists():
            issues.append(f"多余 skills/{slug}/.codebuddy-plugin/plugin.json（skill 已删除，元数据未清理）")

    # 3) 根 marketplace.json
    marketplace_path = MARKETPLACE_DIR / "marketplace.json"
    if not marketplace_path.exists():
        issues.append("缺失 .codebuddy-plugin/marketplace.json")
    else:
        try:
            disk = json.loads(marketplace_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            issues.append("无法解析 .codebuddy-plugin/marketplace.json")
        else:
            if disk != build_marketplace(plugins_meta):
                issues.append("过期 .codebuddy-plugin/marketplace.json")

    return issues


def main():
    # --check 模式：只校验不写入（供 pre-commit hook / 手动自查使用）
    check_mode = "--check" in sys.argv

    plugins_meta, plugin_json_map, skipped, warnings, category_stats = collect_plugins()

    if check_mode:
        issues = check_outputs(plugin_json_map, plugins_meta)

        # description 不合格时 npm run mp 会报错退出，提前提示避免二次往返
        if warnings:
            print("⚠️  以下 skill 的 description 不合格（执行 npm run mp 会报错，需先修复 frontmatter）：")
            for w in warnings:
                print(w.rstrip())
            print("")

        if issues:
            print("❌ 插件市场元数据过期（与 SKILL.md frontmatter 不一致）：")
            for issue in issues:
                print(f"   - {issue}")
            print("")
            print("   → 请执行 npm run mp 重新生成后再提交")
            sys.exit(1)
        print("✅ 插件市场元数据与 SKILL.md frontmatter 一致")
        sys.exit(0)

    write_outputs(plugin_json_map, plugins_meta)

    # 输出统计
    print(f"✅ Generated {len(plugins_meta)} plugin.json files")
    if skipped:
        print(f"⏭️  Skipped (no SKILL.md): {skipped}")
    print(f"📦 Marketplace: {MARKETPLACE_DIR / 'marketplace.json'}")
    print(f"\n📊 分类分布：")
    for cat, count in sorted(category_stats.items(), key=lambda x: -x[1]):
        print(f"   {cat}: {count}")

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
