#!/usr/bin/env bash
#
# Runs the k6 load test against the live site at five concurrency levels
# (20, 50, 100, 150, 200 virtual users), two minutes each, writing one JSON
# report per stage into reports/, then a combined reports/SUMMARY.md.
#
# Uses a local k6 if present, otherwise falls back to the official Docker image,
# so it works with either installed.
#
#   ./run-load-tests.sh
#   TARGET_URL=http://my-alb/ DURATION=2m STAGES="20 50" ./run-load-tests.sh
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET_URL="${TARGET_URL:-http://claude-first-project-alb-313830275.us-east-1.elb.amazonaws.com/}"
DURATION="${DURATION:-2m}"
STAGES="${STAGES:-20 50 100 150 200}"

mkdir -p reports

# Pick a runner: native k6, or Docker mounting this directory as the workdir.
run_k6() {
  local stage="$1" vus="$2"
  if command -v k6 >/dev/null 2>&1; then
    STAGE="$stage" VUS="$vus" DURATION="$DURATION" TARGET_URL="$TARGET_URL" \
      k6 run load-test.js
  else
    docker run --rm --user root -v "$(pwd):/work" -w /work \
      -e STAGE="$stage" -e VUS="$vus" -e DURATION="$DURATION" -e TARGET_URL="$TARGET_URL" \
      grafana/k6 run load-test.js
  fi
}

echo "Target: $TARGET_URL"
echo "Duration per stage: $DURATION"

for VUS in $STAGES; do
  echo ""
  echo "=== Stage: ${VUS} concurrent users for ${DURATION} ==="
  run_k6 "${VUS}-vus" "$VUS"
done

echo ""
echo "All stages complete. Building combined summary..."
node summarize.mjs

echo "Done. See reports/SUMMARY.md"
