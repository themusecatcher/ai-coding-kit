// Conservative fixture: 含多种 CRITICAL 违规
const arr = [1, 2, 3];
const last = arr.at(-1);                       // CRITICAL no-array-at
const cloned = structuredClone(arr);           // CRITICAL no-structured-clone
const has = Object.hasOwn({}, 'foo');          // CRITICAL no-object-hasown
const id = crypto.randomUUID();                 // CRITICAL no-crypto-randomuuid

// 注释豁免
// const x = arr.at(-1); // 整行注释 → 不报
const y = arr.at(0); // @compat-ignore 业务理由 → 不报

console.log(last, cloned, has, id, y);
