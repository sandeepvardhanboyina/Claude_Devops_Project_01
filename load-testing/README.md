# Load Testing

Load tests for the deployed site, using [k6](https://k6.io). They drive the
live ALB at five concurrency levels and record how it behaves.

## What it measures

Each stage holds a fixed number of concurrent virtual users (VUs) for a fixed
duration and records, into `reports/`:

- **Requests** total and **requests/sec** (throughput in requests)
- **Response time** — average, p90, **p95**, max
- **Error %** — share of non-2xx / failed requests
- **Throughput** — KB/sec received

Stages: **20, 50, 100, 150, 200** concurrent users, **2 minutes** each.

## Running

From this directory:

```bash
./run-load-tests.sh
```

The script uses a local `k6` if installed, otherwise the official Docker image
(`grafana/k6`) — so either works. Override the defaults with env vars:

```bash
TARGET_URL=http://my-alb/  DURATION=2m  STAGES="20 50 100 150 200"  ./run-load-tests.sh
```

Run a single stage directly:

```bash
# native k6
STAGE=100-vus VUS=100 DURATION=2m k6 run load-test.js

# or via Docker
docker run --rm --user root -v "$(pwd):/work" -w /work \
  -e STAGE=100-vus -e VUS=100 -e DURATION=2m grafana/k6 run load-test.js
```

## Output

- `reports/summary-<N>-vus.json` — one file per stage with the metrics above
- `reports/SUMMARY.md` — a single table across all stages (built by `summarize.mjs`)

## Notes

- The site is static content served by nginx, which is very light, so a healthy
  run shows near-zero errors and low latency even at 200 users. The point is to
  confirm the ALB + Auto Scaling Group stay healthy and responsive under load.
- Sustained high CPU (>70%) would trip the scale-out alarm and add instances;
  static files rarely push CPU that high, so scaling may not trigger from this
  workload alone — the CloudWatch dashboard shows CPU during the run either way.
