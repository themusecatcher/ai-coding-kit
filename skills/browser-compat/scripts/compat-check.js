#!/usr/bin/env node
/**
 * browser-compat 核心检测脚本
 *
 * 基于 远程知识库 `skillhub/browser-compat/scripts/compat-check.js` 精简实现，
 * 规则库与 `~/.codebuddy/rules/浏览器兼容性规范.mdc` 保持一致。
 *
 * 使用方式：
 *   node compat-check.js <path>          # 扫描指定文件/目录
 *   node compat-check.js --diff          # 扫描 git diff
 *   node compat-check.js --staged        # 扫描 git staged 文件
 *
 * 退出码：
 *   0 - 无违规或仅 WARNING（approve/warning）
 *   1 - 存在 CRITICAL 违规（block）
 *   2 - 脚本执行错误
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// 项目级配置加载 + 规则过滤（Stage 2/3 接入）
const { loadConfig } = require('./lib/load-config');
const { filterRules, shouldSkipPath } = require('./lib/rule-filter');
// gap 上下文扫描器（Stage 4 接入）
const { scanGapWithContext } = require('./lib/gap-context-scanner');
// 输出 schema 校验（Stage 5 接入）
const { validateReport } = require('./lib/output-validator');

// ===== 规则库（与 rules/浏览器兼容性规范.mdc 保持一致）=====
// 元门控由 scripts/meta/validate-rules-sync.sh 守护双向一致性

const JS_RULES = [
  {
    id: 'no-array-at',
    severity: 'CRITICAL',
    // 匹配 .at(-1) / .at(0) 但排除 object.at 这种属性访问场景（注意：正则有误报率）
    pattern: /\b(\w+)\.at\(\s*-?\d+\s*\)/g,
    message: '使用了 Array.prototype.at()',
    reason: 'Safari 15.4+ / Chrome 92+ 才支持，项目基线不支持',
    fixHint: '改用 arr[arr.length - 1] 或 arr.slice(-1)[0]',
  },
  {
    id: 'no-structured-clone',
    severity: 'CRITICAL',
    pattern: /\bstructuredClone\s*\(/g,
    message: '使用了 structuredClone()',
    reason: 'Safari 15.4+ / Chrome 98+ 才支持',
    fixHint: '改用 JSON.parse(JSON.stringify(x)) 或 lodash.cloneDeep',
  },
  {
    id: 'no-object-hasown',
    severity: 'CRITICAL',
    pattern: /\bObject\.hasOwn\s*\(/g,
    message: '使用了 Object.hasOwn()',
    reason: 'Safari 15.4+ / Chrome 93+ 才支持',
    fixHint: '改用 Object.prototype.hasOwnProperty.call(obj, key)',
  },
  {
    id: 'no-array-tosorted',
    severity: 'CRITICAL',
    pattern: /\b(\w+)\.(toSorted|toReversed|toSpliced)\s*\(/g,
    message: '使用了 Array.prototype.toSorted/toReversed/toSpliced',
    reason: 'Safari 16+ / Chrome 110+ 才支持',
    fixHint: '改用 [...arr].sort() / [...arr].reverse()',
  },
  {
    id: 'no-object-groupby',
    severity: 'CRITICAL',
    pattern: /\b(Object|Map)\.groupBy\s*\(/g,
    message: '使用了 Object.groupBy / Map.groupBy',
    reason: 'Safari 17.4+ / Chrome 117+ 才支持',
    fixHint: '改用 arr.reduce 实现分组',
  },
  {
    id: 'no-promise-withresolvers',
    severity: 'CRITICAL',
    pattern: /\bPromise\.withResolvers\s*\(/g,
    message: '使用了 Promise.withResolvers',
    reason: 'Safari 17.4+ / Chrome 119+ 才支持',
    fixHint: '手写：let resolve, reject; new Promise((r, j) => { resolve=r; reject=j; })',
  },
  {
    id: 'no-crypto-randomuuid',
    severity: 'CRITICAL',
    pattern: /\bcrypto\.randomUUID\s*\(/g,
    message: '使用了 crypto.randomUUID()',
    reason: 'Safari 15.4+ / Chrome 92+ 才支持',
    fixHint: '改用 uuid npm 包的 v4()',
  },
];

const CSS_RULES = [
  {
    id: 'no-has-selector',
    severity: 'CRITICAL',
    pattern: /:has\s*\(/g,
    message: '使用了 :has() 选择器',
    reason: 'Safari 15.4+ / Chrome 105+ 才支持',
    fixHint: '改用 JS 逻辑 + className 切换',
  },
  {
    id: 'no-container-type',
    severity: 'CRITICAL',
    pattern: /\bcontainer-type\s*:/g,
    message: '使用了 container-type（容器查询）',
    reason: 'Safari 16+ / Chrome 105+ 才支持',
    fixHint: '改用 ResizeObserver + JS 计算',
  },
  {
    id: 'no-color-mix',
    severity: 'CRITICAL',
    pattern: /\bcolor-mix\s*\(/g,
    message: '使用了 color-mix()',
    reason: 'Safari 16.2+ / Chrome 111+ 才支持',
    fixHint: '用 CSS 变量预计算颜色',
  },
  {
    id: 'no-subgrid',
    severity: 'CRITICAL',
    pattern: /\bgrid-template-\w+\s*:\s*subgrid\b/g,
    message: '使用了 subgrid',
    reason: 'Safari 16+ / Chrome 117+ 才支持',
    fixHint: '改用嵌套 grid 或重新设计布局',
  },
  {
    id: 'no-flexbox-gap',
    severity: 'CRITICAL',
    // 专用扫描器：按 display 上下文区分 flex(CRITICAL) / grid(不报) / unknown(WARNING)
    pattern: /\bgap\s*:\s*[\d.]+/g,
    message: '可能使用了 Flexbox gap',
    reason: 'Safari 14.1 以下 Flexbox 不支持 gap',
    fixHint: '用 margin + 负 margin 抵消；或确认上下文是 Grid（Grid 的 gap Safari 10.1+ 支持）',
    specialScanner: 'gap-context',
  },
  {
    id: 'no-aspect-ratio',
    severity: 'CRITICAL',
    pattern: /\baspect-ratio\s*:/g,
    message: '使用了 aspect-ratio',
    reason: 'Safari 15.4+ / Chrome 88+ 才支持',
    fixHint: '用 padding-bottom 百分比技巧',
  },
  {
    id: 'no-inset-shorthand',
    severity: 'CRITICAL',
    // 匹配 inset: 属性（避免匹配 inset() 函数或 box-shadow inset 关键字）
    pattern: /(^|[\s;{])inset\s*:\s*[^;]+/gm,
    message: '使用了 inset 简写',
    reason: 'Safari 14.1+ 才支持',
    fixHint: '展开为 top/right/bottom/left',
  },
  {
    id: 'no-text-wrap',
    severity: 'CRITICAL',
    pattern: /\btext-wrap\s*:\s*(balance|pretty)/g,
    message: '使用了 text-wrap: balance/pretty',
    reason: 'Safari 17.5+ / Chrome 114+ 才支持',
    fixHint: '不使用，让浏览器默认换行',
  },
  {
    id: 'no-css-layer',
    severity: 'CRITICAL',
    pattern: /@layer\b/g,
    message: '使用了 @layer 级联层',
    reason: 'Safari 15.4+ / Chrome 99+ 才支持',
    fixHint: '用选择器优先级控制层级',
  },
  {
    id: 'no-accent-color',
    severity: 'CRITICAL',
    pattern: /\baccent-color\s*:/g,
    message: '使用了 accent-color',
    reason: 'Safari 15.4+ / Chrome 93+ 才支持',
    fixHint: '自定义 checkbox/radio 样式',
  },
  {
    id: 'warn-backdrop-filter',
    severity: 'WARNING',
    // 只报告没有 -webkit- 前缀的
    pattern: /(?<!-webkit-)backdrop-filter\s*:/g,
    message: '使用了 backdrop-filter 但没有 -webkit- 前缀',
    reason: 'Safari 需 -webkit-backdrop-filter 前缀，且不支持时需兜底',
    fixHint: '添加 -webkit-backdrop-filter + @supports 降级',
  },
];

// ===== 扫描引擎 =====

function isJsFile(file) {
  return /\.(js|jsx|ts|tsx|mjs|cjs)$/.test(file);
}

function isCssFile(file) {
  return /\.(css|scss|sass|less|module\.css|module\.scss)$/.test(file);
}

// 判断 match 位置是否落在块注释 /* ... */ 之内（跨行也支持）
function isInsideBlockComment(content, matchIndex) {
  const before = content.slice(0, matchIndex);
  const lastOpen = before.lastIndexOf('/*');
  const lastClose = before.lastIndexOf('*/');
  // 最近的 /* 在 */ 之后 → match 落在未闭合的块注释内
  return lastOpen > lastClose;
}

