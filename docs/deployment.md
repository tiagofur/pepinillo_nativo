# Despliegue y releases

Producción activa: **`https://api.ppn.creapolis.dev/api/v1`** (VPS IONOS,
Docker Compose + Caddy). Guía inicial histórica: `docs/legacy/root/`.

---

## 1. Topología de producción

```text
GitHub Actions (deploy.yml, push a main tocando backend/**)
   → SSH deploy@<vps> (/home/deploy/pepinillo)
   → docker compose -f docker-compose.prod.yml build --no-deps api && up -d api
   → healthcheck http://127.0.0.1:8090/api/v1/health (30 x 2 s)

api    (Go/Fiber, Dockerfile, :8090→8080 interno, healthcheck /api/v1/health)
db     (postgres:16-alpine)
redis  (redis:7-alpine)
caddy  (caddy:2, 80/443, TLS automático, HSTS, gzip, api.ppn.creapolis.dev → api:8080)
```
`ml_service` corre solo con perfil `ml` en `docker-compose.yml` (dev); no está
en prod compose. Variables críticas del runtime en `backend/.env.production`
(existente en el VPS; nunca commiteada):

- `APP_ENV=production`, `JWT_SECRET`, `REFRESH_TOKEN_HASH_KEY` (≥32 bytes),
  `CORS_ALLOWED_ORIGINS` (sin `*`), `APPLE_BUNDLE_ID`.
- `REVENUECAT_WEBHOOK_AUTH_TOKEN` (auth del webhook), claves APNs/FCM,
  `GOOGLE_CLIENT_IDS`, MinIO, SendGrid, Sentry DSN.

**Fail-closed**: sin esas variables en production el API no arranca
(`internal/config/config.go`). Rollback: redeploy del compose anterior o
`git revert` + push (el workflow repite deploy).

## 2. Releases de clientes

### iOS / iPadOS / watchOS / macOS
- Versionado en `ios/project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
- Pipeline por CLI (upload `xcodebuild` + API key p8) documentado en memoria de
  proyecto; screenshots en `ios/apple_store/` y guías vivas en `ios/docs/`
  (`launch-checklist.md`, `app-store-listing.md` — este último protegido por
  `PaywallCommercialClaimsTests`).
- Checklist previo: bump de versión, `xcodegen generate`, suite fast en CI,
  archive Release, privacy report, metadata ASC al día.

### Android / Wear OS
- Versionado en `android/app/build.gradle.kts` y `android/wear/build.gradle.kts`
  (`versionCode` phone 29 / wear 10029, `versionName` 3.1.0).
- Release firmado con `android/key.properties` + `pepinillo.jks` (nunca
  commiteados). Assets de listing en `screenshots/` y `screenshots/dist/`.
- Checklist: bump versionCode, suite unit completa, bundle Release, listing
  Play Console, rollout gradual.

## 3. Secretos y seguridad

Reglas canónicas en [`../SECURITY.md`](../SECURITY.md): nunca commitear `.env`,
claves `sk_` de RevenueCat, certificados o tokens. Scanner local
`python3 scripts/check_secrets.py` + CI `secret-scan.yml`. El secret de
RevenueCat expuesto (issue #613, commit `d6d98eee`) permanece en historia Git:
tratar como comprometido hasta confirmar rotación.

## 4. Dominios y URLs de referencia

| Entorno | URL |
| :--- | :--- |
| API producción | `https://api.ppn.creapolis.dev/api/v1` |
| API staging | `https://staging.api.ppn.creapolis.dev/api/v1` |
| Web marketing | `https://creapolis.dev` (privacy/terms: `/privacy-policy/`, `/terms-of-use/`) |
| Upgrade URL (paywall) | `https://pepinillo.app/upgrade` |
