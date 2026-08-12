#!/bin/bash
# validate-step7.sh — 步骤 7 确定性门控（单脚本，串联校验）
# 设计哲学：确定性用代码。REQUIRED 字段硬编码在 python dict，AI 无需心算。
# 用法: bash validate-step7.sh <json-file> [yaml-file]
# 退出码: 0=通过 / 1=校验失败

JSON_FILE="${1:-}"
YAML_FILE="${2:-}"

python3 << PYEOF
import json, sys, os

errors = []

# ===== 阶段 1：完成标记 JSON 校验 =====
if not os.path.exists("$JSON_FILE"):
    errors.append("json_file_not_found:$JSON_FILE")
else:
    with open("$JSON_FILE") as f:
        d = json.load(f)
    out = d.get("outputs", {})

    REQUIRED = {
        "debug_code_cleaned": True,
        "l2_review_result": "__NONEMPTY__",
        "devlog_generated": True,
        "knowledge_updated": True,
        "metrics_report_generated": True,
        "metrics_file": "__NONEMPTY__",
    }

    for field, expected in REQUIRED.items():
        val = out.get(field)
        if val is None:
            errors.append(f"json_missing:{field}")
        elif expected is True and val is not True:
            errors.append(f"json_not_true:{field}={val}")
        elif expected == "__NONEMPTY__" and (val == "" or val is None):
            errors.append(f"json_empty:{field}")

    # ===== 阶段 2：度量 YAML 校验（仅当 JSON 中 metrics_report_generated=true 时） =====
    if out.get("metrics_report_generated") is True and "$YAML_FILE" != "" and os.path.exists("$YAML_FILE"):
        import yaml
        with open("$YAML_FILE") as f:
            yd = yaml.safe_load(f)

        # 扁平 Tier 1 字段（与 gen-dashboard.py REQUIRED_FIELDS 和
        # validate-metrics-yaml.sh 保持严格一致。2026-06-05 从嵌套 schema 迁移）
        YAML_REQUIRED = [
            "requirement_id", "mode", "complexity",
            "files_changed", "lines_added", "lines_deleted",
            "rollback_count", "user_corrections", "first_time_right",
            "l2_issues_found", "bugs_found_in_verify",
        ]

        for field in YAML_REQUIRED:
            val = yd.get(field) if isinstance(yd, dict) else None
            if val is None or val == "":
                errors.append(f"yaml_missing:{field}")

if errors:
    print(json.dumps({"result": "fail", "violations": errors}))
    sys.exit(1)
else:
    print(json.dumps({"result": "pass"}))
    sys.exit(0)
PYEOF
