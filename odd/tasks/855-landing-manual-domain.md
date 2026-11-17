# 855 — feat(web): guides strip on landing + domain split to app.pepinillo.app
Objective: Surface the macOS user manual on the landing (strip + footer link, i18n es/en/pt) and record the domain split decision (landing/guides at `pepinillo.app`, PWA + upgrade at `app.pepinillo.app`) in code (sitemap, canonicals, backend upgrade_url defaults) and docs.
Branch: `feat/landing-manual-domain` (stacked on `docs/manual-macos` / PR #854 — retarget to main when it merges) | Delivery: `complete` | Test runners: `pnpm check` + `pnpm test` (web), `go test ./internal/config/... ./internal/adapters/middleware/... ./internal/services/...` (backend)

## Specs

- **S1**: Landing shows a guides strip (title + sub + CTA to `/guides/macos.html` + secondary link to `/guides`) in es/en/pt; footer gains a direct "Manual de macOS" link.
- **S2**: `sitemap.xml` `/upgrade` and the `/upgrade` canonical/OG point to `https://app.pepinillo.app/upgrade`; landing/guides canonicals stay `https://pepinillo.app`.
- **S3**: Backend `upgrade_url` (require_backend_sync) and Stripe success/cancel URL defaults point to `https://app.pepinillo.app/upgrade`; test fixture updated.
- **S4**: `docs/deployment.md` §4.1 records the domain split + W9 sequencing note; `docs/product-map.md` Web row updated.
- **S5**: `pnpm check` + `pnpm test` + build green; affected backend Go tests green.

## Allowed edit surfaces

- `web/src/routes/+page.svelte`, `web/src/lib/i18n/messages.ts`, `web/static/sitemap.xml`, `web/src/routes/upgrade/+page.svelte`
- `backend/internal/config/config.go`, `backend/internal/adapters/middleware/require_backend_sync.go`, `backend/internal/services/stripe_service_test.go`
- `docs/deployment.md`, `docs/product-map.md`
- `odd/tasks/855-landing-manual-domain.md`

## Execution notes

- W8 already used "Mac"/"macOS" vocabulary on the landing (FAQ devices answer, guides index), so the strip copy follows the same approved wording.
- Backend URL changes are code DEFAULTS (env-overridable); they reach production only with the next backend deploy (W9) — DNS for `app.pepinillo.app` must resolve before that deploy.
- VPS/DNS/Caddy/CORS work remains in W9 (out of this artifact's scope).

## Log

- **L1 (2026-11-17)**: User request verbatim: `esto tiene que estar integrado a la app web en su landingpage... y la app sera en un subdominio app.pepinillo.app, de hecho ya compre el dominio pepinillo.app`. Issue #855 created; branch stacked on #854 after discovering main still carries the old manual (the landing CTA was serving it — merged `docs/manual-macos` into this branch and verified the full landing→manual flow in the browser: 13 sections, 28/28 images, 0 broken).
