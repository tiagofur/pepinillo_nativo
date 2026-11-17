#!/usr/bin/env bash
# Deploy the web build (landing + guides + PWA) to the production VPS.
#
# Topology (docs/deployment.md §4.1-4.2): Plesk nginx owns 80/443 on the VPS;
# two Plesk sites serve the SAME SvelteKit static build:
#   pepinillo.app          → /var/www/vhosts/pepinillo.app/httpdocs
#   app.pepinillo.app      → /var/www/vhosts/pepinillo.app/app.pepinillo.app
#
# Usage:
#   scripts/deploy_web.sh [--dry-run]
#
# Prereqs: DNS A records for pepinillo.app and app.pepinillo.app → 74.208.234.244;
# Plesk sites created (see docs/deployment.md §4.2); ssh alias `ordo-vps` in ~/.ssh/config.
set -euo pipefail

VPS_HOST="${VPS_HOST:-ordo-vps}"
VPS_DOCROOT_MAIN="${VPS_DOCROOT_MAIN:-/var/www/vhosts/pepinillo.app/httpdocs}"
VPS_DOCROOT_APP="${VPS_DOCROOT_APP:-/var/www/vhosts/pepinillo.app/app.pepinillo.app}"
WEB_DIR="$(cd "$(dirname "$0")/../web" && pwd)"
DRY_FLAG=""
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_FLAG="--dry-run"
fi

echo "==> Building web (pnpm build)"
(cd "$WEB_DIR" && pnpm build)

echo "==> rsync build → $VPS_HOST:$VPS_DOCROOT_MAIN ${DRY_FLAG}"
rsync -az --delete $DRY_FLAG "$WEB_DIR/build/" "$VPS_HOST:$VPS_DOCROOT_MAIN/"

echo "==> rsync build → $VPS_HOST:$VPS_DOCROOT_APP ${DRY_FLAG}"
rsync -az --delete $DRY_FLAG "$WEB_DIR/build/" "$VPS_HOST:$VPS_DOCROOT_APP/"

echo "==> Reloading nginx (Plesk)"
ssh "$VPS_HOST" "nginx -t && nginx -s reload"

echo "==> Done. Verify: https://pepinillo.app and https://app.pepinillo.app"
