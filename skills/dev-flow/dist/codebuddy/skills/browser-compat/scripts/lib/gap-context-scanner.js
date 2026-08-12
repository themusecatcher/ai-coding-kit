/**
 * gap-context-scanner.js
 *
 * 区分 Flexbox gap (Safari 14.1+) 与 Grid gap (Safari 10.1+)：
 *   - display:flex 同块内的 gap → CRITICAL
 *   - display:grid 同块内的 gap → 不报
 *   - 无明确 display 上下文 → WARNING（降级，提示人工确认）
 *
 * 第一版限制：
 *   - SCSS 嵌套不做 display 继承（嵌套块内的 gap 若该块无 display:flex/grid → WARNING）
 *   - 字符串字面量内的 { } 不会误吞（用简易词法跳过）
 */

/**
 * 拆出顶层 + 嵌套块（每个 { ... } 范围都视为一个块），返回 [{ start, end, body }]
 * start/end 为 content 中的字符索引（指向块内容，不含外层大括号）
 */
function extractBlocks(content) {
  const blocks = [];
  const stack = []; // 存放每个 { 的位置
  let i = 0;
  let inString = null;       // " or ' or `
  let inLineComment = false;
  let inBlockComment = false;

  while (i < content.length) {
    const ch = content[i];
    const next = content[i + 1];

    // 注释/字符串状态机
    if (inLineComment) {
      if (ch === '\n') inLineComment = false;
      i += 1;
      continue;
    }
    if (inBlockComment) {
      if (ch === '*' && next === '/') {
        inBlockComment = false;
        i += 2;
        continue;
      }
      i += 1;
      continue;
    }
    if (inString) {
      if (ch === '\\') {
        i += 2;
        continue;
      }
      if (ch === inString) inString = null;
      i += 1;
      continue;
    }
    if (ch === '/' && next === '/') {
      inLineComment = true;
      i += 2;
      continue;
    }
    if (ch === '/' && next === '*') {
      inBlockComment = true;
      i += 2;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') {
      inString = ch;
      i += 1;
      continue;
    }
    if (ch === '{') {
      stack.push(i + 1);
      i += 1;
      continue;
    }
    if (ch === '}') {
      const start = stack.pop();
      if (start !== undefined) {
        blocks.push({ start, end: i });
      }
      i += 1;
      continue;
    }
    i += 1;
  }
  return blocks;
}

/**
 * 在指定块内查找直接的 display 声明（不递归到子块）
 *   - 跳过子块（嵌套 { ... }）
 *   - 返回 'flex' / 'grid' / null（未明确）
 *
 * 优化：直接在原 content 上扫描指定区间，跳过嵌套子块的字符。
 */
function detectDisplayInBlock(content, block, allBlocks) {
  // 收集 block 范围内的子块（直接子块，不含孙子块）
  const childBlocks = allBlocks
    .filter((b) => b !== block && b.start > block.start && b.end < block.end)
    .filter((b, _, arr) => {
      // 仅保留「直接父级是 block」的子块：父级 = 包裹它的最小块
      // 简化：最近祖先即父级
      const ancestors = arr.filter((p) => p.start < b.start && p.end > b.end);
      const minSpan = ancestors.reduce(
        (acc, cur) => (cur.end - cur.start < acc ? cur.end - cur.start : acc),
        Infinity
      );
      return ancestors.some((p) => p.end - p.start === minSpan && p === block);
    });

  // 从 block.start 到 block.end，过滤掉所有子块的范围
  let body = '';
  let cursor = block.start;
  for (const child of childBlocks.sort((a, b) => a.start - b.start)) {
    body += content.slice(cursor, child.start - 1); // -1 跳过 '{'
    cursor = child.end + 1; // +1 跳过 '}'
  }
  body += content.slice(cursor, block.end);

  if (/\bdisplay\s*:\s*(?:inline-)?flex\b/.test(body)) return 'flex';
  if (/\bdisplay\s*:\s*(?:inline-)?grid\b/.test(body)) return 'grid';
  return null;
}

/**
 * 扫描 CSS 内容中的 gap 使用，结合 display 上下文判定 severity
 * @returns {Array<{ severity, line, column, matchIndex, code_snippet, contextHint }>}
 */
function scanGapWithContext(content) {
  const blocks = extractBlocks(content);
  const findings = [];
  const gapRegex = /\bgap\s*:\s*[\d.]+/g;
  let m;

  while ((m = gapRegex.exec(content)) !== null) {
    const matchIndex = m.index;

    // 找到该 match 所在的最内层块
    const containingBlocks = blocks.filter((b) => b.start <= matchIndex && b.end >= matchIndex);
    if (containingBlocks.length === 0) {
      // 不在任何块内（顶层裸 gap，几乎不会出现，CSS 语法错误）→ 跳过
      continue;
    }
    // 最内层 = 块尺寸最小的
    const innermost = containingBlocks.sort((a, b) => (a.end - a.start) - (b.end - b.start))[0];

    const display = detectDisplayInBlock(content, innermost, blocks);

    // 行号
    const lineNum = content.slice(0, matchIndex).split('\n').length;
    const lineStart = content.lastIndexOf('\n', matchIndex - 1) + 1;
    const lineEnd = content.indexOf('\n', matchIndex);
    const codeSnippet = content.slice(lineStart, lineEnd === -1 ? content.length : lineEnd).trim();

    if (display === 'flex') {
      findings.push({
        severity: 'CRITICAL',
        line: lineNum,
        matchIndex,
        code_snippet: codeSnippet,
        contextHint: 'flex',
      });
    } else if (display === 'grid') {
      // Grid 的 gap Safari 10.1+ 支持，不报
      continue;
    } else {
      findings.push({
        severity: 'WARNING',
        line: lineNum,
        matchIndex,
        code_snippet: codeSnippet,
        contextHint: 'unknown',
      });
    }
  }

  return findings;
}

module.exports = {
  scanGapWithContext,
  // 仅供测试
  _internal: { extractBlocks, detectDisplayInBlock },
};
