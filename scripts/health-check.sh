#!/usr/bin/env bash
#
# Polls a URL until it answers HTTP 200, or gives up.
#
# Used as the final gate in the deploy pipeline: a green deploy job means
# nothing if the load balancer is handing out 502s.
#
#   ./scripts/health-check.sh http://my-alb-123.us-east-1.elb.amazonaws.com
#   RETRIES=60 INTERVAL=5 ./scripts/health-check.sh "$ALB_DNS"

set -euo pipefail

URL="${1:-${TARGET_URL:-}}"
RETRIES="${RETRIES:-30}"
INTERVAL="${INTERVAL:-10}"
EXPECT="${EXPECT:-200}"

if [[ -z "${URL}" ]]; then
  echo "usage: $0 <url>    (or set TARGET_URL)" >&2
  exit 2
fi

# Accept a bare DNS name as well as a full URL.
if [[ "${URL}" != http://* && "${URL}" != https://* ]]; then
  URL="http://${URL}"
fi

echo "Health check: ${URL}"
echo "Expecting HTTP ${EXPECT}, up to ${RETRIES} attempts every ${INTERVAL}s"

for (( attempt = 1; attempt <= RETRIES; attempt++ )); do
  # --max-time keeps a hung connection from eating the whole budget.
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${URL}" || echo "000")"

  if [[ "${code}" == "${EXPECT}" ]]; then
    echo "Attempt ${attempt}: HTTP ${code} — healthy"

    # A single 200 can come from one instance that happens to be ready while
    # others are still rolling. Confirm stability before declaring success.
    ok=1
    for confirm in 1 2 3; do
      sleep 2
      recheck="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${URL}" || echo "000")"
      if [[ "${recheck}" != "${EXPECT}" ]]; then
        echo "  confirmation ${confirm}: HTTP ${recheck} — not stable yet"
        ok=0
        break
      fi
    done

    if [[ "${ok}" == "1" ]]; then
      echo "Deployment verified: ${URL} is serving HTTP ${EXPECT} consistently."
      exit 0
    fi
  else
    echo "Attempt ${attempt}/${RETRIES}: HTTP ${code} — waiting ${INTERVAL}s"
  fi

  sleep "${INTERVAL}"
done

echo "Health check FAILED after ${RETRIES} attempts: ${URL} never returned HTTP ${EXPECT}." >&2
echo "Check: target group health, nginx status on the instances, and the instance security group." >&2
exit 1