// 判断整行是否为注释行（含单行 // / JSDoc * / HTML <!-- / 同行完整 /* ... */ 块注释）
function isCommentLine(lineContent) {
  const trimmed = lineContent.trim();
  if (!trimmed) return false;
  // 单行 // 注释 / JSDoc 延续行 * / HTML 注释起止
  if (/^(\/\/|\*|<!--|-->)/.test(trimmed)) return true;
  // 同行完整块注释 /* xxx */（前后可能有缩进）
  if (/^\/\*.*\*\/\s*$/.test(trimmed)) return true;
  // 整行都在块注释中（// 或 /* 开头但无闭合 → 延续行由 isInsideBlockComment 判断）
  if (/^\/\*/.test(trimmed) && !trimmed.includes('*/')) return true;
  return false;
}

function scanContent(content, filePath, rules) {
  const findings = [];
  const lines = content.split('\n');

  for (const rule of rules) {
    // 专用扫描器分发：gap-context
    if (rule.specialScanner === 'gap-context') {
      const gapResults = scanGapWithContext(content);
      for (const r of gapResults) {
        // 行级豁免与注释检查（与通用逻辑一致）
        const lineContent = lines[r.line - 1] || '';
        if (lineContent.includes('@compat-ignore')) continue;
        if (isCommentLine(lineContent)) continue;
        if (isInsideBlockComment(content, r.matchIndex)) continue;

        findings.push({
          severity: r.severity,
          type: 'css',
          rule_id: rule.id,
          file: filePath,
          line: r.line,
          code_snippet: r.code_snippet,
          message:
            r.contextHint === 'flex'
              ? rule.message
              : '发现 gap 但未明确上下文是 flex/grid',
          reason:
            r.contextHint === 'flex'
              ? rule.reason
              : '无法从同块内 display 声明推断上下文（SCSS 嵌套继承未实现）',
          fix_hint: rule.fixHint,
        });
      }
      continue;
    }

    // 通用正则扫描路径
    const regex = new RegExp(rule.pattern.source, rule.pattern.flags);
    let match;
    while ((match = regex.exec(content)) !== null) {
      const upToMatch = content.slice(0, match.index);
      const lineNum = upToMatch.split('\n').length;
      const lineContent = lines[lineNum - 1] || '';

      // 行级豁免
      if (lineContent.includes('@compat-ignore')) continue;
      // 注释行跳过（整行注释 + 同行完整块注释）
      if (isCommentLine(lineContent)) continue;
      // match 位置在跨行块注释 /* ... */ 内 → 跳过
      if (isInsideBlockComment(content, match.index)) continue;

      findings.push({
        severity: rule.severity,
        type: isCssFile(filePath) ? 'css' : 'js',
        rule_id: rule.id,
        file: filePath,
        line: lineNum,
        code_snippet: lineContent.trim(),
        message: rule.message,
        reason: rule.reason,
        fix_hint: rule.fixHint,
      });
    }
  }
  return findings;
}

