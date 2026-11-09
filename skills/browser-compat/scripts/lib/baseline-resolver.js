/**
 * baseline-resolver.js
 *
 * 把 browserslist 字符串数组解析为 browser-compat 三档基线档位
 * （conservative / standard / aggressive）以及最低浏览器版本。
 *
 * 判定规则与 references/browser-baseline.md §二「三档基线判定规则」对齐。
 */

const fs = require('fs');
const path = require('path');

const BASELINE_DEFAULT = Object.freeze({
  level: 'conservative',
  source: 'fallback',
  minVersions: { chrome: 70, safari: 12, firefox: 68, edge: 79 },
});

// 仅识别这 4 个主流浏览器，其他（ios_saf、samsung 等）不影响档位判定但保留版本
const SUPPORTED_BROWSERS = ['chrome', 'safari', 'firefox', 'edge'];

/**
 * 解析单条 browserslist query
 * @returns {{ browser: string, op: string, version: number, isAggregate: boolean, raw: string }|null}
 */
function parseQuery(rawQuery) {
  const query = String(rawQuery || '').trim().toLowerCase();
  if (!query || query.startsWith('#')) return null;

  // 否定查询暂忽略（"not ie 11" 等不影响下限判定）
  if (query.startsWith('not ')) return { isAggregate: true, raw: query };

  // 聚合查询（必须用前缀匹配，避免误吞 "chrome >= 90" 这类带比较符的单浏览器查询）
  const aggregatePrefixes = [
    'last ',
    'dead',
    'defaults',
    'maintained ',
    'unreleased ',
    'current node',
    'extends ',
    'cover ',
    'supports ',
  ];
  if (aggregatePrefixes.some((k) => query === k.trim() || query.startsWith(k))) {
    return { isAggregate: true, raw: query };
  }
  // 百分比聚合：> 0.5%, >= 1%, < 0.1% 等
  if (/^[<>]=?\s*\d+(\.\d+)?\s*%/.test(query)) {
    return { isAggregate: true, raw: query };
  }
  if (/^last\s+\d+/.test(query)) {
    return { isAggregate: true, raw: query };
  }

  // 单浏览器版本：chrome >= 70 / safari 12 / chrome > 70 / chrome 90-92
  const m = query.match(/^([a-z_]+)\s*(>=|<=|>|<|=)?\s*(\d+(?:\.\d+)?)/);
  if (!m) return null;
  const browser = m[1];
  const op = m[2] || '>=';
  const version = parseFloat(m[3]);
  return { browser, op, version, isAggregate: false, raw: query };
}

/**
 * 把多条 query 合并为「每个浏览器的最低支持版本」
 * 注：op 为 >= / > 时取「下限」，op 为 <= / < 时不影响下限
 */
function mergeMinVersions(parsedQueries) {
  const min = {};
  for (const q of parsedQueries) {
    if (!q || q.isAggregate) continue;
    if (!SUPPORTED_BROWSERS.includes(q.browser)) continue;
    if (q.op === '<=' || q.op === '<') continue; // 上限不参与「最低支持」推断
    const ver = q.op === '>' ? q.version + 0.0001 : q.version;
    if (min[q.browser] === undefined || ver < min[q.browser]) {
      min[q.browser] = ver;
    }
  }
  return min;
}

/**
 * 三档判定规则（与 references/browser-baseline.md §二 对齐）
 */
function decideLevel(minVersions, hasAggregate, queries) {
  const { chrome, safari, firefox, edge } = minVersions;
  const onlyChrome =
    chrome !== undefined &&
    safari === undefined &&
    firefox === undefined &&
    edge === undefined;

  // 1. 激进型：仅 chrome 且 chrome >= 100，或显式 last X chrome versions
  const hasLastChromeOnly = queries.some(
    (q) => q && q.isAggregate && /^last\s+\d+\s+chrome\s+versions?$/.test(q.raw)
  );
  if (hasLastChromeOnly) return 'aggressive';
  if (onlyChrome && chrome >= 100) return 'aggressive';

  // 2. 标准型：safari >= 14 && chrome >= 90（同时收紧）
  if (safari !== undefined && chrome !== undefined && safari >= 14 && chrome >= 90) {
    return 'standard';
  }

  // 3. 保守型：safari <= 13 或 chrome <= 79 或含 last 4+ years 类聚合
  const hasLastYearsLong = queries.some(
    (q) => q && q.isAggregate && /^last\s+(\d+)\s+years?$/.test(q.raw) &&
      parseInt(q.raw.match(/^last\s+(\d+)/)[1], 10) >= 4
  );
  if (hasLastYearsLong) return 'conservative';
  if (safari !== undefined && safari <= 13) return 'conservative';
  if (chrome !== undefined && chrome <= 79) return 'conservative';

  // 4. 默认兜底
  return 'conservative';
}

/**
 * 聚合查询（`> 0.5%` / `last 2 versions` / `not dead`）无法从字面推断版本，
 * 改为调用「项目自身」的 browserslist 包解析真实清单，再取每个浏览器的最低版本。
 * 解析失败（未安装 / 查询非法）返回 null，调用方退回字面推断。
 */
