#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dev-flow 单需求复盘报告生成器（HTML）。

职责：
  1. 读取单条 ~/.codebuddy/.metrics/reports/{需求ID}.yaml；
  2. 聚合工作上下文中的纠正记录、devlog/knowledge 关联资源；
  3. 与 summary.yaml 同模式历史均值对比，自动派生异常洞察；
  4. 读取 references/templates/flow-report.tpl.html，替换 __FLOW_DATA__ /
     __HOME_DIR__ / __GENERATED_AT__ 占位符；
  5. 写入 ~/.codebuddy/.metrics/flow-reports/{需求ID}.html；
  6. 默认自动 open 打开浏览器（--no-open 关闭）。

用法：
  python3 gen-flow-report.py {需求ID}             # 生成 + 自动打开
  python3 gen-flow-report.py {需求ID} --no-open   # 仅生成

设计原则：
  - 与 metrics-rules.md「采集纪律」红线一致，扁平 schema only
  - 失败容忍：报告/工作上下文/devlog 任一缺失，对应区块降级显示「未采集」
  - 自动打开失败时降级为打印路径，不阻断流程
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys

# 本地 lib 引用
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

try:
    import yaml
except ImportError:
    sys.exit("缺少依赖 PyYAML，请先执行：python3 -m pip install pyyaml")

from lib.metrics_lib import (  # noqa: E402
    HOME, METRICS_DIR, WORKING_CONTEXT_DIR, TODAY,
    load_one_report, load_all_reports, avg, resolve_working_context_slug,
)

TEMPLATE = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "references", "templates", "flow-report.tpl.html"))
FLOW_REPORTS_DIR = os.path.join(METRICS_DIR, "flow-reports")
SUMMARY = os.path.join(METRICS_DIR, "summary.yaml")
DEVLOGS_DIR = os.path.join(HOME, ".codebuddy", "dev-logs")
KNOWLEDGE_DIR = os.path.join(HOME, ".codebuddy", "knowledge")


# === 数据聚合：从工作上下文 grep 用户纠正 ===
def extract_corrections(slug):
    """从工作上下文 grep 「🔧 [纠正]」行，返回 [{time, content}]。"""
    if not slug:
        return []
    fp = os.path.join(WORKING_CONTEXT_DIR, "%s.md" % slug)
    if not os.path.exists(fp):
        return []
    corrections = []
    pattern = re.compile(
        r"^\s*[-*]\s*\[(?:(\d{4}-\d{2}-\d{2})\s+)?(\d{1,2}:\d{2})\]\s*🔧(?:\s*\[纠正\])?\s*(.+?)\s*$"
    )
    with open(fp, "r", encoding="utf-8") as f:
        for line in f:
            m = pattern.match(line)
            if m:
                date_part = m.group(1) or ""
                time_part = m.group(2)
                full_time = (date_part + " " + time_part).strip() if date_part else time_part
                corrections.append({
                    "time": full_time,
                    "content": m.group(3).strip(),
                })
    return corrections


def extract_rollbacks(slug):
    """从工作上下文 grep 「步骤 X→Y 回退」行，返回 [{from, to, reason}]。"""
    if not slug:
        return []
    fp = os.path.join(WORKING_CONTEXT_DIR, "%s.md" % slug)
    if not os.path.exists(fp):
        return []
    rollbacks = []
    # 匹配 "步骤 6→3 回退"、"步骤6→5回退"、"回退步骤 5"、"回退步骤5"
    pattern = re.compile(r"步骤\s*(\d+(?:\.\d+)?)\s*[→\-]+\s*(\d+(?:\.\d+)?)\s*回退|回退步骤\s*(\d+(?:\.\d+)?)")
    with open(fp, "r", encoding="utf-8") as f:
        content = f.read()
        for m in pattern.finditer(content):
            if m.group(1) and m.group(2):
                rollbacks.append({"from": m.group(1), "to": m.group(2)})
            elif m.group(3):
                rollbacks.append({"from": "?", "to": m.group(3)})
    return rollbacks


