#!/usr/bin/env bash
#
# Runs ON an EC2 instance, invoked by the deploy pipeline through SSM Run Command
# (not SSH). It swaps a freshly-fetched copy of the site into the nginx web root
# and reloads.
#
# The pipeline fetches this repo's tarball for the deployed commit, extracts it,
# and runs, as root:
#
#   DEPLOY_SHA=... DEPLOY_RUN=... DEPLOY_REF=... bash scripts/remote-deploy.sh app
#
set -euo pipefail

SRC_APP="${1:-app}"
WEB_ROOT="/var/www/html"

if [[ ! -d "${SRC_APP}" ]]; then
  echo "source app directory '${SRC_APP}' not found" >&2
  exit 1
fi

# Stamp the deployment metadata the footer reads, using the values the pipeline
# passed in. Generated here so it always reflects the commit actually deployed.
cat > "${SRC_APP}/build-info.json" <<JSON
{
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "${DEPLOY_SHA:-unknown}",
  "branch": "${DEPLOY_REF:-unknown}",
  "buildNumber": "${DEPLOY_RUN:-unknown}"
}
JSON

# Stage into a temp dir first, then swap, so nginx never serves a half-copied
# site. cp -a preserves permissions; find -delete clears the old files while
# keeping the web root directory itself in place.
STAGE="$(mktemp -d)"
cp -a "${SRC_APP}/." "${STAGE}/"

install -d -o www-data -g www-data "${WEB_ROOT}"
find "${WEB_ROOT}" -mindepth 1 -delete
cp -a "${STAGE}/." "${WEB_ROOT}/"
chown -R www-data:www-data "${WEB_ROOT}"
rm -rf "${STAGE}"

# Reload (not restart) so in-flight requests are not dropped, and -t first so a
# broken config can never take nginx down.
nginx -t
systemctl reload nginx

echo "Deployed commit ${DEPLOY_SHA:-unknown} (build ${DEPLOY_RUN:-unknown}) to ${WEB_ROOT}"