function scanFile(filePath, ctx) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    let rules = isJsFile(filePath) ? JS_RULES : isCssFile(filePath) ? CSS_RULES : null;
    if (!rules) return [];
    if (ctx && ctx.activeRulesByType) {
      rules = isJsFile(filePath) ? ctx.activeRulesByType.js : ctx.activeRulesByType.css;
    }
    return scanContent(content, filePath, rules);
  } catch (err) {
    console.error(`[browser-compat] 读取文件失败: ${filePath}`, err.message);
    return [];
  }
}

function scanDirectory(dir, ctx) {
  const findings = [];
  const walk = (d) => {
    const entries = fs.readdirSync(d, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(d, entry.name);
      if (entry.isDirectory()) {
        if (['node_modules', '.git', 'dist', 'build', '.next'].includes(entry.name)) continue;
        walk(full);
      } else if (isJsFile(full) || isCssFile(full)) {
        if (ctx && shouldSkipPath(full, ctx.config.excludePaths, ctx.config.includePaths, ctx.projectRoot)) {
          continue;
        }
        findings.push(...scanFile(full, ctx));
      }
    }
  };
  walk(dir);
  return findings;
}

function scanGitDiff(staged, ctx) {
  const cmd = staged ? 'git diff --staged --name-only' : 'git diff --name-only';
  const files = execSync(cmd, { encoding: 'utf-8' })
    .split('\n')
    .filter((f) => f && (isJsFile(f) || isCssFile(f)));
  const findings = [];
  for (const file of files) {
    if (fs.existsSync(file)) {
      if (ctx && shouldSkipPath(file, ctx.config.excludePaths, ctx.config.includePaths, ctx.projectRoot)) {
        continue;
      }
      findings.push(...scanFile(file, ctx));
    }
  }
  return findings;
}