# === 跨项目信息提取（从工作上下文 YAML front matter） ===
def extract_cross_project_info(slug):
    """从工作上下文 YAML front matter 提取 cross_project 信息。

    返回 dict，结构：
      - is_cross: bool
      - projects: [{name, role, workspace, short?, role_label?, branch?,
                    files_changed?, mr?, mr_url?, mr_status?}]
        角色：main / source / fix / dep-bump / dependency / extra
        带 ? 字段来自 front matter 的 projects_detail 增强明细（可选）
      - handoff_note: str | None
      - status: str | None
    """
    if not slug:
        return {"is_cross": False, "projects": [], "handoff_note": None, "status": None}

    fp = os.path.join(WORKING_CONTEXT_DIR, "%s.md" % slug)
    if not os.path.exists(fp):
        return {"is_cross": False, "projects": [], "handoff_note": None, "status": None}

    content = ""
    with open(fp, "r", encoding="utf-8") as f:
        # 只读 YAML front matter（--- 之间的内容，最多 200 行）
        in_front = False
        for i, line in enumerate(f):
            if i == 0 and line.strip() == "---":
                in_front = True
                continue
            if i > 0 and line.strip() == "---":
                break
            if in_front:
                content += line
            if i > 200:
                break

    if not content:
        return {"is_cross": False, "projects": [], "handoff_note": None, "status": None}

    try:
        fm = yaml.safe_load(content)
    except yaml.YAMLError:
        return {"is_cross": False, "projects": [], "handoff_note": None, "status": None}

    if not isinstance(fm, dict):
        return {"is_cross": False, "projects": [], "handoff_note": None, "status": None}

    cp = fm.get("cross_project")
    if not cp or not cp.get("enabled"):
        return {"is_cross": False, "projects": [], "handoff_note": None, "status": None}

    # 项目名映射（workspace path → human-readable name）
    # 用户可在 config/org.yaml 中自定义项目映射
    KNOWN_PROJECTS = {
        "my-project": "My Project",
        "my-lib": "My Library",
        "my-components": "My Components",
    }

    def _path_to_name(ws_path):
        """从 workspace 路径提取项目名。"""
        if not ws_path:
            return None
        dirname = os.path.basename(str(ws_path))
        # 先查映射表
        if dirname in KNOWN_PROJECTS:
            return KNOWN_PROJECTS[dirname]
        return dirname

    projects = []

    # 主项目（当前工作上下文所在项目）
    main_ws = fm.get("project")
    main_name = _path_to_name(main_ws) or "主项目"
    projects.append({
        "name": main_name,
        "role": "main",
        "workspace": main_ws or "",
    })

    # origin/source 项目（跨项目来源）
    source_ws = cp.get("source_project") or cp.get("origin_project")
    source_name = _path_to_name(source_ws)
    if source_name and source_name != main_name:
        projects.append({
            "name": source_name,
            "role": "source",
            "workspace": source_ws or "",
        })

    # fix 项目（修复目标）：优先用 workspace 路径解析项目名
    fix_ws = cp.get("fix_workspace") or cp.get("fix_project")
    fix_name = _path_to_name(fix_ws) or _path_to_name(cp.get("fix_project"))
    if fix_name and fix_name != main_name and fix_name != source_name:
        projects.append({
            "name": fix_name,
            "role": "fix",
            "workspace": fix_ws or "",
        })

    # additional_repos（如 order-component dep-bump）
    def _normalize_extra_role(raw_role):
        """把长描述转换为短标签。"""
        role_map = {
            "dep": "dep-bump",
            "dep-bump": "dep-bump",
            "被依赖": "dependency",
            "被依赖方": "dependency",
            "dependency": "dependency",
        }
        raw = (raw_role or "").lower()
        for key, val in role_map.items():
            if raw.startswith(key):
                return val
        return raw_role or "extra"

    for extra_repo in cp.get("additional_repos") or []:
        if isinstance(extra_repo, dict):
            er_name = extra_repo.get("name") or ""
            er_path = extra_repo.get("path") or ""
            er_role = _normalize_extra_role(extra_repo.get("role") or "")
            er_display = _path_to_name(er_path) or _path_to_name(er_name) or er_name
            if er_display and er_display not in {p["name"] for p in projects}:
                projects.append({
                    "name": er_display,
                    "role": er_role,
                    "workspace": er_path or er_name,
                })

    # projects_detail（增强明细：short/role_label/branch/files_changed/mr/mr_url/mr_status）
    # 若存在则以明细为准重建 projects 列表，workspace/role 缺失时回退到上面的 legacy 解析结果
    detail_list = cp.get("projects_detail") or []
    if isinstance(detail_list, list) and detail_list:
        legacy_by_key = {}
        for p in projects:
            legacy_by_key[p["name"]] = p
            if p["workspace"]:
                legacy_by_key[os.path.basename(str(p["workspace"]))] = p
        detailed = []
        for d in detail_list:
            if not isinstance(d, dict):
                continue
            d_key = str(d.get("name") or "")
            d_ws = str(d.get("workspace") or "")
            legacy = legacy_by_key.get(d_key) or legacy_by_key.get(os.path.basename(d_ws)) or {}
            display_name = _path_to_name(d_ws) or _path_to_name(d_key) or d_key
            if not display_name:
                continue
            detailed.append({
                "name": display_name,
                "short": d.get("short") or d_key or display_name,
                "role": d.get("role") or legacy.get("role") or "extra",
                "role_label": d.get("role_label") or "",
                "workspace": d_ws or legacy.get("workspace") or "",
                "branch": d.get("branch") or "",
                "files_changed": d.get("files_changed"),
                "lines_added": d.get("lines_added"),
                "lines_deleted": d.get("lines_deleted"),
                "mr": d.get("mr") or "",
                "mr_url": d.get("mr_url") or "",
                "mr_status": d.get("mr_status") or "",
            })
        if detailed:
            projects = detailed

    return {
        "is_cross": True,
        "projects": projects,
        "handoff_note": cp.get("handoff_note") or cp.get("handoff_prompt") or None,
        "status": cp.get("status") or None,
    }


