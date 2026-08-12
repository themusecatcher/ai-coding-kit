#!/usr/bin/env node

function usage() {
  console.error(`用法: extract.mjs "url1" ["url2" ...]`);
  process.exit(2);
}

const args = process.argv.slice(2);
if (args.length === 0 || args[0] === "-h" || args[0] === "--help") usage();

const urls = args.filter(a => !a.startsWith("-"));

if (urls.length === 0) {
  console.error("未提供 URL");
  usage();
}

const apiKey = (process.env.TAVILY_API_KEY ?? "").trim();
if (!apiKey) {
  console.error("缺少 TAVILY_API_KEY 环境变量");
  process.exit(1);
}

const resp = await fetch("https://api.tavily.com/extract", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    api_key: apiKey,
    urls: urls,
  }),
});

if (!resp.ok) {
  const text = await resp.text().catch(() => "");
  throw new Error(`Tavily 内容提取失败 (${resp.status}): ${text}`);
}

const data = await resp.json();

const results = data.results ?? [];
const failed = data.failed_results ?? [];

for (const r of results) {
  const url = String(r?.url ?? "").trim();
  const content = String(r?.raw_content ?? "").trim();
  
  console.log(`# ${url}\n`);
  console.log(content || "(未提取到内容)");
  console.log("\n---\n");
}

if (failed.length > 0) {
  console.log("## 失败的 URL\n");
  for (const f of failed) {
    console.log(`- ${f.url}: ${f.error}`);
  }
}
