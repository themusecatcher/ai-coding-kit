/**
 * baseline-resolver.js
 *
 * 把 browserslist 字符串数组解析为 browser-compat 三档基线档位
 * （conservative / standard / aggressive）以及最低浏览器版本。
 *
 * 判定规则与 references/browser-baseline.md §二「三档基线判定规则」对齐。
 */

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
  BASELINE_DEFAULT,
  // 仅供测试导出
  _internal: { parseQuery, mergeMinVersions, decideLevel },
};