# === 关联资源探测 ===
def _detect_file_in_devlog_dir(slug, filename):
    """探测 dev-logs/{slug}/{filename} 是否存在。通用探测逻辑。"""
    if not slug:
        return None
    # 策略1：精确匹配
    fp = os.path.join(DEVLOGS_DIR, slug, filename)
    if os.path.exists(fp):
        return fp
    # 策略2：日期前缀回退（前8位 = YYYYMMDD）
    date_prefix = slug[:8]
    if date_prefix.isdigit() and os.path.isdir(DEVLOGS_DIR):
        for entry in sorted(os.listdir(DEVLOGS_DIR)):
            if not entry.startswith(date_prefix):
                continue
            entry_path = os.path.join(DEVLOGS_DIR, entry)
            if not os.path.isdir(entry_path):
                continue
            fp = os.path.join(entry_path, filename)
            if os.path.exists(fp):
                return fp
    return None


def detect_devlog(slug):
    """探测 dev-logs/{slug}/devlog.md 是否存在。"""
    return _detect_file_in_devlog_dir(slug, "devlog.md")


def detect_plan(slug):
    """探测 dev-logs/{slug}/plan.md 是否存在。"""
    return _detect_file_in_devlog_dir(slug, "plan.md")


def detect_knowledge(slug):
    """探测 knowledge/{project}/ 下是否有对应项目目录。
    
    匹配策略（按优先级）：
    1. 精确缩写匹配：slug 尾段 → knowledge/{project}/
    2. 包含匹配回退：knowledge/ 下目录名包含 slug 尾段（忽略大小写、连字符）
    """
    if not slug or "_" not in slug:
        return None
    project = slug.rsplit("_", 1)[-1]
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
            # 去掉连字符后做包含匹配，例如 webactivity 匹配 myappactivity
            if proj_lower in d_clean or d_clean == proj_lower:
                d_path = os.path.join(KNOWLEDGE_DIR, d)
                if os.path.isdir(d_path):
                    return d_path
    return None


