// 临时测试 baseline-resolver
const { resolveBaselineLevel } = require('../scripts/lib/baseline-resolver.js');

const cases = [
  { name: '保守型(典型)', input: ['chrome >= 70', 'safari >= 12', 'firefox >= 68', 'edge >= 79', 'not dead'], expect: 'conservative' },
  { name: '标准型(收紧)', input: ['chrome >= 90', 'safari >= 14'], expect: 'standard' },
  { name: '激进型(仅 Chrome 100)', input: ['chrome >= 100'], expect: 'aggressive' },
  { name: '激进型(last 2 chrome versions)', input: ['last 2 chrome versions'], expect: 'aggressive' },
  { name: '保守型(last 4 years)', input: ['last 4 years'], expect: 'conservative' },
  { name: '空数组兜底', input: [], expect: 'conservative' },
  { name: '纯聚合查询无版本', input: ['> 0.5%', 'not dead'], expect: 'conservative' },
  { name: 'Safari 13 应判 conservative', input: ['chrome >= 90', 'safari >= 13'], expect: 'conservative' },
];

let ok = 0;
let fail = 0;
for (const c of cases) {
  const got = resolveBaselineLevel(c.input);
  const status = got.level === c.expect ? '✅' : '❌';
  if (got.level === c.expect) ok += 1;
  else fail += 1;
  console.log(`${status} ${c.name} -> level=${got.level} (expect=${c.expect}) source=${got.source}`);
}
console.log(`\nResult: ${ok} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
