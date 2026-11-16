# Pruebas locales — Web ↔ Backend Go real (pre-deploy)

Runbook verificado end-to-end el 2026-11-16 (epic #809). Todo corre en tu Mac:
web :4174 · API :8090 · Postgres :55433 · Redis :6380 · email por **log** (sin SMTP).

> Rama de integración: `local-integration` (W8 web + backend Stripe fusionados).
> `pnpm preview` NO se usa — cada rebuild lo mata (ENOENT en hashes). Se usa
> `scripts/serve-build.mjs`, que sobrevive rebuilds.

## 0. Infra (una vez)

```bash
cd backend
docker compose up -d postgres          # 5433 (o el contenedor que ya uses)
docker run -d --name pepinillo-redis-dev -p 6380:6379 redis:7-alpine
```

> Si 6379/5433/8080 están ocupados por otros proyectos (ordeno, creapolis-crm,
> etc.), estos puertos alternativos ya lo evitan. Postgres nuevo: borra
> `backend_postgres_data` si tiene una password vieja (`docker compose rm -sf
> postgres && docker volume rm backend_postgres_data && docker compose up -d postgres`).

## 1. API Go real (:8090)

```bash
cd backend
DATABASE_URL="postgres://postgres:postgres@127.0.0.1:55433/pepinillo?sslmode=disable" \
REDIS_URL="redis://localhost:6380" \
JWT_SECRET="$(openssl rand -hex 32)" \
APP_ENV=development \
CORS_ALLOWED_ORIGINS="http://127.0.0.1:4174,http://localhost:4174" \
EMAIL_PROVIDER=log \
PORT=8090 \
go run ./cmd/api
```

Las migraciones (000001–000017) corren al boot. Health: `curl localhost:8090/api/v1/health`.

## 2. Web apuntando al API real

```bash
cd web
PUBLIC_API_BASE_URL=http://127.0.0.1:8090 \
PUBLIC_WS_URL=ws://127.0.0.1:8090 \
pnpm install && pnpm build

node ../scripts/serve-build.mjs 4174   # http://localhost:4174
```

⚠️ Cada build DEBE incluir los `PUBLIC_*` (rolldown no hornea `import.meta.env`
en chunks de SvelteKit — se hornean vía `__PUBLIC_*__` defines en vite.config).

## 3. Flujo de prueba (10 min)

1. **Registro** en `/account` → el email de verificación sale en el **log del API**.
   Código de 6 dígitos también en Redis:
   `docker exec pepinillo-redis-dev redis-cli GET "email_verify:<tu-email>"`.
2. **Verificar** → sign in → badge Free → crea tareas en Plan (cap de 3 en free).
3. **Sync**: "Sync now" en Account → 402 `ERR_TIER_INSUFFICIENT` visible →
   correcto: sync requiere Everywhere+.
4. **Simular Everywhere+** (dev): `docker exec pepinillo-web-pg psql -U postgres
   -d pepinillo -c "UPDATE users SET subscription_tier='everywhere_monthly',
   subscription_expires_at=now() + interval '30 days' WHERE email='<tu-email>"`
   → refresca la página → badge Everywhere/AI+ → sync OK (initial-upload +
   sync/full 200), subtareas/recurrencia/30D/1Y desbloqueadas, WS conectado.
5. **Focus** completo: sesiones con sonido/celebraciones/journal (ver PRs).
6. **IA**: con LLM key configurada cargan tips; sin key, error graceful
   (predictions estadísticas sí funcionan sin LLM).
7. **Sign out** → todo queda local (IndexedDB).

## 4. Stripe (opcional, test mode)

```bash
STRIPE_SECRET_KEY=sk_test_... STRIPE_WEBHOOK_SECRET=whsec_... \
STRIPE_PRICE_PEPINILLO_PLUS=price_... \
STRIPE_PRICE_EVERYWHERE_MONTHLY=price_... \
STRIPE_PRICE_EVERYWHERE_ANNUAL=price_...
# + las variables del paso 1
go run ./cmd/api
# y `stripe listen --forward-to localhost:8090/api/v1/billing/stripe/webhook`
```

`/upgrade` → comprar en test mode → webhook → `stripe_tier` en users → tier efectivo.

## Limpieza

```bash
docker rm -f pepinillo-redis-dev
docker compose -f backend/docker-compose.yml down   # (deja volúmenes)
```
