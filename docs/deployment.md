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
| Upgrade URL (paywall) | `https://app.pepinillo.app/upgrade` |

### 4.1 Dominio propio `pepinillo.app` (comprado 2026-11-17)

Split de dominios decidido por Tiago (issue #855); el despliegue real es el batch
**W9** del epic #809 (Caddy vhosts + DNS + CORS + QA):

| Superficie | Dominio |
| :--- | :--- |
| Landing + guías de usuario (`/`, `/guides*`) | `https://pepinillo.app` |
| PWA app (`/focus`, `/plan`, `/dashboard`, `/account`, `/upgrade`) | `https://app.pepinillo.app` |

Notas: los canonical/OG de landing y guías usan `pepinillo.app`; `/upgrade`
canonicaliza a `app.pepinillo.app` (ver `web/static/sitemap.xml`). CORS del
backend deberá permitir ambos orígenes al configurar W9.

### 4.2 Runbook de deploy web (W9, issue #857)

Topología real del VPS (`ordo-vps`, 74.208.234.244): **Plesk nginx posee 80/443**
(el `pepinillo-proxy` de `docker-compose.prod.yml` no puede enlazar esos puertos y
no corre; `api.ppn.creapolis.dev` es un sitio Plesk con proxy a `127.0.0.1:8090`).
El deploy web es estático por rsync, no Docker.

**DNS previo (accionar en el registrador — IONOS, ns `ui-dns.*`):**

| Registro | Valor |
| :--- | :--- |
| `A @ (pepinillo.app)` | `74.208.234.244` (hoy apunta a `74.208.236.21`, nginx ajeno — corregir) |
| `A app.pepinillo.app` | `74.208.234.244` (hoy no existe) |

**Creación de sitios (una vez, Plesk CLI por ssh como root):**

```bash
plesk bin site --create pepinillo.app -hosting-type vhost -www-root httpdocs
plesk bin subdomain --create app -domain pepinillo.app -www-root app.pepinillo.app
# SPA fallback para rutas de la PWA (ambos sitios):
#   /var/www/vhosts/system/<dominio>/conf/vhost_nginx.conf con:
#     location / { try_files $uri $uri/ /index.html; }
plesk bin httpdmng --reconfigure-server
# TLS cuando el DNS resuelva (extensión Let's Encrypt de Plesk):
plesk bin extension --exec letsencrypt-cli -d pepinillo.app -d www.pepinillo.app -d app.pepinillo.app
```
(Sintaxis a verificar en ejecución con `plesk bin site --help` / `plesk bin subdomain --help`.)

**Deploy estático (repetible):**

```bash
scripts/deploy_web.sh            # build + rsync a ambos docroots + nginx reload
scripts/deploy_web.sh --dry-run  # solo ver el plan
```

**CORS del backend (una vez por cambio de orígenes):** en
`/home/deploy/pepinillo/backend/.env.production` añadir
`https://app.pepinillo.app,https://pepinillo.app` a `CORS_ALLOWED_ORIGINS`
(sin `*`, fail-closed) y recrear el API:
`docker compose -f docker-compose.prod.yml up -d api`.

**Verificación post-deploy:** `https://pepinillo.app` (landing + `/guides/macos`),
`https://app.pepinillo.app/focus` (PWA) y `https://app.pepinillo.app/upgrade`
(checkout Stripe con `app.pepinillo.app` en success/cancel); llamada al API desde
el origen de la PWA sin error CORS; QA touch/responsive spot-check.

**Rollback:** los docroots son reemplazables por rsync del build anterior;
`plesk bin site --remove` elimina los sitios sin tocar otros proyectos del host.
