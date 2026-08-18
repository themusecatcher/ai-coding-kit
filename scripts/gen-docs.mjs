// @ts-check
/**
 * gen-docs.mjs —— AI Coding Kit 文档站内容生成脚本
 *
 * 职责：把源文件（skills/ · rules/ · agents/）「投影」到 docs/，并生成
 *      VitePress 侧边栏（docs/.vitepress/sidebar.generated.mjs）与各分组索引页。
 *
 * 设计哲学：单一权威源。源文件保持原位，生成物是构建产物（已在 .gitignore 忽略），
 *          绝不复制维护第二份。每次 `npm run docs:gen` 全量重建。
 *
 * 用法：node scripts/gen-docs.mjs
 */

import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, readdirSync, statSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = join(__dirname, '..')
const DOCS = join(ROOT, 'docs')

const SRC = {
  skills: join(ROOT, 'skills'),
  rules: join(ROOT, 'rules'),
  agents: join(ROOT, 'agents'),
  devflow: join(ROOT, 'skills', 'dev-flow'),
}
const OUT = {
  skills: join(DOCS, 'skills'),
  rules: join(DOCS, 'rules'),
  agents: join(DOCS, 'agents'),
  devflow: join(DOCS, 'dev-flow'),
}

// ------------------------------------------------------------------
// 通用工具
// ------------------------------------------------------------------

