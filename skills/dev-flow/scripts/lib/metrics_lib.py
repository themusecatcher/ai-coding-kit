#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dev-flow 度量数据共享库（被 gen-dashboard.py / gen-flow-report.py 共用）。

职责：
  1. 集中维护 Tier 1/2 字段定义
  2. 提供 normalize() 把 reports/*.yaml 扁平 schema 归一化为统一结构
  3. 提供 validate_report() 闸门校验（必填/推荐字段缺失分级）
  4. 提供 working-context slug 解析（确定性查表）
  5. 提供基础工具函数（num/first/to_bool/extract_date_from_id 等）

设计原则：
  - 与 metrics-rules.md「采集纪律」红线一致
  - 仅支持扁平 schema（嵌套格式已于 2026-06-02 一次性迁移完成）
  - 缺失字段走轻量默认值，不再有双 schema fallback 链
  - 2026-06-05：删除 PROJECT_ALIAS / KNOWN_ALIAS 人工映射，需求 ID 由
    validate-metrics-yaml.sh 保证确定性一致性
"""
import datetime
import glob
import os
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("缺少依赖 PyYAML，请先执行：python3 -m pip install pyyaml")

HOME = os.path.expanduser("~")
METRICS_DIR = os.path.join(HOME, ".codebuddy", ".metrics")
REPORTS_DIR = os.path.join(METRICS_DIR, "reports")
WORKING_CONTEXT_DIR = os.path.join(HOME, ".codebuddy", "working-context")
TODAY = datetime.date.today().isoformat()

# === 字段定义（与 metrics-rules.md「采集纪律」红线对齐） ===
REQUIRED_FIELDS = [
    "requirement_id", "title", "mode", "complexity",
    "files_changed", "lines_added", "lines_deleted",
    "rollback_count", "user_corrections", "first_time_right",
    "l2_issues_found", "bugs_found_in_verify",
    "plan_adherence",  # 升级为 REQUIRED：HTML 报告 KPI，缺失显示"未采集"影响报告完整性
]
RECOMMENDED_FIELDS = [
    "requirement_type",
    "knowledge_updated", "devlog_generated",
    "rules_created", "lessons_learned",
    "iteration", "start_date", "complete_date",
    # 🆕 2026-07-30 P2：跨项目字段
    "is_cross_project", "projects_involved", "primary_project",
    # 🆕 2026-07-08 P2：Token/模型统计（估算值，非精确）
    "est_tokens", "primary_model",
]

# requirement_id 到 working-context slug 的映射已废弃（2026-06-05 去补丁化）。
# validate-metrics-yaml.sh 保证 requirement_id == 文件名 == 工作上下文 slug，
# 不再需要 PROJECT_ALIAS / KNOWN_ALIAS 人工映射。


# === 基础工具 ===
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
    """从 requirement_id 前缀提取日期，例如 "20260514_addressbook" → "2026-05-14"。"""
    if not rid:
        return None
    m = re.match(r"^(\d{4})(\d{2})(\d{2})_", str(rid))
    if not m:
        return None
    y, mo, d = m.group(1), m.group(2), m.group(3)
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


# === working-context slug 解析（兜底匹配） ===
_slug_cache = None


def list_working_context_slugs():
    """扫描 working-context/*.md，返回所有有效 slug（无扩展名）。"""
    global _slug_cache
    if _slug_cache is None:
        slugs = []
        if os.path.isdir(WORKING_CONTEXT_DIR):
            for fp in glob.glob(os.path.join(WORKING_CONTEXT_DIR, "*.md")):
                name = os.path.splitext(os.path.basename(fp))[0]
                if name.lower() == "readme":
                    continue
                slugs.append(name)
        _slug_cache = slugs
    return _slug_cache


def _slug_tokens(s):
    if not s:
        return set()
    parts = re.split(r"[_\-\s]+", str(s).lower())
    return {p for p in parts if p and re.search(r"[a-z]", p)}


def resolve_working_context_slug(rid, start_date=None, branch=None, title=None, strict=False):
    """把 requirement_id 映射到 working-context 中真实存在的 slug。

    2026-06-05 去补丁化：validate-metrics-yaml.sh 保证
    requirement_id == 文件名 == 工作上下文 slug。
    此处仅做确定性查表，不再做任何猜测性匹配。

    Args:
        strict: 兼容旧调用方，当前已无实际作用（仅做简单查表）。
    """
    slugs = list_working_context_slugs()
    if not rid:
        return None
    if rid in slugs:
        return rid
    return None


# === 校验闸门 ===
def validate_report(d, fname):
    """非阻塞校验，返回 (missing_required, missing_recommended)。"""
    missing_req = [k for k in REQUIRED_FIELDS if d.get(k) is None]
    missing_rec = [k for k in RECOMMENDED_FIELDS if d.get(k) is None]
    if missing_req:
        sys.stderr.write("❌ %s: missing REQUIRED %s\n" % (fname, missing_req))
    elif missing_rec:
        sys.stderr.write("⚠️  %s: missing recommended %s\n" % (fname, missing_rec))
    return missing_req, missing_rec


# === 归一化（扁平 schema → 模板消费的统一结构） ===
def normalize(d, fname):
    """把扁平 schema 归一化为统一结构。"""
    rid = d.get("requirement_id")
    id_for_date = rid or fname
    mode = d.get("mode") or "standard"
    if mode not in ("standard", "full", "cross-project"):
        mode = "standard"

    files = num(d.get("files_changed"))
    ladd = num(first(d.get("lines_added"), d.get("lines_added_total")))
    ldel = num(first(d.get("lines_deleted"), d.get("lines_removed")))
    if files == 0 and (ladd > 0 or ldel > 0):
        files = 1

    complexity = d.get("complexity")
    if complexity not in ("simple", "medium", "complex"):
        complexity = infer_complexity(files, ladd)

    id_date = extract_date_from_id(id_for_date)
    start_date = first(d.get("start_date"), d.get("date"), id_date)
    complete_date = first(d.get("complete_date"), d.get("end_date"), d.get("date"), start_date, id_date)

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

    branch = d.get("branch")
    title = first(d.get("title"), d.get("requirement_title"))
    wc_slug = resolve_working_context_slug(rid, start_date, branch, title)

    plan_adherence = d.get("plan_adherence")
    if plan_adherence not in ("full", "minor_deviation", "major_deviation"):
        plan_adherence = None

    return {
        "requirement_id": rid or fname,
        "working_context_slug": wc_slug,
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
        "files_created": num(d.get("files_created"), 0),
        "files_deleted": num(d.get("files_deleted"), 0),
        "lines_added": ladd,
        "lines_deleted": ldel,
        "complexity": complexity,
        "issues_per_file": ipf,
        "bugs_per_100_lines": round(bugs / (ladd / 100), 2) if ladd else 0,
        "first_time_right": ftr,
        "conversation_rounds": rounds,
        "iteration": iteration,
        "is_iteration_fix": iteration > 1,
        "plan_adherence": plan_adherence,
        "knowledge_updated": knowledge,
        "devlog_generated": devlog,
        "rules_created": num(first(d.get("rules_created"), 0)),
        "lessons_learned": num(first(d.get("lessons_learned"), 0)),
        # 🆕 2026-07-03: 需求类型 + 纠正分类
        "requirement_type": d.get("requirement_type") or "feature",
        "correction_types": d.get("correction_types") or None,
        # 扩展字段（单需求报告需要，但归一化保持向后兼容）
        "branch": branch or "",
        "title": title or "",
        "task_url": first(d.get("task_url"), (d.get("extra") or {}).get("task_url"), ""),
        "doc_url": first(d.get("doc_url"), (d.get("extra") or {}).get("doc_url"), ""),
        # 🆕 2026-07-30：跨项目字段
        "is_cross_project": to_bool(d.get("is_cross_project")),
        "projects_involved": d.get("projects_involved") or [],
        "primary_project": d.get("primary_project") or "",
        # 🆕 2026-07-08 P2：Token/模型统计
        "est_tokens": num(d.get("est_tokens"), 0),
        "primary_model": d.get("primary_model") or "",
    }


def load_one_report(rid):
    """读取单个 report yaml 并归一化，找不到返回 None。"""
    fp = os.path.join(REPORTS_DIR, "%s.yaml" % rid)
    if not os.path.exists(fp):
        return None, None
    fname = rid
    data = {}
    with open(fp, "r", encoding="utf-8") as f:
        for doc in yaml.safe_load_all(f):
            if isinstance(doc, dict):
                data.update(doc)
    missing_req, missing_rec = validate_report(data, fname)
    return normalize(data, fname), {
        "missing_req": missing_req,
        "missing_rec": missing_rec,
        "raw": data,
    }


def load_all_reports():
    """加载全量 reports + 校验，返回 (reports, health)。"""
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
            for doc in yaml.safe_load_all(f):
                if isinstance(doc, dict):
                    data.update(doc)
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
        reports.append(normalize(data, fname))
    reports.sort(key=lambda r: r.get("start_date") or r.get("date") or "")
    return reports, health


def avg(nums):
    return round(sum(nums) / len(nums), 2) if nums else 0
