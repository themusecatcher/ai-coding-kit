/**
 * load-config.js
 *
 * 按优先级链加载项目级 browser-compat 配置：
 *   1. .browser-compat.json （支持「我们 schema」+「用户 schema」+「集中式 projects」三种风格）
 *   2. package.json > browserslist
 *   3. .browserslistrc
 *   4. 默认（保守型）
 *
 * 输出统一的 BrowserCompatConfig 对象，供 rule-filter / compat-check 消费。
 *
 * Schema 兼容矩阵（详见 SKILL.md §「配置文件 Schema 兼容」）：
 *
 *  ┌──────────────────┬──────────────────────────────┬──────────────────────────────┐
 *  │ 字段             │ 用户 schema（主路径）          │ 我们 schema（语法糖）          │
 *  ├──────────────────┼──────────────────────────────┼──────────────────────────────┤
 *  │ baseline 版本    │ targets: { chrome:"70" }       │ target: "conservative" + baseline:{...} │
 *  │ 规则开关         │ rules: { "X":"error|warn|off" }│ ignore:[{rule_id,reason}]    │
 *  │ 路径排除         │ ignore: ["node_modules/**"]    │ excludePaths: [...]          │
 *  │ 多项目           │ projects: { name: {...} }      │ —                            │
 *  └──────────────────┴──────────────────────────────┴──────────────────────────────┘
 *
 *  ignore 字段类型嗅探：第一个元素是字符串 → 路径 glob 数组（用户 schema），
 *  是对象 → 规则豁免数组（我们 schema）；空数组 → 空规则豁免。
 */

const fs = require('fs');
const path = require('path');
const { resolveBaselineLevel, BASELINE_DEFAULT } = require('./baseline-resolver');

const VALID_LEVELS = ['conservative', 'standard', 'aggressive'];

const CONFIG_DEFAULT = Object.freeze({
  baseline: { ...BASELINE_DEFAULT },
  polyfills: [],
  ignore: [],
  customRules: {},
  excludePaths: [
    'node_modules/**',
    'dist/**',
    'build/**',
    '.next/**',
    '**/*.min.js',
    '**/*.d.ts',
  ],
  includePaths: [],
  // 保留字段（当前 compat-check 不消费，未来扩展）
  customMessages: {},
  reportOptions: {},
});

function safeReadJson(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    const raw = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(raw);
  } catch (err) {
    process.stderr.write(`[browser-compat] 读取 ${filePath} 失败: ${err.message}\n`);
    return null;
  }
}

