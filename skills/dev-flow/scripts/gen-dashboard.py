#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dev-flow 度量仪表盘生成器（dev:metrics --dashboard / --all 的确定性实现）。

职责：
  1. 读取 ~/.codebuddy/.metrics/reports/*.yaml 全量报告；
  2. 归一化两种历史 schema（扁平格式 + 嵌套 requirement/scope/quality 格式）为统一扁平结构；
  3. 解析每条 report 对应的 working-context/<slug>.md 真实文件名（处理 ID 不一致历史包袱）；
  4. 重算 summary.yaml（含一致性校验，修复 total_requirements 漂移）；
  5. 读取 references/templates/dashboard.tpl.html，替换 __METRICS_DATA__ /
     __WORKING_CONTEXT_DIR__ / __FLOW_REPORTS_DIR__ / __HOME_DIR__ 占位符，
     生成 ~/.codebuddy/.metrics/dashboard.html。

用法：
  python3 gen-dashboard.py            # 重算 summary + 生成 dashboard 并自动打开浏览器（dev:metrics --dashboard 默认行为）
  python3 gen-dashboard.py --no-open  # 仅重算 summary + 生成 dashboard，不打开浏览器（供 dev:metrics --all 使用）

依赖：PyYAML（python3 -m pip install pyyaml）。
"""
import argparse
import datetime
import glob
import json
import os
import re
import shutil
import subprocess
import sys

try:
    import yaml
except ImportError:
    sys.exit("缺少依赖 PyYAML，请先执行：python3 -m pip install pyyaml")

HOME = os.path.expanduser("~")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
METRICS_DIR = os.path.join(HOME, ".codebuddy", ".metrics")
REPORTS_DIR = os.path.join(METRICS_DIR, "reports")
FLOW_REPORTS_DIR = os.path.join(METRICS_DIR, "flow-reports")
WORKING_CONTEXT_DIR = os.path.join(HOME, ".codebuddy", "working-context")
WORKING_CONTEXT_ARCHIVE_DIR = os.path.join(WORKING_CONTEXT_DIR, "archive")
DEVLOGS_DIR = os.path.join(HOME, ".codebuddy", "dev-logs")
TEMPLATE = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "references", "templates", "dashboard.tpl.html"))
OUT_HTML = os.path.join(METRICS_DIR, "dashboard.html")
SUMMARY = os.path.join(METRICS_DIR, "summary.yaml")
TODAY = datetime.date.today().isoformat()
KNOWLEDGE_DIR = os.path.join(HOME, ".codebuddy", "knowledge")
LEARNINGS_DIR = os.path.join(HOME, ".codebuddy", ".learnings")

# requirement_id 到 dev-logs 目录名的映射已废弃（2026-06-05 去补丁化）。
# 现在的确定性逻辑：从 requirement_id 提取 YYYYMMDD 前缀，
# 在 dev-logs/ 中查找同日期前缀的唯一目录进行匹配。
# 多候选时（同一天多个需求）借助 slug token 重合度兜底。


def num(v, default=0):
    """把 "~50" / "350" / None 等清洗为数字。"""
    if v is None:
        return default
    if isinstance(v, bool):
        return v
    if isinstance(v, (int, float)):
        return v
    s = str(v).strip().lstrip("~").strip()
    try:
        return int(s)
    except ValueError:
        try:
            return float(s)
        except ValueError:
            return default


def first(*vals):
    for v in vals:
        if v is not None:
            return v
    return None


def to_bool(v, default=False):
    if isinstance(v, bool):
        return v
    if v is None:
        return default
    return str(v).strip().lower() in ("true", "yes", "1", "pass")


def extract_date_from_id(rid):
    """从 requirement_id 前缀提取日期，例如 "20260514_addressbook" → "2026-05-14"。
    匹配失败返回 None。"""
    if not rid:
        return None
    m = re.match(r"^(\d{4})(\d{2})(\d{2})_", str(rid))
    if not m:
        return None
    y, mo, d = m.group(1), m.group(2), m.group(3)
    # 简单合法性校验，避免 99999999_ 这种误匹配
    try:
        datetime.date(int(y), int(mo), int(d))
    except ValueError:
        return None
    return "%s-%s-%s" % (y, mo, d)


def infer_complexity(files, lines):
    if files <= 2 and lines <= 100:
        return "simple"
    if files > 6 or lines > 500:
        return "complex"
    return "medium"


def calibrate_complexity(complexity, start_date_str, complete_date_str):
    """P3: 根据实际耗时校准复杂度。
    - 实际耗时 ≤ 1 天 → 自动降级为 simple
    - 实际耗时 ≥ 7 天 → 自动升级为 complex
    仅在日期有效时调整；无效日期保持原值。
    """
    if not start_date_str or not complete_date_str:
        return complexity, None
    try:
        start = datetime.datetime.strptime(str(start_date_str)[:10], "%Y-%m-%d")
        end = datetime.datetime.strptime(str(complete_date_str)[:10], "%Y-%m-%d")
        days = max(1, (end - start).days)
    except (ValueError, TypeError):
        return complexity, None

    original = complexity
    if days <= 1 and complexity != "simple":
        return "simple", "simple (原 %s，耗时 %dd → 降级)" % (original, days)
    if days >= 7 and complexity != "complex":
        return "complex", "complex (原 %s，耗时 %dd → 升级)" % (original, days)
    return complexity, None


def list_working_context_slugs():
    """扫描 working-context/*.md 与 archive 子目录，返回 {slug: rel_path} 字典。

    rel_path 为相对 WORKING_CONTEXT_DIR 的相对路径（已含 .md 后缀），
    例如 "20260306_user-login_my-app.md" 或
    "archive/2026-06/20260429_list-pagination_my-project.md"。
    结果缓存。
    """
    if not hasattr(list_working_context_slugs, "_cache"):
        mapping = {}
        if os.path.isdir(WORKING_CONTEXT_DIR):
            # 顶层活跃文件 + archive 子目录递归扫描
            for root, _dirs, files in os.walk(WORKING_CONTEXT_DIR):
                for fn in files:
                    if not fn.endswith(".md"):
                        continue
                    name = os.path.splitext(fn)[0]
                    if name.lower() == "readme":
                        continue
                    fp = os.path.join(root, fn)
                    relpath = os.path.relpath(fp, WORKING_CONTEXT_DIR)
                    # 同名优先级：顶层活跃 > 任意子目录（根级无路径分隔符即为活跃文件）
                    if name in mapping:
                        existing = mapping[name]
                        # 已有根级文件 → 保留；否则，新路径是根级 → 升级覆盖
                        if os.sep in existing and os.sep not in relpath:
                            mapping[name] = relpath
                    else:
                        mapping[name] = relpath
        list_working_context_slugs._cache = mapping
    return list_working_context_slugs._cache


def list_devlog_dirs():
    """扫描 dev-logs/<dirname>/，返回 {dirname: entry_file} 字典。

    entry_file 是该目录下的入口文件名：优先 devlog.md，否则 plan.md，否则 None。
    只要目录下存在 devlog.md 或 plan.md 即视为有效 dev-log。结果缓存。
    """
    if not hasattr(list_devlog_dirs, "_cache"):
        mapping = {}
        if os.path.isdir(DEVLOGS_DIR):
            for entry in os.listdir(DEVLOGS_DIR):
                full = os.path.join(DEVLOGS_DIR, entry)
                if not os.path.isdir(full) or entry.startswith("_") or entry.startswith("."):
                    continue
                if os.path.exists(os.path.join(full, "devlog.md")):
                    mapping[entry] = "devlog.md"
                elif os.path.exists(os.path.join(full, "plan.md")):
                    mapping[entry] = "plan.md"
        list_devlog_dirs._cache = mapping
    return list_devlog_dirs._cache


# === Knowledge directory scanning (Phase 1: knowledge panorama) ===

def _parse_frontmatter(filepath):
    """Parse YAML frontmatter from a markdown file. Returns dict or {}."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except (FileNotFoundError, IOError):
        return {}
    m = re.match(r"^---\s*\n(.*?)\n---", content, re.DOTALL)
    if not m:
        return {}
    try:
        return yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return {}


def _git_first_commit_date(filepath):
    """Get first commit date of a file (YYYY-MM-DD) from git log, or None."""
    try:
        result = subprocess.run(
            ["git", "log", "--diff-filter=A", "--follow", "--format=%aI", "--", filepath],
            capture_output=True, text=True, cwd=HOME, timeout=5
        )
        lines = result.stdout.strip().split("\n")
        if lines and lines[-1]:
            return lines[-1][:10]
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    return None


def _classify_knowledge_type(filepath, filename):
    """Classify a knowledge file by its name and path.

    Returns one of: index, overview, data-model, api, logic, ui, pitfalls,
    pattern, recipe, lesson, or None if unclassifiable.
    """
    basename = os.path.splitext(filename)[0]
    parent_dir = os.path.basename(os.path.dirname(filepath))

    if basename == "_index":
        return "index"
    if parent_dir == "_patterns":
        return "pattern"
    if parent_dir == "_recipes":
        return "recipe"
    if parent_dir == "_lessons":
        return "lesson"

    type_map = {
        "_overview": "overview",
        "data-model": "data-model",
        "api": "api",
        "logic": "logic",
        "ui": "ui",
        "pitfalls": "pitfalls",
    }
    return type_map.get(basename, None)


def scan_knowledge_dir():
    """Scan ~/.codebuddy/knowledge/ and ~/.codebuddy/.learnings/ for all knowledge entries.

    Returns a dict with keys:
      overview                 — summary metrics (total, new_this_month, stale_ratio, etc.)
      growth_timeline          — {months, series} for ECharts stacked area chart
      confidence_distribution  — {verified: N, scanned: N, draft: N, stale: N, unlabeled: N}
      projects_coverage        — per-project coverage stats
      entries                  — raw entry list
    """
    entries = []

    # ---- Scan knowledge/ directory ----
    if os.path.isdir(KNOWLEDGE_DIR):
        for root, _dirs, files in os.walk(KNOWLEDGE_DIR):
            if "_global" in root.split(os.sep):
                continue
            for fn in files:
                if not fn.endswith(".md"):
                    continue
                filepath = os.path.join(root, fn)
                relpath = os.path.relpath(filepath, KNOWLEDGE_DIR)

                parts = relpath.split(os.sep)
                project = parts[0] if parts else "_unknown"

                ktype = _classify_knowledge_type(filepath, fn)
                if ktype is None:
                    continue

                fm = _parse_frontmatter(filepath)

                # Date resolution: frontmatter.created → git log → mtime → today
                created = fm.get("created")
                if not created:
                    created = _git_first_commit_date(filepath)
                if not created:
                    try:
                        created = datetime.date.fromtimestamp(
                            os.path.getmtime(filepath)).isoformat()
                    except OSError:
                        created = TODAY

                confidence = fm.get("confidence", "unlabeled")
                if confidence not in ("verified", "scanned", "draft", "stale"):
                    confidence = "unlabeled"

                last_verified = fm.get("last_verified")
                verification_lag = None
                if last_verified:
                    try:
                        lv_date = datetime.datetime.strptime(
                            str(last_verified)[:10], "%Y-%m-%d").date()
                        verification_lag = (datetime.date.today() - lv_date).days
                    except (ValueError, TypeError):
                        pass

                module = None
                if ktype not in ("index", "pattern", "recipe"):
                    module = os.path.basename(os.path.dirname(filepath))

                entries.append({
                    "project": project,
                    "module": module,
                    "type": ktype,
                    "file": relpath,
                    "confidence": confidence,
                    "created": str(created)[:10] if created else TODAY,
                    "last_verified": str(last_verified)[:10] if last_verified else None,
                    "verification_lag_days": verification_lag,
                    "title": os.path.splitext(fn)[0],
                })

    # ---- Scan .learnings/ directory ----
    if os.path.isdir(LEARNINGS_DIR):
        for fn in os.listdir(LEARNINGS_DIR):
            if not fn.endswith(".md"):
                continue
            filepath = os.path.join(LEARNINGS_DIR, fn)
            fm = _parse_frontmatter(filepath)
            created = fm.get("created") or _git_first_commit_date(filepath)
            if not created:
                try:
                    created = datetime.date.fromtimestamp(
                        os.path.getmtime(filepath)).isoformat()
                except OSError:
                    created = TODAY
            entries.append({
                "project": "_global",
                "module": None,
                "type": "lesson",
                "file": os.path.join(".learnings", fn),
                "confidence": fm.get("confidence", "unlabeled"),
                "created": str(created)[:10] if created else TODAY,
                "last_verified": None,
                "verification_lag_days": None,
                "title": os.path.splitext(fn)[0],
            })

    if not entries:
        return {
            "overview": {"total_entries": 0, "new_this_month": 0,
                         "stale_ratio": 0, "stale_count": 0,
                         "avg_verification_lag_days": 0, "projects_with_knowledge": 0},
            "growth_timeline": {"months": [], "series": []},
            "confidence_distribution": {"verified": 0, "scanned": 0, "draft": 0,
                                         "stale": 0, "unlabeled": 0},
            "gap_alerts": [],
            "freshness_top5": [],
        }

    # ---- Compute derived data ----
    entries.sort(key=lambda e: e["created"] or "0000-00-00")

    # Confidence distribution
    conf_dist = {"verified": 0, "scanned": 0, "draft": 0, "stale": 0, "unlabeled": 0}
    for e in entries:
        conf_dist[e["confidence"]] = conf_dist.get(e["confidence"], 0) + 1

    # Growth timeline — monthly cumulative counts by 5 categories
    growth_by_month = {}
    for e in entries:
        month = (e["created"][:7] if e["created"] and len(e["created"]) >= 7
                 else TODAY[:7])
        if month not in growth_by_month:
            growth_by_month[month] = {
                "module_knowledge": 0, "pitfalls": 0,
                "patterns": 0, "recipes": 0, "lessons": 0,
            }
        cat = growth_by_month[month]
        t = e["type"]
        if t in ("index", "overview", "data-model", "api", "logic", "ui"):
            cat["module_knowledge"] += 1
        elif t == "pitfalls":
            cat["pitfalls"] += 1
        elif t == "pattern":
            cat["patterns"] += 1
        elif t == "recipe":
            cat["recipes"] += 1
        elif t == "lesson":
            cat["lessons"] += 1

    sorted_months = sorted(growth_by_month.keys())
    timeline_series = [
        {"name": "模块知识", "data": []},
        {"name": "易错点", "data": []},
        {"name": "设计模式", "data": []},
        {"name": "操作手册", "data": []},
        {"name": "经验教训", "data": []},
    ]
    cum = [0, 0, 0, 0, 0]
    keys = ["module_knowledge", "pitfalls", "patterns", "recipes", "lessons"]
    for month in sorted_months:
        gm = growth_by_month[month]
        for i, k in enumerate(keys):
            cum[i] += gm[k]
            timeline_series[i]["data"].append(int(cum[i]))
    growth_timeline = {"months": sorted_months, "series": timeline_series}

    # Per-project stats
    by_project = {}
    for e in entries:
        proj = e["project"]
        if proj == "_global":
            continue
        if proj not in by_project:
            by_project[proj] = {"total": 0, "modules": set(), "pitfalls": set(),
                                "api": set(), "data_model": set(),
                                "logic": set(), "ui": set(),
                                "patterns": 0, "recipes": 0, "lessons": 0}
        ps = by_project[proj]
        ps["total"] += 1
        if e["module"]:
            ps["modules"].add(e["module"])
        if e["type"] == "pitfalls" and e["module"]:
            ps["pitfalls"].add(e["module"])
        if e["type"] == "api" and e["module"]:
            ps["api"].add(e["module"])
        if e["type"] == "data-model" and e["module"]:
            ps["data_model"].add(e["module"])
        if e["type"] == "logic" and e["module"]:
            ps["logic"].add(e["module"])
        if e["type"] == "ui" and e["module"]:
            ps["ui"].add(e["module"])
        if e["type"] == "pattern":
            ps["patterns"] += 1
        if e["type"] == "recipe":
            ps["recipes"] += 1
        if e["type"] == "lesson":
            ps["lessons"] += 1

    projects_coverage = {}
    for proj, ps in by_project.items():
        projects_coverage[proj] = {
            "total_entries": ps["total"],
            "modules_documented": len(ps["modules"]),
            "with_pitfalls": len(ps["pitfalls"]),
            "with_api": len(ps["api"]),
            "with_data_model": len(ps["data_model"]),
            "with_logic": len(ps["logic"]),
            "with_ui": len(ps["ui"]),
            "patterns": ps["patterns"],
            "recipes": ps["recipes"],
            "lessons": ps["lessons"],
        }

    # Overview metrics
    total_entries = len(entries)
    stale_entries = conf_dist.get("stale", 0)
    new_this_month = sum(1 for e in entries
                         if e["created"] and e["created"][:7] == TODAY[:7])
    verification_lags = [e["verification_lag_days"] for e in entries
                         if e["verification_lag_days"] is not None]
    avg_verification_lag = (round(sum(verification_lags) / len(verification_lags), 1)
                            if verification_lags else 0)

    overview = {
        "total_entries": total_entries,
        "new_this_month": new_this_month,
        "stale_ratio": round(stale_entries / total_entries, 2) if total_entries else 0,
        "stale_count": stale_entries,
        "avg_verification_lag_days": avg_verification_lag,
        "projects_with_knowledge": len(by_project),
    }

    # ---- Gap alerts: which knowledge types are missing across projects ----
    learnings_lesson_count = sum(
        1 for e in entries if e["type"] == "lesson" and e["project"] == "_global"
    )

    gap_alerts = []
    total_projects = len(projects_coverage)
    gap_checks = [
        ("with_api", "缺少 API 文档", "📋"),
        ("patterns", "缺少设计模式", "🧩"),
        ("recipes", "缺少操作手册", "📖"),
        ("lessons", "缺少项目级经验教训", "💡"),
    ]
    for key, label, icon in gap_checks:
        missing = sum(1 for _p, pc in projects_coverage.items() if pc.get(key, 0) == 0)
        if missing > 0:
            alert = {
                "type": key, "label": label, "icon": icon,
                "missing": missing, "total": total_projects,
                "pct": round(missing / total_projects * 100) if total_projects else 0,
                "severity": "danger" if missing == total_projects else "warn",
            }
            gap_alerts.append(alert)

    # Global lessons pool: separate from per-project gaps, always info severity
    if learnings_lesson_count > 0:
        missing_lessons = sum(
            1 for _p, pc in projects_coverage.items() if pc.get("lessons", 0) == 0
        )
        gap_alerts.append({
            "type": "_lessons_global_pool",
            "label": "全局经验池",
            "icon": "📚",
            "value": learnings_lesson_count,
            "missing": missing_lessons,
            "total": total_projects,
            "pct": round(missing_lessons / total_projects * 100) if total_projects else 0,
            "severity": "info",
            "render_as": "global_pool",
        })

    # Sort: danger first (by pct desc), then warn (by pct desc), info last
    gap_alerts.sort(key=lambda g: (
        0 if g["severity"] == "danger" else (1 if g["severity"] == "warn" else 2),
        -g["pct"],
    ))

    # ---- Freshness: all entries needing verification (全量展示, 超出滚动) ----
    # 纳入规则：stale / scanned / draft / verified 验证滞后 > 60 天
    # 阈值 60 天 = 健康检查「⚠️ 提醒验证」的下限
    freshness_candidates = sorted(
        [e for e in entries
         if e["confidence"] in ("stale", "scanned", "draft")
         or (e["confidence"] == "verified"
             and e["verification_lag_days"] is not None
             and e["verification_lag_days"] > 60)],
        key=lambda e: (
            0 if e["confidence"] == "stale"
            else (1 if e["confidence"] in ("scanned", "draft") else 2),
            -(e["verification_lag_days"] or 0),
        ),
    )
    freshness_due = []
    for e in freshness_candidates:
        freshness_due.append({
            "project": e["project"],
            "file": e["file"],
            "title": e["title"],
            "type": e["type"],
            "confidence": e["confidence"],
            "verification_lag_days": e["verification_lag_days"],
        })

    return {
        "overview": overview,
        "growth_timeline": growth_timeline,
        "confidence_distribution": conf_dist,
        "gap_alerts": gap_alerts,
        "freshness_top5": freshness_due,
        "total_projects": total_projects,
        "learnings_lesson_count": learnings_lesson_count,
    }


def build_knowledge_panorama():
    """Build knowledge panorama data for dashboard consumption.

    Returns a dict ready for injection into the dashboard template.
    """
    return scan_knowledge_dir()


def _slug_tokens(s):
    """把 slug 拆成小写英文 token（用于关键词匹配）。"""
    if not s:
        return set()
    parts = re.split(r"[_\-\s]+", str(s).lower())
    return {p for p in parts if p and re.search(r"[a-z]", p)}


def resolve_working_context_slug(rid, start_date, branch, title):
    """把 requirement_id 映射到 working-context 中真实存在的 slug。

    2026-06-05 去补丁化：validate-metrics-yaml.sh 已保证
    requirement_id == 文件名 == 工作上下文 slug。
    此处仅做确定性查表，不再做任何猜测性匹配。

    返回：slug 字符串（不含扩展名），未命中返回 None。
    """
    slug_map = list_working_context_slugs()
    if not rid:
        return None
    if rid in slug_map:
        return rid
    return None


def resolve_doc_url(wc_slug):
    """从 working-context 文件中提取 doc_platform 技术方案链接。

    扫描 working-context/<wc_slug>.md，用正则提取 wiki URL 中的文档 ID，
    返回第一个匹配的完整 URL（去重），未命中返回 None。
    """
    if not wc_slug:
        return None
    slug_map = list_working_context_slugs()
    relpath = slug_map.get(wc_slug)
    if not relpath:
        return None
    md_path = os.path.join(WORKING_CONTEXT_DIR, relpath)
    try:
        with open(md_path, "r", encoding="utf-8") as f:
            text = f.read()
    except (FileNotFoundError, IOError):
        return None
    urls = re.findall(r"https?://doc\.example\.com/p/\d+", text)
    seen = set()
    unique = []
    for u in urls:
        if u not in seen:
            seen.add(u)
            unique.append(u)
    return unique[0] if unique else None


def _detect_knowledge_dir(wc_slug, rid, start_date):
    """探测 knowledge/{project}/ 下是否有对应项目目录。

    匹配策略（与 gen-flow-report.py 的 detect_knowledge 一致）：
    1. 从 wc_slug 尾段提取 project 名，精确匹配 knowledge/{project}/
    2. 包含匹配回退：knowledge/ 下目录名包含 project（忽略大小写、连字符）
    返回绝对路径或 None。
    """
    slug = wc_slug
    if not slug:
        return None
    if "_" not in str(slug):
        return None
    project = str(slug).rsplit("_", 1)[-1]
    # 策略1：精确匹配
    project_dir = os.path.join(KNOWLEDGE_DIR, project)
    if os.path.isdir(project_dir):
        return project_dir
    # 策略2：包含匹配回退
    if os.path.isdir(KNOWLEDGE_DIR):
        proj_lower = project.lower()
        for d in sorted(os.listdir(KNOWLEDGE_DIR)):
            d_lower = d.lower()
            d_clean = d_lower.replace("-", "")
            if proj_lower in d_clean or d_clean == proj_lower:
                d_path = os.path.join(KNOWLEDGE_DIR, d)
                if os.path.isdir(d_path):
                    return d_path
    return None


def resolve_devlog_dirname(rid, wc_slug, start_date, explicit_dir=None):
    """把 requirement_id 映射到 dev-logs 子目录名。

    2026-06-05 去补丁化：从 requirement_id 提取 YYYYMMDD 前缀，
    在 dev-logs/ 中查找同日期前缀的目录进行确定性匹配。
    多候选时借助 slug token 重合度兜底。
    """
    devlog_map = list_devlog_dirs()
    if not devlog_map:
        return None

    # 1. 显式声明
    if explicit_dir and explicit_dir in devlog_map:
        return explicit_dir

    # 2. 从 requirement_id 提取日期前缀
    date_prefix = None
    if rid:
        m = re.match(r"^(\d{8})_", str(rid))
        if m:
            date_prefix = m.group(1)

    if not date_prefix:
        return None

    # 3. 日期前缀唯一命中 → 确定性匹配
    candidates = [d for d in devlog_map if d.startswith(date_prefix + "_")]
    if len(candidates) == 1:
        return candidates[0]

    # 4. 多候选（同一天多个需求）→ token 重合度兜底（含 substring 匹配，
    #    处理中文目录名中嵌入英文 token 的情况，如 "API接口优化" 含 "api"）
    if candidates:
        hint_tokens = _slug_tokens(wc_slug or rid)
        if hint_tokens:
            best, best_score = None, 0
            for d in candidates:
                d_lower = d.lower()
                # 除精确 token 匹配外，还检查 hint token 是否为候选目录名的子串
                candidates_tokens = _slug_tokens(d)
                score = len(candidates_tokens & hint_tokens)
                # 子串匹配：hint token 在候选目录名中出现（≥2 字防止误匹配）
                for t in hint_tokens:
                    if len(t) >= 2 and t in d_lower:
                        score += 1
                if score > best_score:
                    best, best_score = d, score
            if best_score > 0:
                return best
    return None


# === schema 校验闸门（P0-3） ===
# 必填字段：缺失 → stderr 报 ❌，dashboard 顶部健康度徽章计入「不完整」
# 推荐字段：缺失 → stderr 报 ⚠️，dashboard 雷达图/热力图相关维度按默认值降级
# 条件采集字段（如 remote_kb_metrics / parallel_mode）由规范明确"仅触发条件命中时记录"，不参与校验
REQUIRED_FIELDS = [
    "requirement_id", "title", "mode", "complexity",
    "files_changed", "lines_added", "lines_deleted",
    "rollback_count", "user_corrections", "first_time_right",
    "l2_issues_found", "bugs_found_in_verify",
    "plan_adherence",  # 2026-07-22: 与 metrics_lib.py 同步升级为 REQUIRED
]
RECOMMENDED_FIELDS = [
    "requirement_type",
    "knowledge_updated", "devlog_generated",
    "rules_created", "lessons_learned",
    "iteration", "start_date", "complete_date",
]


def validate_report(d, fname):
    """非阻塞校验，返回 (missing_required, missing_recommended)。"""
    missing_req = [k for k in REQUIRED_FIELDS if d.get(k) is None]
    missing_rec = [k for k in RECOMMENDED_FIELDS if d.get(k) is None]
    if missing_req:
        sys.stderr.write("❌ %s: missing REQUIRED %s\n" % (fname, missing_req))
    elif missing_rec:
        sys.stderr.write("⚠️  %s: missing recommended %s\n" % (fname, missing_rec))
    return missing_req, missing_rec


def normalize(d, fname):
    """把扁平 schema 归一化为模板消费的统一结构。

    设计原则（P0-2 改造后）：
    - 仅支持扁平格式（嵌套格式已于 2026-06-02 一次性迁移完成）
    - 字段缺失走轻量默认值（不再有 90 行的双 schema fallback 链）
    - 仅保留个别历史拼写差异的兼容（如 lines_removed → lines_deleted）
    - schema 校验由 validate_report() 闸门负责，与 normalize 解耦
    """
    rid = d.get("requirement_id")
    id_for_date = rid or fname
    mode = d.get("mode") or "standard"
    if mode not in ("standard", "full"):
        mode = "standard"

    files = num(d.get("files_changed"))
    ladd = num(first(d.get("lines_added"), d.get("lines_added_total")))
    # 兼容历史拼写：bug-123456789 / 1000000000123456790 用了 lines_removed
    ldel = num(first(d.get("lines_deleted"), d.get("lines_removed")))
    # 文件变更细分：新增/删除（默认 0，兼容历史数据无此字段）
    files_created = num(d.get("files_created"))
    files_deleted = num(d.get("files_deleted"))
    if files == 0 and (ladd > 0 or ldel > 0):
        files = 1  # 缺陷密度热力图分母兜底

    complexity = d.get("complexity")
    if complexity not in ("simple", "medium", "complex"):
        complexity = infer_complexity(files, ladd)

    # date fallback：显式字段 → date 别名 → requirement_id/文件名 YYYYMMDD_ 前缀
    id_date = extract_date_from_id(id_for_date)
    start_date = first(d.get("start_date"), d.get("date"), id_date)
    complete_date = first(d.get("complete_date"), d.get("end_date"), d.get("date"), start_date, id_date)

    # P3: 复杂度自动校准（根据实际耗时修正）
    complexity, complexity_calibration_note = calibrate_complexity(
        complexity, start_date, complete_date)

    l2_found = num(d.get("l2_issues_found"))
    l2_fixed = num(d.get("l2_issues_fixed"))
    rollback = num(first(d.get("rollback_count"), d.get("rollbacks")))
    corrections = num(d.get("user_corrections"))
    bugs = num(d.get("bugs_found_in_verify"))
    bugs_fixed = num(d.get("bugs_fixed_in_verify"), 0)
    ftr = to_bool(d.get("first_time_right"))
    rounds = num(d.get("conversation_rounds"))
    ipf = d.get("issues_per_file")
    ipf = num(ipf) if ipf is not None else (round(l2_found / files, 2) if files else 0)
    iteration = num(d.get("iteration") or 1)

    knowledge = to_bool(d.get("knowledge_updated"))
    devlog = to_bool(d.get("devlog_generated"))

    # 解析 working-context slug（用于表格展示与点击跳转）
    branch = d.get("branch")
    title = first(d.get("title"), d.get("requirement_title"))
    wc_slug = resolve_working_context_slug(rid, start_date, branch, title)
    wc_relpath = list_working_context_slugs().get(wc_slug) if wc_slug else None
    wc_archived = bool(wc_relpath and wc_relpath.startswith("archive"))

    # 解析 dev-logs 子目录（开发日志列）
    devlog_dirname = resolve_devlog_dirname(
        rid, wc_slug, start_date, explicit_dir=d.get("devlog_dir"))
    devlog_entry = list_devlog_dirs().get(devlog_dirname) if devlog_dirname else None

    # 解析 doc_platform 技术方案链接（从 working-context 提取）
    doc_url = resolve_doc_url(wc_slug or rid) if (wc_slug or rid) else None

    # 解析 knowledge 目录（用于表格「知识」列跳转）
    knowledge_dir = _detect_knowledge_dir(wc_slug, rid, start_date)

    # 判断 plan.md 是否存在（devlog_dirname 有效时，检查 plan.md）
    plan_exists = False
    if devlog_dirname:
        plan_path = os.path.join(DEVLOGS_DIR, devlog_dirname, "plan.md")
        plan_exists = os.path.isfile(plan_path)

    # plan_adherence：默认 None（缺失，让 dashboard 显示 -），不再硬编码兜底
    plan_adherence = d.get("plan_adherence")
    if plan_adherence not in ("full", "minor_deviation", "major_deviation", "unassessed"):
        plan_adherence = None

    return {
        "requirement_id": rid or fname,
        "working_context_slug": wc_slug,
        "working_context_relpath": wc_relpath,
        "working_context_archived": wc_archived,
        "devlog_dirname": devlog_dirname,
        "devlog_entry": devlog_entry,  # devlog.md / plan.md / None
        "plan_exists": plan_exists,  # plan.md 是否存在于 dev-logs 目录下
        "doc_url": doc_url,  # doc_platform 技术方案链接（从 working-context 提取）
        "task_id": d.get("task_id") or "",
        "mode": mode,
        "date": complete_date or TODAY,
        "start_date": start_date or complete_date or TODAY,
        "complete_date": complete_date or TODAY,
        "rollback_count": rollback,
        "user_corrections": corrections,
        "l2_issues_found": l2_found,
        "l2_issues_fixed": l2_fixed,
        "bugs_found_in_verify": bugs,
        "bugs_fixed_in_verify": bugs_fixed,
        "files_changed": files,
        "files_created": files_created,
        "files_deleted": files_deleted,
        "lines_added": ladd,
        "lines_deleted": ldel,
        "complexity": complexity,
        "complexity_calibration_note": complexity_calibration_note,  # P3: 校准说明
        "issues_per_file": ipf,
        "bugs_per_100_lines": round(bugs / (ladd / 100), 2) if ladd else 0,
        "first_time_right": ftr,
        "conversation_rounds": rounds,
        "iteration": iteration,
        "is_iteration_fix": iteration > 1,
        "plan_adherence": plan_adherence,
        "knowledge_updated": knowledge,
        "knowledge_dir": knowledge_dir,  # knowledge/{project}/ 绝对路径（用于表格跳转）
        "devlog_generated": devlog,
        "rules_created": num(first(d.get("rules_created"), 0)),
        "lessons_learned": num(first(d.get("lessons_learned"), 0)),
        # 🆕 2026-07-03: 需求类型 + 纠正分类
        "requirement_type": d.get("requirement_type") or "feature",
        "correction_types": d.get("correction_types") or None,
        # 跨项目需求标识（仪表盘需求明细表格高亮徽章）
        "is_cross_project": to_bool(d.get("is_cross_project")),
        "projects_involved": d.get("projects_involved") or [],
        "primary_project": d.get("primary_project") or "",
    }


def load_reports():
    """加载全量 reports + 同步运行 schema 校验闸门，返回 (reports, health)。

    health 结构：{ total, complete, missing_required, missing_recommended,
                  by_file: [{fname, missing_req, missing_rec}, ...] }
    """
    reports = []
    health = {
        "total": 0,
        "complete": 0,
        "missing_required": 0,
        "missing_recommended": 0,
        "by_file": [],
    }
    for fp in sorted(glob.glob(os.path.join(REPORTS_DIR, "*.yaml"))):
        fname = os.path.splitext(os.path.basename(fp))[0]
        data = {}
        with open(fp, "r", encoding="utf-8") as f:
            for doc in yaml.safe_load_all(f):  # 兼容多文档 YAML（--- 分隔）
                if isinstance(doc, dict):
                    data.update(doc)
        # P0-3 校验闸门：基于原始 yaml 数据校验（在 normalize 兜底之前）
        missing_req, missing_rec = validate_report(data, fname)
        health["total"] += 1
        if not missing_req and not missing_rec:
            health["complete"] += 1
        if missing_req:
            health["missing_required"] += 1
        if missing_rec and not missing_req:
            health["missing_recommended"] += 1
        if missing_req or missing_rec:
            health["by_file"].append({
                "fname": fname,
                "missing_req": missing_req,
                "missing_rec": missing_rec,
            })
        normalized = normalize(data, fname)
        # P0：标记单需求 HTML 复盘报告是否已生成（用于仪表盘表格「📊 复盘」列）
        # 优先按 requirement_id 探测，其次按 yaml 文件名，最后按 task_id（兼容 任务平台 ID 命名的报告）
        rid = normalized.get("requirement_id") or fname
        rid_html = os.path.join(FLOW_REPORTS_DIR, "%s.html" % rid)
        fname_html = os.path.join(FLOW_REPORTS_DIR, "%s.html" % fname)
        task_id = normalized.get("task_id")
        task_html = os.path.join(FLOW_REPORTS_DIR, "%s.html" % task_id) if task_id else None
        if os.path.exists(rid_html):
            normalized["flow_report_exists"] = True
            normalized["flow_report_filename"] = rid  # 前端拼接路径用
        elif os.path.exists(fname_html):
            normalized["flow_report_exists"] = True
            normalized["flow_report_filename"] = fname
        elif task_html and os.path.exists(task_html):
            normalized["flow_report_exists"] = True
            normalized["flow_report_filename"] = task_id
        else:
            normalized["flow_report_exists"] = False
            normalized["flow_report_filename"] = rid  # 默认值
        reports.append(normalized)
    reports.sort(key=lambda r: r.get("start_date") or r.get("date") or "")

    # P2: 长周期数据可信度检测（≥10 天 + 0 回退 + 0 纠正 → 可能数据未完整记录）
    data_warnings = []
    for r in reports:
        try:
            sd = datetime.datetime.strptime(str(r.get("start_date", ""))[:10], "%Y-%m-%d")
            ed = datetime.datetime.strptime(str(r.get("complete_date", ""))[:10], "%Y-%m-%d")
            duration = max(1, (ed - sd).days)
        except (ValueError, TypeError):
            duration = 0
        if (duration >= 10 and r.get("rollback_count", 0) == 0
                and r.get("user_corrections", 0) == 0
                and r.get("first_time_right") is False):
            data_warnings.append({
                "requirement_id": r["requirement_id"],
                "duration_days": duration,
                "conversation_rounds": r.get("conversation_rounds", 0),
                "iteration": r.get("iteration", 1),
            })
    health["data_warnings"] = data_warnings

    # P3: 知识沉淀字段一致性交叉校验
    # 检测 knowledge_updated=false 但存在 doc_url 或 lessons_learned>0 的报告
    knowledge_inconsistencies = []
    for r in reports:
        kw = r.get("knowledge_updated", False)
        iw = r.get("doc_url") or (r.get("extra") or {}).get("doc_url")
        ll = r.get("lessons_learned", 0)
        if kw is False and (iw or ll > 0):
            reasons = []
            if iw:
                reasons.append("有 文档平台 文档")
            if ll > 0:
                reasons.append(f"有 {ll} 条经验教训")
            knowledge_inconsistencies.append({
                "requirement_id": r["requirement_id"],
                "reasons": reasons,
                "doc_url": iw or None,
                "lessons_learned": ll,
            })
    health["knowledge_inconsistencies"] = knowledge_inconsistencies

    return reports, health


def avg(nums):
    return round(sum(nums) / len(nums), 2) if nums else 0


def build_summary(reports):
    total = len(reports)
    dd = {"standard": 0, "full": 0}
    for r in reports:
        dd[r["mode"]] = dd.get(r["mode"], 0) + 1

    def qa_of(rs):
        return {
            "rollbacks": avg([r["rollback_count"] for r in rs]),
            "user_corrections": avg([r["user_corrections"] for r in rs]),
            "l2_issues_per_file": avg([r["issues_per_file"] for r in rs]),
            "verify_bugs": avg([r["bugs_found_in_verify"] for r in rs]),
            "first_time_right_rate": round(sum(1 for r in rs if r["first_time_right"]) / len(rs), 2) if rs else 0,
        }

    qbd = {}
    for depth in ("standard", "full"):
        rs = [r for r in reports if r["mode"] == depth]
        if rs:
            entry = qa_of(rs)
            entry["count"] = len(rs)
            qbd[depth] = entry

    recent = sorted(reports, key=lambda r: r.get("start_date") or r.get("date") or "", reverse=True)[:10]
    # 数据源覆盖率：reports/*.yaml 数 vs 去重后的独立需求数
    # 2026-07-06 fix: 旧逻辑直接数 dev-logs/ 目录数，会把多轮次/多项目阶段的
    # 后续目录也计为独立需求（如 Round 7/8 的后续变更、跨项目 Phase 2），
    # 导致分母膨胀、覆盖率虚低。P2（step-4 复用检测）从源头防止冗余目录产生。
    # P1 此处：reports 本身就是已度量需求的权威清单，分母 = reports 数 = 100%。
    # 若未来出现有 devlog 但无 YAML 的新需求，P3（devlog-integrity-lint.sh 孤儿检测）
    # 会在运行仪表盘前发出 WARN，不依赖覆盖率百分比来发现。
    devlog_dirs = total

    # 🆕 2026-07-03: 需求类型分布
    type_dist = {"feature": 0, "bugfix": 0, "refactor": 0, "style": 0, "other": 0}
    for r in reports:
        t = r.get("requirement_type") or "feature"
        if t in type_dist:
            type_dist[t] += 1
        else:
            type_dist["other"] += 1

    # 🆕 按类型质量对比
    quality_by_type = {}
    for tname in ("feature", "bugfix", "refactor", "style", "other"):
        rs = [r for r in reports if (r.get("requirement_type") or "feature") == tname]
        if rs:
            entry = qa_of(rs)
            entry["count"] = len(rs)
            quality_by_type[tname] = entry

    # 🆕 纠正类型按月趋势
    ct_trend = {"months": [], "logic": [], "boundary": [], "other": []}
    monthly_ct = {}
    for r in reports:
        ct = r.get("correction_types")
        if not ct:
            continue
        month = (r.get("start_date") or r.get("date") or TODAY)[:7]
        if month not in monthly_ct:
            monthly_ct[month] = {"logic": 0, "boundary": 0, "other": 0}
        monthly_ct[month]["logic"] += ct.get("logic", 0)
        monthly_ct[month]["boundary"] += ct.get("boundary", 0)
        monthly_ct[month]["other"] += ct.get("other", 0)
    if monthly_ct:
        sorted_months = sorted(monthly_ct.keys())
        ct_trend["months"] = sorted_months
        ct_trend["logic"] = [monthly_ct[m]["logic"] for m in sorted_months]
        ct_trend["boundary"] = [monthly_ct[m]["boundary"] for m in sorted_months]
        ct_trend["other"] = [monthly_ct[m]["other"] for m in sorted_months]

    # 🆕 月度吞吐量
    monthly_throughput = {"months": [], "counts": []}
    month_counts = {}
    for r in reports:
        month = (r.get("start_date") or r.get("date") or TODAY)[:7]
        month_counts[month] = month_counts.get(month, 0) + 1
    if month_counts:
        mp_sorted = sorted(month_counts.keys())
        monthly_throughput["months"] = mp_sorted
        monthly_throughput["counts"] = [month_counts[m] for m in mp_sorted]

    return {
        "last_updated": TODAY,
        "total_requirements": total,
        "devlog_dir_count": devlog_dirs,
        "coverage_pct": round(total / devlog_dirs * 100, 1) if devlog_dirs else 100,
        "depth_distribution": dd,
        "quality_averages": qa_of(reports),
        "quality_by_depth": qbd,
        "requirement_type_distribution": type_dist,
        "quality_by_type": quality_by_type,
        "correction_type_trend": ct_trend,
        "monthly_throughput": monthly_throughput,
        "recent": [{"id": r["requirement_id"], "mode": r["mode"], "date": r["date"],
                    "rollbacks": r["rollback_count"], "files": r["files_changed"],
                    "first_time_right": r["first_time_right"]} for r in recent],
    }


def write_summary(summary):
    if os.path.exists(SUMMARY):
        shutil.copy2(SUMMARY, SUMMARY + ".bak")
    with open(SUMMARY, "w", encoding="utf-8") as f:
        f.write("# dev-flow 度量汇总统计（由 gen-dashboard.py 自动重算）\n")
        f.write("# 重算时间：%s | 数据源：reports/*.yaml 全量\n\n" % TODAY)
        yaml.safe_dump(summary, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def write_dashboard(summary, reports, health, knowledge_panorama=None):
    with open(TEMPLATE, "r", encoding="utf-8") as f:
        tpl = f.read()
    payload = {
        "summary": summary,
        "reports": reports,
        "health": health,  # P0-3 数据健康度（用于顶部徽章/告警）
        "knowledge_panorama": knowledge_panorama or {},
        "generated_at": TODAY,
    }
    html = tpl.replace("__METRICS_DATA__", json.dumps(payload, ensure_ascii=False))
    # __WORKING_CONTEXT_DIR__ 是 working-context 目录的绝对路径；__HOME_DIR__ 保留兼容
    html = html.replace("__WORKING_CONTEXT_DIR__", WORKING_CONTEXT_DIR)
    # __FLOW_REPORTS_DIR__ 是单需求 HTML 复盘报告目录的绝对路径（P0：仪表盘表格新增「📊 复盘」列）
    html = html.replace("__FLOW_REPORTS_DIR__", FLOW_REPORTS_DIR)
    # __DEVLOGS_DIR__ 是开发日志目录的绝对路径（新增「开发日志」列）
    html = html.replace("__DEVLOGS_DIR__", DEVLOGS_DIR)
    # __KNOWLEDGE_DIR__ 是知识沉淀目录的绝对路径（知识全景入口 + 表格「知识」列）
    html = html.replace("__KNOWLEDGE_DIR__", KNOWLEDGE_DIR)
    html = html.replace("__HOME_DIR__", HOME)
    with open(OUT_HTML, "w", encoding="utf-8") as f:
        f.write(html)


def main():
    parser = argparse.ArgumentParser(description="dev-flow 度量仪表盘生成器")
    parser.add_argument("--no-open", action="store_true",
                        help="仅生成 dashboard.html，不打开浏览器（默认会自动打开）")
    args = parser.parse_args()

    if not os.path.isdir(REPORTS_DIR):
        sys.exit("未找到报告目录：%s" % REPORTS_DIR)

    reports, health = load_reports()
    summary = build_summary(reports)
    knowledge_panorama = build_knowledge_panorama()
    write_summary(summary)
    write_dashboard(summary, reports, health, knowledge_panorama)

    qa = summary["quality_averages"]
    print("OK total=%d  FTR=%.0f%%  rollbacks=%.2f  corrections=%.2f  l2/file=%.2f  bugs=%.2f" % (
        summary["total_requirements"], qa["first_time_right_rate"] * 100,
        qa["rollbacks"], qa["user_corrections"], qa["l2_issues_per_file"], qa["verify_bugs"]))
    print("depth=%s" % summary["depth_distribution"])
    # P0-3 健康度摘要
    print("health: complete=%d/%d  required-missing=%d  recommended-missing=%d" % (
        health["complete"], health["total"],
        health["missing_required"], health["missing_recommended"]))
    ko = knowledge_panorama.get("overview", {})
    print("knowledge: entries=%d  new_month=%d  stale=%d(%.0f%%)  lag=%.1fd  projects=%d" % (
        ko.get("total_entries", 0), ko.get("new_this_month", 0),
        ko.get("stale_count", 0), ko.get("stale_ratio", 0) * 100,
        ko.get("avg_verification_lag_days", 0), ko.get("projects_with_knowledge", 0)))
    gaps = knowledge_panorama.get("gap_alerts", [])
    print("knowledge gaps: %s" % ", ".join(
        "%s=%d/%d(%s)" % (g["type"], g["total"] - g["missing"], g["total"], g["severity"])
        for g in gaps
    ) or "none")
    lc = knowledge_panorama.get("learnings_lesson_count", 0)
    if lc > 0:
        print("learnings_lessons=%d (global pool)" % lc)
    # P3: 知识沉淀一致性告警
    inconsistencies = health.get("knowledge_inconsistencies", [])
    if inconsistencies:
        n = len(inconsistencies)
        print("⚠️  knowledge_consistency=%d — knowledge_updated=false 但存在 doc_platform/经验教训，建议修正" % n)
        for inc in inconsistencies:
            reason_str = "、".join(inc["reasons"])
            print("   └─ %s — %s" % (inc["requirement_id"], reason_str))
    else:
        print("✅ knowledge_consistency=0 — 所有字段一致")
    print("summary=%s" % SUMMARY)
    print("dashboard=%s" % OUT_HTML)

    if not args.no_open:
        opener = "open" if sys.platform == "darwin" else "xdg-open"
        try:
            subprocess.run([opener, OUT_HTML], check=False)
        except FileNotFoundError:
            print("提示：未找到 %s 命令，请手动打开 %s" % (opener, OUT_HTML))


if __name__ == "__main__":
    main()
