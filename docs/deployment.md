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
| API producción (nuevo) | `https://api.pepinillo.app/api/v1` — en paralelo hasta migrar las apps nativas |
| API staging | `https://staging.api.ppn.creapolis.dev/api/v1` |
| Web marketing | `https://creapolis.dev` (privacy/terms: `/privacy-policy/`, `/terms-of-use/`) |
| Upgrade URL (paywall) | `https://app.pepinillo.app/upgrade` |

### 4.1 Dominio propio `pepinillo.app` (comprado 2026-11-17)

Split de dominios decidido por Tiago (issues #855 y #859); el despliegue real es
el batch **W9** del epic #809 (DNS + sitios Plesk + rsync + CORS + QA):

| Superficie | Dominio |
| :--- | :--- |
| Landing (`/`) + guías (`/guides*`) | `https://pepinillo.app` |
| PWA app (`/focus`, `/plan`, `/dashboard`, `/account`, `/upgrade`) | `https://app.pepinillo.app` (abre directamente en `/focus`) |
| API (nuevo hostname) | `https://api.pepinillo.app` — mismo contenedor que el viejo |

**Separación por código (decisión Tiago 2026-11-17, PR #869): dos proyectos.**

| Proyecto | Contenido | Dominio | Deploy |
| :--- | :--- | :--- | :--- |
| `landing/` | Marketing (`/`) + guías (`/guides*`) + assets propios | `https://pepinillo.app` | `landing-deploy.yml` |
| `web/` | PWA app-only (`/` = stub → `/focus`, `/focus|plan|dashboard|account|upgrade`) | `https://app.pepinillo.app` | `web-deploy.yml` |

Ambos builds comparten el diseño/i18n por copia (toast store, LocaleCode,
tokens). En `pepinillo.app`, las rutas PWA redirigen 302 a `app.pepinillo.app`;
en `app.pepinillo.app`, `/` redirige a `/focus` (además de que el propio build
sirve un stub `meta refresh` → `/focus` en el docroot) y `/guides*` redirige a la
landing. El índice de guías se sirve desde `guides.html` (adapter-static emite
sin trailing slash): `location = /guides { try_files /guides.html =404; }`.
`web/` mantiene `sw.js`, manifest (`start_url /focus`) y el fallback SPA
(`app.html`) para las rutas no pre-renderizadas.

**Coexistencia de API (issue #859):** las apps nativas siguen apuntando a
`api.ppn.creapolis.dev`, así que **ambos hostnames sirven el mismo contenedor
`pepinillo-api`** (dos sitios Plesk con proxy a `127.0.0.1:8090` — Fiber no
depende del Host). La migración de clientes (bump de base-URL por plataforma) es
backlog aparte; el hostname viejo no se retira hasta que todas las apps
publicadas usen el nuevo.

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
| `A api.pepinillo.app` | `74.208.234.244` (hoy no existe) |

**Creación de sitios (una vez, Plesk CLI por ssh como root):**

```bash
plesk bin subscription -c pepinillo.app -login pepinillo_app -passwd '<secreto>'
plesk bin subscription -u pepinillo.app -hosting true -ip 74.208.234.244 -login pepinillo_app -passwd '<secreto>'
plesk bin site -u pepinillo.app -www-root httpdocs
plesk bin subdomain -c app -domain pepinillo.app -www-root app.pepinillo.app
plesk bin subdomain -c api -domain pepinillo.app -www-root api.pepinillo.app
# nginx custom (vhost_nginx.conf por dominio) + regenerar config + nginx reload:
#   app.pepinillo.app → el fallback SPA es app.html (adapter fallback), NUNCA
#     /index.html (en el build app-only, index.html es un stub meta-refresh →
#     /focus: usarlo como fallback crea un redirect eterno):
#       location = / { return 302 /focus; }
#       location ~ ^/(focus|plan|dashboard|account|upgrade) {
#           try_files $uri $uri.html $uri/ /app.html;
#       }
#       error_page 404 =200 /app.html;
#   pepinillo.app (landing): redirects 302 de rutas PWA al subdominio app +
#     mapeo del índice de guías + fallback a /index.html (landing shell):
#   api.pepinillo.app → proxy igual que api.ppn.creapolis.dev:
#       location ~ ^/.* { proxy_pass http://127.0.0.1:8090; ...headers ws... }
plesk repair web -y <dominio>          # regenera e incluye vhost_nginx.conf
nginx -t && nginx -s reload
# TLS (extensión "letsencrypt", flag de email es -m):
plesk bin extension --exec letsencrypt cli.php -d <dominio> -m hola@creapolis.dev
plesk bin site -u <dominio> -certificate-name 'Lets Encrypt <dominio>'  # si no auto-asigna
```
Ejecutado con éxito 2026-11-17. Notas: los docroots se dan al usuario de deploy
(`usermod -aG psaserv <user>` + chmod 2775) para el rsync del workflow; el rsync
usa `--no-o --no-g --no-perms -O --exclude=.well-known` (sin chown/chgrp de dirs
de Plesk; .well-known sobrevive a --delete para renovaciones LE).

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