// ===== 主入口 =====

function buildContext(target) {
  // 推断 projectRoot：从 target 向上找含 package.json 或 .browser-compat.json 或 .git 的目录
  let projectRoot = process.cwd();
  if (target && fs.existsSync(target)) {
    let cur = path.resolve(fs.statSync(target).isDirectory() ? target : path.dirname(target));
    const root = path.parse(cur).root;
    while (cur !== root) {
      if (
        fs.existsSync(path.join(cur, 'package.json')) ||
        fs.existsSync(path.join(cur, '.browser-compat.json')) ||
        fs.existsSync(path.join(cur, '.git'))
      ) {
        projectRoot = cur;
        break;
      }
      cur = path.dirname(cur);
    }
  }

  const config = loadConfig(projectRoot);
  const jsResult = filterRules(JS_RULES, config);
  const cssResult = filterRules(CSS_RULES, config);

  return {
    projectRoot,
    config,
    activeRulesByType: { js: jsResult.activeRules, css: cssResult.activeRules },
    skipped: [...jsResult.skipped, ...cssResult.skipped],
  };
}

function main() {
  const args = process.argv.slice(2);
  let findings = [];
  let scanScope = 'directory';

  if (args.length === 0) {
    console.error('用法: node compat-check.js <path> | --diff | --staged | --print-baseline');
    process.exit(2);
  }

  // --print-baseline：仅打印当前项目基线判定（用于调试 / 流程展示）
  if (args[0] === '--print-baseline') {
    const ctx = buildContext(args[1] || process.cwd());
    console.log(JSON.stringify({ projectRoot: ctx.projectRoot, baseline: ctx.config.baseline, polyfills: ctx.config.polyfills, ignore: ctx.config.ignore }, null, 2));
    process.exit(0);
  }

  let ctx;
  if (args[0] === '--diff' || args[0] === '--staged') {
    ctx = buildContext(process.cwd());
    scanScope = args[0] === '--staged' ? 'staged' : 'diff';
    findings = scanGitDiff(args[0] === '--staged', ctx);
  } else {
    const target = args[0];
    if (!fs.existsSync(target)) {
      console.error(`路径不存在: ${target}`);
      process.exit(2);
    }
    ctx = buildContext(target);
    const stat = fs.statSync(target);
    if (stat.isDirectory()) {
      scanScope = 'directory';
      findings = scanDirectory(target, ctx);
    } else {
      scanScope = 'file';
      // 单文件路径过滤（用户显式指定时也要尊重 excludePaths）
      if (!shouldSkipPath(target, ctx.config.excludePaths, ctx.config.includePaths, ctx.projectRoot)) {
        findings = scanFile(target, ctx);
      }
    }
  }

  const critical = findings.filter((f) => f.severity === 'CRITICAL');
  const warning = findings.filter((f) => f.severity === 'WARNING');

  const report = {
    skill: 'browser-compat',
    scan_scope: scanScope,
    projectRoot: ctx ? ctx.projectRoot : null,
    baseline: ctx ? ctx.config.baseline : null,
    findings,
    skipped: ctx ? ctx.skipped : [],
    summary: {
      critical: critical.length,
      warning: warning.length,
      info: 0,
      conclusion: critical.length > 0 ? 'block' : warning.length > 0 ? 'warning' : 'approve',
    },
  };

  console.log(JSON.stringify(report, null, 2));

  // 输出 schema 校验（失败仅 stderr 警告，不阻断退出码）
  const validationErrors = validateReport(report);
  if (validationErrors.length > 0) {
    process.stderr.write('[browser-compat] ⚠️  输出 schema 校验失败:\n');
    for (const e of validationErrors) {
      process.stderr.write(`  - ${e}\n`);
    }
  }

  process.exit(critical.length > 0 ? 1 : 0);
}

if (require.main === module) {
  main();
}

module.exports = { JS_RULES, CSS_RULES, scanContent, scanFile, scanDirectory, buildContext };
