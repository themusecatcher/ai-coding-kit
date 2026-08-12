/**
 * output-validator.js
 *
 * 手写最小 JSON Schema 校验器（零外部依赖），仅覆盖
 * schemas/finding.schema.json 中的关键字段。
 *
 * 校验失败 → 返回错误数组（调用方决定是否阻断）。
 */

const ALLOWED_SEVERITY = ['CRITICAL', 'WARNING', 'INFO'];
const ALLOWED_TYPE = ['js', 'css'];
const ALLOWED_LEVEL = ['conservative', 'standard', 'aggressive'];
const ALLOWED_CONCLUSION = ['approve', 'warning', 'block'];
const ALLOWED_SCAN_SCOPE = ['diff', 'staged', 'file', 'directory'];

function validateReport(report) {
  const errors = [];

  if (!report || typeof report !== 'object') {
    return ['report 必须是对象'];
  }
  if (report.skill !== 'browser-compat') {
    errors.push(`skill 必须是 'browser-compat'，实际: ${JSON.stringify(report.skill)}`);
  }
  if (report.scan_scope !== undefined && !ALLOWED_SCAN_SCOPE.includes(report.scan_scope)) {
    errors.push(`scan_scope 非法: ${JSON.stringify(report.scan_scope)}`);
  }

  // baseline
  if (report.baseline !== undefined && report.baseline !== null) {
    const b = report.baseline;
    if (!ALLOWED_LEVEL.includes(b.level)) {
      errors.push(`baseline.level 非法: ${JSON.stringify(b.level)}`);
    }
    if (typeof b.source !== 'string' || !b.source) {
      errors.push('baseline.source 必填且为非空字符串');
    }
  }

  // findings
  if (!Array.isArray(report.findings)) {
    errors.push('findings 必须是数组');
  } else {
    report.findings.forEach((f, i) => {
      if (!ALLOWED_SEVERITY.includes(f.severity)) {
        errors.push(`findings[${i}].severity 非法: ${JSON.stringify(f.severity)}`);
      }
      if (!ALLOWED_TYPE.includes(f.type)) {
        errors.push(`findings[${i}].type 非法: ${JSON.stringify(f.type)}`);
      }
      if (typeof f.rule_id !== 'string' || !f.rule_id) {
        errors.push(`findings[${i}].rule_id 必填且为非空字符串`);
      }
      if (typeof f.file !== 'string' || !f.file) {
        errors.push(`findings[${i}].file 必填且为非空字符串`);
      }
      if (!Number.isInteger(f.line) || f.line < 1) {
        errors.push(`findings[${i}].line 必须是 >= 1 的整数，实际: ${JSON.stringify(f.line)}`);
      }
      if (typeof f.message !== 'string' || !f.message) {
        errors.push(`findings[${i}].message 必填`);
      }
    });
  }

  // skipped
  if (report.skipped !== undefined) {
    if (!Array.isArray(report.skipped)) {
      errors.push('skipped 必须是数组');
    } else {
      report.skipped.forEach((s, i) => {
        if (typeof s.rule_id !== 'string' || !s.rule_id) {
          errors.push(`skipped[${i}].rule_id 必填`);
        }
        if (typeof s.reason !== 'string') {
          errors.push(`skipped[${i}].reason 必填`);
        }
      });
    }
  }

  // summary
  if (!report.summary || typeof report.summary !== 'object') {
    errors.push('summary 必填');
  } else {
    const s = report.summary;
    for (const k of ['critical', 'warning', 'info']) {
      if (!Number.isInteger(s[k]) || s[k] < 0) {
        errors.push(`summary.${k} 必须是非负整数`);
      }
    }
    if (!ALLOWED_CONCLUSION.includes(s.conclusion)) {
      errors.push(`summary.conclusion 非法: ${JSON.stringify(s.conclusion)}`);
    }

    // 一致性：summary 计数应与 findings 实际数量匹配
    if (Array.isArray(report.findings)) {
      const actualCritical = report.findings.filter((f) => f.severity === 'CRITICAL').length;
      const actualWarning = report.findings.filter((f) => f.severity === 'WARNING').length;
      if (s.critical !== actualCritical) {
        errors.push(`summary.critical=${s.critical} 与 findings 实际 CRITICAL 数量 ${actualCritical} 不一致`);
      }
      if (s.warning !== actualWarning) {
        errors.push(`summary.warning=${s.warning} 与 findings 实际 WARNING 数量 ${actualWarning} 不一致`);
      }
    }
  }

  return errors;
}

module.exports = { validateReport };
