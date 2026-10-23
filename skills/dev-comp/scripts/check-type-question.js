#!/usr/bin/env node
/**
 * B9j 类型表 `?` 一致性检查（权威源 doc-tables-spec.md §2.3）
 *
 * 用法：node check-type-question.js <docsFile> <projectRoot>
 *   例：node check-type-question.js docs/guide/components/menu.md .
 *   环境变量 PROJECT_ROOT 可替代第 2 参数。
 *
 * 判定：`### {类型名} Type` 下 3 列及以上表格的首列，其 `?` 后缀必须与组件源码
 *       `interface`（含 `extends` 继承字段）逐字段一致。
 * 输出：不一致项以 `类型:字段(doc=?, src=?)` 形式打印（最多 3 条），无输出即一致。
 * 退出码：恒 0（WARN 级；无法静态解析的类型——文档自造类型、`Picker*` 等重导出——
 *        会被跳过，不产生误报）。
 */
const fs = require('fs')
const path = require('path')

const docFile = process.argv[2]
const root = process.argv[3] || process.env.PROJECT_ROOT || '.'
if (!docFile || !fs.existsSync(docFile)) process.exit(0)

const comp = path.basename(docFile, '.md')
const compDir = path.join(root, 'components', comp)

/** 递归收集 .vue / .ts（排除 .d.ts） */
function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name)
    if (e.isDirectory()) walk(p, out)
    else if (/\.(vue|ts)$/.test(e.name) && !/\.d\.ts$/.test(e.name)) out.push(p)
  }
  return out
}

/** 解析 `export interface X extends A, B { ... }`，记录字段可选性与基接口 */
function parseDefs(files) {
  const defs = new Map()
  const alias = new Map()
  for (const f of files) {
    const src = fs.readFileSync(f, 'utf8')
    // 重导出别名：`PickerPreset as DatePickerPreset` / `Item as TabsItem`
    for (const m of src.matchAll(/([A-Za-z_$][\w$]*)\s+as\s+([A-Za-z_$][\w$]*)/g)) {
      if (!alias.has(m[2])) alias.set(m[2], m[1])
    }
    // 允许非导出的接口（如 menu 的 `interface ItemSharedProps`）—— extends 基接口常为局部定义
    const re = /^[ \t]*(?:export\s+)?interface\s+(\w+)(?:\s+extends\s+([\w,\s<>]+))?\s*\{/gm
    let m
    while ((m = re.exec(src))) {
      const name = m[1]
      const ext = (m[2] || '').trim()
      let i = re.lastIndex
      let depth = 1
      while (i < src.length && depth > 0) {
        if (src[i] === '{') depth++
        else if (src[i] === '}') depth--
        i++
      }
      const body = src.slice(re.lastIndex, i - 1)
      const fields = []
      for (const line of body.split('\n')) {
        const fm = line.match(/^\s{2}(?:readonly\s+)?(\w+)(\??)\s*[:?]/)
        if (fm) fields.push([fm[1], fm[2] === '?'])
      }
      if (!defs.has(name)) defs.set(name, [])
      defs.get(name).push({ fields, ext: ext.split(',').map((s) => s.trim()).filter(Boolean) })
    }
  }
  return { defs, alias }
}

/** 展开 extends 后的字段表（基接口在前，同名字段以派生接口为准） */
function resolveFields(defs, name, seen = new Set()) {
  if (!name || seen.has(name) || !defs.has(name)) return null
  seen.add(name)
  const d = defs.get(name)[0]
  let out = []
  for (const e of d.ext) {
    const base = e.replace(/<.*>/, '').replace(/^Partial$/, '').trim()
    const sub = resolveFields(defs, base, seen)
    if (sub) out = out.concat(sub)
  }
  return out.concat(d.fields)
}

/** 解析文档中所有 `### Xxx Type` 区块的首张表 */
function parseTables(text) {
  const lines = text.split('\n')
  const tables = []
  let i = 0
  while (i < lines.length) {
    const hm = lines[i].match(/^###\s+(.+?)\s+Type\s*$/)
    if (!hm) {
      i++
      continue
    }
    const name = hm[1]
    let j = i + 1
    while (j < lines.length && !/^#{2,3}\s/.test(lines[j])) {
      if (/^\s*\|/.test(lines[j]) && lines[j].includes('名称')) {
        const cols = lines[j].trim().replace(/^\||\|$/g, '').split('|').length
        const rows = []
        let k = j + 2
        while (k < lines.length && /^\s*\|/.test(lines[k])) {
          const cells = lines[k].trim().replace(/^\|/, '').replace(/\|$/, '').split('|')
          if (cells.length === cols) rows.push(cells[0].trim())
          k++
        }
        tables.push({ name, cols, rows })
        break
      }
      j++
    }
    i = j + 1
  }
  return tables
}

const text = fs.readFileSync(docFile, 'utf8')
if (!fs.existsSync(compDir)) process.exit(0)

const files = walk(compDir)
// 共享类型目录（picker / theme）供 date-picker / time-picker / config-provider 复用
for (const shared of ['picker', 'theme']) walk(path.join(root, 'components', shared), files)

const { defs, alias } = parseDefs(files)
const pref = comp
  .split('-')
  .map((s) => (s ? s[0].toUpperCase() + s.slice(1) : ''))
  .join('')

const issues = []
for (const t of parseTables(text)) {
  if (t.cols < 3) continue
  const cands = []
  if (alias.has(t.name)) cands.push(alias.get(t.name))
  cands.push(t.name)
  if (t.name.startsWith(pref) && t.name.length > pref.length) cands.push(t.name.slice(pref.length))
  const src = cands.find((c) => defs.has(c))
  if (!src) continue // 文档自造类型 / 无法静态解析，交人工
  const map = new Map(resolveFields(defs, src) || [])
  for (const cell of t.rows) {
    if (cell.startsWith('[')) continue // 索引签名
    const name = cell.replace(/\?$/, '')
    const docOpt = cell.endsWith('?')
    if (map.has(name) && map.get(name) !== docOpt) {
      issues.push(`${t.name}:${name}(doc=${docOpt ? '?' : '必填'},src=${map.get(name) ? '?' : '必填'})`)
    }
  }
}

if (issues.length) console.log(issues.slice(0, 3).join('; '))
