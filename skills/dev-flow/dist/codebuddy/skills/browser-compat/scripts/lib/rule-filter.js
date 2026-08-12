/**
 * rule-filter.js
 *
 * 按 baseline.level / polyfills / ignore 过滤规则集 + finding 集。
 *
 * 策略：
 *   1. 规则级过滤（先过滤规则，再扫描）：按 enabledIn / polyfilledBy / ignore.rule_id
 *   2. Finding 级过滤（扫描后再过滤）：按文件路径排除（excludePaths/includePaths）
 */

const path = require('path');

// 启用矩阵：规则 ID → 启用的基线档位列表
// 含义：该 API/属性「在该档位下仍超出基线，应当报警」
//   - conservative（Safari 12+/Chrome 70+）
//   - standard      (Safari 14+/Chrome 90+)
//   - aggressive    (Chrome 100+)
const ENABLED_MATRIX = Object.freeze({
  // ===== JS =====
  // Safari 15.4+ / Chrome 92+ → standard(Safari14) 仍超线，aggressive(Chrome100) OK
  'no-array-at': ['conservative', 'standard'],
  // Safari 15.4+ / Chrome 98+ → standard 仍超线，aggressive OK
  'no-structured-clone': ['conservative', 'standard'],
  // Safari 15.4+ / Chrome 93+ → standard 仍超线，aggressive OK
  'no-object-hasown': ['conservative', 'standard'],
  // Safari 16+ / Chrome 110+ → aggressive(Chrome100) 仍超线
  'no-array-tosorted': ['conservative', 'standard', 'aggressive'],
  // Safari 17.4+ / Chrome 117+ → aggressive 仍超线
  'no-object-groupby': ['conservative', 'standard', 'aggressive'],
  // Safari 17.4+ / Chrome 119+ → aggressive 仍超线
  'no-promise-withresolvers': ['conservative', 'standard', 'aggressive'],
  // Safari 15.4+ / Chrome 92+ → standard 仍超线，aggressive OK
  'no-crypto-randomuuid': ['conservative', 'standard'],

  // ===== CSS =====
  // Safari 15.4+ / Chrome 105+ → standard 仍超线，aggressive(Chrome100) 仍超线
  'no-has-selector': ['conservative', 'standard', 'aggressive'],
  // Safari 16+ / Chrome 105+ → aggressive 仍超线
  'no-container-type': ['conservative', 'standard', 'aggressive'],
  // Safari 16.2+ / Chrome 111+ → aggressive 仍超线
  'no-color-mix': ['conservative', 'standard', 'aggressive'],
  // Safari 16+ / Chrome 117+ → aggressive 仍超线
  'no-subgrid': ['conservative', 'standard', 'aggressive'],
  // Safari 14.1+ → standard(Safari14) 边界场景，保守起见仅 conservative 启用
  'no-flexbox-gap': ['conservative'],
  // Safari 15.4+ / Chrome 88+ → standard 仍超线，aggressive OK
  'no-aspect-ratio': ['conservative', 'standard'],
  // Safari 14.1+ → standard 起 OK
  'no-inset-shorthand': ['conservative'],
  // Safari 17.5+ / Chrome 114+ → aggressive 仍超线
  'no-text-wrap': ['conservative', 'standard', 'aggressive'],
  // Safari 15.4+ / Chrome 99+ → standard 仍超线，aggressive(Chrome100) 边界，保守仍报
  'no-css-layer': ['conservative', 'standard'],
  // Safari 15.4+ / Chrome 93+ → standard 仍超线，aggressive OK
  'no-accent-color': ['conservative', 'standard'],
  // 前缀建议无版本依赖，所有档位都启用（除非项目主动 ignore）
  'warn-backdrop-filter': ['conservative', 'standard', 'aggressive'],
});

// Polyfill ↔ 规则 ID 映射：声明 polyfills 后跳过对应规则
// 当前规则集中没有直接对应 polyfill 的（ResizeObserver/IntersectionObserver 是 🟡 仅参考，未自动检测）
// 保留映射表以便未来扩展
const POLYFILL_MAP = Object.freeze({
  ResizeObserver: [],          // 当前无对应规则
  IntersectionObserver: [],    // 当前无对应规则
});

/**
 * 把规则名/ID 归一化用于模糊匹配：小写 + 去 `no-`/`warn-` 前缀 + 去 `prototype` + 去非字母数字。
 *   "structuredClone"        → "structuredclone"
 *   "no-structured-clone"    → "structuredclone"
 *   "Object.hasOwn"          → "objecthasown"
 *   "no-object-hasown"       → "objecthasown"
 *   "Array.prototype.at"     → "arrayat"   ← 去除 .prototype. 字面，对齐 rule.id 风格
 *   "no-array-at"            → "arrayat"
 *
 * 设计意图：用户 schema 里的 rules 名（如 "structuredClone"、"Array.prototype.at"）
 * 与 ENABLED_MATRIX 的 rule.id（如 "no-structured-clone"、"no-array-at"）形态差异较大，
 * 必须双向归一后比较。`prototype` 是用户 schema 风格特有的、对匹配无意义的中间词。
 */
