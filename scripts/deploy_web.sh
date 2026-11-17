#!/usr/bin/env bash
# Deploy BOTH static sites to the production VPS (Plesk docroots):
#   landing/ (marketing + guides) → pepinillo.app
#   web/    (PWA app)             → app.pepinillo.app
# GitHub Actions deploys these automatically (landing-deploy.yml, web-deploy.yml);
# this script is the manual equivalent.
# Usage: scripts/deploy_web.sh [--dry-run]
set -euo pipefail

VPS_HOST="${VPS_HOST:-ordo-vps}"
VPS_DOCROOT_MAIN="${VPS_DOCROOT_MAIN:-/var/www/vhosts/pepinillo.app/httpdocs}"
VPS_DOCROOT_APP="${VPS_DOCROOT_APP:-/var/www/vhosts/pepinillo.app/app.pepinillo.app}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_FLAG=""
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_FLAG="--dry-run"
fi

RSYNC_FLAGS=(-a --no-o --no-g --no-perms -O --delete --exclude=.well-known)

echo "==> Building landing (pnpm build)"
(cd "$ROOT/landing" && pnpm build)

echo "==> Building web app (pnpm build)"
(cd "$ROOT/web" && pnpm build)

echo "==> rsync landing → $VPS_HOST:$VPS_DOCROOT_MAIN ${DRY_FLAG}"
rsync -az "${RSYNC_FLAGS[@]}" $DRY_FLAG "$ROOT/landing/build/" "$VPS_HOST:$VPS_DOCROOT_MAIN/"

echo "==> rsync app → $VPS_HOST:$VPS_DOCROOT_APP ${DRY_FLAG}"
rsync -az "${RSYNC_FLAGS[@]}" $DRY_FLAG "$ROOT/web/build/" "$VPS_HOST:$VPS_DOCROOT_APP/"

echo "==> Reloading nginx (Plesk)"
ssh "$VPS_HOST" "nginx -t && nginx -s reload"

echo "==> Done. Verify: https://pepinillo.app (landing) + https://app.pepinillo.app/focus (app)"