function safeReadLines(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    return fs
      .readFileSync(filePath, 'utf-8')
      .split('\n')
      .map((l) => l.replace(/#.*$/, '').trim())
      .filter(Boolean);
  } catch (err) {
    process.stderr.write(`[browser-compat] 读取 ${filePath} 失败: ${err.message}\n`);
    return null;
  }
}

/**
 * 把版本号字符串/数字归一为整数主版本号（"9.1" → 9，70 → 70，"70" → 70）。
 * 用户 schema 习惯写 "safari": "9.1"，我们的 baseline 校验只关心主版本。
 */
function normalizeMajorVersion(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.floor(value);
  if (typeof value === 'string') {
    const match = value.match(/^\d+/);
    if (match) return parseInt(match[0], 10);
  }
  return undefined;
}

/**
 * 把用户 schema 的 targets 对象转为 minVersions（带 ios/android 兼容映射）。
 */
function targetsToMinVersions(targets) {
  if (!targets || typeof targets !== 'object') return null;
  const minVersions = {};
  for (const [browser, ver] of Object.entries(targets)) {
    const major = normalizeMajorVersion(ver);
    if (major === undefined) continue;
    // ios → safari（用户 schema 偏好分开写 ios/safari，但我们脚本用 safari 统一）
    const key = browser === 'ios' ? 'safari' : browser === 'android' ? 'chrome' : browser;
    // 同时设置时取较小者（更保守）
    if (minVersions[key] === undefined || major < minVersions[key]) {
      minVersions[key] = major;
    }
  }
  return Object.keys(minVersions).length > 0 ? minVersions : null;
}

/**
 * 把 ESLint 风格的 rules 对象（`{ "structuredClone": "off" }`）转为我们的 ignore 数组。
 *  - "off"          → 写入 ignore 列表（rule_id 用规则文本本身，下游 rule-filter 按文本匹配兜底）
 *  - "error"        → 不动作（默认就是启用）
 *  - "warn" / "info"→ 写入 customRules，备未来做 severity 降级（当前 compat-check 暂不消费）
 *
 * 注意：用户 schema 里的 key 是规则文本（如 "structuredClone"、"CSS gap (Flexbox)"），
 * 不是我们脚本里用的 rule_id（如 "no-structured-clone"）。所以这里同时写入 reason
 * 字段，便于 rule-filter 做模糊匹配 + 调试时显式追溯。
 */
function rulesToIgnoreAndCustom(rules) {
  if (!rules || typeof rules !== 'object') return { ignore: [], customRules: {} };
  const ignore = [];
  const customRules = {};
  for (const [name, severity] of Object.entries(rules)) {
    if (name.startsWith('_comment')) continue; // 用户 schema 里有 _comment_xxx 注释字段
    if (typeof severity !== 'string') continue;
    const sev = severity.toLowerCase();
    if (sev === 'off') {
      ignore.push({
        rule_id: name,
        reason: 'rules:off',
        match: 'fuzzy', // 标记给 rule-filter：按规则名/规则 ID 双向模糊匹配
      });
    } else if (sev === 'warn' || sev === 'info') {
      customRules[name] = severity;
    }
    // 'error' 是默认启用，无需动作
  }
  return { ignore, customRules };
}

/**
 * ignore 字段类型嗅探：
 *  - 第一个元素是字符串 → 路径 glob 数组（用户 schema），并入 excludePaths
 *  - 第一个元素是对象 → 规则豁免数组（我们 schema），并入 ignore
 *  - 空数组 → 不动作
 */
function classifyIgnoreField(arr) {
  const result = { paths: [], ruleIgnores: [] };
  if (!Array.isArray(arr) || arr.length === 0) return result;
  const first = arr[0];
  if (typeof first === 'string') {
    result.paths = arr.filter((x) => typeof x === 'string');
  } else if (first && typeof first === 'object' && first.rule_id) {
    result.ruleIgnores = arr.filter((x) => x && typeof x === 'object' && x.rule_id);
  } else {
    process.stderr.write(
      `[browser-compat] ignore 字段元素类型未识别（第一个元素：${JSON.stringify(first)}），已跳过\n`
    );
  }
  return result;
}

/**
 * 集中式 projects 配置：从同目录 package.json>name 反查应该用哪一份子配置。
 * @returns {object|null} 选中的子配置；找不到返回 null
 */
function resolveCentralProject(centralCfg, projectRoot) {
  if (!centralCfg || !centralCfg.projects || typeof centralCfg.projects !== 'object') return null;
  const pkg = safeReadJson(path.join(projectRoot, 'package.json'));
  const name = pkg && typeof pkg.name === 'string' ? pkg.name : null;
  if (name && centralCfg.projects[name]) {
    return { config: centralCfg.projects[name], matchedName: name };
  }
  // 兜底：使用 projectRoot 末段目录名匹配（处理 monorepo / package.json>name 不一致场景）
  const dirName = path.basename(projectRoot);
  if (centralCfg.projects[dirName]) {
    return { config: centralCfg.projects[dirName], matchedName: dirName };
  }
  return null;
}

/**
 * 应用单个 .browser-compat.json 子配置到 config（in-place 改写）。
 * 同时支持「我们 schema」字段和「用户 schema」字段；优先级：我们 schema 的字段 > 用户 schema 的字段
 * （即 target 优先于 targets，excludePaths 优先于 ignore-as-paths，ignore 对象数组优先于 rules）。
 *
 * @returns {boolean} 是否成功设置了 baseline（用于决定是否需要继续 fallback）
 */
function applyCompatJson(compatJson, config, sourceLabel) {
  let baselineSet = false;

  // ─── baseline 版本：target（单数糖）→ targets（复数主路径）→ baseline（数字对象） ───
  if (compatJson.target && VALID_LEVELS.includes(compatJson.target)) {
    config.baseline = {
      level: compatJson.target,
      source: sourceLabel,
      minVersions: compatJson.baseline
        ? { ...config.baseline.minVersions, ...compatJson.baseline }
        : { ...config.baseline.minVersions },
    };
    baselineSet = true;
  } else if (compatJson.targets && typeof compatJson.targets === 'object') {
    const minVersions = targetsToMinVersions(compatJson.targets);
    if (minVersions) {
      // 用 resolver 反推档位（基于浏览器版本号判定）
      const synthesized = Object.entries(minVersions).map(([b, v]) => `${b} >= ${v}`);
      const resolved = resolveBaselineLevel(synthesized);
      config.baseline = {
        level: resolved.level,
        source: sourceLabel,
        minVersions: { ...config.baseline.minVersions, ...minVersions },
      };
      baselineSet = true;
    }
  } else if (compatJson.baseline && typeof compatJson.baseline === 'object') {
    const synthesized = [];
    for (const [browser, ver] of Object.entries(compatJson.baseline)) {
      const major = normalizeMajorVersion(ver);
      if (major !== undefined) synthesized.push(`${browser} >= ${major}`);
    }
    if (synthesized.length > 0) {
      const resolved = resolveBaselineLevel(synthesized);
      config.baseline = {
        level: resolved.level,
        source: sourceLabel,
        minVersions: { ...config.baseline.minVersions, ...compatJson.baseline },
      };
      baselineSet = true;
    }
  }

  // ─── polyfills ───
  if (Array.isArray(compatJson.polyfills)) config.polyfills = compatJson.polyfills.slice();

  // ─── 路径排除：excludePaths（明确）优先；否则嗅探 ignore 字段 ───
  if (Array.isArray(compatJson.excludePaths)) {
    config.excludePaths = compatJson.excludePaths.slice();
  }
  if (Array.isArray(compatJson.ignore)) {
    const { paths, ruleIgnores } = classifyIgnoreField(compatJson.ignore);
    if (paths.length > 0 && !Array.isArray(compatJson.excludePaths)) {
      // 用户 schema：ignore 是路径 glob → 合并到 excludePaths（保留默认值 + 用户值，去重）
      const merged = new Set([...config.excludePaths, ...paths]);
      config.excludePaths = Array.from(merged);
    }
    if (ruleIgnores.length > 0) {
      config.ignore = ruleIgnores;
    }
  }

  // ─── rules（ESLint 风格，用户 schema）→ 转为 ignore + customRules ───
  if (compatJson.rules && typeof compatJson.rules === 'object') {
    const { ignore: rulesIgnore, customRules } = rulesToIgnoreAndCustom(compatJson.rules);
    if (rulesIgnore.length > 0) {
      // 与已有 ignore 合并（rules.off 不覆盖显式 ignore 对象数组的强声明）
      const existingIds = new Set(config.ignore.map((x) => x && x.rule_id));
      for (const item of rulesIgnore) {
        if (!existingIds.has(item.rule_id)) config.ignore.push(item);
      }
    }
    config.customRules = { ...config.customRules, ...customRules };
  }

  // ─── 我们 schema 显式的 customRules 字段 ───
  if (compatJson.customRules && typeof compatJson.customRules === 'object') {
    config.customRules = { ...config.customRules, ...compatJson.customRules };
  }

  // ─── includePaths ───
  if (Array.isArray(compatJson.includePaths)) config.includePaths = compatJson.includePaths.slice();

  // ─── 保留字段：customMessages / reportOptions（当前 compat-check 不消费）───
  // 透传到 config，便于 --print-baseline 调试可见；同时 stderr 提示用户避免沉默失败。
  if (compatJson.customMessages && typeof compatJson.customMessages === 'object') {
    config.customMessages = { ...compatJson.customMessages };
    process.stderr.write(
      `[browser-compat] ℹ️  检测到 customMessages 字段（${Object.keys(compatJson.customMessages).length} 条），当前版本暂未消费（finding.message 仍来自规则定义），未来扩展\n`
    );
  }
  if (compatJson.reportOptions && typeof compatJson.reportOptions === 'object') {
    config.reportOptions = { ...compatJson.reportOptions };
    process.stderr.write(
      `[browser-compat] ℹ️  检测到 reportOptions 字段，当前版本暂未消费（输出格式由 compat-check 内置控制），未来扩展\n`
    );
  }

  return baselineSet;
}

/**
 * 主入口：按优先级加载并合并配置
 * @param {string} projectRoot - 项目根目录绝对路径
 * @returns {object} 完整 BrowserCompatConfig
 */
function loadConfig(projectRoot) {
  const root = projectRoot || process.cwd();
  const config = JSON.parse(JSON.stringify(CONFIG_DEFAULT));

  // 1. .browser-compat.json
  const compatJsonPath = path.join(root, '.browser-compat.json');
  const compatJson = safeReadJson(compatJsonPath);
  let compatJsonBaselineSet = false;

  if (compatJson) {
    // 1a. 集中式 projects 配置（如 nextWebsite/.browser-compat.json）
    const matched = resolveCentralProject(compatJson, root);
    if (matched) {
      compatJsonBaselineSet = applyCompatJson(
        matched.config,
        config,
        `.browser-compat.json>projects.${matched.matchedName}`
      );
    } else if (compatJson.projects) {
      // 集中式但未匹配到当前项目：警告并 fallback
      process.stderr.write(
        `[browser-compat] .browser-compat.json 是集中式（含 projects 字段）但未匹配当前项目 (package.json>name 或 目录名)，将 fallback 到 browserslist\n`
      );
    } else {
      // 1b. 独立式（用户 schema 或我们 schema）
      compatJsonBaselineSet = applyCompatJson(compatJson, config, '.browser-compat.json');
    }

    // 关键修复：仅当 baseline 已成功设置才返回；否则继续往下 fallback 到 browserslist
    if (compatJsonBaselineSet) return config;
  }

  // 2. package.json > browserslist
  const pkgPath = path.join(root, 'package.json');
  const pkg = safeReadJson(pkgPath);
  if (pkg && pkg.browserslist) {
    const list = Array.isArray(pkg.browserslist)
      ? pkg.browserslist
      : (pkg.browserslist.production || pkg.browserslist.development || []);
    if (Array.isArray(list) && list.length > 0) {
      const resolved = resolveBaselineLevel(list);
      config.baseline = {
        level: resolved.level,
        source: compatJson
          ? 'package.json>browserslist (compat-json fallback)'
          : 'package.json>browserslist',
        minVersions: resolved.minVersions,
      };
      return config;
    }
  }

  // 3. .browserslistrc
  const browserslistrcPath = path.join(root, '.browserslistrc');
  const lines = safeReadLines(browserslistrcPath);
  if (lines && lines.length > 0) {
    const resolved = resolveBaselineLevel(lines);
    config.baseline = {
      level: resolved.level,
      source: '.browserslistrc',
      minVersions: resolved.minVersions,
    };
    return config;
  }

  // 4. 默认（保守型）
  config.baseline = {
    level: BASELINE_DEFAULT.level,
    source: compatJson ? 'fallback (compat-json incomplete)' : 'default',
    minVersions: { ...BASELINE_DEFAULT.minVersions },
  };
  return config;
}

module.exports = {
  loadConfig,
  CONFIG_DEFAULT,
  VALID_LEVELS,
  // 暴露给测试用
  _internal: {
    targetsToMinVersions,
    rulesToIgnoreAndCustom,
    classifyIgnoreField,
    resolveCentralProject,
    normalizeMajorVersion,
  },
};