def detect_working_context(slug):
    if not slug:
        return None
    fp = os.path.join(WORKING_CONTEXT_DIR, "%s.md" % slug)
    return fp if os.path.exists(fp) else None


# === 历史均值对比 ===
def build_baseline(all_reports, current_mode):
    """计算同模式历史均值（不含本次），返回基线字典。"""
    others = [r for r in all_reports if r["mode"] == current_mode]
    if len(others) < 2:
        # 样本太少，回退到全局
        others = all_reports
    if not others:
        return None
    return {
        "sample_size": len(others),
        "mode": current_mode,
        "rollback_count": avg([r["rollback_count"] for r in others]),
        "user_corrections": avg([r["user_corrections"] for r in others]),
        "l2_issues_per_file": avg([r["issues_per_file"] for r in others]),
        "bugs_found_in_verify": avg([r["bugs_found_in_verify"] for r in others]),
        "files_changed": avg([r["files_changed"] for r in others]),
        "files_created": avg([r.get("files_created", 0) for r in others]),
        "files_deleted": avg([r.get("files_deleted", 0) for r in others]),
        "lines_added": avg([r["lines_added"] for r in others]),
        "lines_deleted": avg([r["lines_deleted"] for r in others]),
        "first_time_right_rate": round(
            sum(1 for r in others if r["first_time_right"]) / len(others), 2
        ) if others else 0,
    }


# === 异常检测（来源：metrics-rules.md「异常检测」表） ===
def detect_insights(report, baseline, total_samples):
    """返回 [{level, title, message}]。"""
    insights = []
    if total_samples < 3:
        insights.append({
            "level": "info",
            "title": "样本不足",
            "message": "历史数据少于 3 条（当前 %d 条），暂不做趋势对比。继续积累后会有更准确的对比。" % total_samples,
        })
        return insights

    if not baseline:
        return insights

    # 1. 回退异常
    rb = report["rollback_count"]
    rb_avg = baseline["rollback_count"]
    if rb >= 2 and rb_avg > 0 and rb > rb_avg * 2:
        insights.append({
            "level": "warn",
            "title": "回退频繁",
            "message": "本次回退 %d 次，历史均值 %.1f 次（同 %s 模式 %d 条样本）。建议加强需求理解和方案设计。" % (
                rb, rb_avg, baseline["mode"], baseline["sample_size"]
            ),
        })

    # 2. 质量异常（L2 问题/文件）
    ipf = report["issues_per_file"]
    ipf_avg = baseline["l2_issues_per_file"]
    if ipf >= 1.5 and ipf_avg > 0 and ipf > ipf_avg * 2:
        insights.append({
            "level": "warn",
            "title": "代码质量问题较多",
            "message": "本次 L2 问题/文件 %.2f，历史均值 %.2f。建议编码时加强自检。" % (ipf, ipf_avg),
        })

    # 3. 规模异常
    if report["files_changed"] > 10:
        insights.append({
            "level": "warn",
            "title": "改动范围较大",
            "message": "本次改动 %d 个文件。建议拆分为多个子需求或采用分批执行。" % report["files_changed"],
        })

    # 4. 用户纠正异常
    uc = report["user_corrections"]
    uc_avg = baseline["user_corrections"]
    if uc >= 3 and uc_avg > 0 and uc > uc_avg * 2:
        insights.append({
            "level": "warn",
            "title": "用户纠正较多",
            "message": "本次纠正 %d 次，历史均值 %.1f 次。建议在阶段 0/步骤 1 多澄清需求边界。" % (uc, uc_avg),
        })

    # 5. 验证 Bug 异常
    bugs = report["bugs_found_in_verify"]
    bugs_avg = baseline["bugs_found_in_verify"]
    if bugs >= 2 and bugs_avg >= 0 and bugs > max(bugs_avg * 2, 1):
        insights.append({
            "level": "warn",
            "title": "验证发现 Bug 较多",
            "message": "本次步骤 6 发现 %d 个 bug，历史均值 %.1f 个。建议步骤 5 编码时增加自验证。" % (bugs, bugs_avg),
        })

    # 6. 全部正常
    if not insights:
        if report["first_time_right"]:
            insights.append({
                "level": "ok",
                "title": "本次执行数据正常",
                "message": "✅ 一次做对，所有指标在历史均值合理范围内。继续保持。",
            })
        else:
            insights.append({
                "level": "info",
                "title": "本次执行数据正常",
                "message": "📊 各项指标在历史均值合理范围内，但未达成「一次做对」（有回退或 ≥2 次纠正）。",
            })

    return insights


