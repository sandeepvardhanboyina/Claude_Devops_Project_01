#!/usr/bin/env bash
#
# Stamps the site with deployment metadata and stages it for upload.
#
# Produces app/build-info.json, which js/main.js fetches at runtime to render
# the "Last deployed" line in the footer. Run from anywhere.
#
#   ./scripts/build.sh              # stamp in place
#   OUT_DIR=dist ./scripts/build.sh # also copy the site to dist/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${REPO_ROOT}/app"
OUT_DIR="${OUT_DIR:-}"

# In GitHub Actions the SHA is handed to us; locally, ask git. Fall back to
# "unknown" so the script still works in a tarball with no .git directory.
if [[ -n "${GITHUB_SHA:-}" ]]; then
  COMMIT="${GITHUB_SHA}"
elif git -C "${REPO_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
  COMMIT="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
else
  COMMIT="unknown"
fi

DEPLOYED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-local}"
BRANCH="${GITHUB_REF_NAME:-$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"

cat > "${APP_DIR}/build-info.json" <<JSON
{
  "deployedAt": "${DEPLOYED_AT}",
  "commit": "${COMMIT}",
  "branch": "${BRANCH}",
  "buildNumber": "${BUILD_NUMBER}"
}
JSON

echo "Build stamp written to app/build-info.json"
echo "  deployedAt : ${DEPLOYED_AT}"
echo "  commit     : ${COMMIT}"
echo "  branch     : ${BRANCH}"
echo "  build      : ${BUILD_NUMBER}"

if [[ -n "${OUT_DIR}" ]]; then
  DEST="${REPO_ROOT}/${OUT_DIR}"
  rm -rf "${DEST}"
  mkdir -p "${DEST}"
  cp -r "${APP_DIR}/." "${DEST}/"
  echo "Site copied to ${OUT_DIR}/"
fi
