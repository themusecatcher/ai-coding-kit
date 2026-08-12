#!/usr/bin/env node
/**
 * summarize-result.js
 *
 * 把 compat-check.js 的 JSON 结果转成易读的人类摘要：
 *   - findings 严重度分布
 *   - 按 rule_id 分类的 top N
 *   - skipped 的 reason 分类
 *   - 用户配置的 rules.off / polyfills 是否真正生效（健康度自检）
 *
 * 使用：node scripts/summarize-result.js <compat-check-output.json>
 *
 * 设计哲学：可程序化的统计逻辑用代码，规则解释才用 LLM。
 * 来自端到端验证项目时的需求沉淀。
 *
 * 2026-05-15 修订（v2）：健康度自检改为「真实反查」——
 *   1. 读 report.projectRoot/.browser-compat.json
 *   2. 提取 rules.off 列表 + ignore 数组
 *   3. 与 skipped 集合比对：每条 off 必须在 skipped 中（否则即配置失效）
 *   旧版仅做"常见名字未出现在 findings 即 ✅"的弱检查（祖父原则：真有用 > 显得专业）。
 */

const fs = require('fs');
const path = require('path');

const inputPath = process.argv[2];
if (!inputPath) {
  console.error('用法: node summarize-result.js <compat-check-output.json>');
  process.exit(1);
}

let report;
try {
  report = JSON.parse(fs.readFileSync(inputPath, 'utf-8'));
} catch (err) {
  console.error('读取/解析失败: ' + err.message);
  process.exit(1);
}

const findings = report.findings || [];
const skipped = report.skipped || [];
const baseline = report.baseline || {};
const projectRoot = report.projectRoot || null;

// ─── 严重度分布 ───
const sevCnt = { CRITICAL: 0, WARNING: 0, INFO: 0 };
findings.forEach((f) => {
  sevCnt[f.severity] = (sevCnt[f.severity] || 0) + 1;
});

// ─── 按 rule_id 分类 ───
const ruleCnt = {};
findings.forEach((f) => {
  ruleCnt[f.rule_id] = (ruleCnt[f.rule_id] || 0) + 1;
});

// ─── skipped reason 分类 ───
const reasonCnt = {};
skipped.forEach((s) => {
  reasonCnt[s.reason] = (reasonCnt[s.reason] || 0) + 1;
});

// ─── 输出 ───
console.log('═══════════════════════════════════════════════════');
console.log('扫描目标:', inputPath);
console.log('projectRoot:', projectRoot || '(未提供)');
console.log('baseline:', baseline.level, '(source: ' + baseline.source + ')');
console.log('───────────────────────────────────────────────────');
console.log('findings 总数:', findings.length, JSON.stringify(sevCnt));
console.log('skipped  总数:', skipped.length, JSON.stringify(reasonCnt));

if (findings.length > 0) {
  console.log('');
  console.log('--- findings 按 rule_id 分类（Top 10）---');
  Object.entries(ruleCnt)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .forEach(([k, v]) => {
      console.log('  ' + String(v).padStart(4) + '\t' + k);
    });
}

// ─── 用户配置健康度自检（真实反查）───
console.log('');
console.log('--- 用户配置健康度自检（真实反查）---');

// 归一化函数：与 rule-filter.js 保持一致
function normalizeRuleKey(name) {
  if (typeof name !== 'string') return '';
  return name
    .toLowerCase()
    .replace(/^no-/, '')
    .replace(/^warn-/, '')
    .replace(/prototype/g, '')
    .replace(/[^a-z0-9]/g, '');
}