function normalizeRuleKey(name) {
  if (typeof name !== 'string') return '';
  return name
    .toLowerCase()
    .replace(/^no-/, '')
    .replace(/^warn-/, '')
    .replace(/prototype/g, '')
    .replace(/[^a-z0-9]/g, '');
}

/**
 * 判断单个 rule.id 是否被 ignore 列表命中（支持 exact + fuzzy 两种匹配）。
 * @returns {{ matched: boolean, reason: string }}
 */
function matchIgnoreRule(ruleId, ignore) {
  const exactReasons = [];
  const fuzzyReasons = [];
  const ruleKey = normalizeRuleKey(ruleId);

  for (const item of ignore) {
    if (!item || !item.rule_id) continue;
    const itemKey = normalizeRuleKey(item.rule_id);

    if (item.match === 'fuzzy') {
      // 模糊匹配：双向 includes（用户名包含规则名 或 规则名包含用户名）
      if (itemKey && ruleKey && (itemKey.includes(ruleKey) || ruleKey.includes(itemKey))) {
        fuzzyReasons.push(`${item.reason || '项目配置'} (fuzzy: ${item.rule_id})`);
      }
    } else {
      // 精确匹配（默认）：原始字符串相等 或 归一化后相等
      if (item.rule_id === ruleId || (itemKey && itemKey === ruleKey)) {
        exactReasons.push(item.reason || '项目配置');
      }
    }
  }

  // 精确优先于模糊
  if (exactReasons.length > 0) return { matched: true, reason: exactReasons[0] };
  if (fuzzyReasons.length > 0) return { matched: true, reason: fuzzyReasons[0] };
  return { matched: false, reason: '' };
}

/**
 * 按 baseline / polyfills / ignore 过滤规则集
 * @param {Array} rules - JS_RULES 或 CSS_RULES
 * @param {object} config - loadConfig() 返回的配置
 * @returns {{ activeRules: Array, skipped: Array }}
 */
function filterRules(rules, config) {
  const level = (config && config.baseline && config.baseline.level) || 'conservative';
  const polyfills = (config && config.polyfills) || [];
  const ignore = (config && config.ignore) || [];

  const polyfilledIds = new Set();
  for (const p of polyfills) {
    const ids = POLYFILL_MAP[p] || [];
    for (const id of ids) polyfilledIds.add(id);
  }

  const activeRules = [];
  const skipped = [];

  for (const rule of rules) {
    // ignore 优先级最高（含 exact + fuzzy 两种匹配路径）
    const ig = matchIgnoreRule(rule.id, ignore);
    if (ig.matched) {
      skipped.push({ rule_id: rule.id, reason: `ignore: ${ig.reason}` });
      continue;
    }
    // polyfill 跳过
    if (polyfilledIds.has(rule.id)) {
      skipped.push({ rule_id: rule.id, reason: `polyfilled` });
      continue;
    }
    // 启用矩阵
    const enabledIn = ENABLED_MATRIX[rule.id];
    if (enabledIn && !enabledIn.includes(level)) {
      skipped.push({ rule_id: rule.id, reason: `baseline:${level}` });
      continue;
    }
    activeRules.push(rule);
  }

  return { activeRules, skipped };
}

/**
 * 简易 glob 匹配（仅支持 ** 和 * 通配符）
 */
function globToRegex(glob) {
  // 转义正则特殊字符（除 * 和 ?）
  let re = glob.replace(/[.+^${}()|[\]\\]/g, '\\$&');
  // ** → .*
  re = re.replace(/\*\*/g, '__GLOBSTAR__');
  // * → [^/]*
  re = re.replace(/\*/g, '[^/]*');
  // ? → [^/]
  re = re.replace(/\?/g, '[^/]');
  re = re.replace(/__GLOBSTAR__/g, '.*');
  // 大括号扩展 {a,b,c} → (a|b|c)
  re = re.replace(/\\\{([^}]+)\\\}/g, (_, inner) => '(' + inner.split(',').join('|') + ')');
  re = re.replace(/\{([^}]+)\}/g, (_, inner) => '(' + inner.split(',').join('|') + ')');
  return new RegExp('^' + re + '$');
}

function shouldSkipPath(filePath, excludePaths, includePaths, projectRoot) {
  const rel = projectRoot ? path.relative(projectRoot, filePath) : filePath;
  const normalized = rel.split(path.sep).join('/');

  // excludePaths：任一命中即跳过
  for (const pat of excludePaths || []) {
    if (globToRegex(pat).test(normalized)) return true;
  }

  // includePaths：若声明则必须命中其一
  if (includePaths && includePaths.length > 0) {
    let included = false;
    for (const pat of includePaths) {
      if (globToRegex(pat).test(normalized)) {
        included = true;
        break;
      }
    }
    if (!included) return true;
  }

  return false;
}

module.exports = {
  filterRules,
  shouldSkipPath,
  ENABLED_MATRIX,
  POLYFILL_MAP,
  // 仅供测试
  _internal: { globToRegex, normalizeRuleKey, matchIgnoreRule },
};