# === 健康度评分（0-100，简单加权） ===
def compute_health_score(report):
    """综合评分：一次做对(40) + 回退控制(20) + 质量(20) + 规模合理(20)。"""
    score = 0
    if report["first_time_right"]:
        score += 40
    elif report["rollback_count"] == 0:
        score += 20

    # 回退控制
    if report["rollback_count"] == 0:
        score += 20
    elif report["rollback_count"] == 1:
        score += 10

    # 质量（L2 问题/文件）
    ipf = report["issues_per_file"]
    if ipf == 0:
        score += 20
    elif ipf < 0.5:
        score += 15
    elif ipf < 1:
        score += 10
    elif ipf < 2:
        score += 5

    # 规模合理（5-10 文件正常，过多扣分）
    files = report["files_changed"]
    if 1 <= files <= 6:
        score += 20
    elif files <= 10:
        score += 15
    elif files <= 15:
        score += 10
    else:
        score += 5

    return min(score, 100)


# === 主流程 ===
def build_payload(rid):
    """聚合所有数据，返回模板可消费的 dict。"""
    report, raw_info = load_one_report(rid)
    if not report:
        sys.exit("❌ 未找到度量报告：%s/%s.yaml" % (
            os.path.join(METRICS_DIR, "reports"), rid
        ))

    all_reports, health = load_all_reports()
    baseline = build_baseline(
        [r for r in all_reports if r["requirement_id"] != report["requirement_id"]],
        report["mode"],
    )
    insights = detect_insights(report, baseline, len(all_reports))
    health_score = compute_health_score(report)

    # 单需求场景使用 strict=True 重算 slug，避免跨需求误关联（例如同日期不同需求的工作上下文）
    # normalize() 中的 wc_slug 给 dashboard 全局聚合用，可宽松匹配；这里需要严格一致性
    strict_slug = resolve_working_context_slug(
        report["requirement_id"],
        report.get("start_date"),
        report.get("branch"),
        report.get("title"),
        strict=True,
    )
    slug = strict_slug or report["requirement_id"]
    corrections = extract_corrections(slug) if strict_slug else []
    rollbacks_detail = extract_rollbacks(slug) if strict_slug else []

    devlog_path = detect_devlog(slug)
    plan_path = detect_plan(slug)
    knowledge_path = detect_knowledge(slug)
    wc_path = detect_working_context(strict_slug) if strict_slug else None

    # 跨项目信息
    cross_project_info = extract_cross_project_info(strict_slug or slug) if (strict_slug or slug) else {}

    # 迭代历史（含 per-iteration 对话轮次）
    iteration_rounds = []
    raw_iter_history = (raw_info or {}).get("raw", {}).get("iteration_history") or {}
    if isinstance(raw_iter_history, dict):
        for num in sorted(raw_iter_history.keys(), key=lambda k: int(k) if str(k).isdigit() else 0):
            entry = raw_iter_history[num]
            iteration_rounds.append({
                "num": int(num) if str(num).isdigit() else num,
                "date": entry.get("date") or "",
                "summary": entry.get("summary") or "",
                "rounds": entry.get("conversation_rounds"),  # 可选：未来版本按此采集
            })

    return {
        "report": report,
        "baseline": baseline,
        "insights": insights,
        "health_score": health_score,
        "corrections": corrections,
        "rollbacks_detail": rollbacks_detail,
        "cross_project": cross_project_info,
        "iteration_breakdown": {
            "iteration": report.get("iteration", 1),
            "total_rounds": report.get("conversation_rounds", 0),
            "per_iteration": iteration_rounds,
        },
        "links": {
            "working_context": _to_relative_link(wc_path),
            "devlog": _to_relative_link(devlog_path),
            "plan": _to_relative_link(plan_path),
            "knowledge_dir": _to_relative_link(knowledge_path),
            "dashboard": _to_relative_link(os.path.join(METRICS_DIR, "dashboard.html")),
            "task_url": report.get("task_url") or "",
            "doc_url": report.get("doc_url") or "",
        },
        "global_stats": {
            "total_requirements": len(all_reports),
            "health": health,
        },
        "generated_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    }


def _to_relative_link(abs_path):
    """把绝对路径转为 file:// 链接（HTML 中可点击）。不存在返回空字符串。"""
    if not abs_path or not os.path.exists(abs_path):
        return ""
    return "file://" + abs_path


def render_html(payload, rid):
    """读模板 + 替换占位符 + 写文件，返回输出路径。"""
    if not os.path.exists(TEMPLATE):
        sys.exit("❌ 未找到模板：%s" % TEMPLATE)

    with open(TEMPLATE, "r", encoding="utf-8") as f:
        tpl = f.read()

    out_dir = FLOW_REPORTS_DIR
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "%s.html" % rid)

    html = tpl.replace(
        "__FLOW_DATA__",
        json.dumps(payload, ensure_ascii=False, default=str),
    )
    html = html.replace("__HOME_DIR__", HOME)
    html = html.replace("__GENERATED_AT__", payload["generated_at"])
    html = html.replace("__REQUIREMENT_ID__", rid)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)
    return out_path


