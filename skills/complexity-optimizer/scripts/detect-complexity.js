#!/usr/bin/env node

/**
 * 复杂度检测脚本
 * 基于 ESLint complexity 规则，输出复杂度超过20的函数
 * 
 * 支持没有 eslint 配置的项目：自动查找有配置的兄弟项目进行检测
 * 
 * 用法: node detect-complexity.js <文件路径>
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const THRESHOLD = 20;

/**
 * 移除文件中的 eslint-disable complexity 注释
 * 返回处理后的内容和是否有移除
 */
function removeComplexityDisable(content) {
  // 匹配各种形式的 eslint-disable complexity 注释
  const patterns = [
    /\/\*\s*eslint-disable\s+complexity\s*\*\//g,
    /\/\*\s*eslint-disable-next-line\s+complexity\s*\*\//g,
    /\/\/\s*eslint-disable-next-line\s+complexity/g,
    /\/\/\s*eslint-disable-line\s+complexity/g,
  ];
  
  let result = content;
  let removed = false;
  
  for (const pattern of patterns) {
    if (pattern.test(result)) {
      removed = true;
      result = result.replace(pattern, '/* TEMP_REMOVED_COMPLEXITY_DISABLE */');
    }
  }
  
  return { content: result, removed };
}

/**
 * 查找有 eslint 配置的目录
 * 优先查找当前目录，其次查找兄弟目录（如 my-project）
 */
function findEslintConfigDir(filePath) {
  const absPath = path.resolve(filePath);
  let dir = path.dirname(absPath);
  
  // 向上查找 eslint 配置
  while (dir !== path.dirname(dir)) {
    const configFiles = ['.eslintrc.js', '.eslintrc.json', '.eslintrc', '.eslintrc.yaml', '.eslintrc.yml'];
    for (const cfg of configFiles) {
      if (fs.existsSync(path.join(dir, cfg))) {
        return { configDir: dir, hasConfig: true };
      }
    }
    dir = path.dirname(dir);
  }
  
  return { configDir: null, hasConfig: false };
}

/**
 * 查找有 eslint 配置的兄弟项目目录
 */
function findSiblingEslintDir(workspaceRoot) {
  const candidates = ['my-project', 'another-project', 'third-project', 'fourth-project'];
  for (const name of candidates) {
    const dir = path.join(workspaceRoot, name);
    if (fs.existsSync(path.join(dir, '.eslintrc.js'))) {
      return dir;
    }
  }
  return null;
}

/**
 * 运行 eslint 检测
 */
function runEslint(filePath, cwd) {
  let output = '';
  try {
    output = execSync(
      `npx eslint --rule "complexity: [error, { max: 1 }]" --format json "${filePath}" 2>&1`,
      { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024, cwd }
    );
  } catch (e) {
    output = e.stdout || e.stderr || '';
  }
  return output;
}

