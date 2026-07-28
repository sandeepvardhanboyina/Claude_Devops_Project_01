// Reads reports/summary-*.json and writes reports/SUMMARY.md — one table across
// every stage. Run with:  node summarize.mjs
import { readdirSync, readFileSync, writeFileSync } from "node:fs";

const dir = "reports";
const rows = readdirSync(dir)
  .filter((f) => /^summary-.*\.json$/.test(f))
  .map((f) => JSON.parse(readFileSync(`${dir}/${f}`, "utf8")))
  .sort((a, b) => a.concurrent_users - b.concurrent_users);

if (rows.length === 0) {
  console.error("No reports/summary-*.json files found. Run the load test first.");
  process.exit(1);
}

let md = `# Load Test Results\n\n`;
md += `- Target: ${rows[0].target}\n`;
md += `- Duration per stage: ${rows[0].duration}\n`;
md += `- Tool: k6 (constant virtual users)\n\n`;
md += `| Users | Requests | Req/s | Avg (ms) | p95 (ms) | Max (ms) | Error % | Throughput (KB/s) |\n`;
md += `|------:|---------:|------:|---------:|---------:|---------:|--------:|------------------:|\n`;
for (const r of rows) {
  const t = r.response_time_ms;
  md += `| ${r.concurrent_users} | ${r.requests_total} | ${r.requests_per_sec} | ${t.avg} | ${t.p95} | ${t.max} | ${r.error_rate_pct} | ${r.throughput_kb_per_sec} |\n`;
}
md += `\n_Generated ${new Date().toISOString()}_\n`;

writeFileSync(`${dir}/SUMMARY.md`, md);
console.log(md);