def open_in_browser(path):
    """跨平台打开浏览器，失败时降级为打印路径。返回是否成功打开。"""
    if sys.platform == "darwin":
        opener = "open"
    elif sys.platform.startswith("linux"):
        opener = "xdg-open"
    elif sys.platform == "win32":
        opener = "start"
    else:
        opener = None

    if not opener:
        print("提示：未知平台，请手动打开 %s" % path)
        return False

    try:
        if opener == "start":
            subprocess.run([opener, "", path], shell=True, check=False)
        else:
            subprocess.run([opener, path], check=False)
        return True
    except (FileNotFoundError, OSError) as e:
        print("提示：自动打开失败（%s），请手动打开 %s" % (e, path))
        return False


def main():
    parser = argparse.ArgumentParser(description="dev-flow 单需求复盘报告生成器")
    parser.add_argument("requirement_id", help="需求 ID（即 reports/{ID}.yaml 的文件名）")
    parser.add_argument("--no-open", action="store_true",
                        help="仅生成 HTML，不打开浏览器（默认会自动打开）")
    args = parser.parse_args()

    rid = args.requirement_id

    try:
        payload = build_payload(rid)
        out_path = render_html(payload, rid)
    except SystemExit:
        raise
    except Exception as e:  # 失败容忍：脚本异常仅打印 stderr，不抛
        sys.stderr.write("❌ 生成单需求报告失败：%s\n" % e)
        import traceback
        traceback.print_exc()
        sys.exit(1)

    print("OK flow-report=%s" % out_path)
    print("  health-score=%d  insights=%d  corrections=%d  rollbacks=%d" % (
        payload["health_score"], len(payload["insights"]),
        len(payload["corrections"]), len(payload["rollbacks_detail"]),
    ))

    if not args.no_open:
        opened = open_in_browser(out_path)
        if opened:
            print("  opened in browser")
        else:
            print("  please open manually: %s" % out_path)


if __name__ == "__main__":
    main()
