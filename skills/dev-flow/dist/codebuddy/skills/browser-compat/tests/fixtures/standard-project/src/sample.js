// Standard fixture: 含 inset(应被 standard 跳过) + :has(被 ignore 配置豁免) + accent-color(standard 仍启用)
const obj = {};
const has = Object.hasOwn(obj, 'k');  // standard 启用 → 应报
console.log(has);