let healthCheckRun = false;
if (projectRoot) {
  const compatJsonPath = path.join(projectRoot, '.browser-compat.json');
  if (fs.existsSync(compatJsonPath)) {
    try {
      const cfg = JSON.parse(fs.readFileSync(compatJsonPath, 'utf-8'));
      // 找到「实际生效的子配置」（处理集中式 projects）
      let activeCfg = cfg;
      if (cfg.projects && typeof cfg.projects === 'object') {
        // 尝试通过 baseline.source 反推匹配的 projectName
        const sourceMatch = (baseline.source || '').match(/projects\.(\S+)/);
        const projName = sourceMatch ? sourceMatch[1] : path.basename(projectRoot);
        if (cfg.projects[projName]) activeCfg = cfg.projects[projName];
      }

      const offNames = Object.entries(activeCfg.rules || {})
        .filter(([k, v]) => v === 'off' && !k.startsWith('_'))
        .map(([k]) => k);

      const explicitIgnoreIds = (Array.isArray(activeCfg.ignore) ? activeCfg.ignore : [])
        .filter((x) => x && typeof x === 'object' && x.rule_id)
        .map((x) => x.rule_id);

      const userOffPlusIgnore = [...offNames, ...explicitIgnoreIds];

      if (userOffPlusIgnore.length === 0) {
        console.log('  ℹ️  用户配置中无 rules.off 或 ignore 规则项，跳过反查。');
      } else {
        healthCheckRun = true;
        console.log(
          '  共反查 ' + userOffPlusIgnore.length + ' 条用户豁免项（rules.off + ignore.rule_id）'
        );

        // 取所有真实 rule.id（来自 skipped + findings + ENABLED_MATRIX 兜底）
        let knownRuleIds = new Set();
        try {
          const rf = require(path.join(__dirname, 'lib', 'rule-filter.js'));
          Object.keys(rf.ENABLED_MATRIX || {}).forEach((id) => knownRuleIds.add(id));
        } catch (e) {
          // 找不到 rule-filter 时，退化到从结果集合中拼凑
        }
        skipped.forEach((s) => s.rule_id && knownRuleIds.add(s.rule_id));
        findings.forEach((f) => f.rule_id && knownRuleIds.add(f.rule_id));

        // skipped 里所有以 ignore: 开头的（即 user ignore 命中的）规则名集合
        const skippedByIgnoreRuleIds = new Set(
          skipped.filter((s) => /^ignore:/.test(s.reason || '')).map((s) => s.rule_id)
        );
        const skippedKeys = new Set(
          [...skippedByIgnoreRuleIds].map((id) => normalizeRuleKey(id))
        );

        const failed = [];
        const succeeded = [];
        const unmappable = [];

        for (const userName of userOffPlusIgnore) {
          const userKey = normalizeRuleKey(userName);
          // 是否在已知 rule.id 中能找到模糊对应？
          const matchedRuleIds = [...knownRuleIds].filter((id) => {
            const idKey = normalizeRuleKey(id);
            return idKey === userKey || idKey.includes(userKey) || userKey.includes(idKey);
          });
          if (matchedRuleIds.length === 0) {
            // 用户写的名字根本不在脚本规则集里——这是合法的（如 IntersectionObserver
            // 在脚本规则集里没有对应规则），不算错配。但记录为「无法反查」。
            unmappable.push(userName);
            continue;
          }
          // 检查 skipped 里是否真的包含这些 rule.id
          const hits = matchedRuleIds.filter((id) => skippedByIgnoreRuleIds.has(id));
          if (hits.length > 0) {
            succeeded.push({ user: userName, ruleIds: hits });
          } else {
            failed.push({ user: userName, expected: matchedRuleIds });
          }
        }

        console.log('  ✅ 真实生效:', succeeded.length);
        succeeded.slice(0, 5).forEach((s) => {
          console.log('     ' + s.user + ' → ' + s.ruleIds.join(', '));
        });

        if (failed.length > 0) {
          console.log('  🔴 配置失效（用户写了 off 但 rule-filter 没跳过）:', failed.length);
          failed.slice(0, 5).forEach((f) => {
            console.log(
              '     ' + f.user + '（期望豁免: ' + f.expected.join(', ') + '，实际未豁免）'
            );
          });
        }

        if (unmappable.length > 0) {
          console.log(
            '  ℹ️  无对应规则（用户写的名字脚本规则集没覆盖，写了等于无操作）:',
            unmappable.length
          );
          if (unmappable.length <= 8) {
            unmappable.forEach((n) => console.log('     - ' + n));
          } else {
            unmappable.slice(0, 5).forEach((n) => console.log('     - ' + n));
            console.log('     ... 共 ' + unmappable.length + ' 条');
          }
        }
      }
    } catch (err) {
      console.log('  ⚠️ 解析 .browser-compat.json 失败:', err.message);
    }
  } else {
    console.log('  ℹ️  projectRoot 下无 .browser-compat.json，跳过反查。');
  }
} else {
  console.log('  ⚠️ report.projectRoot 字段缺失（请升级 compat-check.js ≥ 2026-05-15 fuzzy fix 版本）');
}

if (!healthCheckRun) {
  console.log('  （未执行真实反查；conclusion 仅基于 findings 数量）');
}

console.log('');
console.log('结论:', report.summary && report.summary.conclusion);
console.log('═══════════════════════════════════════════════════');