function detectComplexity(filePath) {
  const absFilePath = path.resolve(filePath);
  
  if (!fs.existsSync(absFilePath)) {
    console.error(`❌ 文件不存在: ${filePath}`);
    process.exit(1);
  }

  // 读取文件内容，检查是否有 eslint-disable complexity 注释
  const originalContent = fs.readFileSync(absFilePath, 'utf-8');
  const { content: processedContent, removed: hasDisableComment } = removeComplexityDisable(originalContent);

  const { configDir, hasConfig } = findEslintConfigDir(absFilePath);
  
  let output = '';
  let tempFile = null;
  let usedFallback = false;
  
  if (hasConfig) {
    if (hasDisableComment) {
      // 有 disable 注释，需要创建临时文件
      const dir = path.dirname(absFilePath);
      const ext = path.extname(absFilePath);
      tempFile = path.join(dir, `_temp_complexity_${Date.now()}${ext}`);
      fs.writeFileSync(tempFile, processedContent, 'utf-8');
      try {
        output = runEslint(tempFile, configDir);
      } finally {
        if (fs.existsSync(tempFile)) {
          fs.unlinkSync(tempFile);
        }
      }
    } else {
      // 无 disable 注释，直接运行
      output = runEslint(absFilePath, configDir);
    }
  } else {
    // 没有配置，尝试使用兄弟项目的配置
    // 查找 workspace 根目录（向上找到包含多个子项目的目录）
    let workspaceRoot = path.dirname(absFilePath);
    while (workspaceRoot !== path.dirname(workspaceRoot)) {
      const siblings = ['my-project', 'other-project', 'another-project'].filter(
        name => fs.existsSync(path.join(workspaceRoot, name))
      );
      if (siblings.length >= 2) break;
      workspaceRoot = path.dirname(workspaceRoot);
    }
    
    const fallbackDir = findSiblingEslintDir(workspaceRoot);
    
    if (fallbackDir) {
      // 复制文件到有配置的项目 src 目录下临时检测（使用处理后的内容）
      const srcDir = path.join(fallbackDir, 'src');
      const fileName = `_temp_complexity_check_${Date.now()}${path.extname(absFilePath)}`;
      tempFile = path.join(srcDir, fileName);
      
      fs.writeFileSync(tempFile, processedContent, 'utf-8');
      usedFallback = true;
      
      try {
        output = runEslint(tempFile, fallbackDir);
      } finally {
        // 清理临时文件
        if (fs.existsSync(tempFile)) {
          fs.unlinkSync(tempFile);
        }
      }
    } else {
      // 没有找到可用配置，尝试直接运行
      output = runEslint(absFilePath, process.cwd());
    }
  }

  const issues = [];
  try {
    // 提取 JSON 部分（跳过 TypeScript 版本警告等前缀信息）
    const jsonStart = output.indexOf('[{');
    const jsonEnd = output.lastIndexOf('}]');
    if (jsonStart === -1 || jsonEnd === -1) {
      throw new Error('No JSON found');
    }
    const jsonStr = output.substring(jsonStart, jsonEnd + 2);
    const json = JSON.parse(jsonStr);
    if (json[0]?.messages) {
      for (const msg of json[0].messages) {
        if (msg.ruleId === 'complexity') {
          const match = msg.message.match(/complexity of (\d+)/);
          if (match) {
            issues.push({
              line: msg.line,
              name: msg.message.replace(/\s+has a complexity of \d+.*$/, '').trim(),
              complexity: parseInt(match[1], 10),
            });
          }
        }
      }
    }
  } catch {
    // 文本解析备用
    for (const line of output.split('\n')) {
      const m = line.match(/(\d+):\d+\s+\w+\s+(.+?)\s+(?:has\s+)?(?:a\s+)?complexity of (\d+)/i);
      if (m) {
        issues.push({ line: parseInt(m[1], 10), name: m[2].trim(), complexity: parseInt(m[3], 10) });
      }
    }
  }

  const high = issues.filter(i => i.complexity > THRESHOLD).sort((a, b) => b.complexity - a.complexity);

  console.log(`\n文件: ${filePath}`);
  console.log(`阈值: ${THRESHOLD}`);
  if (hasDisableComment) {
    console.log('(已临时移除 eslint-disable complexity 注释)');
  }
  if (usedFallback) {
    console.log('(使用兄弟项目 eslint 配置检测)');
  }
  console.log('');

  if (high.length === 0) {
    console.log('✅ 所有函数复杂度 ≤ 20\n');
  } else {
    console.log(`🔴 复杂度超过 ${THRESHOLD} 的函数:\n`);
    high.forEach((i, idx) => {
      console.log(`${idx + 1}. ${i.name} (第 ${i.line} 行)`);
      console.log(`   复杂度: ${i.complexity} (超出 ${i.complexity - THRESHOLD})\n`);
    });
  }

  return high;
}

if (require.main === module) {
  const filePath = process.argv[2];
  if (!filePath) {
    console.log('用法: node detect-complexity.js <文件路径>');
    process.exit(1);
  }

  detectComplexity(filePath);
}

module.exports = { detectComplexity };
