// 临时测试 load-config
const path = require('path');
const { loadConfig } = require('../scripts/lib/load-config.js');

const cases = [
  {
    name: 'conservative-project (browserslist)',
    root: path.join(__dirname, 'fixtures/conservative-project'),
    expectLevel: 'conservative',
    expectSource: 'package.json>browserslist',
  },
  {
    name: 'standard-project (.browser-compat.json)',
    root: path.join(__dirname, 'fixtures/standard-project'),
    expectLevel: 'standard',
    expectSource: '.browser-compat.json',
  },
  {
    name: 'empty-project (默认兜底)',
    root: path.join(__dirname, 'fixtures/empty-project'),
    expectLevel: 'conservative',
    expectSource: 'default',
  },
];

let ok = 0;
let fail = 0;
for (const c of cases) {
  const config = loadConfig(c.root);
  const passLevel = config.baseline.level === c.expectLevel;
  const passSource = config.baseline.source === c.expectSource;
  const pass = passLevel && passSource;
  console.log(`${pass ? '✅' : '❌'} ${c.name}`);
  console.log(`   level=${config.baseline.level} (expect=${c.expectLevel}) ${passLevel ? 'OK' : 'MISMATCH'}`);
  console.log(`   source=${config.baseline.source} (expect=${c.expectSource}) ${passSource ? 'OK' : 'MISMATCH'}`);
  if (config.polyfills && config.polyfills.length) console.log(`   polyfills=${JSON.stringify(config.polyfills)}`);
  if (config.ignore && config.ignore.length) console.log(`   ignore=${JSON.stringify(config.ignore)}`);
  if (pass) ok += 1;
  else fail += 1;
}
console.log(`\nResult: ${ok} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