/** 版本号数值比较（仅用于挑选 pnpm store 中的最高版本；预发布后缀按数值前缀参与比较） */
function compareVersion(first, second) {
  const parse = (value) =>
    String(value)
      .split('.')
      .map((part) => parseFloat(part) || 0);
  const left = parse(first);
  const right = parse(second);
  const length = Math.max(left.length, right.length);
  for (let index = 0; index < length; index += 1) {
    const diff = (left[index] || 0) - (right[index] || 0);
    if (diff !== 0) return diff;
  }
  return 0;
}

function loadBrowserslist(projectRoot) {
  // 1) 常规解析（npm / yarn / hoisted 布局）
  try {
    return require(require.resolve('browserslist', { paths: [projectRoot] }));
  } catch (err) {
    /* 继续尝试 */
  }
  // 2) 直接从项目 node_modules 解析
  try {
    return require(require.resolve('browserslist', { paths: [path.join(projectRoot, 'node_modules')] }));
  } catch (err) {
    /* 继续尝试 */
  }
  // 3) pnpm：依赖不提升，落在 node_modules/.pnpm/browserslist@x.y.z/node_modules/browserslist
  try {
    const pnpmDir = path.join(projectRoot, 'node_modules', '.pnpm');
    const latest = fs
      .readdirSync(pnpmDir)
      .filter((name) => name.startsWith('browserslist@'))
      // 按版本号数值排序：字典序会把 4.29.5 排在 4.9.5 之前，选到旧版数据
      .sort((first, second) => compareVersion(first.slice('browserslist@'.length), second.slice('browserslist@'.length)))
      .pop();
    if (latest) return require(path.join(pnpmDir, latest, 'node_modules', 'browserslist'));
  } catch (err) {
    /* 无 pnpm 布局 */
  }
  return null;
}

function resolveByBrowserslist(queries, projectRoot) {
  if (!projectRoot) return null;
  const browserslist = loadBrowserslist(projectRoot);
  if (!browserslist) return null;
  let list;
  try {
    list = browserslist(queries);
  } catch (err) {
    return null;
  }
  const min = {};
  for (const entry of list) {
    const [browser, version] = String(entry).split(' ');
    if (!SUPPORTED_BROWSERS.includes(browser)) continue;
    const parsed = parseFloat(version);
    if (Number.isNaN(parsed)) continue;
    if (min[browser] === undefined || parsed < min[browser]) min[browser] = parsed;
  }
  return Object.keys(min).length > 0 ? min : null;
}

/**
 * 带项目上下文的基线解析：优先用 browserslist 包解析聚合查询，
 * 失败时退回 resolveBaselineLevel 的字面推断（旧行为）。
 * @param {string[]|string} browserslistInput
 * @param {string} [projectRoot] 用于定位项目内的 browserslist 包
 */
function resolveBaselineLevelFromProject(browserslistInput, projectRoot) {
  const raw = Array.isArray(browserslistInput)
    ? browserslistInput
    : String(browserslistInput || '').split(/[,\n]/);
  const queries = raw.map((query) => String(query).trim()).filter(Boolean);
  const resolvedMin = resolveByBrowserslist(queries, projectRoot);
  if (!resolvedMin) {
    return resolveBaselineLevel(browserslistInput);
  }
  const filled = { ...BASELINE_DEFAULT.minVersions };
  for (const browser of SUPPORTED_BROWSERS) {
    if (resolvedMin[browser] !== undefined) filled[browser] = resolvedMin[browser];
  }
  return {
    level: decideLevel(resolvedMin, false, []),
    source: 'browserslist (resolved)',
    minVersions: filled,
    queries: queries.map((query) => ({ isAggregate: true, raw: query })),
  };
}

/**
 * 主入口
 * @param {string[]|string} browserslistInput
 * @returns {{ level: string, source: string, minVersions: object, queries: object[] }}
 */
function resolveBaselineLevel(browserslistInput) {
  if (!browserslistInput) {
    return { ...BASELINE_DEFAULT, queries: [] };
  }

  const raw = Array.isArray(browserslistInput)
    ? browserslistInput
    : String(browserslistInput).split(/[,\n]/);

  const queries = raw.map(parseQuery).filter(Boolean);

  if (queries.length === 0) {
    return { ...BASELINE_DEFAULT, queries: [] };
  }

  const minVersions = mergeMinVersions(queries);
  const hasAggregate = queries.some((q) => q.isAggregate);

  const level = decideLevel(minVersions, hasAggregate, queries);

  // 用解析结果填充 minVersions 缺失项（用档位默认值兜底）
  const filled = { ...BASELINE_DEFAULT.minVersions };
  for (const b of SUPPORTED_BROWSERS) {
    if (minVersions[b] !== undefined) filled[b] = minVersions[b];
  }

  return {
    level,
    source: 'browserslist',
    minVersions: filled,
    queries,
  };
}

module.exports = {
  resolveBaselineLevel,
  resolveBaselineLevelFromProject,
  BASELINE_DEFAULT,
  // 仅供测试导出
  _internal: { parseQuery, mergeMinVersions, decideLevel, resolveByBrowserslist },
};
