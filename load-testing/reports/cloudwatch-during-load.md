# CloudWatch metrics during the load test

Captured during the k6 run (20/50/100/150/200 VUs, 2 min each) against the ALB, 05:22-05:36 UTC.

| Time (UTC) | Stage | Requests/min | EC2 CPU max (%) | ALB backend resp (ms) |
|---|---|---:|---:|---:|
| 05:22 |  | 1 | 0.74 | 0.76 |
| 05:23 | 20 VUs start | 67 | 0.73 | 0.63 |
| 05:24 | 20 VUs | 260 | 0.80 | 0.59 |
| 05:25 |  | 1135 | 0.94 | 0.64 |
| 05:26 | 50 VUs | 1484 | 1.07 | 0.70 |
| 05:27 |  | 2831 | 1.25 | 0.66 |
| 05:28 | 100 VUs | 3268 | 1.37 | 0.67 |
| 05:29 |  | 5714 | 1.58 | 0.65 |
| 05:30 | 150 VUs | 6035 | 1.82 | 0.72 |
| 05:31 |  | 8367 | 1.93 | 0.66 |
| 05:32 | 200 VUs | 8655 | 2.18 | 0.67 |
| 05:33 |  | 10844 | 2.28 | 0.67 |
| 05:34 | 200 VUs end | 9030 | 2.23 | 0.84 |
| 05:35 |  | 0 | 1.11 |  |

**Peak requests/min:** 10844

**Peak EC2 CPU during the test:** 2.28% — far below the 70% scale-out threshold, so the Auto Scaling Group correctly stayed at 1 instance. A static nginx site is light enough that ~180 req/s barely touches CPU; the ALB backend response time held near 0.6-0.8 ms throughout.