/** 解析 YAML frontmatter（仅支持本仓库用到的简单标量 / 内联数组，无需引第三方库） */
function parseFrontmatter(raw) {
  const m = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/)
  if (!m) return { data: {}, body: raw, hasFrontmatter: false }

  const data = {}
  const lines = m[1].split(/\r?\n/)
  for (const line of lines) {
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/)
    if (!kv) continue
    const key = kv[1]
    let val = kv[2].trim()
    if (val === '') {
      data[key] = ''
    } else if (val === 'true' || val === 'false') {
      data[key] = val === 'true'
    } else if (val.startsWith('[') && val.endsWith(']')) {
      // 内联数组：["a", "b"]
      data[key] = val
        .slice(1, -1)
        .split(',')
        .map((s) => s.trim().replace(/^["']|["']$/g, ''))
        .filter(Boolean)
    } else {
      data[key] = val.replace(/^["']|["']$/g, '')
    }
  }
  return { data, body: raw.slice(m[0].length), hasFrontmatter: true }
}

/** slug 归一化：处理空格、中文、特殊字符，生成 URL 安全片段 */
function toSlug(name) {
  return name
    .trim()
    .replace(/\.mdc?$/i, '')
    .replace(/\s+/g, '-') // 空格 → 连字符（如 "2 号" → "2-号"）
    .replace(/[/\\]/g, '-')
    .replace(/[（）()]/g, '') // 去中英文括号
    .replace(/[「」【】]/g, '')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
}

/** 转义用于 VitePress frontmatter 的 YAML 字符串值 */
function yamlString(s) {
  if (s == null) return '""'
  const needQuote = /[:#\[\]{}&*!|>'"%@`]/.test(s) || /^\s|\s$/.test(s)
  const escaped = String(s).replace(/"/g, '\\"')
  return needQuote ? `"${escaped}"` : `"${escaped}"`
}

/** 截断描述用于 feature 卡片 / 索引摘要 */
function truncate(s, n = 90) {
  if (!s) return ''
  const clean = String(s).replace(/\s+/g, ' ').trim()
  return clean.length > n ? clean.slice(0, n) + '…' : clean
}

/** 生成投影页顶部的「源文件」提示块 */
function sourceBanner(relPath) {
  return `> 📄 本页由源文件 \`${relPath}\` 自动投影生成（单一权威源）。请勿直接编辑本页。\n\n`
}

/**
 * 规范化投影正文的标题层级（避免与投影页注入的 H1 重复、避免多 H1）：
 *  1. 跳过 body 开头的前导空白 + HTML 注释块，移除紧随其后的「文档主标题」H1。
 *  2. 将正文中剩余的所有 H1 降级为 H2（源文件正文中段偶用 H1 作章节标题的情况），
 *     保护 fenced code block 内的 `#`（shell 注释）不动。
 */
function stripLeadingH1(body) {
  // 1) 移除开头主标题：允许前导空白与若干 HTML 注释块在 H1 之前
  const leading = body.match(/^(?:\s*<!--[\s\S]*?-->\s*)*/)
  const prefix = leading ? leading[0] : ''
  const rest = body.slice(prefix.length)
  const withoutMainH1 = rest.replace(/^\s*#\s+.*(\r?\n)+/, '')
  let out = prefix + withoutMainH1

  // 2) 正文剩余 H1 降级为 H2（仅代码块外）
  const parts = out.split(/(```[\s\S]*?```|~~~[\s\S]*?~~~)/g)
  out = parts
    .map((seg, i) => (i % 2 === 1 ? seg : seg.replace(/^# (?!#)/gm, '## ')))
    .join('')
  return out
}

// 允许在正文中作为真实 HTML 渲染的标签白名单（源文件里有意使用的）
const HTML_TAG_WHITELIST = new Set([
  'div', 'span', 'br', 'hr', 'img', 'a', 'b', 'i', 'em', 'strong', 'code', 'pre',
  'ul', 'ol', 'li', 'table', 'thead', 'tbody', 'tr', 'td', 'th', 'kbd', 'sub', 'sup',
  'details', 'summary', 'p', 'blockquote', 'small', 'mark', 'del', 'ins',
])

/**
 * 转义代码块外的「裸尖括号」，避免 Vue 编译器把 `<Type>` / `<your-repo-url>` / `<T>`
 * 等占位符或泛型当成未闭合 HTML 标签导致构建失败。
 * 保护 fenced code block（``` ```）与 inline code（`code`），仅处理其余文本。
 * 白名单内的合法 HTML 标签保留渲染。
 */
function escapeBareAngles(body) {
  // 以 fenced code block 为分隔切段，奇数段为代码块（保护）
  const fenceParts = body.split(/(```[\s\S]*?```|~~~[\s\S]*?~~~)/g)
  return fenceParts
    .map((seg, i) => {
      if (i % 2 === 1) return seg // fenced code block，原样保留
      // 再保护 inline code
      const inlineParts = seg.split(/(`[^`\n]*`)/g)
      return inlineParts
        .map((s, j) => {
          if (j % 2 === 1) return s // inline code，原样保留
          // 处理裸尖括号：仅转义非白名单标签的 `<`
          return s.replace(/<(\/?)([a-zA-Z][\w-]*)?/g, (match, slash, tag) => {
            if (tag && HTML_TAG_WHITELIST.has(tag.toLowerCase())) return match
            return '&lt;' + slash + (tag || '')
          })
        })
        .join('')
    })
    .join('')
}

/**
 * 重写投影正文里的相对链接，消除死链（M4）。
 * 策略：
 *  1. 外链（http/https）、file://、~/.codebuddy/、纯锚点(#xxx)、站内绝对路径(/xxx)、含占位符 → 原样保留。
 *  2. dev-flow 内部互链（steps/references/cross-project 下已投影的 .md）→ 重写为 docs 站路由，
 *     且校验目标页面确实已生成（DEVFLOW_ROUTES），不存在则降级去链接化。
 *  3. 其余相对链接（.md/.html/.sh 或指向源仓库未投影文件）→ 去链接化：`[文字](死链)` 仅保留「文字」。
 * 仅处理代码块外的文本（复用分段保护）。
 *
 * @param {string} body 正文
 * @param {'devflow'|'other'} kind 上下文类型
 * @param {string} ctxDir 当前文件相对 dev-flow 根的目录（如 'steps'、'references'、'references/cross-project'、'flowchart'）
 */
function rewriteLinks(body, kind, ctxDir = '') {
  const fenceParts = body.split(/(```[\s\S]*?```|~~~[\s\S]*?~~~)/g)
  return fenceParts
    .map((seg, i) => {
      if (i % 2 === 1) return seg // 代码块保护
      // 注意：不在此处切分 inline code，否则链接文字含反引号（如 [`references/x.md`](x.md)）
      // 会被切断导致匹配失败。Markdown 链接语法在 inline code 外仍可安全匹配。
      return seg.replace(/\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g, (match, text, url) => {
        // 1) 保留的链接类型（不会死链）
        if (
          /^https?:\/\//i.test(url) ||
          /^file:\/\//i.test(url) ||
          url.startsWith('#') ||
          url.startsWith('/') ||
          url.startsWith('mailto:') ||
          url.startsWith('~') ||
          url.includes('{')
        ) {
          return match
        }

        // 2) dev-flow 内部互链重写（校验目标存在）
        if (kind === 'devflow') {
          const mapped = mapDevFlowLink(url, ctxDir)
          if (mapped) return `[${text}](${mapped})`
        }

        // 3) 其余相对链接 → 去链接化，仅保留文字（消除死链）
        return text
      })
    })
    .join('')
}

// 已生成的 dev-flow 页面路由集合（供链接存在性校验，main 生成后填充）
const DEVFLOW_ROUTES = new Set()

/**
 * 把 dev-flow 源文件相对链接映射为 docs 站路由，并校验目标页面已生成。
 * 依据 ctxDir（当前文件目录）+ 相对 url 解析出目标在 dev-flow 内的位置。
 * 无法识别或目标未生成时返回 null（交由上层去链接化）。
 */
function mapDevFlowLink(url, ctxDir) {
  if (!/\.md(#|$)/i.test(url)) return null // 仅处理 .md 链接（.html/.sh 等去链接化）

  const hashIdx = url.indexOf('#')
  const anchor = hashIdx >= 0 ? url.slice(hashIdx) : ''
  const rawPath = hashIdx >= 0 ? url.slice(0, hashIdx) : url

  // 以 ctxDir 为基准解析相对路径（处理 ./ 与 ../）
  const ctxParts = ctxDir ? ctxDir.split('/') : []
  const segs = rawPath.split('/')
  const stack = [...ctxParts]
  for (const seg of segs) {
    if (seg === '.' || seg === '') continue
    if (seg === '..') stack.pop()
    else stack.push(seg)
  }
  // stack 现在是相对 dev-flow 根的路径，如 ['references','trigger.md'] 或 ['references','cross-project','trigger.md']
  const fileMatch = stack[stack.length - 1].match(/([^/]+)\.md$/i)
  if (!fileMatch) return null
  const base = toSlug(fileMatch[1])
  const dirSegs = stack.slice(0, -1)

  let route = null
  if (dirSegs[0] === 'steps') {
    route = `/dev-flow/steps/${base}`
  } else if (dirSegs[0] === 'references' && dirSegs[1] === 'cross-project') {
    route = `/dev-flow/references/cross-project-${base}`
  } else if (dirSegs[0] === 'references') {
    route = `/dev-flow/references/${base}`
  }

  // 校验目标已生成，避免制造新死链
  if (route && DEVFLOW_ROUTES.has(route)) return route + anchor
  return null
}

/** 写文件（自动建目录） */
function writeFile(path, content) {
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, content, 'utf8')
}

/** 投影正文统一处理：去 H1 → 重写链接（消除死链）→ 转义裸尖括号 */
function processBody(body, kind = 'other', ctxDir = '') {
  return escapeBareAngles(rewriteLinks(stripLeadingH1(body), kind, ctxDir))
}

/** 生成带 VitePress frontmatter 的投影页 */
function projectionPage({ title, description, sourceRel, body }) {
  const fm = [
    '---',
    `title: ${yamlString(title)}`,
    description ? `description: ${yamlString(truncate(description, 150))}` : null,
    '---',
    '',
  ]
    .filter((x) => x !== null)
    .join('\n')
  return fm + '\n' + sourceBanner(sourceRel) + `# ${title}\n\n` + processBody(body, 'other')
}

// ------------------------------------------------------------------
// 过滤规则（见 .docs-site-plan.md §3.5）
// ------------------------------------------------------------------
const SKILL_IGNORE = new Set(['_platform-integrations.yaml'])

// ------------------------------------------------------------------
// Skills 生成
// ------------------------------------------------------------------

// 角色分组映射（见 .docs-site-plan.md §五 IA）；dev-flow 单独作旗舰板块不在此
const SKILL_GROUPS = [
  {
    text: '流程协作类',
    keys: ['requirement-intake', 'design-advisor', 'code-review', 'tech-doc', 'smart-commit', 'coding-standards', 'frontend-patterns', 'search-first', 'issue-trace', 'dev-comp'],
  },
  {
    text: '质量保障类',
    keys: ['verification-pipeline', 'verification-loop', 'security-review', 'complexity-optimizer', 'browser-compat'],
  },
  {
    text: '工具能力类',
    keys: ['agent-browser', 'browser-toolkit', 'e2e-testing', 'dom-animation', 'i18n', 'pdf-reader', 'research-doc', 'tavily-search', 'find-skills'],
  },
  {
    text: '学习进化类',
    keys: ['knowledge-loop', 'self-improving-agent', 'continuous-learning-v2', 'proactive-agent'],
  },
]

function generateSkills() {
  const entries = readdirSync(SRC.skills)
    .filter((name) => !SKILL_IGNORE.has(name) && name !== 'dev-flow')
    .filter((name) => statSync(join(SRC.skills, name)).isDirectory())
    .filter((name) => existsSync(join(SRC.skills, name, 'SKILL.md')))

  const meta = {} // slug -> { name, slug, description }
  for (const name of entries) {
    const srcPath = join(SRC.skills, name, 'SKILL.md')
    const raw = readFileSync(srcPath, 'utf8')
    const { data, body } = parseFrontmatter(raw)
    const title = data.name || name
    const description = data.description || ''
    const slug = toSlug(name)
    meta[name] = { name: title, slug, description }

    const page = projectionPage({
      title,
      description,
      sourceRel: `skills/${name}/SKILL.md`,
      body,
    })
    writeFile(join(OUT.skills, `${slug}.md`), page)
  }

  // 分组索引页 docs/skills/index.md
  const grouped = new Set()
  let indexBody = ''
  for (const group of SKILL_GROUPS) {
    const rows = []
    for (const key of group.keys) {
      if (!meta[key]) continue
      grouped.add(key)
      const m = meta[key]
      rows.push(`| [\`${m.name}\`](/skills/${m.slug}) | ${truncate(m.description, 60)} |`)
    }
    if (rows.length === 0) continue
    indexBody += `\n### ${group.text}\n\n| Skill | 简介 |\n|-------|------|\n${rows.join('\n')}\n`
  }
  // 未归类的兜底分组
  const ungrouped = Object.keys(meta).filter((k) => !grouped.has(k))
  if (ungrouped.length) {
    const rows = ungrouped.map((k) => `| [\`${meta[k].name}\`](/skills/${meta[k].slug}) | ${truncate(meta[k].description, 60)} |`)
    indexBody += `\n### 其他\n\n| Skill | 简介 |\n|-------|------|\n${rows.join('\n')}\n`
  }

  const indexPage = `---\ntitle: Skills 生态\n---\n\n# Skills 生态\n\n> 共 ${entries.length} 个 AI 技能（dev-flow 旗舰单列，见 [dev-flow 板块](/dev-flow/)），按角色分组。\n${indexBody}`
  writeFile(join(OUT.skills, 'index.md'), indexPage)

  // 侧边栏
  const sidebarGroups = SKILL_GROUPS.map((group) => ({
    text: group.text,
    collapsed: false,
    items: group.keys
      .filter((k) => meta[k])
      .map((k) => ({ text: meta[k].name, link: `/skills/${meta[k].slug}` })),
  })).filter((g) => g.items.length > 0)

  if (ungrouped.length) {
    sidebarGroups.push({
      text: '其他',
      collapsed: false,
      items: ungrouped.map((k) => ({ text: meta[k].name, link: `/skills/${meta[k].slug}` })),
    })
  }

  const sidebar = [{ text: '📚 Skills 总览', link: '/skills/' }, ...sidebarGroups]
  return { count: entries.length, sidebar }
}

// ------------------------------------------------------------------
// Rules 生成
// ------------------------------------------------------------------
function generateRules() {
  const files = readdirSync(SRC.rules).filter((f) => f.endsWith('.mdc'))

  const groups = {
    core: { text: '核心红线（alwaysApply）', items: [] },
    official: { text: '官方规范', items: [] },
    onDemand: { text: '按需规范', items: [] },
  }
  const meta = {}

  for (const file of files) {
    const srcPath = join(SRC.rules, file)
    const raw = readFileSync(srcPath, 'utf8')
    const { data, body } = parseFrontmatter(raw)
    const baseName = file.replace(/\.mdc$/, '')
    const slug = toSlug(baseName)
    const title = baseName
    const description = data.description || ''

    // 分类：alwaysApply=true → 核心红线；官方规范/编程指南 → 官方；其余 → 按需
    let cat = 'onDemand'
    if (data.alwaysApply === true) cat = 'core'
    else if (/官方规范$/.test(baseName) || /^(TypeScript|CSS|SQL)_/.test(baseName)) cat = 'official'
    else cat = 'onDemand'

    meta[slug] = { title, slug, description, cat }
    groups[cat].items.push({ text: title, link: `/rules/${slug}` })

    const page = projectionPage({
      title,
      description,
      sourceRel: `rules/${file}`,
      body,
    })
    writeFile(join(OUT.rules, `${slug}.md`), page)
  }

  // 索引页
  let indexBody = ''
  for (const key of ['core', 'official', 'onDemand']) {
    const g = groups[key]
    if (g.items.length === 0) continue
    const rows = g.items.map((it) => {
      const m = Object.values(meta).find((x) => x.slug === it.link.split('/').pop())
      return `| [${it.text}](${it.link}) | ${truncate(m?.description || '', 60) || '—'} |`
    })
    indexBody += `\n### ${g.text}（${g.items.length} 条）\n\n| 规则 | 说明 |\n|------|------|\n${rows.join('\n')}\n`
  }
  const indexPage = `---\ntitle: Rules 规范\n---\n\n# Rules 规范\n\n> 共 ${files.length} 条编码规范与项目规则，约束 AI 代码生成行为。\n${indexBody}`
  writeFile(join(OUT.rules, 'index.md'), indexPage)

  const sidebar = [
    { text: '📏 Rules 总览', link: '/rules/' },
    ...['core', 'official', 'onDemand']
      .map((k) => ({ text: groups[k].text, collapsed: false, items: groups[k].items }))
      .filter((g) => g.items.length > 0),
  ]
  return { count: files.length, sidebar }
}

// ------------------------------------------------------------------
// Agents 生成
// ------------------------------------------------------------------
function generateAgents() {
  const files = readdirSync(SRC.agents).filter((f) => f.endsWith('.md'))
  const meta = []

  for (const file of files) {
    const srcPath = join(SRC.agents, file)
    const raw = readFileSync(srcPath, 'utf8')
    const { data, body, hasFrontmatter } = parseFrontmatter(raw)
    const baseName = file.replace(/\.md$/, '')
    const slug = toSlug(baseName)

    let title = data.name || baseName
    let description = data.description || ''

    // step-gate 无 frontmatter：从首个 # 标题 + 引用块提取
    if (!hasFrontmatter) {
      const h1 = body.match(/^#\s+(.+)$/m)
      title = h1 ? h1[1].trim() : baseName
      const quote = body.match(/^>\s*(.+)$/m)
      description = quote ? quote[1].replace(/^职责[：:]\s*/, '').trim() : ''
    }

    // 工具白名单表（若有 tools 字段）
    let toolsTable = ''
    if (data.tools) {
      const tools = String(data.tools)
        .split(',')
        .map((t) => t.trim())
        .filter(Boolean)
      const mcp = data.mcpTools
        ? String(data.mcpTools).split(',').map((t) => t.trim()).filter(Boolean)
        : []
      toolsTable =
        `\n## 配置\n\n| 项 | 值 |\n|----|----|\n` +
        (data.model ? `| 模型 | \`${data.model}\` |\n` : '') +
        (data.agentMode ? `| 模式 | \`${data.agentMode}\` |\n` : '') +
        `| 工具白名单 | ${tools.map((t) => `\`${t}\``).join(' · ')} |\n` +
        (mcp.length ? `| MCP 工具 | ${mcp.map((t) => `\`${t}\``).join(' · ')} |\n` : '') +
        '\n'
    }

    const bodyWithoutH1 = processBody(body, 'other')
    // 描述引用块：仅当 description 来自 frontmatter（不在正文）时注入，
    // 避免无 frontmatter 的 agent（如 step-gate）正文已含该引用块导致重复。
    const descBlock = hasFrontmatter && description ? `> ${description}\n\n` : ''
    const page =
      `---\ntitle: ${yamlString(title)}\n${description ? `description: ${yamlString(truncate(description, 150))}\n` : ''}---\n\n` +
      sourceBanner(`agents/${file}`) +
      `# ${title}\n\n` +
      descBlock +
      toolsTable +
      bodyWithoutH1

    writeFile(join(OUT.agents, `${slug}.md`), page)
    meta.push({ title, slug, description, baseName })
  }

  // 排序：1号~9号 在前，step-gate 收尾
  meta.sort((a, b) => {
    const na = parseInt(a.baseName, 10)
    const nb = parseInt(b.baseName, 10)
    if (!isNaN(na) && !isNaN(nb)) return na - nb
    if (!isNaN(na)) return -1
    if (!isNaN(nb)) return 1
    return a.baseName.localeCompare(b.baseName)
  })

  const rows = meta.map((m) => `| [${m.title}](/agents/${m.slug}) | ${truncate(m.description, 60) || '—'} |`)
  const indexPage = `---\ntitle: Agents\n---\n\n# Agents\n\n> 共 ${files.length} 个专职 AI Agent 配置，覆盖不同开发场景。\n\n| Agent | 职责 |\n|-------|------|\n${rows.join('\n')}\n`
  writeFile(join(OUT.agents, 'index.md'), indexPage)

  const sidebar = [
    { text: '🤖 Agents 总览', link: '/agents/' },
    { text: 'Agent 列表', collapsed: false, items: meta.map((m) => ({ text: m.title, link: `/agents/${m.slug}` })) },
  ]
  return { count: files.length, sidebar }
}

// ------------------------------------------------------------------
// dev-flow 旗舰板块生成（M3）
// ------------------------------------------------------------------

// steps 顺序（阶段 0 路由器 + 步骤 1~10）
const DEVFLOW_STEP_ORDER = [
  'step-router',
  'step-1-research',
  'step-2-scope',
  'step-3-plan',
  'step-4-decision',
  'step-4.5-env-check',
  'step-5-execute',
  'step-5.5-post-coding',
  'step-6-verify',
  'step-7-commit',
  'step-8-10-full',
]

// references 主题分组（键为该组包含的文件名，不含扩展名）；未列出的落入「其他参考」兜底组
const DEVFLOW_REF_GROUPS = [
  {
    text: '核心与流程',
    keys: ['core-principles', 'flow-graph', 'shared-rules', 'mode-matrix', 'interaction-mode', 'menu', 'help'],
  },
  {
    text: '步骤支撑',
    keys: ['working-context', 'active-flows', 'gate-validator', 'output-schemas', 'rollback', 'iteration-fix', 'drift-handling', 'branch-recommendation', 'code-safety-rules'],
  },
  {
    text: '文档与知识',
    keys: ['doc-sync-rules', 'devlog-rules', 'tech-proposal-flow', 'in-flow-sync', 'remote-knowledge', 'metrics-rules', 'flow-retrospective'],
  },
  {
    text: '验收 · 联调 · 调用图',
    keys: ['user-acceptance', 'integration-flow', 'call-graph-spec', 'cross-project-flow'],
  },
  {
    text: '专项规范',
    keys: ['react', 'component-library', 'env-tools', 'tdd-mode', 'topic-specs'],
  },
  {
    text: '模式与场景',
    keys: ['no-dev-flow-mode', 'micro-fix-light', 'figma-flow', 'onboard-flow', 'conversation-quality', 'token-management'],
  },
  {
    text: '元与维护',
    keys: ['dist-sync', 'skill-full'],
  },
]

/** 读取源 md 并投影为 dev-flow 子页（复用 escape / stripH1 / banner） */
function projectDevFlowDoc({ srcAbs, sourceRel, title, outAbs, ctxDir = '' }) {
  const raw = readFileSync(srcAbs, 'utf8')
  const { body } = parseFrontmatter(raw)
  const page =
    `---\ntitle: ${yamlString(title)}\n---\n\n` +
    sourceBanner(sourceRel) +
    `# ${title}\n\n` +
    processBody(body, 'devflow', ctxDir)
  writeFile(outAbs, page)
}

function generateDevFlow() {
  const D = SRC.devflow
  const O = OUT.devflow

  // 预扫描：填充 DEVFLOW_ROUTES（供 rewriteLinks 校验内部链接目标是否真实存在）
  DEVFLOW_ROUTES.clear()
  for (const step of DEVFLOW_STEP_ORDER) {
    if (existsSync(join(D, 'steps', `${step}.md`))) DEVFLOW_ROUTES.add(`/dev-flow/steps/${toSlug(step)}`)
  }
  const refDirPre = join(D, 'references')
  for (const f of readdirSync(refDirPre).filter((x) => x.endsWith('.md') && x !== '_index.md')) {
    DEVFLOW_ROUTES.add(`/dev-flow/references/${toSlug(f.replace(/\.md$/, ''))}`)
  }
  const cpDirPre = join(refDirPre, 'cross-project')
  if (existsSync(cpDirPre)) {
    for (const f of readdirSync(cpDirPre).filter((x) => x.endsWith('.md'))) {
      DEVFLOW_ROUTES.add(`/dev-flow/references/cross-project-${toSlug(f.replace(/\.md$/, ''))}`)
    }
  }

  // 1) 概览页（README.md）——作为 dev-flow 板块首页 index.md
  projectDevFlowDoc({
    srcAbs: join(D, 'README.md'),
    sourceRel: 'skills/dev-flow/README.md',
    title: 'dev-flow 概览',
    outAbs: join(O, 'index.md'),
  })

  // 2) 触发与命令（SKILL.md）
  projectDevFlowDoc({
    srcAbs: join(D, 'SKILL.md'),
    sourceRel: 'skills/dev-flow/SKILL.md',
    title: 'dev-flow 触发与命令',
    outAbs: join(O, 'skill.md'),
  })

  // 3) 流程总览（flow.md）
  if (existsSync(join(D, 'flow.md'))) {
    projectDevFlowDoc({
      srcAbs: join(D, 'flow.md'),
      sourceRel: 'skills/dev-flow/flow.md',
      title: 'dev-flow 流程总览',
      outAbs: join(O, 'flow.md'),
    })
  }

  // 4) 步骤详解 steps/
  const stepMeta = []
  for (const step of DEVFLOW_STEP_ORDER) {
    const srcAbs = join(D, 'steps', `${step}.md`)
    if (!existsSync(srcAbs)) continue
    const raw = readFileSync(srcAbs, 'utf8')
    const h1 = raw.match(/^#\s+(.+)$/m)
    const title = h1 ? h1[1].trim() : step
    const slug = toSlug(step)
    projectDevFlowDoc({ srcAbs, sourceRel: `skills/dev-flow/steps/${step}.md`, title, outAbs: join(O, 'steps', `${slug}.md`), ctxDir: 'steps' })
    stepMeta.push({ title, slug })
  }

  // 5) 参考规范 references/（含 cross-project 子目录）
  const refDir = join(D, 'references')
  const refFiles = readdirSync(refDir).filter((f) => f.endsWith('.md') && f !== '_index.md')
  const refMeta = {} // baseName -> { title, slug }
  for (const file of refFiles) {
    const srcAbs = join(refDir, file)
    const base = file.replace(/\.md$/, '')
    const raw = readFileSync(srcAbs, 'utf8')
    const h1 = raw.match(/^#\s+(.+)$/m)
    const title = h1 ? h1[1].trim() : base
    const slug = toSlug(base)
    projectDevFlowDoc({ srcAbs, sourceRel: `skills/dev-flow/references/${file}`, title, outAbs: join(O, 'references', `${slug}.md`), ctxDir: 'references' })
    refMeta[base] = { title, slug }
  }

  // cross-project 子目录
  const cpDir = join(refDir, 'cross-project')
  const cpMeta = []
  if (existsSync(cpDir)) {
    for (const file of readdirSync(cpDir).filter((f) => f.endsWith('.md'))) {
      const srcAbs = join(cpDir, file)
      const base = file.replace(/\.md$/, '')
      const raw = readFileSync(srcAbs, 'utf8')
      const h1 = raw.match(/^#\s+(.+)$/m)
      const title = h1 ? h1[1].trim() : base
      const slug = `cross-project-${toSlug(base)}`
      projectDevFlowDoc({ srcAbs, sourceRel: `skills/dev-flow/references/cross-project/${file}`, title, outAbs: join(O, 'references', `${slug}.md`), ctxDir: 'references/cross-project' })
      cpMeta.push({ title: `跨项目 · ${title}`, slug })
    }
  }

  // 6) 流程图 flowchart/（各版本 Mermaid）
  const fcDir = join(D, 'flowchart', 'versions')
  const versions = existsSync(fcDir)
    ? readdirSync(fcDir).filter((d) => statSync(join(fcDir, d)).isDirectory()).sort()
    : []
  const versionMeta = []
  for (const v of versions) {
    const mdPath = join(fcDir, v, 'flowchart.md')
    if (!existsSync(mdPath)) continue
    const label = v.replace(/_/g, ' ') // v5 2026-07-22
    const slug = toSlug(v)
    projectDevFlowDoc({
      srcAbs: mdPath,
      sourceRel: `skills/dev-flow/flowchart/versions/${v}/flowchart.md`,
      title: `流程图 ${label}`,
      outAbs: join(O, 'flowchart', `${slug}.md`),
      ctxDir: 'flowchart',
    })
    versionMeta.push({ label, slug, version: v })
  }
  // 流程图入口页（版本切换）
  const latest = versionMeta[versionMeta.length - 1]
  const fcIndex =
    `---\ntitle: dev-flow 流程图\n---\n\n# dev-flow 流程图\n\n` +
    `> 各版本流程图均为 Mermaid 源码，VitePress 原生渲染。默认展示最新版 **${latest ? latest.label : ''}**。\n\n` +
    `## 版本切换\n\n| 版本 | 说明 |\n|------|------|\n` +
    versionMeta
      .slice()
      .reverse()
      .map((v) => `| [${v.label}](/dev-flow/flowchart/${v.slug})${v === latest ? '（最新）' : ''} | 流程图 ${v.label} |`)
      .join('\n') +
    '\n'
  writeFile(join(O, 'flowchart', 'index.md'), fcIndex)

  // ---- 侧边栏 ----
  const refGrouped = new Set()
  const refGroupSidebar = DEVFLOW_REF_GROUPS.map((g) => ({
    text: g.text,
    collapsed: true,
    items: g.keys
      .filter((k) => refMeta[k])
      .map((k) => {
        refGrouped.add(k)
        return { text: refMeta[k].title, link: `/dev-flow/references/${refMeta[k].slug}` }
      }),
  })).filter((g) => g.items.length > 0)

  // 跨项目单列一组
  if (cpMeta.length) {
    refGroupSidebar.push({
      text: '跨项目协作',
      collapsed: true,
      items: cpMeta.map((m) => ({ text: m.title, link: `/dev-flow/references/${m.slug}` })),
    })
  }
  // 兜底：未归类的 references
  const refUngrouped = Object.keys(refMeta).filter((k) => !refGrouped.has(k))
  if (refUngrouped.length) {
    refGroupSidebar.push({
      text: '其他参考',
      collapsed: true,
      items: refUngrouped.map((k) => ({ text: refMeta[k].title, link: `/dev-flow/references/${refMeta[k].slug}` })),
    })
  }

  const sidebar = [
    {
      text: '🚩 dev-flow',
      items: [
        { text: '概览', link: '/dev-flow/' },
        { text: '触发与命令', link: '/dev-flow/skill' },
        ...(existsSync(join(D, 'flow.md')) ? [{ text: '流程总览', link: '/dev-flow/flow' }] : []),
        { text: '流程图（Mermaid）', link: '/dev-flow/flowchart/' },
      ],
    },
    {
      text: '步骤详解',
      collapsed: false,
      items: stepMeta.map((s) => ({ text: s.title, link: `/dev-flow/steps/${s.slug}` })),
    },
    // 参考规范（按主题分组，含跨项目 / 兜底组）
    ...refGroupSidebar,
  ]

  const refTotal = Object.keys(refMeta).length + cpMeta.length
  return {
    sidebar,
    counts: { steps: stepMeta.length, refs: refTotal, versions: versionMeta.length },
  }
}

// ------------------------------------------------------------------
// 主流程
// ------------------------------------------------------------------
function clean() {
  for (const dir of [OUT.skills, OUT.rules, OUT.agents, OUT.devflow]) {
    if (existsSync(dir)) rmSync(dir, { recursive: true, force: true })
  }
}

function main() {
  console.log('🚀 gen-docs：开始生成文档站内容…')
  clean()

  const skills = generateSkills()
  console.log(`  ✓ Skills：${skills.count} 个页面`)

  const rules = generateRules()
  console.log(`  ✓ Rules：${rules.count} 个页面`)

  const agents = generateAgents()
  console.log(`  ✓ Agents：${agents.count} 个页面`)

  const devflow = generateDevFlow()
  console.log(`  ✓ dev-flow：${devflow.counts.steps} 步骤 + ${devflow.counts.refs} 参考 + ${devflow.counts.versions} 版本流程图`)

  // 聚合侧边栏
  const sidebar = {
    '/dev-flow/': devflow.sidebar,
    '/skills/': skills.sidebar,
    '/rules/': rules.sidebar,
    '/agents/': agents.sidebar,
  }

  const sidebarFile = join(DOCS, '.vitepress', 'sidebar.generated.mjs')
  const content =
    `// ⚠️ 本文件由 scripts/gen-docs.mjs 自动生成，请勿手动编辑。\n` +
    `// 运行 \`npm run docs:gen\` 重新生成。\n\n` +
    `export const sidebar = ${JSON.stringify(sidebar, null, 2)}\n\n` +
    `export default sidebar\n`
  writeFile(sidebarFile, content)
  console.log(`  ✓ 侧边栏：docs/.vitepress/sidebar.generated.mjs`)

  console.log('✅ gen-docs：生成完成')
}

main()
