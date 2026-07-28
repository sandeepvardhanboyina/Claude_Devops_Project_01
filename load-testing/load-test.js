import http from "k6/http";
import { check, sleep } from "k6";

// Target the live site. Override with -e TARGET_URL=...
const TARGET_URL =
  __ENV.TARGET_URL ||
  "http://claude-first-project-alb-313830275.us-east-1.elb.amazonaws.com/";

// One "stage" = a fixed number of concurrent virtual users (VUs) held for a
// fixed duration. The runner invokes this script once per stage: 20, 50, 100,
// 150 and 200 users, two minutes each.
export const options = {
  scenarios: {
    load: {
      executor: "constant-vus",
      vus: Number(__ENV.VUS || 20),
      duration: __ENV.DURATION || "2m",
    },
  },
  // Pass/fail gates: the run is marked failed if either is breached.
  thresholds: {
    http_req_failed: ["rate<0.05"], // fewer than 5% errors
    http_req_duration: ["p(95)<2000"], // 95% of requests under 2s
  },
};

export default function () {
  const res = http.get(TARGET_URL);
  check(res, { "status is 200": (r) => r.status === 200 });
  // Think time, so each VU models a real user rather than a tight loop.
  sleep(1);
}

// Emit exactly the metrics the assignment asks for, per stage, as JSON.
export function handleSummary(data) {
  const m = data.metrics;
  const round = (x) => Math.round((Number(x) + Number.EPSILON) * 100) / 100;
  const checks = m.checks ? m.checks.values : { passes: 0, fails: 0 };
  const totalChecks = checks.passes + checks.fails || 1;

  const summary = {
    stage: __ENV.STAGE || `${__ENV.VUS || 20}-vus`,
    concurrent_users: Number(__ENV.VUS || 20),
    duration: __ENV.DURATION || "2m",
    target: TARGET_URL,
    requests_total: m.http_reqs.values.count,
    requests_per_sec: round(m.http_reqs.values.rate),
    response_time_ms: {
      avg: round(m.http_req_duration.values.avg),
      p90: round(m.http_req_duration.values["p(90)"]),
      p95: round(m.http_req_duration.values["p(95)"]),
      max: round(m.http_req_duration.values.max),
    },
    error_rate_pct: round(m.http_req_failed.values.rate * 100),
    throughput_kb_per_sec: round(m.data_received.values.rate / 1024),
    checks_passed_pct: round((checks.passes / totalChecks) * 100),
  };

  const stage = summary.stage;
  return {
    [`reports/summary-${stage}.json`]: JSON.stringify(summary, null, 2),
    stdout: `\n[${stage}] ${summary.requests_total} reqs | ${summary.requests_per_sec}/s | p95 ${summary.response_time_ms.p95}ms | err ${summary.error_rate_pct}%\n`,
  };
}
